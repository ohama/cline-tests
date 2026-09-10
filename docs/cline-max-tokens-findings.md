# Cline `max_tokens` 실측 기록 (CFG-03)

> **2026-09-10 정정.** 이 문서의 1차 결론(`OBSERVED_MAX = 2048`)은 **관측 자체는 정확했으나
> 일반화가 틀렸다.** 2026-08-29 세션에서 실제로 서버가 `max_tokens=2048` 을 받은 것은 사실이다 —
> 그 값을 "cline 이 항상 보내는 고정 캡"으로 일반화한 것이 틀렸다. `phase-11/OPEN-ITEMS.md`
> Open Item 2 가 같은 프롬프트에서 `20983` 을 측정했고, 이어서 `phase-11/AB-PROTOCOL.md` §3 이
> 278개 서버 로그 샘플로 확인한 것: `OBSERVED_MAX` 는 상수가 아니라 **요청마다 사이징되는 값**이다.
> 아래 §2·§4·§5 가 현재 유효한 내용이고, 정정 전 기록은 §9 부록에 원문 그대로 보존한다.

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

## 2. 관찰된 값 (2026-09-10 정정 — 원문은 §9 부록)

측정 절차 (`phase-01/results/max-tokens-probe/`):

```
source phase-01/config/cline-invocation.env
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext --compaction agentic \
  --json --auto-approve true -t 600 "Reply with exactly one word: OK"
```

`--config`/`--data-dir` 는 넘기지 않았다 — 실제 `~/.cline/data/settings/providers.json` 이 적용된
상태를 재야 하기 때문이다 (격리하면 기본 provider 를 재는 셈이 되어 CFG-03 과 무관해진다).

측정 시점 오프셋(`wc -c < flashnext.err`)부터 로그를 슬라이스해서 얻은 서버 측 원본 증거
(`phase-01/results/max-tokens-probe/observed_lines.txt`), 2026-08-29, cline `3.0.53`:

```
2026-08-29 18:16:40,587 - INFO - Generation queued: request=82eb9186e0 prompt_tokens=5495 max_tokens=2048 images=0 audio=0 videos=0
```

이 로그 줄 자체는 실제 캡처이고 바뀐 적 없다. 문제는 이 한 줄에서 일반화된 결론이었다: 이
세션에는 요청이 **딱 1개**만 발생했다(도구 호출 없이 한 단어만 답하는 프롬프트라 후속 턴이
없었다) — 그 단일 표본에서 상수를 일반화한 것이 방법론적 약점이었다.

그 약점이 실제로 틀렸다는 것이 이후 두 단계로 확인됐다:

1. **같은 프롬프트를 3.0.60/3.0.61 에서 재현하면 `20983` 이 나온다.** `prompt_tokens=5494` 로
   거의 동일한 프롬프트인데도 `max_tokens` 는 10배 넘게 늘었다 (`phase-11/OPEN-ITEMS.md`
   Open Item 2, `oi2-maxtokens.txt`/`oi2.tsv`).
2. **278개 서버 로그 샘플에 대한 분석은 이 값이 요청마다 사이징된다는 것을 보였다.** cline은
   `prompt_tokens + max_tokens` 의 합이 `contextWindow × 0.9` ≈ **26,100** 부근에 오도록
   `max_tokens` 를 매 요청마다 계산한다 — 관측된 합의 범위는 **9,442~32,013**, 서버의
   `MAX_KV_SIZE`(32,768) 한도를 넘은 사례는 **0건**이다 (`phase-11/AB-PROTOCOL.md` §3). Phase 11
   비교 실행(66개 셀) 동안 실측 예산은 대략 20,800~20,873 토큰대였고, 66개 셀 전부
   `finish_reason=stop` — 두 쪽 모두 잘림(truncation)은 관측되지 않았다
   (`phase-11/PHASE-11-FINDINGS.md` §5.3).

**따라서 여기에 못박을 `OBSERVED_MAX` 는 없다.** `2048` 은 3.0.53 한 세션의 관측값으로만
남는다. 이 수치가 필요한 미래 문서는 현재 설치된 바이너리와 현재 `contextWindow` 값으로 직접
재측정해야 하며, 이 문서를 상수의 출처로 인용해서는 안 된다.

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

## 4. 결정과 조치 (2026-09-10 정정 — 원문은 §9 부록)

이 절의 원래 분기 판단은 `OBSERVED_MAX = 2048` 이라는 이제는 무효화된 전제 위에 있었다: 조건
`OBSERVED_MAX < 6226` 은 `2048` 에서는 성립했지만, 이후 실측된 `20983` 에서는 성립하지 않는다
(`20983 < 6226` 은 거짓이다). 이 문서는 그 분기를 여기서 다시 계산하거나 새 분기를 선언하지
않는다 — 이 플랜이 실제로 하지 않은 재도출을 한 것처럼 굴지 않는 것이 맞는 태도다. 오늘 실제로
유지되는 사실은 §2 의 실측(278개 표본, 서버 32,768 한도 위반 0건)이며, 분기 자체의 재도출이
필요하다면 그것은 **v1.2 작업**이다. 원문(당시의 분기 판단과 근거 문장)은 §9 부록에 그대로
남겨둔다.

당시(2026-08-29) 실제로 취해진 조치는, 분기 판단의 유효성과 무관하게 그대로의 실행 기록으로
남는다:

- `providers.json` 은 변경되지 않았다 (`contextWindow` 는 그대로 `32768`).
- `phase-01/config/apply_provider_config.sh` / `phase-01/config/verify_config.sh` 는 수정되지
  않았다.
- `.planning/REQUIREMENTS.md` 의 CFG-02 와 `.planning/ROADMAP.md` 의 Phase 1 Success Criterion 1
  도 수정되지 않았다.

남은 리스크로 그때 이미 적혀 있던 것: `2048` 은 `providers.json` 설정이 아니라 Cline 버전에
종속된 값으로 보인다는 관찰이었다. 이 관찰은 이후 `20983` 측정으로 더 강하게 확인됐을 뿐,
"버전에 종속된다"는 진단 자체는 틀리지 않았다 — 틀린 것은 그 종속된 값이 여전히 하나의
상수라는 가정이었다.

## 5. 예산 관계식 (2026-09-10 정정 — 원문 표는 §9 부록)

이전 판은 `트리거 + OBSERVED_MAX = 26100 + 2048 = 28148` 이라는 고정 합을 계산해 여유(headroom)
`4178` 을 도출했다. 그 계산은 고정 덧셈 항을 전제한 산수이고, 그 전제가 §2 에서 무효화된 이상
그 산수도 **더 이상 성립하지 않는다** — 조용히 지우는 대신, 여기서 말로 남긴다.

실측으로 대체되는 관계는 다음과 같다: cline 은 `prompt_tokens + max_tokens` 의 합이
`contextWindow × 0.9`(≈26,100) 부근에 오도록 `max_tokens` 를 매 요청마다 사이징한다. 278개
표본에서 그 합은 9,442~32,013 사이였고, 서버 `MAX_KV_SIZE`(32,768) 를 넘은 사례는 0건이다
(`phase-11/AB-PROTOCOL.md` §3). 즉 예산은 미리 고정 항을 더해 계산할 수 있는 값이 아니라, cline
자신의 사이징 규칙에 의해 상한이 걸리는 값이다 — 그 사이징 규칙이 `contextWindow` 를 근거로
동작한다는 것은 278개 표본의 관측이고, cline 소스를 읽어 확인한 것은 아니다(§8 참고).

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

## 7. 이 정정이 바꾸는 것

| 대상 | 이전 | 이후 |
| --- | --- | --- |
| `OBSERVED_MAX` | 고정 상수 `2048` (1개 표본에서 일반화) | 못박을 상수 없음 — 요청마다 `contextWindow × 0.9` 부근으로 사이징(278개 표본, 9,442~32,013, 위반 0건) |
| §4 분기 전제 | `OBSERVED_MAX < 6226` → `2048 < 6226` 참, Branch A 통과 | 전제 무효 (`20983 < 6226` 은 거짓) — 새 분기 재도출은 하지 않음, v1.2 로 유예 |
| §5 예산 산수 | `트리거 + OBSERVED_MAX = 26100 + 2048 = 28148`, 여유 4178 | 고정 덧셈 항 없음 — cline 자신의 사이징이 상한을 건다는 실측(278개 표본, 위반 0건) |
| §6 재-프로브 트리거 | "관측된 wire `max_tokens` 가 `2048` 에서 변함" | 더 이상 의미 있는 트리거가 아님(못박을 값이 없다) — `MAX_KV_SIZE` 를 언급하는 400 은 여전히 유효한 트리거 |

## 8. 미해결

- **CFG-05 — 이 드리프트가 왜 일어났는가.** 이 값이 바뀐 근본 원인은 cline 바이너리 자체가
  이 milestone 동안 `3.0.53 → 3.0.60 → 3.0.61` 로 사용자 동의 없이 이동했고, 한 번은 실행 중간에
  npm 패키지가 디스크에서 완전히 제거된 상태로 발견된 적도 있다(`phase-11/PHASE-11-FINDINGS.md`
  §5.5). CFG-05(자동 업데이트 차단)는 이 milestone 이 끝난 지금도 미해결이다 — 값이 다시
  바뀔 수 있다는 뜻이다.
- **사이징 규칙 자체는 소스가 아니라 추론이다.** "`contextWindow × 0.9` 부근으로 사이징한다"는
  문장은 278개 표본, 한 워크로드(Phase 11 비교 실행)에 대한 통계적 관측이다. cline 이 이 예산을
  실제로 계산하는 소스 코드를 아무도 읽지 않았다 — 그래서 이것은 증거이지 증명이 아니다.

## 9. 부록 — 정정 전 기록 (2026-08-29 실측 원문)

아래는 2026-09-10 정정 전, 이 문서가 실제로 썼던 §2·§4·§5 원문이다. **측정값(로그 줄, `2048`)은
그대로 유효하며**, 그 값에서 무엇을 일반화했는지의 증거로서 보존한다. 결론 문장만 위 §2·§4·§5 로
대체됐다.

<details>
<summary>원문 펼치기</summary>

### 2. 관찰된 값 (원문)

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

### 4. 결정과 조치 (원문)

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

### 5. 예산 계산 (원문)

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

</details>
