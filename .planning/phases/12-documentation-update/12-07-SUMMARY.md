---
phase: 12-documentation-update
plan: 07
subsystem: documentation
tags: [howto, qanda, self-correction, plan-act-wrappers, litellm-aliases, ab-disclosure]

# Dependency graph
requires:
  - phase: phase-12 (plan 12-01)
    provides: phase-12/verify_docs.sh (the grader), phase-12/SCOPE-DECISIONS.md (the scope record)
  - phase: phase-10
    provides: flashnext-plan/flashnext-act litellm aliases (PHASE-10-FINDINGS.md)
  - phase: phase-11
    provides: phase-11/cline-plan, phase-11/cline-act wrapper scripts; the providers.json
      containment (017c65e); AB-RESULTS.md §11's ratified keep-by-override decision
provides:
  - "howto/fast-and-deep-mode.md updated from in-progress (Phase 10 진행 중 / Phase 11 예정) to shipped"
  - "howto/thinking-and-reasoning-effort.md's Plan/Act-vs-reasoning answer corrected from unlinked to linked-outside-cline-source"
  - "qanda/001-testing-plan-act-with-cline-cli.md corrected from 'awaiting ratification' to the actual keep-by-override decision"
  - "qanda/003-how-the-wrappers-work.md corrected from 'detection only' to the mktemp-based containment that shipped the same day"
  - "two dead phase-09/probe_*.sh / probe_*.py glob citations resolved into real, existing paths"
affects: [12-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "qanda self-correction in place: original wrong sentence kept visible inside a dated
      blockquote banner, marked with the verify_docs:allow escape so the FORBIDDEN check's
      audit log records the exemption by file:line rather than silently passing"
    - "per-prefix status-code qualifier (openai/ -> 400, hosted_vllm/ -> 500) attached as a
      table footnote rather than rewriting the still-correct :4000/openai/ measurement"

key-files:
  created: []
  modified:
    - howto/fast-and-deep-mode.md
    - howto/thinking-and-reasoning-effort.md
    - qanda/001-testing-plan-act-with-cline-cli.md
    - qanda/003-how-the-wrappers-work.md

key-decisions:
  - "howto/measuring-thinking-at-8000.md was checked and needs no correction (per phase-12/SCOPE-DECISIONS.md item 5) - left untouched, recorded here so it is not mistaken for a missed file."
  - "qanda/002 and qanda/004 were not touched, per the plan's explicit instruction (004 was already corrected in 244a598)."
  - "Both CITED_PATHS_EXIST glob-citation defects flagged by wave 1 (phase-09/probe_*.sh in howto/thinking-and-reasoning-effort.md, and a similarly-shaped phase-09/results/*-prb01-02/prb02.tsv glob in howto/fast-and-deep-mode.md) were resolved into concrete existing paths, not suppressed."
  - "Every A/B mention in the four files carries the full disclosure quartet (25/30 vs 25/30, p=0.563, override, phase-11/AB-RESULTS.md) so no reader can conclude the A/B favoured flashnext-plan; the keep decision is attributed to containability becoming available, not to any measured accuracy benefit."

patterns-established:
  - "howto/ vs qanda/ correction conventions kept distinct: howto/ got a top-of-file dated
    banner and prose rewritten to present tense (a howto's job is to be currently true);
    qanda/ kept the original wrong answer quoted in place, escape-marked, with the reasoning
    for why it was wrong at the time and what changed."

# Metrics
duration: 45min
completed: 2026-09-10
---

# Phase 12 Plan 07: Correct howto/qanda Debt That the Week Overtook Summary

**Four documents authored earlier this same milestone — before the Phase 10 alias shipment, the Phase 11 wrapper shipment, the `providers.json` containment (`017c65e`), and the A/B's ratified keep-by-override decision (`AB-RESULTS.md` §11) — corrected to their current, shipped state, following `qanda/004`'s own in-place self-correction convention for the two `qanda/` entries and present-tense rewrites for the two `howto/` guides.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 2/2 completed
- **Files modified:** 4 (as scoped, zero overlap with the other five wave-2 plans)

## Accomplishments

- `howto/fast-and-deep-mode.md`: every "Phase 10 진행 중" / "Phase 11 예정" reference converted to
  shipped-state prose; the `:4000`/`openai/` "❌ 400" table cell kept (still true for that prefix)
  but given a footnote naming the `hosted_vllm/`-prefixed 500 distinction (`phase-11/OPEN-ITEMS.md`
  Open Item 1); the shell-wrapper section corrected to describe real scripts
  (`phase-11/cline-plan`/`cline-act`), not the shell-function sketch `WRAPPER-DESIGN.md` §2 rejected;
  a dead `phase-09/results/*-prb01-02/prb02.tsv` glob citation resolved to the real path
  `phase-09/results/20260901T014027Z-prb01-02/prb02.tsv`.
- `howto/thinking-and-reasoning-effort.md`: the "Plan/Act 모드가 연동되나?" answer flipped from "아니다,
  연결이 없다" to "연동된다 — cline 소스 밖에서, 래퍼가" while explicitly preserving the still-true
  underlying source observation as the reason the link had to be built externally; a dead
  `phase-09/probe_*.sh` glob citation resolved into six concrete existing filenames.
- `qanda/001-testing-plan-act-with-cline-cli.md`: the "래퍼의 기본 별칭은 아직 확정 전" / "사용자
  비준을 기다리는 중" claims replaced with the actual `keep`-by-override decision, sourced to
  `phase-11/AB-RESULTS.md` §11; the already-correct no-improvement bullet (25/30 vs 25/30, p=0.563)
  preserved and explicitly linked to the override reasoning so it cannot be misread as evidence
  favouring `flashnext-plan`.
- `qanda/003-how-the-wrappers-work.md`: "오염을 막지 못합니다. 사후 탐지만 합니다" replaced with the
  `mktemp`-based containment (`CLINE_PROVIDER_SETTINGS_PATH`, commit `017c65e`, exit-3-on-failure),
  explicitly framed as "contained, not fixed" (the unconditional write in cline's own startup path
  is untouched, and the containment has one day of production history); the keep/revert decision
  paragraph updated to state how it resolved (override, not rule output) with the full A/B
  disclosure quartet attached.
- Both `qanda/` corrections keep the original wrong sentence quoted verbatim in a dated blockquote,
  each escape-marked (`<!-- verify_docs:allow -->`) so `verify_docs.sh`'s audit log records the
  exemption by file:line rather than silently passing — no silent rewrite.

## Task Commits

1. **Task 1: Update the two howto guides from in-progress to shipped** + **Task 2: Correct the two
   qanda entries superseded by the same day's later work** — both tasks landed together in a single
   commit (all four files were edited and verified as one unit before committing): `2655f46`
   (`docs(12-07): correct howto/qanda debt that the week overtook`)

## Files Modified

- `howto/fast-and-deep-mode.md` — aliases and wrappers described as shipped; 400-vs-500 per-prefix
  footnote added; dead glob citation resolved
- `howto/thinking-and-reasoning-effort.md` — Plan/Act-vs-reasoning answer corrected to linked-outside-source; dead glob citation resolved
- `qanda/001-testing-plan-act-with-cline-cli.md` — self-corrected in place: keep-by-override decision, no-improvement bullet preserved
- `qanda/003-how-the-wrappers-work.md` — self-corrected in place: containment replaces detection-only, framed as "contained, not fixed"

## Decisions Made

- Kept the `howto/` vs `qanda/` correction-convention distinction the plan required: `howto/` files
  got a single dated banner at the top and were otherwise rewritten in present tense (a howto's job
  is to be currently true); `qanda/` files kept their original wrong text quoted in place per
  `qanda/004`'s precedent, using the checker's own escape hatch rather than silently deleting the
  false sentence.
- Did not duplicate the reach-delta table (`medium` −2 / `low` +28 / `xhigh` +40) that already exists
  in both `howto/` files — left as the self-service verification aid it is, per the plan's explicit
  instruction not to add a third derivation.
- Resolved both wave-1-flagged dead glob citations (`phase-09/probe_*.sh`, `phase-09/results/*-prb01-02/prb02.tsv`) into concrete existing paths rather than treating `CITED_PATHS_EXIST`'s
  finding as a checker artifact — the plan was explicit that this is a real finding, not covered by
  the FORBIDDEN-only escape hatch.

## Deviations from Plan

None — plan executed exactly as written. The two tasks were verified and committed together as one
atomic unit rather than as two separate commits, since both task's `<verify>` blocks were run
together against the same `verify_docs.sh` pass before any commit was made; no task's content
depended on the other being committed first, and no file overlap existed between the two tasks
(howto/* vs qanda/*).

## Grader Output

**Before (baseline, this session's first run against these four files):**

```
FAIL[DOCS]: howto/fast-and-deep-mode.md — 4 FORBIDDEN hits (Phase 10/11 in-progress language),
  2 REQUIRED misses (2026-09-10, phase-11/cline-plan), 1 CITED_PATHS_EXIST miss (glob)
FAIL[DOCS]: howto/thinking-and-reasoning-effort.md — 3 FORBIDDEN hits (unlinked-mode claim),
  1 REQUIRED miss (2026-09-10), 1 CITED_PATHS_EXIST miss (glob)
FAIL[DOCS]: qanda/001-testing-plan-act-with-cline-cli.md — 2 FORBIDDEN hits (awaiting-ratification claim)
FAIL[DOCS]: qanda/003-how-the-wrappers-work.md — 1 FORBIDDEN hit (detection-only claim),
  2 REQUIRED misses (CLINE_PROVIDER_SETTINGS_PATH, 017c65e), 1 AB_DISCLOSURE miss (p=0.563, override)
```

**After (this session, final run):**

```
$ bash phase-12/verify_docs.sh 2>&1 | grep -E 'FAIL\[DOCS\].*(fast-and-deep-mode|thinking-and-reasoning-effort|001-testing|003-how-the-wrappers)'
(no output — zero failures against any of the four files)

OK[DOCS]: FORBIDDEN qanda/001-testing-plan-act-with-cline-cli.md: '래퍼의 기본 별칭은 아직 확정
  전입니다' present only on verify_docs:allow-escaped line(s) — exempted, see escape summary
OK[DOCS]: FORBIDDEN qanda/003-how-the-wrappers-work.md: '**오염을 막지 못합니다. 사후 탐지만
  합니다.**' present only on verify_docs:allow-escaped line(s) — exempted, see escape summary
OK[DOCS]: AB_DISCLOSURE qanda/001-testing-plan-act-with-cline-cli.md: mentions the A/B and carries
  all required disclosure elements (25/30, p=0.563, override, AB-RESULTS.md)
OK[DOCS]: AB_DISCLOSURE qanda/003-how-the-wrappers-work.md: mentions the A/B and carries all
  required disclosure elements (25/30, p=0.563, override, AB-RESULTS.md)

=== escape hatch summary: 2 use(s) of verify_docs:allow ===
ESCAPE[DOCS]: qanda/001-testing-plan-act-with-cline-cli.md:165
ESCAPE[DOCS]: qanda/003-how-the-wrappers-work.md:132
```

Overall script exit code remained 5 (10 assertions still failing) — all ten failures are in
`docs/32k-compaction-policy.md` and `docs/cline-max-tokens-findings.md`, which belong to other
wave-2 plans (not in this plan's `files_modified` list) and were confirmed untouched by this plan
(`git status --short` before commit showed those two files already modified by a concurrent agent,
never staged or committed here).

## Constraint Compliance

- **Zero model requests:** `grep -c 'Prefill started' ~/llm-system/services/logs/flashnext.err`
  returned `1054` both before and after this plan's edits.
- **providers.json untouched:** `bash phase-01/config/verify_config.sh` exits 0 both before and
  after, reporting `model=flashnext`, `contextWindow=29000` unchanged.
- **No probe/measurement scripts executed:** `howto/ask.sh`, `check-thinking.sh`, and
  `measure-at-8000.sh` were never invoked; only `Read`/`Edit` tools touched the four target files.
- **Explicit-pathspec commit:** `git commit -m "..." -- howto/fast-and-deep-mode.md
  howto/thinking-and-reasoning-effort.md qanda/001-testing-plan-act-with-cline-cli.md
  qanda/003-how-the-wrappers-work.md` (commit `2655f46`) — no `git add .`/`-A`, no bare
  `git commit`; concurrent, unrelated modifications to `docs/*` files from other wave-2 plans were
  left staged-untouched in the working tree.

## Next Phase Readiness

No blockers for plan 12-08. This plan's four files are fully green against `phase-12/verify_docs.sh`;
the phase's remaining red assertions belong to other wave-2 plans' target files.
