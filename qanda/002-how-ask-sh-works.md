# (Q) `ask.sh` 는 어떻게 동작하나? `cline` 을 쓰지 않는 건가?

> **질문 (2026-09-10):** ask.sh 는 어떻게 동작하나? cline 을 쓰지 않는 건가?

## 짧은 답

**`cline` 을 전혀 쓰지 않습니다.** 스크립트에 `cline` 이라는 문자열조차 없습니다:

```bash
$ grep -c cline howto/ask.sh
0
```

`curl` 로 **role-shim(`:8011`)에 직접 HTTP 요청**을 보냅니다. 그래서 뒷정리가 필요 없습니다 —
`providers.json` 을 건드릴 일 자체가 없습니다.

---

## 어느 계층에 말을 거는가

```
cline  →  litellm(:4000)  →  role-shim(:8011)  →  mlx_vlm.server(:8000)
                                    ↑
                              ask.sh 는 여기
```

| 도구 | 붙는 곳 | `cline` 사용 | `providers.json` 영향 |
|---|---|---|---|
| `howto/ask.sh` | `:8011` | ❌ | 없음 |
| `howto/measure-at-8000.sh` | `:8000` | ❌ | 없음 |
| `howto/check-thinking.sh` | `:8011` + `:4000` | ❌ | 없음 |
| `phase-11/cline-plan` / `cline-act` | `:4000` (cline 경유) | ✅ | **매번 오염** |
| 맨손 `cline -m …` | `:4000` | ✅ | **매번 오염** |

`cline` 이 `:4000` 을 쓴다는 건 `providers.json` 의 `baseUrl` 이 그렇게 적혀 있어서입니다
(`http://localhost:4000/v1`).

---

## 하는 일 — 네 단계

**1. 모드를 요청 본문으로 번역한다**

```bash
--act   →  (아무것도 안 붙임)                                  max_tokens 256
--plan  →  "enable_thinking":true, "reasoning_effort":"medium"  max_tokens 1024
--max   →  "enable_thinking":true, "reasoning_effort":"xhigh"   max_tokens 1024
```

사고 모드의 기본 예산이 큰 이유: **사고가 답보다 먼저 예산을 씁니다.** Phase 9 에서
`max_tokens=300` 을 줬더니 사고가 다 써버려 **본문이 빈 채로** 끝난 적이 있습니다.

**2. 로그 워터마크를 찍고 요청을 보낸다**

```bash
MARK=$(wc -l < flashnext.err)     # 요청 직전
curl ... "$SHIM"                   # 발사
```

**3. 응답에서 사고와 답을 분리한다**

```python
r = m.get("reasoning") or m.get("reasoning_content") or ""
```

🔴 **두 필드명을 모두 읽습니다.** `:8011` 은 `reasoning`, litellm 경유는 `reasoning_content`
입니다. 한쪽만 보면 **거짓 음성**이 납니다 — Phase 9 에서 실제로 이 실수가 나서 "파라미터가
안 먹는다"고 잘못 읽은 적이 있습니다.

**4. 서버 로그로 귀속시킨다**

새로 생긴 줄에서 `Prefill started` 를 찾되, **정확히 1건이 아니면 토큰 판정을 생략**합니다.
모델이 `--max-num-seqs 1` 로 Kanban·Telegram 과 공유되므로, 창 안에 남의 요청이 끼면
그 표본은 못 믿습니다. **그럴듯한 숫자를 만들지 않습니다.**

---

## 실제 출력 (2026-09-10, 같은 질문)

```
$ ./howto/ask.sh --act "2+2는? 숫자만."
4

prompt=21  completion=2  finish=stop  reasoning=0자
elapsed=1s
서버 로그 prompt_tokens=21  (모드 act)
```

```
$ ./howto/ask.sh --plan "2+2는? 숫자만."
The answer is 4. They want only the number.

─── 답 ──────────────────────────────────────────
4

prompt=19  completion=55  finish=stop  reasoning=150자
elapsed=2s
서버 로그 prompt_tokens=19  (모드 plan)
```

**읽을 것 셋:**

- `reasoning` **0자 → 150자** — 사고가 실제로 켜졌습니다
- `prompt` **21 → 19**, 즉 **−2**. 이게 `medium` 의 서명입니다
  (`howto/measuring-thinking-at-8000.md` 의 델타 표와 일치)
- `completion` **2 → 55** — 사고가 완성 토큰을 씁니다. 1초 대 2초의 차이가 여기서 옵니다

---

## 그래서 무엇을 증명하고 무엇을 증명하지 않나

**증명함:** 이 파라미터들이 모델에 어떻게 작용하는가. 사고가 켜지는지, 토큰이 얼마나 드는지,
답이 어떻게 달라지는지.

**증명 못 함:** *"Cline 이 이 설정으로 동작한다."* `cline` 을 거치지 않으니까요.
Cline 은 자기 나름의 시스템 프롬프트·도구 정의·컨텍스트 관리를 붙이고, 그게 결과를 바꿉니다.

이 구분이 이 프로젝트의 핵심입니다. v1 에서 `providers.json` 에 값이 멀쩡히 있고 서버도
`200` 을 돌려줬는데 **CLI 가 그 칸을 안 읽어서** 이틀을 날린 적이 있습니다.
`ask.sh` 로는 그런 종류의 결함을 절대 못 잡습니다.

**Cline 까지 포함해 확인하려면** `qanda/001` 의 방법 2·3(실제 `cline` 실행)을 쓰세요.
대신 뒷정리가 필요합니다.

---

## 근거

| 주장 | 확인 방법 |
|---|---|
| `cline` 미사용 | `grep -c cline howto/ask.sh` → `0` |
| `:8011` 로 감 | `howto/ask.sh:17` `SHIM=http://localhost:8011/v1/chat/completions` |
| `providers.json` 무영향 | 위 두 실행 후 `verify_config.sh` → `OK` |
| `−2` 델타 | 위 출력 21→19, `phase-11/results/20260910T070004Z-measure8000/sweep.tsv` 와 일치 |
| 예산 고갈 전례 | `phase-09/PRB-03-ORACLE.md` §3 |
