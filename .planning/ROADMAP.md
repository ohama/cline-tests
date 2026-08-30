# Roadmap: Cline 로컬 서버

## Overview

기존에 검증된 `litellm(:4000) → role-shim(:8011) → mlx_vlm.server(:8000)` 추론 스택은 손대지 않는다.
이 로드맵은 그 위에 Cline 에이전트 코어를 올바르게 설정하고(Core Value: 압축이 벽에 닿기 전에
도는가), 그 설정을 실측으로 검증한 뒤, 인프라 보정 → 샌드박스 → 헤드리스/서비스 표면 →
네트워크 노출 → 동작 검증 → 매뉴얼 순으로 얹는다. 검증(VER)은 첫 단계에서 끝내고, 네트워크
노출은 build 단계 중 가장 마지막에 오며, 문서화는 실제로 출하된 것을 기준으로 맨 마지막에 쓴다.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Cline 설정 + 압축 검증** - flashnext/32768/`--compaction agentic` 설정을 박고, 압축이 ~26.5k에서 실제로 도는지 실측으로 증명한다 (Core Value)
- [x] **Phase 2: 인프라 보정** - 동시성 상한과 litellm 노출 차단으로 기존 스택을 두 표면 동시 기동에 대비시킨다
- [x] **Phase 3: 샌드박스 + 저장소 화이트리스트** - 원격에서 트리거 가능한 어떤 것도 이 안전망 없이는 만들지 않는다
- [x] **Phase 4: 헤드리스 CLI 래퍼** - 설정+샌드박스가 실제로 맞물리는지 가장 싼 값으로 확인하는 단발 스모크 테스트
- [x] **Phase 5: Kanban·Telegram 서비스화** - 두 표면이 launchd 상시 서비스로 뜨고 스스로 회복한다 (아직 loopback-only)
- [ ] **Phase 6: 네트워크 노출** - Tailscale 무인증 + LAN 토큰 게이팅으로 처음 이 시스템을 localhost 밖에 연다 (build 단계 중 최후)
- [ ] **Phase 7: cline-bench 동작 검증** - 공식 과제 일부를 로컬 Docker 로 돌려 파이프라인 전체가 실제로 동작함을 증명한다
- [ ] **Phase 8: 한글 사용 매뉴얼** - 실제로 출하된 것을 기준으로 CLI·웹·iPad/iPhone 사용법을 쓴다 (최종 단계)

## Phase Details

### Phase 1: Cline 설정 + 압축 검증
**Goal**: Cline 이 `flashnext`(`:4000`)를 32768 컨텍스트로 정확히 인식하도록 설정하고, 대화가
26,214 토큰을 넘겼을 때 Cline 이 실제로 압축을 발동하는지, 아니면 발동 없이 32,768 에서 서버가
400 으로 막는지를 재실행 가능한 회귀 테스트로 실측 증명한다. 압축이 실제로 돌지 않아도 이
단계는 실패가 아니다 — "결정적 증거 + 그에 대한 대응 방침 기록"이 목표다.
**Depends on**: 없음 (첫 단계, Phase 2·3과 병렬 가능)
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04, CFG-05, CFG-06, CFG-07, VER-01, VER-02, VER-03, VER-04
**Success Criteria** (what must be TRUE):
  1. `providers.json` 에 `flashnext` 프로바이더가 `baseUrl: http://localhost:4000/v1`, **`settings` 최상위 `contextWindow: 29000`** 으로 기록돼 있고 `models[]` 가 없다 (2026-08-30 정정 — `models[]` 는 CLI 가 읽지 않는 경로)
  2. `--compaction` 모드가 명시적으로 고정돼 있고(기본값 의존 아님), Cline 설정이 `flashnext` 만 쓰며 `flashnext-codex` 를 선택할 수 없음이 확인된다
  3. `cline --version` 이 재실행 후에도 `3.0.53` 을 반환하고, 모든 관련 plist 의 `EnvironmentVariables` 에 `CLINE_NO_AUTO_UPDATE=1` 이 존재한다; `kanban` 패키지 버전도 재기동 후 동일 버전으로 확인된다
  4. 재실행 가능한 다중 턴 회귀 테스트 스크립트가 존재하고, 실행하면 서버 로그의 `prompt_tokens` 또는 API `usage`(Cline UI 바가 아님)를 근거로 ① ~26.2k 에서 압축 발동 ② 압축 없이 32,768 에서 서버 400 ③ 그 외, 셋 중 정확히 하나로 판정해 출력한다
  5. 테스트 실행 결과와 그에 대한 대응 방침이 파일로 기록돼 있다 — 결과가 ②(압축 미발동)여도 방침이 문서화돼 있으면 이 기준은 통과한다
**Plans**: 6 plans

Plans:
- [x] 01-01-PLAN.md — flashnext 프로바이더 설정: baseURL/contextWindow 32768/codex 별칭 차단 (CFG-01, CFG-02, CFG-07)
- [x] 01-02-PLAN.md — 버전 고정 + 호출 규약: cline 3.0.53 / kanban 0.1.70 / --compaction agentic (CFG-04, CFG-05, CFG-06)
- [x] 01-03-PLAN.md — 판정기(TDD): NDJSON + flashnext.err 로 ①/②/③ 삼분 판정 (VER-02, VER-03)
- [x] 01-04-PLAN.md — 회귀 하니스: 필러 생성기 + 단일 호출 툴루프 러너 + 오프라인 드라이런 (VER-01)
- [x] 01-05-PLAN.md — max_tokens 실측 후 대응책 결정·적용 (CFG-03)
- [x] 01-06-PLAN.md — 실제 회귀 실행 + 결과·대응 방침 문서화 (VER-03 보고, VER-04)

### Phase 2: 인프라 보정
**Goal**: 이미 상주 중인 `flashnext`/`litellm` 서비스를 건드리지 않던 두 위험 — 무제한 동시 배칭과
무인증 LAN 노출 — 에 대해서만 보정한다. Kanban 과 Telegram 이 동시에 뜨는 시점(Phase 5) 이전에,
그리고 네트워크가 열리는 시점(Phase 6) 이전에 반드시 끝나 있어야 한다.
**Depends on**: 없음 (Phase 1과 병렬 가능)
**Requirements**: INF-01, INF-02, INF-03
**Success Criteria** (what must be TRUE):
  1. `com.ohama.flashnext.plist` 에 `--max-num-seqs` 상한 값이 박혀 있고, 서비스 재기동 후 두 개의 동시 요청을 보내면 하나가 즉시 처리되고 다른 하나는 큐잉/지연되는 동작이 로그로 관찰된다 (OOM 이 아니다)
  2. `litellm` 설정이 `127.0.0.1` 바인딩 또는 `master_key` 중 하나로 잠겨 있어, LAN IP 에서 인증 없이 보낸 요청이 거부된다 (curl 로 재현 가능)
  3. 위 두 변경 후에도 기존 `flashnext` 별칭 호출(litellm → role-shim → mlx_vlm.server)이 정상 200 응답을 그대로 반환한다
**Plans**: 4 plans

Plans:
- [x] 02-01-PLAN.md — Phase-2 안전 툴킷(config.env/preflight/restart_service/verify_queueing) + 변경 전 무캡 동시성 베이스라인 (라이브 무변경)
- [x] 02-02-PLAN.md — INF-01: flashnext plist 에 `--max-num-seqs` 적용 + 재기동 + 로그 타이밍으로 큐잉 증명 (라이브 재기동 승인 체크포인트 포함)
- [x] 02-03-PLAN.md — INF-02: litellm plist 에 `--host 127.0.0.1` 적용 + 재기동 + LAN 거부/루프백 200 증명
- [x] 02-04-PLAN.md — INF-03: 전체 체인 회귀 게이트 + `sync.sh` 미러 반영 + `docs/infra-hardening.md` 기록

### Phase 3: 샌드박스 + 저장소 화이트리스트
**Goal**: 원격에서 트리거될 수 있는 어떤 것(헤드리스 래퍼, Kanban, Telegram)도 이 안전망이
갖춰지기 전에는 실제 저장소에 연결되지 않는다.
**Depends on**: 없음 (Phase 1·2와 병렬 가능)
**Requirements**: SBX-01, SBX-02, SBX-03, SBX-04
**Success Criteria** (what must be TRUE):
  1. `ALLOWED_REPOS.json` 파일이 존재하고 허용 저장소 경로 목록을 담고 있다
  2. 화이트리스트 밖 경로에 대한 파일 읽기/쓰기 시도가 실제로 실패한다 (직접 시도로 재현 가능)
  3. 화이트리스트 밖 경로를 대상으로 한 `execute_command` 실행이 `sandbox-exec` 에 의해 차단된다
  4. 벤치 결과 디렉터리가 샌드박스 경로 밖에 위치해, 샌드박스 안에서 실행되는 명령이 그 디렉터리의 내용을 읽을 수 없다
**Plans**: 4 plans

Plans:
- [x] 03-01-PLAN.md — ALLOWED_REPOS.json(SBX-01) + realpath 정규화 SBPL 생성기 + run_sandboxed.sh 래퍼
- [x] 03-02-PLAN.md — 영구 회귀 픽스처 + in-process/subprocess 프로브 + false-pass 판별 단언 헬퍼
- [x] 03-03-PLAN.md — verify_sandbox.sh 상시 게이트: 네 성공 기준 실증 + 음성 대조군 (SBX-02/03/04)
- [x] 03-04-PLAN.md — cline 스모크 테스트 1회(예산) + docs/sandbox-whitelist.md + phase-close 재검증

### Phase 4: 헤드리스 CLI 래퍼
**Goal**: Phase 1(설정)과 Phase 3(샌드박스)이 실제로 함께 맞물려 동작하는지 가장 싸고 빠르게
확인하는 단발 스모크 테스트. 서비스화는 이번 마일스톤에서 하지 않는다.
**Depends on**: Phase 1, Phase 3
**Requirements**: HLS-01, HLS-02, HLS-03
**Success Criteria** (what must be TRUE):
  1. 래퍼 스크립트에 프롬프트를 넣어 한 번 실행하면 NDJSON 형식의 결과가 반환된다
  2. 래퍼의 실행 커맨드/코드에 `--auto-approve false` 가 명시적으로 박혀 있다 (CLI 기본값 `true` 에 기대지 않음 — grep 으로 확인 가능)
  3. 샌드박스 밖 경로를 건드리려는 프롬프트로 실행하면 Phase 3 의 화이트리스트에 의해 거부된다
**Plans**: 4 plans

Plans:
- [x] 04-01-PLAN.md — NDJSON 결과 분류기 + fixtures + 테스트 + phase-04/config.env (오프라인, cline 호출 0회)
- [x] 04-02-PLAN.md — 출하용 헤드리스 래퍼 `run_headless.sh` (`--auto-approve false` 고정) + 라이브 스모크 1회 (기준 1·2)
- [x] 04-03-PLAN.md — 기준 3 증명 게이트 `verify_sandbox_via_cline.sh` 작성 (TEST-ONLY `--auto-approve true`, 오프라인 자체검증)
- [x] 04-04-PLAN.md — 기준 3 라이브 1회 + `docs/headless-wrapper.md` + phase-close 게이트 스윕

### Phase 5: Kanban·Telegram 서비스화
**Goal**: 두 표면이 launchd 상시 서비스로 뜨고, 죽으면 스스로 복구하며, flashnext 가 아직 뜨지
않은 상태로 부팅돼도 크래시루프 없이 재시도로 회복한다. 아직 loopback-only 이며 네트워크에는
열리지 않는다.
**Depends on**: Phase 1, Phase 2, Phase 3
**Requirements**: SVC-01, SVC-02, SVC-03, SVC-04, SVC-05
**Success Criteria** (what must be TRUE):
  1. `launchctl print gui/$UID/<label>` 로 Kanban·Telegram 두 서비스 라벨이 모두 조회되고 상태가 running 이다; 재부팅 후에도 동일하게 확인된다
  2. 두 서비스 중 하나를 강제 종료(`kill`)하면 launchd 가 `KeepAlive` 로 다시 살려낸다
  3. flashnext 서비스를 잠시 내린 상태에서 두 서비스를 기동해도 크래시루프 없이 재시도를 반복하다 flashnext 가 뜨면 정상 연결된다
  4. 두 plist 파일이 `~/local-llm-settings/launchagents/` 에 존재하고, `sync.sh` 실행 결과에 반영돼 있다
**Plans**: 7 plans

Plans:
- [x] 05-01-PLAN.md — 두 launchd 래퍼 스크립트와 공유 config (SVC-03/04 메커니즘)
- [x] 05-02-PLAN.md — check_versions.sh Check C 에 KANBAN_NO_AUTO_UPDATE 추가 + restart_service.sh 포트 없는 라벨 일반화
- [x] 05-03-PLAN.md — 등록 전 실증: dead-port SVC-04, 빈 토큰 idle 무-spin, 포트 인벤토리(Open Question 2)
- [x] 05-04-PLAN.md — com.ohama.kanban 등록/기동/KeepAlive 부활/bootout 회수 (SVC-01, SVC-03)
- [x] 05-05-PLAN.md — com.ohama.telegram-connect 등록(토큰 슬롯 빈 채) + 두 서비스 동시 기동 검증 (SVC-02, SVC-03)
- [x] 05-06-PLAN.md — sync.sh LABELS 편집 + 미러 반영 (SVC-05) + Phase 6 용 상시 게이트 verify_services.sh
- [x] 05-07-PLAN.md — docs/services.md + 전체 게이트 스윕 + 재부팅 검증 방식 결정 체크포인트

### Phase 6: 네트워크 노출
**Goal**: Tailscale 무인증 + LAN 토큰 게이팅으로, 처음으로 이 시스템을 이 Mac 의 셸 밖에서
접근 가능하게 연다. 포트 3000 에는 어떤 컴포넌트도 절대 바인딩하지 않는다. build 단계 중
반드시 최후에 온다.
**Depends on**: Phase 2, Phase 5
**Requirements**: NET-01, NET-02, NET-03, NET-04, NET-05
**Success Criteria** (what must be TRUE):
  1. iPad Safari 에서 Tailscale 주소(`https://ohama-2.tail318f12.ts.net` 계열이 아닌 Kanban 전용 주소)로 접속해 카드 목록을 보고 diff 를 리뷰할 수 있다
  2. 같은 LAN(비-Tailscale IP)에서 토큰 없이 Kanban 접근을 시도하면 거부된다
  3. `lsof -i :3000` 결과, 이 프로젝트가 만든 어떤 서비스도 포트 3000 을 점유하지 않는다
  4. `--allowed-user-id` 없이 Telegram 커넥터를 기동하면 즉시 기동 실패한다
  5. 32K 근처 요청 중 Kanban 카드와 Telegram 대화 양쪽 모두에서 "작업 중" 상태가 시각적으로 확인된다
**Plans**: 6 plans

Plans:
- [ ] 06-01-PLAN.md — 변경 전 베이스라인(4개 상시 게이트 + 네트워크 인벤토리) + Phase 6 상수 고정(8444) + 기존 Tailscale 핸들러 3개 동결
- [ ] 06-02-PLAN.md — NET-04: run_telegram_service.sh 래퍼 프리플라이트 가드 + 실제 기동 실패 실증 후 원복
- [ ] 06-03-PLAN.md — setup_tailscale_serve.sh + verify_network.sh 오프라인 저작·자가검증(음성 대조군), 네트워크 무변경
- [ ] 06-04-PLAN.md — 네트워크 개방 1회(serve :8444 → 127.0.0.1:3484) + NET-01 서버측/NET-02/NET-03 실증 + 사후 게이트 스윕
- [ ] 06-05-PLAN.md — NET-05 서버측 증거 + 실토큰 Telegram 라이브 트라이얼 결정 체크포인트
- [ ] 06-06-PLAN.md — docs/network-exposure.md + iPad 체크리스트 + phase-close 게이트 스윕/criteria.md

### Phase 7: cline-bench 동작 검증
**Goal**: cline-bench 공식 과제 일부를 로컬 Docker 로 실행해, 압축/설정(Phase 1)과 샌드박스
(Phase 3) 위에서 전체 파이프라인이 실제로 동작함을 증명하고 기록을 남긴다.
**Depends on**: Phase 1, Phase 3 (Phase 4·5·6과 병렬 가능)
**Requirements**: BCH-01, BCH-02, BCH-03
**Success Criteria** (what must be TRUE):
  1. `harbor run --env docker` 로 cline-bench 공식 과제 5~8개가 로컬 Docker 에서 실행된 결과 디렉터리가 존재한다
  2. 각 실행 디렉터리에 프롬프트 원문과 결과가 모두 파일로 저장돼 있다
  3. 통과/실패와 소요 시간을 정리한 표가 파일로 존재한다
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

### Phase 8: 한글 사용 매뉴얼
**Goal**: 실제로 출하된 것을 기준으로 CLI·웹(Kanban)·iPad/iPhone 사용법과 32K 운용 주의사항을
문서화한다. 운영 런북은 별도 문서(v2 범위)로 제외한다.
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, Phase 6, Phase 7 (전체 완료 후)
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04
**Success Criteria** (what must be TRUE):
  1. CLI 사용법 문서에 기동·태스크 실행·Plan/Act·체크포인트 절차가 실제 명령어와 함께 기술돼 있다
  2. 웹(Kanban) 사용법 문서에 카드·worktree·diff 리뷰·의존 체인 절차가 기술돼 있다
  3. iPad·iPhone 사용법 문서에 Tailscale 접속과 Telegram 대화/승인·거부 절차가 기술돼 있다
  4. 32K 운용 주의 문서에 64초 대기, 26k 작업 예산, 태스크 쪼개기, ⌘+클릭 터치 불가, 그리고 Phase 1 VER 실측 결론이 반영돼 있다
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

## Progress

**Execution Order:**
Phase 1·2·3 은 서로 병렬 가능(의존성 없음). Phase 4·5 는 1·2·3 완료 후. Phase 6 은 2·5 완료 후
(build 단계 중 최후). Phase 7 은 1·3 완료 후 4·5·6 과 병렬 가능. Phase 8 은 전체 완료 후 최종 단계.

순번 기준 실행 순서: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
(config.json 의 `parallelization: true` 에 따라 1·2·3, 그리고 4·5 완료 후 6과 7은 각각 병렬 착수 가능)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Cline 설정 + 압축 검증 | 6/6 | ✓ Complete | 2026-08-29 |
| 2. 인프라 보정 | 4/4 | ✓ Complete | 2026-08-30 |
| 3. 샌드박스 + 저장소 화이트리스트 | 4/4 | ✓ Complete | 2026-08-30 |
| 4. 헤드리스 CLI 래퍼 | 4/4 | ✓ Complete | 2026-08-30 |
| 5. Kanban·Telegram 서비스화 | 7/7 | ✓ Complete | 2026-08-30 |
| 6. 네트워크 노출 | 0/6 | Planned | - |
| 7. cline-bench 동작 검증 | 0/TBD | Not started | - |
| 8. 한글 사용 매뉴얼 | 0/TBD | Not started | - |
