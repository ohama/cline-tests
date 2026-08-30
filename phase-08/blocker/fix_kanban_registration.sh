#!/bin/bash
# phase-08/blocker/fix_kanban_registration.sh
#
# Half of the 08-01 no-widening fix (08-RESEARCH.md §A5). This script makes
# SANDBOX_WORKDIR (workspace/scratch-repo) its OWN git top-level, so that
# kanban's compiled resolveWorkspacePath() (dist/cli.js, confirmed in
# 08-RESEARCH.md §A4) no longer substitutes the outer repo root
# (/Users/ohama/projs/cline-tests) — the one path ALLOWED_REPOS.json's own
# comment permanently forbids adding, because bench/ lives under it and
# SBX-04 requires bench/ to stay unreachable from inside the sandbox.
#
# This script NEVER edits workspace/ALLOWED_REPOS.json, NEVER edits
# workspace/sandbox.sb, and NEVER sets EXTRA_ALLOW_PATHS. A .git directory
# appearing INSIDE an already-allowed subpath (workspace/scratch-repo is
# already repos[0] in ALLOWED_REPOS.json) is not a sandbox boundary change —
# it changes what git itself resolves as "top-level" for that subpath, not
# what the sandbox profile allows.
#
# Idempotent and re-runnable: if $SANDBOX_WORKDIR/.git already exists, this
# script prints "already-initialized" and changes nothing else.
#
# macOS /bin/bash is 3.2 — indexed arrays only, no `declare -A` (none used
# here).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=/dev/null
# Transitively provides SANDBOX_WORKDIR and ALLOWED_REPOS_JSON — do not
# re-derive either path here.
source "$PROJECT_ROOT/phase-05/services/config.env"

if [ -z "${SANDBOX_WORKDIR:-}" ]; then
  echo "ABORT: SANDBOX_WORKDIR is empty after sourcing phase-05/services/config.env" >&2
  exit 1
fi

mkdir -p "$SANDBOX_WORKDIR"

if [ ! -d "$SANDBOX_WORKDIR/.git" ]; then
  echo "initializing $SANDBOX_WORKDIR as its own git top-level"
  git init -b main "$SANDBOX_WORKDIR"
  git -C "$SANDBOX_WORKDIR" add -A
  # Author/committer supplied on the command line so the result does not
  # depend on ~/.gitconfig (which the sandbox denies — 08-RESEARCH.md §A2).
  git -C "$SANDBOX_WORKDIR" \
    -c user.name=kanban-scratch -c user.email=kanban-scratch@localhost \
    commit -m "init scratch repo (phase-08/01)"
else
  echo "already-initialized"
fi

# Assert the end state in BOTH paths (fresh init and already-initialized),
# and fail loudly otherwise. An initial commit is required, not optional:
# kanban calls `git log` and `git diff`, and both fail on an unborn branch.
REAL_WORKDIR="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$SANDBOX_WORKDIR")"
TOPLEVEL="$(git -C "$SANDBOX_WORKDIR" rev-parse --show-toplevel)"
if [ "$TOPLEVEL" != "$REAL_WORKDIR" ]; then
  echo "ABORT: git top-level for $SANDBOX_WORKDIR resolved to '$TOPLEVEL', expected '$REAL_WORKDIR'" >&2
  exit 1
fi

BRANCH="$(git -C "$SANDBOX_WORKDIR" symbolic-ref --quiet --short HEAD)"
if [ "$BRANCH" != "main" ]; then
  echo "ABORT: HEAD branch for $SANDBOX_WORKDIR is '$BRANCH', expected 'main'" >&2
  exit 1
fi

echo "OK: $SANDBOX_WORKDIR is its own git top-level (branch=$BRANCH)"
