# Requirements Archive: v1 Cline 로컬 서버

**Archived:** 2026-08-31
**Status:** ✅ SHIPPED (기술부채 수용)

v1 의 요구사항 명세 아카이브. 현재 요구사항은 다음 마일스톤에서 새로 정의된다.
누적 기록은 PROJECT.md 의 Validated 절이 담당한다.

---

# Requirements: Cline 로컬 서버

**Defined:** 2026-08-29
**Core Value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것

## v1 Requirements

### CFG — Cline 설정 정확성

- [ ] **CFG-01**: Cline 이 `flashnext` 모델을 `http://localhost:4000/v1` 로 호출한다 (`providers.json`, 비대화식 설정)
- [x] **CFG-02**: `providers.json` 의 **`settings` 최상위** `contextWindow` 가 `29000` 으로 기록돼 있고,
  `models[]` 는 존재하지 않는다
  <br>※ **2026-08-30 정정** — 원래 문구는 `models[].contextWindow: 32768` 이었으나, `models[]` 는
  VS Code 용 per-model override 경로이고 CLI 는 읽지 않음이 소스로 확인됨
  (`provider-settings.ts:150/266`). 값이 29000 인 이유는 오버슈트(약 3,100 토큰) 흡수.
  근거: `docs/32k-compaction-policy.md` §2·§4, `phase-01/results/exp-verify29k/`
- [ ] **CFG-03**: Cline 이 실제로 보내는 `max_tokens` 값이 서버 로그로 확인되고, `prompt + max_tokens > 32768` 로
  400 이 나지 않도록 상한이 적용된다 — providers.json 의 `maxTokens` 가 먹지 않는 것으로 관찰됐으므로
  **먼저 실측하고 대응책을 정한다**
- [ ] **CFG-04**: `--compaction` 모드가 명시적으로 고정돼 있다 (`agentic|basic|off` 중 택일, 기본값에 기대지 않음)
  <br>※ 당초의 "Compact Prompt" 는 VS Code 확장 전용이며 CLI 에 존재하지 않음이 확인돼 재정의됨 (2026-08-29)
- [ ] **CFG-07**: Cline 설정이 `flashnext` 만 쓰고 `flashnext-codex` 별칭을 선택할 수 없다
  <br>※ 조사 중 codex 별칭 호출이 mlx_vlm.server 를 죽여 29초 다운이 실제 발생
- [ ] **CFG-05**: `cline` 버전이 `3.0.53` 에 고정되고, 재실행해도 드리프트하지 않는다 (`CLINE_NO_AUTO_UPDATE=1`)
  <br>※ **2026-08-31 마일스톤 감사 정정 — 오늘 기준 충족되지 않는다.** 호스트 전역 설치는
  `3.0.60` 이다(`/opt/homebrew/lib/node_modules/cline/package.json` 실측). `CLINE_NO_AUTO_UPDATE=1`
  은 이 자기-업데이트를 **막지 못한다** — 프로젝트 내내 반복 재현됐다. 추적 표가 `Complete` 로
  돼 있던 것은 Phase 1 이 검증자를 거치지 않은 유일한 페이즈였기 때문이며, 이번 감사에서 정정했다.
  복구 방법: 실행 중인 cline/kanban 프로세스가 없음을 `ps` 로 확인한 뒤 `npm install -g cline@3.0.53`.
  주의: 컨테이너 측 벤치 핀(3.0.53)은 별도 설치라 영향받지 않는다.
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
- [ ] **NET-05**: 긴 대기가 Kanban 과 Telegram 양쪽에서 상태로 보인다 — ① 프리필 대기(32K 근처 64초)
  ② **압축 중**(요약 호출이 추가 지연을 만든다)
  <br>※ 2026-08-30 정정 — 압축이 정상 작동하므로 "죽은 작업" 상태가 아니라 "압축 중" 상태가 필요하다

### HLS — 헤드리스 래퍼

- [ ] **HLS-01**: 프롬프트를 받아 Cline 을 한 번 돌리고 NDJSON 결과를 돌려주는 래퍼 스크립트가 있다
- [ ] **HLS-02**: 래퍼가 `--auto-approve false` 를 명시한다 (CLI 기본값 `true` 에 기대지 않는다)
- [ ] **HLS-03**: 래퍼가 샌드박스 안에서만 동작한다

### BCH — 동작 검증

- [ ] **BCH-01**: cline-bench 공식 과제 5~8개를 로컬 Docker(`harbor run --env docker`)로 실행한다
  <br>※ 2026-08-31 정정 — gap-closure(07-06~09) 로 주입 메커니즘은 고쳐져 모델 도달까지
  실측 증명됐지만(3개 과제, 32K 천장에서 거부), 실제 실행된 고유 과제 수는 4개로 여전히
  5~8 하한에 못 미친다. `not_met` 그대로.
  <br>※ 2026-08-31 추가(gap-closure 2, 07-11~07-16) — 그 3개 과제가 32K 천장에서 거부된
  근인을 규명했다: 하나가 아니라 최소 두 가지 서로 다른 메커니즘(`telegram-plugin-refactor`:
  압축이 프루닝 없이 발동한 직후 단일 tool 결과가 벽을 5,435 토큰 초과; `v-edit-workspace-tests`:
  압축이 한 번 발동한 뒤 4턴 연속 스킵되며 서서히 기어올라 123 토큰 초과;
  `discord-trivia-approval-keyerror`: 459 토큰 초과, 메커니즘 미측정). `fail-context` 를
  매기던 분류기(`\b400\b` 단순 매치)를 위양성·위음성 모두 확인 후 수리했고, 저장된 5개
  실행 인스턴스를 오프라인 재분류한 결과 판정은 **0건 변경** — 기존 판정이 정확했음을
  재확인했다. `settings.contextWindow` 는 무변경(`SELECTION: doc-only`) — 압축이 실제로는
  프루닝하지 않는다는 확인된 결함이 있으므로 그 값을 조정해도 근본 원인은 닫히지 않는다는
  판단이다. 이 조사는 과제 실행 개수를 늘리지 않았다 — **BCH-01 은 여전히 `not_met`이며
  체크박스도 그대로 미체크다.** 근거:
  `phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md`,
  `phase-07/results/20260831T004024Z-classifier-audit/CLASSIFIER-AUDIT.md`,
  `phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md`,
  `phase-07/results/20260831T011037Z-remediation/RECOMMENDATION.md`,
  `phase-07/results/20260831T011037Z-remediation/DECISION.md`.
- [x] **BCH-02**: 각 실행의 **프롬프트와 결과가 모두** 파일로 저장된다
- [x] **BCH-03**: 통과/실패와 소요 시간이 한 표로 요약된다

### DOC — 한글 사용 매뉴얼

- [x] **DOC-01**: CLI 사용법 (기동, 태스크 실행, Plan/Act, 체크포인트)
  <br>※ 2026-08-31 — `docs/manual/01-cli.md` 존재, `check_manual_claims.sh` 통과. 근거:
  `phase-08/results/20260830T200237Z-phase-close/gates/check_manual_claims.txt`
- [ ] **DOC-02**: 웹(Kanban) 사용법 (카드, worktree, diff 리뷰, 의존 체인)
  <br>※ 2026-08-31 — **부분적으로만 충족.** 카드/등록/의존 체인은 라이브 서버를 상대로 실측
  확인됐고, CLI 에 diff/review 명령이 없다는 사실도 실측으로 확인해 정직하게 기록했다(§4).
  네 주제 중 **작업(task)별 worktree** 만 이 배포에서 지원되지 않는다 — `git worktree add` 를
  켜는 유일한 방법(metadata-only `$HOME` widening)을 사용자가 그 정확한 비용을 보고 명시적으로
  **decline** 했다(08-04). 격상·완화하지 않는다. 근거: `docs/manual/02-kanban.md` §4·§6,
  `docs/sandbox-whitelist.md` §9, `phase-08/results/20260830T193634Z-widening/DECISION.md`
- [x] **DOC-03**: iPad·iPhone 사용법 (Tailscale 접속, Telegram 대화, 승인/거부)
  <br>※ 2026-08-31 — `docs/manual/03-mobile.md` 존재, `check_manual_claims.sh` 통과. iOS 기기
  실측 방문·Telegram 실토큰 라이브 트라이얼은 여전히 human_needed(NET-01/NET-05) 로, 문서
  안에 `[GAP-IPAD]`/`[GAP-TELEGRAM-INDICATOR]`/`[GAP-TELEGRAM-TOKEN]` 로 명시돼 있다 — 문서
  자체(절차 기술)는 완료.
- [x] **DOC-04**: 32K 운용 주의 (64초 대기, **압축이 자동으로 도는 것과 그때의 지연**,
  `contextWindow` 는 `settings` 최상위에 넣어야 한다는 점, ⌘+클릭 터치 불가)
  <br>※ 2026-08-30 정정 — "26k 작업 예산 / 태스크 쪼개기"는 불필요해졌다. 압축이 대역을 유지한다
  <br>※ 2026-08-31 — `docs/manual/04-32k-operations.md` 존재, `check_manual_claims.sh` 통과,
  폐기된 조언(작업 예산/태스크 쪼개기)이 §4 에서 명시적으로 폐기 상태로 기록돼 있고 다시
  지침으로 나오지 않는다.

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

로드맵 생성 완료 — 아래 표는 .planning/ROADMAP.md 기준.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CFG-01 | Phase 1 | Complete |
| CFG-02 | Phase 1 | Complete |
| CFG-03 | Phase 1 | Complete |
| CFG-04 | Phase 1 | Complete |
| CFG-05 | Phase 1 | **Not satisfied today** (호스트 `cline` 3.0.60 — 아래 참조) |
| CFG-06 | Phase 1 | Complete |
| CFG-07 | Phase 1 | Complete |
| VER-01 | Phase 1 | Complete |
| VER-02 | Phase 1 | Complete |
| VER-03 | Phase 1 | Complete |
| VER-04 | Phase 1 | Complete |
| INF-01 | Phase 2 | Complete |
| INF-02 | Phase 2 | Complete |
| INF-03 | Phase 2 | Complete |
| SBX-01 | Phase 3 | Complete |
| SBX-02 | Phase 3 | Complete |
| SBX-03 | Phase 3 | Complete |
| SBX-04 | Phase 3 | Complete |
| HLS-01 | Phase 4 | Complete |
| HLS-02 | Phase 4 | Complete |
| HLS-03 | Phase 4 | Complete |
| SVC-01 | Phase 5 | Complete |
| SVC-02 | Phase 5 | Complete |
| SVC-03 | Phase 5 | Complete |
| SVC-04 | Phase 5 | Complete |
| SVC-05 | Phase 5 | Complete |
| NET-01 | Phase 6 | Human-needed |
| NET-02 | Phase 6 | Complete |
| NET-03 | Phase 6 | Complete |
| NET-04 | Phase 6 | Complete |
| NET-05 | Phase 6 | Human-needed |
| BCH-01 | Phase 7 | Not met (고유 4/12 과제, 3개 모델 도달·32K 천장에서 fail-context, 5~8 하한 미달; gap2 07-11~16 이 근인 규명, contextWindow 무변경, 판정 불변) |
| BCH-02 | Phase 7 | Complete (시도된 4개 과제/5개 인스턴스 기준, 두 런 디렉터리 모두) |
| BCH-03 | Phase 7 | Complete (시도된 4개 과제/5개 인스턴스 기준, 두 런 디렉터리 모두) |
| DOC-01 | Phase 8 | Complete |
| DOC-02 | Phase 8 | Partial (worktree unavailable — user declined sandbox widening, 08-04) |
| DOC-03 | Phase 8 | Complete |
| DOC-04 | Phase 8 | Complete |

**Coverage:**
- v1 requirements: 38 total
- Mapped to phases: 38
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-29*
*Last updated: 2026-08-29 after Phase 1 research — CFG-03 재서술, CFG-04 재정의, CFG-07 신설*

---

## Milestone Summary

**Shipped:** 38 개 v1 요구사항 중 33 complete, 1 partial, 2 human_needed, 2 not met

**Adjusted (구현 중 변경):**
- CFG-02 — `models[].contextWindow: 32768` → **`settings` 최상위 `contextWindow: 29000`**
  (`models[]` 는 VS Code 용 경로이고 CLI 가 읽지 않음이 소스로 확인됨)
- CFG-03 — "maxTokens 상한 설정" → "실제 전송값을 관측하고 대응책을 정한다"
  (providers.json 의 maxTokens 미적용. 실측 2048 로 예산이 충족되어 Branch A)
- CFG-04 — "Compact Prompt 켜기" → "`--compaction` 모드 명시 고정"
  (Compact Prompt 는 VS Code 확장 전용이며 CLI 에 존재하지 않음)
- CFG-07 — **신설**. `flashnext-codex` 별칭 차단 (호출 시 모델 서버 사망, 29초 다운 실측)
- NET-05 — "작업 중 표시" → "프리필 대기 + **압축 중** 상태 표시"
- DOC-04 — "26k 작업 예산·태스크 쪼개기" → 삭제. 설정 위치 주의로 대체

**Not met (기술부채로 수용):**
- **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 자동 업데이트를 막지 못함. 드리프트 반복
- **BCH-01** — 고유 4과제(하한 5), 통과 0개. 사용자 정지 결정

**Human needed (미관측):**
- **NET-01** — iPad Safari 에서 Kanban 접속. 서버측만 증명, iPad 오프라인
- **NET-05** — Telegram 실토큰 시험 거절

**Partial:**
- **DOC-02** — worktree 불가. 사용자가 샌드박스 확장을 명시적으로 거절

---
*Archived: 2026-08-31 as part of v1 milestone completion*
