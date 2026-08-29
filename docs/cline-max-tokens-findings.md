# Cline `max_tokens` 실측 기록 (CFG-03)

이 문서는 Cline 이 서버(litellm → flashnext)에 실제로 보내는 `max_tokens` 값을 측정한 기록이다.
CFG-03 은 원래 "설정 키 하나를 지정한다"였지만, 연구 단계에서 `providers.json` 의 `maxTokens`
필드가 먹지 않는다는 사실이 나오면서 재정의되었다: **와이어 값을 실측하고, 그 값에 맞는 완화책을
고르는 것**이 CFG-03 이다.

정본은 `phase-01/config/observed.env` (측정값 export) 와
`phase-01/results/max-tokens-probe/` (원본 증거)다. 이 문서는 그 값이 **왜** 그 값인지, 그리고
**무엇을 결정했는지**의 기록이다.

## 1. 왜 이것이 문제인가

flashnext 서버(litellm 뒤의 MLX 서빙 스택)는 prefill 을 시작하기 **전에** accept-time 예산을
검사한다: `prompt_tokens + max_tokens ≤ 32768` (`MAX_KV_SIZE`). 이 검사를 통과하지 못하면
HTTP 400 (`PromptTooLongError`, `MAX_KV_SIZE` 언급)으로 즉시 거부된다 — 실제 토큰을 하나도
생성하기 전에, 심지어 짧은 프롬프트라도. 연구 단계에서 실측된 두 사례:

- `prompt 13 + max_tokens 40000` → HTTP 400 `Request needs 40013 context tokens (13 prompt +
  40000 max generation), but MAX_KV_SIZE is 32768.`
- `prompt 13 + max_tokens 32000` → 200 OK

즉, Cline 이 요청마다 서버에 보내는 `max_tokens` 가 크면, 압축(compaction) 트리거가 26,542
토큰 근처에서 뜨기도 전에 이 400 벽에 먼저 부딪힐 수 있다. Phase 1 의 회귀 테스트는 "압축이
뜨는가/안 뜨는가"를 재는 것인데, 만약 `max_tokens` 가 이 벽을 먼저 건드리면 "압축 미발동(②)"이라는
결과가 실제로는 "압축이 뜰 기회조차 없었다"는 뜻이 되어버린다 — 확신을 가지고 틀린 결론을 내리는
최악의 시나리오다. 이걸 막는 것이 이 플랜의 목적이다.

## 2. 관찰된 값

측정 절차 (`phase-01/results/max-tokens-probe/`):

```
source phase-01/config/cline-invocation.env
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext --compaction agentic \
  --json --auto-approve true -t 600 "Reply with exactly one word: OK"
```

`--config`/`--data-dir` 는 넘기지 않았다 — 실제 `~/.cline/data/settings/providers.json` 이 적용된
상태를 재야 하기 때문이다 (격리하면 기본 provider 를 재는 셈이 되어 CFG-03 과 무관해진다).

측정 시점 오프셋(`wc -c < flashnext.err`)부터 로그를 슬라이스해서 얻은 서버 측 원본 증거
(`phase-01/results/max-tokens-probe/observed_lines.txt`):

```
2026-08-29 18:16:40,587 - INFO - Generation queued: request=82eb9186e0 prompt_tokens=5495 max_tokens=2048 images=0 audio=0 videos=0
```

**`OBSERVED_MAX = 2048`.** 이 세션에서 딱 1개의 요청만 발생했다(도구 호출 없이 한 단어만
답하는 프롬프트라 후속 턴이 없었다). NDJSON 스트림의 `usage` 이벤트를 교차 확인하면
Cline 이 보고한 `outputTokens = 2` ("OK" 두 글자) — 2048 캡에는 전혀 근접하지 못했다. 즉 이번
실측은 "서버에 어떤 캡을 알렸는가"만 확인했고, 실제로 그 캡에서 잘리는 동작까지 재현한 것은
아니다.

원본 파일: `phase-01/results/max-tokens-probe/{prompt.txt,ndjson.log,stderr.log,
flashnext_window.log,observed_lines.txt,observed.txt}`.

## 3. `providers.json` 의 `maxTokens` 는 먹는가

**아니다.** 측정 시점에 `providers.json` 에는

```json
"models": [{"id": "flashnext", "contextWindow": 32768, "maxTokens": 4096}]
```

이 설정되어 있었지만, 서버 로그에 찍힌 실제 와이어 값은 `2048` 이었다 — 설정값과 다르다.

이는 연구 단계(`01-RESEARCH.md`)가 이미 관찰한 것과 정확히 같은 패턴이다: 연구에서는 `512`와
`77`을 각각 설정해봤지만 서버는 매번 `max_tokens=2048`을 로그에 남겼고, 실제로 출력 캡이
전혀 적용되지 않은 채 `finish_reason=stop`으로 1,228 토큰을 생성한 사례도 있었다. 두 곳
(top-level `settings.maxTokens` 및 `settings.models[0].maxTokens`)에 값을 넣어봐도 결과가
<!-- 주: maxTokens 는 여전히 미적용이다. contextWindow 와 달리 최상위 경로도 없다. -->
바뀌지 않았다는 것이 연구의 결론이었고, 이번 실측도 그 결론과 모순되지 않는다.

**근본 원인은 여전히 밝혀지지 않았다.** `2048`이 Cline 바이너리에 하드코딩된 내부 기본값인지,
provider 설정 스키마의 다른 필드를 봐야 하는 건지는 이 플랜의 범위 밖이며, 추측으로 원인을
지어내지 않는다. Branch A(아래)를 택했기 때문에 이 문제를 더 깊이 파고들 필요가 없었다 — 관찰된
값 자체가 이미 안전 범위 안에 있기 때문이다.

## 4. 결정과 조치

**분기: Branch A.** 조건 `OBSERVED_MAX < 6226` (아래 예산 계산 참고) 이 `2048 < 6226`으로
참이므로, 추가 완화 조치 없이 통과.

- `providers.json` 은 변경하지 않았다 (`contextWindow` 는 그대로 `32768`).
- `phase-01/config/apply_provider_config.sh` / `phase-01/config/verify_config.sh` 는 수정하지
  않았다 — Branch A/B1/B3 는 이 두 스크립트를 건드릴 필요가 없다.
- `.planning/REQUIREMENTS.md` 의 CFG-02 와 `.planning/ROADMAP.md` 의 Phase 1 Success Criterion 1
  은 **수정하지 않았다.** 이 두 문서는 Branch B2("`contextWindow`를 32768 아래로 낮췄을 때")에만
  수정 대상이며, 이번 실행은 그 분기를 타지 않았다.
- 잔존 리스크: `2048` 이라는 값은 Cline 내부 기본값으로 보이며, 이는 `providers.json` 설정이
  아니라 Cline 버전에 종속된 동작이다. `phase-01/config/check_versions.sh` (CFG-05/06)가 이미
  `cline` 버전 드리프트를 감시하고 있으므로, 버전이 바뀌면 이 실측도 재확인 대상이 된다(6절 참고).

Branch B2 관련 문서 두 곳(REQUIREMENTS.md CFG-02, ROADMAP.md Success Criterion 1)은 이번
실행에서 **변경되지 않았음**을 명시적으로 기록한다 — Branch A 이므로 두 문서 모두 실행 전과
동일한 `contextWindow: 32768` 문구를 그대로 유지한다.

## 5. 예산 계산

| 항목 | 값 |
| --- | --- |
| 설정된(live) `contextWindow` | 32768 |
| 예측 트리거 (**정정**: `maxInputTokens × 0.9`) | 26100 (최상위 contextWindow=29000) |
| 관찰된 `max_tokens` (OBSERVED_MAX) | 2048 |
| 트리거 + OBSERVED_MAX | 26100 + 2048 = 28148 |
| 서버 `MAX_KV_SIZE` | 32768 |
| 여유(headroom) | 32768 − 28590 = 4178 |
| 판정 | **안전 (safe)** — `28590 < 32768` |

공식(**2026-08-30 정정**): `trigger = maxInputTokens × 0.9`, 그리고 `maxInputTokens` 는 `settings` 최상위 `contextWindow` 에서 온다. 이 문서와 `observed.env` 모두 이 공식을 **살아있는
`contextWindow` 로부터 매번 재계산**하며, `cline-invocation.env` 의 리터럴 기본값을
그대로 재사용하지 않는다 — Branch B2 가 `contextWindow` 를 낮췄다면 그 리터럴은 곧바로 틀린 값이
되기 때문이다 (이번 실행에서는 `contextWindow` 가 바뀌지 않았으므로 우연히 두 값이 같다).

## 6. 재확인 조건

다음 중 하나라도 발생하면 이 실측을 재실행해야 한다:

1. `cline --version` 이 `3.0.53` 이 아닌 값을 보고할 때 (`phase-01/config/check_versions.sh` 가
   이를 감시한다).
2. `providers.json` 이 (`apply_provider_config.sh` 를 통해서든 수동으로든) 재적용될 때 —
   `contextWindow` 나 다른 값이 바뀌었을 수 있다.
3. 평소 사용 중에 `MAX_KV_SIZE` 를 언급하는 HTTP 400 이 나타날 때 — `OBSERVED_MAX` 가 더 이상
   유효하지 않다는 신호다.

재확인 명령 (이 플랜 Task 1 과 동일):

```bash
cd /Users/ohama/projs/cline-tests
source phase-01/config/cline-invocation.env
bash phase-01/config/verify_config.sh
OFFSET=$(wc -c < "$FLASHNEXT_ERR_LOG")
bash -c '
source phase-01/config/cline-invocation.env
CLINE_NO_AUTO_UPDATE=1 "$CLINE_BIN" $CLINE_COMMON_FLAGS --json --auto-approve true \
  -t 600 "Reply with exactly one word: OK" \
  > /tmp/recheck-ndjson.log 2> /tmp/recheck-stderr.log
'
tail -c +$((OFFSET+1)) "$FLASHNEXT_ERR_LOG" | grep 'Generation queued'
```

`Generation queued: ... max_tokens=<n>` 줄의 `<n>` 을 다시 읽고, 4절의 예산 계산 표를 그 값으로
다시 채운다.
