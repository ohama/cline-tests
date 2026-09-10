---
phase: 11-usage-surface-wrappers
verified: 2026-09-10T07:54:00Z
status: passed
score: 7/7 plans' must_haves verified (truths, artifacts, key_links) + all 3 ROADMAP success criteria confirmed live
human_verification:
  - test: "qanda/004-does-cline-always-write-providers-json.md §5 still reads '아직 제안이지 구현이 아닙니다' (still a proposal, not an implementation) even though the containment it describes was implemented four minutes later (017c65e) and, per this verification, does work end to end through the real wrapper scripts."
    expected: "A human/maintainer should add one line to qanda/004 §5 noting the implementation landed in 017c65e and was verified — or delete the now-false disclaimer — so the file that PHASE-11-FINDINGS.md, AB-RESULTS.md §11 and wrapper_common.sh's own header all cite as evidence does not contradict them."
    why_human: "Not a functional defect (independently re-verified live below), just a stale sentence in a cited evidence file; a documentation edit, not a re-run."
---

# Phase 11: 사용 표면 — 래퍼와 A/B 게이트 Verification Report

**Phase Goal:** `cline-plan`/`cline-act` wrappers enforce the mode↔alias pairing, and an A/B decides
whether `medium` thinking actually improves results — a "no improvement" result is an equally valid
pass (ROADMAP, USE-01/02/03).

**Verified:** 2026-09-10T07:54:00Z
**Status:** passed
**Re-verification:** No — initial verification

**Model requests spent by this verification pass:** 2 (one `cline-act` call, one `cline-plan`
call — see "Containment" section below). Both were spent deliberately to close a gap this pass
found in the recorded evidence for commit `017c65e`'s wrapper-level claim; every other check in
this report ran against `phase-11/testing/stub-cline` or was a static/structural read, confirmed
by `~/llm-system/services/logs/flashnext.err` line count being unchanged by every other command run
in this pass.

---

## Goal Achievement — Observable Truths (aggregated across all 7 plans)

| # | Truth (paraphrased, full text in each PLAN.md `must_haves`) | Status | Evidence |
|---|---|---|---|
| 1 | `cline-plan` always constructs `-p -m flashnext-plan -P openai-compatible`; observed from real argv, not read from the script | ✓ VERIFIED | Re-ran `bash phase-11/wrapper_argv_test.sh` myself: `Real-wrapper suite: ALL PASS`, 13/13 cases, `MUTANT-LEAKY: CAUGHT`, `MUTANT-SWAP: CAUGHT` |
| 2 | `cline-act` constructs `-m flashnext-act`, never `-p`/`--plan` | ✓ VERIFIED | Same run; P2 row: `-P openai-compatible -m flashnext-act --compaction agentic -t 600` |
| 3 | Unrecognised flags (`--thinking high`, `-m`, `-P`, `--plan`, anything else beginning `-`) are refused, exit non-zero, name the flag, real binary never invoked | ✓ VERIFIED | Same run's R-series cases; also `verify_config.sh`'s own live output: `cline-plan --thinking high 'wrapper-check' correctly refused (exit=2), stub argv file byte-unchanged` |
| 4 | The alias each wrapper targets lives in exactly one file (one-line revert) | ✓ VERIFIED | `phase-11/wrapper.env` is the sole source; `cline-plan`/`cline-act` read `$WRAPPER_PLAN_ALIAS`/`$WRAPPER_ACT_ALIAS` from it, neither file contains a literal alias string (`verify_config.sh`'s `OK[WRAPPER]: neither ... contains a literal alias string`) |
| 5 | The argv test was proven able to fail (leaky mutant) | ✓ VERIFIED | Same run: both seeded leak mutants CAUGHT |
| 6 | No live model request issued by plans 11-01 through 11-04 | ✓ VERIFIED (structural) | All four plans' scripts route through `phase-11/testing/stub-cline`; confirmed by re-reading each script's `CLINE_WRAPPER_TEST`/stub wiring |
| 7 | Fixed 8-task set, mechanically-derived answer keys, no cline-bench | ✓ VERIFIED | `phase-11/AB-TASKSET.md` (cline-bench set-aside, quoting Phase 07's 0/4-passed, 3× `fail-context` result), `phase-11/tasks/MANIFEST.tsv` (8 rows, derivation column per task) |
| 8 | 4-state grader (correct/incorrect/no-answer/no-output), proven against seeded fixtures including reasoning-only-answer | ✓ VERIFIED | Re-ran `bash phase-11/selftest_grade_ab.sh` myself: 9/9 fixtures PASS, including `f5-reasoning-only` → `no-answer` with `answer-seen-in-reasoning-only` qualifier |
| 9 | `verify_config.sh` catches a mode/alias mismatch and a `--thinking high` leak, by seeded real mutants, not by assertion | ✓ VERIFIED | Re-ran `bash phase-11/selftest_verify_wrappers.sh` myself: M1–M7 all `CAUGHT` (exit 3), M8 (legitimate-revert positive control) and M9 (clean control) both `PASS` (exit 0) |
| 10 | `verify_config.sh` still exits 0 unmutated, providers.json assertions unchanged, callers unaffected | ✓ VERIFIED | Re-ran `bash phase-01/config/verify_config.sh` myself: exit 0, `model=flashnext`, `contextWindow=29000`, unchanged trigger line, `OK[WRAPPER]` block appended after the pre-existing assertions |
| 11 | Wrapper failure distinguishable from providers.json failure by exit code/prefix | ✓ VERIFIED | `FAIL[WRAPPER]` prefix + exit 3 vs. the pre-existing providers.json exit 1; confirmed in `verify_config.sh` source and in the selftest's captured messages |
| 12 | No self-recursion when `verify_config.sh` exercises the wrappers, demonstrated with a depth counter | ✓ VERIFIED | `phase-11/results/20260902T043511Z-wrapcheck/recursion-depth-counter.txt` (exactly 1 line for 1 invocation) + `recursion-depth-METHOD.txt` (mechanism: `CLINE_WRAPPER_TEST=1` never re-enters `verify_config.sh`, honestly distinguished from the `VERIFY_CONFIG_NO_WRAPPER_CHECK` brake which is not what actually stops it) |
| 13 | Phase 11 safety envelope judges `providers.json` on `model`/`contextWindow`, not sha256 | ✓ VERIFIED | `phase-11/probe_lib11.sh` delegates to `verify_config.sh`; `selftest_probe_lib11.sh` mutants distinguish a real `model` change from an `updatedAt`-only change |
| 14 | `--thinking high` failure modes and `max_tokens` re-measured live at 3.0.60/61 | ✓ VERIFIED | `phase-11/OPEN-ITEMS.md` + `phase-11/results/20260902T045814Z-openitems/` (`oi1.tsv`, `oi2.tsv`), cited with concrete HTTP codes (400 via `openai/`, 500 via `hosted_vllm/`) |
| 15 | A/B protocol + pre-registered decision rule + falsifier written before data exists | ✓ VERIFIED | `phase-11/AB-PROTOCOL.md` committed `d0521e2`, before the pilot (`e1f083c`) and main run (`dbdad9e`) — checked commit order, not just file content |
| 16 | Pilot run, sizing rule, human budget approval | ✓ VERIFIED | `phase-11/results/20260902T054619Z-ab-pilot/`; `AB-PROTOCOL.md` §4's Task 3 checkpoint records `approve-as-proposed, invocation ceiling 88` |
| 17 | Main A/B run at authorised size, request count reported next to cap, raw streams on disk, 4-category table, median/p90 latency, decision rule applied mechanically whichever way it points, void-condition check | ✓ VERIFIED | `phase-11/AB-RESULTS.md` §1–§8; independently re-derived from `phase-11/results/20260902T062649Z-ab-main/ab.tsv` myself (see "A/B re-derivation" below) — matches the document exactly |
| 18 | A human ratified keep/revert; the decision is its own labelled line; no-improvement stated as a valid completion | ✓ VERIFIED | `AB-RESULTS.md` §11: `DECISION: keep cline-plan -> flashnext-plan`, human's verbatim reply quoted, classified explicitly as `override-with-reason` not `ratify-rule-output` |
| 19 | If keep, `wrapper.env` unchanged and that is recorded as a deliberate no-op; wrappers re-verified after | ✓ VERIFIED | `phase-11/wrapper.env` line 5–9 comment; `AB-RESULTS.md` §11 Part C re-runs `verify_config.sh`/`wrapper_argv_test.sh`/`verify_wrappers.sh`, all exit 0 — I independently re-ran all three again in this pass with the same result |
| 20 | Findings document maps every USE requirement and ROADMAP criterion with a disclosures section | ✓ VERIFIED | `phase-11/PHASE-11-FINDINGS.md` §2/§3/§5 |

**Score: 20/20 aggregated truths verified** (paraphrased from the 7 PLAN.md `must_haves.truths` lists; full verbatim text is in each PLAN.md).

---

## Live Re-Execution — what I actually ran, not what the SUMMARYs claimed

| Command | Result |
|---|---|
| `bash phase-11/wrapper_argv_test.sh` | Exit 0. `Real-wrapper suite: ALL PASS`, `MUTANT-LEAKY: CAUGHT`, `MUTANT-SWAP: CAUGHT` (13 real cases + 2 leak mutants, all against the stub binary — no model cost) |
| `bash phase-11/selftest_verify_wrappers.sh` | Exit 0. M1–M7 `CAUGHT`, M8 (alias-reverted positive control) `PASS`, M9 (clean control) `PASS`. Overall verdict: PASS |
| `bash phase-11/selftest_grade_ab.sh` | Exit 0. 9/9 fixtures matched required verdict, including the reasoning-only-answer distinction (f5) |
| `bash phase-01/config/verify_config.sh` | Exit 0. `model=flashnext`, `contextWindow=29000`, no codex alias, no `models[]` override, both wrapper aliases distinct and known-good, construction region audited clean (no `$@`/`$*` passthrough, no bare `cline`) |

None of these four commands issued a live model request (confirmed structurally: all four operate on the stub binary or static file content only).

---

## A/B re-derivation, from `phase-11/results/20260902T062649Z-ab-main/ab.tsv` directly, not from `AB-RESULTS.md`'s tables

Computed independently with a fresh script over the raw TSV:

```
task arm n_reps n_correct
01   A   5      5
01   C   5      5
02   A   5      5
02   C   5      5
03   A   5      5
03   C   5      5
04   A   5      5
04   C   5      5
05   A   5      5
05   C   5      5
06   A   5      0
06   C   5      0
07   A   5      5
07   C   1      1
```

Tasks 01–06 (equal N=5 both arms): arm A = 25/30, arm C = 25/30 — **identical**, exactly as claimed.
Task 07 (unequal N: A=5, C=1, both 100% correct on what ran): the only source of the raw imbalance.
Totals: A = 30/35, C = 26/31, gap = −4. This −4 is arithmetically produced entirely by A having 4
more (all-correct) task-07 reps than C, not by any accuracy difference — **confirmed**, matching
`AB-RESULTS.md` §11 ground 1's own claim verbatim ("arm A 25/30 correct, arm C 25/30 correct" on the
equal-N slice, headline gap "entirely produced by task 07's unequal replication").

`AB-RESULTS.md` and `PHASE-11-FINDINGS.md` were checked specifically for language that could leave a
reader believing the A/B favoured `flashnext-plan`. It does not: §8 states the rule output is
`revert` (arm C's raw count is *lower*); §11 states explicitly "A reader must not come away from
this document thinking the A/B favoured `flashnext-plan` on answer quality — it did not measurably
favour either arm. `keep` is justified here by the side effect becoming avoidable, not by any
evidence that thinking helps." `PHASE-11-FINDINGS.md`'s handoff section repeats the same instruction
to Phase 12 verbatim ("do not summarize this as 'the A/B found thinking helps'; it did not"). No
overselling found in either direction.

---

## Containment (commit `017c65e`) — verified structurally, then live (2 model requests spent)

**Structural checks (no model cost):**
- Read `phase-11/wrapper_common.sh` in full. The containment block (lines 148–187: `mktemp`, `cp`,
  `trap ... EXIT INT TERM`, `export CLINE_PROVIDER_SETTINGS_PATH=...`, `exit 3` on failure to copy or
  read) sits **before** the comment `# --- construction site: the ONLY place the binary is named ---`
  (line 189) and the first `set --` (line 190).
- Confirmed the failure paths refuse (`exit 3`, printing `REFUSED: ...`) rather than falling through
  to invoke the real binary uncontained, in both the "cannot read real file" and "cannot create/copy
  scratch file" branches.
- Confirmed `verify_config.sh`'s construction-region audit (`phase-01/config/verify_config.sh`, live
  output reproduced above) extracts and prints exactly lines 190–201 — the containment block is
  outside the audited region, matching the commit message's claim about the M9 self-inflicted-and-
  fixed placement bug.
- Confirmed the postflight guard call inside `wrapper_common.sh` (which still runs with
  `CLINE_PROVIDER_SETTINGS_PATH` exported to the scratch copy) cannot be fooled into validating the
  scratch file instead of the real one: `verify_config.sh` keys off a *different* variable,
  `PROVIDERS_JSON` (defaulting to the real path), which `wrapper_common.sh` never sets — so the
  postflight check still inspects the real file, not the redirected one.
- Line-number citation self-correction (`26595e8`, "424-430 at 3.0.61, not 347-353") checked against
  the commit diff: legitimate, disclosed, non-functional correction, not a cover-up.

**Live checks — 2 model requests spent, as anticipated by this task's instructions, to close a gap
this pass found (see "Finding" below):**
- `phase-11/cline-act -t 60 "2+2? respond with just the number."` → exit 0, answered correctly.
  `sha256(~/.cline/data/settings/providers.json)` before and after: both
  `588bd7cc5e15977a2fc23585f07c11a0ce70210fc17b685636e5393be26652fd` — **byte-identical**.
- `phase-11/cline-plan -t 60 "3+4? respond with just the number."` → exit 0, answered correctly
  (`7`, visible thinking trace streamed). Same sha256 before/after this call too — **byte-identical**,
  and identical to the sha cited in `qanda/004` and the `017c65e` commit message.
- No leftover scratch file found under `/tmp` after either call (trap cleanup confirmed).
- `bash phase-01/config/verify_config.sh` re-run immediately after: exit 0, `model=flashnext`,
  `contextWindow=29000` — unaffected by either live call.

**The containment works as claimed, verified live through the actual wrapper scripts, not just
through a bare `cline` invocation.**

---

## Finding (not on the pre-disclosed list — new)

**`qanda/004-does-cline-always-write-providers-json.md` §5 contains a stale, now-false disclaimer.**
That document is written and committed (`ceba670`, 16:27) *before* the containment was implemented
in `wrapper_common.sh` (`017c65e`, 16:31). Its §5 says, in the present tense: "🔴 아직 제안이지
구현이 아닙니다. 맨손 `cline` 으로만 확인했고, 래퍼에 넣어 13케이스 argv 테스트와 뮤턴트 검증을
통과시키는 일은 안 했습니다." ("Still a proposal, not an implementation. Only confirmed with bare
`cline`; putting it in the wrapper and passing the 13-case argv test and mutant verification was not
done.") The file was touched once more after the implementation landed (`26595e8`, 16:45) — but only
to fix an unrelated line-number citation, not to update this sentence. As of this verification pass,
the sentence is simply wrong: the containment *is* in the wrapper, *did* pass the 13-case argv test
and the 9-mutant `selftest_verify_wrappers.sh` ladder (both re-confirmed live in this pass), and (now,
also) has been confirmed to work through a genuine live call to both wrapper scripts, not just a bare
`cline` invocation.

This is not a functional defect — the actual containment works, independently re-verified above by
spending 2 live model requests specifically to close this gap. It is a documentation-consistency
defect: three other documents (`wrapper_common.sh`'s own header comment, `PHASE-11-FINDINGS.md`, and
`AB-RESULTS.md` §11) all cite `qanda/004` as the source of truth for this mechanism, and the cited
file itself still asserts the opposite of what actually shipped. Filed as a human-verification item
in this report's frontmatter (a one-line doc edit, not a re-run) rather than as a blocking gap, since
none of the 7 plans' `must_haves` reference `qanda/004`, and every must_have that *is* in scope was
independently verified true above.

---

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| USE-01 | ✓ SATISFIED | Live argv capture, both wrappers, this pass and the phase's own record agree |
| USE-02 | ✓ SATISFIED | Live 9-mutant ladder re-run this pass, M1–M7 CAUGHT, M8/M9 PASS |
| USE-03 | ✓ SATISFIED | `AB-RESULTS.md` §11 `DECISION: keep`, correctly labelled `override-with-reason` against a `RULE OUTPUT: revert`, no-improvement explicitly stated as a valid completion, independently re-derived from raw `ab.tsv` in this pass |

## ROADMAP Phase 11 Success Criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | `cline-plan`/`cline-act` argv always paired correctly, confirmed by code | ✓ MET | Live argv test, both this pass and the phase's own |
| 2 | Negative tests for mode/alias mismatch and `--thinking high` both caught | ✓ MET | `selftest_verify_wrappers.sh`, re-run live this pass |
| 3 | Same task set run on `flashnext`/`flashnext-plan`, tabulated, keep/revert judgement recorded regardless of direction | ✓ MET | `AB-RESULTS.md` + `PHASE-11-FINDINGS.md`, headline numbers independently re-derived and confirmed accurate in this pass; no reader is left believing the A/B favoured `flashnext-plan` |

## Known Disclosed Items (not re-reported as gaps, per task instructions)

Confirmed present and accurately described in `phase-11/PHASE-11-FINDINGS.md` and
`.planning/STATE.md`: the 66/88 cap-limited A/B stop (task 08 and arm B never measured); the
pre-registered rule outputting `revert`, overridden to `keep` on a stated non-accuracy ground; the
`assert_budget` cap-abort path skipping postflight; cline's 3.0.61 drift and mid-run self-removal
during 11-04; Phase 9's `session-runtime.ts`-vs-`main.ts:1122` scoping error; the unexplained
VRF-04-vs-31/31 contradiction; the containment being one day old with no production track record.

## Anti-Patterns Found

None of severity blocker. No stub patterns, empty handlers, or placeholder content found in any of
the 7 plans' artifacts. `wrapper_common.sh` lacks the executable bit (`-rw-r--r--`) but this is not a
defect: both `cline-plan` and `cline-act` `source` it (`. "$HERE/wrapper_common.sh"`) rather than
executing it, so the bit is irrelevant to function — confirmed by both wrappers running correctly in
this pass's live test.

## Gaps Summary

No gaps found against any of the 7 plans' `must_haves` (truths, artifacts with their `contains`
strings, key_links with their `pattern`s) — every one was checked directly against the live system
in this pass, most by re-running the actual scripts rather than reading their recorded output. The
one new finding (qanda/004's stale disclaimer) is a documentation-only inconsistency, independently
resolved by this pass's own live re-verification of the mechanism it describes, and is recorded as a
human-verification item (a doc edit) rather than a blocking gap.

---

_Verified: 2026-09-10T07:54:00Z_
_Verifier: Claude (gsd-verifier)_
