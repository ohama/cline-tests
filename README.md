# Cline 로컬 서버

## 한 문단 소개

이미 검증된, 손대지 않은 로컬 추론 스택(`litellm(:4000) → role-shim(:8011) →
mlx_vlm.server/flashnext(:8000)`) 위에 Cline 에이전트 코어를 얹은 저장소다. 핵심 가치는
**압축이 32K 벽에 닿기 전에 스스로 돌아서, 작업이 중간에 죽지 않는 것** — `contextWindow` 를
`settings` 최상위 `29000` 으로 설정해 트리거(`26100`)를 실측 오버슈트(~3,100 토큰) 전에
넉넉히 넘기고, 실제 긴 세션이 완주함을 실측으로 확인했다. 위에 세 사용 표면(헤드리스 CLI,
Kanban 보드, Telegram 커넥터)이 있고, 셋 다 macOS Seatbelt 샌드박스로 격리된다.

## 사용 매뉴얼

시작점은 `docs/manual/00-getting-started.md` 다 — 다른 네 문서로 가는 길을 여기서 안내한다.

| 문서 | 내용 |
|---|---|
| `docs/manual/00-getting-started.md` | **시작점.** 시스템 개요, 여섯 서비스, 오늘 아침 확인 명령, 증상→문서 표 |
| `docs/manual/01-cli.md` | 헤드리스 CLI 사용법 — 태스크 실행, 결과 판정, Plan/Act, 체크포인트, 버전 확인 |
| `docs/manual/02-kanban.md` | 웹 Kanban 사용법 — 접속, 등록, 카드, diff 리뷰, 의존 체인 (부분적으로만 충족 — worktree 불가) |
| `docs/manual/03-mobile.md` | iPad·iPhone 사용법 — Tailscale 접속, Telegram 대화 |
| `docs/manual/04-32k-operations.md` | 32K 운용 주의 — 64초 대기, 압축, 서버 400, cline-bench 상태 |

## 엔지니어링 기록

`docs/manual/` 은 **어떻게 쓰나**를 기록하고, 아래 아홉 개 문서는 **어떻게 만들어졌고 어떻게
검증됐나**를 기록한다 — 뭔가의 이유가 궁금할 때 여기로 온다.

| 문서 | 내용 |
|---|---|
| `docs/32k-compaction-policy.md` | 압축 실측 정책 — 트리거 지점, `contextWindow` 설정 위치, 오버슈트 |
| `docs/cline-bench.md` | cline-bench 공식 과제 실행 기록 (§9: 매뉴얼에 쓰면 안 되는 문장 목록) |
| `docs/cline-config-pins.md` | `cline`/`kanban` 버전, compaction 모드, 모델 고정값의 근거 |
| `docs/cline-max-tokens-findings.md` | Cline 이 실제로 보내는 `max_tokens` 실측 기록 |
| `docs/headless-wrapper.md` | 헤드리스 CLI 래퍼 설계, THE CWD RULE, `--auto-approve false` 결정 |
| `docs/infra-hardening.md` | flashnext 동시성 상한, litellm 인증/바인딩 하드닝 |
| `docs/network-exposure.md` | Tailscale 노출 경로, 포트 3000 금지, NET 기준 검증 |
| `docs/plan-act-reasoning-design.md` | **제안(미구현)** — Plan/Act ↔ `reasoning_effort` 연결 설계. litellm 이 `reasoning_effort` 를 400 으로 차단하는 문제 포함 |
| `docs/sandbox-whitelist.md` | 샌드박스 화이트리스트 설계, SBPL 규칙, worktree widening 결정(§9) |
| `docs/services.md` | 여섯 서비스의 launchd 등록, 재부팅 proxy 증거, kanban 등록 픽스(§5a) |

## 상시 게이트

읽기 전용, 재실행 가능. 정상 신호가 기재된 것과 다르면 문제가 있다는 뜻이다.

| 게이트 | 명령 | 정상 신호 |
|---|---|---|
| 서비스 | `bash phase-05/services/verify_services.sh` | exit 0 |
| 네트워크 | `bash phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline` | `CASES 24/24` |
| 설정 | `bash phase-01/config/verify_config.sh` | exit 0 |
| 인프라 회귀 | `bash phase-02/infra/verify_no_regression.sh` | exit 0 |
| 샌드박스 | `bash phase-03/sandbox/verify_sandbox.sh` | 네 개 `CRITERION` 줄 모두 PASS |
| 벤치 | `bash phase-07/bench/verify_bench.sh` | exit 0 |

`phase-01/config/check_versions.sh` 는 이 목록에 **의도적으로 포함하지 않았다** — 이 스크립트의
Check B 가 호스트 `cline` 바이너리를 직접 호출하고, 그 호출 자체가 자동 업데이트 드리프트를
유발하는 트리거이기 때문이다.

## 절대 하지 말 것

1. 포트 3000 을 절대 바인딩하지 않는다 — 기존 공용 Funnel(`:8443`)이 그쪽으로 포워딩한다.
2. `tailscale serve reset` 을 절대 실행하지 않는다 — 이 프로젝트 이전부터 있던 핸들러 3개와
   공용 Funnel 키까지 전부 지워버린다.
3. `tailscale funnel` 을 절대 실행하지 않는다 — 이 프로젝트의 어떤 서비스도 공용 노출 대상이
   아니다.
4. 서비스를 `kill`/`pkill`, `launchctl load|unload|kickstart` 로 내리지 않는다 — 항상
   `phase-02/infra/restart_service.sh` 만 쓴다.
5. 저장소 루트를 `workspace/ALLOWED_REPOS.json` 에 추가하지 않는다 — `bench/` 가 그 아래
   있고, 샌드박스 안에서 `bench/` 가 절대 닿지 않아야 한다는 SBX-04 요구를 깬다.

## 계획 문서

이 프로젝트 자신의 진행 이력과 요구사항 추적성은 `.planning/ROADMAP.md` 와
`.planning/REQUIREMENTS.md` 를 볼 것.
