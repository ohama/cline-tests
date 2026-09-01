# CHANGE-BRIEF.md — Phase 10 litellm config change

What exactly changes, what goes down while it changes, for how long, and the literal command that
puts it back. Read top to bottom; it is short by design. Nothing described here has been installed
— the candidate lives entirely under `phase-10/config/`, never under `/Users/ohama/agent-stack/`.

**Freshness of the validation ladder cited below:** re-run at approval time, not merely at
authoring time — `bash phase-10/validate_config.sh phase-10/config/config.yaml.candidate`,
run directory `phase-10/results/20260901T053938Z-validate`, **2026-09-01T05:39:38Z UTC**:

```
RUNG 1: PASS -- yaml-parses (python3 yaml.safe_load succeeded)
RUNG 2: PASS -- drop_params-ban (no drop_params (any form) found anywhere in the file)
RUNG 3: PASS -- baseline-preserved (flashnext + flashnext-codex deep-equal live vs candidate)
RUNG 4: PASS -- real-boot (booted on 127.0.0.1:4010 after 2s, all 4 aliases served)
VALIDATION LADDER: ALL 4 RUNGS PASSED
```

The candidate is still green right now. This ladder has separately been proven to actually reject
bad configs: 5 seeded mutants, 4 caught as mechanical/enforced checks (MUTANT-1 unclosed YAML,
MUTANT-2 `drop_params`, MUTANT-3 `flashnext` baseline drift, MUTANT-5 deletion-overreach into
`flashnext`), 1 recorded as a measurement, not an assertion (MUTANT-4, a schema-invalid
`litellm_params: null` shape that a real litellm 1.86.1 crashes on via an unhandled exception
rather than a graceful rejection — see `ALIAS-DESIGN.md` §8 for the full disclosure of what this
does and does not prove).

---

## 1. The diff

```diff
--- /Users/ohama/agent-stack/litellm/config.yaml	2026-08-29 14:43:06
+++ phase-10/config/config.yaml.candidate	2026-09-01 14:23:39
@@ -32,19 +32,42 @@
       api_base: http://localhost:8011/v1
       api_key: dummy
 
-  # ── 호환용 옛 별칭 (deprecated, 2026-08-29) ────────────────────────────
-  #   qwen36-35b·qwen122b 는 영구 비활성화됐다. 이 이름들은 더 이상 그 모델을
-  #   가리키지 않고 전부 Flash-Next 로 간다. 미처 못 찾은 참조가 조용히 깨지지
-  #   않도록 남겨 둔 것이며, 한동안 로그를 보고 쓰이지 않으면 지운다.
-  - model_name: qwen-local
-    litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
-  - model_name: qwen-35b
-    litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
-  - model_name: qwen-122b
-    litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
-  - model_name: qwen-122b-claude
-    litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
-  - model_name: qwen-35b-claude
-    litellm_params: { model: openai//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
-  - model_name: qwen-122b-codex
-    litellm_params: { model: openai/chat_completions//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4, api_base: http://localhost:8011/v1, api_key: dummy }
+  # ── Plan/Act reasoning aliases (Phase 10, v1.1) ─────────────────────────
+  #   🔴 provider prefix is hosted_vllm/, NOT openai/. In the installed
+  #   litellm 1.86.1, OpenAIGPTConfig.get_supported_openai_params() does not
+  #   list reasoning_effort for a non-o-series model name, so an openai/-
+  #   prefixed alias carrying reasoning_effort returns HTTP 400
+  #   UnsupportedParamsError on EVERY call. HostedVLLMChatConfig whitelists it
+  #   (llms/hosted_vllm/chat/transformation.py:92). enable_thinking is not a
+  #   recognized litellm param under either prefix and rides through
+  #   extra_body, which both request paths flatten onto the top-level body.
+  #   Verified 2026-09-01 by executing the installed library — see
+  #   .planning/phases/10-alias-injection-reach-proof/10-RESEARCH.md Q1.
+  #   Silent parameter-dropping settings are deliberately NOT used anywhere
+  #   in this file (CFG-14, banned as project policy — see ALIAS-DESIGN.md).
+  - model_name: flashnext-plan
+    litellm_params:
+      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
+      api_base: http://localhost:8011/v1
+      api_key: dummy
+      reasoning_effort: medium
+      enable_thinking: true
+
+  - model_name: flashnext-act
+    litellm_params:
+      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
+      api_base: http://localhost:8011/v1
+      api_key: dummy
+      enable_thinking: false
+
+  # 검증 전용 별칭 — 출하 표면이 아니다. flashnext-plan 이 배포하는 조합
+  # (et-medium) 은 prompt_tokens 델타가 −2 밖에 안 돼서 도달 증명 프로브로 쓸 수
+  # 없다(phase-09/PRB-03-ORACLE.md §4). xhigh 는 +40 이라 우발적 드리프트와
+  # 구별된다. VRF-01 은 이 별칭으로 넓은 마진의 증명을 얻고, 출하 조합은
+  # 좁은 마진으로 따로 기록한다.
+  - model_name: flashnext-reach-xhigh
+    litellm_params:
+      model: hosted_vllm//Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
+      api_base: http://localhost:8011/v1
+      api_key: dummy
+      reasoning_effort: xhigh
```

**One-line summary: this is NOT a pure insertion.** 39 content lines added (3 new `model_list`
entries + their comment header), **16 lines removed** (the 4-line deprecated-alias comment header
and the 6 named `qwen-*` aliases: `qwen-local`, `qwen-35b`, `qwen-122b`, `qwen-122b-claude`,
`qwen-35b-claude`, `qwen-122b-codex` — CFG-17, user-instructed). **Zero lines altered** —
everything else, including every byte of `flashnext` and `flashnext-codex` and their comments, is
untouched (verified mechanically: `head -n 34` of both files is byte-identical, and both entries
deep-equal under `yaml.safe_load` — `phase-10/config/candidate-proof.txt` Proofs 2–3). No
`drop_params` anywhere in the candidate.

## 2. What each new alias does

- **`flashnext-plan`** — injects `reasoning_effort: medium` + `enable_thinking: true`. The shipped
  Plan-mode alias (CFG-11).
- **`flashnext-act`** — injects `enable_thinking: false`. The shipped Act-mode alias (CFG-12).
  **Honest note:** `enable_thinking`'s default is already `false`, so `flashnext-act` is expected
  to be **behaviorally indistinguishable** from the existing, unmodified `flashnext` alias — Phase
  11's `cline-act` wrapper could equally well point at plain `flashnext` today. It is created
  anyway for explicitness and so the shipped Plan/Act pair shares one `hosted_vllm/` provider
  prefix ahead of Phase 11's A/B (`ALIAS-DESIGN.md` §5). Plan 10-04 measures this; "no measurable
  difference" is the expected, not a failing, result.
- **`flashnext-reach-xhigh`** — a verification-only alias, not a shipped surface. It exists because
  the shipped combination (`et-medium`, what `flashnext-plan` deploys) has a `prompt_tokens` delta
  of exactly **−2** from `unspecified` — too narrow a margin to trust as proof of reach against
  incidental prompt drift (`phase-09/PRB-03-ORACLE.md` §4). `xhigh` alone has a **+40** delta and
  shares the same `hosted_vllm/` prefix, isolating the injected parameter from the provider path.
  What ships is therefore not the arm that carries the reach proof.

**And what is removed:** the six deprecated `qwen-*` aliases (CFG-17). The config file's own
comment set the deletion condition when these were redirected to Flash-Next on 2026-08-29 ("watch
the logs for a while, and if unused, delete them"). That condition is met: since the current
`litellm` instance started, server logs show **zero** `qwen-*` requests against **163**
`flashnext` requests. `build_candidate.sh` verified structurally, before cutting a single byte,
that the deleted block is exactly these 6 named aliases plus the comment header and nothing else,
and that it does not mention `flashnext` anywhere (`ALIAS-DESIGN.md` §2).

## 3. Which file is edited, and which is not

- `/Users/ohama/agent-stack/litellm/config.yaml` — **this is the file that gets edited.** It is
  the file the launchd plist passes to `--config` (confirmed).
- `~/local-llm-settings/config/litellm-config.yaml` — a **generated mirror**. It is not edited by
  hand and will be regenerated by `sync.sh` in plan 10-06. As of this brief it is still
  byte-identical to the live file (`phase-10/BASELINE.txt` line 2).
- `~/.cline/data/settings/providers.json` — **not touched at all.** The real-`cline` test in plan
  10-05 uses `-m <alias>` per invocation, so `phase-01/config/verify_config.sh`'s hard assertion
  `model == "flashnext"` is never disturbed by this change.

## 4. Blast radius

litellm on `:4000` is the single gateway. While it restarts, **every** consumer fails with
connection refused: Kanban (`:3484`), the Telegram connector, and any headless wrapper run. The
model itself (`com.ohama.flashnext`, 104 GiB resident) is **not** restarted and is **not**
reloaded — the 20–45s model load does not happen. `com.ohama.role-shim` is not restarted either.

## 5. Downtime

The window contains **two restarts, not one**:

- **Restart A — rehearsal, on the unmodified config.** Proves `restart_service.sh` works on the
  `com.ohama.litellm` label today and measures the real downtime before any config change exists.
  If it fails or overruns, plan 10-03 stops *before* mutating anything.
- **Restart B — the real one, on the new config** — gated on Restart A having succeeded and on the
  validation ladder passing again immediately beforehand.

**Expected figure and hard bound:** litellm is a small Python process with no model to load, so
each restart is expected to complete in **well under 20 seconds** (this expectation comes from
this ladder's own rung 4: the real litellm binary booted the candidate in **2 seconds** on the
scratch port just now — a cold boot including config parse; a launchd restart of the same binary
should be comparable). The helper is invoked with `--timeout 60`, the hard bound at which it
aborts and prints its own rollback recipe. Total expected interruption ≈ two brief windows, worst
case bounded at 2 × 60s = 120s. **This is an estimate — Restart A is what turns it into a
measurement**, before Restart B (the one that actually matters) ever runs.

## 6. Precondition — read live at brief time, 2026-09-01T05:40Z UTC

- Model idleness: last `in_flight=` line in `~/llm-system/services/logs/flashnext.err` reads
  **`in_flight=0`** — idle.
- `cline` process check (`pgrep -fl 'bin/\.cline|bin/cline'`): **NOT clear — 3 matching processes
  are currently running**, not zero:
  ```
  4672  node /opt/homebrew/bin/cline                    (elapsed ~06:02:12)
  4673  /opt/homebrew/lib/node_modules/cline/bin/.cline  (elapsed ~06:02:12, child of 4672)
  43410 .../cline/bin/.cline --cline-hub-daemon --cwd /Users/ohama/tmp/toy-lang --host 127.0.0.1 --port 25463 --pathname /hub  (elapsed ~1d 01:40:59)
  ```
  **This precondition, as literally stated, is not met right now.** Whether these are an active
  interactive session, a long-idle hub daemon, or both is not something this brief can determine
  automatically — it is reported plainly rather than waved through. If any of these are in the
  middle of real work, "not now" is the correct answer at the checkpoint.

## 7. Rollback

```
bash phase-10/rollback_config.sh phase-10/backups/config.yaml.20260901T053509Z
bash phase-02/infra/restart_service.sh com.ohama.litellm 4000 --timeout 60
```

Step 1 has **already been executed against the live path**, twice, in the same rehearsal session
(`phase-10/results/20260901T053807Z-rollback-rehearsal`, 2026-09-01T05:38:26Z UTC): a positive
restore against the still-pristine live file (exit 0, live sha256 and `com.ohama.litellm` pid both
unchanged before/after — a verified content no-op) and a negative control against a deliberately
corrupted copy of the same backup (exit 1, refused with an explicit integrity-check message, live
file confirmed untouched). Both outcomes are recorded with full command/exit-code/hash evidence in
`phase-10/ROLLBACK.md`.

**Worst case, stated honestly:** if the new config fails to boot for real (a shape the validation
ladder's rung 4 didn't catch — see MUTANT-4's residual-risk disclosure above), litellm crash-loops
under `KeepAlive` at one attempt per `ThrottleInterval: 10` seconds until the rollback above runs.
This is why the candidate is booted on a scratch port first (this plan's own ladder, rung 4) and
why plan 10-03 re-runs that ladder immediately before installing — the same check just run for
this brief, re-run again right before the real cutover.

## 8. What this does not change

- No `providers.json` write, ever, in this phase's plans up to and including this one.
- No model restart — `com.ohama.flashnext` (pid 46573) is untouched.
- No `flashnext` or `flashnext-codex` edit — both deep-equal between live and candidate
  (`phase-10/config/candidate-proof.txt` Proof 3; `validate_config.sh` rung 3, CFG-13).
- Nothing binds port 3000. `flashnext-codex` is never called by anything in this plan.
