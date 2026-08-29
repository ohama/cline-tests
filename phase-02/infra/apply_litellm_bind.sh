#!/bin/bash
# phase-02/infra/apply_litellm_bind.sh — idempotent plist writer (INF-02).
#
# Adds/updates --host <LITELLM_BIND_HOST> in the live litellm plist's
# ProgramArguments. Always backs up the plist first (unconditionally, even
# if the edit turns out to be a no-op). Never restarts anything — editing
# the plist on disk has zero live effect until a separate bootout/bootstrap
# cycle (restart_service.sh, run under explicit user consent).
#
# Structurally a twin of apply_max_num_seqs.sh (INF-01), reading
# LITELLM_BIND_HOST instead of hardcoding 127.0.0.1.
#
# Usage: apply_litellm_bind.sh
#   TARGET_PLIST=<path>  overrides which plist file is edited, so the
#                        idempotence check can run against a throwaway
#                        copy instead of the live file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

PLIST="${TARGET_PLIST:-$LAUNCH_AGENTS_DIR/$LITELLM_LABEL.plist}"

if [ ! -f "$PLIST" ]; then
  echo "plist not found: $PLIST" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Backup first, unconditionally, before any modification.
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
BACKUP_PATH="$BACKUP_DIR/$(basename "$PLIST").$(date -u +%Y%m%dT%H%M%SZ)"
cp -p "$PLIST" "$BACKUP_PATH"
echo "BACKUP: $BACKUP_PATH"

# ---------------------------------------------------------------------------
# 2. Modify with python3 + plistlib. Note: plistlib rewrites the whole file
# on dump, so byte-level whitespace/ordering may differ from the original —
# this is exactly why the backup above is taken first, and why plan 02-04
# re-runs sync.sh rather than diffing byte-for-byte against the mirror.
# ---------------------------------------------------------------------------
STATE_FILE="$(mktemp)"
trap 'rm -f "$STATE_FILE"' EXIT

export APPLY_PLIST_PATH="$PLIST"
export APPLY_BIND_HOST="$LITELLM_BIND_HOST"
export APPLY_STATE_FILE="$STATE_FILE"

python3 <<'PYEOF'
import os
import plistlib
import sys

path = os.environ["APPLY_PLIST_PATH"]
value = os.environ["APPLY_BIND_HOST"]

with open(path, "rb") as f:
    data = plistlib.load(f)

args = data.get("ProgramArguments")
if not isinstance(args, list):
    print("ProgramArguments missing or not a list in %s" % path, file=sys.stderr)
    sys.exit(1)

flag = "--host"
count = args.count(flag)

if count > 1:
    print(
        "ERROR: --host appears %d times in %s ProgramArguments — "
        "this looks like corruption from a previous bad run. Abort and "
        "restore from a backup in phase-02/infra/backups/ before retrying."
        % (count, path),
        file=sys.stderr,
    )
    sys.exit(1)

already_applied = False
if count == 1:
    idx = args.index(flag)
    if idx + 1 < len(args) and args[idx + 1] == str(value):
        already_applied = True
    if idx + 1 >= len(args):
        # Flag present but no value slot after it — append one.
        args.append(str(value))
    else:
        args[idx + 1] = str(value)
else:
    args.append(flag)
    args.append(str(value))

data["ProgramArguments"] = args

with open(path, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_XML)

with open(os.environ["APPLY_STATE_FILE"], "w") as f:
    f.write("ALREADY" if already_applied else "APPLIED")
PYEOF

# ---------------------------------------------------------------------------
# 3. Lint — a plist that fails lint must never reach a bootout.
# ---------------------------------------------------------------------------
LINT_OUT="$(plutil -lint "$PLIST" 2>&1)"
if ! printf '%s\n' "$LINT_OUT" | grep -qE ': OK$'; then
  echo "plutil -lint did not report OK: $LINT_OUT" >&2
  exit 1
fi
echo "$LINT_OUT"

# ---------------------------------------------------------------------------
# 4. Re-read and assert exactly one pair with the right value; print the
# full resulting ProgramArguments array.
# ---------------------------------------------------------------------------
export APPLY_PLIST_PATH="$PLIST"
export APPLY_BIND_HOST="$LITELLM_BIND_HOST"

python3 <<'PYEOF'
import os
import plistlib
import sys

path = os.environ["APPLY_PLIST_PATH"]
value = str(os.environ["APPLY_BIND_HOST"])

with open(path, "rb") as f:
    data = plistlib.load(f)

args = data.get("ProgramArguments", [])
flag = "--host"
count = args.count(flag)

if count != 1:
    print(
        "ERROR: post-write verification found --host %d times (expected 1) in %s"
        % (count, path),
        file=sys.stderr,
    )
    sys.exit(1)

idx = args.index(flag)
if idx + 1 >= len(args) or args[idx + 1] != value:
    print(
        "ERROR: post-write verification found wrong/missing value after --host in %s"
        % path,
        file=sys.stderr,
    )
    sys.exit(1)

print("ProgramArguments:")
for a in args:
    print("  %s" % a)
PYEOF

APPLY_STATE="$(cat "$STATE_FILE")"
if [ "$APPLY_STATE" = "ALREADY" ]; then
  echo "ALREADY APPLIED: --host $LITELLM_BIND_HOST"
else
  echo "APPLIED: --host $LITELLM_BIND_HOST"
fi
