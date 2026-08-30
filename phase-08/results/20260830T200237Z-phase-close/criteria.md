# Phase 8 (한글 사용 매뉴얼) — 성공 기준 대조

RUN_DIR: `phase-08/results/20260830T200237Z-phase-close`
작성: 2026-08-31 (08-06, 마일스톤 마지막 플랜)

ROADMAP 원문(Phase 8 Success Criteria, 4개)을 그대로 옮기고 각각 met/partially_met/not_met 을
매긴다.

## Criterion 1

**원문:** "CLI 사용법 문서에 기동·태스크 실행·Plan/Act·체크포인트 절차가 실제 명령어와 함께
기술돼 있다"

**Verdict: met**

**Artifact:** `docs/manual/01-cli.md` (145줄) — 기동(§1, `verify_services.sh`), 태스크 실행
(§2, `phase-04/run_headless.sh` 실제 명령/env 노브 표), 결과 판정(§3, 6가지 outcome 표),
Plan/Act(§6, `[GAP-PLANMODE]` 정직 표기), 체크포인트(§7, `[GAP-CHECKPOINT-CLINE]` — cline
세션 체크포인트와 kanban 태스크 체크포인트를 명시적으로 구분).

**Evidence:** `phase-08/results/20260830T200237Z-phase-close/gates/check_manual_claims.txt`
(`CASES 21/21`, exit 0, C1~C4 전부 `01-cli.md` PASS).

## Criterion 2

**원문:** "웹(Kanban) 사용법 문서에 카드·worktree·diff 리뷰·의존 체인 절차가 기술돼 있다"

**Verdict: partially_met**

**Artifact:** `docs/manual/02-kanban.md` (198줄) — 문서 서두에 "부분적으로만 충족(partially
met)"을 명시적으로 고지. 카드(§3)·등록(§2)·의존 체인(§7)은 라이브 서버를 상대로 실측 확인해
문서화됐고, diff 리뷰(§4)는 CLI 에 diff/review 명령이 없다는 사실을 실측으로 확인해 정직하게
기록했다(웹 UI 는 직접 열어 확인하지 않았다고 명시). 네 주제 중 **worktree** 만 이 배포에서
지원되지 않는다(§6, `[GAP-WORKTREE]`) — Kanban 은 작업(task)마다 `git worktree add` 로 별도
작업 디렉터리를 만드는데, 08-RESEARCH.md §A6b 가 세 가지 call-shape 변형을 전부 재현해 확인한
대로 이 프로젝트 전체가 `$HOME` 아래 있는 한 no-widening 수정이 존재하지 않고, 유일한 해법
(metadata-only `$HOME` widening, `gen_sandbox_profile.py`의 `render_profile()` 변경)을
사용자가 정확한 비용을 보고 2026-08-31 에 **명시적으로 decline** 했다(08-04). 격상·완화하지
않는다 — 08-01 이 등록 블로커(gitconfig/git-toplevel)를 no-widening 으로 고쳤다는 사실과
worktree 가 여전히 불가능하다는 사실은 서로 다른, 독립된 두 실패 지점이다.

**Evidence:** `docs/manual/02-kanban.md` §6, `docs/sandbox-whitelist.md` §9,
`phase-08/results/20260830T193634Z-widening/DECISION.md` (DECLINED, 정확한 4-파일 diff와
측정 비용 포함), `phase-08/results/WORKTREE_STATUS` (`WORKTREE=UNAVAILABLE`).

## Criterion 3

**원문:** "iPad·iPhone 사용법 문서에 Tailscale 접속과 Telegram 대화/승인·거부 절차가 기술돼
있다"

**Verdict: met**

**Artifact:** `docs/manual/03-mobile.md` (115줄) — Tailscale 접속(§1, 단일 진입점 URL·연결
체인 3단), 승인/거부(§5) — 커넥터가 `--no-tools` 로 뜨므로 읽기·대화 전용이고 도구 승인/거부
프롬프트 자체가 발생하지 않는다는 사실을 정직하게 기록(아무도 도달할 수 없는 UI 를 지어내지
않음). iOS 기기 실측 방문(NET-01)과 Telegram 실토큰 라이브 트라이얼(NET-05)은 이 문서의 책임
범위가 아니라 사람이 닫아야 할 별개의 열린 항목이며, `[GAP-IPAD]`/`[GAP-TELEGRAM-INDICATOR]`/
`[GAP-TELEGRAM-TOKEN]` 으로 문서 안에 정직하게 표시돼 있다 — 이 gap 들의 존재가 "절차가
기술돼 있다"는 criterion 자체를 깎지 않는다: 절차는 기술돼 있고, 그중 사람이 아직 실행하지
않은 부분이 무엇인지도 함께 기술돼 있다.

**Evidence:** `phase-08/results/20260830T200237Z-phase-close/gates/check_manual_claims.txt`
(`03-mobile.md` C1~C4 전부 PASS), `phase-06/IPAD-CHECKLIST.md` (사람이 직접 따라갈 7단계).

## Criterion 4

**원문:** "32K 운용 주의 문서에 64초 대기, 압축이 자동으로 도는 것과 그때의 지연,
`contextWindow` 는 `settings` 최상위에 넣어야 한다는 점, ⌘+클릭 터치 불가, 그리고 Phase 1 VER
실측 결론이 반영돼 있다" (2026-08-31 정정 — 원 문구의 "26k 작업 예산"/"태스크 쪼개기" 두
항목은 DOC-04 의 2026-08-30 정정과 충돌해 제거됨)

**Verdict: met**

**Artifact:** `docs/manual/04-32k-operations.md` (126줄) — 64초 대기(§1), 압축 자동 발동과
그때의 추가 지연(§2), `contextWindow` 위치 gap(§3, `[GAP-COMPACTION-CONFIG]`), 폐기된 조언이
다시 나오지 않는다는 명시적 선언(§4 — "이 문서는 이 폐기된 조언을 어디에서도 다시 지침으로
내지 않는다"), ⌘+클릭 터치 불가(§6), Phase 1 VER 실측 결론(§2, 트리거 26,100·오버슈트
~3,100 토큰 근거).

**Evidence:** `phase-08/results/20260830T200237Z-phase-close/gates/check_manual_claims.txt`
(`04-32k-operations.md` C1~C4 전부 PASS); `.planning/ROADMAP.md` Phase 8 절 자체를
`grep -c '작업 예산'` 하면 0(재발 없음 재확인).

## 요약

| Criterion | Verdict |
|---|---|
| 1 (CLI) | met |
| 2 (Kanban) | partially_met — worktree unavailable |
| 3 (iPad/iPhone) | met |
| 4 (32K 운용 주의) | met |
