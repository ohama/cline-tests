---
phase: 05-kanban-telegram-services
plan: 07
subsystem: infra
tags: [launchd, docs, phase-close, checkpoint, reboot-evidence, check_versions, verify_services]

# Dependency graph
requires:
  - phase: 05-kanban-telegram-services (05-01 through 05-06)
    provides: "Both launchd services live (com.ohama.kanban, com.ohama.telegram-connect), SVC-05 mirror registration, and the standing phase-05/services/verify_services.sh gate"
provides:
  - "Phase 5 closed: all four ROADMAP criteria evidenced (criterion 1's reboot clause explicitly proxy-only, by human decision)"
  - "docs/services.md — the single house-style document for restart/take-down/full-removal/token-injection/logs/house-rules for both services"
  - "phase-05/results/20260830T024606Z-phase-close/ — full standing-gate sweep with both services live, plus criteria.md mapping all four criteria to evidence"
  - "check_versions.sh proven non-vacuous against the two real installed plists"
  - "Recorded, durable decision: accept-proxy for criterion 1's reboot clause (no reboot performed)"
affects: [06-network-exposure, 07-telegram-token-activation, 08-manual]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Phase-close evidence directories always include a criteria.md mapping every ROADMAP success criterion to its exact evidence file/line, with any partially-proven clause explicitly labelled as such rather than silently rounded up to PASS"
    - "Blocking human decisions are recorded verbatim in at least two places (the house-style doc's limitations section and the phase-close evidence's own criteria map), both worded to avoid the literal forbidden phrase even in negated/explanatory prose, so no future grep-based check or human skim can misread a hedge as a claim"

key-files:
  created:
    - docs/services.md
    - phase-05/results/20260830T024606Z-phase-close/ (README.md, criteria.md, check-versions.txt, invariants.txt, pytest.txt, config/, inf03/, sandbox/, services-gate/)
  modified:
    - docs/services.md (Task 3: filled the "Task 3 결정 기록" placeholder with the accept-proxy decision)
    - phase-05/results/20260830T024606Z-phase-close/criteria.md (Task 3: filled the "Task 3 decision" placeholder)

key-decisions:
  - "accept-proxy: the human accepted the proxy evidence (RunAtLoad + LaunchAgents placement + a per-label bootout/bootstrap cold-start cycle) for ROADMAP criterion 1's reboot clause. No real reboot was performed and none is required as follow-up. Criterion 1's reboot half remains proxy-evidenced, not observed, even after this decision — Phase 6/8 must not mistake it for measured reboot behavior."
  - "The real reboot was not performed because it resets iogpu.wired_limit_mb, which phase-02/infra/preflight.sh hard-fails on until a privileged sudo sysctl re-apply — a cost/risk trade the human, not Claude, gets to decide."
  - "check_versions.sh's Check C correctly emits three PASS lines, not four, for the two new plists (com.ohama.telegram-connect invokes cline, not kanban, so only CLINE_NO_AUTO_UPDATE applies to it by the gate's own documented design) — not a bug, and not a reason to weaken the gate."

patterns-established:
  - "Task 3's decision fill touched two independent evidence artifacts (docs/services.md and the phase-close criteria.md) in two atomic commits, each re-verified against the plan's own grep contracts before committing, including a self-check that explanatory negation prose ('no wording claims a reboot happened') doesn't itself trip the very grep it's trying to satisfy."

# Metrics
duration: ~40min (includes the blocking checkpoint wait for the human's decision; active execution time across the original agent's Tasks 1-2 and this continuation's Task 3 is roughly 20 min)
completed: 2026-08-30
---

# Phase 5 Plan 07: Phase-close gate sweep, docs/services.md, and the reboot-decision checkpoint Summary

**Closed Phase 5 with a full standing-gate sweep (15+ checks across six gates, all PASS with both new services live), a 243-line house-style `docs/services.md`, and a human-made, verbatim-recorded decision (`accept-proxy`) settling ROADMAP criterion 1's one unprovable-without-a-real-reboot clause.**

## Performance

- **Duration:** ~40 min wall-clock (original agent: Tasks 1-2, ~11:30-11:52 KST; blocking checkpoint wait for the human's decision; this continuation: Task 3, ~12:27-12:29 KST)
- **Started:** 2026-08-30T02:2x:xxZ (approximate, original agent)
- **Completed:** 2026-08-30T03:28:30Z
- **Tasks:** 3 (Task 3 executed by this continuation agent)
- **Files modified:** 2 created directories/files (`docs/services.md`, `phase-05/results/20260830T024606Z-phase-close/`) + 2 files edited in Task 3

## Accomplishments

- **Task 1 — full standing-gate sweep with both services live:** `verify_services.sh` (15/15
  CHECK PASS), `verify_no_regression.sh` (`INF03: PASS`), `verify_sandbox.sh` (4/4 CRITERION,
  16/16 CASES, 0 CRASHED), `verify_config.sh` (exit 0 both pre- and post-`check_versions.sh`, no
  heal needed), `check_versions.sh` (the plan's single `cline` invocation, run against the real
  `~/Library/LaunchAgents` plists — exit 0, non-vacuous), `pytest phase-03/tests/ phase-04/tests/`
  (24/24), and 8/8 invariants (empty `EXTRA_ALLOW_PATHS`, empty `phase-03/` git diff, all five
  service pids unchanged, no second restart helper, no port 3000, `sync.sh --check` exits 0).
  Wrote `criteria.md` mapping all four ROADMAP criteria to exact evidence paths, with criterion
  1's reboot clause explicitly marked proxy-only pending this plan's Task 3.
- **Task 2 — `docs/services.md`:** a 10-section, house-style (matching `docs/infra-hardening.md`/
  `docs/headless-wrapper.md`) record covering what was built (verbatim `ProgramArguments` for both
  plists), why each design choice was made (`-i` mandatory, `--no-tools` as the honest
  `--auto-approve false` translation, idle-branch blocks not exits, the flashnext-not-litellm
  readiness probe rationale), operations (restart/take-down/full-removal/standing gate), the
  token-injection recipe (BotFather-only source, watch for `unknown option` on first
  post-injection restart), logs, house rules, an evidence table, and Phase 6 handoff items. The
  limitations section (§4) is its own top-level heading and was left with an explicit, empty
  placeholder for the Task 3 decision.
- **Task 3 (this continuation) — the `accept-proxy` decision, recorded honestly in two places:**
  - `docs/services.md` §4's placeholder now states what was accepted (the proxy evidence already
    documented earlier in §4: `RunAtLoad: true` in both plists, both plists present under
    `~/Library/LaunchAgents/`, both labels enabled, and a full `bootout` → stays-gone →
    `bootstrap` → healthy cycle executed per label — the same cold-start path a login/boot
    bootstrap takes), what it does not prove (real macOS reboot behavior, login-session ordering,
    `:4000` reachability at boot), and why the real reboot was skipped (`iogpu.wired_limit_mb` is
    reset by a real reboot, which `phase-02/infra/preflight.sh` hard-fails on until a privileged
    `sudo sysctl` re-apply). No mandatory post-reboot checklist was added — the human chose to
    accept, not defer — but one line notes a future natural reboot as the moment this clause could
    still be observed for real.
  - `phase-05/results/20260830T024606Z-phase-close/criteria.md`'s own "Task 3 decision" section
    (left as a placeholder by Task 1) was filled the same way, cross-referencing
    `docs/services.md` §4 as the verbatim record.
  - Neither file contains the literal phrase "reboot-verified" or "재부팅 검증 완료" — including in
    the explanatory prose that describes what was *not* claimed, which was deliberately reworded
    (`No wording anywhere in this repo claims that a reboot actually happened`) after a first draft
    accidentally quoted the forbidden phrase inside its own negation and would have tripped
    `grep -ci 'reboot-verified'` if that check were ever run against `criteria.md` too.
  - Re-ran every one of the plan's `docs/services.md` verify greps after the edit: `wc -l` = 243
    (≥120), `bootout` count = 8 (≥3), `verify_services.sh` count = 2 (≥2), `infra-hardening` count
    = 1 (≥1), `iogpu.wired_limit_mb` count = 2 (≥1), `reboot-verified`/`재부팅 검증 완료` count = 0,
    `no-tools` count = 2 (≥1), `auto-approve` count = 2 (≥1), `loaded_model` count = 1 (≥1),
    `unknown option` count = 1 (≥1), `BotFather` count = 1 (≥1) — all pass.
  - Confirmed no side effects from the decision-recording work itself: all five service pids
    unchanged (flashnext 46573, litellm 48525, role-shim 75548, kanban 53894,
    telegram-connect 56669), `EXTRA_ALLOW_PATHS` empty, no listener on port 3000, `phase-03/` git
    diff empty, no reboot performed, no `sudo sysctl` invoked.

## Task Commits

Each task was committed atomically:

1. **Task 1: Phase-close gate sweep with both services live** - `c21cc33` (feat)
2. **Task 2: docs/services.md** - `b54cee8` (docs)
3. **Task 3: record accept-proxy decision in docs/services.md** - `5c01bd8` (docs)
3b. **Task 3 (evidence-file follow-up): fill accept-proxy decision in criteria.md** - `d20cd98` (docs)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `docs/services.md` — the single house-style record for both launchd services (created in Task
  2, decision section filled in Task 3).
- `phase-05/results/20260830T024606Z-phase-close/` — full sweep evidence: `README.md`,
  `check-versions.txt`, `invariants.txt`, `pytest.txt`, `config/`, `inf03/`, `sandbox/`,
  `services-gate/`, and `criteria.md` (created in Task 1, decision section filled in Task 3).

## Decisions Made

- **`accept-proxy` (human-made, checkpoint decision):** the human selected accepting the proxy
  evidence for ROADMAP criterion 1's "재부팅 후에도 동일하게 확인된다" clause over `reboot-now` or
  `defer-to-next-reboot`. No reboot was performed; none is required as a mandatory follow-up.
  Recorded verbatim in `docs/services.md` §4 and `phase-05/results/20260830T024606Z-phase-close/criteria.md`.
- Criterion 1's reboot half stays **proxy-evidenced, not observed**, even after this decision —
  this is a durable fact for Phase 6/8 to inherit, not a closed/upgraded claim. See STATE.md
  Decisions log for the same note recorded at the project level.
- `check_versions.sh`'s Check C emitting three PASS lines (not the plan text's anticipated four)
  for the two new plists was confirmed as correct-by-design during Task 1, not a deviation: only
  `com.ohama.kanban` invokes the `kanban` binary and needs both auto-update gates checked;
  `com.ohama.telegram-connect` invokes `cline` and only needs `CLINE_NO_AUTO_UPDATE` checked by
  that gate's own documented logic (it still sets `KANBAN_NO_AUTO_UPDATE=1` defensively in its
  plist, per 05-05).

## Deviations from Plan

None from the plan's own task structure — Task 3 was executed exactly as the `accept-proxy`
branch specifies. One self-caught wording collision during Task 3, fixed before committing:

### Auto-fixed Issues

**1. [Rule 1 — authoring trap, not a code bug] First draft of `criteria.md`'s Task 3 decision section used the literal string "reboot-verified" inside its own negation sentence**
- **Found during:** Task 3, immediately after editing `criteria.md`, while re-running the plan's
  grep-intent check as a self-check (this file isn't covered by the plan's literal
  `docs/services.md`-scoped grep, but honoring the intent, not just the regex, was explicit in the
  resume instructions).
- **Issue:** The sentence `No wording anywhere in this repo reads as "reboot-verified"` contains
  the forbidden literal string, which would misleadingly increment any future `grep -ci
  'reboot-verified'` count run against this file, and reads confusingly on a skim even though the
  intent (a negation) is correct.
- **Fix:** Reworded to `No wording anywhere in this repo claims that a reboot actually happened` —
  same meaning, zero occurrences of the literal string.
- **Files modified:** `phase-05/results/20260830T024606Z-phase-close/criteria.md`
- **Verification:** `grep -ni 'reboot-verified\|재부팅 검증 완료' phase-05/results/20260830T024606Z-phase-close/criteria.md`
  now shows only one pre-existing Task 1 occurrence (also a negation: `Never write
  "reboot-verified" for this half`), zero from this edit.
- **Committed in:** `d20cd98` (Task 3 evidence-file follow-up commit)

---

**Total deviations:** 1 auto-fixed (1 Rule 1 — self-caught wording collision, no behavior/claim
change).
**Impact on plan:** Zero — pure wording fix caught and corrected before commit, same class of
collision this project has now hit roughly ten times across earlier plans (05-01, 05-04, 05-05,
05-06, etc.).

## Issues Encountered

None beyond the one documented deviation above.

## User Setup Required

None for this plan. (The Telegram token-injection recipe documented in `docs/services.md` §6
remains the only outstanding manual step for actually activating the telegram-connect service,
and it is explicitly out of Phase 5's scope — token generation belongs to BotFather, not this
project.)

## Next Phase Readiness

- **Phase 5 is closed.** All four ROADMAP success criteria are evidenced:
  1. Both labels report `running` with stable pids — measured directly; the reboot clause is
     explicitly proxy-evidenced by human decision (`accept-proxy`), not observed.
  2. `kill` → `KeepAlive` revival — measured directly (05-04, 05-05).
  3. No crash-loop while flashnext is down, correct recovery once it's up — measured directly
     (05-03).
  4. SVC-05 mirror registration — measured directly (05-06).
- `phase-05/services/verify_services.sh` is the standing gate Phase 6 must call before and after
  opening anything to the network.
- `docs/services.md` is the one document the next person needs to restart, take down, fully
  remove, inject a token into, and reason about both services.
- **Durable note for Phase 6/8:** criterion 1's reboot clause is proxy-evidenced only. Do not cite
  it as observed reboot behavior in any later phase's documentation or manual.
- Deferred, not blocking: `workspace/scratch-repo` needs its own `git init` (research Pitfall 6);
  `--allowed-user-id` needs wrapper-level enforcement in Phase 6 (not a CLI guarantee in cline
  3.0.53); the RPC-coexistence residual for a token-present connector
  (`--rpc-address`/`CLINE_RPC_ADDRESS`).
- No blockers. Live pids unchanged throughout (flashnext 46573, litellm 48525, role-shim 75548,
  kanban 53894, telegram-connect 56669); `EXTRA_ALLOW_PATHS` empty; no port 3000; `cline`
  invocations: 1 (phase total: 2, cap 3, both spent in earlier plans/Task 1).

---
*Phase: 05-kanban-telegram-services*
*Completed: 2026-08-30*
