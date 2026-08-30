#!/bin/bash
# phase-05/services/run_telegram_service.sh
#
# This file is ProgramArguments[1] of
# ~/Library/LaunchAgents/com.ohama.telegram-connect.plist (ProgramArguments[0]
# is /bin/bash). It is never called by hand except for testing.
#
# THE CWD RULE (docs/headless-wrapper.md §6): the OS-level process cwd must
# ALREADY be inside workspace/ALLOWED_REPOS.json or Bun/Node dies during
# startup with a path-less generic error that looks exactly like a sandbox
# tightening. The plist sets WorkingDirectory AND this script `cd`s and
# asserts — belt and braces, because the plist alone silently fails if the
# directory is missing.
#
# NEVER `kill`/pkill this service; never `launchctl load`/`unload`/`kickstart`.
# Restart is phase-02/infra/restart_service.sh com.ohama.telegram-connect
# none (portless label); take-down is
# `launchctl bootout gui/$(id -u)/com.ohama.telegram-connect`.
#
# NEVER widen the sandbox from here. EXTRA_ALLOW_PATHS is empty and this
# wrapper does not need it.
#
# ============================================================================
# A. `cline connect telegram` SELF-DAEMONIZES BY DEFAULT.
#
# Without -i/--interactive it forks a detached child
# (CLINE_TELEGRAM_CONNECT_CHILD=1), prints "[telegram] starting background
# connector pid=<N>", and the parent — the process launchd is supervising —
# exits almost immediately. Under KeepAlive that either crash-loops the
# parent or leaks a NEW orphaned, unsupervised bot child every
# ThrottleInterval. -i IS MANDATORY HERE AND MUST NEVER BE REMOVED.
# (Confirmed via `strings` on the pinned 3.0.53; the same base-class
# behavior exists for every other `connect <channel>` subcommand.)
#
# B. THE "auto approve = false" POSTURE, TRANSLATED ONTO THE SURFACE THAT
#    ACTUALLY EXISTS.
#
# The boolean tool-auto-approval flag of the one-shot `cline <prompt>` mode
# (Phase 4) is NOT a flag of `cline connect telegram` — copying it here would be an
# ignored/invalid flag that silently leaves tools ENABLED, the exact
# opposite of the intent. The faithful translation on this surface is
# --no-tools (tools are enabled by default; --hook-command is the only
# other approval surface and it is mutually exclusive with
# --allowed-user-id). This is the settled decision carried over from
# docs/headless-wrapper.md §4/§8: the connector comes up, self-recovers and
# survives reboot, but stays intentionally inert for tool-using prompts. Do
# not add a switchable flag; revisiting the posture is Phase 6's, and it is
# a human decision.
# ============================================================================
#
# macOS /bin/bash is 3.2 — indexed arrays only, no `declare -A`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=config.env
source "$PROJECT_ROOT/phase-05/services/config.env"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/phase-01/config/cline-invocation.env"

export CLINE_NO_AUTO_UPDATE=1
export KANBAN_NO_AUTO_UPDATE=1

mkdir -p "$SERVICE_LOG_DIR" "$SANDBOX_WORKDIR"
cd "$SANDBOX_WORKDIR"

# Same python3 cwd assertion as the kanban wrapper.
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
  echo "ABORT: process cwd ($PWD) is not a prefix match of any repos[] entry in $ALLOWED_REPOS_JSON — refusing to invoke the telegram connector (THE CWD RULE)." >&2
  exit 1
fi

# ---- The empty-token idle branch — before anything else that could cost
# anything. Never generate, guess, or fabricate a token. The slot stays
# empty in this phase. -----------------------------------------------------
TOKEN="${TELEGRAM_BOT_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "run_telegram_service.sh: TELEGRAM_BOT_TOKEN is empty — this service is registered but intentionally INERT. cline is NOT being invoked." >&2
  echo "To activate: set TELEGRAM_BOT_TOKEN in phase-05/plists/com.ohama.telegram-connect.plist's EnvironmentVariables, re-run phase-05/services/install_services.sh com.ohama.telegram-connect, then phase-02/infra/restart_service.sh com.ohama.telegram-connect none. Never hand-edit ~/local-llm-settings/." >&2

  # Block WITHOUT spinning and WITHOUT exiting. The literal /bin/sleep
  # argument "infinity" is BANNED BY NAME — verified live on this machine,
  # macOS /bin/sleep rejects that word (`usage: sleep number[unit]`) and
  # returns instantly, which would turn this branch into a 100%-CPU spin.
  # Numeric seconds only. Exiting is equally wrong: `exit 0` under
  # KeepAlive: true relaunches immediately, which is a real crash loop by
  # definition, and `exit 1` is the same thing with a longer period.
  while :; do
    /bin/sleep "$IDLE_SLEEP_SECONDS" || /bin/sleep 60
  done
fi

# ---- Token is non-empty: bounded upstream readiness wait (identical
# mechanism to the kanban wrapper), then the real invocation. -------------
if ! bash "$SCRIPT_DIR/wait_for_upstream.sh" "$UPSTREAM_WAIT_TIMEOUT" "$UPSTREAM_WAIT_INTERVAL"; then
  echo "ABORT: flashnext still not ready after ${UPSTREAM_WAIT_TIMEOUT}s (see stderr above for which stage failed) — launchd will retry the whole cycle after ThrottleInterval." >&2
  exit 1
fi

# LONG FLAG NAMES ARE MANDATORY HERE AND THIS IS NOT COSMETIC. `cline
# connect telegram` is a DIFFERENT flag surface from the one-shot
# `cline <prompt>` mode that phase-01/config/cline-invocation.env's
# CLINE_COMMON_FLAGS targets. Verified live on the pinned 3.0.53: this
# subcommand has NO short provider flag at all (`cline connect telegram
# -Pfoobar` fails with `error: unknown option '-P'`, exit 1, thrown before
# the -k token check is even reached), and the short bot-name flag IS
# BOUND TO --bot-username, NOT --model. Only --provider <id> and --model
# <id> exist. Copying either short form across from the prompt surface
# would hard-fail at argv parsing on the very first launch after a real
# token is injected — i.e. it would crash-loop every ThrottleInterval,
# which is the exact failure this whole phase exists to design out, and it
# would only surface at the moment the user follows docs/services.md §6.
# NEVER ABBREVIATE THESE TWO FLAGS.
#
# -i and --no-tools as literal adjacent tokens below.
#
# TODO(Phase 6): add --allowed-user-id <digits> here — confirmed via
# `strings` that cline 3.0.53 does NOT itself refuse to start without it,
# so Phase 6's criterion 4 will need wrapper-level enforcement, not a CLI
# guarantee.
exec "$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh" -- \
  "$CLINE_BIN" connect telegram -k "$TOKEN" -i --no-tools \
  --provider "$CLINE_PROVIDER" --model "$CLINE_MODEL" --cwd "$SANDBOX_WORKDIR"
