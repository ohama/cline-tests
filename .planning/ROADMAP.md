# Roadmap: Cline 로컬 서버

## Milestones

- ✅ **v1 Cline 로컬 서버** — Phases 1–8 (shipped 2026-08-31)
  아카이브: `.planning/milestones/v1-{ROADMAP,REQUIREMENTS,MILESTONE-AUDIT}.md`, `v1-phases/`
- 🚧 **v1.1 Plan/Act ↔ reasoning_effort** — Phases 9–12 (진행 중)

## Overview

v1.1 은 Cline 의 Plan/Act 모드에 `reasoning_effort` 를 묶는다. 설계·구현 계획은 이미
`docs/plan-act-reasoning-{design,implementation,diagrams}.md` 로 존재하며, 이 로드맵은 그
문서의 T1–T7 순서를 네 개의 GSD 페이즈로 재구성한 것이다. 핵심 성질은 유지된다 — 두 킬
컨디션(PRB-01, PRB-04)이 **스택을 건드리지 않는 무위험 구간(Phase 9)에서** 답이 나오고,
litellm 설정 변경(Phase 10)은 그 답이 나온 뒤에만 일어난다. 게이트에서 멈추는 것은 이
마일스톤의 정당한 출하물이다 — Phase 9 의 성공 기준은 특정 답(사고가 켜진다/누적 안 된다)이
아니라 "근거 있는 답이 나왔다"는 사실 자체다.

## Phases

**Phase Numbering:** v1 이 1–8 을 썼다. v1.1 은 9 에서 시작한다 (연속 번호, 재시작 없음).

- [ ] **Phase 9: 사전 확인 게이트 (스택 무변경)** - `:8011` 직결 무위험 실측으로 두 킬 컨디션에 근거 있는 답을 낸다
- [ ] **Phase 10: 별칭 주입과 도달 증명** - litellm 재기동을 감수하고 별칭을 추가한 뒤, 서버 로그로 도달을 증명한다
- [ ] **Phase 11: 사용 표면 — 래퍼와 A/B 게이트** - `cline-plan`/`cline-act` 짝 강제와 medium 개선 여부 판정
- [ ] **Phase 12: 문서 갱신** - 매뉴얼·고정값·설계문서를 실측 결과로 갱신

**실행 순서:** 9 → 10 → 11 → 12, **전 구간 순차 실행.** `config.json` 의
`parallelization: true` 는 이 마일스톤에 적용되지 않는다 — 게이트 순서(제약 2)와 설정 변경
의존성이 병렬화를 허용하지 않는다. Phase 10 은 Phase 9 의 두 게이트가 모두 "진행" 판정일
때만 착수한다. 어느 한쪽이 "폐기/중단"이면 마일스톤은 Phase 9 에서 종료하며, Phase 10–12 는
집행되지 않고 그 사실이 STATE.md·PROJECT.md 에 기록된다 — 이 또한 유효한 출하 결과다.

## Phase Details

### Phase 9: 사전 확인 게이트 (스택 무변경)
**Goal**: `reasoning_effort`/`enable_thinking` 이 모델 계층(`:8011` 직결)에서 실제로 무엇을
하는지, 그리고 사고 트레이스가 다음 턴 컨텍스트로 누적되는지에 대해 **스택을 하나도 바꾸지
않은 채** 근거 있는 답을 낸다.
**Depends on**: Nothing (v1.1 첫 페이즈)
**Requirements**: PRB-01, PRB-02, PRB-03, PRB-04
**Success Criteria** (관찰 가능·반증 가능 — 특정 결과가 아니라 "답이 나왔다"는 사실을 기준으로 함):
  1. `:8011` 직결에서 `reasoning_effort: medium` 요청·응답이 캡처되고, `reasoning` 필드의
     유무가 기록된다 (PRB-01, 게이트)
  2. `:8011` 직결에서 `enable_thinking: false` 요청의 HTTP 상태가 기록되고, 그 결과가
     `flashnext-act` 별칭 생성 여부의 결정 기준으로 문서화된다 (PRB-02)
  3. 미지정/medium/low/xhigh 각각의 `prompt_tokens` 가 재측정되어 VALIDATED.md 기록
     (23/21/51/63)과 대조한 표로 남는다 (PRB-03)
  4. thinking on/off 로 각 3턴 이상 실행한 두 시퀀스의 `prompt_tokens` 증가폭이 비교·기록된다
     (PRB-04, 게이트)
  5. PRB-01·PRB-04 두 게이트의 판정에 따라 "Phase 10 진행" 또는 "마일스톤 종료"가 문서에
     명시된다 — 어느 쪽이든 이 기준을 충족시킨다
**Plans**: TBD

Plans:
- [ ] 09-01: TBD (plan-phase 에서 세분화)

### Phase 10: 별칭 주입과 도달 증명
**Goal**: `flashnext-plan`(및 PRB-02 판정에 따른 `flashnext-act`) 별칭이 litellm 에 추가되고,
주입된 파라미터가 실제로 모델까지 도달했음이 HTTP 200 이 아니라 서버 측 증거로 증명된다.
**Depends on**: Phase 9 (두 게이트 모두 "진행" 판정이어야 착수)
**Requirements**: CFG-11, CFG-12, CFG-13, CFG-14, CFG-15, VRF-01, VRF-02, VRF-03
**Success Criteria** (관찰 가능·반증 가능):
  1. `~/local-llm-settings/config/litellm-config.yaml` 에 `flashnext-plan` 별칭이 추가되어
     `reasoning_effort: medium` 을 주입하며, `drop_params` 가 어디에도 설정되지 않았음이
     diff 로 확인된다 (CFG-11, CFG-14)
  2. PRB-02 판정에 따라 `flashnext-act` 별칭 생성 여부가 결정·실행되고, 그 근거(통과했다면
     생성, 통과 못 했다면 미생성과 사유)가 기록된다 (CFG-12)
  3. 기존 `flashnext` 별칭 설정이 변경 전후 바이트 단위로 동일함이 확인된다 (CFG-13, 회귀
     판정 기준선 보존)
  4. `flashnext` 와 `flashnext-plan` 에 동일 사용자 메시지를 보낸 두 요청의 서버 로그
     `prompt_tokens` 가 서로 다르며, 판정 근거가 HTTP 200 이 아니라 이 로그값이라는 점이
     스크립트 출력에 명시된다 (VRF-01, VRF-02)
  5. 위 비교가 재실행 가능한 스크립트로 저장소에 남고, `~/local-llm-settings/sync.sh` 실행
     결과에 이번 변경이 반영된다 (VRF-03, CFG-15)
**Plans**: TBD

Plans:
- [ ] 10-01: TBD (plan-phase 에서 세분화 — litellm 재기동 유지보수 창 명시 필요)

### Phase 11: 사용 표면 — 래퍼와 A/B 게이트
**Goal**: `cline-plan`/`cline-act` 래퍼가 모드와 별칭의 짝을 강제하고, `medium` 이 실제로
결과를 개선하는지 A/B 로 판정된다 — 개선이 없다는 결과도 이 게이트의 유효한 통과다.
**Depends on**: Phase 10 (래퍼가 참조할 별칭이 존재해야 함)
**Requirements**: USE-01, USE-02, USE-03
**Success Criteria** (관찰 가능·반증 가능):
  1. `cline-plan` 호출이 항상 `-p -m flashnext-plan` 인자를 포함하고, `cline-act` 호출이
     항상 act 대상 별칭(Phase 10 판정에 따라 `flashnext-act` 또는 `flashnext`)을 포함함이
     코드로 확인된다 (USE-01)
  2. `verify_config.sh` 에 모드-별칭 불일치를 주입한 네거티브 테스트가 실패를 검출하고,
     `--thinking high` 사용을 주입한 네거티브 테스트도 실패를 검출한다 (USE-02)
  3. 동일 cline-bench 과제 세트로 `flashnext` 와 `flashnext-plan` 을 각각 실행한 결과
     (정답률·소요시간)가 표로 기록되고, 개선 유무와 무관하게 래퍼 기본값 유지/되돌림 판단이
     문서에 남는다 (USE-03, 게이트)
**Plans**: TBD

Plans:
- [ ] 11-01: TBD (plan-phase 에서 세분화)

### Phase 12: 문서 갱신
**Goal**: 실측 결과(성공이든 게이트 중단이든)가 매뉴얼과 설계 문서에 반영되어, 사용자가
실제 상태를 문서만 보고 알 수 있다.
**Depends on**: Phase 11 (A/B 판정과 최종 래퍼 상태가 확정된 후에만 문서화 가능)
**Requirements**: USE-04, USE-05
**Success Criteria** (관찰 가능·반증 가능):
  1. `docs/manual/01-cli.md` 에 `cline-plan`/`cline-act` 사용법(도입되지 않았다면 그 사유)이
     반영된다 (USE-04)
  2. `docs/cline-config-pins.md` 에 별칭과 주입 파라미터가 고정값 목록으로 추가되고,
     `--thinking` 이 litellm 에서 400 이 된다는 사실이 명시된다 (USE-04)
  3. `docs/plan-act-reasoning-design.md` / `-implementation.md` 상단 상태 배지가
     "제안/계획"에서 이번 마일스톤의 실측 결과(구현됨 · 게이트 폐기 등)로 갱신된다 (USE-05)
**Plans**: TBD

Plans:
- [ ] 12-01: TBD (plan-phase 에서 세분화)

## Progress

**Execution Order:**
Phases execute in numeric order: 9 → 10 → 11 → 12 (전 구간 순차, 병렬화 없음)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|-----------------|--------|-----------|
| 1–8 | v1 | 55/55 | Complete | 2026-08-31 |
| 9. 사전 확인 게이트 | v1.1 | 0/TBD | Not started | - |
| 10. 별칭 주입과 도달 증명 | v1.1 | 0/TBD | Not started | - |
| 11. 사용 표면 — 래퍼와 A/B 게이트 | v1.1 | 0/TBD | Not started | - |
| 12. 문서 갱신 | v1.1 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-09-01 — v1.1 Plan/Act ↔ reasoning_effort*
