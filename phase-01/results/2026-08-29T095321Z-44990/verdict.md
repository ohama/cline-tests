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

