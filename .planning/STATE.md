# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-01)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
  — v1 에서 **합성 조건에 한해** 달성. 실제 에이전트 부하에서는 미달성
**Current focus:** v1.1 — Phase 9 (사전 확인 게이트, 스택 무변경)

## Current Position

Milestone: v1.1 Plan/Act ↔ reasoning_effort
Phase: 9 of 12 (사전 확인 게이트 — 스택 무변경) — 진행 중
Plan: 2 of 4 (09-02 완료 — PRB-03 오라클 재측정 + 멀티턴 성장 비교)
Status: In progress
Last activity: 2026-09-01 — 09-02-PLAN.md 실행 완료: 6-arm effort/enable_thinking
  스윕(unspecified/medium/low/xhigh/et-true/et-medium) watermark 귀속으로 재측정,
  xhigh thinking-on/off 3턴 시퀀스 실행 및 실제 reasoning 트레이스 2,497자 확보
  (게이트 판정 자체는 09-04 로 이연)

Progress: [███░░░░░░░] v1.1 in progress (19/19 requirements mapped, 2/4 Phase 9 plans executed; Phase 10–12 plans TBD)

## Performance Metrics

**v1 총계:**
- 페이즈 8, 플랜 55, 커밋 276
- 3,326 files changed, 171,472 insertions
- 3일 (2026-08-29 → 08-31)

**v1.1:** Phase 9 Plan 01 — 3 tasks, 3 commits, ~15min (2026-09-01)
**v1.1:** Phase 9 Plan 02 — 3 tasks, 3 commits, ~25min (2026-09-01)

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
- **09-02**: PRB-03 오라클을 처음부터 다시 측정 — 4-arm 이 아니라 6-arm(unspecified/medium/
  low/xhigh/et-true/et-medium), 매 요청을 log watermark 로 귀속(tail -N 아님), 스윕을
  두 번(A/B) 돌려 일치 확인(불일치 시 3차 스윕 로직도 구현했으나 이번엔 불일치 없어 미실행).
  결과: fresh 절대값(13/11/41/53)과 delta(medium −2/low +28/xhigh +40) 모두 09-RESEARCH.md·
  VALIDATED.md 와 완전히 일치. 새 발견: `et-true`(enable_thinking:true 단독)는 `xhigh` 와
  절대값까지 동일(VALIDATED.md §4 검증됨) — 그러나 `et-medium`(출하되는 조합)은 `medium` 과
  절대값까지 동일(11), 즉 **`enable_thinking:true` 를 얹어도 `medium` 의 −2 마진이 전혀
  넓어지지 않음** — Phase 10 은 `et-medium` 자체를 도달 증명 오라클로 쓸 수 없고 `low`/`xhigh`
  로 도달을 증명한 뒤 별칭은 `medium`/`et-medium` 으로 배포해야 한다. 이어서 xhigh thinking
  on/off 3턴 시퀀스 각 1회씩 실행 — ON 은 매 턴 reasoning_content 를 다음 턴에 되먹임,
  prompt_tokens 69→127→150(+58,+23); OFF 는 되먹임 없이 29→360→681(+331,+321). ON 이 훨씬
  느리게 자란 것은 09-RESEARCH.md 의 "재생된 reasoning 은 토큰 비용이 0" 결과와 방향은
  일치하지만, ON 턴2·3 은 max_tokens=300 을 xhigh reasoning 이 전부 써버려 content 가 완전히
  비어 나온 confound 가 있어 결정적 증거로 쓰지 않음(09-03 의 통제된 replay 프로브가 결정적).
  실제 xhigh reasoning 트레이스 2,497자를 디스크에 확보(09-03 재사용용). 게이트 판정은 여전히
  선언 안 함 — 09-04 몫. 증거: `phase-09/results/CURRENT_PRB03_RUN` → `PRB-03-ORACLE.md`.

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
Stopped at: 09-02-PLAN.md 실행 완료 (PRB-03 오라클 6-arm 재측정 + xhigh 멀티턴
  성장 비교 + 실제 트레이스 확보), 09-02-SUMMARY.md 작성. 다음: 09-03-PLAN.md
Resume file: None
