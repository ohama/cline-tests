---
phase: 08-korean-user-manual
verified: 2026-08-30T20:18:47Z
status: passed
score: 4/4 success criteria addressed (1/3/4 met, 2 partially_met — honest, deliberate, user-declined limitation, not a phase failure)
---

# Phase 8: 한글 사용 매뉴얼 Verification Report

**Phase Goal:** 실제로 출하된 것을 기준으로 CLI·웹(Kanban)·iPad/iPhone 사용법과 32K 운용
주의사항을 문서화한다.
**Verified:** 2026-08-30T20:18:47Z (session date 2026-08-31)
**Status:** passed
**Milestone status:** This is the final phase (8 of 8). Milestone-level judgment included below.

## Summary Judgment

**Phase 8 is `passed`.** All four ROADMAP success criteria are addressed by real, gated, honest
Korean-language documentation written from live evidence rather than source-reading or
assumption. Criteria 1, 3, 4 are fully met. Criterion 2 (Kanban) is honestly recorded as
**partially met**: cards, registration, diff-review-absence, and dependency chains are
documented from live transcripts and work; per-task `git worktree` remains genuinely
unavailable in this deployment because the user explicitly declined the one measured fix
(metadata-only `$HOME` sandbox widening) after seeing its exact cost. This is not a
task-completion illusion — it is a real, permanent architectural fact of this deployment,
correctly and consistently recorded as partial everywhere (the document itself, `criteria.md`,
`REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`). Per the explicit instruction not to manufacture a
gap the user deliberately declined, this partial status does not block the phase from `passed`.

## Goal Achievement

### Observable Truths (four ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | CLI 문서에 기동·태스크 실행·Plan/Act·체크포인트가 실제 명령어와 함께 기술 | ✓ VERIFIED | `docs/manual/01-cli.md` §1(기동)·§2(`phase-04/run_headless.sh` 실제 커맨드/env 표)·§6(Plan/Act, `[GAP-PLANMODE]` 정직 헤지)·§7(두 체크포인트 개념 분리, `02-kanban.md` 교차참조) |
| 2 | Kanban 문서에 카드·worktree·diff 리뷰·의존 체인 절차 기술 | ⚠️ PARTIALLY VERIFIED | `docs/manual/02-kanban.md` §3(카드, 실측)·§4(diff — CLI 표면 없음을 실측으로 확인, 정직히 기록)·§6(`[GAP-WORKTREE]`, 재현된 원인 + declined 수정)·§7(의존 체인, 실측). 4개 주제 중 3개는 동작, 1개(worktree)는 배포에서 불가능함이 재현으로 확인되고 정직히 기록됨 |
| 3 | iPad/iPhone 문서에 Tailscale 접속과 Telegram 대화/승인·거부 기술 | ✓ VERIFIED | `docs/manual/03-mobile.md` §1(단일 진입점, 3단 체인)·§5(Telegram, `--no-tools`이므로 승인/거부 UI 자체가 존재하지 않음을 정직히 기록) |
| 4 | 32K 운용 주의에 64초 대기·자동 압축과 지연·`contextWindow` 위치·⌘+클릭 불가·Phase1 VER 결론 반영 | ✓ VERIFIED | `docs/manual/04-32k-operations.md` §1·§2·§3(`[GAP-COMPACTION-CONFIG]`)·§6·Phase1 VER(§2, 트리거 26,100/오버슈트 ~3,100). 폐기된 "작업 예산/태스크 쪼개기" 조언은 §4에 정확히 1회, 폐기 선언으로만 등장 — 되풀이되지 않음(전체 매뉴얼 grep 확인, 0건 외 이 1건) |

**Score:** 3/4 fully met, 1/4 (criterion 2) honestly partial for a deliberate, documented, user-decided reason.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `docs/manual/00-getting-started.md` | Entry point, service table, symptom→doc index | ✓ VERIFIED | 133 lines, C1-C5 all PASS, indexes all 4 sibling docs + 9 engineering records |
| `docs/manual/01-cli.md` | DOC-01 | ✓ VERIFIED | 145 lines, C1-C4 PASS, Plan/Act hedged at exact evidence level, checkpoints separated |
| `docs/manual/02-kanban.md` | DOC-02 | ⚠️ PARTIAL (by design) | 198 lines, C1-C4 PASS, explicitly self-labels "부분적으로만 충족" in its own second paragraph |
| `docs/manual/03-mobile.md` | DOC-03 | ✓ VERIFIED | 115 lines, C1-C4 PASS, delegates rather than duplicates iPad checklist/Telegram recipe |
| `docs/manual/04-32k-operations.md` | DOC-04 | ✓ VERIFIED | 126 lines, C1-C4 PASS, retired advice named once and retired, never reissued |
| `phase-08/manual/check_manual_claims.sh` | Standing honesty gate | ✓ VERIFIED | Marker+link-integrity based (not forbidden-string), scoped only to `docs/manual/`, negative-control proven fail-closed (see below) |
| `README.md` | Repo entry index | ✓ VERIFIED | 73 lines, distinguishes `docs/manual/` (usage) from 9 engineering records, all named paths resolve, 6-gate table, 5 prohibitions |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `check_manual_claims.sh` | `docs/manual/*.md` (5 files) | required-marker registry (17 pairs, 13 distinct GAP tokens) | ✓ WIRED | Registry cross-checked against every `[GAP-*]` token planned across all six 08-0x PLAN.md files — 13/13 distinct tokens match exactly, none silently dropped |
| `check_manual_claims.sh` negative control | `phase-08/manual/fixtures/negative/` | `--negative-control` flag, inverted pass/fail | ✓ WIRED, PROVEN | Re-ran myself: `CASES 11/18` on the broken fixture corpus, exits 0 (correctly fails closed); additionally, I tampered with a temp copy (removed `[GAP-PLANMODE]` from a copy of `01-cli.md`) and confirmed `C3-markers` genuinely flips from PASS to FAIL — the gate is not fail-open |
| `01-cli.md` §7 (cline checkpoint) | `02-kanban.md` (kanban checkpoint) | cross-reference, kept conceptually distinct | ✓ WIRED | Two concepts (`createCheckpoint`/`restoreCheckpoint` session-level vs `createWorkingTreeCheckpointCommit` task-level) never merged, each has its own `[GAP-*]` marker (`[GAP-CHECKPOINT-CLINE]` / `[GAP-CHECKPOINT-KANBAN]`) |
| `02-kanban.md` §2 registration | live `com.ohama.kanban` (pid 36175) | `workspace/scratch-repo` git-toplevel + `GIT_CONFIG_GLOBAL=/dev/null` | ✓ WIRED | Re-verified live: `kanban task list` from inside `workspace/scratch-repo` works, `verify_services.sh` 15/15 PASS |
| `02-kanban.md` §6 worktree | sandbox boundary | `git worktree add` ancestor-stat vs `$HOME` deny | ✓ CORRECTLY UNWIRED (documented) | Reproduced failure not re-tested by me (would require live `git worktree add`, out of read-only scope) but the cause chain (SBPL `file-read-metadata` deny on `$HOME`) is consistent with `docs/sandbox-whitelist.md` §9 and the DECLINED decision record |
| `phase-06/results/.../inventory.txt`, `phase-07/bench/config.env` | `verify_network.sh` check 15, `verify_bench.sh` B10 | dated `RECONCILED` addendum, first-match parser | ✓ WIRED, VERIFIED HONEST | See Pid-Baseline Reconciliation section below |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|---|---|---|
| DOC-01 | ✓ SATISFIED | None |
| DOC-02 | ⚠️ PARTIALLY SATISFIED (recorded as such in REQUIREMENTS.md, not ticked) | Worktree unavailable — deliberate user decline, not a defect |
| DOC-03 | ✓ SATISFIED | None (iPad/Telegram live observation remains a separate human_needed item from Phase 6, correctly out of this phase's scope) |
| DOC-04 | ✓ SATISFIED | None |

### Anti-Patterns Found

None. No `TODO`/`FIXME`/placeholder patterns found in any of the five manual documents or the
gate script. No overclaim sentences found (see Overclaim Audit below).

## Honesty Gate Audit (`phase-08/manual/check_manual_claims.sh`)

**Marker registry completeness.** Cross-referenced the 13 distinct `[GAP-*]` tokens the gate
enforces against every `[GAP-*]` token named across all six `08-0x-PLAN.md` files. Exact match,
13/13, nothing silently dropped:
`GAP-BENCH, GAP-CHECKPOINT-CLINE, GAP-CHECKPOINT-KANBAN, GAP-CLINE-VERSION,
GAP-COMPACTION-CONFIG, GAP-IPAD, GAP-PLANMODE, GAP-PORT3000, GAP-READONLY, GAP-REBOOT,
GAP-TELEGRAM-INDICATOR, GAP-TELEGRAM-TOKEN, GAP-WORKTREE`.

**Scope.** Confirmed by reading the script: `MANUAL_DIR` defaults to `docs/manual`, all four
content checks (`C1`-`C4`) operate only inside `$MANUAL_DIR`, and the script's own header states
it never reads `.planning/`, never reads a PLAN.md, and never scans `docs/*.md` outside
`docs/manual/`. Confirmed empirically: ran the gate and it never touched any file outside
`docs/manual/`.

**Fails when it should.** Two independent proofs, both executed live in this session:
1. `bash phase-08/manual/check_manual_claims.sh --negative-control` against the pre-built broken
   fixture corpus (`phase-08/manual/fixtures/negative/`): `CASES 11/18`, and because
   `--negative-control` inverts the pass/fail expectation, this correctly exits 0 ("gate correctly
   rejected the broken fixture corpus"). Each of C1-C4 is individually demonstrated failing on
   its own dedicated fixture defect (missing file, too-short file, missing marker, dangling
   link, missing index reference).
2. **My own tamper test** (not pre-scripted by the project): copied `docs/manual/` and the gate
   script into a scratch directory, ran the gate clean (baseline), then stripped the literal
   `[GAP-PLANMODE]` string from a copy of `01-cli.md` and re-ran. `C3-markers:01-cli.md` flipped
   from `PASS` to `FAIL — missing: [GAP-PLANMODE]`, `CASES` dropped from 4/4 (well, 3/4 baseline
   in my isolated copy, C4-links legitimately failed due to my copy lacking the rest of the repo
   tree — not a gate defect) to 2/4. The marker check genuinely fails when the marker is absent.

**Real run over all five documents:** `CASES 21/21`, exit 0, confirmed matching the claimed
`CASES 21/21` from 08-06-SUMMARY.md exactly.

## Overclaim Audit (independent of the gate — read all five documents directly)

Read all five documents in full and checked each item the verification brief flagged as a
potential overclaim:

| Overclaim to check for | Found? | Where checked |
|---|---|---|
| Remotely-triggered agent can modify files | Not found — explicitly denied 3x (`[GAP-READONLY]` in 00/01/02) | "원격에서 트리거된 에이전트는 파일을 수정할 수 없다" appears verbatim in all three |
| Reboot persistence observed | Not found — explicitly denied | `00-getting-started.md` §4: "실제 macOS 재부팅은 한 번도 수행된 적이 없다" |
| iPad access observed | Not found — explicitly denied | `03-mobile.md` §2 `[GAP-IPAD]`: "이 tailnet 주소를 iOS 기기에서 방문해본 사람은 아직 아무도 없다" |
| Telegram indicator observed | Not found — explicitly denied | `03-mobile.md` §6 `[GAP-TELEGRAM-INDICATOR]`: "아무도 실제 Telegram 클라이언트를 지켜본 적이 없다" |
| Telegram token configured | Not found — explicitly denied | `03-mobile.md` §5 `[GAP-TELEGRAM-TOKEN]`: "토큰 슬롯은 지금 비어 있다" |
| cline-bench passed / verified the stack | Not found — 3-sentence allowlist enforced, forbidden-sentence list included | `04-32k-operations.md` §7 `[GAP-BENCH]`: exactly the 3 permitted sentences, explicit forbidden-sentence list |
| Pinned cline currently 3.0.53 | Not found — explicitly denied everywhere it's mentioned | `00-getting-started.md` §5, `01-cli.md` §8: "이 매뉴얼의 어떤 문서도 '3.0.53 고정'을 현재 사실로 쓰지 않는다" / "이 문서 어디에도 핀(3.0.53)을 현재 사실로 적지 않는다" — grepped all 5 docs for `3.0.53`, every occurrence is in a sentence denying it's current |
| Worktree works | Not found — explicitly denied | `02-kanban.md` §6 `[GAP-WORKTREE]`: "지원되지 않는다"; also confirmed by the empty `worktreeCleanup: [{"removed":false}]` evidence in §3 |
| Retired "작업 예산"/"태스크 쪼개기" advice reissued | Not found — appears exactly once, only in a retiring heading | Grepped all 5 docs: 1 total occurrence, in `04-32k-operations.md` §4's own retiring heading; never repeated as live guidance |

No overclaims found anywhere in the prose beyond what the gate's markers check for presence —
the surrounding sentences genuinely carry the hedges, not just the bracket tokens.

## Plan/Act and Checkpoint Separation (Criterion 1 detail)

Verified `01-cli.md` §6 hedges at exactly the claimed evidence level: `--mode <act|plan>` is
stated as a confirmed literal from a binary `strings` scan (fact), while whether this project's
own headless one-shot command *exposes* `--mode` is explicitly marked `[GAP-PLANMODE]` and
stated as unconfirmed — "Plan 모드가 헤드리스에서 작동한다고도, 작동하지 않는다고도 쓰지 않는다".
No sentence in the document asserts Plan mode works or fails headlessly.

The two "체크포인트" concepts are kept structurally separate and cross-referenced, never merged:
`01-cli.md` §7 owns cline's own session-level file checkpointing
(`createCheckpoint`/`restoreCheckpoint`), explicitly hands off Kanban's task-level
`createWorkingTreeCheckpointCommit` to `02-kanban.md` in one sentence ("이건 02-kanban.md 의
소관이다 — 두 개념을 섞지 말 것"). `02-kanban.md` §5 mirrors this in reverse, cross-referencing
back to `01-cli.md` §7. Confirmed both directions.

## Pid-Baseline Reconciliation Audit (highest-risk item)

Read the diffs directly (`git show ef9f3fb`) and `RECONCILIATION.md`. Findings:

- **`phase-06/results/20260830T051403Z-baseline/inventory.txt`**: A new
  `=== RECONCILED (2026-08-31, 08-06 phase-close) ===` block with the current kanban pid (36175)
  in the exact `ps`-row format was **inserted before** the original 2026-08-30T05:14:03Z capture.
  Read the full file myself: the original capture (including the historical `53894` line under
  `lsof -nP -iTCP:3484`) is present, byte-for-byte, below the new block. Nothing was deleted or
  overwritten.
- **`phase-07/bench/config.env`**: `LIVE_PIDS_STR`'s default was changed in place
  (`53894` → `36175`) with a dated comment. This is a live-expectation config constant (not an
  audit transcript), consistent with how B10 and `preflight.sh` P1 consume it.
- **Parser confirmation**: read `phase-06/net/verify_network.sh`'s check 15 code directly — it
  does `grep -F '/opt/homebrew/bin/kanban' "$INV" | awk '{print $1}' | head -1`, which correctly
  picks up the new RECONCILED line first (since it precedes the original transcript in the file).
- **Check counts unchanged**: read both scripts' check logic — `record_check`/`record` calls for
  check 15 / B10 are structurally untouched; no check was added, removed, or weakened. Only the
  input data these checks read against changed.
- **Live re-run confirms the claim**: I ran both gates myself. `verify_network.sh --baseline
  phase-06/results/20260830T051403Z-baseline` → `CASES 24/24`. `verify_bench.sh` → `CASES 11/11`.
  Both match the SUMMARY's claimed counts exactly.

**Verdict: this reconciliation is honest.** The recorded expectation was updated to match live
reality via an additive, dated, explained marker — not by weakening a check or discarding the
original measurement.

## Standing Gates — Re-run Personally

| Gate | Result |
|---|---|
| `phase-08/manual/check_manual_claims.sh` | PASS, `CASES 21/21`, exit 0 |
| `phase-08/manual/check_manual_claims.sh --negative-control` | PASS (correctly fails the broken fixture), exit 0 |
| `phase-01/config/verify_config.sh` | PASS, exit 0 |
| `phase-02/infra/verify_no_regression.sh` | `INF03: PASS`, exit 0 |
| `phase-03/sandbox/verify_sandbox.sh` | PASS, `CASES 16/16`, all 4 CRITERION lines PASS, exit 0 |
| `phase-03/sandbox/verify_sandbox.sh --negative-control` | PASS — correctly rejected a deliberately fail-open fixture profile (exercised as an additional negative control per the task's instruction to break at least one gate's documented negative control) |
| `phase-05/services/verify_services.sh` | PASS, `CASES 15/15`, exit 0 |
| `phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline` | PASS, `CASES 24/24`, exit 0 |
| `phase-07/bench/verify_bench.sh` | PASS, `CASES 11/11`, exit 0 |
| `pytest phase-03/tests phase-04/tests` | 24 passed |

All match the SUMMARY-claimed values exactly. No gate was silently weakened.

## Sandbox Boundary — Confirmed Exactly As It Was

- `EXTRA_ALLOW_PATHS`: confirmed empty in environment and not present in any live config touched by this phase.
- `git diff --stat 1d71189^..HEAD -- phase-03/`: 188 files changed, but **every single one** is
  under `phase-03/results/<timestamp>-{sbx,negative-control}/` — generated, read-only gate-run
  transcripts, consistent with the project's pre-existing convention of tracking such evidence.
  `git diff` on the core files (`phase-03/sandbox/*.py`, `phase-03/sandbox/*.sh`,
  `workspace/ALLOWED_REPOS.json`, `workspace/sandbox.sb`) since before Phase 8 is **empty** —
  confirmed directly.
- `workspace/sandbox.sb`: 10 lines, unchanged shape.
- `workspace/ALLOWED_REPOS.json`: `repos[]` contains exactly one entry
  (`workspace/scratch-repo`); `bench/` absent, confirmed via direct JSON parse.
- `bench/runs/CANARY.txt`: exists on disk (readable from *outside* the sandbox, as expected — the
  guarantee is unreadability *from inside* it); `verify_bench.sh` B9 (unchanged) and B7 (SBX-04
  re-assertion) both re-ran PASS in this session, consistent with continued in-sandbox
  unreachability.

## Collateral Damage — Confirmed None

- Six live pids, checked directly via `ps -p`: flashnext 46573 ALIVE, role-shim 75548 ALIVE,
  litellm 48525 ALIVE, kanban 36175 ALIVE, telegram-connect 99162 ALIVE, kanban-proxy 19669
  ALIVE — all match the SUMMARY-claimed pids exactly.
- Port 3000: confirmed unbound (`lsof -nP -iTCP:3000 -sTCP:LISTEN` empty).
- `tailscale serve status`: only the pre-existing `:8443` Funnel handler and Phase 6's `:8444`
  tailnet-only handler are present (plus two other pre-existing, unrelated entries at `:10000`
  and bare `:443` that were already in the Phase 6 baseline capture, confirmed by reading
  `inventory.txt`) — no new entry added by Phase 8.
- `AllowFunnel`: `{'ohama-2.tail318f12.ts.net:8443': True}` — holds only the pre-existing `:8443`
  key.
- Host `cline`: `/opt/homebrew/lib/node_modules/cline/package.json` reports `3.0.60` — confirmed
  still drifted from the 3.0.53 pin, and confirmed Phase 8 did not change it (no `cline`
  invocation was made by this phase per every SUMMARY's explicit "zero host cline invocations"
  claim, and I did not invoke it either, per my own read-only constraint).

## Milestone Coherence (Final Phase)

`ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `phase-08/results/20260830T200237Z-phase-close/
criteria.md` all agree: criteria 1/3/4 `met`, criterion 2 `partially_met` with the identical
reason (worktree unavailable, user declined sandbox widening in 08-04) stated in each place, no
softening or promotion anywhere. `REQUIREMENTS.md`'s DOC-02 checkbox is deliberately left
unticked (`[ ]`) with a dated note — this is itself evidence the project did not attempt to hide
the partial status.

`README.md` (new, root of repo) clearly distinguishes `docs/manual/` (사용법 — usage) from the
nine `docs/*.md` engineering records (어떻게 만들어졌고 검증됐나 — how it was built/verified), with
a table for each and every named path confirmed to resolve. `docs/manual/00-getting-started.md`
provides the same distinction from the manual's side, and additionally documents the six live
services, symptom→document routing, and links to all nine engineering records.

## Judgment on DOC-02 / Criterion 2

**This is honest partial-met status, not a false green, and not a gap requiring further plans.**
The phase's actual goal — "실제로 출하된 것을 기준으로 ... 문서화한다" (document based on what was
actually shipped) — requires the manual to accurately reflect the deployed system, not to make
the deployed system more capable. Since `git worktree add` is genuinely, permanently unusable in
this deployment (reproduced via three independent call-shapes, root-caused to an SBPL ancestor-
stat conflict with `$HOME`), and the user was shown the exact, measured, ready-to-apply fix and
explicitly declined it, the only honest way to satisfy criterion 2's intent is exactly what was
done: document the working parts (cards, registration, dependency chain) from live evidence,
and document the non-working part (worktree) with its exact cause, its exact would-be fix, and
the fact that the fix was declined — rather than silently omitting the topic or asserting it
works. The criterion's own wording ("절차가 기술돼 있다" — the procedure is described) is satisfied
for worktree in the only way truthfully available: the *absence* of the procedure, and why, is
what is actually described. Per the explicit instruction not to manufacture a gap the user
deliberately declined, and finding the partial status honestly and consistently recorded
everywhere it needs to be, this does not block the phase or the milestone.

## Human Verification Required

None new from this phase. The pre-existing human_needed items (iPad live visit / NET-01,
Telegram live trial / NET-05) were already correctly flagged as out-of-scope for Phase 8 by
Phase 6, and Phase 8's documents correctly reference them via `[GAP-IPAD]` /
`[GAP-TELEGRAM-INDICATOR]` / `[GAP-TELEGRAM-TOKEN]` rather than re-claiming or re-opening them.

---
*Verified: 2026-08-30T20:18:47Z*
*Verifier: Claude (gsd-verifier)*
