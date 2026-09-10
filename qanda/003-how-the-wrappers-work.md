# (Q) `cline-act` / `cline-plan` 은 어떻게 동작하나? 내부적으로 `cline` 을 쓰나?

> **질문 (2026-09-10):** cline-act 와 cline-plan 은 어떻게 동작하나?
> 이것은 cline 을 사용하나, 내부적으로?

## 짧은 답

**네, 진짜 `cline` 바이너리를 부릅니다.** `ask.sh` 와 정반대입니다.

```
ask.sh      →  curl 로 :8011 직접  →  cline 안 씀
래퍼        →  /opt/homebrew/bin/cline 실행  →  cline 씀
```

래퍼는 **얇은 껍데기**입니다. 하는 일은 인자를 조립하고, 위험한 인자를 거부하고,
실행 전후로 설정을 확인하는 것뿐입니다. 추론은 전부 `cline` 이 합니다.

---

## 실제로 부르는 명령

스텁 바이너리로 argv 를 가로채서 확인한 것입니다 (2026-09-10, 모델 요청 0건):

```bash
$ ./phase-11/cline-act "질문"
/opt/homebrew/bin/cline -P openai-compatible    -m flashnext-act  --compaction agentic -t 600 질문

$ ./phase-11/cline-plan "질문"
/opt/homebrew/bin/cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 600 질문
                                             ↑↑                ↑
                                        Plan 모드 플래그    별칭이 사고를 결정
```

**차이는 두 곳뿐입니다** — `-p` 의 유무와 별칭 이름.

🔴 **이 둘은 별개의 축입니다.**
`-p` 는 **Cline 자체의 Plan 모드**(도구 사용 제한)이고, `-m` 의 별칭이 **모델의 사고**를
결정합니다. 손으로 쓰면 어긋난 조합(`-p` + act 별칭)이 조용히 생길 수 있고,
래퍼의 존재 이유가 바로 그 짝을 강제하는 것입니다.

---

## 구조

```
cline-plan          모드별 3줄 (별칭·모드 플래그·이름) 만 정하고
   ↓ source
wrapper.env         별칭·프로바이더·타임아웃 — 값의 단일 출처
   ↓ source
wrapper_common.sh   파싱 · 거부 · 설정 가드 · 실행 — 로직 전부
```

`cline-plan` 전문이 이게 다입니다:

```bash
. "$HERE/wrapper.env"
WRAPPER_SELF="cline-plan"
WRAPPER_MODE_FLAG="-p"
WRAPPER_ALIAS="$WRAPPER_PLAN_ALIAS"
. "$HERE/wrapper_common.sh"
```

**별칭 문자열이 스크립트 어디에도 하드코딩돼 있지 않습니다.** `wrapper.env` 한 줄만 고치면
되돌릴 수 있고, Phase 11 의 유지/되돌림 결정이 정확히 그 한 줄입니다.

---

## 실행 순서 다섯 단계

**1. 인자 파싱 — 화이트리스트, 차단 목록이 아님**

허용: `-t/--timeout`, `-c/--cwd`, `--json`, `--`. **그 외 전부 거부.**

```
$ ./phase-11/cline-plan --thinking high "q"
REFUSED: cline-plan does not accept '--thinking'. Reasoning effort is injected
server-side by the litellm alias. litellm merges client kwargs AFTER the alias's
litellm_params, so a client-sent reasoning_effort OVERRIDES the alias — using
--thinking silently bypasses this wrapper's guarantee.
```

🔴 **왜 차단 목록이 아닌가.** `--thinking` 과 `-p` 는 둘 다 cline `3.0.53 → 3.0.60` 사이에
**예고 없이 생겼습니다**(CFG-05, 자동 업데이트를 막지 못함). 오늘 쓴 차단 목록은 내일
불완전합니다. 모르는 인자를 **기본 거부**하면 새 플래그가 생겨도 자동으로 막힙니다.

🔴 **조용히 제거하지 않고 거부합니다.** `--thinking high` 를 쳤는데 말없이 무시되면
사용자는 자기가 뭘 요청했는지 모른 채 다른 결과를 받습니다. (그리고 `high` 는 이 모델에
없는 값이라 서버에서 500 이 납니다 — `howto/measuring-thinking-at-8000.md`.)

**2. 실행 전 설정 확인**

`verify_config.sh` 를 돌려 실패하면 **아무것도 실행하지 않고 exit 3.**

**3. argv 조립** — 바이너리 이름이 나오는 유일한 지점.

**4. `cline` 실행**

```bash
CLINE_NO_AUTO_UPDATE=1 "$CMD" "$@"
```

주석이 정직합니다: *"작동한다고 증명된 바 없다 — CFG-05 는 미해결이고 바이너리는
3.0.53→3.0.60 으로 드리프트했다."* 그래도 붙입니다.

**5. 실행 후 설정 확인 → 오염 탐지**

```
FAIL: model expected 'flashnext', observed 'flashnext-plan'
WARNING[CONFIG]: cline exited 0, but the post-run config guard failed
$ echo $?
4
```

---

## 종료 코드

| 코드 | 의미 |
|---|---|
| `0..N` | `cline` 자신의 종료 코드 |
| **`2`** | 인자 거부. **아무것도 실행 안 됨** |
| **`3`** | 실행 전 설정 이상. **아무것도 실행 안 됨** |
| **`4`** | 실행은 정상, **실행 후 설정이 오염됨 → 복구 필요** |

🔴 **`4` 는 실행 실패가 아닙니다.** cline 은 exit 0 이고 답도 맞습니다.
*"설정이 오염됐으니 `apply_provider_config.sh` 를 돌려라"* 는 신호입니다.

---

## 래퍼가 못 하는 것

**오염을 막지 못합니다. 사후 탐지만 합니다.**

`cline` 이 `providers.json` 에 쓰는 것은 우리 코드가 아닙니다. 래퍼가 알아차렸을 때는
**이미 쓰인 뒤**고, 그 사이 Kanban·Telegram 이 파일을 읽었다면 잘못된 별칭을 봅니다.

Phase 11 의 A/B 에서 **31회 호출 중 31회, 100%** 발생했고, A/B 가 완주한 유일한 이유는
**하네스 안에만 있던 수리 루프** 덕분입니다. 래퍼에는 그게 없습니다.

이것이 유지/되돌림 결정의 핵심 입력입니다 — 정확도 개선은 관측되지 않았는데
(동일 조건 25/30 대 25/30) 부작용은 100% 확실합니다.

---

## 세 도구 비교

| | `ask.sh` | 맨손 `cline -m` | 래퍼 |
|---|---|---|---|
| `cline` 사용 | ❌ | ✅ | ✅ |
| 붙는 곳 | `:8011` | `:4000` | `:4000` |
| 모드·별칭 짝 강제 | — | ❌ 손으로 | ✅ |
| `--thinking` 차단 | — | ❌ | ✅ 거부 |
| 설정 오염 | 없음 | 발생, **탐지 안 됨** | 발생, **탐지됨** |
| Cline 동작 증명 | ❌ | ✅ | ✅ |

---

## 근거

모두 2026-09-10 확인. argv 캡처는 스텁 바이너리를 써서 **모델 요청 0건**.

| 주장 | 확인 방법 |
|---|---|
| 진짜 cline 을 부름 | `phase-11/wrapper.env` → `WRAPPER_CLINE_BIN=/opt/homebrew/bin/cline` |
| 정확한 argv | `CLINE_WRAPPER_TEST=1` + 스텁, 이 문서 작성 중 캡처 |
| 화이트리스트 거부 | `wrapper_common.sh:98`, `--thinking high` 실행으로 확인 |
| 거부 시 미실행 | `phase-11/wrapper_argv_test.sh` 13케이스 — argv 파일 바이트 불변으로 증명 |
| 오염률 100% | `phase-11/AB-RESULTS.md`, `providers-drift.tsv` (31/31) |
| exit 4 의 의미 | `wrapper_common.sh:167-168` |
