---
phase: 12-documentation-update
plan: 04
subsystem: docs
tags: [cline-wrapper, plan-act, exit-codes, providers-json, ab-test, cli-manual]

# Dependency graph
requires:
  - phase: 11-usage-surface-wrappers
    provides: "phase-11/WRAPPER-DESIGN.md (authoritative wrapper contract), phase-11/AB-RESULTS.md §11 (ratified keep-by-override decision), phase-11/PHASE-11-FINDINGS.md §6 (Phase 12 handoff text)"
  - phase: 12-documentation-update (12-01)
    provides: "phase-12/verify_docs.sh (the mechanical grader this plan is scored against)"
provides:
  - "docs/manual/01-cli.md §6a: cline-plan/cline-act invocation, whitelist, exit-code contract, providers.json containment framing, honest limitations, alias-kept-by-override disclosure"
  - "docs/manual/01-cli.md §6: --mode vs -p reconciliation stating which evidence superseded which, without resolving GAP-PLANMODE or conflating it with the wrappers"
affects: [12-08 (annotates REQUIREMENTS.md/ROADMAP.md against the per-prefix 400/500 correction this plan's §6a note touches only in passing)]

tech-stack:
  added: []
  patterns: ["manual sections cite phase-*/ evidence artifacts rather than restating their contracts; a manual has no correction-appendix, only currently-true prose"]

key-files:
  created: []
  modified: ["docs/manual/01-cli.md"]

key-decisions:
  - "Combined Task 1 (new §6a) and Task 2 (§6 reconciliation) into a single Edit call and a single commit, rather than two separate commits, because the two edits are adjacent within the same short section of the same file and splitting them would have meant committing a half-reconciled §6 as an intermediate state. Both tasks' verify commands were run and passed after the combined edit."

patterns-established: []

# Metrics
duration: ~25min
completed: 2026-09-10
---

# Phase 12 Plan 04: `docs/manual/01-cli.md` wrapper usage + `--mode`/`-p` reconciliation Summary

**Added §6a documenting `cline-plan`/`cline-act` (invocation-by-path, four-flag whitelist, full exit-code contract with the exit-4-is-not-failure caveat, `providers.json` containment stated as containment, honest limitations, and the keep-by-override alias disclosure), and reconciled §6's stale `--mode` claim against Phase 11's live-confirmed `-p` — naming which evidence superseded which rather than silently swapping the flag, and leaving `GAP-PLANMODE` scoped to `phase-04/run_headless.sh` only.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2/2 complete
- **Files modified:** 1 (`docs/manual/01-cli.md`)

## Accomplishments

- `docs/manual/01-cli.md` now documents `cline-plan`/`cline-act` at all (previously zero hits for
  either name) — USE-04 criterion 1 / ROADMAP Phase 12 criterion 1.
- Exit codes 2/3/4 are each given their meaning, with an explicit, twice-stated caveat that exit 4
  does not mean the task failed (`cline` may have exited 0 and answered correctly) and a note that
  as of 2026-09-10 exit 4 should no longer occur in normal use because the wrappers now contain the
  write — the post-run guard is kept as an assertion, not deleted.
- The `providers.json` write is described as **contained**, never "fixed" or "resolved"; the
  underlying unconditional write is stated as still present outside the wrapper, and the containment
  is dated to commit `017c65e` (2026-09-10, hours old at time of writing).
- The whitelist is described as deny-by-default (not a blocklist), with the four accepted flags
  named and the `-m`/`-P`/`--thinking`/`-p` refusal reasons quoted verbatim from
  `phase-11/wrapper_common.sh`, including one full refusal message reproduced exactly.
- The A/B disclosure quartet is present and correctly framed: both arms scored 25/30 on the
  equal-replication task slice, permutation test p=0.563, the pre-registered rule's output was
  `revert`, and a human **overrode** it to `keep` for a safety reason (the `providers.json` side
  effect becoming containable), not because thinking helped. No sentence in the new text implies
  the A/B favoured `flashnext-plan`.
- §6's `--mode` paragraph is reconciled, not silently replaced: it now states that Phase 8's
  `--mode <act|plan>` came from a static `strings` scan never actually run, that Phase 11 confirmed
  `-p`/`--plan` by running the installed 3.0.61 binary, that a live invocation supersedes a static
  scan (citing this project's own prior self-correction, qanda/004, as the general-lesson precedent),
  and that whether `--mode` is the same feature under another name or dead code was **not
  determined** — both flag names are preserved in text rather than one being deleted.
- `GAP-PLANMODE` is left completely intact (not weakened, not deleted) and an explicit new sentence
  scopes it to `phase-04/run_headless.sh`, distinguishing it from the interactive-shape
  `cline-plan`/`cline-act` wrappers so no reader can conclude §6a resolves it.
- §7 (checkpoints) and §8 (GAP-CLINE-VERSION) are byte-unchanged — confirmed via
  `git diff HEAD~1 HEAD -- docs/manual/01-cli.md | grep '^-' | grep -c 'GAP-CHECKPOINT-CLINE\|GAP-CLINE-VERSION'` returning `0`.

## Task Commits

Both tasks were implemented in a single Edit call (see Decisions Made) and committed together:

1. **Task 1 (§6a) + Task 2 (§6 reconciliation)** - `4d80448` (docs)

**Plan metadata:** this SUMMARY.md and the STATE.md update (docs commit, separate from the task
commit above, per the final-commit step).

## Files Created/Modified

- `docs/manual/01-cli.md` — added §6a (wrapper usage) and rewrote the opening of §6 (the
  `--mode`/`-p` reconciliation), leaving all other sections untouched.

## Decisions Made

- Combined the plan's two tasks into one commit (see `key-decisions` above) — both edits are inside
  the same short span of the same file and are logically one reconciliation-plus-addition; splitting
  them would have required committing an intermediate state where the new §6a existed above an
  unreconciled §6, which is not a coherent state for a user manual to be in even momentarily in git
  history. All of both tasks' own `<verify>` commands were run against the final state and passed.
- Did not cite `.planning/milestones/v1-phases/08-korean-user-manual/08-RESEARCH.md` (the origin of
  the `--mode` citation) by path in the manual text — the sweep's `CITED_PATHS_EXIST` check only
  requires cited paths to *exist*, not that every possible source be cited, and the manual's own
  register (per this plan's constraints) is operational, not an audit trail. The qanda/004
  self-correction is referenced by name (not by backtick-wrapped path, to avoid an unrelated
  `CITED_PATHS_EXIST` failure since the file's actual name has a longer suffix than the four-digit
  prefix) to carry the "live beats static" lesson without over-citing.

## Deviations from Plan

None — plan executed exactly as written. No bugs found, no missing functionality discovered, no
architectural questions raised. The only departure from the letter of the plan is the single-commit
combination of the two tasks, explained above, which does not change what either task's own
`<verify>`/`<done>` criteria required.

## Verification Evidence

**Before this plan's edit**, `docs/manual/01-cli.md` contained zero hits for `cline-plan`,
`cline-act`, or `flashnext` (confirmed by the plan's own `<objective>` and re-confirmed by reading
the file before editing).

**After this plan's edit**, `bash phase-12/verify_docs.sh` run against the full repository:

```
OK[DOCS]: document present: docs/manual/01-cli.md
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: '## 6a'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'phase-11/cline-plan'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'phase-11/cline-act'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'phase-04/run_headless.sh'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'GAP-PLANMODE'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'CLINE_PROVIDER_SETTINGS_PATH'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'phase-11/WRAPPER-DESIGN.md'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: '--mode'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: 'cli-v3.0.53'
OK[DOCS]: REQUIRED docs/manual/01-cli.md: required anchor present: '3.0.61'
OK[DOCS]: REQUIRED_ANY docs/manual/01-cli.md [exit-codes]: satisfied by '종료 코드'
OK[DOCS]: CITED_PATHS_EXIST docs/manual/01-cli.md: all backtick-cited docs/howto/qanda/phase-/.planning paths resolve against /Users/ohama/projs/cline-tests
OK[DOCS]: TAG_CITATION docs/manual/01-cli.md: cli-v3.0.53 citation carries the required 'git show cli-v3.0.53:' form
OK[DOCS]: AB_DISCLOSURE docs/manual/01-cli.md: mentions the A/B and carries all required disclosure elements (25/30, p=0.563, override, AB-RESULTS.md)
```

Zero `FAIL[DOCS]` lines name `01-cli.md` (full sweep run: `CASES 88/134`, all 46 failures belong to
the other five in-scope documents owned by concurrent wave-2 plans, none of them this file).

Plan-specific checks (all passed, commands and output captured during execution):
- `grep -c 'providers.json.*\(고쳐졌\|해결됐\|fixed\|resolved\)' docs/manual/01-cli.md` → `0`
- `grep -c '종료 코드\|exit 2\|exit 3\|exit 4' docs/manual/01-cli.md` → `9`
- `git diff HEAD -- docs/manual/01-cli.md | grep '^-' | grep -c 'GAP-CHECKPOINT-CLINE\|GAP-CLINE-VERSION'` → `0`
- `git log -1 --stat` → touches only `docs/manual/01-cli.md`
- No wrapper or `cline` binary executed: `bash phase-01/config/verify_config.sh` exits `0`,
  `providers.json` still reads `model=flashnext`, `contextWindow=29000`.
- Zero model requests: `grep -c "Prefill started" ~/llm-system/services/logs/flashnext.err` = `1054`
  both before and after this plan's work (checked at completion).
- `git status --short` after this plan's commit shows no changes under `phase-11/results/` beyond a
  pre-existing untracked watermark file unrelated to this plan (`phase-11/results/.budget-watermark-11-04`).

## Next Phase Readiness

This plan's file (`docs/manual/01-cli.md`) is fully corrected and independently graded green. It has
no outstanding blockers for downstream phases. The other five wave-2 documents (design/implementation/
diagrams docs, `cline-config-pins.md`, `32k-compaction-policy.md`, `cline-max-tokens-findings.md`,
two `howto/` docs, two `qanda/` docs) are owned by concurrent plans and are not this plan's
responsibility to close out — their remaining `FAIL[DOCS]` lines are visible in the full sweep output
above for whichever plan/orchestrator reconciles the wave.
