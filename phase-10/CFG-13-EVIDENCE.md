# CFG-13-EVIDENCE.md — byte-identity proof for `flashnext` / `flashnext-codex`, and the CFG-14 ban

Run against the **installed** live file
(`/Users/ohama/agent-stack/litellm/config.yaml`, sha256
`d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e`) and the pre-mutation backup
(`phase-10/backups/config.yaml.20260901T053509Z`, sha256
`12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c`), 2026-09-01, immediately after
Restart B and its health check both passed. All output below is pasted verbatim from the actual
commands, not summarized.

## Check 1 — raw line-level diff, every removed line classified

**🔴 2026-09-01 change**: this check is **no longer** "must be empty." CFG-17 removes 16 lines by
design (the deprecated comment header + the 6 named `qwen-*` aliases). The check that replaces
"empty" is **stronger**, not weaker: every `^<` line must be individually classified as the
deprecated header or one of the six named aliases, and nothing else. This is
`phase-10/config/candidate-proof.txt` Proof 1's exact logic, reused here against the **installed**
file (Proof 1 itself was run against the pre-install candidate; the installed file is
byte-identical to it, but this reruns the classification against the file the gateway now
actually loads — not just the file that was going to be installed).

```
$ diff phase-10/backups/config.yaml.20260901T053509Z /Users/ohama/agent-stack/litellm/config.yaml
35,50c35,73
<   # ── 호환용 옛 별칭 (deprecated, 2026-08-29) ────────────────────────────
<   #   qwen36-35b·qwen122b 는 영구 비활성화됐다. 이 이름들은 더 이상 그 모델을
<   #   가리키지 않고 전부 Flash-Next 로 간다. 미처 못 찾은 참조가 조용히 깨지지
<   #   않도록 남겨 둔 것이며, 한동안 로그를 보고 쓰이지 않으면 지운다.
<   - model_name: qwen-local
<     litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
<   - model_name: qwen-35b
<     litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
<   - model_name: qwen-122b
<     litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
<   - model_name: qwen-122b-claude
<     litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
<   - model_name: qwen-35b-claude
<     litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
<   - model_name: qwen-122b-codex
<     litellm_params: { model: openai/chat_completions//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
---
>   # ── Plan/Act reasoning aliases (Phase 10, v1.1) ─────────────────────────
>   #   🔴 provider prefix is hosted_vllm/, NOT openai/. In the installed
>   #   litellm 1.86.1, OpenAIGPTConfig.get_supported_openai_params() does not
>   #   list reasoning_effort for a non-o-series model name, so an openai/-
>   #   prefixed alias carrying reasoning_effort returns HTTP 400
>   #   UnsupportedParamsError on EVERY call. HostedVLLMChatConfig whitelists it
>   #   (llms/hosted_vllm/chat/transformation.py:92). enable_thinking is not a
>   #   recognized litellm param under either prefix and rides through
>   #   extra_body, which both request paths flatten onto the top-level body.
>   #   Verified 2026-09-01 by executing the installed library — see
>   #   .planning/phases/10-alias-injection-reach-proof/10-RESEARCH.md Q1.
>   #   Silent parameter-dropping settings are deliberately NOT used anywhere
>   #   in this file (CFG-14, banned as project policy — see ALIAS-DESIGN.md).
>   - model_name: flashnext-plan
>     litellm_params:
>       model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
>       api_base: http://localhost:8011/v1
>       api_key: dummy
>       reasoning_effort: medium
>       enable_thinking: true
>
>   - model_name: flashnext-act
>     litellm_params:
>       model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
>       api_base: http://localhost:8011/v1
>       api_key: dummy
>       enable_thinking: false
>
>   # 검증 전용 별칭 — 출하 표면이 아니다. flashnext-plan 이 배포하는 조합
>   # (et-medium) 은 prompt_tokens 델타가 −2 밖에 안 돼서 도달 증명 프로브로 쓸 수
>   # 없다(phase-09/PRB-03-ORACLE.md §4). xhigh 는 +40 이라 우발적 드리프트와
>   # 구별된다. VRF-01 은 이 별칭으로 넓은 마진의 증명을 얻고, 출하 조합은
>   # 좁은 마진으로 따로 기록한다.
>   - model_name: flashnext-reach-xhigh
>     litellm_params:
>       model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
>       api_base: http://localhost:8011/v1
>       api_key: dummy
>       reasoning_effort: xhigh
```

**Removed-line count**: `grep -c '^<'` = **16** (expected exactly 16 — not 0).
**Inserted-line count**: `grep -c '^>'` = **39** (matches the inserted block size exactly).

**Classification of all 16 removed lines** (identical to `candidate-proof.txt` Proof 1, since the
installed file is byte-for-byte the candidate):

| line | classification | content |
|---|---|---|
| 1 | COMMENT-HEADER | `# ── 호환용 옛 별칭 (deprecated, 2026-08-29) ──` |
| 2 | COMMENT-HEADER | `#   qwen36-35b·qwen122b 는 영구 비활성화됐다...` |
| 3 | COMMENT-HEADER | `#   가리키지 않고 전부 Flash-Next 로 간다...` |
| 4 | COMMENT-HEADER | `#   않도록 남겨 둔 것이며, 한동안 로그를 보고...` |
| 5 | QWEN-ALIAS-NAME (`qwen-local`) | `- model_name: qwen-local` |
| 6 | QWEN-ALIAS-PARAMS (`qwen-local`) | `litellm_params: { model: openai/...Qwen3.8-Flash-Next-MLX-oQ4, ... }` |
| 7 | QWEN-ALIAS-NAME (`qwen-35b`) | `- model_name: qwen-35b` |
| 8 | QWEN-ALIAS-PARAMS (`qwen-35b`) | `litellm_params: { model: openai/...Qwen3.8-Flash-Next-MLX-oQ4, ... }` |
| 9 | QWEN-ALIAS-NAME (`qwen-122b`) | `- model_name: qwen-122b` |
| 10 | QWEN-ALIAS-PARAMS (`qwen-122b`) | `litellm_params: { model: openai/...Qwen3.8-Flash-Next-MLX-oQ4, ... }` |
| 11 | QWEN-ALIAS-NAME (`qwen-122b-claude`) | `- model_name: qwen-122b-claude` |
| 12 | QWEN-ALIAS-PARAMS (`qwen-122b-claude`) | `litellm_params: { model: openai/...Qwen3.8-Flash-Next-MLX-oQ4, ... }` |
| 13 | QWEN-ALIAS-NAME (`qwen-35b-claude`) | `- model_name: qwen-35b-claude` |
| 14 | QWEN-ALIAS-PARAMS (`qwen-35b-claude`) | `litellm_params: { model: openai/...Qwen3.8-Flash-Next-MLX-oQ4, ... }` |
| 15 | QWEN-ALIAS-NAME (`qwen-122b-codex`) | `- model_name: qwen-122b-codex` |
| 16 | QWEN-ALIAS-PARAMS (`qwen-122b-codex`) | `litellm_params: { model: openai/chat_completions/...Qwen3.8-Flash-Next-MLX-oQ4, ... }` |

TOTAL removed lines classified: 16 (matches `grep -c '^<'` exactly).

**PASS**: every removed line is exactly the CFG-17 comment header or one of the six named
`qwen-*` aliases — nothing else was removed.

## Check 2 — head-range byte identity (proves `flashnext` AND `flashnext-codex` untouched)

```
$ diff <(head -n 34 phase-10/backups/config.yaml.20260901T053509Z) \
       <(head -n 34 /Users/ohama/agent-stack/litellm/config.yaml)
(empty -- exit 0)

$ head -n 34 /Users/ohama/agent-stack/litellm/config.yaml | shasum -a 256
06814402ef0b45d0dc2eaaf3db7bc80d58076de8c021d84c8caf4823ca2f35a8  -
```

This reproduces, byte for byte, the witness hash recorded in `phase-10/BASELINE.txt` **before**
any mutation:

```
witness hash (BASELINE.txt): 06814402ef0b45d0dc2eaaf3db7bc80d58076de8c021d84c8caf4823ca2f35a8
```

**PASS — identical.** Everything strictly before the CFG-17-deleted block (line 35 onward) —
i.e. `flashnext`, `flashnext-codex`, and every comment above them — is byte-identical between the
backup and the now-installed live file. This is a stronger claim than CFG-13 strictly requires
(CFG-13 only requires the `flashnext` **entries**, not the surrounding comments, to survive); there
is no reason to weaken it.

**Blind spot of this check**: it says nothing about anything from line 35 onward — it cannot by
itself confirm that the CFG-17 deletion was clean or that the new aliases are well-formed. Check 1
covers that half.

## Check 3 — semantic deep-equal (`yaml.safe_load`)

```
--- flashnext ---
backup: {'model_name': 'flashnext', 'litellm_params': {'model': 'openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4', 'api_base': 'http://localhost:8011/v1', 'api_key': 'dummy'}}
live:   {'model_name': 'flashnext', 'litellm_params': {'model': 'openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4', 'api_base': 'http://localhost:8011/v1', 'api_key': 'dummy'}}
MATCH: flashnext

--- flashnext-codex ---
backup: {'model_name': 'flashnext-codex', 'litellm_params': {'model': 'openai/chat_completions//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4', 'api_base': 'http://localhost:8011/v1', 'api_key': 'dummy'}}
live:   {'model_name': 'flashnext-codex', 'litellm_params': {'model': 'openai/chat_completions//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4', 'api_base': 'http://localhost:8011/v1', 'api_key': 'dummy'}}
MATCH: flashnext-codex

deprecated alias 'qwen-local' present in live: False (expect False)
deprecated alias 'qwen-35b' present in live: False (expect False)
deprecated alias 'qwen-122b' present in live: False (expect False)
deprecated alias 'qwen-122b-claude' present in live: False (expect False)
deprecated alias 'qwen-35b-claude' present in live: False (expect False)
deprecated alias 'qwen-122b-codex' present in live: False (expect False)
PASS
```
(python3 exit code: 0)

**Blind spot of this check, stated plainly**: `yaml.safe_load` deep-equal cannot see comment loss
and would happily pass a whole-file YAML re-dump that stripped every comment in the file — exactly
what Check 1's raw line diff catches. The two checks cover each other's blind spot; both are kept,
neither replaces the other.

## Check 4 — CFG-14: no `drop_params` in any form

```
$ grep -in 'drop_params' /Users/ohama/agent-stack/litellm/config.yaml
(no output)
$ echo $?
1
```

**PASS — empty result, exit 1 (grep's "no match" code).** No form of `drop_params` exists anywhere
in the installed file.

**Why this ban matters (one sentence, as required):** `drop_params` turns a rejected parameter
into a silent HTTP 200 no-op — exactly the failure shape this project has already been bitten by
once (a manually-edited setting silently reverting without an error, RESEARCH.md Pitfall 5), and
exactly the shape VRF-02 (later in this phase) exists to positively refuse rather than merely hope
does not happen.

## Check 5 — comments survived

```
backup head(1..34) '#'-leading line count: 20
live   head(1..34) '#'-leading line count: 20   (unchanged)

backup 🔴-flagged operational note count (whole file): 3
live   🔴-flagged operational note count (whole file): 4   (>= backup's 3 -- PASS)
```

The live file's count is **larger**, not merely equal — the new `flashnext-plan`/`flashnext-act`/
`flashnext-reach-xhigh` comment block itself carries one new 🔴-flagged note (the `hosted_vllm/`
provider-prefix rationale, `ALIAS-DESIGN.md` §1), so the live file now documents one more
operationally load-bearing fact than the backup did, on top of preserving all three that were
already there.

## Summary

| Check | Result | What it proves | Stated blind spot |
|---|---|---|---|
| 1. Raw line diff, classified | PASS (16 removed, all classified; 39 inserted) | Nothing outside the intended CFG-17 deletion + Phase-10 insertion was touched | Cannot see semantic equivalence within the surviving lines — Check 3 covers that |
| 2. Head-range byte identity | PASS (empty diff, witness hash matches BASELINE.txt) | `flashnext` + `flashnext-codex` + all preceding comments are byte-identical, stronger than CFG-13 requires | Says nothing about line 35 onward — Check 1 covers that |
| 3. Semantic deep-equal | PASS (both entries match; all 6 deprecated names absent) | The `flashnext`/`flashnext-codex` **data** (not just bytes) is unchanged; the 6 deprecated aliases are gone | Blind to comment loss / whole-file re-dump — Check 1 covers that |
| 4. CFG-14 ban | PASS (no match, exit 1) | No silent-parameter-drop configuration exists anywhere in the installed file | N/A — a pure absence check |
| 5. Comment survival | PASS (20=20 in head range; 🔴 count 4 ≥ 3) | Operational documentation was not incidentally stripped by the edit | Counts, not content — Checks 1/2 already prove the actual bytes |

CFG-13 and CFG-14 are both proven against the file the gateway now actually loads, not merely
against the pre-install candidate.
