---
phase: 02-infra-hardening
plan: 03
subsystem: infra
tags: [launchd, litellm, uvicorn, network-binding, plist, macos, loopback]

# Dependency graph
requires:
  - phase: 02-infra-hardening (plan 01)
    provides: config.env, preflight.sh, restart_service.sh
  - phase: 02-infra-hardening (plan 02)
    provides: "CHECKPOINT_ANSWER: proceed-1 (restart consent covering this litellm bounce), async-bootout-race fix in restart_service.sh (Step 3b)"
provides:
  - "--host 127.0.0.1 live on com.ohama.litellm, restarted and verified (INF-02 satisfied)"
  - "apply_litellm_bind.sh — idempotent plist writer (backup-first, plutil-lint-gated, twin of apply_max_num_seqs.sh)"
  - "verify_lan_bind.sh — re-runnable INF-02 proof: lsof bind-address, LAN-IP refused, loopback by IP and by localhost hostname, collateral-port check"
  - "LAN_IP=192.168.75.108 curl-refused evidence (rc=7), loopback 200 by both IP and hostname"
affects: [02-04-mirror-sync, phase-05-launchd-services, phase-06-network-exposure]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bind-address hardening via plist --host flag, not master_key: chosen because all four current :4000 consumers already send the placeholder key 'dummy' and already point at localhost, so a loopback bind is a zero-regression fix while a master_key would 401 every consumer"
    - "verify_*.sh proof scripts must avoid echoing the literal negative-pattern string (e.g. '*:4000') in PASS/log messages, since downstream grep-based verification checks for absence of that exact substring across the whole file, not just a structured section"

key-files:
  created:
    - phase-02/infra/apply_litellm_bind.sh
    - phase-02/infra/verify_lan_bind.sh
    - phase-02/results/20260829T190346Z-inf02/ (apply, restart, loaded-arguments, verdict)
    - phase-02/results/20260829T190317Z/preflight-pre-inf02.txt
    - phase-02/results/20260829T190552Z/preflight-post-inf02.txt
  modified:
    - ~/Library/LaunchAgents/com.ohama.litellm.plist (live edit, outside repo, --host 127.0.0.1 appended)

key-decisions:
  - "LITELLM_BIND_HOST=127.0.0.1 (config.env override point already present from 02-01) applied via plist --host flag, not litellm's config.yaml, per RESEARCH.md Pitfall 4 (binding is a uvicorn/CLI concern, not a config-yaml one)"
  - "master_key deliberately NOT added — bind-only fix keeps all four existing localhost:4000 consumers (Cline providers.json, ~/.hermes/config.yaml, ~/.openjarvis/config.toml, ~/.claude/proxy.env) working unmodified"
  - "Consent for this restart reused verbatim from 02-02's CHECKPOINT_ANSWER: proceed-1 — not re-prompted, per plan constraint"

patterns-established:
  - "restart_service.sh's teardown-wait fix (Step 3b, from 02-02) verified to generalize correctly to a lightweight service: litellm's teardown was 2s (vs flashnext's 104GiB unload), first restart attempt succeeded"

# Metrics
duration: ~10min
completed: 2026-08-30
---

# Phase 2 Plan 03: Lock litellm to Loopback Summary

**litellm's launchd plist gained `--host 127.0.0.1`, restarted live via the shared helper (pid 76864→48525), and both a LAN-IP refusal and a localhost-hostname survival check are now proven and re-runnable — closing the one genuinely LAN-exposed service in the stack (INF-02).**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T04:02Z (approx., following 02-02 completion)
- **Completed:** 2026-08-30T04:06Z
- **Tasks:** 2/2
- **Files modified:** 2 scripts created, 1 live plist edited (outside repo), 5 evidence directories/files

## Accomplishments
- Confirmed consent via literal `grep -E '^CHECKPOINT_ANSWER: proceed-[12]$'` match against `02-02-SUMMARY.md` (matched `proceed-1`) — did not re-prompt the user
- `apply_litellm_bind.sh` (idempotent plist writer, twin of `apply_max_num_seqs.sh`) backed up the live plist, appended `--host 127.0.0.1`, lint-verified, and confirmed idempotence on a throwaway copy (two consecutive runs, exactly one `--host` pair) before touching the live file
- Restarted `com.ohama.litellm` via `restart_service.sh` only — succeeded on the **first attempt** (teardown confirmed after 2s, healthy after 2s of polling), inheriting 02-02's async-bootout-race fix without needing any new workaround
- `lsof` now shows `127.0.0.1:4000 (LISTEN)`, no `*:4000` anywhere
- `verify_lan_bind.sh` (re-runnable, read-only) proves all five required properties in one pass: bind-address structural proof, LAN-IP curl refused (rc=7) from the live LAN IP `192.168.75.108`, loopback by IP returns 200 with `flashnext` in the body, loopback by the `localhost` hostname also returns 200 (the IPv6-subtlety check the plan called out specifically), and `:8000`/`:8011` unaffected — final verdict `INF02: PASS`, confirmed reproducible on a second independent run
- `preflight.sh` before/after contrast: `LITELLM_BIND_MARKER` flipped from `*:4000 (LAN-exposed)` to `127.0.0.1:4000 (localhost-only)`
- `config.yaml` untouched (`grep -c master_key` returns 0); no `master_key` introduced; `flashnext`/`role-shim` untouched by this plan

## Task Commits

Each task was committed atomically:

1. **Task 1: apply_litellm_bind.sh — idempotent --host writer, then restart litellm** - `66e132d` (feat)
2. **Task 2: verify_lan_bind.sh — prove LAN rejection and loopback survival** - `871c8e2` (test)

**Plan metadata:** (this commit, to follow)

## Files Created/Modified
- `phase-02/infra/apply_litellm_bind.sh` - idempotent `--host` writer, backup-first, plutil-lint-gated, structural twin of `apply_max_num_seqs.sh`
- `phase-02/infra/verify_lan_bind.sh` - re-runnable, read-only INF-02 proof (5 checks, PASS/FAIL/INCONCLUSIVE per check, non-zero exit on any FAIL)
- `~/Library/LaunchAgents/com.ohama.litellm.plist` - live edit, `--host 127.0.0.1` appended to `ProgramArguments` (outside repo, backed up first)
- `phase-02/infra/backups/com.ohama.litellm.plist.20260829T190346Z` - fresh pre-edit backup (gitignored)
- `phase-02/results/20260829T190346Z-inf02/` - apply output, restart log, loaded-arguments (launchctl print), `inf02-verdict.txt`
- `phase-02/results/20260829T190317Z/preflight-pre-inf02.txt` - baseline preflight (before)
- `phase-02/results/20260829T190552Z/preflight-post-inf02.txt` - post-restart preflight (after, bind-marker contrast)

## Decisions Made
- Reused `LITELLM_BIND_HOST=127.0.0.1` from `config.env`'s existing INF-02 override point (set up in 02-01) rather than introducing a new variable.
- Kept the plist edit strictly to `--host`; did not touch `config.yaml` and did not add `master_key`, per the plan's explicit constraint and RESEARCH.md's cost/benefit analysis (a `master_key` would 401 all four existing `dummy`-key consumers for no additional protection beyond what the loopback bind already provides on this single-user machine).
- Fixed a minor self-inflicted false-positive in `verify_lan_bind.sh`: the Check 1 PASS message originally echoed the literal substring `*:4000` in prose ("... *:4000 absent"), which caused the plan's own `grep -c '\*:4000' ... returns 0` verification to fail (it found 1 match — the log line itself, not an actual wildcard bind). Reworded to "no wildcard bind found" so the grep-based proof stays a clean structural check on the `lsof` output only, not on human-readable commentary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] verify_lan_bind.sh Check 1 PASS message defeated its own verification grep**
- **Found during:** Task 2, post-write verification of the plan's stated verify commands
- **Issue:** The script's own log line for a passing Check 1 contained the literal text `*:4000` as prose ("127.0.0.1:4000 present, *:4000 absent"), so the plan's verification command `grep -c '\*:4000' phase-02/results/*-inf02/inf02-verdict.txt` (expected to return 0) instead returned 1, incorrectly suggesting a wildcard-bind line existed in the evidence file.
- **Fix:** Reworded the PASS message to avoid the substring entirely ("loopback-only listener confirmed, no wildcard bind found").
- **Files modified:** `phase-02/infra/verify_lan_bind.sh`
- **Verification:** Re-ran the script; `grep -c '\*:4000' phase-02/results/*-inf02/inf02-verdict.txt` now returns exactly `0`, and `grep '127.0.0.1:4000' ...` still matches the actual `lsof` line. `INF02: PASS` unchanged.
- **Committed in:** `871c8e2` (Task 2 commit — fixed before commit, so no separate fix commit was needed)

---

**Total deviations:** 1 auto-fixed (1 bug, self-contained to the new verification script, found before the task commit)
**Impact on plan:** Cosmetic wording fix inside a brand-new script; no behavior change to the actual bind-address logic or restart flow. No scope creep.

## Issues Encountered
None beyond the deviation above. The litellm restart itself succeeded on the first attempt with no teardown race (2s teardown, sub-second reload — as the plan anticipated, since litellm loads no model).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- **INF-02 satisfied and proven both structurally (`lsof`) and behaviorally (LAN-IP refused, loopback survives by both IP and hostname).**
- The IPv6/`localhost` subtlety flagged in this plan's context was checked explicitly and passed: `curl http://localhost:4000/v1/models` returns 200, so none of the four existing consumers (Cline `providers.json`, `~/.hermes/config.yaml`, `~/.openjarvis/config.toml`, `~/.claude/proxy.env`) are at risk of being stranded on `::1`.
- **Mirror sync is explicitly outstanding** — the live `com.ohama.litellm.plist` now differs from `~/local-llm-settings/launchagents/com.ohama.litellm.plist` (confirmed via `preflight --label post-inf02`'s `MIRROR_DRIFT` warning, alongside the pre-existing flashnext drift from 02-02). This is intentional and is plan 02-04's job (`sync.sh`), not this plan's — do not run `sync.sh` here.
- Old litellm pid 76864 → new pid 48525. `flashnext` (46573) and `role-shim` (75548) confirmed unchanged by this plan's `verify_lan_bind.sh` Check 5.
- No blockers for 02-04.

---
*Phase: 02-infra-hardening*
*Completed: 2026-08-30*
