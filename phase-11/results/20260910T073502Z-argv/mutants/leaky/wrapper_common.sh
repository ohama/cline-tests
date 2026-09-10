#!/usr/bin/env bash
# MUTANT-LEAKY — test fixture only, never shipped. Deliberately reproduces the naive `"$@"`
# passthrough docs/plan-act-reasoning-design.md's own L3 sketch would produce
# (`cline -p -m flashnext-plan "$@"`): zero argument filtering, raw caller args forwarded
# verbatim after the fixed prefix. Seeded by phase-11/wrapper_argv_test.sh to prove the test
# can fail; must never be copied into the real phase-11/wrapper_common.sh.
set -euo pipefail
: "${WRAPPER_SELF:?}"
: "${WRAPPER_MODE_FLAG:=}"
: "${WRAPPER_ALIAS:?}"
: "${HERE:?}"

CMD="$WRAPPER_CLINE_BIN"
if [ "${CLINE_WRAPPER_TEST:-}" = "1" ]; then
  : "${CLINE_WRAPPER_TEST_BIN:?}"
  echo "[TEST MODE] using $CLINE_WRAPPER_TEST_BIN instead of $WRAPPER_CLINE_BIN" >&2
  CMD="$CLINE_WRAPPER_TEST_BIN"
fi

ORIG_ARGS=("$@")
set -- -P "$WRAPPER_PROVIDER"
[ -n "$WRAPPER_MODE_FLAG" ] && set -- "$@" "$WRAPPER_MODE_FLAG"
set -- "$@" -m "$WRAPPER_ALIAS" --compaction "$WRAPPER_COMPACTION" -t "$WRAPPER_DEFAULT_TIMEOUT"
set -- "$@" "${ORIG_ARGS[@]}"

CLINE_NO_AUTO_UPDATE=1 "$CMD" "$@"
