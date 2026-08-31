# Cline 로컬 서버

## What This Is

이 Mac 에서 도는 Qwen3.8 Flash-Next 를 두뇌로 쓰는 **Cline 상시 서버**를 만든다.
부팅하면 launchd 가 알아서 올리고, 아이패드·아이폰에서 Tailscale 로 들어와 코딩 작업을
시키고 결과를 리뷰할 수 있어야 한다. 사용자는 ohama 본인 한 사람이다.

세 개의 표면을 올린다 — **Kanban 웹 UI**(브라우저·아이패드), **Telegram 커넥터**(아이폰),
**헤드리스 래퍼**(스크립트·자동화). 셋 다 같은 Cline 에이전트 코어와 같은 로컬 모델을 쓴다.

## Core Value

**Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것.**

> ✅ **2026-08-30 — 합성 회귀에서 달성됨.** `providers.json` 의 **`settings` 최상위**에
> `contextWindow: 29000` 을 넣으면 트리거(26,100)가 정상 발동하고, 균일 filler 워크로드에서는
> 실제로 프루닝돼 토큰이 준다. 실측: `phase-01/results/exp-verify29k/`
> (필러 18개 완주, 압축 3회 이상, 서버 400 0건). 상세: `docs/32k-compaction-policy.md`.
>
> 🔶 **2026-08-31 정정(범위 좁힘, 반전 아님) — 임의의 실제 에이전트 작업으로 일반화되지
> 않는다.** Phase 7 cline-bench gap-closure 가 실제 워크로드에서 캡처한 `completed` 압축
> 이벤트는 2건뿐이지만, **2/2건 모두 메시지를 하나도 지우지 않았고 토큰이 오히려 늘었다** —
> 그 결과 모델에 도달한 cline-bench 과제 3개 전부 32K 천장에서 죽었다(`fail-context`,
> 통과 여전히 0개). `contextWindow` 값은 바뀌지 않는다(`SELECTION: doc-only`) — 압축이
> 실제로는 대역을 만들어 주지 않는다는 확인된 결함이 있으므로, 그 값을 낮추는 것은 문제의
> 축이 아니라는 판단이다. 합성 증명은 지워지지 않는다 — 위 필러 회귀는 여전히 유효하고
> 재현 가능하다. 상세: `docs/32k-compaction-policy.md` §1·§4a,
> `phase-07/results/20260831T011037Z-remediation/RECOMMENDATION.md` §6,
> `phase-07/results/20260831T011037Z-remediation/DECISION.md`.

🔴 초기 가정을 실측으로 뒤집었다. 모델 서버는 조용히 고장 나지 않는다 —
`prompt + max_tokens > 32768` 이면 prefill 전에 **HTTP 400 으로 크게 실패**한다.
🔴 **아래 진단은 2026-08-30 에 뒤집혔다** — 원인은 #12520 이 아니라 우리가 `contextWindow` 를
`models[]` 안에 넣은 것이었다. 기록으로만 남긴다.

문제는 다른 데 있다. Cline 은 자기가 128k 를 쓴다고 믿어서 압축을 ~115k 에서 기다린다.
그래서 대화가 32k 를 넘는 순간 이후 모든 요청이 400 이 되고, **Cline 은 스스로 회복하지
못한 채 작업이 죽는다.**

그러므로 지켜야 할 것은 "거부"가 아니라 **"벽에 닿지 않기"** 다.
Cline 의 압축이 ~26.2k 에서 실제로 도는지 — 이것만은 실측으로 증명돼야 한다.

## Requirements

### Validated

<!-- 이 프로젝트 이전에 이미 이 기계에서 검증된 것들. 손대지 않는다. -->

- ✓ Qwen3.8-Flash-Next-MLX-oQ4 + MTP drafter 가 `:8000` 에 상주 — `--max-kv-size 32768`
- ✓ `role-shim`(`:8011`) 이 mlx_vlm.server 의 role 제약을 흡수
- ✓ `litellm`(`:4000`) 이 OpenAI 호환 엔드포인트로 `flashnext` 별칭 제공
- ✓ 위 세 서비스 모두 `RunAtLoad` + `KeepAlive` 로 부팅 자동 기동
- ✓ 32K 에서 실측 — peak 120.16 GB(여유 4.39 GB), TTFT 64.3s, 생성 17.0 tok/s
- ✓ 정확도 전 축 통과 — coding 95% · reasoning 100% · agent 93.3%

### Active

<!-- 이번에 만드는 것. 출하 전까지는 전부 가설이다. -->

- [ ] Kanban 웹 UI 를 launchd 서비스로 상시 기동 (`:3484`), 부팅 시 자동 재시동
- [ ] Telegram 커넥터를 launchd 서비스로 구성 (토큰 자리는 비워 두고 나중에 주입)
- [ ] 헤드리스 CLI 래퍼 스크립트 (서비스화는 보류, 호출 규약만 깔끔하게)
- [ ] Cline 이 `flashnext`(`:4000`) 를 프로바이더로 쓰도록 구성
- [ ] **Cline 쪽 컨텍스트 창을 32768 로 못 박기** — 128k 폴백을 덮어쓴다
- [ ] **`max_output_tokens` 상한 설정** — 서버 예산은 `prompt + max_tokens`. 크게 보내면 첫 턴부터 400
- [x] **다중 턴 압축 회귀 테스트** — 완료. 최상위 `contextWindow` 설정 시 26,100 에서 압축 발동 확인
- [ ] **`CLINE_NO_AUTO_UPDATE=1` 을 모든 plist 에** — Cline 이 실행 때마다 몰래 자기를 업데이트한다
- [ ] cline-bench 공식 과제 일부를 로컬 Docker 로 실행해 동작 검증
- [ ] 테스트의 **프롬프트와 결과를 모두** 파일로 보존
- [ ] Tailscale 무인증 접근 + LAN 접근은 토큰 요구
- [ ] 작업공간 샌드박스 + 허용 저장소 화이트리스트
- [ ] 한글 사용 매뉴얼 — CLI / 웹 / iPad·iPhone
- [ ] 새 서비스를 `~/local-llm-settings` 에 등록하고 `sync.sh` 반영

### Out of Scope

- **운영 런북(재시작·로그·장애 대응)** — 매뉴얼은 사용법만 담기로 했다. 별도 문서로 분리
- **헤드리스 HTTP 서버** — 무엇이 호출할지 미정. 래퍼만 만들고 서비스화는 보류
- **64K 이상 컨텍스트** — 64K 는 여유 0.10 GB, 128K 는 wired limit 초과. 이 기계에서 불가능
- **다른 모델 동시 기동** — Flash-Next 104 GiB. 한 번에 한 모델만 올라간다
- **인터넷 노출 / 공개 URL** — Tailscale 과 LAN 까지만. Discord·WhatsApp 웹훅은 안 쓴다
- **Cline 업스트림 버그 수정 PR** — 폴백 버그는 우회하고 기록만 한다. 고쳐서 보내지 않는다
- **기존 Tailscale Funnel 정리** — `:8443 → 127.0.0.1:3000` Funnel 이 켜져 있으나 이 프로젝트에서 건드리지 않기로 했다(사용자 결정 2026-08-29). 아래 제약 참조
- **게이트웨이 32K 거부 가드** — 모델 서버가 이미 `prompt + max_tokens > 32768` 을 prefill 전에
  HTTP 400 으로 거부함을 실측 확인(2026-08-29). 같은 판정을 role_shim 에서 반복하면 지연만 늘고
  모델 토크나이저와 어긋날 위험이 있다. 거부는 서버에 맡기고 **검증으로 대체**한다
- **cline-bench 전 과제 완주** — 과제당 타임아웃 2400s. 32K TTFT 64s 인 기계에서 비현실적
- **deep mode(drafter 제거) 전환** — 현재 fast mode 유지. 재기동 20~45초가 상시 서버와 안 맞는다

## Context

### 물려받는 스택

```text
Cline (새로 만드는 부분)
   └→ litellm :4000   ── 별칭 flashnext, OpenAI 호환, api_key 아무 값
        └→ role-shim :8011   ── developer/system role 정규화
             └→ mlx_vlm.server :8000   ── Qwen3.8-Flash-Next-MLX-oQ4 + MTP drafter
                                          --max-kv-size 32768
```

기준 문서는 `~/local-llm-settings/` (README·TOPOLOGY·STATE·VALIDATED).
`STATE.md` 는 `sync.sh` 가 생성하므로 손으로 고치지 않는다.

### ✅ 32K 압축 트리거 — 합성 회귀에서 해결됨 (2026-08-30)

🔶 **2026-08-31 정정(범위 좁힘)** — 아래 표는 트리거 발동 메커니즘(맞음, 최상위
`contextWindow` → `maxInputTokens`, `×0.9`)과 합성 filler 회귀에서의 결과만 기술한다.
실제 cline-bench 워크로드에서는 압축이 발동해도 프루닝하지 않아(메시지 0건 삭제, 토큰
오히려 증가, 2/2건) 모델에 도달한 과제 3개 전부 이 천장에서 죽었다(`fail-context`, 통과
0개) — `docs/32k-compaction-policy.md` §1·§4a, `docs/cline-bench.md` §4,
`phase-07/results/20260831T011037Z-remediation/RECOMMENDATION.md`.

```jsonc
// providers.json — CLI 가 읽는 유일한 경로
"settings": { "provider": "openai-compatible", "model": "flashnext",
              "baseUrl": "http://localhost:4000/v1",
              "contextWindow": 29000 }   // ← settings 최상위. models[] 아님
```

| 항목 | 값 | 근거 |
| --- | --- | --- |
| 매핑 | `settings.contextWindow` → `maxInputTokens` | `provider-settings.ts:150, 266` |
| 트리거 | `maxInputTokens × 0.9` = 26,100 | 실측 2회 (12000→10800, 29000→26100) |
| 오버슈트 | 트리거 초과 후 약 3,100 토큰 | `exp-verify29k` 압축 기록 |
| 결과 | 필러 18개 완주, 서버 400 **0건** | `phase-01/results/exp-verify29k/` |

부수 효과: `providers.json` 필드 소실(Pitfall 5)도 같은 원인이었다. `models[]` 는 정규화에서
버려지지만 최상위 `contextWindow` 는 살아남는다.

🔴 **하위 페이즈 적용 규칙** — 컨텍스트 관련 설정을 다루는 모든 플랜은
`phase-01/config/apply_provider_config.sh` / `verify_config.sh` 를 통해야 한다.
직접 `providers.json` 을 쓰지 말 것. 두 스크립트가 최상위 경로를 강제·검사한다.

### 🔴 (기록) 이 프로젝트를 정면으로 겨냥한다고 판단했던 Cline 버그

Cline 의 `openai-compatible` 프로바이더는 모델 정보를 못 찾으면 컨텍스트를
**128,000 으로 폴백**한다.

| 위치 | 내용 |
| --- | --- |
| `sdk/packages/llms/src/providers/builtins.ts` `fallbackModelInfo()` | `family === "openai-compatible"` → `contextWindow = 128_000` |
| `sdk/packages/llms/src/providers/compat.ts:629` `resolveModelInfo()` | `config.modelInfo ?? knownModels[modelId] ?? {…}` — 폴백 객체가 먼저 잡혀 카탈로그에 **영영 도달하지 않는다** |
| 이슈 [#12520](https://github.com/cline/cline/issues/12520) | 1M 선언인데 115.2k(=128000×0.9)에서 압축. **CLI 3.0.46 기준** |
| 이슈 [#13457](https://github.com/cline/cline/issues/13457) | LM Studio 200k 설정인데 실제로 128k 기준으로 압축 |

이 기계에 깔린 건 **cline@3.0.53** 이다. 영향권에 있을 가능성이 높다.
32K 서버 앞에서 이 버그는 "Cline 이 115k 를 쌓아 올린 뒤에야 압축을 시도"하는
조용한 고장으로 나타난다. 그래서 요구사항을 **Cline 설정 + 게이트웨이 가드** 이중으로 잡았다.

### ✅ 실측으로 해소된 우려 (2026-08-29)

| 우려 | 실측 결과 |
| --- | --- |
| 서버가 조용히 잘라내나? | **아니다.** `prompt + max_tokens > 32768` → HTTP 400 `PromptTooLongError`, prefill 전 ~400ms |
| `usage` 가 null 이라 Cline 이 눈머나(#9433)? | **아니다.** 비스트리밍·스트리밍 모두 `usage` 정상 반환 |

```text
prompt 13 + max_tokens 40000 → 400  "Request needs 40013 context tokens … MAX_KV_SIZE is 32768."
prompt 13 + max_tokens 32000 → 200
prompt 13 + max_tokens  4096 → 200
```

🔴 검사식은 **`prompt_tokens + max_tokens ≤ 32768`** 이다. 프롬프트가 짧아도
`max_output_tokens` 를 크게 보내면 **첫 턴부터** 400 이 난다 (이슈 #9651 증상).

### 🔴 Cline 이 실행할 때마다 자기를 업데이트한다

조사 중 `3.0.53 → 3.0.60` 드리프트를 두 번 재현했다. 백그라운드로 분리된
`npm update -g cline` 가 돈다. 버전이 바뀌면 이 프로젝트의 설정 전제가 조용히 무너진다.
`CLINE_NO_AUTO_UPDATE=1` 로 고정되는 것을 확인했다 — **모든 plist 에 넣는다.**

### 🔴 32K 의 대가 — prefill

| 컨텍스트 | TTFT | 생성 | MTP 배율 |
| ---: | ---: | ---: | ---: |
| 4K | 6.0 s | 17.9 tok/s | 1.090 |
| 16K | 26.7 s | 17.2 tok/s | 1.125 |
| **32K** | **64.3 s** | 16.6 tok/s | 1.028 |

긴 컨텍스트의 병목은 생성이 아니라 prefill 이다. 에이전트 루프는 매 턴 대화 전체를
다시 보내므로, 컨텍스트가 차면 한 턴에 1분이 넘는다.

- Cline 압축 임계값 (2026-08-30 실측 확정): **`trigger = maxInputTokens × 0.9`**
  `settings` 최상위 `contextWindow` 가 `maxInputTokens` 로 직행한다 → `29000 × 0.9 = 26,100`
  (초기 추정 `max(ctx−40000, ctx×0.8)` 도, 1차 조사의 `×0.9×0.9` 도 둘 다 틀렸다.
   `×0.9×0.9` 는 `maxInputTokens` 가 없을 때의 폴백 경로다.)
- Compact Prompt(전체 시스템 프롬프트의 약 10%)는 32K 에서 **선택이 아니라 필수**
- 아이패드 UI 는 이 대기를 사용자에게 반드시 알려야 한다

### 이미 갖춰진 환경

| | |
| --- | --- |
| `cline@3.0.53` | 전역 설치됨 (`/opt/homebrew/bin/cline`) |
| Node | v25.9.0 (요구 22+ 충족) |
| 포트 3484 | 비어 있음 |
| Tailscale | 가동 중. 이 Mac 은 `ohama-2` / `100.118.140.2`, 테일넷 `tail318f12.ts.net` |
| 등록된 모바일 기기 | iPad `ipad165`, iPad `ipad-mini-6th-gen-wifi`, iPhone `iphone171` |
| Docker · uv | 설치됨 (cline-bench 실행 가능). Python 은 3.14.6, cline-bench 는 3.13 요구 → uv 로 해결 |

### 집 규칙 (따를 것)

- launchd plist 는 `~/Library/LaunchAgents/`, 사본은 `~/local-llm-settings/launchagents/`
- 로그는 `~/llm-system/services/logs/`
- 라벨은 `com.ohama.*`
- `RunAtLoad` + `KeepAlive` + `ThrottleInterval`
- 설정을 바꿨으면 `~/local-llm-settings/sync.sh`

## Constraints

- **메모리**: Flash-Next 104 GiB, `iogpu.wired_limit_mb` 124.55 GB — 32K 에서 여유 4.39 GB.
  다른 모델을 동시에 못 올린다. Cline 서버가 무거운 프로세스를 띄우면 안 된다
- **컨텍스트**: 상한 32,768. 64K 는 여유 0.10 GB 라 위험, 128K 는 불가능
- **지연**: 32K prefill 64.3초. 대화형 UX 설계와 타임아웃 값이 여기 묶인다
- **모델 API**: `reasoning_effort` 는 `low`·`medium`·`xhigh` 뿐 — `high` 는 500.
  `thinking_budget` 은 drafter 부착 상태에서 사용 불가
- **경유**: `:8000` 직결 금지. `:4000` 을 거쳐야 role 제약이 흡수된다
- **Cline 버전**: 3.0.53. 128k 폴백 버그 영향권 추정 — 우회로 해결한다
- **보안**: Tailscale 무인증, LAN 은 토큰 요구. 이 프로젝트가 만드는 것은 인터넷에 노출하지 않는다
- 🔴 **포트 3000 금지**: `https://ohama-2.tail318f12.ts.net:8443` Funnel 이 `127.0.0.1:3000` 으로
  프록시된다. Funnel 은 테일넷이 아니라 **공개 인터넷**이다. 지금은 3000 에 아무것도 안 떠 있어
  실노출이 없지만, 규칙은 살아 있다. **이 프로젝트의 어떤 컴포넌트도 3000 에 바인딩하면 안 된다**
- **작업 범위**: 샌드박스 작업공간 + 허용 저장소 화이트리스트 밖으로 못 나간다
- **외부 의존**: Telegram 봇 토큰은 사람이 BotFather 에서 받아야 한다 (자동화 불가)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 세 표면(Kanban·Telegram·헤드리스) 모두 구축 | iPad 는 웹 UI, iPhone 은 메신저, 자동화는 CLI — 기기마다 맞는 표면이 다르다 | — Pending |
| 게이트웨이 거부 가드를 빼고 검증으로 대체 | 서버가 이미 400 으로 크게 실패함을 실측. 중복 판정은 지연만 늘고 토크나이저 불일치 위험 (사용자 결정 2026-08-29) | ✓ Good |
| 진짜 검증 대상을 "압축이 26.2k 에서 도는가" 로 재정의 | 400 은 벽을 알려줄 뿐 막지 못한다 | ✓ Good — 이 재정의 덕에 설정 위치 오류를 찾아냈다 |
| `contextWindow` 는 `settings` 최상위에 넣는다 (`models[]` 아님) | `provider-settings.ts:266` 이 최상위 값만 `maxInputTokens` 로 매핑한다. `models[]` 는 VS Code 용이며 CLI 가 기동 시 버린다 | ✓ Good — 압축 발동 실측 확인 |
| `contextWindow` 값은 32768 이 아니라 29000 | 압축이 트리거를 약 3,100 토큰 초과한 뒤 발동(오버슈트). 32768 이면 `29,491+3,100+2,048 > 32,768` 로 여전히 벽을 넘는다 | ✓ Good |
| `max_output_tokens` 상한을 요구사항으로 승격 | 서버 예산이 `prompt + max_tokens` 임을 실측. 첫 턴부터 깨질 수 있다 | — Pending |
| Cline 버전을 `CLINE_NO_AUTO_UPDATE=1` 로 고정 | 자동 업데이트 드리프트를 실측 재현. 버전이 바뀌면 설정 전제가 무너진다 | — Pending |
| 테스트는 cline-bench 공식 과제 사용 | 자작 테스트는 내가 아는 것만 검증한다. 공식 하니스가 더 정직하다 | — Pending |
| cline-bench 는 부분 실행 | 과제당 2400s 타임아웃 × 64s TTFT. 전 과제 완주는 비현실적 | — Pending |
| Tailscale 무인증 + LAN 토큰 | iPad 가 이미 테일넷에 있어 실사용 불편이 없다. LAN 은 같은 와이파이 = 셸 접근이라 막는다 | — Pending |
| 헤드리스는 래퍼만, 서비스화 보류 | 무엇이 호출할지 미정. 미정인 채로 서비스를 만들면 잘못된 모양이 굳는다 | — Pending |
| Telegram 은 토큰 자리를 비워 두고 구성 완료 | BotFather 는 사람만 할 수 있다. 나머지를 다 끝내 두면 토큰 한 줄로 끝난다 | — Pending |
| 작업공간 샌드박스 + 화이트리스트 | 원격에서 도는 에이전트가 홈 디렉터리 전체에 닿으면 안 된다 | — Pending |
| enable_thinking 생략 (기본 false) | VALIDATED — 코드 편집에는 thinking 이 불필요하고 가장 빠르다. 64s TTFT 에 더 얹을 수 없다 | — Pending |
| Compact Prompt 켬 | 32K 에서 전체 시스템 프롬프트는 작업 공간을 다 먹는다. MCP·Focus Chain 포기가 대가 | — Pending |
| 새 서비스를 `~/local-llm-settings` 에 등록 | 집 규칙. 나중에 이 기계 상태를 볼 때 누락이 없어야 한다 | — Pending |
| 매뉴얼은 사용법만 | 운영 런북은 성격이 다른 문서다. 섞으면 둘 다 읽기 나빠진다 | — Pending |
| 기존 Funnel(:8443→3000) 은 그대로 둔다 | 사용자 결정. 이 프로젝트 범위 밖이고 되돌리기 어려운 변경이다. 대신 3000 바인딩을 금지해 우회한다 | ✓ Good |

---
*Last updated: 2026-08-29 after research — 가드 제거, Core Value 재서술, 자동 업데이트 대응 추가*
