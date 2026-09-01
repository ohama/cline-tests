#!/usr/bin/env python3
"""probe_prb04_replay.py -- Phase 9 Plan 03, Task 1.

Re-runs 09-RESEARCH.md's literal PRB-04 replay probe (Q1) from scratch, as its
own independent measurement rather than trusting the research's single run.
Question: does attaching a historical assistant message's replayed reasoning
(`reasoning_content` or `reasoning`) cost extra `prompt_tokens` on the next
turn, through the FULL unmodified stack (:8011 direct, and :4000 through the
existing, unmodified `flashnext` litellm alias)?

FAKE_REASONING and the base 3-message conversation are copied verbatim from
09-RESEARCH.md sec Q1 -- this plan does not re-derive the method, it re-runs
it and adds a second field name (`reasoning`, which is the name our model
server actually emits, per wave 1/2's field-name lesson) that the research
only reasoned about but did not literally send as a nested message key.

ANTI-FLAKE DESIGN (see probe_lib.sh header comment for the four-state rule):
the *expected* result here is delta == 0 (replay is free). A delta != 0 is the
*unexpected*, milestone-relevant result and must not be trusted from a single
observation. Each 6-request round (baseline + reasoning_content + reasoning,
at both endpoints) is one "attempt". Two rounds are mandatory regardless of
outcome ("no single reading carries a gate"). If, after 2 rounds, any
(endpoint, field) label has not reached a terminal verdict (CONFIRMED or
CONFIRMED-NEGATIVE) in probe_lib.sh's four-state machine, a 3rd round is run.
If still unresolved after 3 rounds, that label is recorded INDETERMINATE --
a legitimate outcome, not a gate failure.

This script does not reimplement preflight/postflight/flake_window/
record_verdict; it sources probe_lib.sh via `bash -c` subprocesses for those,
exactly as phase-09/probe_multiturn_growth.py already established.
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
PROBE_LIB = PHASE09_DIR / "probe_lib.sh"
CURRENT_RUN_PTR = REPO_ROOT / "phase-09" / "results" / "CURRENT_PRB04_RUN"

# Duplicated read-only stack facts (cannot literally `source` bash into
# Python) -- must match probe_lib.sh's own MODEL / FLASHNEXT_LOG constants.
MODEL = "/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4"
FLASHNEXT_LOG = str(Path.home() / "llm-system" / "services" / "logs" / "flashnext.err")
URL_8011 = "http://localhost:8011/v1/chat/completions"
URL_4000 = "http://localhost:4000/v1/chat/completions"

MAX_TOKENS = 4
ATTEMPT_MAX = 3           # rounds of the full 6-request matrix (anti-flake loop)
ATTR_RETRY_MAX = 3        # per-request local retry on Prefill-line attribution ambiguity

# 09-RESEARCH.md sec Q1, verbatim.
FAKE_REASONING = "This is a long fake internal reasoning trace. " * 30  # ~1,380 chars
TRACE_LEN = len(FAKE_REASONING)

BASE_MESSAGES = [
    {"role": "user", "content": "What is the capital of France?"},
    {"role": "assistant", "content": "The capital of France is Paris."},
    {"role": "user", "content": "And what is its population?"},
]

ENDPOINTS = [
    ("8011", URL_8011, MODEL, False),
    ("4000", URL_4000, "flashnext", True),
]

FIELDS = [None, "reasoning_content", "reasoning"]


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


def call_new_run_dir(tag: str) -> str:
    p = bash_lib(0, f'new_run_dir "{tag}"')
    if p.returncode != 0:
        sys.exit(f"FATAL: new_run_dir failed: {p.stderr}")
    return p.stdout.strip().splitlines()[-1]


def call_preflight(run_dir: str):
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


def build_messages(field):
    msgs = json.loads(json.dumps(BASE_MESSAGES))  # deep copy
    if field:
        msgs[1][field] = FAKE_REASONING
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


def fire_and_attribute(endpoint_label, url, model, messages, auth):
    """Fires one request, attributes it to a 'Prefill started' log line by
    watermark (retrying up to ATTR_RETRY_MAX times only on attribution
    ambiguity -- 0 or >=2 matches -- not on non-200, which is recorded
    verbatim per the plan's instruction, not swallowed/retried)."""
    for attempt in range(1, ATTR_RETRY_MAX + 1):
        wait_idle()
        mark = wc_l(FLASHNEXT_LOG)
        http_code, raw = call_model(url, model, messages, auth)
        time.sleep(0.3)  # let the server-side log line land

        if http_code != 200:
            return http_code, None, None, raw, attempt

        new_lines = read_lines(FLASHNEXT_LOG)[mark:]
        prefill_matches = [l for l in new_lines if "Prefill started" in l]
        if len(prefill_matches) == 1:
            matched_line = prefill_matches[0].rstrip("\n")
            m = re.search(r"prompt_tokens=(\d+)", matched_line)
            prompt_tokens = int(m.group(1)) if m else None
            if prompt_tokens is not None:
                return http_code, prompt_tokens, matched_line, raw, attempt
        sys.stderr.write(
            f"  [{endpoint_label}] attribution ambiguous "
            f"({len(prefill_matches)} Prefill-started lines), attempt {attempt}/{ATTR_RETRY_MAX} -- retrying\n"
        )
        time.sleep(1)
    # Exhausted attribution retries -- record as-is (last observed http_code, no prompt_tokens).
    return http_code, None, None, raw, ATTR_RETRY_MAX


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


def main():
    run_dir_rel = call_new_run_dir("prb04")
    run_dir = REPO_ROOT / run_dir_rel
    CURRENT_RUN_PTR.write_text(run_dir_rel + "\n")
    print(f"Run directory: {run_dir}", file=sys.stderr)

    log_watermark = call_preflight(str(run_dir))
    print(f"LOG_WATERMARK={log_watermark}", file=sys.stderr)

    tsv_path = run_dir / "prb04-synthetic.tsv"
    with open(tsv_path, "w") as f:
        f.write("repeat\tendpoint\tfield\ttrace_chars\thttp_code\tprompt_tokens\tdelta\n")

    labels = [f"prb04-synth-{ep}-{fld}" for ep, _, _, _ in ENDPOINTS for fld in ("reasoning_content", "reasoning")]

    round_no = 0
    while round_no < ATTEMPT_MAX:
        round_no += 1
        print(f"=== Round {round_no}/{ATTEMPT_MAX} (6 requests: baseline + 2 fields x 2 endpoints) ===", file=sys.stderr)
        round_watermark = wc_l(FLASHNEXT_LOG)

        round_readings = {}  # (endpoint_label, field_or_None) -> (http_code, prompt_tokens)
        for endpoint_label, url, model_name, auth in ENDPOINTS:
            for field in FIELDS:
                messages = build_messages(field)
                http_code, prompt_tokens, matched_line, raw, attr_attempts = fire_and_attribute(
                    endpoint_label, url, model_name, messages, auth
                )
                field_tag = field or "none"
                raw_file = run_dir / f"raw-prb04-{round_no}-{endpoint_label}-{field_tag}.json"
                raw_file.write_bytes(raw)
                round_readings[(endpoint_label, field)] = (http_code, prompt_tokens)
                print(
                    f"  [{endpoint_label} field={field_tag}] http={http_code} prompt_tokens={prompt_tokens} "
                    f"(attr_attempts={attr_attempts})",
                    file=sys.stderr,
                )
                time.sleep(1)  # strictly sequential, ~1s apart

        flake_state = call_flake_window(str(run_dir), round_watermark)
        print(f"  round {round_no} flake_state={flake_state}", file=sys.stderr)

        with open(tsv_path, "a") as f:
            for endpoint_label, url, model_name, auth in ENDPOINTS:
                base_code, base_pt = round_readings[(endpoint_label, None)]
                # baseline row itself: trivial self-delta = 0 (every row gets an integer delta)
                f.write(f"{round_no}\t{endpoint_label}\tnone\t0\t{base_code}\t{base_pt if base_pt is not None else 'NA'}\t0\n")
                for field in ("reasoning_content", "reasoning"):
                    code, pt = round_readings[(endpoint_label, field)]
                    if base_pt is None or pt is None:
                        delta = "NA"
                    else:
                        delta = pt - base_pt
                    f.write(f"{round_no}\t{endpoint_label}\t{field}\t{TRACE_LEN}\t{code}\t{pt if pt is not None else 'NA'}\t{delta}\n")

                    label = f"prb04-synth-{endpoint_label}-{field}"
                    if delta == "NA":
                        verdict = call_record_verdict(str(run_dir), round_watermark, label, "indeterminate")
                    else:
                        result = "expected" if delta == 0 else "unexpected"
                        verdict = call_record_verdict(str(run_dir), round_watermark, label, result, flake_state)
                    print(f"    verdict[{label}] round={round_no} delta={delta} -> {verdict}", file=sys.stderr)

        if round_no >= 2 and all(label_is_terminal(run_dir, l) for l in labels):
            print(f"All {len(labels)} labels reached a terminal verdict after round {round_no}.", file=sys.stderr)
            break
    else:
        pass

    # Anything still not terminal after ATTEMPT_MAX rounds is recorded INDETERMINATE explicitly.
    for label in labels:
        if not label_is_terminal(run_dir, label):
            verdict = call_record_verdict(str(run_dir), round_watermark, label, "indeterminate")
            print(f"  {label}: retries exhausted ({ATTEMPT_MAX} rounds) without reproduced CLEAN result -> {verdict}", file=sys.stderr)

    print("=== postflight ===", file=sys.stderr)
    rc, out, err = call_postflight(str(run_dir), log_watermark)
    sys.stdout.write(out)
    sys.stderr.write(err)
    if rc != 0:
        sys.exit(f"FATAL: postflight failed (exit {rc}) -- stack-unchanged constraint violated, see {run_dir}/postflight.txt")

    print(f"=== Task 1 done. See {tsv_path}, {run_dir}/verdicts.tsv, {run_dir}/postflight.txt ===", file=sys.stderr)


if __name__ == "__main__":
    main()
