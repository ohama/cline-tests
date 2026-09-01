#!/usr/bin/env bash
# rollback_config.sh <backup-path>
#
# The ONLY sanctioned way to put /Users/ohama/agent-stack/litellm/config.yaml
# back after an install goes wrong. It does exactly one thing: sha-verified
# restore of a named backup over the live path. It does NOT restart anything
# -- restarting is plan 10-03's privilege, not this script's. A restore path
# that will happily install an unverified/corrupted file is a way to make an
# outage permanent, so step 2 below refuses on any hash mismatch rather than
# trusting the caller's claim about which file this is.
#
# Usage: rollback_config.sh <backup-path>
# Exit 0  : live file now matches the backup's recorded sha256.
# Exit !=0: refused (backup missing, hash mismatch against BASELINE.txt, or
#           the post-copy re-hash didn't come back equal) -- live file is
#           left exactly as it was before this script ran.
#
# bash 3.2 compatible (no declare -A) -- this machine's default /bin/bash.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE="/Users/ohama/agent-stack/litellm/config.yaml"
BASELINE="$HERE/BASELINE.txt"

if [ $# -lt 1 ]; then
  echo "usage: rollback_config.sh <backup-path>" >&2
  exit 2
fi
BACKUP="$1"

# ---- Step 1: backup must exist ----
if [ ! -f "$BACKUP" ]; then
  echo "REFUSED: backup not found at $BACKUP" >&2
  exit 1
fi

# ---- Step 2: sha256 of the GIVEN BYTES must match the one canonical backup
# hash recorded in BASELINE.txt ("5. backup just taken" section). This is a
# content check, not a path check -- it does not matter what the argument is
# named or where it lives; if its bytes don't reproduce the recorded golden
# hash, it is not the sanctioned backup and this script refuses,
# unconditionally. This is the integrity gate: a restore script that will
# install an unverified/corrupted file is worse than no restore script at
# all. ----
if [ ! -f "$BASELINE" ]; then
  echo "REFUSED: $BASELINE not found -- cannot verify backup integrity without it" >&2
  exit 1
fi

# The one canonical recorded backup hash: the non-blank line immediately
# following the "5. backup just taken  (<path>):" label in BASELINE.txt.
RECORDED_SHA=$(awk '
  /^5\. backup just taken/ { want=1; next }
  want==1 {
    gsub(/^[ \t]+|[ \t]+$/, "", $0)
    if (length($0) > 0) { print $0; found=1; exit }
  }
  END { if (!found) exit 1 }
' "$BASELINE")
RECORDED_STATUS=$?

if [ "$RECORDED_STATUS" -ne 0 ] || [ -z "$RECORDED_SHA" ]; then
  echo "REFUSED: could not find the recorded backup sha256 in $BASELINE -- refusing to guess" >&2
  exit 1
fi

ACTUAL_SHA=$(shasum -a 256 "$BACKUP" | awk '{print $1}')

if [ "$ACTUAL_SHA" != "$RECORDED_SHA" ]; then
  echo "REFUSED: integrity check failed. $BACKUP's bytes do not match the sanctioned backup's recorded sha256." >&2
  echo "  recorded (BASELINE.txt, sanctioned backup): $RECORDED_SHA" >&2
  echo "  actual   ($BACKUP, just computed):          $ACTUAL_SHA" >&2
  echo "  Live file NOT touched." >&2
  exit 1
fi
echo "integrity OK: $BACKUP sha256 matches the sanctioned backup recorded in BASELINE.txt ($ACTUAL_SHA)"

# ---- Step 3: copy bytes back over the live path ----
if ! cp -p "$BACKUP" "$LIVE"; then
  echo "FAILED: cp of $BACKUP over $LIVE did not exit 0 -- live file state is now UNCERTAIN, inspect by hand" >&2
  exit 1
fi

# ---- Step 4: re-hash the live file and assert it now equals the backup's
# hash. Refuse (non-zero) if not -- this catches a cp that silently didn't
# do what it claimed to. ----
POST_SHA=$(shasum -a 256 "$LIVE" | awk '{print $1}')
if [ "$POST_SHA" != "$ACTUAL_SHA" ]; then
  echo "FAILED: post-copy verification mismatch. live file sha256 ($POST_SHA) != backup sha256 ($ACTUAL_SHA)" >&2
  exit 1
fi
echo "RESTORE OK: $LIVE now matches $BACKUP (sha256 $POST_SHA)"

# ---- Step 5: print, but do NOT run, the required follow-up. Restarting is
# plan 10-03's privilege; this script only puts bytes back. ----
echo ""
echo "Bytes are restored. litellm has NOT been restarted -- it is still serving whatever it"
echo "loaded at its last start. For the restore to take effect, the operator must separately run:"
echo ""
echo "  bash phase-02/infra/restart_service.sh com.ohama.litellm 4000 --timeout 60"
echo ""
exit 0
