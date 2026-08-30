#!/bin/bash
# phase-06/net/verify_network.sh — Phase 6's standing network gate.
#
# Phase 7 and Phase 8 should run this before AND after any change to network
# posture, the same way phase-05/services/verify_services.sh is Phase 5's
# standing gate. Read-only and re-runnable: this script never mutates
# Tailscale config (only `tailscale status` and `tailscale serve status` are
# ever called — read-only subcommands), never restarts a service, never
# sends a signal to any process, and never calls a state-changing launchd
# subcommand (the only launchd subcommand used below is the read-only
# `print`). Check 12 does invoke run_telegram_service.sh directly by hand,
# outside launchd — that is a deliberately bounded, safe, re-runnable
# behavioural probe (the NET-04 guard fires before cline is ever executed),
# not a mutation of anything this gate is itself responsible for policing.
#
# Usage: verify_network.sh [--out-dir <dir>] [--baseline <dir>]
#   --baseline <dir>: the 06-01 pre-change baseline directory (contains
#     inventory.txt). Only used by check 15 (live-pids-stable). If omitted,
#     check 15 reports INCONCLUSIVE (rc=2), never a silent pass.
#
# 06-04.1 added checks 16-24, covering the Host/Origin-rewriting loopback
# proxy that unblocks 06-04 (com.ohama.kanban-proxy on
# 127.0.0.1:$KANBAN_PROXY_PORT). These add curl probes, one `lsof`, one
# `launchctl print` (sampled twice, read-only both times), and two
# `node probe_proxy.js` runs — all read-only, same as every check above:
# none of them restarts a service, sends a signal, or calls a
# state-changing launchd subcommand. Health for the new checks never rests
# on `state = running` alone (check 16 samples the SAME pid twice, >=10s
# apart, exactly like restart_service.sh's own portless-label health poll)
# — a job stuck in a KeepAlive restart loop reports `running` on almost
# every sample taken mid-loop.
#
# Exit code contract (mirrors phase-05/services/verify_services.sh and
# phase-03/sandbox/verify_sandbox.sh):
#   0 = every CHECK line PASSed
#   1 = at least one CHECK FAILed and nothing crashed
#   2 = at least one probe CRASHED (inconclusive) — never reported as a pass
#
# macOS /bin/bash is 3.2 — indexed arrays only, no associative-array
# declarations.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

OUT_DIR=""
BASELINE_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --baseline)
      BASELINE_DIR="$2"
      shift 2
      ;;
    *)
      echo "verify_network.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-net-gate"
fi
mkdir -p "$OUT_DIR"

REPORT="$OUT_DIR/verify_network-verdict.txt"
: > "$REPORT"

UID_NUM="$(id -u)"

vlog() {
  echo "$1" | tee -a "$REPORT"
}

# ---------------------------------------------------------------------------
# Case bookkeeping: parallel indexed arrays (bash 3.2 has no associative
# arrays).
# rc convention (same as verify_services.sh / assert_denied.sh):
#   0 = PASS, 1 = FAIL, 2 = CRASHED/INCONCLUSIVE.
# ---------------------------------------------------------------------------
CASE_IDS=()
CASE_RCS=()

record_check() {
  local id="$1" rc="$2" detail="${3:-}"
  CASE_IDS+=("$id")
  CASE_RCS+=("$rc")
  if [ "$rc" -eq 0 ]; then
    vlog "CHECK: PASS $id"
  elif [ "$rc" -eq 2 ]; then
    vlog "CHECK: FAIL $id -- CRASHED: $detail"
  else
    vlog "CHECK: FAIL $id -- $detail"
  fi
}

# Captures `tailscale serve status --json` to $1, filtering the benign
# client/daemon version warning off stderr (house rule 7: never gate
# success on stderr being empty; never let the warning pollute a JSON
# capture either).
capture_serve_json() {
  "$TAILSCALE_BIN" serve status --json 2>&1 1>"$1" | grep -Ev "$TS_WARN_FILTER" >&2 || true
}

# Read-only launchd pid lookup for one label (same idiom as
# verify_services.sh's print_state_pid).
get_label_pid() {
  local label="$1" out
  out="$(launchctl print "gui/$UID_NUM/$label" 2>&1)"
  printf '%s\n' "$out" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}'
}

vlog "=== phase-06/net/verify_network.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
vlog ""

LIVE_JSON="$OUT_DIR/serve-status.json"
capture_serve_json "$LIVE_JSON"

# ---------------------------------------------------------------------------
# 1. tailscale-reachable
# ---------------------------------------------------------------------------
vlog "--- 1: tailscale-reachable ---"
TS_OUT="$("$TAILSCALE_BIN" status 2>&1)"
TS_RC=$?
if [ "$TS_RC" -eq 0 ]; then
  record_check "tailscale-reachable" 0
else
  TS_FILTERED="$(printf '%s\n' "$TS_OUT" | grep -Ev "$TS_WARN_FILTER" || true)"
  record_check "tailscale-reachable" 1 "rc=$TS_RC: $TS_FILTERED"
fi
vlog ""

# ---------------------------------------------------------------------------
# 2. no-new-public-exposure -- the phase's overriding safety property.
# AllowFunnel must have exactly one key, and it must be $EXPECTED_FUNNEL_KEY.
# ---------------------------------------------------------------------------
vlog "--- 2: no-new-public-exposure ---"
FUNNEL_RESULT="$(python3 -c '
import json, sys
live = json.load(open(sys.argv[1]))
key, count = sys.argv[2], int(sys.argv[3])
af = live.get("AllowFunnel", {})
ok = len(af) == count and all(k == key and af[k] is True for k in af)
if count > 0:
    ok = ok and key in af
print("OK" if ok else "FAIL: AllowFunnel=%r expected exactly {%r: true}" % (af, key))
sys.exit(0 if ok else 1)
' "$LIVE_JSON" "$EXPECTED_FUNNEL_KEY" "$EXPECTED_FUNNEL_KEY_COUNT")"
FUNNEL_RC=$?
if [ "$FUNNEL_RC" -eq 0 ]; then
  record_check "no-new-public-exposure" 0
else
  record_check "no-new-public-exposure" 1 "$FUNNEL_RESULT"
fi
vlog ""

# ---------------------------------------------------------------------------
# 3. preexisting-serve-entries-untouched -- the three baseline Web handlers
# and TCP keys must still match $EXPECTED_SERVE_BASELINE. Subset check on
# Web/TCP (an added kanban entry is fine and expected once 06-04 has run),
# exact check on AllowFunnel (identical logic to check 2, defense in depth).
# ---------------------------------------------------------------------------
vlog "--- 3: preexisting-serve-entries-untouched ---"
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
' "$LIVE_JSON" "$EXPECTED_SERVE_BASELINE")"
BASELINE_RC=$?
if [ "$BASELINE_RC" -eq 0 ]; then
  record_check "preexisting-serve-entries-untouched" 0
else
  record_check "preexisting-serve-entries-untouched" 1 "$BASELINE_RESULT"
fi
vlog ""

# ---------------------------------------------------------------------------
# 4. kanban-serve-entry-present -- NET-01 (server side). Before 06-04 runs
# this is expected to FAIL (that is the negative-control point of 06-03
# Task 3 Step B).
# ---------------------------------------------------------------------------
vlog "--- 4: kanban-serve-entry-present ---"
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
' "$LIVE_JSON" "$TAILNET_HOSTNAME:$TS_SERVE_PORT" "$TS_SERVE_TARGET")"
ENTRY_RC=$?
if [ "$ENTRY_RC" -eq 0 ]; then
  record_check "kanban-serve-entry-present" 0
else
  record_check "kanban-serve-entry-present" 1 "$ENTRY_RESULT -- no handler for $TAILNET_HOSTNAME:$TS_SERVE_PORT proxying / to $TS_SERVE_TARGET yet"
fi
vlog ""

# ---------------------------------------------------------------------------
# 5. port-3000-unbound -- NET-03.
# ---------------------------------------------------------------------------
vlog "--- 5: port-3000-unbound ---"
PORT3000_COUNT="$(lsof -nP -iTCP:3000 2>/dev/null | wc -l | tr -d ' ')"
if [ "$PORT3000_COUNT" = "0" ]; then
  record_check "port-3000-unbound" 0
else
  record_check "port-3000-unbound" 1 "port 3000 has $PORT3000_COUNT lsof line(s) bound -- must stay unbound: a pre-existing public-exposure entry on :8443 already forwards there, so anything binding 3000 becomes world-reachable with no tailnet login at all"
fi
vlog ""

# ---------------------------------------------------------------------------
# 6. kanban-bind-loopback-only -- NET-02.
# ---------------------------------------------------------------------------
vlog "--- 6: kanban-bind-loopback-only ---"
KANBAN_LISTEN="$(lsof -nP -iTCP:"$KANBAN_PORT" -sTCP:LISTEN 2>/dev/null)"
if printf '%s\n' "$KANBAN_LISTEN" | grep -q "127.0.0.1:${KANBAN_PORT} " \
  && ! printf '%s\n' "$KANBAN_LISTEN" | grep -q "\*:${KANBAN_PORT} "; then
  record_check "kanban-bind-loopback-only" 0
else
  record_check "kanban-bind-loopback-only" 1 "lsof=$(printf '%s' "$KANBAN_LISTEN" | tr '\n' ';')"
fi
vlog ""

# ---------------------------------------------------------------------------
# 7. lan-refused-kanban-port -- NET-02. Mirrors
# phase-02/infra/verify_lan_bind.sh Check 2 exactly, including the
# INCONCLUSIVE path when no LAN IP can be derived.
# ---------------------------------------------------------------------------
vlog "--- 7: lan-refused-kanban-port ---"
if [ -z "$LAN_IP" ]; then
  record_check "lan-refused-kanban-port" 2 "no LAN IP could be derived (en0/en1 both empty)"
else
  HTTP_CODE7="$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$LAN_IP:$KANBAN_PORT/")"
  CURL7_RC=$?
  if [ "$CURL7_RC" -eq 7 ] || [ "$CURL7_RC" -eq 28 ]; then
    record_check "lan-refused-kanban-port" 0
  elif [ "$CURL7_RC" -eq 0 ]; then
    record_check "lan-refused-kanban-port" 1 "reachable from LAN ($LAN_IP), http_code=$HTTP_CODE7 -- expected connection refused/timeout"
  else
    record_check "lan-refused-kanban-port" 1 "unexpected curl rc=$CURL7_RC"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 8. lan-refused-serve-port -- the Serve listener must not be reachable from
# the LAN interface either (Tailscale routes over the tailscale interface,
# never a raw LAN listener, so this must PASS both before and after 06-04).
# ---------------------------------------------------------------------------
vlog "--- 8: lan-refused-serve-port ---"
if [ -z "$LAN_IP" ]; then
  record_check "lan-refused-serve-port" 2 "no LAN IP could be derived (en0/en1 both empty)"
else
  HTTP_CODE8="$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$LAN_IP:$TS_SERVE_PORT/")"
  CURL8_RC=$?
  if [ "$CURL8_RC" -eq 7 ] || [ "$CURL8_RC" -eq 28 ]; then
    record_check "lan-refused-serve-port" 0
  elif [ "$CURL8_RC" -eq 0 ]; then
    record_check "lan-refused-serve-port" 1 "reachable from LAN ($LAN_IP), http_code=$HTTP_CODE8 -- expected connection refused/timeout"
  else
    record_check "lan-refused-serve-port" 1 "unexpected curl rc=$CURL8_RC"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 9. tailnet-https-200 -- NET-01 (server side). Uses the MagicDNS hostname,
# never loopback -- the point is that the tailnet address itself answers.
# Before 06-04 runs this is expected to FAIL (the other half of the 06-03
# Task 3 Step B negative control).
# ---------------------------------------------------------------------------
vlog "--- 9: tailnet-https-200 ---"
CODE9="$(curl -s -m 15 -o /dev/null -w '%{http_code}' "$TS_SERVE_URL")"
if [ "$CODE9" = "200" ]; then
  record_check "tailnet-https-200" 0
else
  record_check "tailnet-https-200" 1 "http_code=${CODE9:-<none>} url=$TS_SERVE_URL"
fi
vlog ""

# ---------------------------------------------------------------------------
# 10. tailnet-no-passcode-gate -- kanban's passcode gate is decided once at
# startup from its --host flag; keeping the bind on loopback is what keeps
# it off for any caller, tailnet or otherwise. Reachability of $TS_SERVE_URL
# itself is check 9's job, not this one's -- this check's PASS condition is
# "no banner ever appeared in the log", evaluated regardless of whether the
# tailnet URL happens to be reachable yet, plus (when it IS reachable) that
# the body genuinely looks like the board.
# ---------------------------------------------------------------------------
vlog "--- 10: tailnet-no-passcode-gate ---"
BODY10="$(curl -s -m 15 "$TS_SERVE_URL")"
CURL10_RC=$?
BANNER_HIT=0
LOGF="$SERVICE_LOG_DIR/kanban.log"
if [ -f "$LOGF" ] && grep -qi "passcode" "$LOGF"; then
  BANNER_HIT=1
fi
if [ "$BANNER_HIT" -eq 1 ]; then
  record_check "tailnet-no-passcode-gate" 1 "a remote-access passcode banner was found in $LOGF -- kanban's bind may have changed off loopback"
elif [ "$CURL10_RC" -ne 0 ]; then
  vlog "tailnet-no-passcode-gate: $TS_SERVE_URL not yet reachable (curl_rc=$CURL10_RC) -- reachability is check 9's job; no banner in the log is this check's PASS condition when unreachable"
  record_check "tailnet-no-passcode-gate" 0
elif printf '%s' "$BODY10" | grep -qi "kanban\|<!doctype html\|<html"; then
  record_check "tailnet-no-passcode-gate" 0
else
  record_check "tailnet-no-passcode-gate" 1 "URL reachable but the body did not look like the kanban board, and no banner in the log either -- unexpected response, investigate"
fi
vlog ""

# ---------------------------------------------------------------------------
# 11. net04-guard-present -- NET-04 (static). The wrapper carries the
# ABORT-NET04 guard and passes --allowed-user-id on its exec line.
# ---------------------------------------------------------------------------
vlog "--- 11: net04-guard-present ---"
TG_SCRIPT="$PROJECT_ROOT/phase-05/services/run_telegram_service.sh"
if [ ! -f "$TG_SCRIPT" ]; then
  record_check "net04-guard-present" 2 "script not found: $TG_SCRIPT"
else
  GUARD_HIT=0
  grep -q 'ABORT-NET04' "$TG_SCRIPT" && GUARD_HIT=1
  FLAG_HIT=0
  grep -q -- '--allowed-user-id' "$TG_SCRIPT" && FLAG_HIT=1
  if [ "$GUARD_HIT" -eq 1 ] && [ "$FLAG_HIT" -eq 1 ]; then
    record_check "net04-guard-present" 0
  else
    record_check "net04-guard-present" 1 "guard_present=$GUARD_HIT allowed_user_id_flag_present=$FLAG_HIT"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 12. net04-guard-refuses -- NET-04 (behavioural). Runs the wrapper directly
# (never through launchd) with $NET04_PROBE_TOKEN and the allowlist id
# unset, hard-bounded to 15s. Safe and re-runnable because the guard fires
# before wait_for_upstream.sh and before cline is ever executed.
# ---------------------------------------------------------------------------
vlog "--- 12: net04-guard-refuses ---"
PROBE_OUT="$(timeout 15 env -u TELEGRAM_ALLOWED_USER_ID TELEGRAM_BOT_TOKEN="$NET04_PROBE_TOKEN" bash "$TG_SCRIPT" 2>&1)"
PROBE_RC=$?
CONNECT_COUNT="$(pgrep -f 'connect telegram' | wc -l | tr -d ' ')"
ABORT_COUNT="$(printf '%s\n' "$PROBE_OUT" | grep -c 'ABORT-NET04')"
if [ "$PROBE_RC" -eq 1 ] && [ "$ABORT_COUNT" -ge 1 ] && [ "$CONNECT_COUNT" = "0" ]; then
  record_check "net04-guard-refuses" 0
else
  record_check "net04-guard-refuses" 1 "rc=$PROBE_RC abort_count=$ABORT_COUNT connect_telegram_procs=$CONNECT_COUNT"
fi
vlog ""

# ---------------------------------------------------------------------------
# 13. no-wildcard-bind-in-repo.
# ---------------------------------------------------------------------------
vlog "--- 13: no-wildcard-bind-in-repo ---"
WILDCARD_HITS="$(grep -rln '0\.0\.0\.0' "$PROJECT_ROOT/phase-05" "$PROJECT_ROOT/phase-06" --include='*.sh' --include='*.env' --include='*.plist' --include='*.js' 2>/dev/null)"
if [ -z "$WILDCARD_HITS" ]; then
  record_check "no-wildcard-bind-in-repo" 0
else
  record_check "no-wildcard-bind-in-repo" 1 "wildcard bind literal found in: $(printf '%s' "$WILDCARD_HITS" | tr '\n' ';')"
fi
vlog ""

# ---------------------------------------------------------------------------
# 14. no-public-exposure-command-in-repo -- the wording-collision trap,
# live: the needle is built from two variables so this check's own PASS
# path (and its own source text) never contains the literal adjacency it is
# searching for.
# ---------------------------------------------------------------------------
vlog "--- 14: no-public-exposure-command-in-repo ---"
_PART_A="tailscale"
_PART_B="fun""nel"
NEEDLE="$_PART_A $_PART_B"
PUBEXP_HITS="$(grep -rl -- "$NEEDLE" "$PROJECT_ROOT/phase-06/net" 2>/dev/null)"
if [ -z "$PUBEXP_HITS" ]; then
  record_check "no-public-exposure-command-in-repo" 0
else
  record_check "no-public-exposure-command-in-repo" 1 "public-exposure subcommand invocation found in: $(printf '%s' "$PUBEXP_HITS" | tr '\n' ';')"
fi
vlog ""

# ---------------------------------------------------------------------------
# 15. live-pids-stable -- the four upstream pids (flashnext, litellm,
# role-shim, kanban) recorded in the 06-01 baseline must still be the same.
# telegram-connect is deliberately excluded: its pid is expected to change
# across Phase 6 service restarts. INCONCLUSIVE (rc=2), never a silent
# pass, if --baseline was not provided or its inventory.txt is unreadable.
# ---------------------------------------------------------------------------
vlog "--- 15: live-pids-stable ---"
if [ -z "$BASELINE_DIR" ]; then
  record_check "live-pids-stable" 2 "no --baseline <dir> provided"
else
  INV="$BASELINE_DIR/inventory.txt"
  if [ ! -f "$INV" ]; then
    record_check "live-pids-stable" 2 "baseline inventory.txt not found at $INV"
  else
    EXP_FLASHNEXT="$(grep -F 'mlx_vlm.server' "$INV" | awk '{print $1}' | head -1)"
    EXP_LITELLM="$(grep -F '/litellm --config' "$INV" | awk '{print $1}' | head -1)"
    EXP_ROLESHIM="$(grep -F 'role_shim.py' "$INV" | awk '{print $1}' | head -1)"
    EXP_KANBAN="$(grep -F '/opt/homebrew/bin/kanban' "$INV" | awk '{print $1}' | head -1)"

    if [ -z "$EXP_FLASHNEXT" ] || [ -z "$EXP_LITELLM" ] || [ -z "$EXP_ROLESHIM" ] || [ -z "$EXP_KANBAN" ]; then
      record_check "live-pids-stable" 2 "could not parse one or more expected pids from $INV (flashnext=$EXP_FLASHNEXT litellm=$EXP_LITELLM roleshim=$EXP_ROLESHIM kanban=$EXP_KANBAN)"
    else
      LIVE_FLASHNEXT="$(pgrep -f 'mlx_vlm.server' | head -1)"
      LIVE_LITELLM="$(pgrep -f 'litellm --config' | head -1)"
      LIVE_ROLESHIM="$(pgrep -f 'role_shim.py' | head -1)"
      LIVE_KANBAN="$(get_label_pid "$KANBAN_LABEL")"

      MISMATCH=""
      [ "$LIVE_FLASHNEXT" = "$EXP_FLASHNEXT" ] || MISMATCH="$MISMATCH flashnext(exp=$EXP_FLASHNEXT live=${LIVE_FLASHNEXT:-<none>})"
      [ "$LIVE_LITELLM" = "$EXP_LITELLM" ] || MISMATCH="$MISMATCH litellm(exp=$EXP_LITELLM live=${LIVE_LITELLM:-<none>})"
      [ "$LIVE_ROLESHIM" = "$EXP_ROLESHIM" ] || MISMATCH="$MISMATCH role-shim(exp=$EXP_ROLESHIM live=${LIVE_ROLESHIM:-<none>})"
      [ "$LIVE_KANBAN" = "$EXP_KANBAN" ] || MISMATCH="$MISMATCH kanban(exp=$EXP_KANBAN live=${LIVE_KANBAN:-<none>})"

      if [ -z "$MISMATCH" ]; then
        record_check "live-pids-stable" 0
      else
        record_check "live-pids-stable" 1 "pid mismatch:$MISMATCH"
      fi
    fi
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 16. proxy-state-settled -- com.ohama.kanban-proxy, added by 06-04.1.
# Health must never rest on `state = running` alone: a job stuck in a
# KeepAlive restart loop reports `running` on almost every sample taken
# mid-loop. Require the SAME pid across two samples >=10s apart, the same
# discipline restart_service.sh's own portless-label health poll uses. A
# pid that changes between samples is a FAIL ("restarting rather than
# settling"), never a pass.
# ---------------------------------------------------------------------------
vlog "--- 16: proxy-state-settled ---"
PROXY_PRINT1="$(launchctl print "gui/$UID_NUM/$KANBAN_PROXY_LABEL" 2>&1)"
PROXY_STATE1="$(printf '%s\n' "$PROXY_PRINT1" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
PROXY_PID1="$(printf '%s\n' "$PROXY_PRINT1" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}')"
if [ "$PROXY_STATE1" != "running" ] || [ -z "$PROXY_PID1" ]; then
  record_check "proxy-state-settled" 1 "$KANBAN_PROXY_LABEL not running with a pid at first sample (state=${PROXY_STATE1:-<none>})"
else
  sleep 10
  PROXY_PRINT2="$(launchctl print "gui/$UID_NUM/$KANBAN_PROXY_LABEL" 2>&1)"
  PROXY_STATE2="$(printf '%s\n' "$PROXY_PRINT2" | grep -E '^[[:space:]]*state ' | head -1 | awk -F'= ' '{print $2}')"
  PROXY_PID2="$(printf '%s\n' "$PROXY_PRINT2" | grep -E '^[[:space:]]*pid ' | head -1 | awk -F'= ' '{print $2}')"
  if [ "$PROXY_STATE2" = "running" ] && [ -n "$PROXY_PID2" ] && [ "$PROXY_PID2" = "$PROXY_PID1" ]; then
    record_check "proxy-state-settled" 0
  else
    record_check "proxy-state-settled" 1 "pid=$PROXY_PID1 at first sample, state=${PROXY_STATE2:-<none>} pid=${PROXY_PID2:-<none>} 10s later -- restarting rather than settling"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 17. proxy-bind-loopback-only -- NET-02's half for the new component:
# adding a piece to the chain must not add a LAN path. Exactly one
# 127.0.0.1:$KANBAN_PROXY_PORT LISTEN line, no wildcard line, and the
# listening pid equals check 16's settled pid.
# ---------------------------------------------------------------------------
vlog "--- 17: proxy-bind-loopback-only ---"
PROXY_LISTEN="$(lsof -nP -iTCP:"$KANBAN_PROXY_PORT" -sTCP:LISTEN 2>/dev/null)"
PROXY_LISTEN_PID="$(printf '%s\n' "$PROXY_LISTEN" | awk 'NR==2{print $2}')"
if printf '%s\n' "$PROXY_LISTEN" | grep -q "127.0.0.1:${KANBAN_PROXY_PORT} " \
  && ! printf '%s\n' "$PROXY_LISTEN" | grep -q "\*:${KANBAN_PROXY_PORT} " \
  && [ -n "$PROXY_LISTEN_PID" ] && [ "$PROXY_LISTEN_PID" = "${PROXY_PID2:-$PROXY_PID1}" ]; then
  record_check "proxy-bind-loopback-only" 0
else
  record_check "proxy-bind-loopback-only" 1 "lsof=$(printf '%s' "$PROXY_LISTEN" | tr '\n' ';') expected_pid=${PROXY_PID2:-$PROXY_PID1}"
fi
vlog ""

# ---------------------------------------------------------------------------
# 18. proxy-rewrites-host -- the proxy turns kanban's own 403 into a real
# 200 for the tailnet Host, reusing check 10's own board-markup predicate
# rather than inventing a second one.
# ---------------------------------------------------------------------------
vlog "--- 18: proxy-rewrites-host ---"
PROXY_BODY18="$(curl -s -m 10 -w '\n%{http_code}' -H "Host: $TAILNET_HOSTNAME:$TS_SERVE_PORT" "http://127.0.0.1:$KANBAN_PROXY_PORT/")"
PROXY_CODE18="$(printf '%s\n' "$PROXY_BODY18" | tail -1)"
PROXY_HTML18="$(printf '%s\n' "$PROXY_BODY18" | sed '$d')"
if [ "$PROXY_CODE18" = "200" ] \
  && printf '%s' "$PROXY_HTML18" | grep -qi "kanban\|<!doctype html\|<html" \
  && ! printf '%s' "$PROXY_HTML18" | grep -q "Host not allowed\."; then
  record_check "proxy-rewrites-host" 0
else
  record_check "proxy-rewrites-host" 1 "http_code=${PROXY_CODE18:-<none>}"
fi
vlog ""

# ---------------------------------------------------------------------------
# 19. proxy-rejects-unknown-host -- the proxy's own gate rejects, itself,
# without ever forwarding upstream.
# ---------------------------------------------------------------------------
vlog "--- 19: proxy-rejects-unknown-host ---"
PROXY_BODY19="$(curl -s -m 10 -w '\n%{http_code}' -H 'Host: evil.invalid' "http://127.0.0.1:$KANBAN_PROXY_PORT/")"
PROXY_CODE19="$(printf '%s\n' "$PROXY_BODY19" | tail -1)"
PROXY_JSON19="$(printf '%s\n' "$PROXY_BODY19" | sed '$d')"
if [ "$PROXY_CODE19" = "403" ] && [ "$PROXY_JSON19" = '{"error":"Host not allowed."}' ]; then
  record_check "proxy-rejects-unknown-host" 0
else
  record_check "proxy-rejects-unknown-host" 1 "http_code=${PROXY_CODE19:-<none>} body=$PROXY_JSON19"
fi
vlog ""

# ---------------------------------------------------------------------------
# 20. proxy-rejects-unknown-origin -- same shape, Origin instead of Host.
# ---------------------------------------------------------------------------
vlog "--- 20: proxy-rejects-unknown-origin ---"
PROXY_BODY20="$(curl -s -m 10 -w '\n%{http_code}' -H "Host: $TAILNET_HOSTNAME:$TS_SERVE_PORT" -H 'Origin: https://evil.invalid' "http://127.0.0.1:$KANBAN_PROXY_PORT/")"
PROXY_CODE20="$(printf '%s\n' "$PROXY_BODY20" | tail -1)"
PROXY_JSON20="$(printf '%s\n' "$PROXY_BODY20" | sed '$d')"
if [ "$PROXY_CODE20" = "403" ] && [ "$PROXY_JSON20" = '{"error":"Origin not allowed."}' ]; then
  record_check "proxy-rejects-unknown-origin" 0
else
  record_check "proxy-rejects-unknown-origin" 1 "http_code=${PROXY_CODE20:-<none>} body=$PROXY_JSON20"
fi
vlog ""

# ---------------------------------------------------------------------------
# 21. proxy-websocket-upgrade -- the WebSocket path is what makes live card
# updates work, not just the first page load. rc=2 (CRASHED, never a
# silent pass) if node or probe_proxy.js is missing.
# ---------------------------------------------------------------------------
vlog "--- 21: proxy-websocket-upgrade ---"
PROBE_SCRIPT="$PROJECT_ROOT/phase-06/net/probe_proxy.js"
if [ ! -x "$NODE_BIN" ] && [ ! -f "$NODE_BIN" ]; then
  record_check "proxy-websocket-upgrade" 2 "NODE_BIN not found: $NODE_BIN"
elif [ ! -f "$PROBE_SCRIPT" ]; then
  record_check "proxy-websocket-upgrade" 2 "probe_proxy.js not found: $PROBE_SCRIPT"
else
  PROBE21_OUT="$("$NODE_BIN" "$PROBE_SCRIPT" \
    --url "http://127.0.0.1:$KANBAN_PROXY_PORT/api/runtime/ws" \
    --host "$TAILNET_HOSTNAME:$TS_SERVE_PORT" \
    --origin "https://$TAILNET_HOSTNAME:$TS_SERVE_PORT" \
    --expect-upgrade 2>&1)"
  PROBE21_RC=$?
  if [ "$PROBE21_RC" -eq 0 ] && [ "$PROBE21_OUT" = "UPGRADE status=101" ]; then
    record_check "proxy-websocket-upgrade" 0
  else
    record_check "proxy-websocket-upgrade" 1 "rc=$PROBE21_RC out=$PROBE21_OUT"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 22. proxy-lan-refused -- the proxy's half of NET-02: adding a component
# to the chain must not add a LAN path. rc=2 if no LAN IP could be derived.
# ---------------------------------------------------------------------------
vlog "--- 22: proxy-lan-refused ---"
if [ -z "$LAN_IP" ]; then
  record_check "proxy-lan-refused" 2 "no LAN IP could be derived (en0/en1 both empty)"
else
  HTTP_CODE22="$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$LAN_IP:$KANBAN_PROXY_PORT/")"
  CURL22_RC=$?
  if [ "$CURL22_RC" -eq 7 ] || [ "$CURL22_RC" -eq 28 ]; then
    record_check "proxy-lan-refused" 0
  elif [ "$CURL22_RC" -eq 0 ]; then
    record_check "proxy-lan-refused" 1 "reachable from LAN ($LAN_IP), http_code=$HTTP_CODE22 -- expected connection refused/timeout"
  else
    record_check "proxy-lan-refused" 1 "unexpected curl rc=$CURL22_RC"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 23. proxy-pin-gate -- same plutil -convert json + python3 idiom
# verify_services.sh's pin-gate-* checks use, applied to the installed
# proxy plist: both CLINE_NO_AUTO_UPDATE=1 and KANBAN_NO_AUTO_UPDATE=1 must
# be present (check_versions.sh Check C requires both once a plist's
# Program/ProgramArguments contain the substring "kanban", which this
# wrapper's path does).
# ---------------------------------------------------------------------------
vlog "--- 23: proxy-pin-gate ---"
PROXY_PLIST="$LAUNCH_AGENTS_DIR/$KANBAN_PROXY_LABEL.plist"
if [ ! -f "$PROXY_PLIST" ]; then
  record_check "proxy-pin-gate" 1 "plist not found: $PROXY_PLIST"
else
  PIN23_RESULT="$(plutil -convert json -o - "$PROXY_PLIST" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("CRASH:" + str(e))
    sys.exit(0)
env = d.get("EnvironmentVariables") or {}
c = str(env.get("CLINE_NO_AUTO_UPDATE"))
k = str(env.get("KANBAN_NO_AUTO_UPDATE"))
if c == "1" and k == "1":
    print("OK")
else:
    print("FAIL cline=%s kanban=%s" % (c, k))
')"
  if [ -z "$PIN23_RESULT" ]; then
    record_check "proxy-pin-gate" 2 "plutil/python3 produced no output for $PROXY_PLIST"
  elif [[ "$PIN23_RESULT" == CRASH:* ]]; then
    record_check "proxy-pin-gate" 2 "$PIN23_RESULT"
  elif [ "$PIN23_RESULT" = "OK" ]; then
    record_check "proxy-pin-gate" 0
  else
    record_check "proxy-pin-gate" 1 "$PIN23_RESULT"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# 24. tailnet-websocket-101 -- the server-side proof that live card updates
# survive the WHOLE chain (Serve -> proxy -> kanban), not just the loopback
# half. This is EXPECTED TO FAIL while the network is closed -- that is the
# point of the negative control, the same shape as checks 4 and 9.
# ---------------------------------------------------------------------------
vlog "--- 24: tailnet-websocket-101 ---"
if [ ! -f "$PROBE_SCRIPT" ]; then
  record_check "tailnet-websocket-101" 2 "probe_proxy.js not found: $PROBE_SCRIPT"
else
  PROBE24_OUT="$("$NODE_BIN" "$PROBE_SCRIPT" \
    --url "https://$TAILNET_HOSTNAME:$TS_SERVE_PORT/api/runtime/ws" \
    --host "$TAILNET_HOSTNAME:$TS_SERVE_PORT" \
    --origin "https://$TAILNET_HOSTNAME:$TS_SERVE_PORT" \
    --expect-upgrade 2>&1)"
  PROBE24_RC=$?
  if [ "$PROBE24_RC" -eq 0 ] && [ "$PROBE24_OUT" = "UPGRADE status=101" ]; then
    record_check "tailnet-websocket-101" 0
  else
    record_check "tailnet-websocket-101" 1 "rc=$PROBE24_RC out=$PROBE24_OUT -- expected while the network is closed (06-04.2 opens it)"
  fi
fi
vlog ""

# ---------------------------------------------------------------------------
# Final verdict.
# ---------------------------------------------------------------------------
TOTAL=${#CASE_IDS[@]}
PASSED=0
FAILED=0
CRASHED=0
for i in "${!CASE_RCS[@]}"; do
  rc="${CASE_RCS[$i]}"
  if [ "$rc" = "0" ]; then
    PASSED=$((PASSED + 1))
  elif [ "$rc" = "2" ]; then
    CRASHED=$((CRASHED + 1))
    FAILED=$((FAILED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

vlog "CASES $PASSED/$TOTAL"
vlog "CRASHED $CRASHED"

if [ "$CRASHED" -gt 0 ]; then
  vlog "VERIFY_NETWORK: INCONCLUSIVE (crashed=$CRASHED)"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 2
elif [ "$FAILED" -gt 0 ]; then
  vlog "VERIFY_NETWORK: FAIL"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 1
else
  vlog "VERIFY_NETWORK: PASS"
  echo "RESULTS_DIR=$OUT_DIR"
  exit 0
fi
