#!/bin/bash
# phase-02/infra/verify_queueing.sh — INF-01 evidence collector.
#
# Usage: verify_queueing.sh --label before|after [--concurrency <N>] [--cap <C>] [--out-dir <dir>]
#
# Fires $CONCURRENCY concurrent small-prompt requests directly at :8000
# (bypassing role-shim/litellm — this exercises server-side admission
# only), slices the new flashnext.err since before the requests, and
# analyzes the Generation queued / Prefill started / Decode started /
# Decode completed timestamps per request=<id> with python3.
#
# --label before: records only, always exits 0 (a baseline, not a gate).
# --label after:  asserts the concurrency cap actually held.
#
# CAVEAT (see RESEARCH.md Pitfall 3): "Request started: ... in_flight=<N>"
# reaches the full concurrency count even WITH the cap in force, because
# in_flight counts HTTP requests being served, not sequences admitted to
# the decode batch. A high in_flight is NOT counter-evidence and must not
# be used as the pass/fail signal. N HTTP 200s alone prove nothing either
# -- 2 concurrent small requests already succeed today, uncapped, with
# in_flight=2. The half-open interval [prefill_started, decode_completed]
# per request id -- i.e. "this sequence occupied a slot in the decode
# batch" -- is the only evidence used below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

LABEL=""
CONCURRENCY=""
CAP=""
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --label)
      LABEL="$2"
      shift 2
      ;;
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    --cap)
      CAP="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ "$LABEL" != "before" ] && [ "$LABEL" != "after" ]; then
  echo "Usage: $0 --label before|after [--concurrency <N>] [--cap <C>] [--out-dir <dir>]" >&2
  exit 1
fi

# --cap defaults to MAX_NUM_SEQS, --concurrency to MAX_NUM_SEQS + 1 -- one
# more request than the cap allows, the minimum that can demonstrate
# backpressure. Neither is hardcoded: raising MAX_NUM_SEQS in config.env
# to 2 automatically turns this into a 3-concurrent-request probe against
# a cap of 2, with no second script.
if [ -z "$CAP" ]; then
  CAP="$MAX_NUM_SEQS"
fi
if [ -z "$CONCURRENCY" ]; then
  CONCURRENCY=$((MAX_NUM_SEQS + 1))
fi

# Small prompts only, always (RESEARCH.md Pitfall 2: a real single-request
# Metal OOM already happened on this deployment at prompt_tokens=30505;
# large *concurrent* requests could plausibly crash a live service).
if [ "$CONCURRENCY" -gt 4 ]; then
  echo "refusing: --concurrency $CONCURRENCY exceeds the safety cap of 4." >&2
  echo "This probe only ever needs cap+1 requests to demonstrate backpressure;" >&2
  echo "large N multiplies concurrent-request memory pressure on a live service" >&2
  echo "the user depends on (RESEARCH.md Pitfall 2)." >&2
  exit 1
fi

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUT_DIR"

echo "verify_queueing: label=$LABEL concurrency=$CONCURRENCY cap=$CAP out_dir=$OUT_DIR"

# ---------------------------------------------------------------------------
# 1. Capture the log byte offset BEFORE firing anything.
# ---------------------------------------------------------------------------
OFFSET=$(wc -c < "$FLASHNEXT_ERR" | tr -d ' ')

# ---------------------------------------------------------------------------
# 2. Fire $CONCURRENCY concurrent small requests directly at :8000.
# ---------------------------------------------------------------------------
BODY='{"model": "'"$MLX_MODEL_PATH"'", "messages":[{"role":"user","content":"count from 1 to 20 slowly, one number per line"}], "max_tokens": 60, "stream": false}'

i=1
while [ "$i" -le "$CONCURRENCY" ]; do
  (
    curl -s -m 120 -X POST "http://127.0.0.1:${MLX_PORT}/v1/chat/completions" \
      -H 'Content-Type: application/json' \
      -d "$BODY" \
      -o "$OUT_DIR/queueing-$LABEL-r$i.json" \
      -w '%{http_code}' \
      > "$OUT_DIR/queueing-$LABEL-r$i.code" \
      2> "$OUT_DIR/queueing-$LABEL-r$i.err"
    echo $? > "$OUT_DIR/queueing-$LABEL-r$i.rc"
  ) &
  sleep 0.3
  i=$((i + 1))
done
wait

# ---------------------------------------------------------------------------
# 3. Slice only the new log.
# ---------------------------------------------------------------------------
LOG_SLICE="$OUT_DIR/queueing-$LABEL-log-slice.txt"
tail -c "+$((OFFSET + 1))" "$FLASHNEXT_ERR" > "$LOG_SLICE"

# ---------------------------------------------------------------------------
# 4-6. Parse + assert with python3 (bash 3.2 cannot do this cleanly).
# Correlates per-request by the request=<hexid> token. "Decode completed:
# request=<id>" (which DOES carry the id) is used as the "this request
# finished generating" marker -- the anonymous "Request completed" line
# is deliberately NOT used for correlation, since it carries no id.
# ---------------------------------------------------------------------------
export QUEUEING_LOG_SLICE="$LOG_SLICE"
export QUEUEING_OUT_DIR="$OUT_DIR"
export QUEUEING_LABEL="$LABEL"
export QUEUEING_MODE="$LABEL"
export QUEUEING_CONCURRENCY="$CONCURRENCY"
export QUEUEING_CAP="$CAP"

python3 <<'PYEOF'
import datetime
import glob
import json
import os
import re
import sys

log_slice = os.environ["QUEUEING_LOG_SLICE"]
out_dir = os.environ["QUEUEING_OUT_DIR"]
label = os.environ["QUEUEING_LABEL"]
mode = os.environ["QUEUEING_MODE"]  # "before" or "after"
concurrency = int(os.environ["QUEUEING_CONCURRENCY"])
cap = int(os.environ["QUEUEING_CAP"])

TS_RE = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3})"
LINE_RE = re.compile(
    TS_RE
    + r" - INFO - (Generation queued|Prefill started|Decode started|Decode completed): "
    + r"request=(\S+)"
)


def parse_ts(s):
    return datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S,%f")


EVENT_KEY = {
    "Generation queued": "queued_at",
    "Prefill started": "prefill_started_at",
    "Decode started": "decode_started_at",
    "Decode completed": "decode_completed_at",
}

requests = {}
with open(log_slice, "r", errors="replace") as f:
    for line in f:
        m = LINE_RE.search(line)
        if not m:
            continue
        ts_str, event, req_id = m.group(1), m.group(2), m.group(3)
        ts = parse_ts(ts_str)
        rec = requests.setdefault(req_id, {})
        rec[EVENT_KEY[event]] = ts

# Order by Generation queued timestamp so the table reads in submission order.
ordered_ids = sorted(
    (rid for rid, rec in requests.items() if "queued_at" in rec),
    key=lambda rid: requests[rid]["queued_at"],
)
# Any request id observed only via a later event (queued line missed by the
# slice window) still gets appended, ordered after the ones we do have a
# queued_at for.
for rid in requests:
    if rid not in ordered_ids:
        ordered_ids.append(rid)

print("=== per-request timing table (label=%s) ===" % label)
print("%-12s %-23s %-23s %-23s %-23s" % (
    "request", "queued_at", "prefill_started_at", "decode_started_at", "decode_completed_at"))
for rid in ordered_ids:
    rec = requests[rid]
    print("%-12s %-23s %-23s %-23s %-23s" % (
        rid,
        rec.get("queued_at", "-"),
        rec.get("prefill_started_at", "-"),
        rec.get("decode_started_at", "-"),
        rec.get("decode_completed_at", "-"),
    ))

complete_ids = [
    rid for rid in ordered_ids
    if "prefill_started_at" in requests[rid] and "decode_completed_at" in requests[rid]
]

if not complete_ids:
    msg = "no request had both Prefill started and Decode completed in the log slice"
    if mode == "before":
        print("QUEUEING: BASELINE label=%s (%s)" % (label, msg))
        sys.exit(0)
    else:
        print("QUEUEING: INCONCLUSIVE %s" % msg)
        sys.exit(2)

# Half-open interval [prefill_started, decode_completed] per request id --
# "this sequence occupied a slot in the decode batch". Sweep the endpoints
# to get max_overlap (largest number of sequences simultaneously in the
# batch). Ties: an end is processed before a start at the same instant, so
# two intervals that merely touch are not counted as overlapping.
events = []
for rid in complete_ids:
    rec = requests[rid]
    events.append((rec["prefill_started_at"], 1, rid))
    events.append((rec["decode_completed_at"], -1, rid))
events.sort(key=lambda e: (e[0], e[1]))  # -1 (end) sorts before +1 (start) at a tie

running = 0
max_overlap = 0
for _, delta, _ in events:
    running += delta
    if running > max_overlap:
        max_overlap = running

# queued_count: how many requests had prefill_started >= the earliest
# decode_completed among all OTHER requests -- i.e. were admitted only
# after some earlier request finished decoding.
queued_count = 0
for rid in complete_ids:
    others = [requests[o]["decode_completed_at"] for o in complete_ids if o != rid]
    if not others:
        continue
    min_finish_other = min(others)
    if requests[rid]["prefill_started_at"] >= min_finish_other:
        queued_count += 1

earliest_decode_completed = min(requests[rid]["decode_completed_at"] for rid in complete_ids)
latest_prefill_started = max(requests[rid]["prefill_started_at"] for rid in complete_ids)
gap_seconds = (earliest_decode_completed - latest_prefill_started).total_seconds()

print("")
print("max_overlap=%d cap=%d queued_count=%d concurrency=%d distinct_ids=%d" % (
    max_overlap, cap, queued_count, concurrency, len(complete_ids)))
print("gap_seconds(earliest_decode_completed - latest_prefill_started)=%.3f" % gap_seconds)
print("(positive gap => later admissions all started after the earliest one finished;")
print(" negative/near-zero gap => admissions overlapped in time -- interleaved, not queued)")

# Response-body check: every curl must have exited 0 and every response
# JSON must have a non-empty choices[0].message.content (queuing, not an
# OOM, not a 5xx).
bodies_ok = True
body_problems = []
json_files = sorted(glob.glob(os.path.join(out_dir, "queueing-%s-r*.json" % label)))
if not json_files:
    bodies_ok = False
    body_problems.append("no response JSON files found for label=%s" % label)
for jf in json_files:
    idx = jf
    rc_file = jf[: -len(".json")] + ".rc"
    code_file = jf[: -len(".json")] + ".code"
    if os.path.exists(rc_file):
        with open(rc_file) as fh:
            rc = fh.read().strip()
        if rc != "0":
            bodies_ok = False
            body_problems.append("%s: curl exit code %s" % (idx, rc))
    if os.path.exists(code_file):
        with open(code_file) as fh:
            http_code = fh.read().strip()
        if not http_code.startswith("200"):
            bodies_ok = False
            body_problems.append("%s: http code %s" % (idx, http_code))
    try:
        with open(jf) as fh:
            body = json.load(fh)
        content = body.get("choices", [{}])[0].get("message", {}).get("content", "")
        if not content:
            bodies_ok = False
            body_problems.append("%s: empty choices[0].message.content" % idx)
    except Exception as e:
        bodies_ok = False
        body_problems.append("%s: could not parse JSON (%s)" % (idx, e))

if body_problems:
    print("body/status problems: %s" % "; ".join(body_problems))

if mode == "before":
    # A baseline, not a gate: record what happened, never fail on it.
    if max_overlap >= concurrency:
        print("observed admission: INTERLEAVED (max_overlap=%d == concurrency=%d)" % (
            max_overlap, concurrency))
    else:
        print("observed admission: SERIALIZED-OR-PARTIAL (max_overlap=%d < concurrency=%d) "
              "-- record this plainly, do not re-run repeatedly" % (max_overlap, concurrency))
    print("QUEUEING: BASELINE label=%s" % label)
    sys.exit(0)

# after mode: assert.
distinct_ok = len(complete_ids) == concurrency
cap_ok = max_overlap <= cap
queued_ok = queued_count >= (concurrency - cap)

all_pass = bodies_ok and distinct_ok and cap_ok and queued_ok

if all_pass:
    print("QUEUEING: PASS label=%s" % label)
    sys.exit(0)
else:
    print("QUEUEING: FAIL (max_overlap=%d cap=%d queued_count=%d need>=%d) "
          "label=%s [bodies_ok=%s distinct_ok=%s(%d/%d) cap_ok=%s queued_ok=%s]" % (
              max_overlap, cap, queued_count, concurrency - cap, label,
              bodies_ok, distinct_ok, len(complete_ids), concurrency, cap_ok, queued_ok))
    sys.exit(1)
PYEOF
