# Phase 7 criteria mapping, round 2 (post-gap-closure) (BCH-01~03)

Generated: 2026-08-30T17:43:25Z (this phase-close-2 sweep)

This document supersedes `phase-07/results/20260830T103307Z-phase-close/criteria.md` for all
three criteria below. That earlier document is not deleted — it remains the accurate record of
the pre-gap-closure era (1 task attempted, 0 reached the model) — but it no longer describes the
current state of this phase. Read this one for the current verdicts.

## The three numbers

Across both run directories (`bench/runs/20260830T093657Z-phase07/` pre-fix,
`bench/runs/20260830T122809Z-phase07-fix/` post-fix):

- **N (unique tasks attempted): 4** — `discord-trivia-approval-keyerror` (attempted twice, once
  per era — the same task, not two different tasks), `telegram-plugin-refactor`, `filmarchiver`,
  `v-edit-workspace-tests`. Run instances: 5.
- **M (reached the model — non-empty flashnext server-log slice AND `model_turns > 0`): 3** —
  `discord-trivia-approval-keyerror` (post-fix rerun only), `telegram-plugin-refactor`,
  `v-edit-workspace-tests`. `discord-trivia-approval-keyerror`'s pre-fix attempt and
  `filmarchiver` did not reach the model.
- **P (passed): 0.**

## ROADMAP Phase 7 success criteria

### Criterion 1

> `harbor run --env docker` 로 cline-bench 공식 과제 5~8개가 로컬 Docker 에서 실행된 결과
> 디렉터리가 존재한다

**Status: `not_met`**

- Tasks actually attempted (unique): **4** across both run directories. Required: 5-8.
- Evidence: `bench/runs/20260830T093657Z-phase07/` (1 unique task, pre-fix era) +
  `bench/runs/20260830T122809Z-phase07-fix/` (4 unique tasks total in this directory's own
  `summary.md` table — 3 new plus the post-fix rerun of the one pre-fix task).
- **Reached-the-model sub-line (new this round, the number the whole gap-closure set exists to
  establish): 3 of the 4 unique tasks reached this stack's model server** (non-empty flashnext
  server-log slice AND `model_turns > 0` — the same signal `verify_bench.sh` check B11 and
  `make_summary.sh`'s header both compute independently). This is a materially different fact
  from "the tasks ran": the injection mechanism that failed silently in the pre-fix era (07-03)
  is now proven working (07-06 diagnosis, 07-07 fix, 07-09 reproduction on two more tasks).
- Reason for the count shortfall, quoted from the round-2 decision record
  (`phase-07/results/20260830T141218Z-cost-checkpoint/decision2.md`):

  > The user's literal reply to the 07-08 Task 2 checkpoint was "Continue" -- not one of the five
  > named option ids. The orchestrator interpreted this as `plus-three`... **This is recorded
  > here as an interpretation of an ambiguous reply, not as a verbatim user selection**, and is
  > held to a visibly lower evidentiary bar than the 07-03 decision record (`stop-at-one`), which
  > quoted the user's own words directly.

  Three tasks were run under that interpretation (07-09), bringing the unique-task count from 1
  to 4 — not to 5, because `discord-trivia-approval-keyerror` was attempted a second time (not a
  new task). This corrects the original 07-08 plan's own "plus-three ⇒ reaching 5 total" framing,
  which conflated run-instance count with unique-task count — a correction 07-08 made itself and
  this document carries forward without repeating the error.
- **Not promoted.** 4 unique tasks is not described anywhere in this document, in
  `docs/cline-bench.md`, or in `.planning/ROADMAP.md` as satisfying a 5-8 task range.

### Criterion 2

> 각 실행 디렉터리에 프롬프트 원문과 결과가 모두 파일로 저장돼 있다

**Status: `met`** (for every task attempted, across both run directories)

- Evidence: `verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07` → `CASES 10/10` (B11
  correctly `SKIP`, not counted); `verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix`
  → `CASES 11/11` (B11 `PASS`) — both re-swept fresh this round
  (`phase-07/results/20260830T170042Z-gap-batch/post/verify_bench-prefix.txt`,
  `.../verify_bench-postfix.txt`).
- B3/B4 (BCH-02's prompt half and result half) `PASS` in both run directories. `filmarchiver`'s
  `verifier/reward.txt` never exists (the trial crashed in `environment_setup`, before the
  verifier stage) — this is excused via an explained gap in `CAPTURE-GAPS.txt`, per B4's own
  escape valve, not treated as a missing artifact.
- **`agent/cline.txt` (the raw transcript) alone was never accepted as satisfying this criterion**
  in either run directory — `verify_bench.sh`'s B3 check never consults it as a substitute, valve
  or no valve, in either era.
- This status covers every task actually attempted (4 unique, 5 instances) across both
  directories. No claim is made about the 8 tasks that were never run (recorded as `not-run` rows
  in `bench/runs/20260830T122809Z-phase07-fix/summary.md`).

### Criterion 3

> 통과/실패와 소요 시간을 정리한 표가 파일로 존재한다

**Status: `met`**

- Evidence: `bench/runs/20260830T093657Z-phase07/summary.md` (1 attempted row, `fail-infra`,
  `wall_clock_s=232`) and `bench/runs/20260830T122809Z-phase07-fix/summary.md` (4 attempted rows
  — `discord-trivia-approval-keyerror` `fail-context`/1665s/38 turns, `filmarchiver`
  `fail-infra`/437s/0 turns, `telegram-plugin-refactor` `fail-context`/371s/6 turns,
  `v-edit-workspace-tests` `fail-context`/585s/12 turns — plus 8 `not-run` rows, 12 rows total,
  matching the measured live task pool of 12).
- `fail-context` rows (3, all post-fix) are present with their own cause per the table's own
  convention, distinguished explicitly from `fail-infra` (1) in the table's own 한계 note.
- B5/B6 re-verified fresh this round on both run directories: `CHECK: PASS` in both.

## BCH requirement mapping

| Requirement | Status | Evidence |
| --- | --- | --- |
| BCH-01 (5-8 tasks via `harbor run --env docker`) | `not_met` | 4 unique tasks across both run directories (5 instances); 3 reached the model. See Criterion 1 above for the quoted decision record. |
| BCH-02 (prompt + result on disk, per task) | `met` (for all 4 unique tasks / 5 instances attempted) | `bench/runs/20260830T093657Z-phase07/prompts/INDEX.md`, `bench/runs/20260830T122809Z-phase07-fix/prompts/*/`; `verify_bench.sh` B3/B4 PASS on both run directories |
| BCH-03 (pass/fail + duration table) | `met` | `bench/runs/20260830T093657Z-phase07/summary.md`, `bench/runs/20260830T122809Z-phase07-fix/summary.md`; `verify_bench.sh` B5/B6 PASS on both |

## Note on what a `fail-*` row does and does not mean (updated for this round's verdict classes)

Two verdict classes appear across the 5 attempted instances: `fail-infra` (2 instances — the
pre-fix `discord-trivia-approval-keyerror`, which never reached the model at all because of the
schema-rejection bug; and `filmarchiver`, which never reached the model because of an unrelated
Bun/AVX segfault during container environment setup) and `fail-context` (3 instances — the
post-fix `discord-trivia-approval-keyerror` rerun, `telegram-plugin-refactor`, and
`v-edit-workspace-tests`, all of which DID reach the model and were rejected at the 32K
`MAX_KV_SIZE` ceiling after multiple successful turns).

- A `fail-infra` row means the agent never reached the model at all — it is evidence of an
  infrastructure or configuration defect (the schema bug, or the AVX segfault), not evidence
  about whether this stack can complete a cline-bench task.
- A `fail-context` row means the agent DID reach the model, repeatedly, and was rejected only
  once it exceeded this stack's 32K context budget — it is evidence the injection mechanism and
  the flashnext/litellm chain work end-to-end. It is NOT evidence that this stack can complete a
  cline-bench task; three-for-three of the tasks that reached the model hit this same ceiling.
- Neither BCH-02 nor BCH-03 requires a `pass` verdict to be satisfied — both ask only that the
  prompt/result artifacts and the summary table exist on disk, which they do for all 4 unique
  tasks (5 instances) attempted.
- No verdict row of any class, in either run directory, is evidence that any cline-bench task can
  pass on this stack. That remains unproven.

## Known open item: host `cline` version drift (not repaired here)

- **What it is:** the host's (darwin) `cline` binary at `/opt/homebrew/lib/node_modules/cline` is
  version `3.0.60`, not the pinned expectation `3.0.53`. Confirmed live this round:
  `package.json`'s `"version": "3.0.60"`, mtime `Aug 30 13:27:09 2026` (predates this phase's
  later plans — the drift is not something 07-06 through 07-10 introduced).
- **Phase 7 did not cause it.** It was discovered as a side effect of 07-06's H1 diagnosis (07-02's
  original `INJECTABLE` verdict had unknowingly analyzed this same drifted binary), not created by
  any plan in this phase.
- **The container's own pinned 3.0.53 install is unaffected** — `HARBOR_CLINE_VERSION=3.0.53`
  (`phase-07/bench/config.env`) is a separate, per-container npm install inside harbor's ephemeral
  Docker image, confirmed live each run via `agent/setup/install-agent-runtime.log`.
- **Repairing it (`npm install -g cline@3.0.53`) is a separate, explicit decision** requiring
  confirmation that no `cline`/kanban process is running first (kanban invokes the host `cline`
  binary). **This plan does not repair it** — house rule for this plan bans `npm install -g`
  entirely, and the fix belongs to whoever next touches host `cline` posture (Phase 8 or later),
  not to a documentation-correction plan.
