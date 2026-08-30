---
phase: 05-kanban-telegram-services
plan: 05
subsystem: infra
tags: [launchd, telegram, cline-connect-telegram, restart_service.sh, install_services.sh, lsof, keepalive]

requires:
  - phase: 05-04
    provides: "the house-style plist pattern, install_services.sh, and the sanctioned restart_service.sh <label> <port|none> flow, already proven live for com.ohama.kanban"
  - phase: 05-03
    provides: "the empty-token idle branch and the -i/--no-tools/--provider/--model flag-surface findings for run_telegram_service.sh, proven in the foreground before this plan supervised it"
provides:
  - "com.ohama.telegram-connect registered as a live, KeepAlive-supervised launchd service with an empty, discoverable TELEGRAM_BOT_TOKEN slot"
  - "Live proof, under launchd (not just foreground), that the empty-token branch idles forever without ever reaching cline and without leaking an unsupervised bot child"
  - "Live proof that the connector revives from a kill -TERM (SVC-03) and that its take-down path (launchctl bootout) actually works and reverses cleanly"
  - "A measured both-services-up port map showing kanban's port footprint is unchanged by the connector's presence, closing 05-RESEARCH.md Open Question 2 for the shipped configuration"
  - "A written token-injection recipe (staged plist edit -> install_services.sh -> restart_service.sh -> re-check orphans/ports -> watch for 'unknown option') for the human who eventually adds a real BotFather token"
affects: [05-06, 05-07, phase-06-network-exposure]

tech-stack:
  added: []
  patterns:
    - "Portless launchd label registration via restart_service.sh <label> none, reused verbatim from 05-02/05-04 with zero forking"
    - "Orphan sweep as a first-class verification step (pgrep -f '<subcommand>' plus a log-signature grep) whenever a wrapper's failure mode is a self-daemonizing child process, not just a crash loop"

key-files:
  created:
    - phase-05/plists/com.ohama.telegram-connect.plist
    - "phase-05/results/20260830T021706Z-svc02-telegram/ (README.md plus full evidence: launchctl transcripts, orphan sweep, svc03.txt, takedown.txt, both-up.txt, port map, both-up-sandbox/, both-up-inf03/)"
  modified:
    - .gitignore

key-decisions:
  - "The token slot stays empty in this phase by explicit user decision -- no token was ever requested, generated, or fabricated; the service is proven idle up to exactly the point a token would be required"
  - "Orphan-freedom is proven from the outside (pgrep -f 'connect telegram', a log-signature grep for the self-daemonize string) rather than trusted from source reading alone, mirroring the SVC-04 crash-loop proofs 05-03 already did in the foreground"
  - "verify_sandbox.sh's default output dir (phase-03/results/) was relocated into this plan's own results dir for the both-services-live capture, same convention 05-04 established for its pre-sandbox/ artifacts"

patterns-established:
  - "When a plist's own explanatory comments risk colliding with that same task's grep-based verify (a recurring class first seen in 05-01), fix by rewording the prose, never by weakening the verify"

# Metrics
duration: 22min
completed: 2026-08-30
---

# Phase 5 Plan 05: Telegram Connector Registration (SVC-02/SVC-03, empty token) Summary

**`com.ohama.telegram-connect` registered live under launchd with an empty `TELEGRAM_BOT_TOKEN` slot — proven idle, orphan-free, KeepAlive-revivable, and cleanly take-down-able, coexisting with `com.ohama.kanban` with zero port clash.**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-08-30T02:05:00Z
- **Completed:** 2026-08-30T02:26:00Z
- **Tasks:** 3/3
- **Files modified:** 2 new source files (plist, .gitignore edit) + 1 evidence directory (37 files)

## Accomplishments
- Staged and installed `com.ohama.telegram-connect.plist` (house style, empty discoverable token slot, both auto-update gates, no `--allowed-user-id` yet) through the idempotent installer, proven idempotent twice.
- Brought the label up through the one sanctioned helper (`restart_service.sh com.ohama.telegram-connect none`), and proved — under real launchd supervision, not just the foreground test 05-03 already did — that the empty-token branch idles forever: stable pid across 20s, `ppid=1`, `%cpu` 0.0, log line counts static across a 60s window, and zero `connect telegram` processes across three samples over ~60s.
- Proved SVC-03 (criterion 2) with a real `kill -TERM <exact pid>`: KeepAlive revived a new pid within 2s, unchanged 15s later.
- Executed the take-down path for real (`launchctl bootout`), confirmed the label stayed gone for a full 30s (6 samples, 5s apart, zero revivals, zero orphans), then restored it through the same helper.
- Brought both `com.ohama.kanban` and `com.ohama.telegram-connect` up simultaneously and measured: both `state = running` with stable pids 20s apart; kanban holds exactly `127.0.0.1:3484`; the telegram service holds zero TCP sockets; neither pid is on port 3000; kanban's port footprint is byte-identical to 05-03's pre-registration baseline. Both standing gates (`verify_no_regression.sh`, `verify_sandbox.sh`) re-verified PASS with both services live.
- Wrote the token-injection recipe into the results README: edit the staged plist -> `install_services.sh` -> `restart_service.sh` -> re-run the orphan sweep and port map (a token-present connector *does* open an RPC host, the residual for Phase 6) -> watch the first restart's log for `unknown option` (the real invocation line is parsed for the first time then) -> the token itself must come from BotFather, never generated by this project.

## Task Commits

Each task was committed atomically:

1. **Task 1: Stage com.ohama.telegram-connect.plist with an empty token slot** - `c3f7b2f` (feat)
2. **Task 2: Bring up com.ohama.telegram-connect and prove it idles, revives, and has no orphans** - `ebfbe26` (feat)
3. **Task 3: Both services up together — coexistence, port map, and the injection recipe** - `b4f0c35` (feat) + `9355cee` (chore: relocate verify_sandbox.sh evidence into results dir)

**Plan metadata:** (this commit, to follow)

## Files Created/Modified
- `phase-05/plists/com.ohama.telegram-connect.plist` — the staged plist: empty, discoverable `TELEGRAM_BOT_TOKEN`, both auto-update gates, house style matching `com.ohama.kanban.plist`
- `.gitignore` — added `phase-05/services/backups/`, matching the already-ignored `phase-01/config/backups/`/`phase-02/infra/backups/` pattern
- `phase-05/results/20260830T021706Z-svc02-telegram/` — full evidence: `restart.txt`, `launchctl-print{,-20s}.txt`, `supervised-proc.txt`, `orphan-sweep.txt`, `log-quietness.txt`, `svc03.txt`, `takedown.txt`, `pids-before/after.txt`, `pre-inf03/`, `post-inf03/`, `both-up.txt`, `listen-all.txt`, `kanban-pid-tcp.txt`, `telegram-pid-tcp.txt`, `kanban-ports-comparison.txt`, `both-up-inf03/`, `both-up-sandbox/`, `both-up-sandbox.txt`, `README.md`

## Decisions Made
- Token slot deliberately left empty; no token requested/generated/fabricated at any point (user's explicit decision, honored throughout).
- Orphan-freedom proven empirically (`pgrep`, log-signature grep) rather than asserted from reading the wrapper's source, because that is the exact failure class this design exists to rule out.
- Relocated `verify_sandbox.sh`'s default results output into this plan's own evidence directory for the both-services-live capture, matching 05-04's `pre-sandbox/` precedent, instead of leaving a stray untracked directory under `phase-03/results/`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — wording collision, not a code bug] Plist comments collided with Task 1's own grep verify**
- **Found during:** Task 1 verification
- **Issue:** The first draft of `com.ohama.telegram-connect.plist`'s explanatory comments contained the literal substrings `3000` and `allowed-user-id`, which the task's own `grep -c '3000' ... == 0` / `grep -c 'allowed-user-id' ... == 0` checks then failed against.
- **Fix:** Reworded both comments to convey the same meaning ("kanban's other well-known default port", "no per-user Telegram ID allowlist flag") without the literal collision. Same technique 05-01 used for its own four comment collisions.
- **Files modified:** `phase-05/plists/com.ohama.telegram-connect.plist`
- **Verification:** Re-linted, reinstalled, both grep counts re-ran at 0.
- **Committed in:** `c3f7b2f` (Task 1 commit)

**2. [Rule 3 — minor consistency fix] `.gitignore` missing an entry for the new backups directory**
- **Found during:** Task 1, staging for commit
- **Issue:** `install_services.sh`'s own backup mechanism wrote a real backup (produced by the comment-fix reinstall above) into `phase-05/services/backups/`, an untracked directory not covered by `.gitignore`, unlike the equivalent `phase-01/config/backups/`/`phase-02/infra/backups/`.
- **Fix:** Added the missing `.gitignore` line for consistency. No script behavior changed.
- **Files modified:** `.gitignore`
- **Verification:** `git status --short` no longer lists the backups directory as untracked.
- **Committed in:** `c3f7b2f` (Task 1 commit)

**3. [Rule 1 — wording collision, not a code bug] `svc03.txt` prose collided with Task 2's own grep verify**
- **Found during:** Task 2 verification
- **Issue:** The first draft of `svc03.txt` described the kill discipline as "never `-9`/`KILL`, never `pkill`" — the literal substring `pkill` inside "never pkill" tripped the task's own `grep -cE 'pkill|kill -9|kill -KILL' svc03.txt == 0` check.
- **Fix:** Reworded to state the same constraint ("a forceful kill or a process-name-based kill utility was never used") without the literal collision. The actual signal sent throughout was always exactly `kill -TERM <pid>`.
- **Files modified:** `phase-05/results/20260830T021706Z-svc02-telegram/svc03.txt`
- **Verification:** Re-ran the grep, count 0.
- **Committed in:** `ebfbe26` (Task 2 commit)

**4. [Rule 3 — evidence hygiene] Relocated verify_sandbox.sh's stray output directory**
- **Found during:** Task 3, post-verification cleanup
- **Issue:** Running `verify_sandbox.sh` without `--out-dir` (as the plan's Task 3 action literally specifies) wrote its full run artifacts to the script's own default location, `phase-03/results/20260830T022356Z-sbx/`, leaving an untracked directory outside this plan's `phase-05/results/` evidence scope.
- **Fix:** Copied the artifacts into `phase-05/results/20260830T021706Z-svc02-telegram/both-up-sandbox/` and removed the stray original, matching 05-04's `pre-sandbox/` precedent. Transcript/verdict content unchanged.
- **Files modified:** none (evidence relocation only)
- **Verification:** `git status --short` clean apart from pre-existing untracked artifacts predating this session.
- **Committed in:** `9355cee` (chore commit)

---

**Total deviations:** 4 auto-fixed (2 wording-only collisions with the plan's own grep verify, 1 minor `.gitignore` consistency fix, 1 evidence-location cleanup)
**Impact on plan:** All four are cosmetic/hygiene — zero behavioral change to any script, wrapper, or plist semantics. No scope creep.

## Issues Encountered
None beyond the deviations above — every automation step (installer, restart helper, kill/revive, bootout/restore) succeeded on its first live attempt.

## User Setup Required
None — no external service configuration required in this plan. The token itself remains the human's future action, and the exact recipe for it is written into `phase-05/results/20260830T021706Z-svc02-telegram/README.md`'s "Token injection recipe" section (never generated or requested by this project).

## Next Phase Readiness
- Both Phase 5 always-on services (`com.ohama.kanban`, `com.ohama.telegram-connect`) are now live, coexisting, and independently provable stable/revivable/take-down-able.
- `sync.sh` (SVC-05) deliberately not run — that is 05-06's scope.
- Phase 6 (network exposure) inherits a documented residual: once a real token is injected, the connector opens an RPC host, and `--rpc-address`/`CLINE_RPC_ADDRESS` is the sanctioned mechanism if that collides with anything, named explicitly in the injection recipe rather than left implicit.
- Phase 6 also inherits the `--allowed-user-id` gap noted in both the plist comments and the wrapper: cline 3.0.53 does not itself refuse to start without it, so Phase 6's NET criterion 4 needs wrapper-level enforcement.
- Live stack (flashnext 46573 / litellm 48525 / role-shim 75548) unchanged throughout; `EXTRA_ALLOW_PATHS` empty throughout; `cline` invocations used by this plan: 0.

---
*Phase: 05-kanban-telegram-services*
*Completed: 2026-08-30*
