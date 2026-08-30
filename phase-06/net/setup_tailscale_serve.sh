#!/bin/bash
# phase-06/net/setup_tailscale_serve.sh — the ONE script that ever adds
# kanban's tailnet-only Tailscale Serve entry.
#
# Usage: setup_tailscale_serve.sh [--check|--apply] [--out-dir <dir>]
#   --check (default): run every pre-flight assertion, print the exact
#     command --apply would run, and exit WITHOUT mutating anything.
#   --apply: run pre-flight, and only if every pre-flight assertion passes,
#     run exactly ONE mutating command, then run every post-assertion.
#
# Fail-closed: any pre-flight assertion failing aborts BEFORE the mutating
# command is even considered — nothing is touched. Any post-assertion
# failing after --apply is NEVER treated as a pass: the mutating command has
# already run by that point, so a failed post-assertion exits 2
# (inconclusive) and prints the rollback command loudly, because a human
# must look.
#
# Idempotent: if the entry already exists and already points at the right
# target, this script prints ALREADY-CONFIGURED and exits 0 without running
# anything.
#
# ROLLBACK — pinned once in phase-06/net/config.env as $TS_SERVE_ROLLBACK_CMD,
# never re-derived here:
#     "$TAILSCALE_BIN" serve --https="$TS_SERVE_PORT" off
# Do NOT look this up in `tailscale serve --help` — this tailscale version
# documents no per-port removal syntax there at all. The only removal-shaped
# verbs --help shows are `reset` (wipes the ENTIRE serve config, including
# the two out-of-scope pre-existing handlers on :443/:10000 and the
# pre-existing public-exposure key on :8443) and `clear <service>` (named
# --service targets only, not applicable to a plain port entry like this
# one). Using the reset verb as a rollback would destroy configuration this
# project is required to record and never touch. That reset verb MUST NEVER
# be used as a rollback and must never appear anywhere under phase-06/ as
# one. 06-03-PLAN.md Task 3 Step D proves the `--https=<port> off` form is
# accepted by this tailscale version — against a scratch port, never the
# real one — before this script is ever trusted to run --apply for real
# (that live step is 06-04, not this plan).
#
# This script only ever calls `tailscale serve` (never the public-exposure
# subcommand) and `tailscale status`. Kanban's own bind
# (127.0.0.1:$KANBAN_PORT) is never touched by anything below.
#
# macOS /bin/bash is 3.2 — indexed arrays only, no `declare -A`.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

MODE="check"
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "setup_tailscale_serve.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-serve-setup"
fi
mkdir -p "$OUT_DIR"

REPORT="$OUT_DIR/setup-transcript.txt"
: > "$REPORT"

vlog() {
  echo "$1" | tee -a "$REPORT"
}

print_rollback() {
  vlog "ROLLBACK (if ever needed — run by hand, this script never runs it itself): $TS_SERVE_ROLLBACK_CMD"
}

abort_preflight() {
  vlog "PRE-FLIGHT ABORT: $1"
  vlog "Nothing was mutated."
  print_rollback
  echo "RESULTS_DIR=$OUT_DIR"
  exit 1
}

abort_postassert() {
  vlog "POST-ASSERTION FAILED — INCONCLUSIVE, NEVER REPORTED AS A PASS: $1"
  vlog "The apply command has already run. A human must look before retrying."
  print_rollback
  echo "RESULTS_DIR=$OUT_DIR"
  exit 2
}

# Captures `tailscale serve status --json` to $1, with the benign
# client/daemon version warning filtered off stderr (house rule 7: never
# gate success on stderr being empty, but never let the warning pollute a
# JSON capture either).
capture_serve_json() {
  "$TAILSCALE_BIN" serve status --json 2>&1 1>"$1" | grep -Ev "$TS_WARN_FILTER" >&2 || true
}

vlog "=== setup_tailscale_serve.sh MODE=$MODE $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog ""

# ---------------------------------------------------------------------------
# P1: tailscale reachable.
# ---------------------------------------------------------------------------
STATUS_OUT="$("$TAILSCALE_BIN" status 2>&1)"
STATUS_RC=$?
if [ "$STATUS_RC" -ne 0 ]; then
  STATUS_FILTERED="$(printf '%s\n' "$STATUS_OUT" | grep -Ev "$TS_WARN_FILTER" || true)"
  abort_preflight "P1: tailscale status failed rc=$STATUS_RC: $STATUS_FILTERED"
fi
vlog "P1 OK: tailscale reachable"

# ---------------------------------------------------------------------------
# P2: TS_SERVE_PORT is not forbidden.
# ---------------------------------------------------------------------------
for fp in $FORBIDDEN_SERVE_PORTS; do
  if [ "$fp" = "$TS_SERVE_PORT" ]; then
    abort_preflight "P2: TS_SERVE_PORT=$TS_SERVE_PORT is one of FORBIDDEN_SERVE_PORTS ($FORBIDDEN_SERVE_PORTS) — 3000 must stay unbound because a pre-existing public-exposure entry on :8443 already forwards to it; 443/8443/10000 are already claimed by the three pre-existing handlers this project must never touch"
  fi
done
vlog "P2 OK: TS_SERVE_PORT=$TS_SERVE_PORT is not forbidden"

# ---------------------------------------------------------------------------
# P3: port 3000 unbound.
# ---------------------------------------------------------------------------
PORT3000_COUNT="$(lsof -nP -iTCP:3000 2>/dev/null | wc -l | tr -d ' ')"
if [ "$PORT3000_COUNT" != "0" ]; then
  abort_preflight "P3: something is bound to port 3000 ($PORT3000_COUNT lsof line(s)) — refusing to open anything while that trap is armed"
fi
vlog "P3 OK: port 3000 unbound"

# ---------------------------------------------------------------------------
# P4: the fail-closed heart of this script — pre-existing config must match
# the frozen baseline EXACTLY for the three pre-existing entries and the
# single pre-existing public-exposure key. Any drift = ABORT with a diff.
# Uses a subset check on Web/TCP (a prior partial apply's kanban entry is
# tolerated here — P6 below decides idempotency) but an EXACT check on
# AllowFunnel (no new public-exposure key may ever be tolerated, even here).
# ---------------------------------------------------------------------------
PRE_JSON="$OUT_DIR/serve-status-before.json"
capture_serve_json "$PRE_JSON"

BASELINE_RESULT="$(python3 -c '
import json, sys
live = json.load(open(sys.argv[1]))
base = json.load(open(sys.argv[2]))
problems = []
for k, v in base.get("Web", {}).items():
    if k not in live.get("Web", {}):
        problems.append("missing Web key: %s" % k)
    elif live["Web"][k] != v:
        problems.append("Web[%s] drifted: live=%r base=%r" % (k, live["Web"][k], v))
for k, v in base.get("TCP", {}).items():
    if k not in live.get("TCP", {}):
        problems.append("missing TCP key: %s" % k)
    elif live["TCP"][k] != v:
        problems.append("TCP[%s] drifted: live=%r base=%r" % (k, live["TCP"][k], v))
if live.get("AllowFunnel", {}) != base.get("AllowFunnel", {}):
    problems.append("AllowFunnel drifted: live=%r base=%r" % (live.get("AllowFunnel"), base.get("AllowFunnel")))
if problems:
    print("DRIFT:" + " | ".join(problems))
    sys.exit(1)
print("OK")
' "$PRE_JSON" "$EXPECTED_SERVE_BASELINE")"
BASELINE_RC=$?
if [ "$BASELINE_RC" -ne 0 ]; then
  abort_preflight "P4: pre-existing Tailscale config has drifted from expected_serve_baseline.json — $BASELINE_RESULT — a human must look before anything is added"
fi
vlog "P4 OK: three pre-existing handlers + single public-exposure key match the frozen baseline"

# ---------------------------------------------------------------------------
# P5: kanban listening on loopback only, and answering HTTP.
# ---------------------------------------------------------------------------
KANBAN_LISTEN="$(lsof -nP -iTCP:"$KANBAN_PORT" -sTCP:LISTEN 2>/dev/null)"
if ! printf '%s\n' "$KANBAN_LISTEN" | grep -q "127.0.0.1:${KANBAN_PORT} "; then
  abort_preflight "P5: kanban is not listening on 127.0.0.1:$KANBAN_PORT: $KANBAN_LISTEN"
fi
if printf '%s\n' "$KANBAN_LISTEN" | grep -q "\*:${KANBAN_PORT} "; then
  abort_preflight "P5: something is bound to a wildcard address on port $KANBAN_PORT — refusing"
fi
KANBAN_HTTP="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "http://127.0.0.1:$KANBAN_PORT/")"
case "$KANBAN_HTTP" in
  2??|3??) : ;;
  *) abort_preflight "P5: kanban http check returned '$KANBAN_HTTP', expected 2xx/3xx" ;;
esac
vlog "P5 OK: kanban listening on 127.0.0.1:$KANBAN_PORT only, http=$KANBAN_HTTP"

# ---------------------------------------------------------------------------
# P6: idempotency. If the entry already exists and already proxies to the
# right target, stop here — ALREADY-CONFIGURED, exit 0, nothing run.
# ---------------------------------------------------------------------------
ENTRY_RESULT="$(python3 -c '
import json, sys
live = json.load(open(sys.argv[1]))
key, target = sys.argv[2], sys.argv[3]
entry = live.get("Web", {}).get(key)
handlers = entry.get("Handlers", {}) if entry else {}
if entry and handlers.get("/", {}).get("Proxy") == target and len(handlers) == 1:
    print("EXISTS")
    sys.exit(0)
print("ABSENT")
sys.exit(1)
' "$PRE_JSON" "$TAILNET_HOSTNAME:$TS_SERVE_PORT" "$TS_SERVE_TARGET")"
ENTRY_RC=$?
if [ "$ENTRY_RC" -eq 0 ]; then
  vlog "P6: ALREADY-CONFIGURED — $TAILNET_HOSTNAME:$TS_SERVE_PORT already proxies / to $TS_SERVE_TARGET. Nothing to do."
  echo "ALREADY-CONFIGURED"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 0
fi
vlog "P6 OK: no existing entry for $TAILNET_HOSTNAME:$TS_SERVE_PORT yet ($ENTRY_RESULT)"
vlog ""

APPLY_CMD=("$TAILSCALE_BIN" serve --bg --https="$TS_SERVE_PORT" "$TS_SERVE_TARGET")
vlog "Command that would run: ${APPLY_CMD[*]}"

if [ "$MODE" = "check" ]; then
  vlog ""
  vlog "MODE=check — all pre-flight assertions passed. Nothing was mutated. Re-run with --apply to execute the command above."
  # Capture "after" too, so a caller can prove byte-identity across this
  # entire no-op run (06-03-PLAN.md Task 3 Step A does exactly this).
  POST_CHECK_JSON="$OUT_DIR/serve-status-after.json"
  capture_serve_json "$POST_CHECK_JSON"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 0
fi

# ---------------------------------------------------------------------------
# APPLY — exactly one mutating command. Only reachable under --apply, and
# only after every pre-flight assertion above has passed.
# ---------------------------------------------------------------------------
vlog ""
vlog "=== APPLYING ==="
vlog "Running: ${APPLY_CMD[*]}"
APPLY_OUT="$("${APPLY_CMD[@]}" 2>&1)"
APPLY_RC=$?
APPLY_FILTERED="$(printf '%s\n' "$APPLY_OUT" | grep -Ev "$TS_WARN_FILTER" || true)"
vlog "apply rc=$APPLY_RC"
vlog "apply output: $APPLY_FILTERED"
if [ "$APPLY_RC" -ne 0 ]; then
  abort_postassert "the apply command itself returned non-zero (rc=$APPLY_RC): $APPLY_FILTERED"
fi

# ---------------------------------------------------------------------------
# POST-ASSERTIONS Q1-Q5. ANY failure here is inconclusive (exit 2), never a
# pass — the mutating command has already run.
# ---------------------------------------------------------------------------
POST_JSON="$OUT_DIR/serve-status-after.json"
capture_serve_json "$POST_JSON"

# Q1 — the single most important assertion in Phase 6: no new
# public-exposure key may appear, ever.
Q1_RESULT="$(python3 -c '
import json, sys
live = json.load(open(sys.argv[1]))
key, count = sys.argv[2], int(sys.argv[3])
af = live.get("AllowFunnel", {})
ok = len(af) == count and all(k == key and af[k] is True for k in af)
if count > 0:
    ok = ok and key in af
print("OK" if ok else "FAIL: AllowFunnel=%r expected exactly {%r: true}" % (af, key))
sys.exit(0 if ok else 1)
' "$POST_JSON" "$EXPECTED_FUNNEL_KEY" "$EXPECTED_FUNNEL_KEY_COUNT")"
Q1_RC=$?
[ "$Q1_RC" -ne 0 ] && abort_postassert "Q1 (no new public-exposure key): $Q1_RESULT"
vlog "Q1 OK: $Q1_RESULT"

# Q2 — same baseline-drift check as P4, run again against the post-apply
# capture: the three pre-existing handlers must still be byte-identical.
Q2_RESULT="$(python3 -c '
import json, sys
live = json.load(open(sys.argv[1]))
base = json.load(open(sys.argv[2]))
problems = []
for k, v in base.get("Web", {}).items():
    if k not in live.get("Web", {}):
        problems.append("missing Web key: %s" % k)
    elif live["Web"][k] != v:
        problems.append("Web[%s] drifted: live=%r base=%r" % (k, live["Web"][k], v))
for k, v in base.get("TCP", {}).items():
    if k not in live.get("TCP", {}):
        problems.append("missing TCP key: %s" % k)
    elif live["TCP"][k] != v:
        problems.append("TCP[%s] drifted: live=%r base=%r" % (k, live["TCP"][k], v))
if live.get("AllowFunnel", {}) != base.get("AllowFunnel", {}):
    problems.append("AllowFunnel drifted: live=%r base=%r" % (live.get("AllowFunnel"), base.get("AllowFunnel")))
if problems:
    print("DRIFT:" + " | ".join(problems))
    sys.exit(1)
print("OK")
' "$POST_JSON" "$EXPECTED_SERVE_BASELINE")"
Q2_RC=$?
[ "$Q2_RC" -ne 0 ] && abort_postassert "Q2 (three pre-existing handlers byte-identical): $Q2_RESULT"
vlog "Q2 OK: $Q2_RESULT"

# Q3 — the new kanban handler exists and is the ONLY new thing: handler
# count exactly baseline+1, TCP key count exactly baseline+1.
Q3_RESULT="$(python3 -c '
import json, sys
live = json.load(open(sys.argv[1]))
base = json.load(open(sys.argv[2]))
key, target, port = sys.argv[3], sys.argv[4], sys.argv[5]
web = live.get("Web", {})
tcp = live.get("TCP", {})
problems = []
entry = web.get(key)
handlers = entry.get("Handlers", {}) if entry else {}
if not entry or handlers.get("/", {}).get("Proxy") != target or len(handlers) != 1:
    problems.append("new Web handler missing or wrong: %r" % entry)
if len(web) != len(base.get("Web", {})) + 1:
    problems.append("Web handler count=%d expected baseline+1=%d" % (len(web), len(base.get("Web", {})) + 1))
if port not in tcp:
    problems.append("TCP key %s missing" % port)
if len(tcp) != len(base.get("TCP", {})) + 1:
    problems.append("TCP key count=%d expected baseline+1=%d" % (len(tcp), len(base.get("TCP", {})) + 1))
if problems:
    print("FAIL: " + " | ".join(problems))
    sys.exit(1)
print("OK")
' "$POST_JSON" "$EXPECTED_SERVE_BASELINE" "$TAILNET_HOSTNAME:$TS_SERVE_PORT" "$TS_SERVE_TARGET" "$TS_SERVE_PORT")"
Q3_RC=$?
[ "$Q3_RC" -ne 0 ] && abort_postassert "Q3 (new kanban handler present, exactly baseline+1, nothing else appeared): $Q3_RESULT"
vlog "Q3 OK: $Q3_RESULT"

# Q4 — port 3000 still unbound.
PORT3000_AFTER="$(lsof -nP -iTCP:3000 2>/dev/null | wc -l | tr -d ' ')"
[ "$PORT3000_AFTER" != "0" ] && abort_postassert "Q4: port 3000 became bound after apply ($PORT3000_AFTER lsof line(s))"
vlog "Q4 OK: port 3000 still unbound"

# Q5 — kanban's own bind did not change.
KANBAN_LISTEN_AFTER="$(lsof -nP -iTCP:"$KANBAN_PORT" -sTCP:LISTEN 2>/dev/null)"
if ! printf '%s\n' "$KANBAN_LISTEN_AFTER" | grep -q "127.0.0.1:${KANBAN_PORT} "; then
  abort_postassert "Q5: kanban's listener changed — no longer 127.0.0.1:$KANBAN_PORT: $KANBAN_LISTEN_AFTER"
fi
vlog "Q5 OK: kanban's listener is still 127.0.0.1:$KANBAN_PORT only"

vlog ""
vlog "SETUP_TAILSCALE_SERVE: SUCCESS — $TAILNET_HOSTNAME:$TS_SERVE_PORT now proxies / to $TS_SERVE_TARGET (tailnet only, never the public-exposure mode)"
echo "RESULTS_DIR=$OUT_DIR"
exit 0
