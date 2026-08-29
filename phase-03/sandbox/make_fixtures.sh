#!/bin/bash
# make_fixtures.sh — idempotent builder for the permanent regression fixture tree
# used by phase-03's sandbox denial tests.
#
# Deliberately independent of plan 03-01: does NOT source plan 03-01's
# sandbox config-env file and does NOT edit .gitignore (both owned by
# 03-01; phase-03/fixtures/ is already ignored there). Takes --root instead,
# so it works standalone in parallel with 03-01.
#
# Fixtures built (all PERMANENT regression fixtures per 03-RESEARCH.md
# Pitfall 5, not one-off manual checks):
#   allowed/canary.txt                        - inside the whitelist
#   allowed/subdir/deep.txt                   - nested inside the whitelist
#   allowed/escape-link -> $ROOT/forbidden    - symlink INSIDE an allowed dir
#                                                pointing OUT, to prove the
#                                                kernel resolves symlinks to
#                                                their real target before
#                                                checking (not the spelling
#                                                used to reach them)
#   allowed_extra_should_not_match/canary.txt - a SIBLING of allowed/ that
#                                                deliberately shares its full
#                                                name as a string prefix, so
#                                                any regression to naive
#                                                string-prefix matching in
#                                                the generated profile is
#                                                caught (subpath must be
#                                                component-boundary-aware)
#   forbidden/secret.txt                      - outside the whitelist; also
#                                                the write-denial target dir
#   symlinked/real/canary.txt                 - canonical target
#   symlinked/link -> $ROOT/symlinked/real    - symlink SPELLING of an
#                                                allowed entry, so the
#                                                generator's realpath() step
#                                                is exercised end to end
#   allowed_repos.test.json                   - test-only allowlist, second
#                                                entry deliberately uses the
#                                                symlink spelling
set -euo pipefail

ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      ROOT="$2"
      shift 2
      ;;
    *)
      echo "make_fixtures.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -z "$ROOT" ]; then
  ROOT="$REPO_ROOT/phase-03/fixtures"
fi

# Idempotent: remove and rebuild the whole tree every time.
rm -rf "$ROOT"
mkdir -p "$ROOT"

mkdir -p "$ROOT/allowed/subdir"
printf 'ALLOWED-CANARY-OK' > "$ROOT/allowed/canary.txt"
printf 'ALLOWED-DEEP-OK' > "$ROOT/allowed/subdir/deep.txt"

mkdir -p "$ROOT/forbidden"
printf 'FORBIDDEN-SECRET' > "$ROOT/forbidden/secret.txt"

# symlink INSIDE an allowed dir pointing OUT to forbidden.
ln -s "$ROOT/forbidden" "$ROOT/allowed/escape-link"

mkdir -p "$ROOT/allowed_extra_should_not_match"
printf 'PREFIX-TRAP-CANARY' > "$ROOT/allowed_extra_should_not_match/canary.txt"

mkdir -p "$ROOT/symlinked/real"
printf 'CANON-CANARY-OK' > "$ROOT/symlinked/real/canary.txt"
ln -s "$ROOT/symlinked/real" "$ROOT/symlinked/link"

# Resolve the absolute (realpath'd) root for allowed_repos.test.json.
ABS_ROOT="$(cd "$ROOT" && pwd)"

cat > "$ROOT/allowed_repos.test.json" <<EOF
{"repos": ["$ABS_ROOT/allowed", "$ABS_ROOT/symlinked/link"]}
EOF

# Manifest: one line per fixture (path + first line of content), for the
# verifier to archive as evidence. Symlinks report their target.
manifest_line() {
  local path="$1"
  if [ -L "$path" ]; then
    printf '%s -> %s\n' "$path" "$(readlink "$path")"
  else
    printf '%s %s\n' "$path" "$(head -n1 "$path")"
  fi
}

manifest_line "$ROOT/allowed/canary.txt"
manifest_line "$ROOT/allowed/subdir/deep.txt"
manifest_line "$ROOT/allowed/escape-link"
manifest_line "$ROOT/allowed_extra_should_not_match/canary.txt"
manifest_line "$ROOT/forbidden/secret.txt"
manifest_line "$ROOT/symlinked/real/canary.txt"
manifest_line "$ROOT/symlinked/link"
manifest_line "$ROOT/allowed_repos.test.json"
