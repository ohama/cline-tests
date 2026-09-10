---
phase: 12-documentation-update
plan: 06
subsystem: docs
tags: [max_tokens, compaction, cline, litellm, correction, verify_docs]

# Dependency graph
requires:
  - phase: 11-config-hardening
    provides: "phase-11/OPEN-ITEMS.md Open Item 2 (20983 measurement), phase-11/AB-PROTOCOL.md §3
      (278-sample dynamic-sizing analysis), phase-11/PHASE-11-FINDINGS.md §5.3/§5.5"
  - phase: 12-documentation-update (wave 1)
    provides: "phase-12/verify_docs.sh (the grader), phase-12/SCOPE-DECISIONS.md item 1 (this
      correction declared in scope)"
provides:
  - "docs/cline-max-tokens-findings.md corrected: no fixed OBSERVED_MAX asserted as current fact;
    dynamic per-request sizing with its 278-sample basis; original preserved verbatim in a new §9
    appendix"
  - "docs/32k-compaction-policy.md §4's overshoot arithmetic corrected without disturbing the
    2026-08-30 correction or its appendix"
  - "docs/manual/04-32k-operations.md §3's formula annotated against a fixed-max_tokens mental
    model"
affects: []

tech-stack:
  added: []
  patterns:
    - "Second, additively-stacked correction banner on a document that already carries one from an
      earlier round — never replace or renumber the earlier banner away."
    - "Appendix rows from an earlier correction round that are themselves superseded again get an
      annotation note placed outside the <details> verbatim block, not an edit inside it."

key-files:
  created: []
  modified:
    - docs/cline-max-tokens-findings.md
    - docs/32k-compaction-policy.md
    - docs/manual/04-32k-operations.md

key-decisions:
  - "Moved the original §2/§4/§5 of cline-max-tokens-findings.md verbatim into a new §9 appendix
    rather than editing them in place, mirroring 32k-compaction-policy.md's own precedent, since
    the plan required the pre-correction OBSERVED_MAX conclusion, Branch A reasoning, and budget
    table to survive verbatim, not just be described."
  - "Did not re-derive Branch A or invent a new branch decision for cline-max-tokens-findings.md
    §4 — stated the premise (OBSERVED_MAX < 6226) is void because 20983 does not satisfy it, and
    left re-derivation as explicit v1.2 work, per the plan's own instruction not to fabricate a
    conclusion this phase did not reach."
  - "Fixed two pre-existing verify_docs.sh failures in the target files that were not the plan's
    named task but blocked the plan's own must_have ('verify_docs.sh reports no failure naming
    these files'): a TAG_CITATION gap in 32k-compaction-policy.md (cli-v3.0.53 cited without the
    required git-show form) and an AB_DISCLOSURE false trigger in cline-max-tokens-findings.md
    (the substring 'Branch A/B1/B3' matched the literal 'A/B' check). Both were resolved by
    following scope-decision 6's own convention (add the git-show form) and by moving the
    offending sentence into the appendix as part of the planned §4 rewrite, respectively — no
    unrelated content was invented to satisfy the grader."

# Metrics
duration: ~35min
completed: 2026-09-10
---

# Phase 12 Plan 06: Correct the fixed max_tokens=2048 claim to dynamic per-request sizing Summary

**Both documents that asserted a fixed wire `max_tokens=2048` now say instead that cline sizes the
completion budget per request toward `contextWindow × 0.9`, cite the 278-sample basis (9,442–32,013,
zero breaches of 32,768), and preserve every number and banner that came before.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-09-10T08:56Z
- **Tasks:** 2/2
- **Files modified:** 3 (`docs/cline-max-tokens-findings.md`, `docs/32k-compaction-policy.md`,
  `docs/manual/04-32k-operations.md`)

## Accomplishments

- `docs/cline-max-tokens-findings.md` no longer states a fixed `OBSERVED_MAX`. It now explains the
  single-sample generalisation that produced `2048`, cites the `20983` like-for-like remeasurement
  (`phase-11/OPEN-ITEMS.md` Open Item 2), and states the 278-sample per-request-sizing finding
  (`phase-11/AB-PROTOCOL.md` §3, `phase-11/PHASE-11-FINDINGS.md` §5.3) without overclaiming it into
  a guarantee. §4's Branch A condition (`OBSERVED_MAX < 6226`) is stated as void — not
  re-derived, not replaced with an invented new branch. §5's dead `26100 + 2048 = 28148` arithmetic
  is replaced by the measured picture. A new §7 change table, §8 unresolved section (CFG-05 drift;
  the sizing rule is inference from 278 samples of one workload, not a source reading), and §9
  appendix (verbatim original §2/§4/§5) were added.
- `docs/32k-compaction-policy.md` §4's overshoot arithmetic is corrected: the `prompt_tokens +
  max_tokens ≤ 32768` constraint stands (it's the server's real limit), but the fixed-`2048` half is
  replaced with the dynamic-sizing finding, and the existing overshoot table's `+max_tokens` column
  is explicitly marked void while its `trigger`/`+오버슈트` columns (real `exp-verify29k`
  measurements) are left standing. §8's dead Branch A justification is replaced while the surviving
  `maxTokens`-is-ignored fact remains. The pre-existing 2026-08-30 banner and its §9 appendix
  (including the verbatim server log lines) are untouched; a second, separate 2026-09-10 banner
  sits alongside it, and the two appendix rows that were themselves superseded again (the
  `관측된 wire max_tokens` evidence row and the "무효가 되는 조건" trigger row) are annotated with a
  note placed just before the `<details>` block, not edited inside it.
- `docs/manual/04-32k-operations.md` §3's `trigger + 3,100 + max_tokens < MAX_KV_SIZE` formula now
  carries a one-sentence note that `max_tokens` is not a small constant and points at
  `docs/cline-max-tokens-findings.md`; the page is otherwise untouched.
- Fixed two mechanical grader failures in the target files that predated this plan's edits
  (`TAG_CITATION` on the `cli-v3.0.53` source citation in `32k-compaction-policy.md`, and a false
  `AB_DISCLOSURE` trigger from the substring `A/B1/B3` in `cline-max-tokens-findings.md`'s old §4),
  since the plan's own must_have requires zero `verify_docs.sh` failures naming these files.

## Task Commits

Both tasks were completed as a single set of edits and committed together, since they are tightly
coupled (the consuming document's arithmetic cannot be corrected before its source document is):

1. **Task 1: Correct docs/cline-max-tokens-findings.md at the source of the claim** — part of
   `1347dc4`
2. **Task 2: Correct the consuming arithmetic in 32k-compaction-policy.md and annotate the
   operations formula** — part of `1347dc4`

**Commit:** `1347dc4` — `docs(12-06): correct fixed max_tokens=2048 claim to dynamic per-request
sizing`

## Files Created/Modified

- `docs/cline-max-tokens-findings.md` — banner, rewritten §2/§4/§5, new §7/§8/§9 (change table,
  unresolved, verbatim appendix)
- `docs/32k-compaction-policy.md` — second banner, §4 corrected arithmetic + annotated table, §8
  dead justification replaced, appendix rows annotated (not rewritten), `cli-v3.0.53` citation
  given the `git show` form
- `docs/manual/04-32k-operations.md` — one-sentence mental-model note under §3's formula

## Decisions Made

See `key-decisions` in the frontmatter above. In short: original text was moved to a new appendix
rather than edited in place (matching the file's own future §9 marker requirement); no new branch
decision was invented for the now-void Branch A premise; two pre-existing, plan-unrelated grader
failures in the same two files were fixed because the plan is graded on "no failure naming these
files," not "no failure this plan intentionally introduced."

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking issue] `TAG_CITATION` failure in `docs/32k-compaction-policy.md`, pre-existing**
- **Found during:** Task 2, running `phase-12/verify_docs.sh` before making any edits (baseline)
- **Issue:** §2's source citation `tag \`cli-v3.0.53\`` appeared in the live body without the
  literal `git show cli-v3.0.53:` form that `phase-12/SCOPE-DECISIONS.md` item 6 and
  `verify_docs.sh`'s `TAG_CITATION` class require, since `cline-src`'s working tree moved to
  `cli-v3.0.61`.
- **Fix:** Extended the existing citation sentence to include the `git show cli-v3.0.53:<path>`
  form and a pointer to scope decision 6, without changing what it cites.
- **Files modified:** `docs/32k-compaction-policy.md`
- **Verification:** `verify_docs.sh`'s `TAG_CITATION` line for this file changed from FAIL to OK.
- **Committed in:** `1347dc4` (part of the task 2 commit)

**2. [Rule 3 — Blocking issue] `AB_DISCLOSURE` false-positive trigger in `docs/cline-max-tokens-findings.md`, pre-existing**
- **Found during:** Task 1, running `phase-12/verify_docs.sh` before making any edits (baseline)
- **Issue:** The original §4 sentence "Branch A/B1/B3 는 이 두 스크립트를 건드릴 필요가 없다"
  contains the literal substring `A/B` (from `A/B1`), which unconditionally trips
  `verify_docs.sh`'s `AB_DISCLOSURE` check (a blunt literal-string match, unrelated to this
  document's subject) and demands unrelated disclosure elements (`p=0.563`, `25/30`,
  `phase-11/AB-RESULTS.md`) that have nothing to do with `max_tokens` sizing.
  This was a genuine pre-existing grader failure, confirmed by running `verify_docs.sh` against the
  unmodified file before any edit.
- **Fix:** The plan already required rewriting live §4 and moving its original text into the new
  §9 appendix (which `AB_DISCLOSURE` does not scan). No new text was written to work around the
  check; the offending sentence simply no longer appears in the live body as a side effect of the
  planned rewrite, and the sentence itself survives verbatim in the appendix.
- **Files modified:** `docs/cline-max-tokens-findings.md`
- **Verification:** `verify_docs.sh`'s `AB_DISCLOSURE` line for this file changed from FAIL
  (missing `p=0.563|25/30|...|phase-11/AB-RESULTS.md`) to `OK ... does not mention the A/B (check
  not triggered)`.
- **Committed in:** `1347dc4` (part of the task 1 commit)

No other deviations. Both tasks were otherwise executed exactly as specified.

## Verification Evidence

Full sweep, after both files were edited and committed:

```
$ bash phase-12/verify_docs.sh 2>&1 | tail -5
=== escape hatch summary: 2 use(s) of verify_docs:allow ===
ESCAPE[DOCS]: qanda/001-testing-plan-act-with-cline-cli.md:165
ESCAPE[DOCS]: qanda/003-how-the-wrappers-work.md:132

CASES 134/134
OK[DOCS]: all documentation assertions passed for DOCS_ROOT=/Users/ohama/projs/cline-tests
exit code: 0
```

Per-file lines for this plan's targets (all `OK[DOCS]`, zero `FAIL[DOCS]`):
`docs/32k-compaction-policy.md` — 13/13 assertions OK (FORBIDDEN x2, REQUIRED x5, REQUIRED_ANY x2,
CITED_PATHS_EXIST, TAG_CITATION, AB_DISCLOSURE, plus the presence check).
`docs/cline-max-tokens-findings.md` — 11/11 assertions OK (FORBIDDEN x1, REQUIRED x4, REQUIRED_ANY
x1, APPENDIX_INTEGRITY, CITED_PATHS_EXIST, TAG_CITATION, AB_DISCLOSURE, plus the presence check).

Baseline (before this plan's edits) for comparison — 4 FAILs on `docs/32k-compaction-policy.md`
(two FORBIDDEN, one REQUIRED, one REQUIRED_ANY) and 6 FAILs on `docs/cline-max-tokens-findings.md`
(FORBIDDEN, three REQUIRED, APPENDIX_INTEGRITY, AB_DISCLOSURE) — captured by running
`phase-12/verify_docs.sh` against the unedited tree before any change in this session.

Other guards:

```
$ bash phase-01/config/verify_config.sh   # exits 0, unchanged by this plan
$ git status --porcelain phase-01/        # clean — no probe was run
$ git diff --name-only HEAD~1 HEAD
docs/32k-compaction-policy.md
docs/cline-max-tokens-findings.md
docs/manual/04-32k-operations.md
```

No `cline`/model invocation was made in this session (bash/grep/sed/file-edit tools only); the
`phase-01/results/max-tokens-probe/` directory was not touched and no new run directory appeared
under any `results/`.

## Next Phase Readiness

No blockers. This closes `phase-12/SCOPE-DECISIONS.md` item 1 in full. Remaining Phase 12 work
(the other five wave-2 plans) is independent — this plan touched only its three declared files and
made one commit (`1347dc4`) containing exactly those three files.
