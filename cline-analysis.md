# Cline 로컬 운용 노트

> 조사 기준일 **2026-08-29** · `cline/cline` main 브랜치(마지막 푸시 2026-08-29) 소스 대조
> 웹 리포트: https://claude.ai/code/artifact/a90a6fad-9af4-4767-85c2-a7b92ab49243

저장소 구조, Qwen3.8-Flash-Next 로컬 연결, iPhone·iPad 원격 운용, 그리고 32k 컨텍스트에서의
정밀도·시간에 대해 GitHub에 **실제로 존재하는 근거**를 정리했다.

---

## 목차

- [§1 저장소 해부](#1-저장소-해부--확장-프로그램에서-에이전트-플랫폼으로)
- [§2 Qwen3.8-Flash-Next 로컬 연결](#2-qwen38-flash-next-로컬-연결)
- [§3 iPhone · iPad에서 쓰기](#3-iphone--ipad에서-쓰기)
- [§4 32k 컨텍스트에서의 정밀도와 시간 — GitHub 조사](#4-32k-컨텍스트에서의-정밀도와-시간--github-조사)
- [§5 실행 체크리스트](#5-실행-체크리스트)
- [출처](#출처)

---

## §1 저장소 해부 — 확장 프로그램에서 에이전트 플랫폼으로

| 항목 | 값 |
|---|---|
| Stars | 67,096 |
| Forks | 7,243 |
| Open issues | 1,139 |
| License | Apache-2.0 |
| Language | TypeScript |
| Created | 2024-07-06 |
| Last push | 2026-08-29 |

2024년의 Cline은 VS Code 사이드바에 붙는 코딩 확장이었다. 지금 저장소 설명은
*"Autonomous coding agent as an SDK, IDE extension, or CLI assistant"* 로 바뀌었고,
이 문장이 아키텍처를 그대로 요약한다. **하나의 에이전트 코어를 세 개의 표면이 공유한다.**

### 모노레포 구조

| 경로 | 역할 | 비고 |
|---|---|---|
| `sdk/packages/core` | 에이전트 루프, 도구, 컨텍스트 압축 | 세 표면의 공통 심장 |
| `sdk/packages/llms` | 프로바이더 스펙 · 모델 카탈로그 · 라우팅 | §4의 버그가 전부 여기서 나온다 |
| `apps/vscode` | VS Code 확장 + webview UI | 가장 기능이 완전한 표면 |
| `apps/cli` | 터미널 TUI · 헤드리스 · Kanban · 커넥터 | `npm i -g cline`, Node 22+ |

### 실제로 중요한 기능

- **Plan / Act 모드** — 탐색·설계 단계와 실행 단계를 분리. 로컬 모델에서는 Plan을 큰 모델로,
  Act를 작은 모델로 나누는 운용이 가능하다.
- **Checkpoints + diff 리뷰** — 파일 변경마다 스냅숏. 되돌리기가 git 커밋과 독립적이다.
- **Auto-compact** — 컨텍스트가 차면 잘라내는 대신 요약본으로 대체한다.
  임계값은 `autoCondenseThreshold`, 축소 목표는 `maxAllowedSize = max(ctx − 40000, ctx × 0.8)`.
- **MCP · .clinerules · Skills** — 외부 도구와 프로젝트 규약 주입.
- **Kanban** — `cline --kanban` → `localhost:3484`. 카드마다 git worktree를 따로 파고,
  의존 카드가 끝나면 다음 카드가 자동 시작된다.
- **커넥터** — Telegram / Slack / Discord / Google Chat / WhatsApp / Linear. §3의 핵심.

### 모델 프로바이더

Anthropic · OpenAI · Gemini · OpenRouter · Bedrock · Vertex · Cerebras · Groq,
그리고 로컬 쪽으로 **Ollama(11434) · LM Studio(1234) · Atomic Chat(1337) ·
임의의 OpenAI-compatible 엔드포인트**. BYOK가 1급 시민이라 벤더 락인이 없다.

### 냉정한 평가

| 강점 | 약점 |
|---|---|
| Apache-2.0 전면 오픈소스. 에이전트 루프를 직접 읽고 고칠 수 있다. | 토큰을 많이 쓴다. 전체 시스템 프롬프트가 무겁고, Compact Prompt를 켜면 MCP·Focus Chain·MTP가 꺼진다. |
| 세 표면(IDE / CLI / SDK)이 같은 코어를 쓰므로 동작이 일관된다. | 로컬 프로바이더의 컨텍스트 창 회계가 여전히 어긋난다 — §4 참조. |
| diff 편집 성공률을 실사용 텔레메트리로 관리한다 (Sonnet 4.5 96.2%, GLM-4.6 94.9%). | 미해결 이슈 1,139건. 기능 추가 속도가 버그 정리 속도를 앞선다. |

---

## §2 Qwen3.8-Flash-Next 로컬 연결

2026년 8월 26일 공개된 **Qwen3.8-Flash-Next**는 Qwen4 아키텍처의 프리뷰다.
본체 125B MoE에 51B N-gram 임베딩이 붙고, 토큰당 활성 파라미터는 6B.
4개 층 중 3개는 **Gated DeltaNet**으로 과거 컨텍스트를 고정 크기 순환 상태로 압축하고,
나머지 1개 층이 **Qwen Sparse Attention**으로 전체 컨텍스트를 정밀 조회한다.
네이티브 컨텍스트는 **262,144 토큰**, YaRN으로 1M까지 확장된다.

### 벤치마크

| 벤치마크 | Qwen3.8-Flash-Next | Claude Opus 4.6 Max |
|---|---:|---:|
| SWE-bench Pro | 62.5 | 53.4 |
| CoWorkBench | 73.9 | 68.2 |
| JobBench | 55.7 | 36.6 |
| SWE-bench Multilingual | 81.0 | — |
| LiveCodeBench v6 | 91.9 | — |

### 먼저 확인할 것: 메모리

MoE라도 **가중치 전체가 메모리에 올라가야 한다.** 활성 6B는 속도 이야기지 용량 이야기가 아니다.

| 양자화 | 파일 크기 | 필요 RAM | Top-1% 정확도 | 판단 |
|---|---:|---:|---:|---|
| BF16 | 355 GB | — | 100% | 서버 전용 |
| UD-Q4_K_XL | 111.3 GB | 112 GB | 93.5% | 128GB 통합메모리 Mac |
| UD-IQ3_XXS | 82 GB | 79 GB | 87.6% | 96GB에서 균형점 |
| UD-IQ1_S | 72.5 GB | 75 GB | 80.2% | 최소 구동선 |

> ⚠️ **현실 점검**
> Qwen3.8-Flash-Next를 Cline 에이전트 루프에 물리려면 **96GB 이상 통합 메모리**가 사실상 전제다.
> 그 아래라면 **Qwen3-Coder 30B-A3B(Flash)** 4-bit가 32GB에서, 8-bit가 64GB에서 실제로 돌아가는 대안이다.
> Cline 측 테스트에서 `gpt-oss-20b`, `seed-oss-36b`, `deepseek-r1-0528-qwen3-8b` 급은
> 도구 호출이 깨져 에이전트로 쓸 수 없었다.

### 경로 A — LM Studio (가장 쉬움)

1. LM Studio에서 `Qwen3.8-Flash-Next` GGUF를 받는다. Ollama·LM Studio 모두 자체 llama.cpp를
   번들하므로, 새 아키텍처를 지원하는 버전으로 **먼저 업데이트**한다.
2. 모델 로드 시 **Context Length = 262144**, **KV Cache Quantization = 해제**.
   KV 캐시 양자화를 켜두면 작업 간 컨텍스트가 남아 예측 불가능한 동작이 생긴다.
3. Developer 탭에서 서버 시작 → `http://127.0.0.1:1234`
4. Cline Settings → Provider **LM Studio** → 모델 선택 →
   **Context Window를 직접 262144로 입력** → **Use Compact Prompt 켜기**

### 경로 B — llama.cpp 직접 (제어권 최대)

```bash
# 1) 가중치
hf download unsloth/Qwen3.8-Flash-Next-GGUF \
    --local-dir qwen_models --include "*UD-IQ3_XXS*"

# 2) 서버 — 컨텍스트를 명시적으로 열어준다
./llama-server \
    --model qwen_models/UD-IQ3_XXS/Qwen3.8-Flash-Next-UD-IQ3_XXS-00001-of-00003.gguf \
    --ctx-size 262144 \
    --jinja \
    --temp 0.7 --top-p 0.80 --top-k 20 --min-p 0.0 --presence-penalty 1.5 \
    --host 127.0.0.1 --port 8080

# 3) Cline: Provider = OpenAI Compatible
#    Base URL  http://127.0.0.1:8080/v1
#    Model ID  서버가 보고하는 ID와 정확히 일치시킬 것
#    Context Window  262144  (수동 입력 — §4의 폴백을 덮어쓰기 위함)
```

`--jinja`는 모델 고유 함수 호출 포맷을 파싱하기 위해 필요하다.
사고 모드를 쓸 때는 `temp 1.0 / top-p 0.95 / top-k 20`,
깊이는 `reasoning_effort`를 `low · medium · xhigh`로 조절한다.
에이전트 루프에서는 `medium`이 시간 대비 합리적이다.

### 경로 C — vLLM / SGLang (다중 세션·팀)

```bash
vllm serve Qwen/Qwen3.8-Flash-Next \
    --max-model-len 262144 \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder
# vllm >= 0.15.0 필요. Cline은 OpenAI Compatible로 붙인다.
```

### Ollama를 쓸 경우 — 반드시 num_ctx를 박아야 한다

Ollama 서버 기본값은 4096이고, 초과분은 *조용히 버려진다.*
Cline은 자기 요청이 온전히 전달됐다고 믿고, 모델은 파편만 본다.

```dockerfile
# Modelfile
FROM qwen3.8-flash-next
PARAMETER num_ctx 262144
```

```bash
ollama create qwen38-fn-256k -f Modelfile
```

---

## §3 iPhone · iPad에서 쓰기

전제부터 분명히 하자. **Cline의 네이티브 iOS 앱은 없고, iPad에서 에이전트나 모델을
직접 돌릴 수도 없다.** 실제로 가능한 것은 "Mac이나 서버에서 도는 Cline을 아이폰에서
조종하기"이며, 이건 이제 공식 기능이다. 네 가지 경로를 실용성 순으로 정리한다.

### A. CLI 커넥터 — Telegram / Slack  *(공식 · 권장)*

Cline CLI가 메신저 봇으로 붙는다. 메시지 하나가 에이전트 세션 하나를 만들거나 이어가고,
파일 변경 알림과 질문이 폰으로 온다. 아이폰에서 프롬프트를 던지고, 승인·거부하고, 결과를 받는다.

```bash
# @BotFather 에게 /newbot → 토큰 획득
cline connect telegram -k <BOT-TOKEN> --allowed-user-id <내 텔레그램 ID>

# Slack: socket 모드면 공개 URL이 필요 없다
cline connect slack --bot-token <xoxb-…> --app-token <xapp-…>
```

- Slack은 **스레드 1개 = 세션 1개**로 맥락이 유지된다.
- Discord는 `/new`, `/tools`, `/yolo` 슬래시 커맨드를 제공한다.
- 커넥터는 여러 개를 동시에 띄울 수 있고 같은 허브를 공유한다.
- **제약:** 커넥터는 현재 Cline **CLI 전용**이다. VS Code 확장에는 없다.

### B. Kanban 보드 + Tailscale → Safari  *(iPad에 최적)*

`cline --kanban` 이 `localhost:3484`에 웹 UI를 띄운다. Tailscale로 맥을 테일넷에 올리면
iPad Safari에서 그대로 열린다. 카드별 git worktree, 실시간 diff 리뷰, 인라인 코멘트가
터치로 된다 — 아이패드에서 "읽고 승인하는" 워크플로에 가장 잘 맞는다.

```bash
tailscale up
cline --kanban
# iPad Safari → http://<맥의-테일넷-이름>:3484
```

### C. SSH + tmux — Blink Shell / Termius  *(가장 가벼움)*

Blink Shell로 맥에 SSH → `tmux` 안에서 `cline` TUI를 그대로 쓴다.
세션이 끊겨도 tmux가 붙잡아준다. 긴 작업은 `cline -z`(zen 모드)로 백그라운드에 던지고
터미널을 회수할 수 있다.

단점은 명확하다. diff를 좁은 화면의 터미널에서 읽어야 한다.
매직 키보드 없는 아이폰에서는 A 경로가 낫다.

### D. code-server / VS Code 터널  *(기능 완전 · 무거움)*

맥이나 서버에 code-server를 올리고 Safari로 접속하면 **Cline VS Code 확장 전체**가
그대로 돌아간다. Plan/Act 토글, 체크포인트, MCP 패널까지 iPad에서 쓸 수 있는 유일한 경로다.
Tailscale + Caddy 조합이 정석이며, 포트 포워딩보다 훨씬 안전하다.

> 🔒 **보안**
> - Telegram 커넥터에 `--allowed-user-id`를 **반드시** 건다. 없으면 봇 토큰을 아는 누구나 당신의 셸이다.
> - 더 세밀하게는 `--hook-command`로 검증 스크립트를 물려 `{"action":"allow"}` / `{"action":"deny"}`를 반환하게 한다.
> - 메신저 브리지에 `--auto-approve`나 `/yolo`를 켜지 말 것. 폰에서는 무엇을 승인하는지 제대로 읽을 수 없다.
> - 3484 포트를 인터넷에 직접 노출하지 말고 Tailscale을 쓴다.

---

## §4 32k 컨텍스트에서의 정밀도와 시간 — GitHub 조사

### 조사 결론

> **"Cline을 32k 컨텍스트로 고정하고 정밀도와 소요 시간을 측정한" 공개 GitHub 벤치마크는 존재하지 않는다.**
>
> 대신 세 갈래의 자료가 있고, 이것들을 합치면 실무 판단에는 충분하다 —
> ① Cline 자체 하니스(컨텍스트는 변수가 아님),
> ② 32k를 명시적 구간으로 두는 학술 벤치마크(에이전트가 아닌 모델 단위),
> ③ Cline 저장소에 쌓인 32k·128k 관련 **버그 리포트**.
> 그리고 이 버그들이야말로 32k 운용에서 실제로 사람을 무너뜨리는 요인이다.

### ① Cline 자체 평가 하니스 — 컨텍스트 축이 없다

[cline/cline-bench](https://github.com/cline/cline-bench)(36★)는 실사용 세션에서 뽑은 과제를
Harbor 포맷으로 담는다. 각 과제는 `instruction.md` · `task.toml` ·
`environment/Dockerfile`(깨진 초기 상태) · `solution/solve.sh` · `tests/` 로 구성되고,
Daytona에서 실행된다. 별도로 Terminal-Bench 2.0 기반 89개 과제로 CLI 전체를 돌리는 평가가 있다.

| 측정 | 값 | 비고 |
|---|---:|---|
| 과제 수 | 89 | Terminal-Bench 2.0 |
| 과제당 타임아웃 | 2,400 s | "시간"은 이 상한으로만 관리된다 |
| 전체 1회 실행 | 40–50 분 | Modal 병렬화 기준 |
| 기준선 6회 | .49 .43 .45 .44 .48 .46 | 중앙값 45.8% — 실행 간 편차가 크다 |
| 개선 후 | 47% → 57% | 스캐폴드 수정만으로 |

diff 편집 성공률은 실사용 텔레메트리로 따로 관리된다:
Sonnet 4.5 **96.2%**, GLM-4.6 **94.9%**, Sonnet 4 95.8%.
diff-apply 알고리즘 교체 때 Sonnet 3.5는 약 25%p, GPT-4.1은 21%p 이상 올랐다.
**어느 쪽에도 컨텍스트 창 크기는 실험 변수로 들어가 있지 않다.**

### ② 32k를 명시 구간으로 두는 학술 벤치마크

[LongCodeBench](https://arxiv.org/abs/2505.07897)는 실제 GitHub 이슈에서 QA·버그수정 과제를 만들고
32K / 64K / 128K / 256K / 512K / 1M 구간에서 평가한다. **결과가 직관과 반대다.**

| 과제 | 32K | 128K | 256K+ |
|---|---:|---:|---|
| LongCodeQA (정확도 범위) | 61.9–75.2% | 67.4–78.3% | Qwen2.5: 512K 70.2% → 1M 40% |
| LongSWE-Bench · Claude 3.5 Sonnet | 29% | — | 256K에서 **3%** |
| LongSWE-Bench · Gemini 2.5 Pro | 23% | — | 1M에서 **7%** |

> 💡 **핵심 시사점**
> 코드 *편집* 과제에서 성능은 **64K–128K 부근에서 정점**을 찍고 그 위로는 급락한다.
> **32k는 "부족한 설정"이 아니라 정점에서 크게 벗어나지 않은 지점이다.**
> 32k에서 Cline이 실패한다면 원인은 컨텍스트 창의 크기가 아니라,
> 그 32k 안에 무엇이 들어갔는가와 **회계가 맞는가**다.

비용·시간 감각도 이 논문에 있다: Claude 3.5 Sonnet의 LongCodeQA 1회 평가에 약 **$100**,
Qwen2.5 자체 호스팅은 4×A100 64GB에서 **35시간**이 걸렸다.
[SWE Context Bench](https://arxiv.org/abs/2602.08316)(2026-02)도 컨텍스트 규모 대비 정확도와
비용을 다루지만 역시 에이전트 스캐폴드는 평가하지 않는다.

### ③ 32k에서의 "시간"을 실제로 재는 도구

[ivanfioravanti/llm_context_benchmarks](https://github.com/ivanfioravanti/llm_context_benchmarks)가
이 빈칸을 메운다. Ollama·MLX 백엔드로 0.5k~128k 구간을 훑으며 프롬프트 처리 TPS, 생성 TPS,
**TTFT**, TPOT, KV 캐시 메모리, perplexity, 양자화 간 KL divergence를 기록한다.
다만 결과 테이블이 동봉된 게 아니라 프레임워크이며, 하드웨어별 결과는 PR로 모인다.
Cline의 32k 왕복 지연을 직접 재려면 이 도구로 자기 장비의 곡선을 먼저 뽑는 게 맞다.

### ④ 실제로 존재하는 32k 근거는 "벤치마크"가 아니라 "버그"다

cline/cline 이슈 트래커를 훑으면 32.8k / 128k 라는 숫자가 반복해서 나온다.
전부 **선언한 컨텍스트와 Cline이 실제로 쓰는 컨텍스트가 어긋나는** 같은 계열의 문제다.

| 이슈 | 상태 | 환경 | 증상 |
|---|---|---|---|
| [#6494](https://github.com/cline/cline/issues/6494) | closed · **not planned** | Cline 3.32.0 · Qwen3 Next 80B · 설정 262,144 | 설정은 262,144인데 사용량 바는 32.8k. P2로 분류 후 닫힘 |
| [#10375](https://github.com/cline/cline/issues/10375) | open · stale | Cline 3.80.0 · lmstudio/qwen3.6-35b-a3b · 설정 262,144 | 표시 상한이 32.8k라 초과 시 퍼센트가 100%를 넘음 |
| [#13457](https://github.com/cline/cline/issues/13457) | **open** (2026-08-21) | Cline 4.1.11 · llama.cpp · Gemma 4 31B / Qwen 3.6 27B / **Qwen 3.8 27B** | LM Studio에서 200k로 잡아도 **실제로 128k 기준으로 압축이 돈다.** 표시만의 문제가 아님 |
| [#12520](https://github.com/cline/cline/issues/12520) | **open** | Cline CLI 3.0.46 · 선언 1,048,576 | `Context compacted · 115.3k → 62.2k`. 115.2k ≈ 128,000 × 0.9 — 폴백값 사용의 결정적 증거. 비용 표시도 $0.00에 멈춤 |
| [#7772](https://github.com/cline/cline/issues/7772) | closed | llama-server | auto-compact 미발동 → 창을 넘겨 계속 진행 → 뒤늦은 수동 압축 실패 |
| [#9433](https://github.com/cline/cline/issues/9433) | open | OpenAI-compatible | 서버가 `usage: null` 반환 시 바가 0%에 머묾 |
| [#7383](https://github.com/cline/cline/issues/7383) | open | — | UI는 50%인데 API에는 100%가 감 (약 100K 차이) |

### 소스 확인 — 32,768과 128,000은 어디서 오는가

이슈만 읽으면 추측이므로 오늘자 `main`을 직접 열어 확인했다. **세 곳이다.**

**1) Ollama 폴백 — `sdk/packages/llms/src/providers/builtins.ts:100`**

```ts
/* 모델이나 사용자 설정 어느 쪽도 컨텍스트를 주지 않을 때 Ollama에 요청하는 값.
   Ollama 서버 기본값 4096은 Cline의 에이전트 프롬프트를 담을 수 없어 의도적으로 크게 잡았다. */
export const OLLAMA_DEFAULT_CONTEXT_WINDOW = 32768;
```

**2) openai-compatible 폴백 — `builtins.ts` / `fallbackModelInfo()`**

```ts
if (spec?.family === "openai-compatible") {
    info.contextWindow  = 128_000;
    info.maxInputTokens = 128_000;
}
// LM Studio·llama.cpp 등은 openai-compatible 계열로 해석된다 → #13457
```

**3) 카탈로그 조회를 막는 단락 — `sdk/packages/llms/src/providers/compat.ts:629`**

```ts
function resolveModelInfo(config: ProviderConfig): ModelInfo {
    return (
        config.modelInfo ??                                        // ① 폴백 객체가 여기서 먼저 잡히고
        (config.modelId ? config.knownModels?.[config.modelId] : undefined) ??  // ② 카탈로그는 영영 안 본다
        { id: config.modelId, name: config.modelId, capabilities: ["streaming"] }
    );
}
```

`??`는 `null`/`undefined`일 때만 다음으로 넘어간다. 폴백이 이미 *비어 있지 않은 객체*를
만들어 두면 실제 모델 카탈로그의 `contextWindow`는 절대 도달하지 않는다.
이것이 **#12520의 정확한 근인**이며, 오늘자 main에도 그대로 있다.

### 그래서 32k에서 실제로 무슨 일이 벌어지는가

Cline의 압축 임계값은 `maxAllowedSize = max(ctx − 40000, ctx × 0.8)`이다.
여기에 숫자를 넣어보면 32k 운용의 성격이 드러난다.

| 구간 | 토큰 | 근거 |
|---|---:|---|
| Qwen3.8-Flash-Next 네이티브 선언 | 262,144 | 서버에서 열어둔 값 |
| Cline 실효값 — openai-compatible 폴백 | 128,000 | #13457 · #12520 — 압축은 115,200에서 발동 |
| Cline 실효값 — Ollama 폴백 | **32,768** | `builtins.ts:100` — 이것이 문제의 "32k"다 |
| 32,768 설정 시 **실제 압축 시작점** | **26,214** | `max(32768 − 40000, 32768 × 0.8)` → −40000 분기는 200k 미만에서 무의미 |
| 남는 작업 공간 (전체 시스템 프롬프트 사용 시) | ≈ 13k | Compact Prompt는 전체 프롬프트의 약 10% |

> ⚠️ **32k 운용 수칙**
> 1. 32k에서는 **Compact Prompt를 반드시 켠다.** 대신 MCP·Focus Chain·MTP를 포기한다.
> 2. 압축은 **26.2k에서 시작**한다. 26k를 "작업 예산"으로 보고 과제를 잘게 쪼갠다.
> 3. **Cline UI의 컨텍스트 바를 믿지 말 것.** #10375·#9433·#7383이 모두 표시 신뢰성 문제다.
>    실제 사용량은 추론 서버 로그에서 확인한다.
> 4. Ollama라면 Modelfile의 `num_ctx`와 Cline의 Context Window 입력란 **양쪽**을 명시한다.
>    어느 한쪽만 하면 32,768 폴백이 조용히 이긴다.
> 5. 압축이 아예 안 도는 정황(#7772)이 보이면 그 자리에서 새 태스크로 넘어간다.
>    넘긴 뒤의 수동 압축은 실패한다.

---

## §5 실행 체크리스트

| 상황 | 선택 | 설정 요점 |
|---|---|---|
| 통합 메모리 128GB+ | Qwen3.8-Flash-Next UD-Q4_K_XL (93.5% 정확도 유지) | ctx 262144 · KV 양자화 off · Compact Prompt 선택 |
| 96GB | Qwen3.8-Flash-Next UD-IQ3_XXS (균형점) | ctx 262144 · reasoning_effort medium |
| 64GB | Qwen3-Coder 30B-A3B 8-bit | Cline 기능 전체 사용 가능 |
| 32GB | Qwen3-Coder 30B-A3B 4-bit @ 32K | Compact Prompt 필수 · 작업 예산 26k |
| 아이폰에서 조종 | Telegram 커넥터 | `--allowed-user-id` 필수 · auto-approve 금지 |
| 아이패드에서 리뷰 | Kanban + Tailscale | Safari → `테일넷이름:3484` |
| 아이패드에서 전체 기능 | code-server | Tailscale + Caddy · 포트 직접 노출 금지 |

> **한 문장 요약**
> Cline의 32k 문제는 모델의 한계가 아니라 **회계의 문제**다.
> 컨텍스트 창을 서버·Cline 양쪽에 명시적으로 못 박고 Compact Prompt를 켜면,
> 32k는 코드 편집 과제에서 충분히 쓸 만한 구간이다 —
> LongCodeBench가 보여주듯 오히려 성능 정점에 가깝다.

---

## 출처

- [github.com/cline/cline](https://github.com/cline/cline) — 저장소 메타데이터 및 소스 코드(`builtins.ts`, `compat.ts`) 직접 확인
- 이슈 [#6494](https://github.com/cline/cline/issues/6494) · [#10375](https://github.com/cline/cline/issues/10375) · [#13457](https://github.com/cline/cline/issues/13457) · [#12520](https://github.com/cline/cline/issues/12520) · [#7772](https://github.com/cline/cline/issues/7772) · [#9433](https://github.com/cline/cline/issues/9433) · [#7383](https://github.com/cline/cline/issues/7383)
- [cline/cline-bench](https://github.com/cline/cline-bench) — 실사용 기반 벤치마크 과제
- [Cline — A Practical Guide to Hill Climbing](https://cline.bot/blog/a-practical-guide-to-hill-climbing) (Terminal-Bench 2.0, 89 tasks)
- [Cline — Improving Diff Edits by 10%](https://cline.bot/blog/improving-diff-edits-by-10)
- [Cline + LM Studio: Qwen3 Coder 30B](https://cline.bot/blog/local-models) · [AMD 로컬 모델 테스트](https://cline.bot/blog/local-models-amd)
- [Cline Docs — Running Models Locally](https://docs.cline.bot/running-models-locally/read-me-first) · [Auto Compact](https://docs.cline.bot/features/auto-compact)
- [Cline Docs — Connectors](https://docs.cline.bot/cli/connectors) · [Cline CLI](https://cline.bot/cli)
- [QwenLM/Qwen3.8-Flash-Next](https://github.com/QwenLM/Qwen3.8-Flash-Next) · [Unsloth 로컬 실행 가이드](https://unsloth.ai/docs/models/qwen3.8-next)
- [LongCodeBench (arXiv 2505.07897)](https://arxiv.org/abs/2505.07897) · [SWE Context Bench (arXiv 2602.08316)](https://arxiv.org/abs/2602.08316)
- [ivanfioravanti/llm_context_benchmarks](https://github.com/ivanfioravanti/llm_context_benchmarks)
- [Tailscale — code-server on iPad](https://tailscale.com/kb/1166/vscode-ipad) · [code-server iPad 문서](https://coder.com/docs/code-server/ipad)
