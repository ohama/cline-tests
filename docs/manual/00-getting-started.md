# 00. 시작하기

근거 문서: docs/services.md §2·§4·§5, docs/infra-hardening.md, docs/network-exposure.md §2,
docs/sandbox-whitelist.md.

이 문서는 매뉴얼의 입구다 — "오늘 아침 뭘 켜야 하나"와 "64초 대기와 멈춤을 어떻게 구분하나"에
답하고, 나머지 네 사용법 문서(`01-cli.md`, `02-kanban.md`, `03-mobile.md`,
`04-32k-operations.md`)로 안내한다. 왜/어떻게 검증됐는지는 위 근거 문서와 `docs/` 아래 아홉 개
엔지니어링 기록을 볼 것 — 여기서는 되풀이하지 않는다.

## 1. 이게 뭔가

이 프로젝트는 이미 존재하던, 손대지 않은 추론 스택(`litellm(:4000) → role-shim(:8011) →
mlx_vlm.server/flashnext(:8000)`) 위에 Cline 에이전트 코어를 얹은 것이다. 그 위에 사람이 쓰는
표면이 세 개 있다: 헤드리스 CLI 래퍼, Kanban 보드, Telegram 커넥터. 세 표면 모두 원격에서
트리거될 수 있으므로, 셋 다 macOS Seatbelt 샌드박스(`sandbox-exec`) 아래에서만 실행되고, 그
샌드박스의 허용 목록은 `workspace/ALLOWED_REPOS.json` 하나가 정의한다 — 이 목록 밖의 어떤
경로도 읽거나 쓸 수 없다.

## 2. 여섯 개 서비스

여섯 개 모두 `launchd` 상시 에이전트다. **pid 는 재시작마다 바뀌지만 라벨은 바뀌지 않는다 —
그래서 라벨이 서비스의 진짜 신원이다.**

| 라벨 | 포트 | 무엇인가 | 로그 |
|---|---|---|---|
| `com.ohama.flashnext` | `:8000` | 모델 서버 (`mlx_vlm.server`, Qwen3.8-Flash-Next MLX) | `~/llm-system/services/logs/flashnext.log`/`.err` |
| `com.ohama.litellm` | `:4000` | flashnext 앞의 OpenAI-호환 프록시 | `~/agent-stack/litellm/litellm.log`/`.err` |
| `com.ohama.role-shim` | `:8011` | litellm/flashnext 사이의 role/메시지 형태 변환 | `~/llm-system/services/logs/role-shim.log`/`.err` |
| `com.ohama.kanban` | `:3484` | Kanban 보드 서버(카드/태스크) | `~/.cline/logs/kanban.log`/`.err` |
| `com.ohama.telegram-connect` | (없음, 아웃바운드만) | Telegram 봇 커넥터(`cline connect telegram`) — 토큰 슬롯이 비어 있어 현재 inert | `~/.cline/logs/telegram-connect.log`/`.err` |
| `com.ohama.kanban-proxy` | `:18484` | kanban 앞의 Host/Origin 재작성 루프백 프록시(Tailscale 이 도달하는 경로) | `~/.cline/logs/kanban-proxy.log`/`.err` |

(라이브 pid 확인, 2026-08-31: flashnext 46573, role-shim 75548, litellm 48525, kanban 36175,
telegram-connect 99162, kanban-proxy 19669 — 표를 쓰기 전에 `launchctl print`/`ps` 로 직접
확인한 값이다. 다음에 서비스가 재시작되면 이 숫자들은 바뀐다; 위 표의 라벨/포트/로그 칸은
바뀌지 않는다.)

## 3. 오늘 아침 뭘 켜야 하나 — 보통은 아무것도

여섯 서비스 전부 `RunAtLoad: true` 인 launchd 상시 에이전트다. 컴퓨터가 켜져 있으면 이미 떠
있다. 사람이 매일 할 일은 **확인**뿐이다:

```
bash phase-05/services/verify_services.sh
```
정상: 모든 `CHECK` 줄이 `PASS`, 마지막 `CASES N/N` 이 전부 통과.

```
bash phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline
```
정상: `CASES 24/24`.

```
bash phase-01/config/verify_config.sh
```
정상: exit 0 (compaction 트리거·`contextWindow` 설정이 맞는 칸에 있음을 확인).

```
bash phase-02/infra/verify_no_regression.sh
```
정상: `INF03: PASS` — flashnext/litellm 하드닝 이후에도 기존 별칭 호출이 그대로 동작.

## 4. ⚠️ [GAP-REBOOT] 재부팅 검증은 실제로 한 적이 없다

증명된 것은 **proxy** 뿐이다: `com.ohama.kanban`/`com.ohama.telegram-connect` 두 plist 모두
`RunAtLoad: true`, 둘 다 `~/Library/LaunchAgents/` 에 실제로 존재, 두 라벨 모두 활성 상태,
그리고 각 라벨에 대해 `bootout` → (내려간 상태 유지 확인) → `bootstrap` → healthy 확인까지
실제로 한 사이클씩 집행됐다. **하지만 실제 macOS 재부팅은 한 번도 수행된 적이 없다.** "재부팅
검증 완료"라고 쓰지 않는다.

추가로, 이 두 서비스와 무관한 별개의 재부팅 전제조건이 있다: 실제 재부팅은
`iogpu.wired_limit_mb` 를 초기화하고, `phase-02/infra/preflight.sh` 는 이 값이 잘못돼 있으면
하드 실패한다 — 그래서 재부팅 이후에는 flashnext 가 다시 건강해지기 전에 사람이 직접
`sudo sysctl` 로 재적용해야 한다.

## 5. ⚠️ [GAP-CLINE-VERSION] 버전을 반드시 확인할 것

호스트 `cline` 은 핀 `3.0.53` 에서 `3.0.60` 으로 드리프트됐다 — `CLINE_NO_AUTO_UPDATE=1` 이
있어도 막지 못했다. 이 매뉴얼의 어떤 문서도 "3.0.53 고정"을 현재 사실로 쓰지 않는다. 확인하는
법은 `01-cli.md` 8절을 볼 것 — `cline --version` 을 직접 호출하지 말고
`/opt/homebrew/lib/node_modules/cline/package.json` 을 읽는다.

## 6. ⚠️ [GAP-READONLY] 읽기·대화 전용이다

이 프로젝트가 실제로 출하한 표면은 정확히 두 가지다 — 헤드리스 래퍼의 `--auto-approve false`,
Telegram 커넥터의 `--no-tools`. **원격에서 트리거된 에이전트는 파일을 수정할 수 없다.** 이
태세를 뒤집는 것은 사람이 명시적으로 내려야 하는 보안 결정이며, 이 매뉴얼은 누구에게도 플래그를
뒤집으라고 말하지 않는다.

## 7. ⚠️ [GAP-PORT3000] 포트 3000 은 절대 바인딩하면 안 된다

이 프로젝트 이전부터 존재하는, 지금도 살아 있는 공용(public) Tailscale Funnel 핸들러
(`:8443 → http://127.0.0.1:3000`)가 있다. 포트 3000 에 무엇이든 바인딩하면 Tailscale 로그인
없이 전 세계에서 접근 가능해진다. 이 규칙은 영구적이다.

## 8. 64초 대기와 멈춤을 구분하는 법 — 요약

32K 근처까지 채워진 요청은 프리필(prefill) 자체가 ~64초까지 조용하게 걸릴 수 있다 — 그동안
화면에 아무것도 새로 뜨지 않는 것은 정상이다. 수 분 이상 넘어가면 그때 상시 게이트부터
돌려본다. 전체 판단 기준, 압축이 도는 동안의 두 번째 지연, 그리고 서버 400(터미널 실패, 재시도
불가) 은 전부 `docs/manual/04-32k-operations.md` 가 다룬다 — 여기서는 되풀이하지 않는다.

## 9. 증상 → 어느 문서

| 증상 | 문서 |
|---|---|
| 보드가 안 열린다 | `03-mobile.md` / `02-kanban.md` |
| 카드가 안 보인다 | `02-kanban.md` §등록 |
| 64초 넘게 아무 반응이 없다 | `04-32k-operations.md` |
| 결과가 이상하다 / 종료 코드를 모르겠다 | `01-cli.md` |
| 버전이 문서와 다르다 | `01-cli.md` `[GAP-CLINE-VERSION]` |
| Telegram 이 응답이 없다 | `03-mobile.md` |

## 10. 엔지니어링 기록 — 이 매뉴얼과 무엇이 다른가

`docs/manual/` 은 **사용법**(어떻게 쓰나)을 기록하고, 아래 아홉 개 `docs/*.md` 는 **어떻게
만들어졌고 어떻게 검증됐나**를 기록한다. 뭔가 왜 이렇게 돼 있는지 궁금하면 아래로 간다:

| 문서 | 무엇이 들어 있나 |
|---|---|
| `docs/32k-compaction-policy.md` | 압축이 실제로 도는 지점, `contextWindow` 설정 위치, 오버슈트 실측 |
| `docs/cline-bench.md` | cline-bench 공식 과제 실행 기록 — 모델 도달 3개, 통과 0개, §9 에 금지 문장 목록 |
| `docs/cline-config-pins.md` | `cline`/`kanban` 버전, compaction 모드, 모델 고정값의 근거 |
| `docs/cline-max-tokens-findings.md` | Cline 이 실제로 보내는 `max_tokens` 실측 기록 |
| `docs/headless-wrapper.md` | 헤드리스 CLI 래퍼 설계, THE CWD RULE, `--auto-approve false` 결정 |
| `docs/infra-hardening.md` | flashnext 동시성 상한, litellm 인증/바인딩 하드닝 |
| `docs/network-exposure.md` | Tailscale 노출 경로, 포트 3000 금지, NET 기준 검증 |
| `docs/sandbox-whitelist.md` | 샌드박스 화이트리스트 설계, SBPL 규칙, worktree widening 결정(§9) |
| `docs/services.md` | 여섯 서비스의 launchd 등록, 재부팅 proxy 증거, kanban 등록 픽스(§5a) |

---
*근거: docs/services.md, docs/infra-hardening.md, docs/network-exposure.md, docs/sandbox-whitelist.md*
