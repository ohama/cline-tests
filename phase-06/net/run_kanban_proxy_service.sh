#!/bin/bash
# phase-06/net/run_kanban_proxy_service.sh
#
# This file is ProgramArguments[1] of
# ~/Library/LaunchAgents/com.ohama.kanban-proxy.plist (ProgramArguments[0]
# is /bin/bash). It is never called by hand except for testing (Task 1's
# scratch-port smoke test invoked the node script directly, not through
# this wrapper).
#
# NEVER `kill`/pkill this service; never `launchctl load`/`unload`/`kickstart`.
# Restart is phase-02/infra/restart_service.sh com.ohama.kanban-proxy 18484;
# take-down is `launchctl bootout gui/$(id -u)/com.ohama.kanban-proxy`.
#
# NEVER widen the sandbox from here. EXTRA_ALLOW_PATHS is empty and this
# wrapper does not need it.
#
# Two deliberate differences from phase-05/services/run_kanban_service.sh,
# the plist this wrapper's shape is otherwise modeled on:
#
#   1. NO run_sandboxed.sh. The sandbox profile (workspace/sandbox.sb) is
#      `(allow default)` with $HOME denied except two punched subpaths
#      (workspace/scratch-repo and ~/.cline). This proxy's own source lives
#      at phase-06/net/kanban_host_proxy.js, under $HOME and NOT punched,
#      so a sandboxed node could not even read its own entry point — making
#      it work would require widening EXTRA_ALLOW_PATHS, which is
#      forbidden and stays empty for this whole plan. The sandbox exists to
#      confine agent-driven code execution (cline, kanban's own task
#      runner); this process executes no user-supplied or agent-supplied
#      code at all — it forwards bytes between two loopback sockets and
#      touches no filesystem path at runtime beyond its own log fds, which
#      launchd itself opens before exec.
#   2. NO upstream readiness wait. run_kanban_service.sh blocks on
#      wait_for_upstream.sh because kanban needs flashnext before it is
#      useful. This proxy must bind its port whether or not kanban is up —
#      a proxy that refused to start when its backend was down would
#      crash-loop exactly when it is most needed (e.g. while kanban itself
#      is mid-restart), and would make restart_service.sh's port poll time
#      out waiting for a listener that will never appear. A per-connection
#      upstream failure surfaces as a 502 from kanban_host_proxy.js's own
#      'error' handler, not as a dead proxy service.
#
# macOS /bin/bash is 3.2 — indexed arrays only, no `declare -A`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=config.env
source "$PROJECT_ROOT/phase-06/net/config.env"

# Defensive: the plist also sets both of these, but a hand-run wrapper must
# be equally protected. Both are required by phase-01/config/check_versions.sh
# Check C, which lowercases the joined Program/ProgramArguments of every
# installed plist and, on the substring "kanban" (this wrapper's own path
# contains it), requires BOTH CLINE_NO_AUTO_UPDATE=1 and
# KANBAN_NO_AUTO_UPDATE=1 — omitting either makes verify_config.sh FAIL the
# moment this plist installs, even though this process never actually
# invokes cline or kanban itself.
export CLINE_NO_AUTO_UPDATE=1
export KANBAN_NO_AUTO_UPDATE=1

mkdir -p "$SERVICE_LOG_DIR"

# Layer 2 of the three independent loopback-bind guarantees this project
# mandates for this proxy (layer 1: kanban_host_proxy.js itself refuses to
# start unless its own env var is literally 127.0.0.1; layer 3:
# verify_network.sh's own lsof check). Abort here too, before ever
# exec-ing node, rather than relying on the JS-level check alone.
if [ "$KANBAN_PROXY_HOST" != "127.0.0.1" ]; then
  echo "ABORT: KANBAN_PROXY_HOST must be exactly 127.0.0.1 (refusing to start a proxy that could bind a wildcard address)." >&2
  exit 1
fi

# Export every PROXY_*/KANBAN_PROXY_* variable the JS reads. All are already
# exported by phase-06/net/config.env (sourced above), which itself sources
# phase-05/services/config.env for KANBAN_PROXY_PORT/KANBAN_HOST/KANBAN_PORT
# — nothing here re-derives a value already owned by one of those two
# files.
export KANBAN_PROXY_HOST KANBAN_PROXY_PORT
export PROXY_UPSTREAM_HOST_HEADER PROXY_UPSTREAM_ORIGIN
export PROXY_ALLOWED_HOSTS PROXY_ALLOWED_ORIGINS
export KANBAN_HOST KANBAN_PORT

# Final line — this script `exec`s so the supervised pid IS the node
# process, exactly as run_kanban_service.sh does for kanban itself. This is
# what makes the take-down/restore test and the pid-stability sampling in
# both restart_service.sh and verify_network.sh check 16 meaningful.
exec "$NODE_BIN" "$KANBAN_PROXY_SCRIPT"
