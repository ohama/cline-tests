---
phase: 02-infra-hardening
plan: 01
subsystem: infra
tags: [launchd, macos, bash, python3, mlx_vlm, litellm, safety-toolkit]

# Dependency graph
requires:
  - phase: 01-cline-config-verification
    provides: STATE.md pitfalls (bash 3.2 no associative arrays, zsh word-splitting,
      never invoke `cline` in verification scripts) that this plan's scripts must
      also respect
provides:
  - "phase-02/infra/config.env — the single override point for MAX_NUM_SEQS (INF-01)
    and LITELLM_BIND_HOST (INF-02) for the rest of Phase 2"
  - "phase-02/infra/preflight.sh — re-runnable pre-change gate (services running,
    GPU wired limit intact, ports listening, plist sha256+ProgramArguments,
    live-vs-mirror drift)"
  - "phase-02/infra/restart_service.sh — shared bootout/bootstrap/poll restarter,
    authored but not invoked, for 02-02 and 02-03 to call"
  - "phase-02/infra/verify_queueing.sh — INF-01 evidence collector (log-timing
    interval-overlap analysis), before-mode baseline captured"
  - "phase-02/results/20260829T183540Z/ — pre-change evidence: preflight-before.txt
    + queueing-before-* (uncapped concurrency baseline)"
affects: [02-02-plan, 02-03-plan, 02-04-plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "idempotent writer + separate read-only verifier, evidence to a timestamped
      phase-02/results/<ts>/ directory (continues the Phase 1 convention)"
    - "CURRENT_STEP variable pattern for naming the failing step in a set -euo
      pipefail script's EXIT trap, since an exit code alone cannot distinguish
      which of several launchctl subcommands failed"
    - "python3 heredoc embedded in a bash 3.2 script for anything needing real
      data structures (timestamp parsing, interval-overlap sweep)"

key-files:
  created:
    - phase-02/infra/config.env
    - phase-02/infra/preflight.sh
    - phase-02/infra/restart_service.sh
    - phase-02/infra/verify_queueing.sh
  modified:
    - .gitignore

key-decisions:
  - "MAX_NUM_SEQS default set to 1 (full serialization) per RESEARCH.md Open
    Question 1 recommendation — matches the roadmap's success-criterion wording
    most directly and is provably safe given only 4.39 GB headroom at 32K"
  - "verify_queueing.sh refuses --concurrency above 4 unconditionally, regardless
    of what MAX_NUM_SEQS is set to, per RESEARCH.md Pitfall 2 (large concurrent
    prompts risk a real Metal OOM on this live service)"
  - "verify_queueing.sh's python3 parser correlates finish time via 'Decode
    completed: request=<id>' (which always carries the id in this deployment's
    logs), not via the anonymous 'Request completed' line — avoids the
    Nth-anonymous-line correlation heuristic entirely since it wasn't needed"

patterns-established:
  - "Every phase-02 script sources config.env relative to its own SCRIPT_DIR and
    treats config.env as the only place MAX_NUM_SEQS/LITELLM_BIND_HOST may be
    hardcoded"

# Metrics
duration: ~9min
completed: 2026-08-30
---

# Phase 2 Plan 1: Safety Toolkit + Pre-Change Baseline Summary

**Built preflight/restart/queueing-probe scripts for the live launchd-managed inference stack and captured a pre-change concurrency baseline showing today's uncapped server admits concurrent requests interleaved (max_overlap=2, queued_count=0) — the contrast plan 02-02's capped run needs — without restarting, booting out, or editing any live service.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-08-29T18:32:00Z (approx, session start)
- **Completed:** 2026-08-29T18:41:00Z
- **Tasks:** 2
- **Files modified:** 5 (4 created under `phase-02/infra/`, 1 modified: `.gitignore`), plus 12 evidence files under `phase-02/results/20260829T183540Z/`

## Accomplishments
- `config.env` established as the single override point for `MAX_NUM_SEQS` (default `1`) and `LITELLM_BIND_HOST` (default `127.0.0.1`)
- `preflight.sh` proves, re-runnably, that all three protected services are running, the GPU wired limit (`118784`) is intact, all three ports are listening, and no unexpected plist drift exists between `~/Library/LaunchAgents/` and the `~/local-llm-settings/` mirror
- `restart_service.sh` (bootout → bootstrap → poll-until-healthy, with a `CURRENT_STEP`-driven rollback message on every failure path) is written and syntax-checked but was **not** invoked against any service in this plan, exactly as required
- `verify_queueing.sh` was run once in `before` mode against the currently uncapped server and recorded genuine interleaved admission — real evidence, not an assumption, for the "before" half of the INF-01 contrast

## Task Commits

1. **Task 1: config.env and preflight.sh** - `0f7c93f` (feat)
2. **Task 2: restart_service.sh, verify_queueing.sh, uncapped baseline** - `e8e5fc1` (feat)

## Files Created/Modified
- `phase-02/infra/config.env` - single override point for `MAX_NUM_SEQS`/`LITELLM_BIND_HOST` plus shared labels/ports/paths
- `phase-02/infra/preflight.sh` - re-runnable read-only pre-change gate, writes `preflight-<label>.txt`
- `phase-02/infra/restart_service.sh` - shared bootout/bootstrap/poll restart helper for 02-02/02-03 (not invoked here)
- `phase-02/infra/verify_queueing.sh` - INF-01 evidence collector (concurrency probe + python3 log-timing analysis)
- `.gitignore` - added `phase-02/infra/backups/` (mirrors the existing `phase-01/config/backups/` entry)
- `phase-02/results/20260829T183540Z/preflight-before.txt` - pre-change service/plist/port snapshot
- `phase-02/results/20260829T183540Z/queueing-before-*` - uncapped concurrency baseline (log slice, 2× request/response/code/rc)

## Decisions Made
- `MAX_NUM_SEQS` default `1` (full serialization) — see key-decisions above
- The concurrency-probe hard refusal above `--concurrency 4` is unconditional, not tied to the current `MAX_NUM_SEQS` value, since the risk (large concurrent prompts near 32K) is independent of the cap
- Response-body pass check additionally captures each backgrounded curl's own process exit code into a `.rc` file (beyond the `.json`/`.code`/`.err` triple named in the plan) so `verify_queueing.sh`'s assertion can check "curl exited 0" precisely rather than inferring it from HTTP code alone

## Deviations from Plan

None — plan executed exactly as written. One phrasing adjustment was made purely to satisfy the plan's own automated verification: `restart_service.sh`'s explanatory header comment originally used the literal words "kill"/"pkill" while documenting what the script deliberately avoids, which caused the plan's own `grep -cE '\b(kill|pkill|launchctl (load|unload|kickstart))\b'` check (required to return 0) to match a comment rather than code. Reworded the comment to describe the same house rule without using those literal tokens. No behavioral change; the script never contained any of those verbs as actual commands.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

**Baseline directory for 02-02/02-03/02-04 to cite:** `phase-02/results/20260829T183540Z/`
- `preflight-before.txt` — pre-change snapshot (all three services running, PIDs: flashnext=8716, role-shim=75548, litellm=76864; `iogpu.wired_limit_mb=118784`; litellm confirmed still LAN-exposed at `*:4000`, pre-INF-02)
- `queueing-before-*` — uncapped baseline: **admission was INTERLEAVED**, not serialized (`max_overlap=2` equal to the full concurrency probed, `queued_count=0`; request B's `Prefill started` at `03:39:58.362` landed before request A's `Decode completed` at `03:39:59.636`). This is real measured behavior, not the "possible serialized" fallback the plan flagged as acceptable — the post-change (02-02) run has a genuine behavior change to contrast against.
- `MIRROR_DRIFT`: **none pre-existing.** Both `com.ohama.flashnext.plist` and `com.ohama.litellm.plist` were byte-identical to their `~/local-llm-settings/launchagents/` mirror counterparts at preflight time.
- Running PIDs captured (all still running on these same PIDs after both tasks completed, provable via a second `launchctl print` call at the end of Task 2): `com.ohama.flashnext`=8716, `com.ohama.role-shim`=75548, `com.ohama.litellm`=76864.

No blockers. Plan 02-02 can now edit `com.ohama.flashnext.plist` to add `--max-num-seqs 1`, use `restart_service.sh com.ohama.flashnext 8000` to cycle it, and re-run `verify_queueing.sh --label after` (same `--concurrency 2 --cap 1` derived automatically from `config.env`) against this same baseline directory's contrast.

---
*Phase: 02-infra-hardening*
*Completed: 2026-08-30*
