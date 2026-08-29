# Requirements: Cline 로컬 서버

**Defined:** 2026-08-29
**Core Value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것

## v1 Requirements

### CFG — Cline 설정 정확성

- [ ] **CFG-01**: Cline 이 `flashnext` 모델을 `http://localhost:4000/v1` 로 호출한다 (`providers.json`, 비대화식 설정)
- [ ] **CFG-02**: `providers.json` 의 `models[].contextWindow` 가 `32768` 로 기록돼 있다
- [ ] **CFG-03**: `max_output_tokens` 가 상한(≤ 8192)으로 설정돼, 짧은 프롬프트에서도 `prompt + max_tokens > 32768` 로 400 이 나지 않는다
- [ ] **CFG-04**: Compact Prompt 가 켜져 있다
- [ ] **CFG-05**: `cline` 버전이 `3.0.53` 에 고정되고, 재실행해도 드리프트하지 않는다 (`CLINE_NO_AUTO_UPDATE=1`)
- [ ] **CFG-06**: `kanban` npm 패키지 버전도 고정되고, 재기동 후 확인 가능하다

### VER — 압축 검증 (Core Value)

- [ ] **VER-01**: 대화를 여러 턴에 걸쳐 누적해 26,214 토큰을 넘기는 재실행 가능한 회귀 테스트가 존재한다
- [ ] **VER-02**: 그 테스트가 **Cline UI 바가 아니라** 서버 로그의 `prompt_tokens` 또는 API `usage` 를 판정 근거로 쓴다
- [ ] **VER-03**: 테스트가 세 결과를 구분해 보고한다 — ① ~26.2k 에서 압축 발동 ② 압축 없이 32,768 에서 서버 400 ③ 그 외
- [ ] **VER-04**: 결과(② 인 경우 포함)와 그때의 대응 방침이 파일로 기록된다

### INF — 기존 스택 보정

- [ ] **INF-01**: `com.ohama.flashnext.plist` 에 `--max-num-seqs` 상한이 추가돼, 동시 요청이 OOM 대신 큐잉된다
- [ ] **INF-02**: `litellm` 이 무인증으로 LAN 에 열려 있지 않다 (`127.0.0.1` 바인딩 또는 `master_key`)
- [ ] **INF-03**: 두 변경 후에도 기존 `flashnext` 별칭 호출이 그대로 동작한다 (회귀 없음)

### SBX — 샌드박스와 저장소 화이트리스트

- [ ] **SBX-01**: 허용 저장소 목록이 단일 파일(`ALLOWED_REPOS.json`)로 선언된다
- [ ] **SBX-02**: 에이전트가 목록 밖 경로의 파일을 읽거나 쓰지 못한다
- [ ] **SBX-03**: 에이전트의 `execute_command` 도 목록 밖으로 나가지 못한다 (OS 수준 `sandbox-exec`)
- [ ] **SBX-04**: 벤치 결과 디렉터리가 샌드박스 밖에 있어, 벤치 과제가 자기 이전 프롬프트·결과를 읽을 수 없다

### SVC — 서비스화

- [ ] **SVC-01**: Kanban 이 launchd 서비스로 돌고, 재부팅 후 자동으로 올라온다
- [ ] **SVC-02**: Telegram 커넥터가 launchd 서비스로 돌고, 재부팅 후 자동으로 올라온다 (토큰 주입 자리만 비움)
- [ ] **SVC-03**: 두 서비스가 죽으면 launchd 가 되살린다 (`KeepAlive`)
- [ ] **SVC-04**: 두 서비스가 flashnext 기동 전에 떠도 재시도로 회복한다
- [ ] **SVC-05**: plist 가 `~/local-llm-settings/launchagents/` 에 등록되고 `sync.sh` 결과에 반영된다

### NET — 네트워크 접근

- [ ] **NET-01**: iPad Safari 에서 Tailscale 로 Kanban 에 접속해 카드를 보고 diff 를 리뷰할 수 있다
- [ ] **NET-02**: 같은 LAN 의 기기는 토큰 없이 Kanban 에 접근하지 못한다
- [ ] **NET-03**: 이 프로젝트의 어떤 서비스도 포트 3000 에 바인딩하지 않는다 (Funnel 노출 회피)
- [ ] **NET-04**: Telegram 커넥터가 `--allowed-user-id` 없이는 기동하지 않는다
- [ ] **NET-05**: 32K 근처 요청의 64초 대기가 Kanban 과 Telegram 양쪽에서 "작업 중"으로 보인다

### HLS — 헤드리스 래퍼

- [ ] **HLS-01**: 프롬프트를 받아 Cline 을 한 번 돌리고 NDJSON 결과를 돌려주는 래퍼 스크립트가 있다
- [ ] **HLS-02**: 래퍼가 `--auto-approve false` 를 명시한다 (CLI 기본값 `true` 에 기대지 않는다)
- [ ] **HLS-03**: 래퍼가 샌드박스 안에서만 동작한다

### BCH — 동작 검증

- [ ] **BCH-01**: cline-bench 공식 과제 5~8개를 로컬 Docker(`harbor run --env docker`)로 실행한다
- [ ] **BCH-02**: 각 실행의 **프롬프트와 결과가 모두** 파일로 저장된다
- [ ] **BCH-03**: 통과/실패와 소요 시간이 한 표로 요약된다

### DOC — 한글 사용 매뉴얼

- [ ] **DOC-01**: CLI 사용법 (기동, 태스크 실행, Plan/Act, 체크포인트)
- [ ] **DOC-02**: 웹(Kanban) 사용법 (카드, worktree, diff 리뷰, 의존 체인)
- [ ] **DOC-03**: iPad·iPhone 사용법 (Tailscale 접속, Telegram 대화, 승인/거부)
- [ ] **DOC-04**: 32K 운용 주의 (64초 대기, 26k 작업 예산, 태스크 쪼개기, ⌘+클릭 터치 불가)

## v2 Requirements

### 확장 기능

- **EXT-01**: `.clinerules` 로 프로젝트 규약 주입
- **EXT-02**: Skills 활용
- **EXT-03**: `cline schedule` 로 정기 작업
- **EXT-04**: Telegram `--hook-command` 세밀 게이팅
- **EXT-05**: 헤드리스 래퍼의 서비스화 (호출 주체가 정해진 뒤)

### 문서

- **DOC2-01**: 운영 런북 (재시작·로그·장애 대응·모델 교체)

## Out of Scope

| Feature | Reason |
|---------|--------|
| 게이트웨이 32K 거부 가드 | 모델 서버가 이미 prefill 전 HTTP 400 으로 거부함을 실측. 중복은 지연·토크나이저 불일치만 초래 |
| MCP 서버 | Compact Prompt 가 MCP 를 끈다. 32K 에서 Compact Prompt 는 필수 |
| Focus Chain | 동상 |
| 64K 이상 컨텍스트 | 64K 여유 0.10 GB, 128K 는 wired limit 초과 |
| 다중 모델 동시 기동 | Flash-Next 104 GiB. 한 번에 하나 |
| 인터넷 노출 / 공개 웹훅 | Tailscale·LAN 까지만. Discord·WhatsApp 웹훅 미사용 |
| 기존 Funnel(:8443→3000) 정리 | 사용자 결정. 대신 포트 3000 바인딩 금지로 우회 |
| Cline 업스트림 버그 수정 PR | 우회하고 기록만 한다 |
| cline-bench 전 과제 완주 | 과제당 2400s 타임아웃 × 64s TTFT. 비현실적 |
| deep mode(drafter 제거) 전환 | 재기동 20~45초가 상시 서버와 안 맞는다 |

## Traceability

로드맵 생성 시 채워진다.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (pending roadmap) | | |

**Coverage:**
- v1 requirements: 37 total
- Mapped to phases: 0
- Unmapped: 37 ⚠️

---
*Requirements defined: 2026-08-29*
