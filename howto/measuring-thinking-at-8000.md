# `:8000` 직결로 thinking 파라미터 측정하기

**대상:** `mlx_vlm.server` (`:8000`) — 게이트웨이가 하나도 없는 모델 서버 자신.

```
cline → litellm(:4000) → role-shim(:8011) → mlx_vlm.server(:8000)
                                             ↑ 여기에 직접 묻는다
```

**왜 직결인가.** 중간 계층이 파라미터를 바꾸거나 삼킬 수 있다. `:8000` 에 직접 물으면
**"모델 서버 자신이 이 값을 어떻게 다루는가"** 를 해석 없이 본다. 이후 계층에서 다른 값이
나오면 그 차이는 계층 탓임이 확정된다.

**실행:**

```bash
./howto/measure-at-8000.sh          # 21 요청, 약 2분
```

---

## 1. 방법 — 왜 `prompt_tokens` 를 보는가

`:8000` 으로 가는 JSON 은 우리가 직접 만들지만, **서버가 그것을 실제로 반영했는지**는
응답만 봐서는 알 수 없다. 무시해도 `200` 이 나온다.

**원리:** `reasoning_effort` 값이 다르면 서버가 **다른 시스템 프롬프트**를 렌더링한다.
프롬프트가 다르면 토큰 수가 다르고, 그 수는 서버 로그에 찍힌다:

```
2026-09-10 - INFO - Prefill started: request=835b… prompt_tokens=53 images=0 …
```

**본문을 고정하고 파라미터만 바꿔서** 이 값이 움직이면, 그것이 파라미터가
템플릿 렌더링에 도달했다는 증거다.

🔴 **HTTP 200 은 증거가 아니다.** 게이트웨이가 받았다는 뜻일 뿐이다.

### 귀속 — `tail -N` 을 쓰지 않는 이유

모델은 `--max-num-seqs 1` 로 Kanban·Telegram 과 공유된다. 로그 마지막 줄이 내 요청이라는
보장이 없다.

```bash
mark=$(wc -l < "$LOG")                                  # 요청 직전 워터마크
curl ... "$SERVER"                                      # 발사
sed -n "$((mark+1)),\$p" "$LOG" | grep "Prefill started" # 새로 생긴 줄만
```

창 안에 `Prefill started` 가 **정확히 1건이 아니면** 그 표본은 `AMBIG` 로 버린다.
다른 테넌트 요청이 끼었을 때 그럴듯한 숫자를 만들지 않기 위해서다.

### 두 필드명을 모두 읽는다

```
:8000 / :8011  →  message.reasoning  과  message.reasoning_content  둘 다 존재
:4000 (litellm) →  message.reasoning_content 에만 값이 있다
```

한쪽만 보면 **거짓 음성**이 난다. Phase 9 에서 실제로 이 실수가 나서 "파라미터가 안 먹는다"고
잘못 읽은 적이 있다.

---

## 2. 결과 (2026-09-10 측정)

본문 고정: `{"messages":[{"role":"user","content":"hi"}], "max_tokens":4}`
스윕 2회(A/B) **전 항목 일치** — 재현됨.

| 보낸 값 | HTTP | `prompt_tokens` | 델타 | `reasoning` |
|---|---|---:|---:|---:|
| (아무것도 안 보냄) | 200 | **13** | 기준 | 0자 |
| `enable_thinking: false` | 200 | 13 | **+0** | 0자 |
| `enable_thinking: true` | 200 | 53 | **+40** | 18자 |
| `reasoning_effort: low` | 200 | 41 | **+28** | 15자 |
| `reasoning_effort: medium` | 200 | 11 | **−2** | 15자 |
| `reasoning_effort: xhigh` | 200 | 53 | **+40** | 18자 |
| `reasoning_effort: high` | **500** | — | — | — |
| `enable_thinking:true` + `medium` | 200 | 11 | **−2** | 15자 |
| `thinking_budget: 512` | **500** | — | — | — |

### 거부되는 두 값의 실제 메시지

```
high            {"detail":"An unexpected error occurred: Unexpected reasoning effort high.
                 Supported types are xhigh (default), medium, and low."}

thinking_budget {"detail":"Generation failed: thinking_budget is not supported with
                 speculative decoding in the server."}
```

🔴 두 요청은 **prefill 에 도달하지 않는다** — 21건을 쏘고 서버 로그는 17건만 늘었다.
거부된 4건(=2×2)이 그 차이다. 즉 `AMBIG(0)` 은 계측 실패가 아니라 **요청이 거절돼
prefill 자체가 없었다**는 뜻이다.

### 읽어낸 것 넷

**① `enable_thinking: false` 는 미지정과 완전히 같다 (둘 다 13).**
기본값이 `false` 임이 토큰 수준에서 확인된다. 사고를 끄려고 명시적으로 보낼 필요가 없다.

**② `enable_thinking: true` 는 `xhigh` 와 같다 (둘 다 53).**
`VALIDATED.md` §4 의 주장이 재확인됨. `true` 는 **최대 강도**이지 "적당히 켜기"가 아니다.

**③ `reasoning_effort` 가 있으면 `enable_thinking` 은 아무것도 안 한다.**
`et-medium`(11) = `medium`(11). 토큰만이 아니라 **생성된 텍스트까지 바이트 단위로 동일**했다
(`reasoning` sha `e2935b665870`, `content` sha `8a070ae00dd5` — 양쪽 일치).

**④ `medium` 이 미지정보다 프롬프트가 *짧다* (−2).**
직관에 반한다. 원인은 chat template 수준이라 이 저장소 밖이고, 추적하지 않았다.
**작동에는 영향이 없다** — `medium` 은 실제로 사고를 만든다(아래 ⑤).

---

## 3. 토큰만이 아니라 내용도 확인

`max_tokens=4` 에서는 `reasoning` 이 15~18자로 잘린다. 현실적 길이로 다시 재면:

| `max_tokens=256` | `prompt_tokens` | `reasoning` | `content` |
|---|---:|---:|---:|
| 미지정 | 13 | **0자** | 32자 |
| `medium` | 11 | **142자** | 76자 |
| `enable_thinking:true` + `medium` | 11 | **142자** | 76자 |

실제 사고 내용:

> *The user said "hi" - this is a simple greeting. I should respond in a friendly, casual man…*

🔴 **`max_tokens` 를 작게 주면 사고가 예산을 먼저 쓴다.** 위 표에서 `max_tokens=4` 일 때
`content` 가 **0자**인 것이 그 증거다 — 사고하느라 답을 못 썼다. 사고를 켤 거면
`max_tokens` 를 넉넉히(≥512) 줘라.

---

## 4. 이 결과가 다른 계층과 같은가

| 델타 | `:8000` 직결 | `:8011` role-shim | `:4000` 별칭 주입 |
|---|---|---|---|
| `medium` | −2 | −2 | −2 |
| `low` | +28 | +28 | — |
| `xhigh` / `et-true` | +40 | +40 | +40 |
| `et-medium` | −2 | −2 | −2 |

**세 계층이 전부 일치한다.** role-shim 도 litellm 별칭 주입도 값을 바꾸지 않는다.
`:4000` 열의 근거는 `phase-10/REACH-PROOF.md` — 클라이언트가 파라미터를 **하나도 안 보낸**
상태에서 별칭에 심어둔 값만으로 같은 델타가 나왔다.

---

## 5. 한계

**직접 관측이 아니다.** 서버 내부에서 렌더링된 프롬프트 문자열을 본 적은 없다.
`prompt_tokens` 라는 **지문**으로 역산한 것이다.

다만 이 역산은 강하다 — 스윕 2회가 비트 단위로 일치하고, 세 계층에서 같은 델타가 나오며,
응답 내용과 실제 `cline` 실행 관측이 같은 방향을 가리킨다.

**절대값은 믿지 마라.** 과거 기록은 23/21/51/63 이었고 지금은 13/11/41/53 이다.
원인 미규명. **델타는 보존됐다.** 그래서 판정은 항상 **그 실행 자신의 기준선 대비 델타**로 한다.

**증거:** `phase-11/results/20260910T070004Z-measure8000/` — `sweep.tsv` 와 원시 응답 21건.
