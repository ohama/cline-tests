#!/usr/bin/env python3
"""
Phase 4 NDJSON outcome classifier.

Reads a captured `cline --json` NDJSON stream (plus, optionally, the
wrapper's own exit code and stderr) and decides which ONE of six primary
outcomes the run produced. This is the phase's central risk-mitigation: a
crash, a model refusal, a TTY-approval self-abort, or the 32K terminal
failure must never be mistaken for "the sandbox denied it" (criterion 3's
false-pass discipline, ROADMAP Phase 4 brief).

Modelled directly on `phase-01/parse_result.py`'s discipline: stdlib only, a
PURE `classify()` with no file I/O and no clock, plus a thin CLI wrapper.

Six primary outcomes, in this exact PRECEDENCE ORDER (a stream can carry
more than one signature; `signals` records every one detected, but exactly
one is reported as the primary `outcome`, chosen by this order):

    crashed > sandbox_denied > context_overflow_terminal
            > tty_approval_rejected > run_aborted > success > other

Why this order, not some other:
  - `crashed` is first because an unusable/truncated stream, or a
    signal-killed process (exit code > 128), can prove nothing about any of
    the other outcomes -- reporting anything else off a crashed stream would
    be reading tea leaves.
  - `sandbox_denied` outranks everything below it because it is this
    phase's actual positive signal, and its signature (a real kernel EPERM)
    cannot be produced by any of the outcomes below it. A denial that
    happens to coincide with, say, a clean `finishReason:"completed"` must
    still surface as `sandbox_denied`, not `success`.
  - Because `signals` lists every signature found regardless of precedence,
    no information is lost to this ordering -- callers that need "did BOTH
    X and Y happen" can inspect `signals` directly.

Detection rules (see each outcome's block in `classify()` for the concrete
regex/field logic):
  - `crashed` -- no `run_result` event anywhere in the stream, OR
    `cline_exit_code is not None and cline_exit_code > 128` (signal death).
    Same discriminator `phase-03/sandbox/assert_denied.sh` already uses:
    signal death is a crash, never a denial. Reason text says the result is
    inconclusive and must not be reported as a successful block.
  - `sandbox_denied` -- at least one tool `content_end` output entry with
    `success` false whose `error`/`result` text matches
    `EPERM|Operation not permitted|not permitted`.
  - `context_overflow_terminal` -- an `agent_event` error event whose
    message (flat OR nested, see `_error_event_message()`) contains
    `MAX_KV_SIZE`, or matches `context tokens` plus a digit. Reason text
    carries the `docs/32k-compaction-policy.md` operational rule verbatim:
    terminal, not retryable -- restart the task, do not wait or retry in
    place.
  - `tty_approval_rejected` -- at least one tool output (object OR array
    entry) whose `error` matches `requires approval in a TTY session`.
    Reason text says this is the EXPECTED behavior of the shipped
    `--auto-approve false` wrapper for any tool-using prompt -- not a crash,
    not a sandbox event.
  - `run_aborted` -- a top-level `run_aborted` event or
    `run_result.finishReason == "aborted"`, with no TTY-approval signature
    outranking it (precedence already guarantees this: if a TTY signature
    is also present, `tty_approval_rejected` wins as the primary outcome).
  - `success` -- `run_result.finishReason == "completed"` and none of the
    above outrank it.
  - `other` -- anything else. Kept as its own bucket rather than forced
    into a wrong label.

Error-message extraction: `_error_event_message()` is copied from
`phase-01/parse_result.py` -- check flat `event["message"]` first, then fall
back to `event["error"]["message"]`. Cline 3.0.53 emits the NESTED shape in
every live run observed by this project; a flat-only reader silently misses
every real 32K failure (Phase 1 hit exactly this bug against real data, see
`phase-01/parse_result.py`'s own docstring for the incident writeup).

Tool-output shape tolerance: `content_end.output` is an ARRAY of per-query
dicts in the success/denial shape, and a bare OBJECT in the TTY-rejection
shape. `_tool_output_entries()` normalizes both to a list before inspection.
A sibling top-level `event["error"]` string (present alongside an empty/
missing `output` in some TTY captures) is also tolerated as a synthetic
single-entry fallback.

CLI exit code contract (an explicit numeric contract, callers grep it):
    0 = success
    2 = sandbox_denied
    3 = tty_approval_rejected
    4 = run_aborted
    5 = context_overflow_terminal
    6 = other
    7 = crashed / inconclusive
    1 = classifier's own usage/IO error (bad args, unreadable file, etc.)

CLI:
    python3 phase-04/classify_run.py --ndjson <file> [--exit-code <int>]
        [--stderr <file>] [--allowed-prefix <path> ...] --out <dir>
    writes <dir>/outcome.json and <dir>/outcome.md
"""
import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

_MALFORMED_MARKER = "_malformed_line"

_DENIAL_RE = re.compile(r"EPERM|Operation not permitted|not permitted", re.IGNORECASE)
_TTY_RE = re.compile(r'requires approval in a TTY session', re.IGNORECASE)

_KOREAN_ONE_LINER = {
    "success": (
        "정상 완료 - run_result.finishReason == completed (도구 실행 성공 여부와 무관)"
    ),
    "sandbox_denied": (
        "샌드박스가 화이트리스트 밖 경로에 대한 도구 호출을 커널 수준에서 거부했다 "
        "(EPERM/Operation not permitted) - criterion 3의 결정적 양성 신호"
    ),
    "context_overflow_terminal": (
        "32K MAX_KV_SIZE 컨텍스트 초과로 터미널(재시도 불가) 실패 - "
        "작업을 다시 시작해야 한다 (docs/32k-compaction-policy.md)"
    ),
    "tty_approval_rejected": (
        "--auto-approve false 헤드리스(no-TTY) 모드에서 모든 도구 호출이 "
        "TTY 승인 요구로 즉시 거부됨 - 이 래퍼의 예상된 동작이며 크래시가 아니다"
    ),
    "run_aborted": "실행이 외부 신호로 중단됨 (run_aborted / finishReason=aborted)",
    "crashed": (
        "스트림이 불완전하거나(run_result 없음) 프로세스가 시그널로 죽었다(exit>128) - "
        "미확정이며, 절대 '차단 성공'으로 보고하면 안 된다"
    ),
    "other": "위 다섯 결과 중 어디에도 해당하지 않음 - 원본 스트림을 직접 조사할 것",
}


@dataclass
class Outcome:
    outcome: str
    signals: List[str] = field(default_factory=list)
    reason: str = ""
    finish_reason: Optional[str] = None
    tool_attempts: List[dict] = field(default_factory=list)
    denied_targets: List[str] = field(default_factory=list)
    malformed_lines: int = 0
    cline_exit_code: Optional[int] = None


def parse_ndjson(lines):
    """Parse raw NDJSON text lines into event dicts.

    Tolerant of blank lines and a truncated trailing line (a killed run
    leaves a partial last line). Malformed lines are represented as
    sentinel dicts ({"type": "_malformed_line", ...}) rather than raising,
    so classify() can count them without a separate return channel.
    Copies phase-01/parse_result.py's parse_ndjson() pattern verbatim.
    """
    events = []
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            events.append({"type": _MALFORMED_MARKER, "raw": line})
    return events


def _error_event_message(event):
    """Extract the error text from an agent_event error, tolerant of two
    real, both-observed NDJSON shapes:

      - flat:   {"type": "error", "message": "..."}
      - nested: {"type": "error", "error": {"name": ..., "message": "..."}}
                (the ACTUAL shape emitted by cline 3.0.53 in a live run --
                the litellm.BadRequestError text lives one level deeper,
                under event["error"]["message"], not event["message"].
                Without this fallback, classify() silently falls through to
                "other" on every real MAX_KV_SIZE 400.)

    Copied verbatim (same logic) from phase-01/parse_result.py's
    _error_event_message() per this plan's explicit instruction to reuse
    the flat-vs-nested tolerance rather than re-deriving it.
    """
    if not isinstance(event, dict):
        return None
    flat = event.get("message")
    if flat:
        return flat
    nested = event.get("error")
    if isinstance(nested, dict):
        return nested.get("message")
    return None


def _is_context_overflow_message(message):
    """MAX_KV_SIZE OR 'context tokens' + a number -- never a generic error."""
    if not message:
        return False
    if "MAX_KV_SIZE" in message:
        return True
    if re.search(r"context tokens", message, re.IGNORECASE) and re.search(r"\d+", message):
        return True
    return False


def _tool_output_entries(event):
    """Normalize a content_end tool event's `output` field to a list of
    per-attempt dicts, tolerant of both real shapes:

      - ARRAY (success/denial shape): output is already a list of dicts,
        each with query/result/error/success.
      - OBJECT (TTY-rejection shape): output is a bare dict, e.g.
        {"error": "Tool \\"read_files\\" requires approval in a TTY session"}
        -- no query/success keys at all.

    Also tolerates a sibling top-level event["error"] string when `output`
    itself is missing or empty, as a single synthetic entry.
    """
    output = event.get("output")
    if isinstance(output, list):
        return output
    if isinstance(output, dict):
        return [output]
    top_error = event.get("error")
    if top_error:
        return [{"error": top_error}]
    return []


def classify(events, cline_exit_code=None, stderr_text="", allowed_prefixes=None):
    """Pure classification. No file I/O, no clock.

    `events` is a list of already-parsed event dicts (malformed lines
    represented via the `{"type": "_malformed_line", ...}` sentinel from
    parse_ndjson() -- classify() counts but otherwise ignores them).
    """
    allowed_prefixes = allowed_prefixes or []

    malformed_lines = sum(
        1 for e in events if isinstance(e, dict) and e.get("type") == _MALFORMED_MARKER
    )
    real_events = [
        e for e in events if isinstance(e, dict) and e.get("type") != _MALFORMED_MARKER
    ]

    run_result = None
    run_aborted_event = None
    for e in real_events:
        if e.get("type") == "run_result":
            run_result = e
        if e.get("type") == "run_aborted":
            run_aborted_event = e
    finish_reason = run_result.get("finishReason") if run_result else None

    tool_attempts = []
    denied_targets = []
    denied_inside_allowlist = False
    has_denial = False
    has_tty = False

    for e in real_events:
        if e.get("type") != "agent_event":
            continue
        inner = e.get("event")
        if not isinstance(inner, dict):
            continue
        if inner.get("type") != "content_end" or inner.get("contentType") != "tool":
            continue
        tool_name = inner.get("toolName")
        for entry in _tool_output_entries(inner):
            if not isinstance(entry, dict):
                continue
            query = entry.get("query")
            success = entry.get("success")
            error_text = entry.get("error")
            result_text = entry.get("result")
            tool_attempts.append(
                {
                    "tool_name": tool_name,
                    "query": query,
                    "success": success,
                    "error": error_text,
                }
            )
            combined = " ".join(
                str(v) for v in (error_text, result_text) if v is not None
            )
            if _TTY_RE.search(combined):
                has_tty = True
            if success is False and _DENIAL_RE.search(combined):
                has_denial = True
                target = query if query is not None else combined
                denied_targets.append(target)
                if allowed_prefixes and any(
                    str(target).startswith(p) for p in allowed_prefixes
                ):
                    denied_inside_allowlist = True

    context_overflow_messages = []
    for e in real_events:
        if e.get("type") != "agent_event":
            continue
        inner = e.get("event")
        if not isinstance(inner, dict) or inner.get("type") != "error":
            continue
        message = _error_event_message(inner)
        if _is_context_overflow_message(message):
            context_overflow_messages.append(message)
    has_overflow = bool(context_overflow_messages)

    has_crash = (run_result is None) or (
        cline_exit_code is not None and cline_exit_code > 128
    )
    has_aborted = (run_aborted_event is not None) or (finish_reason == "aborted")
    has_success = finish_reason == "completed"

    signals = []
    if has_crash:
        signals.append("crashed")
    if has_denial:
        signals.append("sandbox_denied")
    if has_overflow:
        signals.append("context_overflow_terminal")
    if has_tty:
        signals.append("tty_approval_rejected")
    if has_aborted:
        signals.append("run_aborted")
    if has_success:
        signals.append("success")
    if denied_inside_allowlist:
        signals.append("denied_inside_allowlist")

    if has_crash:
        outcome = "crashed"
        reason = (
            "Stream has no run_result event, or the wrapped process died by "
            "signal (exit code > 128). This result is INCONCLUSIVE about the "
            "sandbox and must never be reported as a successful block -- "
            "same discriminator phase-03/sandbox/assert_denied.sh uses."
        )
    elif has_denial:
        outcome = "sandbox_denied"
        reason = (
            "At least one tool call's output carries success:false and an "
            "EPERM/Operation not permitted signature -- this is the phase's "
            "positive criterion-3 signal: the OS/sandbox layer denied a real "
            "kernel-level attempt, not a crash, a TTY gate, or a model "
            "refusal."
        )
    elif has_overflow:
        outcome = "context_overflow_terminal"
        reason = (
            "An agent_event error contains the MAX_KV_SIZE / context-tokens "
            "overflow signature. Per docs/32k-compaction-policy.md §3②: "
            "this is TERMINAL, NOT RETRYABLE -- restart the task; do not "
            "wait or retry in place."
        )
    elif has_tty:
        outcome = "tty_approval_rejected"
        reason = (
            "At least one tool output's error matches 'requires approval in "
            "a TTY session'. This is the EXPECTED behavior of the shipped "
            "--auto-approve false wrapper for any tool-using prompt -- not a "
            "crash and not a sandbox event."
        )
    elif has_aborted:
        outcome = "run_aborted"
        reason = (
            "A top-level run_aborted event or finishReason:'aborted' was "
            "observed with no TTY-approval or higher-precedence signature."
        )
    elif has_success:
        outcome = "success"
        reason = "run_result.finishReason == 'completed' and no higher-precedence signature fired."
    else:
        outcome = "other"
        reason = (
            "None of the six named outcomes matched cleanly. Investigate "
            "the raw NDJSON stream directly."
        )

    return Outcome(
        outcome=outcome,
        signals=signals,
        reason=reason,
        finish_reason=finish_reason,
        tool_attempts=tool_attempts,
        denied_targets=denied_targets,
        malformed_lines=malformed_lines,
        cline_exit_code=cline_exit_code,
    )


_EXIT_CODES = {
    "success": 0,
    "sandbox_denied": 2,
    "tty_approval_rejected": 3,
    "run_aborted": 4,
    "context_overflow_terminal": 5,
    "other": 6,
    "crashed": 7,
}


def render_outcome_md(outcome_obj, timestamp=None):
    """Render a human-readable outcome.md body. No file I/O here."""
    if timestamp is None:
        timestamp = datetime.now(timezone.utc).isoformat()

    lines = []
    lines.append(f"# Run Outcome: {outcome_obj.outcome}")
    lines.append("")
    lines.append(f"**Generated:** {timestamp}")
    lines.append("")
    lines.append("## Meaning (한글 요약)")
    lines.append("")
    lines.append(_KOREAN_ONE_LINER.get(outcome_obj.outcome, outcome_obj.outcome))
    lines.append("")
    lines.append("## Verdict")
    lines.append("")
    lines.append(f"- **outcome:** `{outcome_obj.outcome}`")
    lines.append(f"- **reason:** {outcome_obj.reason}")
    lines.append(f"- **finish_reason:** `{outcome_obj.finish_reason}`")
    lines.append(f"- **cline_exit_code:** {outcome_obj.cline_exit_code}")
    lines.append(f"- **malformed_lines:** {outcome_obj.malformed_lines}")
    lines.append(f"- **signals:** {', '.join(outcome_obj.signals) if outcome_obj.signals else '(none)'}")
    lines.append("")
    lines.append("## Tool Attempts")
    lines.append("")
    if outcome_obj.tool_attempts:
        lines.append("| tool_name | query | success | error |")
        lines.append("|---|---|---|---|")
        for attempt in outcome_obj.tool_attempts:
            lines.append(
                f"| {attempt.get('tool_name')} | {attempt.get('query')} | "
                f"{attempt.get('success')} | {attempt.get('error')} |"
            )
    else:
        lines.append("(no tool call attempts in this stream)")
    lines.append("")
    lines.append("## Denied Targets")
    lines.append("")
    if outcome_obj.denied_targets:
        for target in outcome_obj.denied_targets:
            lines.append(f"- `{target}`")
    else:
        lines.append("(none)")
    lines.append("")

    return "\n".join(lines) + "\n"


def _build_arg_parser():
    parser = argparse.ArgumentParser(
        description="Phase 4 NDJSON outcome classifier -- six-way run classification."
    )
    parser.add_argument("--ndjson", required=True, help="Path to captured cline --json NDJSON stream")
    parser.add_argument("--exit-code", type=int, default=None, help="Wrapped cline process's exit code")
    parser.add_argument("--stderr", default=None, help="Path to a captured stderr file")
    parser.add_argument(
        "--allowed-prefix",
        action="append",
        default=None,
        help="Path prefix considered inside the sandbox allowlist (repeatable)",
    )
    parser.add_argument("--out", required=True, help="Output directory for outcome.json / outcome.md")
    return parser


def main(argv=None):
    parser = _build_arg_parser()
    args = parser.parse_args(argv)

    ndjson_path = Path(args.ndjson)
    if not ndjson_path.exists():
        print(f"error: --ndjson path does not exist: {ndjson_path}", file=sys.stderr)
        return 1

    lines = ndjson_path.read_text().splitlines()
    events = parse_ndjson(lines)

    stderr_text = ""
    if args.stderr:
        stderr_path = Path(args.stderr)
        if stderr_path.exists():
            stderr_text = stderr_path.read_text()

    outcome_obj = classify(
        events,
        cline_exit_code=args.exit_code,
        stderr_text=stderr_text,
        allowed_prefixes=args.allowed_prefix,
    )

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    outcome_json = {
        "outcome": outcome_obj.outcome,
        "signals": outcome_obj.signals,
        "reason": outcome_obj.reason,
        "finish_reason": outcome_obj.finish_reason,
        "tool_attempts": outcome_obj.tool_attempts,
        "denied_targets": outcome_obj.denied_targets,
        "malformed_lines": outcome_obj.malformed_lines,
        "cline_exit_code": outcome_obj.cline_exit_code,
    }
    (out_dir / "outcome.json").write_text(json.dumps(outcome_json, indent=2) + "\n")
    (out_dir / "outcome.md").write_text(render_outcome_md(outcome_obj))

    return _EXIT_CODES.get(outcome_obj.outcome, 6)


if __name__ == "__main__":
    sys.exit(main())
