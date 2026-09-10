# (Q) cline CLI 를 써서 plan / act 모드를 직접 테스트하는 예

> **질문 (2026-09-10):** cline cli 를 써서 내가 plan, act 모드를 test 하는 예를 작성해 줘.

## 짧은 답

됩니다. 다만 **테스트할 때마다 뒷정리가 필요합니다** — `cline -m <별칭>` 은 호출할 때마다
`providers.json` 을 영구히 바꾸고, 그 파일을 Kanban 과 Telegram 이 공유합니다.

아래 세 방법이 있고, **뒷정리가 필요 없는 것부터** 적었습니다.

---

## 🔴 먼저 — 왜 뒷정리가 필요한가

`cline -m <별칭>` 은 문서상 "호출 단위 오버라이드"지만, **실제로는 설정 파일에 영구 기록**합니다.
2026-09-10 이 문서를 쓰면서 두 모드를 실제로 돌려 재확인했습니다:

```
./phase-11/cline-act  "2+2는?"  →  providers.json: model = flashnext-act
./phase-11/cline-plan "3+4는?"  →  providers.json: model = flashnext-plan
```

**`flashnext-plan` 만의 문제가 아닙니다** — `-m` 을 쓰는 모든 별칭이 그렇습니다.
Phase 11 의 A/B 에서는 **31회 호출 중 31회, 100%** 발생했습니다.

그대로 두면 Kanban·Telegram 이 조용히 다른 별칭으로 돌게 됩니다. **복구 명령:**

```bash
bash phase-01/config/apply_provider_config.sh   # flashnext 로 되돌림
bash phase-01/config/verify_config.sh           # OK 확인
```

---

## 방법 1 — `cline` 없이 (뒷정리 불필요) ⭐ 빠른 확인용

모델에 직접 물어봅니다. `providers.json` 을 아예 안 건드립니다.

```bash
./howto/ask.sh --act  "파이썬 리스트 뒤집는 법"    # 사고 끔
./howto/ask.sh --plan "이 설계의 위험은?"          # 사고 켬 medium
./howto/ask.sh --max  "어려운 추론 문제"           # 사고 켬 xhigh
```

출력에 **사고 과정과 답이 분리되어** 나오고, 마지막에 서버 로그의 `prompt_tokens` 도 찍힙니다.

**한계:** `cline` 을 거치지 않으므로 *"Cline 이 이 설정으로 동작한다"* 는 증명은 아닙니다.
파라미터가 모델에 어떻게 작용하는지만 봅니다.

---

## 방법 2 — 실제 `cline` 으로 (뒷정리 필요)

이게 **진짜 테스트**입니다. Cline 이 그 경로로 실제 사고하는지 봅니다.

```bash
# --- act 모드 (사고 끔) ---
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m flashnext-act \
  --compaction agentic -t 600 "2+2는? 숫자만."

# --- plan 모드 (사고 켬, medium) ---
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -p -m flashnext-plan \
  --compaction agentic -t 600 "3+4는? 숫자만."

# --- 반드시 뒷정리 ---
bash phase-01/config/apply_provider_config.sh
```

`-p` 는 Cline 자체의 Plan 모드(도구 사용 제한)이고, `-m` 이 사고를 결정합니다. **둘은 별개**라
짝을 손으로 맞춰야 합니다 — 그래서 래퍼가 있습니다(방법 3).

---

## 방법 3 — 래퍼로 (짝 강제 + 자동 탐지)

```bash
./phase-11/cline-act  "2+2는? 숫자만."
./phase-11/cline-plan "3+4는? 숫자만."
```

래퍼가 하는 일:

- **모드와 별칭의 짝을 강제**합니다 — `cline-plan` 은 항상 `-p -m flashnext-plan`
- `--thinking` / `-m` / `-P` 를 **거부**합니다 (조용히 무시가 아니라 거부).
  사용자가 `--thinking` 을 넘기면 별칭 주입이 덮어써지기 때문입니다
- 실행 후 `providers.json` 오염을 **탐지**하고 경고합니다

```
FAIL: model expected 'flashnext', observed 'flashnext-plan'
WARNING[CONFIG]: cline exited 0, but the post-run config guard failed
$ echo $?
4
```

🔴 **exit 4 는 이 실행이 실패했다는 뜻이 아닙니다.** cline 자체는 exit 0 이고 답도 맞습니다.
4 는 **"설정이 오염됐으니 복구하라"** 는 신호입니다. 탐지는 하지만 **예방은 못 합니다.**

---

## 사고가 실제로 나왔는지 보는 법

`--json` 으로 NDJSON 스트림을 받습니다:

```bash
./phase-11/cline-plan --json "3+4는? 숫자만." > /tmp/plan.ndjson
bash phase-01/config/apply_provider_config.sh   # 뒷정리
```

🔴 **사고는 한 덩어리로 안 옵니다 — 스트리밍 조각으로 옵니다.** 방금 측정에서 `3+4는?`
한 질문에 **조각 18개**였고, 첫 조각은 `"The"` 한 단어였습니다. 한 조각만 읽으면
"사고 안 함"으로 오독합니다. **이어붙여야** 합니다:

```bash
python3 -c "
import json
r=[]
for l in open('/tmp/plan.ndjson'):
    try: d=json.loads(l)
    except: continue
    e=d.get('event',{})
    if e.get('contentType')=='reasoning' and e.get('reasoning'):
        r.append(e['reasoning'])
print('조각 %d개:' % len(r), ''.join(r))
"
```

실제 출력:

```
조각 18개: The user is asking for a simple arithmetic result and wants only the numeric answer.
```

**대조군을 나란히 돌리세요.** `cline-act` 로 같은 질문을 하면 `reasoning` 줄이 **0개**여야
합니다. 그 대비가 증거입니다 — 한쪽만 보면 아무것도 증명하지 못합니다.

---

## 진짜 도달했는지 확인 (선택)

응답에 사고가 보이는 것과 **설정이 모델까지 갔다**는 건 다른 주장입니다. 서버 로그로 봅니다:

```bash
tail -3 ~/llm-system/services/logs/flashnext.err | grep "Prefill started"
```

같은 질문에 대해 대략 이렇게 나옵니다 (**절대값이 아니라 차이**를 보세요):

| 모드 | `prompt_tokens` |
|---|---|
| act (사고 끔) | 기준 |
| plan (`medium`) | 기준 **−2** |
| `xhigh` | 기준 **+40** |

`medium` 의 −2 는 마진이 좁아 판정용으로는 약합니다. 확실히 보려면
`./howto/ask.sh --max` 로 `xhigh`(+40)를 쓰세요. 자세한 방법은
`howto/measuring-thinking-at-8000.md`.

---

## 지금 상태에서 주의할 것

- **래퍼의 기본 별칭은 아직 확정 전입니다.** Phase 11 의 A/B 는 `revert`(= `flashnext` 로
  되돌림)를 출력했고, 사용자 비준을 기다리는 중입니다. 되돌려져도 `flashnext-plan` 별칭
  자체는 살아 있어서 `-m` 으로 명시 호출은 계속 됩니다
- **A/B 결과: 정확도 차이 없음** (동일 조건 25/30 대 25/30, p=0.563). 사고를 켠다고
  결과가 좋아진다는 증거는 이 과제 세트에서 나오지 않았습니다
- **`cline` 버전이 자주 바뀝니다** (`CLINE_NO_AUTO_UPDATE=1` 이 안 먹습니다).
  실행 중 패키지가 통째로 사라진 적도 있습니다. 테스트 전후로 `cline --version` 을 찍어두세요

## 근거

이 문서의 모든 명령은 2026-09-10 에 실제로 실행해서 확인했습니다.

| 주장 | 근거 |
|---|---|
| `-m` 이 `providers.json` 을 영구 변경 | 이 문서 작성 중 2회 재현 (act·plan 각 1회) |
| 100% 발생률 (31/31) | `phase-11/AB-RESULTS.md`, `providers-drift.tsv` |
| 사고가 조각 18개로 스트리밍 | `/tmp/plan.ndjson`, 이 문서 작성 중 측정 |
| 델타 −2 / +40 | `phase-11/results/20260910T070004Z-measure8000/sweep.tsv` |
| A/B 차이 없음 | `phase-11/AB-RESULTS.md` |
