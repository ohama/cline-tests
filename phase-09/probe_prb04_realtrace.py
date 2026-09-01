#!/usr/bin/env python3
"""probe_prb04_realtrace.py -- Phase 9 Plan 03, Task 2.

09-RESEARCH.md Open Risk #3: the zero-cost replay finding (probe_prb04_replay.py,
Task 1) used a ~1,380-char SYNTHETIC `FAKE_REASONING` string. This script closes
that gap using the REAL `xhigh` reasoning traces plan 09-02 already captured as a
by-product of its multi-turn sequences (phase-09/results/<PRB03 run>/realtrace-
t{1,2,3}.txt, 591/917/989 chars, 2,497 total) -- generating no new model load to
get real traces.

Two replay traces are built from those files, never padded/repeated/fabricated:
  LONGEST -- the single longest captured real trace (t3, 989 chars)
  CONCAT  -- all three captured real traces concatenated (2,497 chars) -- this
             is the length-threshold probe: still real model output, just longer.

Both are compared against the 1,380-char synthetic trace Task 1 used: CONCAT is
longer (2,497 > 1,380), LONGEST alone is not (989 < 1,380) -- both facts are
recorded, not just the favorable one.

Replay stage: for each of {LONGEST, CONCAT} x {:8011, :4000 (flashnext)}, using
field name `reasoning_content` and max_tokens: 4 -- 4 with-field requests plus 2
no-field baselines (one per endpoint) = 6 requests, sequential, ~1s apart,
watermarked exactly like Task 1.

Reuses phase-09/results/CURRENT_PRB04_RUN (Task 1's run directory) rather than
creating a new one, and sources probe_lib.sh via `bash -c` for
flake_window/record_verdict/postflight -- no reimplementation.
"""
import glob
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
PROBE_LIB = PHASE09_DIR / "probe_lib.sh"
CURRENT_PRB04_RUN_PTR = REPO_ROOT / "phase-09" / "results" / "CURRENT_PRB04_RUN"
CURRENT_PRB03_RUN_PTR = REPO_ROOT / "phase-09" / "results" / "CURRENT_PRB03_RUN"

MODEL = "/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4"
FLASHNEXT_LOG = str(Path.home() / "llm-system" / "services" / "logs" / "flashnext.err")
URL_8011 = "http://localhost:8011/v1/chat/completions"
URL_4000 = "http://localhost:4000/v1/chat/completions"

MAX_TOKENS = 4
ATTEMPT_MAX = 3
ATTR_RETRY_MAX = 3

SYNTHETIC_TRACE_CHARS = 1380  # Task 1's FAKE_REASONING length, for the comparison this task requires

BASE_MESSAGES = [
    {"role": "user", "content": "What is the capital of France?"},
    {"role": "assistant", "content": "The capital of France is Paris."},
    {"role": "user", "content": "And what is its population?"},
]

ENDPOINTS = [
    ("8011", URL_8011, MODEL, False),
    ("4000", URL_4000, "flashnext", True),
]


def wc_l(path: str) -> int:
    out = subprocess.check_output(["wc", "-l", path], text=True)
    return int(out.strip().split()[0])


def read_lines(path: str):
    with open(path, "r", errors="replace") as f:
        return f.readlines()


def wait_idle(max_attempts: int = 10) -> None:
    last_inflight = None
    for _ in range(max_attempts):
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


def bash_lib(log_watermark: int, func_call: str) -> subprocess.CompletedProcess:
    script = f'set -euo pipefail; source "{PROBE_LIB}"; export LOG_WATERMARK={log_watermark}; {func_call}'
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, cwd=str(REPO_ROOT))


def call_preflight_reuse(run_dir: str) -> int:
    """Task 2 reuses Task 1's run dir and re-runs preflight (this is a separate
    process; LOG_WATERMARK does not carry over) -- same pattern as
    probe_prb02.sh reusing probe_prb01.sh's run dir in plan 09-01."""
    p = bash_lib(0, f'preflight "{run_dir}"; echo "LOG_WATERMARK_OUT=$LOG_WATERMARK"')
    sys.stdout.write(p.stdout)
    sys.stderr.write(p.stderr)
    if p.returncode != 0:
        sys.exit(f"FATAL: preflight failed (exit {p.returncode})")
    for line in p.stdout.splitlines():
        if line.startswith("LOG_WATERMARK_OUT="):
            return int(line.split("=", 1)[1])
    sys.exit("FATAL: preflight did not report LOG_WATERMARK_OUT")


def call_flake_window(run_dir: str, log_watermark: int) -> str:
    p = bash_lib(log_watermark, f'flake_window "{run_dir}"')
    if p.returncode != 0:
        sys.stderr.write(f"WARNING: flake_window non-zero exit: {p.stderr}\n")
    return p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "DIRTY"


def call_record_verdict(run_dir: str, log_watermark: int, label: str, result: str, flake_state: str = "") -> str:
    p = bash_lib(log_watermark, f'record_verdict "{run_dir}" "{label}" "{result}" "{flake_state}"')
    if p.returncode != 0:
        sys.stderr.write(f"WARNING: record_verdict non-zero exit for {label}: {p.stderr}\n")
    return p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "UNKNOWN"


def call_postflight(run_dir: str, log_watermark: int):
    p = bash_lib(log_watermark, f'postflight "{run_dir}"')
    return p.returncode, p.stdout, p.stderr


def build_messages(reasoning_text):
    msgs = json.loads(json.dumps(BASE_MESSAGES))
    if reasoning_text is not None:
        msgs[1]["reasoning_content"] = reasoning_text
    return msgs


def call_model(url, model, messages, auth):
    body = {"model": model, "messages": messages, "max_tokens": MAX_TOKENS}
    headers = {"Content-Type": "application/json"}
    if auth:
        headers["Authorization"] = "Bearer dummy"
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.getcode(), resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def fire_and_attribute(tag, url, model, messages, auth):
    for attempt in range(1, ATTR_RETRY_MAX + 1):
        wait_idle()
        mark = wc_l(FLASHNEXT_LOG)
        http_code, raw = call_model(url, model, messages, auth)
        time.sleep(0.3)

        if http_code != 200:
            return http_code, None, raw, attempt

        new_lines = read_lines(FLASHNEXT_LOG)[mark:]
        prefill_matches = [l for l in new_lines if "Prefill started" in l]
        if len(prefill_matches) == 1:
            m = re.search(r"prompt_tokens=(\d+)", prefill_matches[0])
            prompt_tokens = int(m.group(1)) if m else None
            if prompt_tokens is not None:
                return http_code, prompt_tokens, raw, attempt
        sys.stderr.write(
            f"  [{tag}] attribution ambiguous ({len(prefill_matches)} matches), "
            f"attempt {attempt}/{ATTR_RETRY_MAX} -- retrying\n"
        )
        time.sleep(1)
    return http_code, None, raw, ATTR_RETRY_MAX


def label_is_terminal(run_dir: Path, label: str) -> bool:
    tsv = run_dir / "verdicts.tsv"
    if not tsv.exists():
        return False
    last_verdict = None
    for line in tsv.read_text().splitlines():
        cols = line.split("\t")
        if len(cols) >= 5 and cols[1] == label:
            last_verdict = cols[4]
    return last_verdict in ("CONFIRMED", "CONFIRMED-NEGATIVE")


def load_real_traces(run_dir: Path):
    """Load stage -- NO model calls. Reads 09-02's captured real xhigh traces.
    Never pads/repeats/fabricates; if none exist, returns (None, None, [])."""
    if not CURRENT_PRB03_RUN_PTR.exists():
        return None, None, []
    prb03_run = REPO_ROOT / CURRENT_PRB03_RUN_PTR.read_text().strip()
    trace_files = sorted(glob.glob(str(prb03_run / "realtrace-t*.txt")))
    traces = []
    for tf in trace_files:
        text = Path(tf).read_text(encoding="utf-8")
        if text:  # only usable (non-empty) traces count
            traces.append((tf, text))
    if not traces:
        return None, None, []

    longest_file, longest_text = max(traces, key=lambda pair: len(pair[1]))
    concat_text = "".join(t for _, t in traces)
    concat_files = ",".join(Path(f).name for f, _ in traces)
    return (longest_file, longest_text), (concat_files, concat_text), traces


def main():
    if not CURRENT_PRB04_RUN_PTR.exists():
        sys.exit(f"FATAL: {CURRENT_PRB04_RUN_PTR} not found -- run probe_prb04_replay.py (Task 1) first")
    run_dir = REPO_ROOT / CURRENT_PRB04_RUN_PTR.read_text().strip()
    if not run_dir.is_dir():
        sys.exit(f"FATAL: run dir '{run_dir}' does not exist")
    print(f"Reusing run dir: {run_dir}", file=sys.stderr)

    realtrace_tsv = run_dir / "prb04-realtrace.tsv"

    longest, concat, all_traces = load_real_traces(run_dir)
    if longest is None:
        # No usable real trace -- record INDETERMINATE with reason, do not
        # fabricate/substitute synthetic text while labelling it real.
        with open(realtrace_tsv, "w") as f:
            f.write("trace_label\tsource_file\tchar_length\tendpoint\thttp_code\tprompt_tokens\tdelta\n")
            f.write(
                "INDETERMINATE\tNONE\t0\tNONE\tNA\tNA\tNA\t"
                "reason=no usable (non-empty) real xhigh trace found under "
                f"{CURRENT_PRB03_RUN_PTR} -- 09-02 did not capture one; "
                "length-threshold question is only partly answered by the synthetic-trace result in Task 1\n"
            )
        print(
            "No usable real trace found -- prb04-realtrace.tsv records an explicit INDETERMINATE. "
            "No model calls made in this script.",
            file=sys.stderr,
        )
        return

    longest_file, longest_text = longest
    concat_files, concat_text = concat
    longest_len = len(longest_text)
    concat_len = len(concat_text)

    print(f"LONGEST: {longest_file} ({longest_len} chars)", file=sys.stderr)
    print(f"CONCAT: {concat_files} ({concat_len} chars, {len(all_traces)} traces)", file=sys.stderr)
    print(
        f"Comparison vs Task 1's {SYNTHETIC_TRACE_CHARS}-char synthetic trace: "
        f"LONGEST {'>' if longest_len > SYNTHETIC_TRACE_CHARS else '<='} synthetic "
        f"({longest_len} vs {SYNTHETIC_TRACE_CHARS}); "
        f"CONCAT {'>' if concat_len > SYNTHETIC_TRACE_CHARS else '<='} synthetic "
        f"({concat_len} vs {SYNTHETIC_TRACE_CHARS})",
        file=sys.stderr,
    )

    log_watermark = call_preflight_reuse(str(run_dir))
    print(f"LOG_WATERMARK={log_watermark}", file=sys.stderr)

    print("=== confirming in_flight=0 before this task's 6-request burst ===", file=sys.stderr)
    wait_idle()

    trace_variants = [("LONGEST", longest_file, longest_text), ("CONCAT", concat_files, concat_text)]

    with open(realtrace_tsv, "w") as f:
        f.write("trace_label\tsource_file\tchar_length\tendpoint\thttp_code\tprompt_tokens\tdelta\n")

    labels = [f"prb04-real-{trace_label}-{ep}" for trace_label, _, _ in trace_variants for ep, _, _, _ in ENDPOINTS]

    round_no = 0
    round_watermark = log_watermark
    while round_no < ATTEMPT_MAX:
        round_no += 1
        print(f"=== Round {round_no}/{ATTEMPT_MAX} (2 baselines + 4 with-field = 6 requests) ===", file=sys.stderr)
        round_watermark = wc_l(FLASHNEXT_LOG)

        baseline_readings = {}
        for endpoint_label, url, model_name, auth in ENDPOINTS:
            messages = build_messages(None)
            tag = f"baseline-{endpoint_label}"
            http_code, prompt_tokens, raw, attempts = fire_and_attribute(tag, url, model_name, messages, auth)
            raw_file = run_dir / f"raw-prb04-real-{round_no}-{endpoint_label}-none.json"
            raw_file.write_bytes(raw)
            baseline_readings[endpoint_label] = (http_code, prompt_tokens)
            print(f"  [{tag}] http={http_code} prompt_tokens={prompt_tokens} (attempts={attempts})", file=sys.stderr)
            time.sleep(1)

        field_readings = {}
        for trace_label, source_file, trace_text in trace_variants:
            for endpoint_label, url, model_name, auth in ENDPOINTS:
                messages = build_messages(trace_text)
                tag = f"{trace_label}-{endpoint_label}"
                http_code, prompt_tokens, raw, attempts = fire_and_attribute(tag, url, model_name, messages, auth)
                raw_file = run_dir / f"raw-prb04-real-{round_no}-{endpoint_label}-{trace_label}.json"
                raw_file.write_bytes(raw)
                field_readings[(trace_label, endpoint_label)] = (http_code, prompt_tokens)
                print(f"  [{tag}] http={http_code} prompt_tokens={prompt_tokens} (attempts={attempts})", file=sys.stderr)
                time.sleep(1)

        flake_state = call_flake_window(str(run_dir), round_watermark)
        print(f"  round {round_no} flake_state={flake_state}", file=sys.stderr)

        with open(realtrace_tsv, "a") as f:
            for trace_label, source_file, trace_text in trace_variants:
                trace_len = len(trace_text)
                for endpoint_label, url, model_name, auth in ENDPOINTS:
                    base_code, base_pt = baseline_readings[endpoint_label]
                    code, pt = field_readings[(trace_label, endpoint_label)]
                    if base_pt is None or pt is None:
                        delta = "NA"
                    else:
                        delta = pt - base_pt
                    f.write(
                        f"{trace_label}\t{source_file}\t{trace_len}\t{endpoint_label}\t{code}\t"
                        f"{pt if pt is not None else 'NA'}\t{delta}\n"
                    )

                    label = f"prb04-real-{trace_label}-{endpoint_label}"
                    if delta == "NA":
                        verdict = call_record_verdict(str(run_dir), round_watermark, label, "indeterminate")
                    else:
                        result = "expected" if delta == 0 else "unexpected"
                        verdict = call_record_verdict(str(run_dir), round_watermark, label, result, flake_state)
                    print(f"    verdict[{label}] round={round_no} delta={delta} -> {verdict}", file=sys.stderr)

        if all(label_is_terminal(run_dir, l) for l in labels):
            print(f"All {len(labels)} labels reached a terminal verdict after round {round_no}.", file=sys.stderr)
            break

    for label in labels:
        if not label_is_terminal(run_dir, label):
            verdict = call_record_verdict(str(run_dir), round_watermark, label, "indeterminate")
            print(
                f"  {label}: retries exhausted ({ATTEMPT_MAX} rounds) without reproduced CLEAN result -> {verdict}",
                file=sys.stderr,
            )

    print("=== flake_window (final) + postflight ===", file=sys.stderr)
    final_flake = call_flake_window(str(run_dir), log_watermark)
    print(f"whole-task flake_state (from Task 2's own preflight watermark)={final_flake}", file=sys.stderr)
    rc, out, err = call_postflight(str(run_dir), log_watermark)
    sys.stdout.write(out)
    sys.stderr.write(err)
    if rc != 0:
        sys.exit(f"FATAL: postflight failed (exit {rc}) -- stack-unchanged constraint violated, see {run_dir}/postflight.txt")

    print(f"=== Task 2 done. See {realtrace_tsv}, {run_dir}/verdicts.tsv, {run_dir}/postflight.txt ===", file=sys.stderr)


if __name__ == "__main__":
    main()
