# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-31)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
  — v1 에서 **합성 조건에 한해** 달성. 실제 에이전트 부하에서는 미달성
**Current focus:** v1.1 — Plan/Act 모드에 따른 reasoning_effort 설정

## Current Position

Milestone: v1.1 Plan/Act ↔ reasoning_effort — 시작
Phase: 미정 (요구사항 정의 중)
Plan: —
Status: Defining requirements
Last activity: 2026-09-01 — v1.1 착수. 범위: plan/act ↔ reasoning, CLI 만

Progress: [░░░░░░░░░░] v1.1 0%

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

### v1.1 게이트 (구현 전 반드시 답해야 함)

- 🔴 **T1-a** — `reasoning_effort: medium` 이 실제로 `reasoning` 필드를 만드는가.
  VALIDATED 의 시스템 프롬프트 길이가 medium(21) < 미지정(23) 이라 직관과 어긋난다.
  확인 없이 진행하면 아무 일도 안 하는 설정을 배포하게 된다.
- 🔴 **T2** — 사고 트레이스가 다음 턴 컨텍스트로 돌아오는가. 돌아오면 v1 의
  "실제 부하에서 압축이 프루닝하지 않는다"와 겹쳐 치명적 → 마일스톤 폐기 조건.
  소스는 "안 돌아온다" 쪽(`toGatewayRequestMessages` 는 content 만 순회)이나 결정적이지 않다.
- 🟡 **litellm 재기동 필요** — 핫리로드 없음. Kanban/Telegram 요청이 끊긴다.

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

Last session: 2026-09-01
Stopped at: v1.1 착수 — PROJECT.md/STATE.md 갱신, 요구사항 정의 대기
Resume file: None
