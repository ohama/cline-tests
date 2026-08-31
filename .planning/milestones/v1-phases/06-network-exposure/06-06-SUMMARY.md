---
phase: 06-network-exposure
plan: 06
subsystem: infra
tags: [docs, tailscale, kanban, telegram, phase-close, criteria]

# Dependency graph
requires:
  - phase: 06-network-exposure
    provides: "06-01..06-05's complete evidence trail -- baseline, NET-04 guard, offline-proved scripts, the blocked-then-fixed-then-successful network opening (06-04/06-04.1/06-04.2), and 06-05's NET-05 evidence + declined Telegram trial decision"
provides:
  - "docs/network-exposure.md -- the Phase 6 house-style record: what was opened, why 8444/why 3000 must stay unbound, the limits section (NET-01/NET-05 human-verify gaps + NET-02/NET-04 interpretation choices), operations, rollback, evidence index, Phase 7/8 handoff"
  - "phase-06/IPAD-CHECKLIST.md -- standalone Korean checklist for NET-01/NET-05's human halves, with the offline-iPad re-login warning and the self-serve Telegram trial pointer"
  - "docs/services.md Sec 10 appended with the resolved --allowed-user-id cross-reference"
  - "phase-06/results/20260830T073411Z-phase-close/ -- full standing-gate sweep with the network open, invariants, and criteria.md mapping all five ROADMAP Phase 6 criteria to evidence"
  - ".planning/ROADMAP.md Phase 6 marked complete (8/8 plans), without upgrading criteria 1 or 5"
affects: [07, 08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "criteria.md status-token discipline: when a formal <verify> check greps for a literal status word count, every other mention of that status elsewhere in the same document must be phrased around it, not repeated -- extended the wording-collision discipline from grep-vs-repo to grep-vs-single-document"

key-files:
  created:
    - docs/network-exposure.md
    - phase-06/IPAD-CHECKLIST.md
    - phase-06/results/20260830T073411Z-phase-close/ (README.md, criteria.md, gate-network/, gate-services/, gate-no-regression/, gate-sandbox/, gate-config/, invariants/)
  modified:
    - docs/services.md (Sec 10 appended, original text preserved)
    - .planning/ROADMAP.md (Phase 6 checkboxes + progress table row)

key-decisions:
  - "Criterion 1's server-side evidence cited exclusively from 06-04.2's gate-network run (CASES 24/24), never from 06-04 (which FAILed at 13/15 on kanban's own Host allowlist and rolled back) -- 06-04 is referenced only as the mechanism-proof/blocker-discovery step, never as NET-01 evidence"
  - "NET-05's Telegram half recorded as probable-not-but-unobserved, matching 06-05's decision.md verbatim -- never upgraded to observed, per the user's explicit instruction when declining the live trial"
  - "ROADMAP Phase 6 marked [x] Complete (8/8 plans) despite two human_needed criteria, following the same precedent Phase 5 set for its proxy-only reboot half -- plan completion and criterion-status honesty are tracked independently"
  - "check_versions.sh (the plan's one optional cline-budget line item) was not run -- verify_config.sh passed exit 0 on the first attempt with no drift, so there was nothing for check_versions.sh's own healing step to exercise; phase-wide cline invocation count for all eight 06-* plans stays at 0"

# Metrics
duration: ~35min
completed: 2026-08-30
---

# Phase 6 Plan 6: docs/network-exposure.md, iPad Checklist, Phase-Close Sweep Summary

**Wrote the Phase 6 house-style record and a standalone iPad checklist that state both human-verify gaps and both interpretation choices in the open, then ran a full eight-gate phase-close sweep with the network open (`verify_network.sh` 24/24) and wrote `criteria.md` mapping all five ROADMAP criteria to evidence -- exactly two (`NET-01`, `NET-05`) honestly marked `human_needed`, citing 06-04.2 rather than the rolled-back 06-04.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-30T07:30:00Z (approx, first context read)
- **Completed:** 2026-08-30T07:39:00Z (Task 3 commit)
- **Tasks:** 3 of 3 completed as planned
- **Files modified:** 2 new docs (`docs/network-exposure.md`, `phase-06/IPAD-CHECKLIST.md`), 2 existing docs appended (`docs/services.md`, `.planning/ROADMAP.md`), 1 new results directory (`phase-06/results/20260830T073411Z-phase-close/`, 37 evidence files)

## Accomplishments

- **`docs/network-exposure.md`** (219 lines): 결론, what was opened (the single command, the resulting `Web` key, kanban's unchanged bind/pid), why each port choice was made (8444 chosen, 3000/443/8443/10000 each excluded with its own reason -- 3000's danger sentence written explicitly so a future reader does not "helpfully" bind it), a standalone limits section covering NET-01's iPad half (server-side proven at 06-04.2's `CASES 24/24`, iPad half unperformed, both iPads offline) and NET-05's Telegram half (static evidence stated as probable, never as observed, per 06-05's declined trial), NET-02's "no LAN path exists" interpretation, and NET-04's wrapper-vs-CLI distinction, operations/rollback/token-injection cross-reference, an evidence index, and a Phase 7/8 handoff section covering the `~/.gitconfig` sandbox blocker and the `--no-tools`/`--auto-approve false` escalation requirement. Appended (not rewrote) `docs/services.md` Sec 10 with a pointer to the now-resolved `--allowed-user-id` item.
- **`phase-06/IPAD-CHECKLIST.md`** (94 lines): standalone, Korean, one action per step with an explicit success/failure pair for each -- offline-iPad re-login warning (item 0), the exact tailnet URL (item 1), the real NET-01 bar of usable cards+diff at iPad width (item 2), the LAN-refusal test framed as "no path exists" rather than "rejected" (item 3), and NET-05's honestly-open Telegram observation step with a pointer to 06-05's self-serve trial checklist rather than any predicted result (item 4b).
- **Phase-close sweep** (`phase-06/results/20260830T073411Z-phase-close/`): all eight required checks exit 0 -- `verify_network.sh` `CASES 24/24`, `verify_services.sh` `CASES 15/15`, `verify_no_regression.sh` `INF03: PASS`, `verify_sandbox.sh` 16/16 CASES/0 CRASHED, `verify_config.sh` exit 0 on the first attempt (no heal needed, so `check_versions.sh` was correctly skipped), `pytest phase-03/tests/ phase-04/tests/` 24/24. Invariants captured: `AllowFunnel` still exactly the one pre-existing `:8443` key, port 3000 confirmed empty, kanban confirmed loopback-only, no wildcard-bind literal or public-exposure-subcommand literal anywhere in `phase-05/`/`phase-06/net/`, `EXTRA_ALLOW_PATHS` empty (live value; the two pre-existing self-referential grep hits inside 06-04.1/06-04.2's own closed READMEs were left untouched per their own established precedent), all six live pids unchanged and settled across two ~18s-apart samples with no crash-looping, `git diff --stat phase-01..04` empty, `sync.sh --check` exit 0.
- **`criteria.md`**: all five ROADMAP Phase 6 criteria mapped to evidence paths -- criterion 1 and criterion 5 `human_needed` (exactly two, `grep -c` verified), criteria 2/3/4 `met`. Criterion 1's evidence is explicitly sourced from `phase-06/results/20260830T070109Z-opening2/gate-network/` (06-04.2's `CASES 24/24` run), with 06-04 named only as the earlier attempt that FAILed at 13/15 and rolled back -- never cited as NET-01 evidence.
- **`.planning/ROADMAP.md`**: all eight Phase 6 plan checkboxes marked `[x]` (06-01 through 06-06, including 06-04.1/06-04.2), the phase header checkbox marked `[x]`, and the Progress table row updated to `8/8` / Complete with an inline note that criteria 1 and 5 stay human-verify items -- following the same precedent Phase 5 set (marked Complete despite its proxy-only reboot half).

## Task Commits

1. **Task 1: Write docs/network-exposure.md** - `7612f0a` (docs)
2. **Task 2: Write the standalone iPad checklist** - `e03b5c1` (docs)
3. **Task 3: Phase-close gate sweep and criteria.md** - `db4a555` (docs)

**Plan metadata:** this SUMMARY + STATE.md update (separate commit, following).

## Files Created/Modified

- `docs/network-exposure.md` - the Phase 6 record (결론/무엇을 열었나/왜/한계/운영/롤백/토큰 주입/증거/Phase 7·8 인계)
- `docs/services.md` - Sec 10 appended with the resolved `--allowed-user-id` cross-reference (original text preserved)
- `phase-06/IPAD-CHECKLIST.md` - standalone human-verification checklist for NET-01/NET-05
- `.planning/ROADMAP.md` - Phase 6 checkboxes + progress table row
- `phase-06/results/20260830T073411Z-phase-close/README.md` - sweep narrative, gate-by-gate table, invariant list, `cline` budget note
- `phase-06/results/20260830T073411Z-phase-close/criteria.md` - five-criterion ROADMAP mapping
- `phase-06/results/20260830T073411Z-phase-close/gate-network/`, `gate-services/`, `gate-no-regression/`, `gate-sandbox/`, `gate-config/`, `invariants/` - full sweep transcripts and invariant captures

## Decisions Made

See `key-decisions` in the frontmatter above: 06-04.2-only citation for criterion 1's server-side evidence, NET-05's Telegram half kept probable-not-but-unobserved verbatim from 06-05's decision, ROADMAP marked Complete alongside two honest `human_needed` criteria (Phase 5 precedent), and `check_versions.sh` correctly skipped since there was nothing for it to heal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Self-inflicted wording-collision hits in this plan's own evidence files**
- **Found during:** Task 3, capturing the `invariants/invariants.txt` file and drafting `README.md`
- **Issue:** Two of this plan's own newly-written evidence files briefly contained the literal searched-for substrings in their own section-header prose -- `invariants.txt`'s header spelled out the wildcard-bind IPv4 literal verbatim (`grep -rn '0\.0\.0\.0' phase-05/ phase-06/` found a self-match, count 1 instead of 0), and `README.md`'s first draft repeated the same literal in backticks describing the check. This is the project's well-established "prose collides with its own grep" trap (Rule 8 in the house rules, ~11 prior occurrences across the project).
- **Fix:** Reworded both headers to describe the literal by its meaning ("the all-interfaces wildcard-bind IPv4 literal, four zero octets, dotted") rather than spelling it, in files I authored this session (not touching any prior closed plan's evidence, consistent with 06-04.1/06-04.2's own established precedent of never rewriting prior evidence).
- **Files modified:** `phase-06/results/20260830T073411Z-phase-close/invariants/invariants.txt`, `phase-06/results/20260830T073411Z-phase-close/README.md`
- **Verification:** `grep -rn '0\.0\.0\.0' phase-05/ phase-06/ | wc -l` == 0, re-confirmed immediately before the Task 3 commit.
- **Committed in:** `db4a555` (Task 3 commit -- caught and fixed before that commit was made)

**2. [Rule 1 - Bug] Draft `criteria.md` exceeded the `grep -c 'human_needed' == 2` verify contract**
- **Found during:** Task 3, first self-check of the drafted `criteria.md`
- **Issue:** The plan's own `<verify>` block requires `grep -c 'human_needed' "$RD/criteria.md"` to equal exactly 2. The first draft used the literal word `human_needed` six times (twice as the two per-criterion `Status:` lines the check is meant to count, plus four more times in prose, the summary table, and the closing sentence), which would have made the count 6, not 2.
- **Fix:** Kept exactly two `**Status: \`human_needed\`**` lines (criteria 1 and 5) and reworded every other mention (prose, summary table, closing sentence) to refer back to those two statuses without repeating the literal token -- e.g. "사람 확인 필요" in the table, "위 절 참고" in the closing line.
- **Files modified:** `phase-06/results/20260830T073411Z-phase-close/criteria.md`
- **Verification:** `grep -c 'human_needed' "$RD/criteria.md"` == 2, and `grep -n 'human_needed' "$RD/criteria.md"` shows exactly the criterion-1 and criterion-5 `Status:` lines.
- **Committed in:** `db4a555` (Task 3 commit -- caught and fixed before that commit was made)

**3. [Rule 3 - Blocking] Two stray untracked evidence directories left by my own read-only exploration runs**
- **Found during:** Between Task 1 and Task 3, while re-confirming the live network posture before writing the documents
- **Issue:** Running `verify_network.sh` twice without `--out-dir` (to confirm the live `CASES 24/24` signature before writing `docs/network-exposure.md`) created two default-named timestamped directories under `phase-06/results/` that were not part of any task's declared evidence set.
- **Fix:** Deleted both (`rm -rf`) before any commit staged anything under `phase-06/results/`, so neither was ever added to git. Two similarly-shaped stray `-gate` directories already existed under `phase-05/results/` from prior sessions (an established, harmless side-effect pattern of running `verify_services.sh` without `--out-dir`) -- left untouched, consistent with the existing repo convention of not retroactively cleaning up prior plans' side effects.
- **Files modified:** none (deleted files were never committed)
- **Verification:** `git status --short` at plan end shows no untracked directory under `phase-06/results/` beyond the one intentional `20260830T073411Z-phase-close/`.
- **Committed in:** N/A (nothing to commit -- the fix was a deletion of never-staged files)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking-cleanup) -- all caught and resolved before their respective task commits, none required a checkpoint or architectural decision.
**Impact on plan:** None on scope or content. All three were self-inflicted authoring artifacts of this plan's own evidence-writing process, not carried-forward issues from any prior plan.

## Issues Encountered

None beyond the three deviations above, all resolved within Task 3 before its commit.

## User Setup Required

**The iPad checklist is the concrete next step for the user, whenever convenient:**
`phase-06/IPAD-CHECKLIST.md` -- both iPads need a Tailscale re-login (offline 29d and 4d
respectively) before item 1 can even be attempted. No dashboard configuration, environment
variables, or Mac-side action is required; the network is already open.

**Optional, self-serve, for later:** if the user wants to resolve NET-05's open Telegram
question, `phase-06/results/20260830T071532Z-net05/decision.md`'s 7-step checklist (also
referenced from `phase-06/IPAD-CHECKLIST.md` item 4b) covers the full BotFather-token-to-cleanup
cycle.

## Next Phase Readiness

**Phase 6 is closed on the record.** Three of five ROADMAP criteria (NET-02, NET-03, NET-04) are
proven with live evidence; two (NET-01, NET-05) are honestly `human_needed` with a concrete
checklist and no overclaiming anywhere in the record. The network is open
(`https://ohama-2.tail318f12.ts.net:8444/` -> proxy `127.0.0.1:18484` -> kanban `127.0.0.1:3484`),
port 3000 stays unbound with the danger clearly documented, `AllowFunnel` still holds exactly its
one pre-existing key, and `verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline`
is the re-runnable standing gate handed to Phase 7 and Phase 8 (current steady-state signature:
`CASES 24/24`).

**Phase 7/8 handoff items, explicitly flagged and not to be rediscovered from scratch:**
- The `~/.gitconfig` sandbox-denial finding (kanban's live server cannot register any git-backed
  project under the current Phase-3 sandbox profile) -- `docs/network-exposure.md` §9 and
  `phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt`.
- The `--no-tools`/`--auto-approve false` posture escalation requirement -- flipping either
  requires an explicit human decision, per `docs/headless-wrapper.md` §4, restated in
  `docs/network-exposure.md` §9.
- The 2026-08-30 correction (`settings.contextWindow` 29000, trigger 26100) must be carried
  forward as-is -- do not reuse 32768/26542/`models[]`.

No blockers. Live pids unchanged throughout this plan (flashnext 46573, litellm 48525, role-shim
75548, kanban 53894, telegram-connect 99162, kanban-proxy 19669); `EXTRA_ALLOW_PATHS` empty; port
3000 unbound; zero mutating `tailscale` commands issued anywhere in this plan; `cline`
invocations this plan: 0 (phase-wide total across all eight 06-* plans: 0, well within the
budget of 2-3 the phase's house rules allowed).

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30*
