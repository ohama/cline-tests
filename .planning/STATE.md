# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-31)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
  — v1 에서 **합성 조건에 한해** 달성. 실제 에이전트 부하에서는 미달성
**Current focus:** v1 출하 완료. 다음 마일스톤 계획 대기

## Current Position

Milestone: v1 ✅ SHIPPED 2026-08-31
Phase: 없음 (전 페이즈 아카이브됨 → `.planning/milestones/v1-phases/`)
Status: Ready to plan next milestone
Last activity: 2026-08-31 — v1 마일스톤 완료, 기술부채 수용하고 종료

Progress: [██████████] v1 8/8 phases, 55/55 plans

## Performance Metrics

**v1 총계:**
- 페이즈 8, 플랜 55, 커밋 276
- 3,326 files changed, 171,472 insertions
- 3일 (2026-08-29 → 08-31)

## Accumulated Context

### Decisions

전체 로그는 PROJECT.md 의 Key Decisions, 마일스톤 요약은 MILESTONES.md 참조.

### Pending Todos

없음

### Blockers/Concerns (v1 에서 이월)

- 🔴 **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 cline 자동 업데이트를 막지 못한다.
  v1 작업 중 3.0.53 ↔ 3.0.60 드리프트가 여러 차례 재현됐고 매번 수동 재설치가 필요했다.
  상시 서비스가 도는 상황에서 특히 위험하다.
- 🔴 **실제 부하에서 압축이 프루닝하지 않는다.** 캡처된 실제 `completed` 압축 이벤트 2/2 건이
  메시지를 하나도 지우지 않았고 토큰은 오히려 늘었다(합성 5/5 건은 반대). cline-bench 통과 0개.
  `contextWindow` 는 이 결함의 지렛대가 아님이 근인 행렬로 확인됐다.
- 🟡 **`--compaction basic` 미검증** — 행렬이 지목한 유일한 유망 후보. 의식적 보류.
  `phase-01/results/exp-basic/` 는 오설정 상태였으므로 증거로 쓸 수 없다.
- 🟡 **Phase 1 VERIFICATION.md 부재** — 결론이 두 번 뒤집힌 유일한 미검증 페이즈.
- 🟡 **NET-01 / NET-05 미관측** — iPad 오프라인, Telegram 실토큰 시험 거절.
- 🟡 **재부팅 지속성은 프록시 증거** — 실제 재부팅 시 `iogpu.wired_limit_mb` 재적용 필요.
- 🟡 **기존 공개 Funnel** `:8443 → 127.0.0.1:3000` 존치. 포트 3000 바인딩 금지가 보상 통제.

## Session Continuity

Last session: 2026-08-31
Stopped at: v1 마일스톤 완료 (아카이브 + PROJECT.md 진화 + 태그)
Resume file: None
