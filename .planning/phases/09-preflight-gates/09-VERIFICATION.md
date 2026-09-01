---
phase: 09-preflight-gates
verified: 2026-09-01T04:00:43Z
status: passed
score: 32/32 must-haves verified
---

# Phase 9: 사전 확인 게이트 (스택 무변경) Verification Report

**Phase Goal:** `reasoning_effort`/`enable_thinking` 이 모델 계층(`:8011` 직결)에서 실제로 무엇을 하는지,
그리고 사고 트레이스가 다음 턴 컨텍스트로 누적되는지에 대해 **스택을 하나도 바꾸지 않은 채** 근거 있는
답을 낸다.
**Verified:** 2026-09-01T04:00:43Z
**Status:** passed
**Re-verification:** No — initial verification

## Method

This is a goal-backward verification against raw artifacts, not SUMMARY.md claims. For every
`must_haves` block (truths / artifacts / key_links) in the frontmatter of 09-01..09-04-PLAN.md, the
claim was checked against: (a) the actual script/doc source code, (b) the raw JSON response bodies
in `phase-09/results/*/`, (c) TSV rows re-derived independently (not re-read from prose), and (d)
live commands re-run against the currently-running stack (`launchctl list`, `verify_config.sh`,
`git describe --tags` in `cline-src`).

## Goal Achievement — Observable Truths (32/32)

### 09-01 (safety envelope + PRB-01/PRB-02) — 6/6

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Reusable safety envelope snapshots PIDs + config hashes before a burst and re-asserts unchanged after | VERIFIED | `phase-09/probe_lib.sh` `preflight()`/`postflight()`; deliberate `selftest-neg`/`selftest-neg2` runs prove the negative-detection path actually fires (`pids-before.txt` seeded with a fake `99999` PID, `hashes-before.txt` seeded with a corrupted hash byte, both correctly produce `FAIL:` lines) |
| 2 | A negative probe result cannot become a gate answer without passing the gpu-stream flake discriminator | VERIFIED | `probe_lib.sh`'s four-state `record_verdict()` — `unexpected`+`DIRTY`→`DISCARDED-FLAKE`; a `CONFIRMED-NEGATIVE` requires two independent CLEAN-window unexpected observations of the *same* label |
| 3 | PRB-01 has a fresh raw response body showing medium vs unspecified reasoning field, with negative control | VERIFIED | `raw-prb01-medium-{1,2}.json` parsed independently: `reasoning`/`reasoning_content` = 179 chars both; `raw-prb01-unspecified-{1,2}.json`: 0 chars both. Matches `prb01.tsv` exactly |
| 4 | PRB-02 has fresh HTTP statuses for `enable_thinking:false` at both `:8011` and `:4000` (unmodified `flashnext` alias) | VERIFIED | `prb02.tsv` rows `8011-false`/`4000-false`, both HTTP 200; raw bodies parse and confirm empty reasoning fields, consistent with "not rejected" |
| 5 | Record distinguishes "not rejected" from "applied" via an `enable_thinking:true` positive control | VERIFIED | `raw-prb02-4000-true.json`: `reasoning_content` = 30 chars (non-empty) vs the `false`/default rows' 0 chars — genuine positive control, independently reparsed from raw JSON |
| 6 | Three service PIDs identical before/after burst; no config file written | VERIFIED | `pids-before.txt`==`pids-after.txt`, `hashes-before.txt`==`hashes-after.txt` in `20260901T014027Z-prb01-02/`; `postflight.txt` reports OK for both; independently re-diffed, not just read |

### 09-02 (PRB-03 oracle + multi-turn growth) — 9/9

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | `prompt_tokens` for unspecified/medium/low/xhigh + shipped combination freshly measured from server log, not copied | VERIFIED | `prb03.tsv`: 13/11/41/53/53/11 for arms `unspecified/medium/low/xhigh/et-true/et-medium`, sourced from literal `Prefill started` log lines quoted verbatim in the same row |
| 2 | Each value attributed via log watermark, not `tail -N` | VERIFIED | `probe_prb03_oracle.sh` `run_prb03_request()`: records `wc -l` mark before firing, requires exactly 1 new `Prefill started` line in the window, retries/discards on 0 or ≥2 matches |
| 3 | Effort sweep repeated so run-to-run variance is measured | VERIFIED | Sweep A and B both run; `sweep-ab-compare.txt` shows `agree` on all 6 arms, `sweep-ab-mismatch.txt` = `0` — reproduced by independently recomputing agreement myself from `prb03.tsv` |
| 4 | Two ≥3-turn sequences (thinking on/off), per-turn `prompt_tokens` growth recorded side by side | VERIFIED | `multiturn.tsv`: ON 69/127/150 (+58/+23), OFF 29/360/681 (+331/+321), each row backed by its own `Prefill started` log line |
| 5 | Thinking-on sequence feeds back reply AND reasoning field, matching Cline's `shouldIncludeReasoningHistory` behavior | VERIFIED | `probe_multiturn_growth.py` line ~255: `assistant_msg["reasoning_content"] = reasoning` appended before `messages.append(assistant_msg)` on the ON path |
| 6 | Real reasoning traces saved to disk with char lengths, for reuse by 09-03 | VERIFIED | `realtrace-t{1,2,3}.txt` exist; `len(open(f).read())` independently recomputed = 591/917/989, matching `realtrace-capture.tsv` and `multiturn.tsv`'s `reasoning_chars` column exactly |
| 7 | Three-way comparison: VALIDATED.md / 09-RESEARCH.md / fresh, each with delta-from-unspecified | VERIFIED | `PRB-03-ORACLE.md` §2 table: 23/21/51/63 vs 13/11/41/53 vs 13/11/41/53, deltas −2/+28/+40 all three columns agree |
| 8 | Document states which effort values are usable as the Phase 10 oracle, with token margin | VERIFIED | `PRB-03-ORACLE.md` §4: `low`(+28)/`xhigh`(+40) usable, `medium`/`et-medium`(−2) not, with explicit margin justification |
| 9 | Absolute-baseline shift recorded as known unexplained observation, not silently dropped | VERIFIED | `PRB-03-ORACLE.md` §5, explicit −10 offset note |

### 09-03 (PRB-04 replay: synthetic + real trace + source re-verification) — 8/8

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Replay probe re-run at both `:8011` and `:4000` (unmodified alias), fresh with/without pairs | VERIFIED | `prb04-synthetic.tsv` 12 rows (2 endpoints × 3 fields × 2 rounds); raw JSON `usage.prompt_tokens` independently re-extracted = 46 for every sampled file, matching TSV |
| 2 | Both field names (`reasoning_content` AND `reasoning`) exercised | VERIFIED | `prb04-synthetic.tsv` field column literally contains both strings; `build_messages()` sets `msgs[1][field]` for each |
| 3 | Zero-cost finding re-tested with real xhigh traces (not only synthetic) | VERIFIED | `prb04-realtrace.tsv`: LONGEST (989 chars, `realtrace-t3.txt`) and CONCAT (2,497 chars, t1+t2+t3) both endpoints, all `prompt_tokens=46`, delta=0 |
| 4 | Character length of every trace recorded | VERIFIED | `trace_chars`/`char_length` columns present in both TSVs: 0, 1380, 989, 2497 |
| 5 | `shouldIncludeReasoningHistory`/`agentPartToContentBlock` independently re-verified in cline-src at the observed tag, with observed line numbers | VERIFIED | `source-verification.txt` cross-checked directly: `git -C cline-src describe --tags` = `cli-v3.0.53` (re-run myself, matches), `sed -n '284,289p' ai-sdk.ts` and `sed -n '1213,1214p' message-builder.ts` re-read directly from disk, byte-for-byte matches the file's own quoted excerpt |
| 6 | Doc correction to `docs/plan-act-reasoning-implementation.md` written down as a false negative, with edit targets | VERIFIED | `PRB-04-FINDINGS.md` §4 names exact lines (96–100, 102) in `plan-act-reasoning-implementation.md` and 187–191 in `-diagrams.md`; confirmed those lines still exist unedited (correctly, per Phase 12 ownership) |
| 7 | Correction explicitly routed to Phase 12 as owner of doc edits, Phase 9 owns only the record | VERIFIED | `PRB-04-FINDINGS.md` §4 heading: "Handoff — Phase 12 owns the doc edits"; "Phase 9 does not edit these docs (Phase 12 owns USE-05)" |
| 8 | Deferral of real-Cline-on-the-wire confirmation recorded as explicit inherited item naming Phase 10's VRF-04 | VERIFIED | `PRB-04-FINDINGS.md` §5, `GATE-VERDICT.md` §6 item 2, both name `VRF-04` explicitly |

### 09-04 (fresh-vs-research comparison, gate adjudication, verdict) — 9/9

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Every fresh measurement placed beside 09-RESEARCH.md value in one table with agree/disagree call | VERIFIED | `GATE-VERDICT.md` §2, 11-row table, `agree?` column populated (`yes`/`n/a`, zero `no`) |
| 2 | Disagreement written up as investigated finding, never silently resolved | VERIFIED | §3.1 (citation correction) and §3.2 (CFG-11 design-rationale refutation) both written up in the open, favoring neither source blindly |
| 3 | Gate adjudication for PRB-01/PRB-04 cites this phase's reproduced values, says so in words | VERIFIED | §4.1/§4.2 "Basis cited" lines explicitly name `phase-09/results/...` paths and state "not 09-RESEARCH.md's" |
| 4 | PRB-04 adjudication weighs both controlled replay (09-03) and multi-turn growth (09-02), states which governs | VERIFIED | §4.2 "Which evidence governs, stated before it is applied" — controlled replay decisive, multi-turn corroborating, with an explicit reconciliation |
| 5 | A single flaky/INDETERMINATE sample cannot produce a gate verdict; document states what happens | VERIFIED | §4.3 states the rule and confirms 0/37 verdicts were non-CONFIRMED; independently recomputed 37 = 7+18+12 by `wc -l` on the three `verdicts.tsv` files |
| 6 | Document ends with exactly one verdict heading, one of the three named options | VERIFIED | `grep -n "^## Phase 10 진행\|^## 마일스톤 종료\|^## 판정 보류"` → exactly one match, `## Phase 10 진행` at line 290 |
| 7 | Verdict states which measured facts would have produced the opposite verdict | VERIFIED | §5 "What would have produced the opposite verdict" — 5 bulleted falsifying conditions, none of which occurred |
| 8 | All of the research's open items accounted for as closed-by-this-phase or explicitly deferred with an owner | VERIFIED | §6 register: all 5 of 09-RESEARCH.md's "Could Not Verify / Open Risks" items accounted for (1 closed inside Phase 9 itself, explained separately; the other 4 in the 6-item register alongside 2 new facts). The plan's must-have text says "four" — GATE-VERDICT.md explicitly reconciles this by naming and explaining all five, which satisfies the underlying intent (nothing dropped) even though the plan's own count was off by one |
| 9 | A human has reviewed and confirmed the verdict before Phase 10 is unlocked | VERIFIED | §7: "Confirmed by: ohama100@gmail.com", "Response: approved", with the specific things shown to the reviewer itemized |

**Score:** 32/32 truths verified

## Required Artifacts

| Artifact | Expected `contains` | Status | Details |
|---|---|---|---|
| `phase-09/probe_lib.sh` | `no Stream(gpu` | VERIFIED | Present in `flake_window()` (grep pattern + evidence-file header) |
| `phase-09/probe_prb01.sh` | `reasoning_effort` | VERIFIED | Used to build request bodies for medium/low/xhigh arms |
| `phase-09/probe_prb02.sh` | `enable_thinking` | VERIFIED | Used to build both `:8011`/`:4000` request bodies |
| `phase-09/results/CURRENT_PRB01_02_RUN` | pointer file | VERIFIED | Exists, points to `20260901T014027Z-prb01-02` (real dir) |
| `phase-09/probe_prb03_oracle.sh` | `enable_thinking` | VERIFIED | Present in `et-true`/`et-medium` body builders |
| `phase-09/probe_multiturn_growth.py` | `xhigh` | VERIFIED | 7 occurrences |
| `phase-09/PRB-03-ORACLE.md` | `VALIDATED.md` | VERIFIED | §2/§5 |
| `phase-09/results/CURRENT_PRB03_RUN` | pointer file | VERIFIED | Exists, points to real dir |
| `phase-09/probe_prb04_replay.py` | `reasoning_content` | VERIFIED | 5 occurrences |
| `phase-09/probe_prb04_realtrace.py` | `realtrace` | VERIFIED | 9 occurrences |
| `phase-09/verify_reasoning_history_source.sh` | `shouldIncludeReasoningHistory` | VERIFIED | Present, used as grep target and re-verified independently against actual cline-src file |
| `phase-09/PRB-04-FINDINGS.md` | `shouldIncludeReasoningHistory` | VERIFIED | §3 |
| `phase-09/GATE-VERDICT.md` | `What would have produced the opposite verdict` | VERIFIED | §5 heading, verbatim |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `probe_prb01.sh` | `probe_lib.sh` | `source .../probe_lib.sh` | WIRED | Line 21, literal `source` statement |
| `probe_prb02.sh` | `probe_lib.sh` | `source .../probe_lib.sh` | WIRED | Line 21, literal `source` statement |
| `probe_lib.sh` | `~/llm-system/services/logs/flashnext.err` | log watermark + flake grep | WIRED | `FLASHNEXT_LOG` constant, used in `preflight`/`flake_window` |
| `probe_prb03_oracle.sh` | `probe_lib.sh` | `source .../probe_lib.sh` | WIRED | Line 38 |
| `probe_multiturn_growth.py` | `flashnext.err` | per-turn prompt_tokens by watermark | WIRED | Contains `Prefill started` (x2), reads log directly |
| `PRB-03-ORACLE.md` | `phase-09/results/CURRENT_PRB03_RUN` | cites run dir | WIRED | Run directory path cited repeatedly with raw evidence file names |
| `probe_prb04_replay.py` | `http://localhost:4000/v1/chat/completions` | full-stack call via unmodified alias | WIRED | `URL_4000` constant, used in `ENDPOINTS` list, `auth=True` header added for `:4000` |
| `probe_prb04_realtrace.py` | `phase-09/results/CURRENT_PRB03_RUN` | reads realtrace-t*.txt | WIRED | `CURRENT_PRB03_RUN_PTR` read and dereferenced at line 195 |
| `verify_reasoning_history_source.sh` | `ai-sdk.ts` | grep at checked-out tag | WIRED | `AI_SDK_TS` path built from `$CLINE_SRC`, grepped; independently re-run by verifier against the live file, byte-identical |
| `PRB-04-FINDINGS.md` | `docs/plan-act-reasoning-implementation.md` | names correction paragraph | WIRED | §4, exact line numbers cited |
| `GATE-VERDICT.md` | `phase-09/results/CURRENT_PRB01_02_RUN` (via `phase-09/results/`) | cites PRB-01/02 basis | WIRED | §1/§4.1, dozens of `phase-09/results/...` citations |
| `GATE-VERDICT.md` | `PRB-04-FINDINGS.md` | cites PRB-04 basis | WIRED | §4.2, multiple citations |
| `GATE-VERDICT.md` | `PRB-03-ORACLE.md` | carries oracle choice forward | WIRED | §5 "What Phase 10 inherits" |

## Decisive PRB-04 Claim — Independently Re-derived

Re-derived from the raw JSON `usage.prompt_tokens` field (not the TSV, not the log-line grep) in a
sample of files spanning both TSVs, both endpoints, both field names, and both trace sources: every
sampled body returns exactly `prompt_tokens: 46`. Row counts independently recounted:
`prb04-synthetic.tsv` = 12 data rows (2 repeats × 2 endpoints × 3 fields), `prb04-realtrace.tsv` = 4
data rows (2 trace variants × 2 endpoints) → **16 rows total, all `prompt_tokens=46`**, covering
`:8011`+`:4000`, `reasoning_content`+`reasoning`, and the synthetic 1,380-char trace plus real traces
up to 2,497 chars (`len()` of `realtrace-t3.txt` and the t1+t2+t3 concatenation independently
recomputed as 989 and 2,497 respectively). This matches the phase's decisive claim exactly.

## Stack-Unchanged Constraint

- `pids-before.txt` == `pids-after.txt` in all three real probe run directories (`prb01-02`, `prb03`,
  `prb04`); independently re-diffed by the verifier, not just re-read.
- `hashes-before.txt` == `hashes-after.txt` in the same three directories.
- The two `selftest-neg*` directories show intentionally-seeded mismatches correctly triggering
  `FAIL:` — proving the detection mechanism itself works, not a real drift.
- `bash phase-01/config/verify_config.sh` re-run live by the verifier (not just read from a log):
  exits 0, prints the same `OK: ...` message recorded throughout the phase.
- `launchctl list | grep 'com.ohama.(flashnext|role-shim|litellm)'` re-run live by the verifier:
  PIDs `46573`/`75548`/`48525` — identical to every `pids-before.txt`/`pids-after.txt` snapshot taken
  across the whole phase, and identical to `GATE-VERDICT.md`'s own "re-run now, at verdict time"
  section.
- `cline` invocation check: grepped every `.sh`/`.py` file in `phase-09/` for any execution of the
  `cline` binary. The only matches are a `pgrep -fl 'bin/\.cline|bin/cline'` advisory check in
  `probe_lib.sh` (explicitly labeled "hint only, NOT a hard gate"), never an `exec`/`subprocess` call
  to the binary itself. Confirmed genuinely never invoked.

## Requirements Coverage

| Requirement | Status | Notes |
|---|---|---|
| PRB-01 | SATISFIED | Diagnostic (demoted 2026-09-01 per CFG-11), decided positive on fresh evidence |
| PRB-02 | SATISFIED | Fresh HTTP statuses + not-rejected-vs-applied distinction recorded; feeds CFG-12 |
| PRB-03 | SATISFIED | Oracle re-measured, three-way comparison, oracle declaration for Phase 10 |
| PRB-04 | SATISFIED | 🔴 gate decided positive, all 16 decisive readings CONFIRMED at delta=0 |

## Anti-Patterns Found

None. Grepped all `phase-09/*.sh`/`*.py` for `TODO|FIXME|placeholder|not implemented|coming soon` —
zero hits outside of prose discussing the research's own history. No stub returns, no empty handlers,
no hardcoded fabricated values found in any script or raw-data-derived table.

## Human Verification Required

None outstanding for this phase. The one item requiring human sign-off (the gate verdict itself, per
`09-04-PLAN.md`'s `checkpoint:human-verify` task and the must-have "A human has reviewed and confirmed
the verdict before Phase 10 is unlocked") is already recorded as completed in `GATE-VERDICT.md` §7
(confirmed by ohama100@gmail.com, approved, dated 2026-09-01).

## Known Non-Gaps (per task instructions, not re-flagged)

- `docs/plan-act-reasoning-implementation.md` still contains the false-negative paragraph unedited —
  confirmed still present at lines 90–105; this is intentional (Phase 9 owns only the record in
  `PRB-04-FINDINGS.md`, Phase 12 owns the doc edit).
- Real `cline` on the wire was never run in Phase 9 — confirmed via source grep (no invocation
  anywhere) and via `GATE-VERDICT.md` §6/§7's explicit, human-approved `VRF-04` deferral to Phase 10.

## Gaps Summary

No gaps found. Every `must_haves` truth, artifact (including its `contains` string), and key_link
(including its regex `pattern`) across all four plans was independently re-derived from raw JSON
bodies, TSV rows recomputed from first principles, live re-execution of `verify_config.sh` and
`launchctl list`, and a direct read of the actual `cline-src` files at the pinned tag — not from
SUMMARY.md prose. The phase's own internal self-tests (`selftest-neg`, `selftest-neg2`) demonstrate
the anti-flake/stack-unchanged machinery actually detects the failure modes it claims to guard
against, rather than merely asserting it does. The one numeric imprecision found (the 09-04 plan's
must-have says "four" open research items where the research actually lists five) is fully reconciled
in the open by `GATE-VERDICT.md` itself and does not constitute a hidden gap.

---

*Verified: 2026-09-01T04:00:43Z*
*Verifier: Claude (gsd-verifier)*
