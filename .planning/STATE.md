# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-01)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
  — v1 에서 **합성 조건에 한해** 달성. 실제 에이전트 부하에서는 미달성
**Current focus:** v1.1 — Phase 9 (사전 확인 게이트, 스택 무변경)

## Current Position

Milestone: v1.1 Plan/Act ↔ reasoning_effort
Phase: 9 of 12 (사전 확인 게이트 — 스택 무변경) — 진행 중
Plan: 1 of 4 (09-01 완료 — probe_lib.sh + PRB-01/PRB-02 fresh 재측정)
Status: In progress
Last activity: 2026-09-01 — 09-01-PLAN.md 실행 완료: preflight/postflight 안전망 +
  gpu-stream flake 판별기 + 4상태 verdict 머신 구축, PRB-01·PRB-02 를 이 페이즈
  자체 결과로 독립 재측정 (게이트 판정 자체는 09-04 로 이연)

Progress: [██░░░░░░░░] v1.1 in progress (19/19 requirements mapped, 1/4 Phase 9 plans executed; Phase 10–12 plans TBD)

## Performance Metrics

**v1 총계:**
- 페이즈 8, 플랜 55, 커밋 276
- 3,326 files changed, 171,472 insertions
- 3일 (2026-08-29 → 08-31)

**v1.1:** Phase 9 Plan 01 — 3 tasks, 3 commits, ~15min (2026-09-01)

## Accumulated Context

### Decisions

전체 로그는 PROJECT.md 의 Key Decisions, 마일스톤 요약은 MILESTONES.md 참조.
v1.1 설계 근거: `docs/plan-act-reasoning-{design,implementation,diagrams}.md`.

- **09-01**: research 의 단발 측정에 기대지 않고, 이 페이즈 자체의 preflight/postflight
  안전망(PID+config hash 스냅샷)과 gpu-stream flake 4상태 verdict 머신을 구축한 뒤 PRB-01·
  PRB-02 를 처음부터 다시 측정했다. PRB-01 은 research 보다 더 깨끗한 결과를 얻음(negative
  control 추가: unspecified 는 reasoning 이 완전히 비고, medium 은 179자 — 명확한 대조).
  PRB-02 는 `enable_thinking:true` positive control 을 추가해 "reject 안 함"과 "실제로
  적용됨"을 구분했고, 적용됨 쪽 증거를 얻었다(reasoning_content 30자). 두 게이트 모두
  verdict 를 선언하지 않음 — research 값과의 대조 및 실제 게이트 판정은 09-04 의 몫.
  증거: `phase-09/results/CURRENT_PRB01_02_RUN` → `RESULT.md`.

### Pending Todos

없음

### v1.1 게이트 — 로드맵에 반영됨 (Phase 9 에서 답한다)

- 🔶 **PRB-01 (Phase 9, 진단 — 2026-09-01 게이트에서 강등)** — `reasoning_effort: medium` 단독으로
  사고가 켜지는가. 별칭이 `enable_thinking: true` 를 함께 주입하도록 바뀌어(CFG-11) 부정이어도
  마일스톤은 계속된다. "effort 하나로 충분한가"에 답하는 값은 여전히 있다.
- 🔴 **CFG-16 (Phase 10, 신설)** — 두 파라미터 조합이 실제로 `reasoning` 을 만드는가.
  이 조합은 이 스택에서 측정된 적이 없다.
- 🔴 **PRB-04 (Phase 9, 게이트)** — 사고 트레이스가 다음 턴 컨텍스트로 돌아오는가. 돌아오면
  v1 의 "실제 부하에서 압축이 프루닝하지 않는다"와 겹쳐 마일스톤 폐기 조건.
- 🟡 **Phase 10 진입 조건** — **PRB-04** 가 "진행" 판정이어야 착수. 하나라도 부정적이면
  Phase 10–12 는 집행하지 않고 Phase 9 에서 종료 — 이 역시 유효한 출하 결과다.
- 🟡 **litellm 재기동 필요 (Phase 10 이 소유)** — 핫리로드 없음. Kanban/Telegram 요청이 끊긴다.

### Blockers/Concerns (v1 에서 이월, v1.1 범위 밖)

- 🔴 **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 cline 자동 업데이트를 막지 못한다. v1.2+ 로 이월.
- 🔴 **실제 부하에서 압축이 프루닝하지 않는다.** cline-bench 통과 0개. `contextWindow` 는
  이 결함의 지렛대가 아님. v1.1 의 PRB-04 게이트가 이 문제와의 상호작용을 확인한다.
- 🟡 **`--compaction basic` 미검증** — v1.2+ 로 이월.
- 🟡 **Phase 1 VERIFICATION.md 부재** — v1 유일 미검증 페이즈, 이월.
- 🟡 **NET-01 / NET-05 미관측** — 이월.
- 🟡 **기존 공개 Funnel** `:8443 → 127.0.0.1:3000` 존치. 포트 3000 바인딩 금지가 보상 통제.

## Session Continuity

Last session: 2026-09-01
Stopped at: 09-01-PLAN.md 실행 완료 (probe_lib.sh + PRB-01/PRB-02 fresh 재측정),
  09-01-SUMMARY.md 작성. 다음: 09-02-PLAN.md
Resume file: None
