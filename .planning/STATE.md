# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-01)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
  — v1 에서 **합성 조건에 한해** 달성. 실제 에이전트 부하에서는 미달성
**Current focus:** v1.1 — Phase 11 (사용 표면: `cline-plan`/`cline-act` 래퍼와 A/B 게이트)

## Current Position

Milestone: v1.1 Plan/Act ↔ reasoning_effort
Phase: 10 of 12 — ✅ **완료** (2026-09-02), 검증 7/7. 다음은 Phase 11
Plan: 6 of 6 완료 (10-01 ~ 10-06)
Status: Phase 10 종료 — 별칭 5개 라이브, 도달 증명 완료, 실제 `cline` 에서 사고 관측됨
Last activity: 2026-09-02 — Phase 10 전체 완료. 사람 승인을 받고 유지보수 창을 열어
  `litellm` 을 두 번 재기동하며 라이브 설정을 교체했다. `flashnext-plan`(사고 medium) ·
  `flashnext-act`(사고 끔) · `flashnext-reach-xhigh`(검증 전용) 3개 추가, deprecated
  `qwen-*` 6개 제거(CFG-17). **도달을 HTTP 200 이 아니라 서버 로그 `prompt_tokens` 로
  증명**했고(+40, 오라클 정확 일치), 접두사 교란은 같은 본문 3쌍 전부 델타 0 으로 배제했다.
  **실제 `cline` 실행에서 `flashnext-plan` 스트림에만 사고가 나타났다**(대조군 0건) —
  v1.1 이 겨냥한 "설정이 존재한다 ≠ 작동한다"의 간극이 처음으로 닫혔다.

Progress: [██████░░░░] v1.1 (20/20 requirements mapped, 15/20 complete: PRB-01..04,
  CFG-11..17, VRF-01..04; Phase 9–10 완료, Phase 11–12 plans TBD)

## Performance Metrics

**v1 총계:**
- 페이즈 8, 플랜 55, 커밋 276
- 3,326 files changed, 171,472 insertions
- 3일 (2026-08-29 → 08-31)

**v1.1:** Phase 9 — 4 플랜, 12 태스크, 14 커밋, ~70분 (2026-09-01)
  측정 표본 37개 전부 CONFIRMED, 플레이크 0건, 스택 무변경 전 구간 유지
**v1.1:** Phase 9 Plan 02 — 3 tasks, 3 commits, ~25min (2026-09-01)
**v1.1:** Phase 9 Plan 03 — 3 tasks, 3 commits, ~15min (2026-09-01)
**v1.1:** Phase 10 Plan 01 — 3 tasks, 3 commits, ~25min (2026-09-01), 스택 무변경 유지,
  뮤턴트 4개 심어 사다리 검증(3/3 결정론적 CAUGHT)

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

- **09-02**: 별칭 설계 변경(CFG-11)에 맞춰 스윕을 4갈래 → 6갈래로 확장한 뒤 실측. **결과가
  설계 전제를 반증했다** — `et-medium`(11) = `medium`(11), `et-true`(53) = `xhigh`(53). 즉
  `reasoning_effort` 가 명시되면 `enable_thinking` 은 프롬프트 수준에서 아무 변화도 만들지
  않는다. 주입은 유지하되 근거를 "필요"에서 "이중 안전장치"로 정정. 또한 `medium`/`et-medium`
  의 −2 마진은 reach 프로브로 쓰기엔 너무 좁다 → Phase 10 은 `low`/`xhigh` 로 증명하고
  `et-medium` 으로 배포한다(더 약한 증명임을 명시).
- **09-03**: PRB-04 를 두 엔드포인트 × 두 필드명 × 합성/실제 트레이스로 재측정 — **16/16 이
  `delta=0`, `prompt_tokens=46` 고정.** 2,497자 실제 트레이스도 필드를 뺀 것과 동일. 길이 임계
  효과 없음. 소스도 태그 `cli-v3.0.53` 에서 재확인: Cline 은 사고를 컨텍스트에 **다시 붙인다**
  (`ai-sdk.ts:284-289`, `agent-message-codec.ts:231`, `message-builder.ts:1213-1214`) — 게이트가
  통과하는 이유는 "안 붙여서"가 아니라 **"붙여도 토큰이 0이라서"**다. 근거가 달랐다.
- **09-04**: 게이트 판정 **Phase 10 진행**, 사람 확인 완료. 판정문은 반증 조건("무엇이 반대
  판정을 냈을 것인가")을 결과를 보기 **전에** 명시했고, `REQUIREMENTS.md` 의 PRB-01 강등과
  `09-04-PLAN.md` §5 문구가 정합하지 않는다는 사실도 스스로 신고했다(이번엔 발동 안 함).
- **10-01**: 후보 설정(`hosted_vllm/` 3별칭)을 순수 삽입으로 생성하고 4단 검증 사다리를 구축한
  뒤, phase-09 의 전례("실제로 뮤턴트를 심어 비영(non-zero) 종료를 관측해야 믿는다")를 그대로
  적용해 4개 뮤턴트로 사다리 자체를 검증했다. 3/3 결정론적 뮤턴트(YAML 파손·drop_params·기준선
  변조) CAUGHT, 1개(litellm_params: null)는 측정치로 기록 — 실제로는 litellm 자신의 미처리
  예외(`AttributeError`)로 죽는 것이었고, 사다리가 처음엔 이를 90초 타임아웃으로만 감지해
  프로세스 생존 확인을 추가해 2초로 단축했다(실행 중 자체 발견·수정). 계획 문서 자체의 검증
  문구 버그 2건도 실행 중 발견해 고쳤다(drop_params 문구 자기충돌, hosted_vllm/ grep 과다 매칭).
  스택은 전 구간 무변경 — 후보는 `phase-10/config/`에만 존재. **미해결**: 실행 중
  `.planning/REQUIREMENTS.md`·`ROADMAP.md`에서 커밋 안 된 CFG-17(deprecated qwen-* 별칭 6개
  삭제, 10-01 범위 편입) 편집을 발견했으나 현재 권위 있는 `10-01-PLAN.md`의 순수 삽입
  불변식과 충돌해 실행하지 않음 — 아키텍처 변경급 판단이라 임의로 흡수하지 않고 그대로 남김.
  증거: `phase-10/results/CURRENT_VALIDATE_RUN` → `10-01-SUMMARY.md`.

### Pending Todos

없음

### v1.1 게이트 — ✅ Phase 9 에서 답했다 (2026-09-01)

- ✅ **PRB-04 (킬 컨디션)** — **양성.** 사고 트레이스를 되먹여도 `prompt_tokens` 가 전혀 늘지
  않는다. 16/16 `delta=0`, 46 토큰 고정 — 두 엔드포인트 · 두 필드명 · 합성 1,380자와 실제
  2,497자 전부. 길이 임계 효과 없음. **마일스톤 폐기 조건 미발동.**
  <br>※ 근거 주의: Cline 은 사고를 컨텍스트에 **다시 붙인다**(소스 재확인 완료). 통과 이유는
  "안 붙여서"가 아니라 **"붙여도 0토큰이라서"** 다. 서버가 필드를 토큰화 전에 버린다.
- ✅ **PRB-01 (진단)** — **양성.** `medium` 단독으로 사고가 켜진다(179자 vs 대조군 0자).
- 🔴 **CFG-16 (Phase 10)** — **질문이 좁아졌다.** "조합이 사고를 켜는가"는 이미 예(effort 가
  담당). 남은 질문은 **"litellm 이 별칭 주입으로 `enable_thinking` 을 통과시키는가"** —
  `reasoning_effort` 는 400 으로 막으면서 `enable_thinking` 은 200 으로 통과시키는 비대칭이 근거.
- 🔴 **VRF-04 (Phase 10)** — **실제 `cline` 은 Phase 9 에서 한 번도 실행하지 않았다.** 부품
  단위 측정만 했다. 사람이 이 이연을 명시적으로 승인했다(`GATE-VERDICT.md` §7).
- 🟡 **reach 프로브 제약 (Phase 10)** — `medium`·`et-medium` 의 −2 마진은 너무 좁다. `low`(+28)
  나 `xhigh`(+40) 로 도달을 증명하고 `et-medium` 으로 배포할 것 — **증명한 것과 배포하는 것이
  다르므로 더 약한 증명**임을 문서에 남길 것.
- 🟡 **오라클은 델타로만 쓸 것** — 절대값은 VALIDATED 대비 이동했다(23/21/51/63 → 13/11/41/53).
  델타는 비트 단위로 보존. 원인 미규명, 비차단.
- 🟡 **litellm 재기동 필요 (Phase 10 이 소유)** — 핫리로드 없음. Kanban/Telegram 요청이 끊긴다.
- 🟡 **문서 오탐 정정 (Phase 12 가 소유)** — `docs/plan-act-reasoning-implementation.md:96-100,102`
  와 `-diagrams.md:187-191`. Phase 9 는 기록만 남겼고 편집하지 않았다.
- 🔴 **미해결: CFG-17 vs 10-01-PLAN.md 불일치 (오케스트레이터 조정 필요)** — 10-01 실행 중
  `.planning/REQUIREMENTS.md`·`ROADMAP.md`에서 커밋되지 않은 편집을 발견함: 새 요구사항
  CFG-17(deprecated `qwen-*` 별칭 6개 삭제, 라이브 설정 34–50행)을 10-01 범위에 편입한다는
  내용. 그러나 실행에 사용한 권위 있는 `10-01-PLAN.md`에는 이 태스크가 없고, 그 문서 자신의
  `must_haves.truths`("라이브 파일의 모든 줄이 후보에 그대로 남는다")와 정면으로 충돌한다
  (삭제는 순수 삽입이 아니다). 10-01 은 이 편집을 실행하지 않고 두 파일을 편집된 그대로
  남겨두었다(커밋 안 함, 되돌리지도 않음). ROADMAP 편집 자체는 "10-03 유지보수 창에 합류"를
  제안하고 있음 — 다음 단계 전에 반드시 정리할 것. 상세: `10-01-SUMMARY.md`의
  "Issues Encountered" 절.

### 🔴 신규 발견 — `cline -m` 이 providers.json 을 건드린다 (2026-09-01, VRF-04 중)

`cline` **3.0.60** 이 `-m flashnext-plan` 호출 중 `providers.json` 의
`openai-compatible.updatedAt` 을 다시 썼다. `cli-v3.0.53` 소스 판독으로는 `-m` 이
호출 단위 오버라이드일 뿐 영속화하지 않는다고 봤는데, **3.0.60 에서는 아니다.**

- **중요한 값은 지켜졌다** — `settings.model` 은 여전히 `flashnext`,
  `contextWindow` 는 여전히 29000, `verify_config.sh` 는 OK.
- **바뀐 것은 타임스탬프뿐**이다. 그래서 파일 해시는 달라졌다:
  `5cf3800da31de885` → `da53de13abdac56b` (2026-09-01 09:10:32Z).
- **제약을 정정한다.** "providers.json sha256 불변"은 과도하게 엄격했다 —
  타임스탬프 한 줄을 설정 변경과 같이 취급했다. 실제로 지켜야 하는 것은
  **`model` 과 `contextWindow` 불변**이고, 그건 `verify_config.sh` 가 이미 검사한다.
  이후 페이즈는 해시가 아니라 이 두 값으로 판정할 것.
- **Phase 11 에 직접 영향** — 래퍼가 `-m` 을 반복 호출하므로 매번 이 쓰기가 일어난다.
- 복구 시도는 이 환경의 권한 시스템이 두 번 막았고, 실행자는 **우회하지 않았다**(옳다).
- 근거: `phase-10/results/20260901T091011Z-vrf04/PROVIDERS-JSON-FINDING.md`
- CFG-05(자동 업데이트 미차단)의 2차 피해다 — 3.0.53 에서 검증한 소스가 3.0.60 에는
  적용되지 않는다. 이 드리프트가 검증을 계속 무효화한다.

### Blockers/Concerns (v1 에서 이월, v1.1 범위 밖)

- 🔴 **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 cline 자동 업데이트를 막지 못한다. v1.2+ 로 이월.
- 🔴 **실제 부하에서 압축이 프루닝하지 않는다.** cline-bench 통과 0개. `contextWindow` 는
  이 결함의 지렛대가 아님. v1.1 의 PRB-04 게이트가 이 문제와의 상호작용을 확인한다.
- 🟡 **`--compaction basic` 미검증** — v1.2+ 로 이월.
- 🟡 **Phase 1 VERIFICATION.md 부재** — v1 유일 미검증 페이즈, 이월.
- 🟡 **NET-01 / NET-05 미관측** — 이월.
- 🟡 **기존 공개 Funnel** `:8443 → 127.0.0.1:3000` 존치. 포트 3000 바인딩 금지가 보상 통제.

## Session Continuity

Last session: 2026-09-02
Stopped at: Phase 10 완료 및 종료 커밋(검증 7/7). 별칭 5개가 라이브이고, 실제 `cline`
  실행에서 사고가 관측됐다.
  다음: /gsd:plan-phase 11 — `cline-plan`/`cline-act` 래퍼로 모드와 별칭의 짝을 강제하고,
  `medium` 이 실제로 결과를 개선하는지 A/B 로 판정한다. **개선이 없다는 결과도 유효한 통과다.**
  ※ Phase 11 이 물려받는 것:
    - `cline -m` 이 매 호출마다 `providers.json` 의 `updatedAt` 을 쓴다(위 🔴 절).
      판정은 파일 해시가 아니라 `model`·`contextWindow` 로 할 것.
    - `cline` 이 3.0.60 으로 드리프트했다(CFG-05 미해결). 3.0.53 기준 소스 인용은
      재검증 없이 신뢰하지 말 것.
    - 배포 팔(`flashnext-plan`, −2 마진)은 도달을 증명한 팔이 아니다.
Resume file: None
