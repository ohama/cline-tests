# Phase 7 criteria mapping (BCH-01~03)

Generated: 2026-08-30T10:33:07Z (this phase-close sweep)

## ROADMAP Phase 7 success criteria

### Criterion 1

> `harbor run --env docker` 로 cline-bench 공식 과제 5~8개가 로컬 Docker 에서 실행된 결과
> 디렉터리가 존재한다

**Status: `not_met`**

- Tasks actually attempted: **1** (`discord-trivia-approval-keyerror`). Required: 5-8.
- Evidence: `bench/runs/20260830T093657Z-phase07/` (one run directory, one meta record,
  `bench/runs/20260830T093657Z-phase07/summary.md` table row 1 of 12).
- Reason for the shortfall, quoted verbatim from the user's checkpoint decision
  (`phase-07/results/20260830T093515Z-smoke/decision.md`):

  > The user selected `stop-at-one`.
  >
  > - Run NO further bench tasks. Zero additional model spend.
  > - `SELECTED_TASKS` stays empty — 07-04 must treat that as its documented "not a
  >   failure of this plan" path.
  > - ROADMAP criterion 1 (5-8 tasks) is NOT met, and must be recorded honestly as such,
  >   with the reason and the user's decision quoted. Do NOT promote it, do not round it
  >   up, do not describe one task as satisfying a 5-8 range.
  > - The user's reasoning, for the record: the invocation shape is identical for every
  >   task, so more runs would very likely reproduce the same structural fail-infra —
  >   buying repeated evidence of one known limitation rather than more passes.

- **Not promoted.** One task is not described anywhere in this document, in
  `docs/cline-bench.md`, or in `.planning/ROADMAP.md` as satisfying a 5-8 task range.

### Criterion 2

> 각 실행 디렉터리에 프롬프트 원문과 결과가 모두 파일로 저장돼 있다

**Status: `met`** (for the one task actually attempted)

- Evidence: `bench/runs/20260830T093657Z-phase07/prompts/INDEX.md` (BCH-02 index for the one
  attempted task) and `verify_bench.sh` checks B3/B4, re-run fresh this sweep:
  `phase-07/results/20260830T103307Z-phase-close/verify_bench_stdout.txt` — `CHECK: PASS B3`,
  `CHECK: PASS B4`, `CASES 10/10`.
- The prompt artifact this criterion is satisfied by is `instruction.md` +
  `agent-command.txt` (1442 bytes + 2066 bytes respectively, per
  `bench/runs/20260830T093657Z-phase07/prompts/INDEX.md`) — **`agent/cline.txt` (the raw
  transcript) alone was never accepted as satisfying this criterion**; `verify_bench.sh`'s
  own B3 check explicitly never consults it as a substitute, valve or no valve.
- The on-wire system prompt was **not** captured (the run failed on its first request,
  before cline could emit or transcribe one — `system-prompt-probe.txt` reads
  `SYSTEM_PROMPT_IN_TRANSCRIPT: no`). This does **not** downgrade the criterion: the
  criterion's own text asks for "프롬프트 원문" (the prompt text sent), which is on disk in
  `instruction.md` + `agent-command.txt` — not the on-wire system prompt Cline itself would
  have constructed, which this stack never enables request-body logging to capture anyway.
- This status covers the one task actually attempted. No claim is made about tasks that
  were not run (11 of 12, all recorded as `not-run` rows in `summary.md`).

### Criterion 3

> 통과/실패와 소요 시간을 정리한 표가 파일로 존재한다

**Status: `met`**

- Evidence: `bench/runs/20260830T093657Z-phase07/summary.md` — one attempted-task row
  (`discord-trivia-approval-keyerror`, verdict `fail-infra`, `wall_clock_s=232`) plus 11
  `not-run` rows (12 rows total, matching the measured live task pool of 12).
- Context-mismatch (`fail-context`) failures, had any occurred, would be included as rows
  with their own cause per the table's own convention — none occurred in this run (the one
  row present is `fail-infra`, not `fail-context`; `summary.md`'s own 한계 section states
  the distinction between the two verdict kinds explicitly).
- The table's row count (12) is verified fresh this sweep: `verify_bench.sh` B5
  ("attempted-rows=1 meta-count=1") and B6 (not-run row completeness), both `CHECK: PASS`.

## BCH requirement mapping

| Requirement | Status | Evidence |
| --- | --- | --- |
| BCH-01 (5-8 tasks via `harbor run --env docker`) | `not_met` | `bench/runs/20260830T093657Z-phase07/` — 1 task attempted, not 5-8; see Criterion 1 above for the quoted user decision |
| BCH-02 (prompt + result on disk, per task) | `met` (for the 1 task attempted) | `bench/runs/20260830T093657Z-phase07/prompts/INDEX.md`; `verify_bench.sh` B3/B4 PASS |
| BCH-03 (pass/fail + duration table) | `met` | `bench/runs/20260830T093657Z-phase07/summary.md`; `verify_bench.sh` B5/B6 PASS |

## Note on `fail-infra`

A `fail-infra` row (this run's only attempted-task row) means the agent never reached the
model at all (`model_turns=0`, zero bytes in the flashnext server-log slice for this task's
window) — it is not evidence that this stack can complete a cline-bench task, and it is not
evidence that the harness itself is broken. Neither BCH-02 nor BCH-03 requires a `pass`
verdict to be satisfied — both ask only that the prompt/result artifacts and the summary
table exist on disk, which they do for the one task attempted.

---
*Phase: 07-cline-bench-verification*
*Generated: 2026-08-30T10:33:07Z*
