# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-01)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
  — v1 에서 **합성 조건에 한해** 달성. 실제 에이전트 부하에서는 미달성
**Current focus:** v1.1 — Phase 9 (사전 확인 게이트, 스택 무변경)

## Current Position

Milestone: v1.1 Plan/Act ↔ reasoning_effort
Phase: 9 of 12 (사전 확인 게이트 — 스택 무변경) — 진행 중
Plan: 3 of 4 (09-03 완료 — PRB-04 통제 replay 재측정 + 소스 정정 기록)
Status: In progress
Last activity: 2026-09-01 — 09-03-PLAN.md 실행 완료: PRB-04 (kill condition) 통제
  replay 를 합성/실제 트레이스 양쪽, :8011/:4000 양쪽, reasoning_content/reasoning
  양쪽 필드명으로 처음부터 재측정 (16개 판정 전부 delta=0 CONFIRMED, 실제 2,497자
  트레이스 포함 길이 임계값 효과 없음 확인), shouldIncludeReasoningHistory/
  agentPartToContentBlock 소스 경로를 관측 라인 번호로 재검증, 구현 문서의 오탐
  (false negative) 을 Phase 12 편집 대상으로 기록 (Phase 9 는 문서를 수정하지 않음).
  게이트 판정 자체는 09-04 로 이연.

Progress: [████░░░░░░] v1.1 in progress (19/19 requirements mapped, 3/4 Phase 9 plans executed; Phase 10–12 plans TBD)

## Performance Metrics

**v1 총계:**
- 페이즈 8, 플랜 55, 커밋 276
- 3,326 files changed, 171,472 insertions
- 3일 (2026-08-29 → 08-31)

**v1.1:** Phase 9 Plan 01 — 3 tasks, 3 commits, ~15min (2026-09-01)
**v1.1:** Phase 9 Plan 02 — 3 tasks, 3 commits, ~25min (2026-09-01)
**v1.1:** Phase 9 Plan 03 — 3 tasks, 3 commits, ~15min (2026-09-01)

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
- **09-03**: PRB-04(🔴 kill condition)의 통제된 replay 를 처음부터 재측정 — research 의
  1,380자 합성 트레이스뿐 아니라 09-02 가 확보한 실제 xhigh 트레이스(최장 989자, 3턴 연결
  2,497자)까지, `:8011`/`:4000`(무수정 `flashnext` 별칭) 양쪽, `reasoning_content`/`reasoning`
  양쪽 필드명으로, 총 16개 delta 판정 전부 CONFIRMED(delta=0, CLEAN flake window). 2,497자
  실제 트레이스에서도 길이 임계값 효과 없음 확인 — research 의 미해결 위험(합성 트레이스만
  썼다는 점)을 실측으로 닫음. 09-02 의 confounded 멀티턴 성장(ON +58/+23)과의 정합성도
  검증 — 소규모 보강 프로브(turn3 사용자 메시지 단독 21 vs baseline 13)로 +23 의 잔차가
  트레이스 길이가 아니라 턴 경계/서식 오버헤드로 설명됨을 확인, 모순 없음(모순이었다면 이
  문서에 그렇게 기록했을 것). 소스 재검증: `shouldIncludeReasoningHistory`(ai-sdk.ts:284-289)
  와 `agentPartToContentBlock`(agent-message-codec.ts:231, `case "reasoning"` at :237)을
  cli-v3.0.53 에서 관측 라인 번호로 재확인(cline-src 무수정, `git status --porcelain` 공백).
  구현 문서(`docs/plan-act-reasoning-implementation.md:96-100,102`,
  `docs/plan-act-reasoning-diagrams.md:187-191`)의 "누적 안 됨" 결론이 **오탐**이라고
  `PRB-04-FINDINGS.md` 에 기록 — Cline 은 non-Cerebras 프로바이더에 기본적으로 reasoning
  history 를 재첨부하지만(구조적으로는 누적), 이 스택에서 토큰 비용은 0(측정으로 확정)이라
  게이트는 무사함. 문서 편집은 Phase 12(USE-05) 소유, Phase 9 는 기록만 함. 실제 `cline`
  프로세스 확인은 Phase 10 의 `VRF-04` 로 명시 이연(REQUIREMENTS.md 기존 항목). 게이트 판정은
  여전히 선언 안 함 — 09-04 몫. 증거: `phase-09/results/CURRENT_PRB04_RUN` →
  `phase-09/PRB-04-FINDINGS.md`.

### Pending Todos

없음

### v1.1 게이트 — 로드맵에 반영됨 (Phase 9 에서 답한다)

- 🔶 **PRB-01 (Phase 9, 진단 — 2026-09-01 게이트에서 강등)** — `reasoning_effort: medium` 단독으로
  사고가 켜지는가. 별칭이 `enable_thinking: true` 를 함께 주입하도록 바뀌어(CFG-11) 부정이어도
  마일스톤은 계속된다. "effort 하나로 충분한가"에 답하는 값은 여전히 있다.
- 🔴 **CFG-16 (Phase 10, 신설)** — 두 파라미터 조합이 실제로 `reasoning` 을 만드는가.
  이 조합은 이 스택에서 측정된 적이 없다.
- 🔴 **PRB-04 (Phase 9, 게이트)** — 사고 트레이스가 다음 턴 컨텍스트로 돌아오는가. 돌아오면
  v1 의 "실제 부하에서 압축이 프루닝하지 않는다"와 겹쳐 마일스톤 폐기 조건. 09-03 이 결정적
  통제 측정(합성+실제 트레이스, 16/16 CONFIRMED delta=0)과 소스 정정 기록을
  `phase-09/PRB-04-FINDINGS.md` 에 남김 — 판정 자체는 09-04 몫.
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
Stopped at: 09-03-PLAN.md 실행 완료 (PRB-04 통제 replay 합성+실제 트레이스 재측정,
  소스 경로 재검증, 구현 문서 오탐 정정 기록), 09-03-SUMMARY.md 작성. 다음: 09-04-PLAN.md
  (PRB-01/PRB-04 게이트 판정)
Resume file: None
