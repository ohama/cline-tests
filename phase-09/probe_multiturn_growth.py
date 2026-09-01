#!/usr/bin/env python3
"""probe_multiturn_growth.py -- Phase 9 Plan 02, Task 2.

Runs two >=3-turn conversations at :8011 direct -- one with reasoning_effort
`xhigh` thinking on, reasoning fed back into every subsequent turn exactly the
way Cline's own code does (shouldIncludeReasoningHistory -> true for our
non-Cerebras provider; the field is re-serialized onto the wire as
`reasoning_content`), one with thinking off entirely -- and records the
per-turn `prompt_tokens` growth side by side. This is ROADMAP Phase 9 success
criterion 4, which 09-RESEARCH.md's single-shot replay probe did not cover,
and it produces REAL `xhigh` reasoning traces (not the ~1,380-char synthetic
one 09-RESEARCH.md used) for plan 09-03 to reuse.

`xhigh` (not `medium`) is used deliberately for the ON sequence: it is the
worst case, producing the longest traces, so if replayed reasoning costs
nothing at `xhigh` then `medium`'s cost is bounded above by that result.

This script does not reimplement preflight/postflight/flake_window/
record_verdict. It reuses the run directory Task 1 (probe_prb03_oracle.sh)
already created and preflight()-ed, and it sources probe_lib.sh via `bash -c`
for the four shared safety-envelope functions -- exactly the same functions,
not a Python reimplementation of their logic.

CONFOUND, stated up front and again in PRB-03-ORACLE.md: the ON and OFF
sequences necessarily produce different assistant reply text (different
content lengths), so their turn-2/turn-3 prompt sizes differ in both content
length AND reasoning presence. This multi-turn comparison is corroborating
evidence, not a controlled experiment -- the controlled single-shot replay
probe in plan 09-03 (identical messages, field present vs absent) is the
decisive measurement for the PRB-04 gate.

NOTE: this machine's litellm names the field `reasoning_content`, not
`reasoning` -- wave 1 (09-01-SUMMARY.md) hit a false-negative parser bug from
checking only `reasoning`. This script checks BOTH names on every response.
"""
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PHASE09_DIR = Path(__file__).resolve().parent
PROBE_LIB = PHASE09_DIR / "probe_lib.sh"  # source probe_lib.sh via bash -c below
CURRENT_RUN_PTR = REPO_ROOT / "phase-09" / "results" / "CURRENT_PRB03_RUN"

# Must match probe_lib.sh's MODEL / FLASHNEXT_LOG constants exactly -- this
# script cannot literally `source` a bash file into its own Python globals,
# so it sources probe_lib.sh via bash -c for its FUNCTIONS (preflight-family)
# and duplicates only these two path/string constants, which are read-only
# facts about the deployed stack, not behavior.
MODEL = "/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4"
FLASHNEXT_LOG = str(Path.home() / "llm-system" / "services" / "logs" / "flashnext.err")
URL_8011 = "http://localhost:8011/v1/chat/completions"

MAX_TOKENS = 300  # cap for every request this script fires (hard constraint)
ATTEMPT_MAX = 3

# Fixed 3-turn user script, identical for ON and OFF -- the only difference
# between the two sequences is thinking (xhigh + reasoning feedback vs none).
USER_SCRIPT = [
    "세 자리 수 중 각 자리 숫자의 합이 7인 가장 큰 수는?",
    "그 수에서 백의 자리와 일의 자리를 바꾸면 얼마나 줄어드나?",
    "왜 그런지 한 줄로 설명해줘",
]


def wc_l(path: str) -> int:
    """Line count via `wc -l` (same watermark technique as probe_prb03_oracle.sh's
    Task 1 -- NOT tail -N ordering inference)."""
    out = subprocess.check_output(["wc", "-l", path], text=True)
    return int(out.strip().split()[0])


def read_lines(path: str):
    with open(path, "r", errors="replace") as f:
        return f.readlines()


def wait_idle(max_attempts: int = 10) -> None:
    for attempt in range(max_attempts):
        lines = read_lines(FLASHNEXT_LOG)
        last_inflight = None
        for line in reversed(lines):
            if "in_flight=" in line:
                last_inflight = line
                break
        if last_inflight and "in_flight=0" in last_inflight:
            return
        time.sleep(1)
    raise RuntimeError(f"model not idle after {max_attempts} attempts (last: {last_inflight!r})")


def bash_lib(run_dir: str, log_watermark: int, func_call: str) -> subprocess.CompletedProcess:
    """Run one probe_lib.sh function via `source probe_lib.sh; <func_call>` in a
    fresh bash -c subprocess. Used for flake_window / record_verdict / postflight
    -- the shared safety-envelope functions this script must not reimplement."""
    script = f'set -euo pipefail; source "{PROBE_LIB}"; export LOG_WATERMARK={log_watermark}; {func_call}'
    return subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )


def call_flake_window(run_dir: str, log_watermark: int) -> str:
    p = bash_lib(run_dir, log_watermark, f'flake_window "{run_dir}"')
    if p.returncode != 0:
        sys.stderr.write(f"WARNING: flake_window non-zero exit: {p.stderr}\n")
    return p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "DIRTY"


def call_record_verdict(run_dir: str, log_watermark: int, label: str, result: str, flake_state: str) -> str:
    p = bash_lib(run_dir, log_watermark, f'record_verdict "{run_dir}" "{label}" "{result}" "{flake_state}"')
    if p.returncode != 0:
        sys.stderr.write(f"WARNING: record_verdict non-zero exit for {label}: {p.stderr}\n")
    return p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "UNKNOWN"


def call_postflight(run_dir: str, log_watermark: int):
    p = bash_lib(run_dir, log_watermark, f'postflight "{run_dir}"')
    return p.returncode, p.stdout, p.stderr


def call_model(messages, reasoning_effort):
    body = {"model": MODEL, "messages": messages, "max_tokens": MAX_TOKENS}
    if reasoning_effort:
        body["reasoning_effort"] = reasoning_effort
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        URL_8011, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            code = resp.getcode()
            raw = resp.read()
    except urllib.error.HTTPError as e:
        code = e.code
        raw = e.read()
    return code, raw


def extract_reasoning(msg: dict) -> str:
    # Check BOTH field names -- litellm/this model server use `reasoning_content`
    # (wave 1's false-negative bug came from checking only `reasoning`).
    return msg.get("reasoning_content") or msg.get("reasoning") or ""


def run_turn(run_dir, log_watermark, seq_label, turn_no, messages, reasoning_effort, prev_prompt_tokens):
    """Fires one turn, attributes it by watermark (bounded 3 attempts on 0 or
    >=2 'Prefill started' matches in the appended-lines window), records a
    flake_window + record_verdict pair, and returns
    (http_code, prompt_tokens, matched_line, content, reasoning)."""
    msgs_file = run_dir / f"msgs-{seq_label}-t{turn_no}.json"
    msgs_file.write_text(json.dumps(messages, ensure_ascii=False, indent=2))

    raw_file = run_dir / f"raw-multiturn-{seq_label}-t{turn_no}.json"

    http_code = None
    matched_line = None
    prompt_tokens = None
    content = ""
    reasoning = ""
    match_count = 0
    ok = False

    for attempt in range(1, ATTEMPT_MAX + 1):
        wait_idle()
        mark = wc_l(FLASHNEXT_LOG)
        http_code, raw = call_model(messages, reasoning_effort)
        raw_file.write_bytes(raw)
        time.sleep(0.3)  # let the async server-side log write for this request land

        new_lines = read_lines(FLASHNEXT_LOG)[mark:]
        prefill_matches = [l for l in new_lines if "Prefill started" in l]
        match_count = len(prefill_matches)

        if http_code == 200 and match_count == 1:
            matched_line = prefill_matches[0].rstrip("\n")
            m = re.search(r"prompt_tokens=(\d+)", matched_line)
            prompt_tokens = int(m.group(1)) if m else None
            try:
                data = json.loads(raw.decode("utf-8"))
                msg = data["choices"][0]["message"]
                content = msg.get("content") or ""
                reasoning = extract_reasoning(msg)
            except Exception as e:
                sys.stderr.write(f"  [{seq_label} t{turn_no}] WARNING: response body did not parse: {e}\n")
            if prompt_tokens is not None:
                ok = True
                break

        if match_count == 0:
            sys.stderr.write(
                f"  [{seq_label} t{turn_no}] attempt {attempt}: http={http_code}, "
                f"0 Prefill-started lines in window -- retrying\n"
            )
        elif match_count >= 2:
            sys.stderr.write(
                f"  [{seq_label} t{turn_no}] attempt {attempt}: http={http_code}, "
                f"{match_count} Prefill-started lines in window -- another tenant's request "
                f"landed here, attribution ambiguous, discarding and retrying\n"
            )
        else:
            sys.stderr.write(f"  [{seq_label} t{turn_no}] attempt {attempt}: http={http_code} -- retrying\n")
        time.sleep(1)

    flake_state = call_flake_window(str(run_dir), log_watermark)
    label = f"multiturn-{seq_label}-t{turn_no}"
    verdict = call_record_verdict(str(run_dir), log_watermark, label, "expected" if ok else "indeterminate", flake_state)

    growth = "NA" if prev_prompt_tokens is None or prompt_tokens is None else prompt_tokens - prev_prompt_tokens
    print(
        f"  [{seq_label} t{turn_no}] http={http_code} prompt_tokens={prompt_tokens} growth={growth} "
        f"content_chars={len(content)} reasoning_chars={len(reasoning)} verdict={verdict} (attempts={attempt})",
        file=sys.stderr,
    )
    time.sleep(1)  # ~1s apart, strictly sequential

    return http_code, prompt_tokens, matched_line, content, reasoning


def run_sequence(run_dir, log_watermark, seq_label, reasoning_effort, tsv_rows, realtrace_rows):
    messages = []
    prev_pt = None
    for i, user_text in enumerate(USER_SCRIPT, start=1):
        messages.append({"role": "user", "content": user_text})
        http_code, prompt_tokens, matched_line, content, reasoning = run_turn(
            run_dir, log_watermark, seq_label, i, messages, reasoning_effort, prev_pt
        )
        growth = "NA" if prev_pt is None or prompt_tokens is None else prompt_tokens - prev_pt
        tsv_rows.append(
            (seq_label, i, http_code, prompt_tokens, growth, len(content), len(reasoning), matched_line or "")
        )

        if seq_label == "ON":
            trace_len = len(reasoning)
            if trace_len > 0:
                trace_file = run_dir / f"realtrace-t{i}.txt"
                trace_file.write_text(reasoning)
                realtrace_rows.append((i, trace_len, "captured"))
            else:
                realtrace_rows.append((i, 0, "empty"))

        assistant_msg = {"role": "assistant", "content": content}
        if seq_label == "ON":
            # Mirrors Cline's outbound serialization: reasoning is re-emitted as
            # `reasoning_content` on the persisted assistant message, attached on
            # every turn regardless of whether this particular turn's trace came
            # back non-empty (recorded, not smoothed over, if it didn't).
            assistant_msg["reasoning_content"] = reasoning
        messages.append(assistant_msg)

        prev_pt = prompt_tokens if prompt_tokens is not None else prev_pt


def main():
    if not CURRENT_RUN_PTR.exists():
        sys.exit(f"FATAL: {CURRENT_RUN_PTR} not found -- run probe_prb03_oracle.sh (Task 1) first")
    run_dir = REPO_ROOT / CURRENT_RUN_PTR.read_text().strip()
    if not run_dir.is_dir():
        sys.exit(f"FATAL: run dir '{run_dir}' does not exist")
    print(f"Reusing run dir: {run_dir}", file=sys.stderr)

    preflight_txt = run_dir / "preflight.txt"
    if not preflight_txt.exists():
        sys.exit(f"FATAL: {preflight_txt} missing -- Task 1's preflight() must have run in this dir")
    log_watermark = None
    for line in preflight_txt.read_text().splitlines():
        if line.startswith("LOG_WATERMARK="):
            log_watermark = int(line.split("=", 1)[1])
            break
    if log_watermark is None:
        sys.exit(f"FATAL: LOG_WATERMARK not found in {preflight_txt}")
    print(f"Reusing LOG_WATERMARK={log_watermark} from Task 1's preflight (whole-burst flake window)", file=sys.stderr)

    print("=== confirming in_flight=0 before the phase's largest burst (6 requests, max_tokens<=300 each) ===", file=sys.stderr)
    wait_idle()

    tsv_rows = []
    realtrace_rows = []

    print("=== Sequence ON: xhigh, reasoning fed back each turn ===", file=sys.stderr)
    run_sequence(run_dir, log_watermark, "ON", "xhigh", tsv_rows, realtrace_rows)

    print("=== Sequence OFF: no reasoning_effort, no reasoning fed back ===", file=sys.stderr)
    run_sequence(run_dir, log_watermark, "OFF", None, tsv_rows, realtrace_rows)

    multiturn_tsv = run_dir / "multiturn.tsv"
    with open(multiturn_tsv, "w") as f:
        f.write("sequence\tturn\thttp_code\tprompt_tokens\tgrowth\tcontent_chars\treasoning_chars\tmatched_line\n")
        for row in tsv_rows:
            f.write("\t".join(str(x) for x in row) + "\n")

    realtrace_tsv = run_dir / "realtrace-capture.tsv"
    with open(realtrace_tsv, "w") as f:
        f.write("turn\ttrace_chars\tstatus\n")
        for row in realtrace_rows:
            f.write("\t".join(str(x) for x in row) + "\n")

    total_trace_chars = sum(r[1] for r in realtrace_rows)
    print(f"Total ON-sequence real reasoning trace characters captured: {total_trace_chars}", file=sys.stderr)
    if total_trace_chars == 0:
        print(
            "NOTE: no non-empty real trace was captured this run. This is recorded, not "
            "papered over -- plan 09-03's real-trace comparison must be reported as "
            "INDETERMINATE rather than substituting synthetic text.",
            file=sys.stderr,
        )

    print("=== postflight (this ends the run) ===", file=sys.stderr)
    rc, out, err = call_postflight(str(run_dir), log_watermark)
    sys.stdout.write(out)
    sys.stderr.write(err)
    if rc != 0:
        sys.exit(f"FATAL: postflight failed (exit {rc}) -- stack-unchanged constraint violated, see {run_dir}/postflight.txt")

    print(f"=== Task 2 done. See {multiturn_tsv}, {realtrace_tsv}, {run_dir}/verdicts.tsv, {run_dir}/postflight.txt ===", file=sys.stderr)


if __name__ == "__main__":
    main()
