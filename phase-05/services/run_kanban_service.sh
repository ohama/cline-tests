#!/bin/bash
# phase-05/services/run_kanban_service.sh
#
# This file is ProgramArguments[1] of ~/Library/LaunchAgents/com.ohama.kanban.plist
# (ProgramArguments[0] is /bin/bash). It is never called by hand except for
# testing.
#
# THE CWD RULE (docs/headless-wrapper.md §6): the OS-level process cwd must
# ALREADY be inside workspace/ALLOWED_REPOS.json or Bun/Node dies during
# startup with a path-less generic error that looks exactly like a sandbox
# tightening. The plist sets WorkingDirectory AND this script `cd`s and
# asserts — belt and braces, because the plist alone silently fails if the
# directory is missing.
#
# NEVER `kill`/pkill this service; never `launchctl load`/`unload`/`kickstart`.
# Restart is phase-02/infra/restart_service.sh com.ohama.kanban 3484;
# take-down is `launchctl bootout gui/$(id -u)/com.ohama.kanban`.
#
# NEVER launch kanban through cline's own launcher subcommand for it. That
# subcommand has its own auto-install fallback (`npm install -g
# kanban@latest`) and is a silent drift vector off the pinned 0.1.70. Always
# the standalone binary (see KANBAN_BIN below, used only on the exec line).
#
# NEVER widen the sandbox from here. EXTRA_ALLOW_PATHS is empty and this
# wrapper does not need it.
#
# macOS /bin/bash is 3.2 — indexed arrays only, no `declare -A`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=config.env
source "$PROJECT_ROOT/phase-05/services/config.env"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/phase-01/config/cline-invocation.env"

# Defensive: the plist also sets both of these, but a hand-run wrapper must
# be equally protected. KANBAN_NO_AUTO_UPDATE=1 is kanban's OWN, SEPARATE
# auto-update gate (confirmed via `strings`: env2.KANBAN_NO_AUTO_UPDATE ===
# "1") — CLINE_NO_AUTO_UPDATE does not cover it.
export CLINE_NO_AUTO_UPDATE=1
export KANBAN_NO_AUTO_UPDATE=1

mkdir -p "$SERVICE_LOG_DIR" "$SANDBOX_WORKDIR"
cd "$SANDBOX_WORKDIR"

# Assert $PWD is a prefix-match of some repos[] entry in ALLOWED_REPOS_JSON
# — same python3 idiom as phase-04/run_headless.sh step 5.
WORKDIR_OK="$(python3 -c '
import json, os, sys

pwd = os.path.realpath(sys.argv[1])
allowed_repos_json = sys.argv[2]

with open(allowed_repos_json) as f:
    data = json.load(f)

repos = data.get("repos", [])
for r in repos:
    rp = os.path.realpath(r)
    if pwd == rp or pwd.startswith(rp + os.sep):
        print("OK")
        sys.exit(0)

print("FAIL")
sys.exit(1)
' "$PWD" "$ALLOWED_REPOS_JSON")"
WORKDIR_STATUS=$?

if [ "$WORKDIR_STATUS" -ne 0 ] || [ "$WORKDIR_OK" != "OK" ]; then
  echo "ABORT: process cwd ($PWD) is not a prefix match of any repos[] entry in $ALLOWED_REPOS_JSON — refusing to invoke kanban (THE CWD RULE)." >&2
  exit 1
fi

# Bounded upstream readiness wait — NOT wait_for_port.sh directly, and NOT a
# TCP probe of litellm's :4000: litellm binds its listener whether or not
# flashnext has loaded, so that would report ready instantly in exactly the
# scenario ROADMAP criterion 3 describes. This is the SVC-04 mechanism: the
# wrapper, not launchd, absorbs the flashnext-not-loaded window, so the
# retry cadence is roughly one process spawn per (timeout + ThrottleInterval),
# not a tight loop.
if ! bash "$SCRIPT_DIR/wait_for_upstream.sh" "$UPSTREAM_WAIT_TIMEOUT" "$UPSTREAM_WAIT_INTERVAL"; then
  echo "ABORT: flashnext still not ready after ${UPSTREAM_WAIT_TIMEOUT}s (see stderr above for which stage failed) — launchd will retry the whole cycle after ThrottleInterval." >&2
  exit 1
fi

# Final line — this script `exec`s so the supervised pid IS the kanban
# process (the pid is preserved all the way through: this script hands off
# to the sandbox wrapper below, which itself hands off to sandbox-exec,
# which hands off to kanban), which is what makes the SVC-03 kill test and
# the anti-orphan check meaningful.
#
# --no-open (no browser under launchd). --port 3484 pinned explicitly, never
# `auto`.
#
# Deliberately NOT passed:
#   --no-passcode          kanban auto-generates a remote-access passcode by
#                           default; Phase 6's NET-02 will build ON that, not
#                           around it.
#   --skip-shutdown-cleanup  default behavior (move sessions to done, delete
#                           task worktrees on shutdown) is acceptable/desired
#                           for a repeatedly-restarted service.
#   --https/--cert/--key   Phase 6's concern, not this plan's.
#   --update                would self-update off the pinned 0.1.70.
exec "$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh" -- \
  "$KANBAN_BIN" --no-open --host "$KANBAN_HOST" --port "$KANBAN_PORT"
