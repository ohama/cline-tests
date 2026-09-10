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

## 래퍼가 못 하는 것 (2026-09-10 정정)

> 🔴 이 절은 원래 이렇게 썼습니다: "**오염을 막지 못합니다. 사후 탐지만 합니다.**" <!-- verify_docs:allow -->
> 그 뒤 `cline` 이 알아차렸을 때는 **이미 쓰인 뒤**고, 그 사이 Kanban·Telegram 이 파일을
> 읽었다면 잘못된 별칭을 본다고 이어졌습니다. **작성 당시엔 맞았고, 지금은 틀렸습니다** —
> 이 문서를 쓴 당일, 몇 시간 뒤 커밋 `017c65e` 가 예방 조치를 배포했는데 한동안 고치지
> 않은 채 뒀습니다 (`qanda/004-does-cline-always-write-providers-json.md` §5 가 같은 날 겪은 것과 같은 실패 모양).

**지금은 오염을 막습니다(격리). 탐지만 하던 것에서 바뀌었습니다.**

래퍼(`phase-11/wrapper_common.sh`)가 호출마다 실제 `providers.json` 을 `mktemp` 사본으로
복사하고, `CLINE_PROVIDER_SETTINGS_PATH` 를 그 사본으로 돌립니다. `cline` 의 쓰기는 사본에
떨어지고, 래퍼를 거친 호출에서는 공유 파일이 건드려지지 않습니다. `EXIT`/`INT`/`TERM` 트랩이
사본을 정리합니다. 사본을 만들 수 없으면 래퍼는 **exit 3 으로 거부**하고 실행하지 않습니다
— 격리 없이 도는 일은 없습니다.

검증됨: 두 래퍼 모두 exit 4 → **0** 으로 바뀌었고, `providers.json` 의 sha 는 격리된 호출
전후로 불변이었습니다.

🔴 **"고쳐졌다"가 아니라 "격리됐다"고 해야 합니다.** cline 자체의 기동 경로에 있는 무조건적인
쓰기는 그대로입니다 — 래퍼 밖에서 맨손으로 `cline -m` 을 부르면 여전히 공유 파일을 바꿉니다.
그리고 이 격리는 하루밖에 안 됐고 프로덕션 실적이 없습니다 — 다음 자동 업데이트가 동작을
다시 바꿀 수 있습니다(CFG-05). 자세한 소스·실측은 `qanda/004-does-cline-always-write-providers-json.md`.

Phase 11 의 A/B 에서 **31회 호출 중 31회, 100%** 발생했고(이 A/B 는 래퍼를 우회해 별칭만
측정했습니다), A/B 가 완주한 유일한 이유는 **하네스 안에만 있던 수리 루프** 덕분입니다.
당시 래퍼에는 격리가 없었습니다.

이것이 유지/되돌림 결정의 핵심 입력이었지만, 이제는 결정이 났습니다 — **`keep`**, 사람이
규칙의 `revert` 출력을 오버라이드해서 나온 결정입니다. 오버라이드의 근거는 정확도가 아니라
`providers.json` 부작용이 격리 가능해졌다는 것입니다(바로 위 내용). 정확도 근거는 그대로
`revert` 를 지지합니다 — 동일 조건에서 arm A 25/30, arm C 25/30 (p=0.563), 사고가 도움이
됐다는 증거는 없습니다. 자세한 판정은 `phase-11/AB-RESULTS.md` §11.

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
