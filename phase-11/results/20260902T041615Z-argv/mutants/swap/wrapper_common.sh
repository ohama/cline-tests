#!/usr/bin/env bash
# phase-11/wrapper_common.sh — sourced by cline-plan and cline-act after they set
# WRAPPER_SELF, WRAPPER_MODE_FLAG and WRAPPER_ALIAS. Holds the shared deny-by-default
# argument parser and the SINGLE construction site of the real `cline` invocation, so
# the two wrappers cannot drift apart in how they handle arguments.
#
# Exit-code contract (identical across cline-plan / cline-act / this file):
#   0..N = the real cline binary's own exit code, forwarded unchanged
#   2    = refused argument or usage error — the real binary was NEVER invoked
#   3    = pre-run config guard failed — the real binary was NEVER invoked
#   4    = post-run config guard failed — NOTE this is NOT cline's own exit code;
#          cline may have exited 0 and this wrapper still exits 4 to surface the guard failure
#
# DENY-BY-DEFAULT, NOT A BLOCKLIST.
# CFG-05 (cline's auto-update is not actually blocked) means the installed binary's flag
# surface can change at any time without anyone asking: `-p`/`--plan` and `--thinking <level>`
# BOTH appeared, unannounced, somewhere between 3.0.53 and 3.0.60
# (.planning/phases/11-usage-surface-wrappers/11-RESEARCH.md Q2 — re-verified live against the
# installed binary). A blocklist of "known-bad" flags written today is, by construction, a list
# that goes stale the very next time the binary drifts. So this parser instead accepts exactly
# four option shapes (-t/--timeout, -c/--cwd, --json, --) and refuses every other argument that
# begins with `-`, unconditionally, whether or not we have ever heard of it before.
#
# REJECT, NEVER STRIP.
# Silently dropping a flag the caller explicitly typed is the same silent-success failure shape
# CFG-14 bans `drop_params` for, and phase-10/ALIAS-DESIGN.md §4 names again: a rejected
# parameter that still quietly runs (as if nothing had been typed) manufactures false confidence
# — the caller has been lied to about what ran. A caller who types `--thinking high` is told so,
# by name, on stderr, with exit 2, and the real binary is never invoked at all.

set -euo pipefail

: "${WRAPPER_SELF:?wrapper_common.sh requires WRAPPER_SELF to be set by the caller}"
: "${WRAPPER_MODE_FLAG:=}"
: "${WRAPPER_ALIAS:?wrapper_common.sh requires WRAPPER_ALIAS to be set by the caller}"
: "${HERE:?wrapper_common.sh requires HERE (the phase-11 directory) to be set by the caller}"

REPO_ROOT="$(cd "$HERE/.." && pwd)"
VERIFY_CONFIG_SH="$REPO_ROOT/phase-01/config/verify_config.sh"
APPLY_CONFIG_SH="$REPO_ROOT/phase-01/config/apply_provider_config.sh"

usage() {
  echo "usage: $WRAPPER_SELF [-t|--timeout <secs>] [-c|--cwd <path>] [--json] [--] <prompt...>" >&2
}

refuse() {
  # $1 = fully-formed message. Loud refusal, never a silent strip: the caller must see exactly
  # what was rejected and why, and nothing downstream of this call runs.
  echo "REFUSED: $1" >&2
  usage
  exit 2
}

TIMEOUT="$WRAPPER_DEFAULT_TIMEOUT"
CWD=""
JSON_FLAG=""
PROMPT_PARTS=()
END_OF_OPTS=""

while [ $# -gt 0 ]; do
  if [ -n "$END_OF_OPTS" ]; then
    PROMPT_PARTS+=("$1")
    shift
    continue
  fi
  case "$1" in
    --)
      END_OF_OPTS=1
      shift
      ;;
    -t|--timeout)
      [ $# -ge 2 ] || refuse "$1 requires a value"
      TIMEOUT="$2"
      shift 2
      ;;
    -c|--cwd)
      [ $# -ge 2 ] || refuse "$1 requires a value"
      CWD="$2"
      shift 2
      ;;
    --json)
      JSON_FLAG=1
      shift
      ;;
    -m|--model)
      refuse "$WRAPPER_SELF does not accept '-m/--model'. The alias is fixed by phase-11/wrapper.env (currently: $WRAPPER_ALIAS) — that pairing is the whole point of this wrapper (USE-01)."
      ;;
    -P|--provider)
      refuse "$WRAPPER_SELF does not accept '-P/--provider'. The provider is fixed to $WRAPPER_PROVIDER by phase-11/wrapper.env."
      ;;
    --thinking|--thinking=*)
      refuse "$WRAPPER_SELF does not accept '--thinking'. Reasoning effort is injected server-side by the litellm alias. litellm merges client kwargs AFTER the alias's litellm_params (phase-10/ALIAS-DESIGN.md §3), so a client-sent reasoning_effort OVERRIDES the alias — using --thinking silently bypasses this wrapper's guarantee. See .planning/REQUIREMENTS.md CFG-11, 2026-09-02 correction."
      ;;
    -p|--plan)
      refuse "$WRAPPER_SELF does not accept '-p/--plan'. The mode flag is fixed by which wrapper you invoked."
      ;;
    -*)
      refuse "unrecognised argument '$1' — $WRAPPER_SELF only accepts -t/--timeout, -c/--cwd, --json and --"
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

if [ ${#PROMPT_PARTS[@]} -eq 0 ]; then
  refuse "no prompt given"
fi

OLDIFS="$IFS"
IFS=' '
PROMPT="${PROMPT_PARTS[*]}"
IFS="$OLDIFS"

case "$PROMPT" in
  -*)
    refuse "the prompt '$PROMPT' begins with '-' and would be re-parsed as a flag by the real binary"
    ;;
esac

# --- test hook: explicitly not a bypass ---
# Substitutes $CLINE_WRAPPER_TEST_BIN for $WRAPPER_CLINE_BIN ONLY when CLINE_WRAPPER_TEST=1 is
# ALSO set, and announces itself on stderr every time it does. A silent override would be a way
# for the real binary to be swapped out without anyone noticing — that must never happen quietly.
CMD="$WRAPPER_CLINE_BIN"
if [ "${CLINE_WRAPPER_TEST:-}" = "1" ]; then
  : "${CLINE_WRAPPER_TEST_BIN:?CLINE_WRAPPER_TEST=1 requires CLINE_WRAPPER_TEST_BIN to be set}"
  echo "[TEST MODE] using $CLINE_WRAPPER_TEST_BIN instead of $WRAPPER_CLINE_BIN" >&2
  CMD="$CLINE_WRAPPER_TEST_BIN"
fi

# --- config guard cycle (docs/headless-wrapper.md §7's standing pattern), skipped in test mode ---
# VERIFY_CONFIG_NO_WRAPPER_CHECK=1 is the recursion brake: plan 11-03 will make verify_config.sh
# itself exercise these wrappers, and these wrappers call verify_config.sh here. Exporting this
# on every internal guard call is what stops that from recursing forever. Written now, even though
# nothing reads it yet, because 11-03 and 11-04 depend on it already being here.
if [ "${CLINE_WRAPPER_TEST:-}" != "1" ]; then
  PRECHECK_RC=0
  PRECHECK_OUT="$(VERIFY_CONFIG_NO_WRAPPER_CHECK=1 "$VERIFY_CONFIG_SH" 2>&1)" || PRECHECK_RC=$?
  if [ "$PRECHECK_RC" -ne 0 ]; then
    echo "$PRECHECK_OUT" >&2
    echo "REFUSED: pre-run config guard failed (exit $PRECHECK_RC). Nothing was invoked. Run: $APPLY_CONFIG_SH" >&2
    exit 3
  fi
fi

# --- construction site: the ONLY place the binary is named ---
set -- -P "$WRAPPER_PROVIDER"
[ -n "$WRAPPER_MODE_FLAG" ] && set -- "$@" "$WRAPPER_MODE_FLAG"
set -- "$@" -m "$WRAPPER_ALIAS" --compaction "$WRAPPER_COMPACTION" -t "$TIMEOUT"
[ -n "$JSON_FLAG" ] && set -- "$@" --json
[ -n "$CWD" ] && set -- "$@" -c "$CWD"
set -- "$@" "$PROMPT"

# CLINE_NO_AUTO_UPDATE=1: not proven to work (CFG-05 is unresolved — the binary drifted
# 3.0.53->3.0.60 anyway) but a version change mid-use would silently invalidate every pinned
# fact this wrapper rests on (phase-10/probe_vrf04_cline.sh sets it for the same reason).
CLINE_RC=0
CLINE_NO_AUTO_UPDATE=1 "$CMD" "$@" || CLINE_RC=$?

if [ "${CLINE_WRAPPER_TEST:-}" != "1" ]; then
  POSTCHECK_RC=0
  POSTCHECK_OUT="$(VERIFY_CONFIG_NO_WRAPPER_CHECK=1 "$VERIFY_CONFIG_SH" 2>&1)" || POSTCHECK_RC=$?
  if [ "$POSTCHECK_RC" -ne 0 ]; then
    echo "$POSTCHECK_OUT" >&2
    echo "WARNING[CONFIG]: cline exited $CLINE_RC, but the post-run config guard failed" >&2
    exit 4
  fi
fi

exit "$CLINE_RC"
