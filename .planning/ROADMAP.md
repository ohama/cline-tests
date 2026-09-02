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

- [x] **Phase 9: 사전 확인 게이트 (스택 무변경)** - `:8011` 직결 무위험 실측으로 두 킬 컨디션에 근거 있는 답을 낸다
- [x] **Phase 10: 별칭 주입과 도달 증명** - litellm 재기동을 감수하고 별칭을 추가한 뒤, 서버 로그로 도달을 증명한다
- [ ] **Phase 11: 사용 표면 — 래퍼와 A/B 게이트** - `cline-plan`/`cline-act` 짝 강제와 medium 개선 여부 판정
- [ ] **Phase 12: 문서 갱신** - 매뉴얼·고정값·설계문서를 실측 결과로 갱신

**실행 순서:** 9 → 10 → 11 → 12, **전 구간 순차 실행.** `config.json` 의
`parallelization: true` 는 이 마일스톤에 적용되지 않는다 — 게이트 순서(제약 2)와 설정 변경
의존성이 병렬화를 허용하지 않는다. Phase 10 은 Phase 9 의 게이트가 "진행" 판정일
때만 착수한다. **2026-09-01: 판정 완료 — Phase 10 진행.** 어느 한쪽이 "폐기/중단"이면 마일스톤은 Phase 9 에서 종료하며, Phase 10–12 는
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
  5. 게이트 판정이 문서에 명시된다 — "Phase 10 진행" · "마일스톤 종료" · "판정 보류" 중 하나.
     어느 쪽이든 이 기준을 충족시킨다
     <br>※ **2026-09-01 변경.** 킬 컨디션은 이제 **PRB-04 하나**다. 별칭이 `enable_thinking: true` 를
     함께 주입하도록 바뀌어(CFG-11), PRB-01 이 부정이어도 조합이 사고를 켜므로 종료 사유가 아니다.
     PRB-01 은 "effort 하나로 충분한가"에 답하는 진단 항목으로 남는다
**Plans**: 4 plans
**Status**: ✅ 완료 (2026-09-01) — 검증 32/32, `09-VERIFICATION.md`
**판정**: **Phase 10 진행** — `phase-09/GATE-VERDICT.md` (사람 확인 완료)
  - PRB-04 (🔴 유일한 킬 컨디션): **양성.** 통제 리플레이 16/16 이 `delta=0`,
    `prompt_tokens=46` 고정. 두 엔드포인트 · 두 필드명(`reasoning_content`/`reasoning`) ·
    합성 1,380자 및 실제 트레이스 2,497자 전부. 길이 임계 효과 없음
  - PRB-01 (진단): **양성.** `medium` 단독 → `reasoning` 179자, 미지정 대조군 → 0자
  - PRB-02: `enable_thinking:false` 는 거부되지 않음(200). `true` 대조군이 실제 적용을 입증 → CFG-12
  - PRB-03: 6갈래 스윕 A/B 완전 일치. 델타는 두 선행 데이터셋과 정확히 일치
  - **스택 무변경 확인**: 전 실행에서 PID·설정 해시 불변, `verify_config.sh` OK, `cline` 미호출
**Phase 10 이 물려받는 것**: reach 프로브는 `low`(+28)/`xhigh`(+40) 사용 — `medium`·`et-medium`
  의 −2 마진은 너무 좁다. CFG-16 질문은 좁혀짐(§3.2). VRF-04(실제 cline 검증)는 미이행 이월

Plans:
- [x] 09-01-PLAN.md — 프로브 안전 외피(PID·설정 해시·gpu-stream 플레이크 판별) 구축 후 PRB-01·PRB-02 독립 재현
- [x] 09-02-PLAN.md — PRB-03 `prompt_tokens` 오라클 재측정 및 Phase 10 도달 프로브 값 선언
- [x] 09-03-PLAN.md — PRB-04 재현(합성 + 실제 xhigh 트레이스) 및 reasoning-history 소스 오탐 정정 기록
- [x] 09-04-PLAN.md — 재현값 대 리서치값 대조, 두 게이트 판정, "Phase 10 진행"/"마일스톤 종료" 판정문 작성

### Phase 10: 별칭 주입과 도달 증명
**Goal**: `flashnext-plan`(및 PRB-02 판정에 따른 `flashnext-act`) 별칭이 litellm 에 추가되고,
**그것이 실제 `cline` CLI 실행에서 작동함이 관측되며,**
주입된 파라미터가 실제로 모델까지 도달했음이 HTTP 200 이 아니라 서버 측 증거로 증명된다.
**Depends on**: Phase 9 (두 게이트 모두 "진행" 판정이어야 착수)
**Requirements**: CFG-11, CFG-12, CFG-13, CFG-14, CFG-15, CFG-16, CFG-17, VRF-01, VRF-02, VRF-03, VRF-04
**Success Criteria** (관찰 가능·반증 가능):
  1. **litellm 이 실제로 읽는 설정 파일** `/Users/ohama/agent-stack/litellm/config.yaml` 에
     `flashnext-plan` 별칭이 추가되어
     **`enable_thinking: true` 와 `reasoning_effort: medium` 을 함께** 주입하며, `drop_params` 가
     어디에도 설정되지 않았음이 diff 로 확인된다 (CFG-11, CFG-14)
     <br>※ 2026-09-01 변경 — effort 단독 주입에서 두 파라미터 주입으로. `enable_thinking` 기본값이
     `false` 라 effort 만으로 사고가 켜진다는 보장이 없다 (VALIDATED.md §4 권장이 둘을 함께 쓴다)
  1b. 🔴 그 **조합이 실제로 `reasoning` 을 만드는 것**이 `:8011` 과 `:4000` 양쪽 curl 로 확인된다.
     이 조합은 이 스택에서 측정된 적이 없다 — 안 되면 별칭 정의를 고친다 (CFG-16)
  2. PRB-02 판정에 따라 `flashnext-act` 별칭 생성 여부가 결정·실행되고, 그 근거(통과했다면
     생성, 통과 못 했다면 미생성과 사유)가 기록된다 (CFG-12)
  3. 기존 `flashnext` 별칭 설정이 변경 전후 바이트 단위로 동일함이 확인된다 (CFG-13, 회귀
     판정 기준선 보존)
  4. `flashnext` 와 `flashnext-plan` 에 동일 사용자 메시지를 보낸 두 요청의 서버 로그
     `prompt_tokens` 가 서로 다르며, 판정 근거가 HTTP 200 이 아니라 이 로그값이라는 점이
     스크립트 출력에 명시된다 (VRF-01, VRF-02)
  5. 위 비교가 재실행 가능한 스크립트로 저장소에 남고, `~/local-llm-settings/sync.sh` 실행
     결과에 이번 변경이 반영된다 (VRF-03, CFG-15)
     <br>※ **2026-09-01 정정.** `~/local-llm-settings/config/litellm-config.yaml` 은 **생성된
     사본**이다 — launchd plist 가 `--config /Users/ohama/agent-stack/litellm/config.yaml` 를
     넘긴다(확인함). 사본을 고치면 litellm 에 아무 영향이 없다. 원본을 고치고 `sync.sh` 로
     사본을 갱신하는 순서다.
     <br>※ **별칭 정의 정정.** 새 별칭은 `openai/` 가 아니라 **`hosted_vllm/`** 접두사를 써야 한다.
     설치된 litellm 1.86.1 에서 `openai` 는 `reasoning_effort` 를 지원 목록에 넣지 않아
     주입해도 400 이 나고, `hosted_vllm` 은 명시적으로 허용한다
     (`llms/hosted_vllm/chat/transformation.py:92`, 직접 확인함). 기존 `flashnext` 별칭은
     건드리지 않으므로 회귀 기준선은 보존된다.
  6. 🔴 **실제 `cline` CLI 로 한 번 이상 실행하여**, `CLINE_NO_AUTO_UPDATE=1 cline -m flashnext-plan
     --json "<짧은 프롬프트>"` 의 NDJSON 스트림에 `reasoning` 이 실제로 나타나는지가 관측·기록된다.
     같은 프롬프트를 `-m flashnext`(또는 `flashnext-act`)로 돌린 대조군과 나란히 남긴다 (VRF-02)
     <br>※ **2026-09-01 추가.** curl 로 증명되는 것은 *게이트웨이가 파라미터를 전달한다*는 사실뿐이고,
     *Cline 이 그 경로로 실제 사고를 한다*는 것은 별개다. v1 에서 `providers.json` 에 값이 기록돼
     있는데도 CLI 가 그 칸을 읽지 않아 이틀을 쓴 전례가 있다 — "설정이 존재한다"와 "작동한다"를
     같은 것으로 취급하지 않기 위한 기준이다.
     <br>※ 관측 결과가 **부정적이어도 이 기준은 충족된다** — 관측하고 기록하는 것이 요구사항이다.
  7. deprecated `qwen-*` 별칭 6개가 제거되고, `flashnext`·`flashnext-codex` 는 보존됨이
     diff 로 확인된다 (CFG-17)
     <br>※ **2026-09-01 사용자 지시로 추가.** 삭제 조건은 설정 파일 주석이 스스로 정한 것이고
     ("한동안 로그를 보고 쓰이지 않으면 지운다"), 로그로 충족을 확인했다 — 현 litellm 기동 이후
     `qwen-*` 요청 **0건** 대 `flashnext` **163건**. 과거 요청은 전부 마지막 재기동 이전이며
     대부분 404·`No deployments available` 실패다.
     <br>※ 삭제는 재기동이 있어야 반영되므로 **이 페이즈의 유지보수 창에 합류**시킨다 — 따로
     하면 Kanban·Telegram 이 두 번 끊긴다. 같은 백업·롤백·검증 사다리를 공유한다.
     <br>※ 삭제 범위 라이브 설정 **34–50행**. 남는 1–33행(`flashnext` 22행,
     `flashnext-codex` 29–33행)은 CFG-13 의 바이트 동일 검사 대상으로 유지된다.
**Plans**: 6 plans (6 waves, 전 구간 직렬 — 재기동 옆에서는 아무것도 측정할 수 없고
모델이 `--max-num-seqs 1` 이라 동시 요청도 불가)
**Status**: ✅ 완료 (2026-09-02) — 검증 7/7, `10-VERIFICATION.md`
  - **별칭 5개 라이브** — `flashnext`(불변) · `flashnext-codex`(불변) · `flashnext-plan` ·
    `flashnext-act` · `flashnext-reach-xhigh`. deprecated `qwen-*` 6개 제거(CFG-17)
  - **도달 증명** — 서버 로그 `prompt_tokens` 기준(HTTP 200 아님). `flashnext`→
    `flashnext-reach-xhigh` **+40**, `flashnext-plan`→`reach-xhigh` **+42**, 오라클과 정확히 일치.
    접두사 교란은 같은 본문 3쌍 전부 **델타 0** 으로 배제됨
  - **CFG-16 양성** — 출하 조합이 별칭 경유로 284자 `reasoning` 생성(클라이언트는 파라미터 미전송)
  - **VRF-04 양성** — 실제 `cline` 실행에서 `flashnext-plan` 스트림에 사고 이벤트 다수,
    `flashnext` 대조군 **0건**. "설정이 존재한다"와 "작동한다"가 처음으로 같아짐
  - **스택** — `flashnext`/`role-shim` PID 불변, `verify_config.sh` OK, 사본 동기 완료
**⚠ 증명 강도 고지** (`phase-10/PHASE-10-FINDINGS.md` §4):
  - **배포 팔(−2)은 도달을 증명한 팔(+42)이 아니다.** 좁은 마진은 우발적 프롬프트 드리프트에 취약
  - **재기동 B 중단은 미측정** — 샘플러가 기록하려던 connection-refused 로 `set -e` 에 죽음.
    A 의 ~7초로 메우지 않음
  - **`cline` 3.0.53 → 3.0.60 드리프트** — Phase 9 소스 인용은 3.0.60 에서 미재검증
  - **`cline -m` 이 `providers.json` 을 쓴다**(`updatedAt`). `model`·`contextWindow` 는 불변.
    제약을 해시가 아니라 이 두 값으로 정정함 → Phase 11 이 물려받음
  - 이 페이즈는 **아무것도 관측하지 않으면서 통과를 보고한 계측기 5개**를 만들었고 전부
    종료 코드가 아니라 실제 출력을 읽어 잡았다 — 방법론상 가장 값진 발견

Plans:
- [x] 10-01-PLAN.md — 후보 설정 작성(신규 별칭 추가 **+ CFG-17 deprecated 6개 삭제**) + 설치 전
      검증 사다리(스크래치 포트 4010 부팅)와 그 음성 대조군
- [x] 10-02-PLAN.md — 백업·기준선·롤백 리허설(변경 전에 실행) + 변경 브리핑 + 🔴 사람 체크포인트
- [x] 10-03-PLAN.md — 🔴 **유지보수 창(이 페이즈에서 유일하게 litellm 재기동 가능).**
      무변경 설정으로 리허설 재기동 → 설치 → 재기동 → 다표본 헬스 → CFG-13/14 증거
- [x] 10-04-PLAN.md — CFG-16 사고 내용 확인(:8011/:4000) + VRF-01/02/03 도달 증명 스크립트
      + `hosted_vllm/` 접두사 교란 해소
- [x] 10-05-PLAN.md — VRF-04: 실제 `cline` 실행과 대조군, NDJSON 관측 기록
- [x] 10-06-PLAN.md — CFG-15 `sync.sh` 반영·커밋 + 요구사항/기준 전체 증거 매핑과 약한 증명 고지

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
**Plans**: 7 plans (6 waves, 전 구간 직렬 — 마일스톤 규칙이 병렬화를 허용하지 않고,
모델이 `--max-num-seqs 1` 이라 A/B 요청도 순차여야 한다)
<br>※ **2026-09-02 계획 시 확정된 범위 결정 3건** (근거는 `11-RESEARCH.md`, 상세는 각 플랜):
  - **`--thinking` 은 3.0.60 에 실재한다.** CFG-11 괄호("Cline 은 `--thinking` 을 쓰지 않는다")는
    거짓이 됐고, 클라이언트가 보낸 `reasoning_effort` 는 litellm kwarg 병합 순서상 별칭 주입을
    **덮어쓴다.** 따라서 래퍼는 `--thinking`/`-m`/`-P` 통과를 **능동적으로 거부**한다
    (거부 목록이 아니라 **화이트리스트 외 전부 거부** — CFG-05 드리프트로 내일 새 플래그가
    생겨도 자동으로 막히도록)
  - **기준 2 의 네거티브 테스트는 실제 뮤턴트로 증명한다.** 검사가 존재한다는 주장이 아니라,
    래퍼를 실제로 망가뜨려 `verify_config.sh` 가 비영 종료하는 것을 관측한다 (Phase 10 이
    아무것도 관측하지 않으면서 통과를 보고한 계측기 5개를 만든 전례)
  - 🔴 **기준 3 의 과제 세트는 cline-bench 가 아니다.** Phase 07 실측(4개 시도, **0개 통과**,
    3개가 21K–37K 에서 `fail-context`, `easy` 두 개 모두 포함)과 `medium` 의 프롬프트 효과
    **−2 토큰**을 근거로, cline-bench A/B 는 사고가 아니라 압축-프루닝 결함을 측정하게 된다.
    대체 세트(단발턴·도구 불필요·기계 채점 8과제)를 쓰고, **왜 공식 벤치를 비켜갔는지와 무엇이
    이 결정을 뒤집는지**를 `phase-11/AB-TASKSET.md` §1 에 기록한다
<br>※ **A/B 는 래퍼가 아니라 별칭을 비교한다** — `cline-plan` 의 `-p` 는 Cline 자체 모드 플래그로
  도구 가용성을 바꾸므로, 래퍼끼리 비교하면 사고 효과와 도구 효과가 교란된다. 세 팔:
  `flashnext`(대조) · `flashnext-act`(접두사 통제) · `flashnext-plan`(피험). 판정 규칙과
  반증 조건은 **데이터를 보기 전에** `AB-PROTOCOL.md` §5 에 등록한다
<br>※ **라이브 요청 예산은 각 플랜이 스스로 상한을 강제한다** (10-04 가 17 선언에 48 발사한 전례).
  선언: 11-04 ≤14, 11-05 ≤10, 11-06 = 사람이 승인한 상한. 실제 측정치를 상한 옆에 보고한다
<br>※ **사람 체크포인트 2개** — 11-05(주 A/B 예산 승인)와 11-07(유지/되돌림 판정 비준.
  사용자가 실제로 쓰는 도구의 기본값이 바뀌는 결정이므로 조용히 내리지 않는다)

Plans:
- [ ] 11-01-PLAN.md — `cline-plan`/`cline-act` 래퍼(단일 출처 별칭 + 화이트리스트 외 전부 거부)와
      스텁 argv 캡처 검증, 누출 뮤턴트로 검증기 자체를 반증
- [ ] 11-02-PLAN.md — cline-bench 배제 결정 기록 + 대체 과제 8개(정답은 실행으로 도출)와
      4상태 채점기(정답/오답/무응답/무출력), 픽스처로 채점기가 실패할 수 있음을 증명
- [ ] 11-03-PLAN.md — `verify_config.sh` 에 짝·`--thinking` 검사 편입(종료 코드 3)과
      뮤턴트 7종 CAUGHT + 정상/되돌림 통제 2종 PASS, 기존 호출자 하위 호환 증거
- [ ] 11-04-PLAN.md — Phase 11 안전 외피(providers.json 은 해시가 아니라 `model`·`contextWindow`
      로 판정) + 미해결 리서치 항목 1·2·3 실측(`--thinking high` 실제 실패 모드, 3.0.60 의
      `max_tokens`, `-m` 반복 호출의 영향)
- [ ] 11-05-PLAN.md — A/B 프로토콜(팔·공정성 통제·크기 규칙·사전 등록 판정 규칙) + 파일럿 6셀,
      🔴 사람 체크포인트(주 A/B 예산 승인)
- [ ] 11-06-PLAN.md — 승인된 크기로 주 A/B 실행(재개 가능·상한 강제) + `AB-RESULTS.md`
      (전 셀 표 · 4범주 집계 · 무효 조건 점검 · 규칙의 기계적 출력)
- [ ] 11-07-PLAN.md — 🔴 사람 체크포인트(유지/되돌림 비준) + `wrapper.env` 한 줄 적용과 재검증
      + `PHASE-11-FINDINGS.md`(요구사항·기준 매핑과 증명 강도 고지)

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
| 9. 사전 확인 게이트 | v1.1 | 4/4 | Complete | 2026-09-01 |
| 10. 별칭 주입과 도달 증명 | v1.1 | 6/6 | Complete | 2026-09-02 |
| 11. 사용 표면 — 래퍼와 A/B 게이트 | v1.1 | 0/7 | In progress | - |
| 12. 문서 갱신 | v1.1 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-09-01 — v1.1 Plan/Act ↔ reasoning_effort*
