#!/usr/bin/env bash
#
# run_sandboxed.sh — the single public entry point for phase-03. This is the
# documented interface Phase 4 consumes.
#
# USAGE:
#   run_sandboxed.sh [--dry-run] [--profile-out <path>] -- <command> [args...]
#   run_sandboxed.sh [--dry-run] [--profile-out <path>] <command> [args...]
#     (the -- separator is optional; anything after the recognized flags is
#     treated as the command to run)
#
# CONTRACT FOR CALLERS (Phase 4):
#   (a) Exact invocation form: source nothing yourself, just call this script
#       with the command to sandbox, e.g.:
#         phase-03/sandbox/run_sandboxed.sh -- cline --some-flag ...
#   (b) The exit code and stderr you see belong to the WRAPPED command, not
#       to this wrapper -- this script `exec`s sandbox-exec so the wrapped
#       process's pid, exit code, and stderr/stdout pass through untouched.
#       An exit code from THIS script itself (before the exec) only happens
#       if profile generation fails (see "fail closed" below).
#   (c) SCOPE LIMITATION (stated, not hidden, copied from config.env): the
#       generated profile uses `(allow default)` with an explicit deny on
#       PROTECTED_ROOT. It protects $HOME. It is NOT a total-deny jail --
#       anything outside $HOME (/tmp, /opt, /usr/local, and any externally
#       mounted volume or network share) stays readable and writable by the
#       sandboxed process. This is an accepted, deliberate scope boundary;
#       revisit only if the machine's storage layout changes.
#   (d) `phase-03/sandbox/verify_sandbox.sh` (built in plan 03-03) is the
#       standing gate to call before trusting this wrapper -- run it, don't
#       assume this script's own behavior is still correct after any edit.
#   (e) EXTRA_ALLOW_PATHS in config.env is the ONLY sanctioned widening
#       point. Do not add ad-hoc punch-throughs anywhere else.
#
# WHY THE PROFILE IS ALWAYS REGENERATED, NEVER CACHED:
#   03-RESEARCH.md: caching reintroduces exactly the "whitelist silently
#   failed to regenerate after a repo was added" drift risk this phase
#   exists to design out. Generation is a sub-millisecond JSON parse -- there
#   is no performance reason to cache it, and every reason not to. There is
#   NO code path in this script that reuses an existing profile.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$SCRIPT_DIR/config.env"

usage() {
  cat >&2 <<'USAGE'
Usage: run_sandboxed.sh [--dry-run] [--profile-out <path>] [--] <command> [args...]
USAGE
}

DRY_RUN=0
PROFILE_OUT="$SANDBOX_PROFILE"

# Parse only our own recognized flags; the first unrecognized token (or --)
# ends flag parsing and everything remaining is the wrapped command.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --profile-out)
      PROFILE_OUT="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

# EXTRA_ALLOW_PATHS is colon-separated. The executing shell may be zsh (which
# does NOT word-split unquoted variables the way bash does), so do the
# splitting here, inside this bash script, with IFS and an indexed array --
# never rely on the caller's shell. macOS /bin/bash is 3.2, so no
# declare -A / associative arrays are used anywhere in this script.
EXTRA_ALLOW_ARGS=()
if [ -n "${EXTRA_ALLOW_PATHS:-}" ]; then
  IFS=':' read -r -a _extra_allow_arr <<< "$EXTRA_ALLOW_PATHS"
  for _p in "${_extra_allow_arr[@]}"; do
    if [ -n "$_p" ]; then
      EXTRA_ALLOW_ARGS+=(--extra-allow "$_p")
    fi
  done
fi

GEN_CMD=(python3 "$SCRIPT_DIR/gen_sandbox_profile.py"
  --allowed-repos "$ALLOWED_REPOS_JSON"
  --protected-root "$PROTECTED_ROOT"
  --extra-allow "$CLINE_DATA_DIR"
  "${EXTRA_ALLOW_ARGS[@]+"${EXTRA_ALLOW_ARGS[@]}"}"
  --out "$PROFILE_OUT")

SANDBOX_EXEC_CMD=(/usr/bin/sandbox-exec -f "$PROFILE_OUT" -- "$@")

if [ "$DRY_RUN" -eq 1 ]; then
  # Still regenerate the profile (so --dry-run reflects reality), but print
  # the command instead of exec'ing it.
  if ! "${GEN_CMD[@]}"; then
    echo "run_sandboxed.sh: profile generation failed; aborting (fail closed, dry-run)" >&2
    exit 1
  fi
  printf '%q ' "${SANDBOX_EXEC_CMD[@]}"
  printf '\n'
  exit 0
fi

# ALWAYS regenerate the profile first, unconditionally. There is no
# [ -f "$PROFILE_OUT" ] guard here and there must never be one -- see the
# header comment above. If generation fails, abort BEFORE running anything:
# fail closed, never fall back to running the command unsandboxed.
if ! "${GEN_CMD[@]}"; then
  echo "run_sandboxed.sh: profile generation failed; aborting (fail closed, command NOT run)" >&2
  exit 1
fi

exec "${SANDBOX_EXEC_CMD[@]}"
