#!/usr/bin/env python3
"""
Three-way compaction verdict classifier (VER-02 / VER-03).

Reads a captured Cline `--json` NDJSON stream plus a slice of
`~/llm-system/services/logs/flashnext.err` and decides, with evidence,
which of exactly three things happened:

  1. compaction_fired            - Cline's own auto-compaction notice fired
  2. server_400_no_compaction    - no compaction, server rejected at MAX_KV_SIZE
  3. other                       - below_trigger (inconclusive) or unexpected

VER-02: the verdict must rest on the API `usage` events and/or the server's
own `prompt_tokens` log lines - NEVER on Cline's own terminal UI percentage
indicator.

Stdlib only. No network calls. No model invocation. Pure `classify()` -
no file I/O, no clock - so tests can call it directly.
"""
import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

# The decompiled formula (see 01-RESEARCH.md):
#   effectiveMaxInputTokens = maxInputTokens ?? contextWindow * CONTEXT_WINDOW_INPUT_RATIO(0.9)
#   triggerTokens           = effectiveMaxInputTokens * COMPACTION_TRIGGER_RATIO(0.9)
# i.e. triggerTokens = contextWindow * 0.9 * 0.9
# 26542 is only the value AT contextWindow=32768. If a later branch lowers
# contextWindow (e.g. a max_tokens mitigation), the trigger moves too - callers
# MUST pass the derived trigger via --predicted-trigger rather than relying on
# this default; classify() never reads this constant directly except as its
# default parameter value.
PREDICTED_TRIGGER_TOKENS = 26542

# Server budget rule: prompt_tokens + max_tokens <= MAX_KV_SIZE (measured on
# the running mlx_vlm.server; see 01-RESEARCH.md and the verified facts).
MAX_KV_SIZE = 32768

_MALFORMED_MARKER = "_malformed_line"

_PROMPT_TOKENS_RE = re.compile(r"prompt_tokens=(\d+)")
_MAX_TOKENS_RE = re.compile(r"max_tokens=(\d+)")
_LOG_LINE_MARKERS = (
    "Generation queued:",
    "Prefill started:",
    "Prefill completed:",
    "Request completed:",
)

_DISAGREEMENT_THRESHOLD = 0.15

_KOREAN_ONE_LINER = {
    "compaction_fired": "압축이 예측된 임계값 근처에서 발동했다 (자동 압축 성공)",
    "server_400_no_compaction": (
        "압축이 발동하지 않았고 서버가 MAX_KV_SIZE 초과로 400 거부했다 "
        "(Cline은 이 오류에서 자동 복구하지 않는다)"
    ),
    "other": "미확정이거나 예상치 못한 결과 (below_trigger 또는 unexpected)",
}


@dataclass
class FlashnextLogResult:
    peak_prompt_tokens: Optional[int] = None
    peak_max_tokens: Optional[int] = None


@dataclass
class Verdict:
    outcome: str  # "compaction_fired" | "server_400_no_compaction" | "other"
    reason: str
    peak_input_tokens: Optional[int]
    peak_prompt_tokens: Optional[int]
    compaction_events: List[dict] = field(default_factory=list)
    server_error: Optional[str] = None
    evidence_source: str = "ndjson_usage"  # "ndjson_usage" | "flashnext_err" | "both"
    malformed_lines: int = 0


def parse_ndjson(lines):
    """Parse raw NDJSON text lines into event dicts.

    Tolerant of blank lines and a truncated trailing line (a killed run
    leaves a partial last line). Malformed lines are represented as
    sentinel dicts ({"type": "_malformed_line", ...}) rather than raising,
    so classify() can count them without a separate return channel.
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


def parse_flashnext_log(lines):
    """Extract peak prompt_tokens / max_tokens from a flashnext.err slice.

    Only considers 'Generation queued:', 'Prefill started:',
    'Prefill completed:', and 'Request completed:' lines - this is the
    server-side oracle, independent of anything Cline claims about itself.
    """
    peak_prompt = None
    peak_max = None
    for line in lines or []:
        if not any(marker in line for marker in _LOG_LINE_MARKERS):
            continue
        m = _PROMPT_TOKENS_RE.search(line)
        if m:
            val = int(m.group(1))
            if peak_prompt is None or val > peak_prompt:
                peak_prompt = val
        m2 = _MAX_TOKENS_RE.search(line)
        if m2:
            val2 = int(m2.group(1))
            if peak_max is None or val2 > peak_max:
                peak_max = val2
    return FlashnextLogResult(peak_prompt_tokens=peak_prompt, peak_max_tokens=peak_max)


def _is_status_notice(event):
    return (
        isinstance(event, dict)
        and event.get("type") == "agent_event"
        and isinstance(event.get("event"), dict)
        and event["event"].get("type") == "notice"
        and event["event"].get("noticeType") == "status"
    )


def _find_notice_by_message(notices, message):
    """First notice metadata dict whose `message` field equals `message`, or None."""
    return next((n for n in notices if n.get("message") == message), None)


def _is_server_context_error(message):
    """MAX_KV_SIZE OR 'context tokens' + a number - never generic 'error'."""
    if not message:
        return False
    if "MAX_KV_SIZE" in message:
        return True
    if re.search(r"context tokens", message, re.IGNORECASE) and re.search(
        r"\d+", message
    ):
        return True
    return False


def _error_event_message(event):
    """Extract the error text from an agent_event error, tolerant of two
    real, both-observed NDJSON shapes:

      - flat:   {"type": "error", "message": "..."}
                (the RESEARCH.md-predicted shape; still used by this repo's
                own hand-written fixtures)
      - nested: {"type": "error", "error": {"name": ..., "message": "..."}}
                (the ACTUAL shape emitted by cline 3.0.53 in a live run,
                confirmed 2026-08-29: the litellm.BadRequestError text -
                which DOES contain "MAX_KV_SIZE" - lives one level deeper,
                under event["error"]["message"], not event["message"].
                Without this fallback, classify() silently falls through to
                "other"/"unexpected" on every real MAX_KV_SIZE 400, which is
                exactly the outcome-② case this classifier exists to catch.
                See phase-01/results/<ts>/ndjson.log from Plan 06 run 2 for
                the raw evidence this was discovered from.)
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


def classify(ndjson_events, server_log_lines, predicted_trigger=PREDICTED_TRIGGER_TOKENS,
             max_kv=MAX_KV_SIZE):
    """Pure classification. No file I/O, no clock.

    `predicted_trigger` is a genuine caller-supplied parameter - it is NOT
    read from the module-level PREDICTED_TRIGGER_TOKENS constant inside this
    function body except as the default argument value. A caller that
    passes a different value (e.g. because contextWindow was lowered) gets
    that value honored end to end.
    """
    malformed_lines = sum(
        1 for e in ndjson_events if isinstance(e, dict) and e.get("type") == _MALFORMED_MARKER
    )
    real_events = [
        e for e in ndjson_events if isinstance(e, dict) and e.get("type") != _MALFORMED_MARKER
    ]

    usage_inputs = [
        e["event"]["inputTokens"]
        for e in real_events
        if e.get("type") == "agent_event"
        and isinstance(e.get("event"), dict)
        and e["event"].get("type") == "usage"
        and isinstance(e["event"].get("inputTokens"), (int, float))
    ]
    peak_input_tokens = max(usage_inputs) if usage_inputs else None

    log_result = parse_flashnext_log(server_log_lines)
    peak_prompt_tokens = log_result.peak_prompt_tokens

    auto_compact_events = [
        e["event"]
        for e in real_events
        if _is_status_notice(e) and str(e["event"].get("message", "")).startswith("auto-compact")
    ]
    overflow_recovery_events = [
        e["event"]
        for e in real_events
        if _is_status_notice(e)
        and str(e["event"].get("message", "")).startswith("overflow-recovery-compact")
    ]

    server_error_events = [
        e["event"]
        for e in real_events
        if e.get("type") == "agent_event"
        and isinstance(e.get("event"), dict)
        and e["event"].get("type") == "error"
        and _is_server_context_error(_error_event_message(e["event"]))
    ]

    run_result = None
    for e in real_events:
        if e.get("type") == "run_result":
            run_result = e
    finish_reason = run_result.get("finishReason") if run_result else None

    has_ndjson_usage = peak_input_tokens is not None
    has_server_log = peak_prompt_tokens is not None
    if has_ndjson_usage and has_server_log:
        evidence_source = "both"
    elif has_ndjson_usage:
        evidence_source = "ndjson_usage"
    elif has_server_log:
        evidence_source = "flashnext_err"
    else:
        evidence_source = "ndjson_usage"

    disagreement_note = ""
    if evidence_source == "both" and peak_input_tokens and peak_prompt_tokens:
        larger = max(peak_input_tokens, peak_prompt_tokens)
        diff_ratio = abs(peak_input_tokens - peak_prompt_tokens) / larger
        if diff_ratio > _DISAGREEMENT_THRESHOLD:
            disagreement_note = (
                f" WARNING: oracle disagreement - peak_input_tokens={peak_input_tokens} "
                f"vs peak_prompt_tokens={peak_prompt_tokens} differ by "
                f"{diff_ratio:.0%} (>{_DISAGREEMENT_THRESHOLD:.0%}); neither oracle wins silently."
            )

    missing_cross_check_note = ""
    if not has_server_log:
        missing_cross_check_note = (
            " (no server-side flashnext.err cross-check available for this run)"
        )

    server_error = None
    reason = ""
    outcome = "other"

    if auto_compact_events:
        outcome = "compaction_fired"
        started = _find_notice_by_message(auto_compact_events, "auto-compacting")
        trigger_tokens = None
        if started and isinstance(started.get("metadata"), dict):
            trigger_tokens = started["metadata"].get("triggerTokens")
        reason = (
            f"auto-compaction notice observed"
            + (f" at triggerTokens={trigger_tokens}" if trigger_tokens is not None else "")
            + "."
        )
    elif server_error_events:
        outcome = "server_400_no_compaction"
        server_error = _error_event_message(server_error_events[0])
        reason = (
            "No auto-compact* notice fired; the server rejected the request as a context "
            "overflow (MAX_KV_SIZE). Cline does not self-heal from this error - its "
            "overflow-recovery classifier's 8 regexes do not match this text, so the task "
            "simply dies and the user must start a new task."
        )
    else:
        if overflow_recovery_events:
            reason = (
                "unexpected: an overflow-recovery-compact* notice fired, meaning the "
                "recovery path activated - this contradicts the research prediction that "
                "Cline's classifier would not recognize this stack's 400 shape."
            )
        elif malformed_lines > 0 and run_result is None:
            reason = (
                "unexpected: the NDJSON stream ended abruptly (truncated/malformed trailing "
                "line, no run_result) - likely a crash or timeout mid-run."
            )
        elif (
            finish_reason == "completed"
            and peak_input_tokens is not None
            and peak_input_tokens < predicted_trigger
        ):
            reason = (
                f"below_trigger: the run finished (finishReason=completed) but never reached "
                f"the predicted trigger (peak_input_tokens={peak_input_tokens} < "
                f"predicted_trigger={predicted_trigger}). This is inconclusive, not a pass or "
                f"a failure of the phase - recommend increasing the filler file count and "
                f"rerunning to actually cross the threshold."
            )
        else:
            reason = (
                "unexpected: run did not match compaction_fired or server_400_no_compaction, "
                "and did not cleanly finish below the trigger either (timeout, crash, or a "
                "non-context error). Investigate the raw NDJSON stream."
            )

    reason = reason + disagreement_note + missing_cross_check_note

    return Verdict(
        outcome=outcome,
        reason=reason,
        peak_input_tokens=peak_input_tokens,
        peak_prompt_tokens=peak_prompt_tokens,
        compaction_events=auto_compact_events,
        server_error=server_error,
        evidence_source=evidence_source,
        malformed_lines=malformed_lines,
    )


_EXIT_CODES = {
    "compaction_fired": 0,
    "server_400_no_compaction": 2,
    "other": 3,
}


def render_verdict(verdict, predicted_trigger, max_kv, trigger_source, timestamp=None):
    """Render a human-readable verdict.md body. No file I/O here."""
    if timestamp is None:
        timestamp = datetime.now(timezone.utc).isoformat()

    lines = []
    lines.append(f"# Compaction Verdict: {verdict.outcome}")
    lines.append("")
    lines.append(f"**Generated:** {timestamp}")
    lines.append("")
    lines.append(f"## Meaning (한글 요약)")
    lines.append("")
    lines.append(_KOREAN_ONE_LINER.get(verdict.outcome, verdict.outcome))
    lines.append("")
    lines.append("## Verdict")
    lines.append("")
    lines.append(f"- **outcome:** `{verdict.outcome}`")
    lines.append(f"- **reason:** {verdict.reason}")
    lines.append(f"- **evidence_source:** `{verdict.evidence_source}`")
    lines.append(f"- **malformed_lines:** {verdict.malformed_lines}")
    lines.append("")
    lines.append("## Token Peaks")
    lines.append("")
    lines.append(f"- **peak_input_tokens** (per-iteration, from `--json` usage events): "
                  f"{verdict.peak_input_tokens}")
    lines.append(f"- **peak_prompt_tokens** (from `flashnext.err` server log): "
                  f"{verdict.peak_prompt_tokens}")
    lines.append("")
    lines.append("## Thresholds Used")
    lines.append("")
    lines.append(f"- **predicted_trigger:** {predicted_trigger} (source: {trigger_source})")
    lines.append(f"- **max_kv:** {max_kv}")
    lines.append("")
    lines.append("## Raw Evidence")
    lines.append("")
    if verdict.compaction_events:
        lines.append("### Compaction notice payload(s)")
        lines.append("")
        lines.append("```json")
        lines.append(json.dumps(verdict.compaction_events, indent=2))
        lines.append("```")
        lines.append("")
    if verdict.server_error:
        lines.append("### Server error payload")
        lines.append("")
        lines.append("```")
        lines.append(verdict.server_error)
        lines.append("```")
        lines.append("")
    if not verdict.compaction_events and not verdict.server_error:
        lines.append("(no compaction notice or server error payload captured for this run)")
        lines.append("")

    return "\n".join(lines) + "\n"


def _build_arg_parser():
    parser = argparse.ArgumentParser(
        description="Three-way compaction verdict classifier (VER-02 / VER-03)."
    )
    parser.add_argument("--ndjson", required=True, help="Path to captured cline --json NDJSON stream")
    parser.add_argument("--server-log", required=False, default=None,
                         help="Path to a flashnext.err slice bracketing the run")
    parser.add_argument("--predicted-trigger", type=int, default=None,
                         help=f"Trigger token threshold to compare against "
                              f"(default: {PREDICTED_TRIGGER_TOKENS}, the value at contextWindow=32768)")
    parser.add_argument("--max-kv", type=int, default=MAX_KV_SIZE,
                         help=f"Server MAX_KV_SIZE (default: {MAX_KV_SIZE})")
    parser.add_argument("--out", required=True, help="Output directory for verdict.md")
    return parser


def main(argv=None):
    parser = _build_arg_parser()
    args = parser.parse_args(argv)

    if args.predicted_trigger is not None:
        predicted_trigger = args.predicted_trigger
        trigger_source = "flag (--predicted-trigger)"
    else:
        predicted_trigger = PREDICTED_TRIGGER_TOKENS
        trigger_source = "default (PREDICTED_TRIGGER_TOKENS)"

    ndjson_path = Path(args.ndjson)
    ndjson_lines = ndjson_path.read_text().splitlines() if ndjson_path.exists() else []
    events = parse_ndjson(ndjson_lines)

    server_log_lines = []
    if args.server_log:
        log_path = Path(args.server_log)
        if log_path.exists():
            server_log_lines = log_path.read_text().splitlines()

    verdict = classify(
        events, server_log_lines, predicted_trigger=predicted_trigger, max_kv=args.max_kv
    )

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    verdict_md = render_verdict(verdict, predicted_trigger, args.max_kv, trigger_source)
    (out_dir / "verdict.md").write_text(verdict_md)

    return _EXIT_CODES.get(verdict.outcome, 3)


if __name__ == "__main__":
    sys.exit(main())
