# Compaction Verdict: server_400_no_compaction

**Generated:** 2026-08-29T10:08:26.148810+00:00

## Meaning (한글 요약)

압축이 발동하지 않았고 서버가 MAX_KV_SIZE 초과로 400 거부했다 (Cline은 이 오류에서 자동 복구하지 않는다)

## Verdict

- **outcome:** `server_400_no_compaction`
- **reason:** No auto-compact* notice fired; the server rejected the request as a context overflow (MAX_KV_SIZE). Cline does not self-heal from this error - its overflow-recovery classifier's 8 regexes do not match this text, so the task simply dies and the user must start a new task.
- **evidence_source:** `both`
- **malformed_lines:** 0

## Token Peaks

- **peak_input_tokens** (per-iteration, from `--json` usage events): 30505
- **peak_prompt_tokens** (from `flashnext.err` server log): 30505

## Thresholds Used

- **predicted_trigger:** 26542 (source: flag (--predicted-trigger))
- **max_kv:** 32768

## Raw Evidence

### Server error payload

```
litellm.BadRequestError: OpenAIException - Error code: 400 - {'detail': 'Request needs 33998 context tokens (31950 prompt + 2048 max generation), but MAX_KV_SIZE is 32768.'}. Received Model Group=flashnext
Available Model Group Fallbacks=None
```


---

## 🔴 2026-08-30 정정 — 이 판정의 해석이 뒤집혔다

이 실행의 **측정값은 모두 유효하다**(peak 30,505, 두 오라클 일치, 서버 400). 그러나 원인 진단이
틀렸다. 압축이 발동하지 않은 것은 #12520 폴백 버그 때문이 아니라, `contextWindow` 를
`providers.json` 의 `models[]` **안에** 넣었기 때문이다. `models[]` 는 VS Code 용 per-model
override 경로이고 **CLI 는 읽지 않는다** (`provider-settings.ts:150/266`).

`settings` **최상위**에 `contextWindow` 를 넣자 압축이 정상 발동했다 —
`phase-01/results/exp-verify29k/` (필러 18개 완주, 압축 3회 이상, 서버 400 0건).

즉 이 실행은 **"CLI 가 읽지 않는 칸에 설정을 넣으면 어떻게 되는가"의 정확한 증거**로 남는다.
현재 유효한 결론과 운영 방침: `docs/32k-compaction-policy.md`
