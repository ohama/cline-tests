# 32K 압축(Compaction) 실측 결과와 대응 방침 (VER-04)

> **2026-08-30 전면 정정.** 이 문서의 1차 결론(결과 ② — 압축 불가)은 **오설정 상태의 측정**이었다.
> 측정 자체는 정확했으나 원인 진단이 틀렸다. 아래 §1~§5 가 현재 유효한 내용이고,
> 정정 전 기록은 §9 부록에 원문 그대로 보존한다.

## 1. 결론 (한 줄)

**자동 압축은 정상 작동한다.** `contextWindow` 를 `providers.json` 의 **`settings` 최상위**에
넣으면 트리거가 발동하고, 32K 벽에 닿지 않은 채 작업이 계속된다.
증거: `phase-01/results/exp-verify29k/` (필러 18개 완주, 압축 3회 이상, **서버 400 0건**, 8분 22초).

1차 결론이 "압축 불가"였던 이유는 #12520 버그가 아니라, `contextWindow` 를 **`models[]` 안에**
넣었기 때문이다. `models[]` 는 VS Code 용 per-model override 경로이고 **CLI 는 읽지 않는다.**

## 2. 근본 원인 — 어느 칸에 넣느냐

소스 근거 (`cline/cline`, tag `cli-v3.0.53`):

| 위치 | 내용 |
| --- | --- |
| `sdk/packages/core/src/services/llms/provider-settings.ts:150` | `contextWindow: z.number().int().positive().optional()` — **settings 최상위** 스키마 필드 |
| `sdk/packages/core/src/services/llms/provider-settings.ts:266` | `maxInputTokens: settings.contextWindow` — 최상위 값이 여기로 매핑된다 |
| `sdk/packages/core/src/services/llms/handler-factory.ts` | 주석: *"`maxInputTokens` is where `ProviderSettings.contextWindow` lands via `toProviderConfig` (the providers.json path used by CLI/Core hosts)"* |

```jsonc
// ✅ 올바름 — CLI 가 읽는 경로
"settings": { "provider": "openai-compatible", "model": "flashnext",
              "baseUrl": "http://localhost:4000/v1",
              "contextWindow": 29000 }

// ❌ 틀림 — VS Code 용 경로. CLI 는 무시하고, 기동 시 정규화하면서 버린다
"settings": { "models": [ { "id": "flashnext", "contextWindow": 32768 } ] }
```

부수 효과: 어제부터 반복되던 **"providers.json 필드가 사라진다"(Pitfall 5)** 도 같은 원인이었다.
`models[]` 는 정규화 대상이라 버려졌고, 최상위 `contextWindow` 는 살아남는다.
`check_versions.sh` 의 `cline config --json` 호출 뒤에도 유지됨을 확인했다.

## 3. 트리거 공식 — ×0.9 이지 ×0.81 이 아니다

```
maxInputTokens 가 있으면   trigger = maxInputTokens × 0.9
없으면(폴백)                trigger = contextWindow × 0.9 × 0.9
```

최상위 `contextWindow` 는 `maxInputTokens` 로 **직행**하므로 우리 설정에서는 **×0.9 한 번**뿐이다.
실측으로 두 번 확인: `12000 → triggerTokens 10800`, `29000 → triggerTokens 26100`.
1차 조사가 기록한 `×0.9×0.9 = 0.81` 은 `maxInputTokens` 가 없을 때의 폴백 경로였다.

## 4. 왜 32768 이 아니라 29000 인가 — 오버슈트

압축은 트리거를 넘는 **즉시** 발동하지 않는다. 한 턴 늦게 반응해서 실측 **2,700~3,100 토큰**을
초과한 뒤에 돈다. 서버 예산은 `prompt_tokens + max_tokens ≤ 32768`, `max_tokens` 실측값은 `2048`.

| `contextWindow` | trigger | +오버슈트 | +max_tokens | 판정 |
| ---: | ---: | ---: | ---: | --- |
| 32,768 | 29,491 | 32,591 | 34,639 | ❌ 벽을 넘는다 |
| **29,000** | **26,100** | **29,230** | **31,278** | ✅ **실측 완주** |

실측 압축 기록 (`exp-verify29k`):

```
iter  8   28,409 → 22,165   (메시지 15 → 9)
iter 10   29,136 → 22,250   (13 → 9)
iter 12   29,230 → 22,045   (13 → 9)
```

## 5. 운영 방침

1. **`settings.contextWindow = 29000`.** `models[]` 는 두지 않는다.
   `phase-01/config/apply_provider_config.sh` 가 이 상태를 강제하고,
   `verify_config.sh` 가 검사한다(최상위가 없거나 `models[]` 가 있으면 FAIL).
2. **작업 크기 제한은 불필요하다.** 압축이 대역을 유지하므로 긴 세션도 완주한다
   (필러 18개 = 누적 30k 초과 시나리오에서 검증).
3. **UI 는 "압축 중"을 표시해야 한다.** 압축 자체가 요약 호출을 발생시켜 지연을 만든다
   (실측: 압축 턴에 요약용 짧은 호출 ~458 토큰이 추가로 발생). Phase 6 NET-05 에 반영.
4. **`contextWindow` 를 올릴 때는 오버슈트를 함께 계산한다.**
   `trigger + 3,100 + max_tokens < MAX_KV_SIZE` 를 만족해야 한다.
5. **서버 400 은 여전히 회복 불가다.** 압축이 정상 작동하면 도달하지 않지만,
   설정이 틀린 칸으로 되돌아가면 다시 발생한다. Cline 의 오류 분류기는 이 스택의
   `MAX_KV_SIZE` 문구를 인식하지 못하므로(정규식 8개 전부 불일치) 자가 복구가 없다.
   따라서 **`verify_config.sh` 가 상시 가드**다.

## 6. 재현 방법

```bash
bash phase-01/config/apply_provider_config.sh   # 최상위 contextWindow=29000 강제
bash phase-01/config/verify_config.sh           # 통과해야 함
FILLER_COUNT=18 bash phase-01/run_regression.sh # 압축 발동 + 서버 400 0건 기대
```

## 7. 이 정정이 바꾸는 것

| 대상 | 이전 | 이후 |
| --- | --- | --- |
| CFG-02 | `models[].contextWindow: 32768` | `settings.contextWindow: 29000` |
| Phase 4 래퍼 | 400 을 종료 조건으로 처리 | 불필요 (정상 설정 시 도달 안 함) |
| Phase 6 NET-05 | "작업 중" 표시 | "압축 중" 상태 추가 |
| Phase 7 벤치 | 과제당 토큰 예산 제한 | 불필요 |
| Phase 8 매뉴얼 | "32k 에서 작업이 죽는다" | "압축되며 계속 간다 / 설정 위치 주의" |

Phase 5(서비스 감독)는 컨텍스트를 다루지 않으므로 영향 없음 — 플랜 7개를 검색해 확인했다.

## 8. 미해결

- **`cline` 자동 업데이트가 `CLINE_NO_AUTO_UPDATE=1` 로 막히지 않는다.** 이 정정 작업 중에도
  3.0.53 → 3.0.60 드리프트가 재현됐다. CFG-05 의 성공 기준이 위태롭다. 별도 과제.
- `providers.json` 의 `maxTokens` 는 여전히 미적용(실측 2048 고정). Branch A 라 문제되지 않는다.

---

## 9. 부록 — 정정 전 기록 (오설정 상태의 실측)

아래는 `contextWindow` 를 `models[]` 안에 넣었을 때의 원문 기록이다. **측정값은 모두 유효하며**,
"CLI 가 읽지 않는 칸에 설정을 넣으면 무슨 일이 벌어지는가"의 증거로서 보존한다.
결론 문장만 §1 로 대체됐다.

<details>
<summary>원문 펼치기</summary>


## 1. 결론 (한 줄)

**2026-08-29, cline `3.0.53`, 실측 결과 ② — 압축은 발동하지 않았고, 서버가 `MAX_KV_SIZE=32768`
초과로 HTTP 400 을 거부했다.** 증거: `phase-01/results/2026-08-29T095321Z-44990/verdict.md`
(및 `ndjson.log`, `flashnext_window.log`, `oracle-crosscheck.txt` — 같은 디렉터리).

이것은 로드맵 성공 기준 5가 명시적으로 통과로 인정하는 결과다: 압축이 안 뜨는 것 자체는 실패가
아니며, 실측 증거와 이 문서(대응 방침)가 존재하는 것이 통과 조건이다.

## 2. 증거

| 항목 | 값 | 출처 |
|---|---|---|
| 설정된 `contextWindow` | `32768` (Plan 05 Branch A — `max_tokens` 완화 불필요, 값 변경 없음. Branch B2 였다면 CFG-02 편차 노트가 `.planning/REQUIREMENTS.md`에 있어야 하지만, Branch A 이므로 없음) | `providers.json` (이 실행 시점 스냅샷: `phase-01/results/2026-08-29T095321Z-44990/providers.json`) |
| 예측 트리거 (derived, `contextWindow × 0.9 × 0.9`) | `int(32768 × 0.9 × 0.9) = 26542` | `phase-01/run_regression.sh` Preflight C가 매 실행마다 라이브로 재계산 (하드코딩 아님) |
| 관측된 최대 per-iteration `usage.inputTokens` (API 오라클) | `30505` | `ndjson.log` |
| 관측된 서버 측 최대 `prompt_tokens=` (서버 로그 오라클) | `30505` | `flashnext_window.log` |
| 두 오라클 일치 여부 | **완전 일치 (차이 0%, 허용 임계 15%)** | `phase-01/results/2026-08-29T095321Z-44990/oracle-crosscheck.txt` |
| `MAX_KV_SIZE` | `32768` | flashnext 서버 설정 (`--max-kv-size 32768`, `com.ohama.flashnext` 프로세스 인자) |
| 관측된 wire `max_tokens` | `2048` (Plan 05 CFG-03 실측; `providers.json`의 `maxTokens=4096`은 미적용) | `docs/cline-max-tokens-findings.md` |

**판정 근거는 `--json` NDJSON 스트림의 `usage` 이벤트와 `flashnext.err`의 `prompt_tokens=` 줄이며,
Cline TUI 진행률 표시줄이 아니다 (VER-02).** 이 회귀는 애초에 `--json` 헤드리스 모드로만 실행되어
TUI 자체가 없다.

### 결정적 원본 증거 (verbatim)

서버 로그(`flashnext_window.log`, 서버가 요청을 거부한 순간):

```
2026-08-29 19:06:26,996 - WARNING - Request failed: endpoint=/chat/completions
model=/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4 stream=True
error=Request needs 33998 context tokens (31950 prompt + 2048 max generation), but MAX_KV_SIZE is 32768. in_flight=0
```

NDJSON(`ndjson.log`, litellm이 감싼 동일한 오류가 Cline의 agent_event로 전달됨):

```json
{"type":"agent_event","event":{"type":"error","error":{
  "name":"Error",
  "message":"litellm.BadRequestError: OpenAIException - Error code: 400 - {'detail': 'Request needs 33998 context tokens (31950 prompt + 2048 max generation), but MAX_KV_SIZE is 32768.'}. Received Model Group=flashnext\nAvailable Model Group Fallbacks=None"
}}}
```

이 실행 전체(19번의 반복, 18개 filler 파일)에서 `auto-compact*` 또는 `overflow-recovery-compact*`
로 시작하는 `notice` 이벤트는 **단 한 번도** 없었다 (`grep -c '"type":"notice"' ndjson.log` → `0`).
peak_input_tokens(30505)는 예측 트리거(26542)를 3,963 토큰 초과한 상태였다 — 압축이 뜰 기회는
있었고, 뜨지 않았다.

## 3. 세 가지 결과와 대응 방침

### ① ~26.5k 에서 압축 발동

(이번 실측 결과 아님 — 실측에서 압축 notice 는 0건이었다)

- 오버라이드(`contextWindow=32768`)가 실제 압축 임계값 계산에 반영된다는 뜻.
- 작업당 실사용 가능 예산은 대략 `trigger − baseline 시스템 프롬프트(≈5,500 토큰 실측, Plan 05)`.
- 압축은 요약 왕복(round trip) 비용이 든다 — 압축 1회마다 추가 지연이 생긴다는 뜻이므로, 압축
  발생 자체를 사용자에게 숨기면 안 된다.
- Kanban/Telegram 은 "압축 중" 을 별도 상태로 표시해야 한다.
- 압축 전후 `tokensBefore → tokensAfter` 비율을 실측해 기록해 두면, 이후 단계에서 "압축 후 얼마나
  많은 대화 이력이 살아남는지"를 예측할 수 있다.

### ② 압축 없이 32,768 에서 서버 400 — ← 이번 실측 결과

이번 실행에서 실제로 관측된 결과다. `contextWindow` 오버라이드가 라이브 압축 체크에 도달하지
못했다는 뜻이거나(연구 단계의 MEDIUM-LOW 신뢰도 추정과 일치), 128k 기본값 경로가 실제로 이긴
것으로 보인다(그 경우 트리거는 ≈103,680 이 되어 이번 실행의 peak인 30,505 로는 애초에 도달 불가능
한 값이다 — 어느 경로든 결론은 같다: **이 스택에서 압축은 서버 벽보다 먼저 뜨지 않는다**).

방침은 구체적이어야 한다:

* **Cline 은 이 오류에서 스스로 복구하지 않는다.** Cline 의 overflow-recovery 분류기는 HTTP
  400/413/422 **이고 동시에** 8개의 하드코딩된 정규식 또는 리터럴 코드 `context_length_exceeded`
  중 하나와 일치해야만 `context_window_exceeded` 로 분류한다. `mlx_vlm.server` 가 실제로 보내는
  본문 — `"Request needs N context tokens (P prompt + M max generation), but MAX_KV_SIZE is
  32768."` — 은 그 어느 것과도 일치하지 않는다 ("context tokens" ≠ "context length/window/limit";
  "exceed" 없음; "too long" 없음; "reduce the length" 없음). 이번 실측에서도 정확히 이 예측대로
  `overflow-recovery-compact*` notice 는 0건이었고, 작업은 그냥 `finishReason: "error"` 로
  죽었다 (iteration 19, `run_result.durationMs=783502`).
* 따라서 운영 규칙은 **"작업을 다시 시작한다"** 이지, "기다리면 회복된다"가 아니다.
* 작업당 하드 예산: 대화를 대략 26k 토큰 이하로 유지한다. 큰 작업은 작은 작업들로 쪼갠다. 긴
  작업을 이어가려 하지 말고 새 작업을 시작한다.
* 화면(surface)이 해야 할 일: Kanban 과 Telegram 은 조용히 멈추는 대신 죽은 작업의 오류를
  그대로 노출해야 한다. Phase 4 의 헤드리스 래퍼는 `MAX_KV_SIZE` 400 을 **터미널(재시도 불가)
  실패**로 취급하고 그렇게 출력해야 한다.
* 의도적으로 하지 않은 것: litellm/role_shim 에 클램프(clamp)를 추가하지 않았다 (범위 밖 결정 —
  서버가 이미 prefill 이전에 거부하므로 이중 방어가 실익이 적다는 로드맵 결정, `.planning/STATE.md`
  기록 참조). 업스트림(Cline)에 PR 도 내지 않았다.

### ③ 그 외 (below_trigger / unexpected)

(이번 실측에서 run 1 이 여기 해당했다 — 아래 참고)

- **below_trigger**: 실행이 정상 종료(`finishReason=completed`)했지만 peak `inputTokens` 가
  예측 트리거에 못 미친 경우. 미확정이며, 다음 진단 단계는 `FILLER_COUNT` 를 늘려 재실행하는 것
  이다. 이번 실측의 run 1(`phase-01/results/2026-08-29T094459Z-42449/`, 12개 filler 파일)이
  정확히 이 경우였다: peak_input_tokens=23266 < predicted_trigger=26542. `FILLER_COUNT=18` 로
  재실행(run 2)해 실제로 트리거를 넘겨 ②를 확정했다.
- **unexpected**: 타임아웃, 크래시, 또는 컨텍스트와 무관한 오류. 다음 진단 단계는 원본 NDJSON
  스트림 조사와 오라클 크로스체크 확인.
- 결론이 나기 전까지의 잠정 방침: **②의 규칙을 그대로 따른다** (보수적 태도) — "작업을 다시
  시작한다"를 기본으로 가정한다.

## 4. 재실행 방법

```bash
cd /Users/ohama/projs/cline-tests
bash phase-01/config/verify_config.sh          # providers.json 드리프트 가드 (RESEARCH.md Pitfall 5)
bash phase-01/config/check_versions.sh         # cline/kanban 버전 드리프트 가드
bash phase-01/run_regression.sh                # 실제 회귀 실행 (기본 12개 filler 파일)
```

노브(knob):

- `FILLER_COUNT=18 bash phase-01/run_regression.sh` — filler 파일 개수 변경(재실행 전
  `python3 phase-01/filler/gen_filler.py --count 18` 로 해당 개수만큼 파일을 먼저 생성해야 함).
- `RUN_TIMEOUT=<초>` — `cline -t` 타임아웃 (기본 1800초).
- `RUN_DRY=1` — 실제 모델 호출 없이 전체 파이프라인만 오프라인으로 검증 (fixture NDJSON 사용).

**경고: 실행 중 다른 무거운 작업(Docker, 빌드, 다른 모델 트래픽)을 동시에 돌리지 말 것.** 32K
컨텍스트에서 헤드룸이 좁고, 이번 실측 중 `cline` 이 `CLINE_NO_AUTO_UPDATE=1` 에도 불구하고 호출
때마다 백그라운드 `npm update cline` 를 트리거해 3.0.53 → 3.0.60 으로 드리프트하는 것이 반복
재현되었다 (실행 직전 `npm install -g cline@3.0.53` 로 재고정 필요 — `check_versions.sh` 가
이를 감지한다).

## 5. 후속 단계에 미치는 영향

> ⛔ **아래 하위 페이즈 지시문은 전부 무효다 (2026-08-30).** 오설정 상태를 전제로 쓰였다.
> 현재 유효한 지시는 이 문서 §7 을 볼 것.

- **DOC-04** (Phase 8, 32K 운용 주의): 이 문서의 결론(②, 압축 미발동, 작업당 하드 예산, "새 작업
  시작" 규칙)을 그대로 재현해야 한다.
- **Phase 5** Kanban/Telegram: ②가 관측되었으므로 "죽은 작업" 상태를 명확히 노출해야 한다 (①이
  관측되었다면 "압축 중" 상태가 필요했을 것이나, 이번 실측에서는 해당 없음).
- **Phase 4** 헤드리스 래퍼: `MAX_KV_SIZE` 를 포함하는 400 을 **터미널, 재시도 불가** 실패로
  분류해야 한다 — Cline 자신은 이를 분류하지 못하므로 래퍼가 대신 해야 하는 일이다.
- **Phase 7** cline-bench 작업 선택: 작업당 토큰 예산을 이 문서의 실측치(트리거 26542, 관측
  peak 30505 에서 거부) 기준으로 설계해야 한다 — 26k 근처에서 작업을 분할하는 것이 안전하다.

## 6. 이 결론이 무효가 되는 조건

| 조건 | 감지 명령 |
|---|---|
| `cline --version` 이 `3.0.53` 에서 벗어남 | `cline --version` |
| `providers.json` 이 재적용되거나(다른 설정으로) 스트립됨 | `bash phase-01/config/verify_config.sh` |
| `com.ohama.flashnext` 의 `--max-kv-size` 인자가 `32768` 이 아니게 됨 | `launchctl print gui/$UID/com.ohama.flashnext \| grep -A2 max-kv-size` 또는 `ps -o command= -p <pid> \| grep -o 'max-kv-size [0-9]*'` |
| 관측된 wire `max_tokens` 가 `2048` 에서 변함 | `docs/cline-max-tokens-findings.md` 의 재-프로브 절차 (`phase-01/results/max-tokens-probe/` 방식) 재실행 |

이 중 하나라도 참이면, 이 문서의 ② 결론은 재검증 없이는 신뢰할 수 없다 — `bash
phase-01/run_regression.sh` 를 다시 돌려 새 증거 디렉터리를 만들고 이 문서를 갱신할 것.


</details>
