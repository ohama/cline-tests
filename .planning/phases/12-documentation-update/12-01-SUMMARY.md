---
phase: 12-documentation-update
plan: 01
subsystem: testing
tags: [bash, documentation-linting, mutant-testing, verify-scripts]

# Dependency graph
requires:
  - phase: phase-11
    provides: WRAPPER-DESIGN.md, OPEN-ITEMS.md, AB-RESULTS.md, PHASE-11-FINDINGS.md as the corrected-replacement source of truth wave 2 must reconcile against
provides:
  - "phase-12/verify_docs.sh — the mechanical, six-class documentation sweep (FORBIDDEN, REQUIRED, REQUIRED_ANY, CITED_PATHS_EXIST, TAG_CITATION, AB_DISCLOSURE) plus APPENDIX_INTEGRITY, graded against all eleven Phase 12 target documents"
  - "phase-12/selftest_verify_docs.sh — the M1-M8 mutant ladder proving each assertion class can fail, plus a clean control"
  - "phase-12/SCOPE-DECISIONS.md — the phase's eight recorded scope decisions with reasons"
  - "phase-12/results/CURRENT_RED_RUN — the captured RED baseline (exit 5) all six wave-2 plans are graded against reaching exit 0"
affects: [12-02, 12-03, 12-04, 12-05, 12-06, 12-07, 12-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "live-body/appendix split on a literal marker line, so forbidden-string checks never collide with a preserved pre-correction original (docs/32k-compaction-policy.md's own precedent, made mechanical)"
    - "auditable escape hatch: an exemption must appear in the transcript by file:line to count as caught, never merely exit 0"
    - "mutant ladder written and proven before the thing it grades is edited, per phase-11/selftest_verify_wrappers.sh's pattern"

key-files:
  created:
    - phase-12/verify_docs.sh
    - phase-12/selftest_verify_docs.sh
    - phase-12/SCOPE-DECISIONS.md
    - phase-12/results/20260910T084101Z-red/ (red.txt, red-exit.txt, README.md)
    - phase-12/results/20260910T084145Z-mutants/ (docs-selftest.tsv, mutants/M1-M8.out)
    - phase-12/results/CURRENT_RED_RUN
  modified: []

key-decisions:
  - "REQUIRED checks (per plan spec) grade the whole file, not just the live body — a preserved appendix citing the same evidence artifact must not make a REQUIRED anchor fail."
  - "CITED_PATHS_EXIST resolves against REPO_ROOT, not DOCS_ROOT, so a fixture tree under test still validates citations of real evidence artifacts (phase-11/WRAPPER-DESIGN.md etc.), matching the plan's explicit instruction."
  - "The escape hatch (verify_docs:allow) is scoped to FORBIDDEN checks only, per the plan's literal wording ('a forbidden-string check') — it does not exempt CITED_PATHS_EXIST, REQUIRED, or any other class."
  - "docs/32k-compaction-policy.md is registered appendix_required=0 (it already carries an appendix from an earlier, out-of-phase correction round; this phase's new correction is graded on FORBIDDEN/REQUIRED only, not APPENDIX_INTEGRITY, since the plan's own table did not tag it appendix_required)."

patterns-established:
  - "Grader-before-edit discipline: verify_docs.sh, its mutant proof, and its RED baseline all exist and are committed before any wave-2 plan touches a target document."

# Metrics
duration: 55min
completed: 2026-09-10
---

# Phase 12 Plan 01: Documentation Sweep Grader Summary

**A six-assertion-class, bash-3.2 documentation sweep (`phase-12/verify_docs.sh`) covering all eleven Phase 12 target documents, proven able to fail by an 8-mutant ladder (M1-M8, all CAUGHT/PASS), with a captured RED baseline (exit 5, 84/134 cases failing, all eleven documents named) that wave 2's six plans are graded against — no document edited, zero model requests issued.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-09-10T08:20:00Z (approx.)
- **Completed:** 2026-09-10T08:42:00Z (approx.)
- **Tasks:** 3/3 completed
- **Files modified:** 4 new files + captured run artifacts (0 pre-existing files touched)

## Accomplishments

- **`phase-12/verify_docs.sh`** — the standing grader for the whole phase. Six assertion classes
  (FORBIDDEN, REQUIRED, REQUIRED_ANY, CITED_PATHS_EXIST, TAG_CITATION, AB_DISCLOSURE) plus
  APPENDIX_INTEGRITY, applied to a hardcoded table covering all eleven target documents. Exit 5
  on any failure (distinct from `verify_config.sh`'s 1 and `verify_wrappers.sh`'s 3). Absence of
  a target document is itself a failure. Every FORBIDDEN literal was cross-checked byte-for-byte
  against the real, currently-uncorrected files before being trusted (see Deviations below — one
  transcription bug found and fixed this way).
- **`phase-12/selftest_verify_docs.sh`** — eight mutants (M1-M8) built against synthetic,
  from-scratch fixtures (never copies of the real docs, since those are still uncorrected). All
  eight verdicts came back correct on the first real run: M1-M7 CAUGHT, M8 PASS, selftest exits
  0. M7 specifically proves the escape hatch is auditable: the mutant sets a forbidden sentence
  behind `<!-- verify_docs:allow -->` and the selftest requires BOTH exit 0 AND an
  `ESCAPE[DOCS]: file:line` line in the transcript to count as CAUGHT — a silent exemption would
  not have passed this bar.
- **RED baseline captured** (`phase-12/results/20260910T084101Z-red/`, pointed to by
  `phase-12/results/CURRENT_RED_RUN`): `bash phase-12/verify_docs.sh` against the real repository
  exits 5, 50/134 cases passing, 84 failing, and every one of the eleven target documents appears
  in the `FAIL[DOCS]` lines — no document produced a suspicious zero-finding quiet pass.
- **`phase-12/SCOPE-DECISIONS.md`** — all eight scope decisions recorded with reasons: four
  inherited (max_tokens dynamism in scope, howto/qanda staleness in scope,
  `flashnext-reach-xhigh` kept as verification-only/v1.2 removal candidate, `--mode` superseded
  by the live-confirmed `-p`), four settled here (three not four `howto/` docs; `cline-src`'s tag
  move to `cli-v3.0.61` with all five Phase 9 citation paths re-verified resolvable at
  `cli-v3.0.53` via `git show`, including the corrected `agent-message-codec.ts` path under
  `sdk/packages/core/src/runtime/config/`; `providers.json` as point-in-time, not a pin; the
  per-alias-prefix 400/500 status code correction).

## Task Commits

1. **Task 1: Record scope decisions** — `7fa7c1e` (docs)
2. **Task 2: Write verify_docs.sh** — `5da7b7c` (feat)
3. **Task 3: Selftest ladder + RED baseline** — `dbb6169` (test) — includes the fix to the
   transcription bug found while building Task 2's assertion table (folded into the feat commit
   was not possible since it was discovered only while cross-checking during Task 3; the fix
   itself is a one-line edit inside `verify_docs.sh` made before this commit, so `5da7b7c` in the
   log already reflects the corrected literal — see Deviations for the actual sequence)

**Plan metadata:** (this summary's own commit, made after this file is written)

## Files Created/Modified

- `phase-12/verify_docs.sh` — the sweep: six assertion classes + APPENDIX_INTEGRITY against all
  eleven target documents, bash 3.2, `set -uo pipefail` (no `-e`), exit 5/0.
- `phase-12/selftest_verify_docs.sh` — the M1-M8 mutant ladder, synthetic fixtures built from
  scratch, TSV output, house `=== overall selftest verdict: PASS|FAIL ===` line.
- `phase-12/SCOPE-DECISIONS.md` — all eight scope decisions with reasons and verified evidence.
- `phase-12/results/20260910T084101Z-red/{red.txt,red-exit.txt,README.md}` — the captured RED
  baseline.
- `phase-12/results/20260910T084145Z-mutants/{docs-selftest.tsv,mutants/M1-M8.out}` — the mutant
  ladder's captured transcript.
- `phase-12/results/CURRENT_RED_RUN` — pointer file to the RED run directory.

## Decisions Made

- **REQUIRED checks grade the whole file (live body + appendix), not just the live body.** The
  plan's own spec for class 2 says "must appear anywhere in the file" — this matters because a
  document citing an evidence artifact both in its corrected live body and in its preserved
  appendix should not be double-jeopardized; only FORBIDDEN and APPENDIX_INTEGRITY care about the
  live-body/appendix distinction.
- **CITED_PATHS_EXIST resolves against `REPO_ROOT`, never `DOCS_ROOT`.** This is what lets the
  selftest's synthetic fixture tree (which is not a full repo mirror) still validate citations of
  real evidence artifacts like `phase-11/WRAPPER-DESIGN.md`, and it's what makes M4 (a genuinely
  dead citation, `phase-99/NOPE.md`) fail for the right reason rather than "file not found because
  the fixture tree is incomplete."
- **The escape hatch exempts FORBIDDEN checks only.** Re-reading the plan's own wording ("a line
  exempted from a forbidden-string check") confirms this scope; `verify_docs:allow` does not and
  should not silence a CITED_PATHS_EXIST or REQUIRED failure.
- **`docs/32k-compaction-policy.md` is not tagged `appendix_required` in this table**, even though
  it already has an appendix from an earlier (pre-Phase-12) correction round, because the plan's
  own assertion-table entry for this file does not carry the `appendix_required` tag other rows
  do. Its FORBIDDEN/REQUIRED assertions are graded on the live body/whole file as normal; no
  APPENDIX_INTEGRITY check runs against it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FORBIDDEN literal for `docs/plan-act-reasoning-implementation.md` was missing backticks present in the real target sentence**

- **Found during:** Task 2, while cross-checking every FORBIDDEN literal against the real,
  currently-uncorrected files (a step not explicitly required by the plan's own `<verify>` block,
  done because the plan's own warning — "This project has produced seven instruments that
  reported clean while observing nothing" — made an unverified literal table unacceptable to ship).
- **Issue:** The plan's assertion-table row 293 gives the FORBIDDEN literal as
  `reasoning 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다` (no backticks around
  `reasoning`). The real sentence on disk (`docs/plan-act-reasoning-implementation.md:99`) reads
  `` `reasoning` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다.`` — with `reasoning`
  backtick-wrapped. `12-RESEARCH.md`'s own verbatim quote of this same sentence (§A2) correctly
  includes the backticks, confirming the plan's transcription (not the research) was the one that
  dropped them. As written, this FORBIDDEN check would never fire against the real sentence — an
  unproven assertion masquerading as a proven one, exactly the failure mode this plan exists to
  prevent.
- **Fix:** Added the backticks to the literal so it matches the real sentence byte-for-byte.
  Verified afterward with an exhaustive Python cross-check of all 89 FORBIDDEN/REQUIRED literals
  in the table against their real target files: zero further mismatches found.
- **Files modified:** `phase-12/verify_docs.sh` (one line).
- **Verification:** Before the fix, this FORBIDDEN check passed against the real repository
  (false negative — the sentence is still there, uncorrected). After the fix, it correctly fails
  in the RED baseline (`FAIL[DOCS]: FORBIDDEN docs/plan-act-reasoning-implementation.md: ... —
  99:  \`reasoning\` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다.`), and the M1 mutant for
  this same file (a different sentence) is independently CAUGHT.
- **Committed in:** `5da7b7c` (the fix predates this commit — it was made while iterating on the
  Task 2 file before the file was ever committed, so the committed `verify_docs.sh` already
  contains the corrected literal; there is no separate fix commit).

---

**Total deviations:** 1 auto-fixed (1 bug).
**Impact on plan:** Necessary for correctness — an unfixed transcription gap would have shipped
an assertion that silently never fires, which is precisely the "eighth clean-but-observing-nothing
instrument" the plan explicitly warned against. No scope creep; the assertion table's intent and
content are otherwise unchanged from the plan.

## Issues Encountered

None beyond the deviation above. Every other design decision resolved without ambiguity once the
plan's own text was read carefully (in particular, the two lines in the plan using double-backtick
markdown fencing to write a literal containing an embedded backtick —
``max_tokens` 실측값은 `2048`.`` and `**`OBSERVED_MAX = 2048`.**` — were disambiguated by
direct comparison against the real files, both confirmed to match exactly as transcribed).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Ready:** All six wave-2 plans (12-02 through 12-07) now have an unambiguous, mechanical
definition of "done" per document they own, and can run `bash phase-12/verify_docs.sh` against
the real repository at any point to see exactly which FORBIDDEN literals remain and which
REQUIRED/REQUIRED_ANY/CITED_PATHS_EXIST/TAG_CITATION/AB_DISCLOSURE/APPENDIX_INTEGRITY assertions
are still unmet, per document. `phase-12/SCOPE-DECISIONS.md` answers the eight scope questions so
none of them need to be re-litigated.

**Assertion classes and which mutant proves each** (all CAUGHT/PASS in one session,
`phase-12/results/20260910T084145Z-mutants/docs-selftest.tsv`):

| Class | Mutant | Verdict |
|---|---|---|
| FORBIDDEN (live-body false string) | M1 | CAUGHT |
| REQUIRED (anchor missing) | M2 | CAUGHT |
| AB_DISCLOSURE (conditional, outcome-neutral) | M3 | CAUGHT |
| CITED_PATHS_EXIST (dead citation) | M4 | CAUGHT |
| APPENDIX_INTEGRITY (appendix content deleted, marker survives) | M5 | CAUGHT |
| TAG_CITATION (3.0.53 cite without git-show form) | M6 | CAUGHT |
| Escape hatch auditability (must appear in transcript, not just exit 0) | M7 | CAUGHT |
| Clean control (unmutated fixture set) | M8 | PASS |

**No assertion class went unexercised.** REQUIRED_ANY is implicitly exercised by every mutant that
leaves a REQUIRED_ANY's alternatives untouched (all pass in M8 and stay passing in every other
mutant, since none of the seven defect mutants target a REQUIRED_ANY row specifically) — this is
the one class without its own dedicated mutant number, matching the plan's own enumeration (M1-M8
maps to seven defect classes plus one control; REQUIRED_ANY is structurally identical to REQUIRED
in the checker's logic — same `grep -qF` mechanism, differing only in trying multiple
alternatives — and M2's proof that a missing-anchor failure fires applies to the underlying
mechanism both classes share). Recorded here rather than silently assumed, per the plan's own
instruction to say so if a class goes unproven — REQUIRED_ANY's mechanism-level coverage via M2 is
judged sufficient given it shares `check_required`'s core `grep -qF` primitive with a trivial
`IFS='|'` alternation wrapper, and both classes were separately confirmed passing/failing
correctly during the exhaustive per-literal cross-check described in the deviation above.

**RED baseline result:** exit 5, 50/134 cases passing, 84 failing, all eleven target documents
named in `FAIL[DOCS]` lines, zero escape-hatch uses. Captured at
`phase-12/results/20260910T084101Z-red/`, pointed to by `phase-12/results/CURRENT_RED_RUN`.

**What surprised me:** `check_manual_claims.sh`'s own header warning about forbidden-string
checks colliding with legitimate prose turned out to have a live, if minor, analogue inside
`CITED_PATHS_EXIST` rather than `FORBIDDEN`: `howto/fast-and-deep-mode.md` and
`howto/thinking-and-reasoning-effort.md` both currently cite glob-pattern paths in backticks
(e.g. `` `phase-09/results/*-prb01-02/prb02.tsv` ``, `` `phase-09/probe_*.sh` ``) that `test -e`
correctly reports as non-existent (a literal `*` is not a wildcard to `test -e`). The plan's spec
for this class gives skip conditions for `~`, a leading `/`, and a space, but not for glob
characters — so per a literal reading of the plan, this is a real, intended finding, not a
checker bug, and I left it un-special-cased. Flagging it here explicitly for whichever wave-2 plan
owns those two `howto/` files: this specific `FAIL[DOCS]: CITED_PATHS_EXIST` is real and will
persist until either the citation is rewritten to name a single existing file/directory, or (if
the illustrative-glob framing is judged legitimate) it is not resolved by this checker at all —
the escape hatch does not cover CITED_PATHS_EXIST by design (see Decisions Made above), so the
only mechanical path to green here is editing the citation itself.

No blockers for wave 2. Zero model requests were issued by this plan (`Prefill started` count in
`flashnext.err` before: 1054, after: 1054); no service was restarted; `providers.json` untouched;
`bash phase-01/config/verify_config.sh` exits 0.

---
*Phase: 12-documentation-update*
*Completed: 2026-09-10*
