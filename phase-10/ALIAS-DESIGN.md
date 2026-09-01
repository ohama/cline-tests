# ALIAS-DESIGN.md — Phase 10 candidate alias record

Companion to `phase-10/config/config.yaml.candidate` and the plan 10-02 human checkpoint. This is
the short document a human is shown before any restart happens. Nothing here has been installed —
the candidate lives entirely under `phase-10/config/`, never under `/Users/ohama/agent-stack/`.

🔴 **2026-09-01 update.** The candidate is no longer a pure insertion. Alongside the three new
aliases below (§1), it also **removes** the six deprecated `qwen-*` aliases per **CFG-17** — a
scope change added at the user's explicit instruction and committed as `dbe79bc`, folded into this
already-executed plan's artifacts by orchestrator-directed corrective work rather than by a new
plan. See §2 for the removal itself. The regression baseline that actually matters, CFG-13, is
unaffected by either change: `flashnext` and `flashnext-codex` are proven byte-identical between
the live file and the candidate both before and after this update (`build_candidate.sh` Proof 2/3,
`validate_config.sh` rung 3).

---

## 1. What is being added, and why each entry exists

Three new `model_list` entries, inserted after the existing `flashnext-codex` block and — as of
CFG-17 — immediately before the end of the file, where the deprecated-aliases block used to be
(see §2). All three route to the same upstream (`api_base: http://localhost:8011/v1`, the same
`role-shim` → `mlx_vlm.server` chain `flashnext` already uses) — they are three named front doors
onto one backend queue, not new backend capacity (`10-RESEARCH.md` Q7).

- **`flashnext-plan`** — the shipped Plan-mode alias (CFG-11). Injects
  `reasoning_effort: medium` **and** `enable_thinking: true` together. `enable_thinking`'s default
  is `false`, so effort alone is not guaranteed to turn thinking on; VALIDATED.md's own
  recommendation is to set both.
- **`flashnext-act`** — the shipped Act-mode alias (CFG-12, see §5 below). Injects
  `enable_thinking: false` explicitly.
- **`flashnext-reach-xhigh`** — a verification-only alias, not a shipped surface. Exists solely so
  VRF-01 has a reach probe with a margin wide enough to be believed (see §6).

## 2. What is being removed, and why (CFG-17)

Six deprecated aliases are deleted from the live config's tail (originally lines 34–50: a blank
separator, a four-line comment header, and twelve lines of six two-line flow-mapping entries):
`qwen-local`, `qwen-35b`, `qwen-122b`, `qwen-122b-claude`, `qwen-35b-claude`, `qwen-122b-codex`.
`flashnext` and `flashnext-codex` are preserved untouched (CFG-13) — the deletion targets only the
block below the anchor comment `  # ── 호환용 옛 별칭`, verified structurally by
`build_candidate.sh` before a single byte is cut (exact alias-name match, no mention of
`flashnext` anywhere in the block staged for deletion, the block runs to EOF with nothing after it).

**Why now.** The config file's own comment set the deletion condition when these aliases were
redirected to Flash-Next on 2026-08-29: "한동안 로그를 보고 쓰이지 않으면 지운다" ("watch the logs
for a while, and if unused, delete them"). That condition is now met: since the current `litellm`
instance started, server logs show **zero** `qwen-*` requests against **163** `flashnext` requests.
The handful of historical `qwen-*` log entries all predate the last restart and are mostly 404s /
`No deployments available` — leftover probes from before the redirect, not live traffic.

**Why folded into this plan's maintenance window rather than a separate change.** Deleting these
lines requires the same `litellm` restart the three new aliases already require. Doing it as a
second, separate change would mean a second, separate restart — a second unnecessary interruption
to Kanban (`:3484`) and the Telegram connector for a change that could ride the same window. Same
backup, same rollback script, same validation ladder (`validate_config.sh`), same human checkpoint
(plan 10-02) — see ROADMAP.md's Phase 10 criterion 7 note.

**What this does NOT change.** The insertion mechanism, the three new aliases' definitions, and the
CFG-13 regression baseline are all identical to what plan 10-01 originally built. The only change to
`build_candidate.sh` is that the deprecated tail it used to carry forward unmodified is now
verified and dropped instead.

## 3. Why `hosted_vllm/` and not `openai/` (CFG-11)

This is a mechanism, not just an observed asymmetry, verified by executing the actual installed
`litellm==1.86.1` package (`10-RESEARCH.md` Q1, no stack mutation, isolated Python process).

litellm's router flattens `deployment["litellm_params"]` (the alias's config) and the client's own
request kwargs into **one dict** before calling `completion()`:

```python
# router.py:2447-2453
input_kwargs = {
    **litellm_params,   # from the alias's config.yaml model_list entry
    "messages": messages,
    "caching": self.cache_responses,
    "client": model_client,
    **kwargs,            # from the actual client request body
}
_response = litellm.acompletion(**input_kwargs)
```

**There is no code path that distinguishes "this came from the alias config" from "this came from
the client."** By the time `reasoning_effort` reaches `completion()`, it is an ordinary keyword
argument regardless of origin. This is why ROADMAP criterion 1 as originally worded — inject
`reasoning_effort` while keeping `flashnext`'s `openai/` prefix — would not have produced a
selectively-behaving alias; it would have produced an alias that 400s on **every single call**.

`reasoning_effort` is a formally declared, validated parameter: `get_optional_params()`
(`utils.py:3981`) calls `_check_valid_arg()` against
`get_supported_openai_params(model, custom_llm_provider)`. For `custom_llm_provider == "openai"`,
`OpenAIGPTConfig.get_supported_openai_params()` (`llms/openai/chat/gpt_transformation.py:137-187`)
does not list `"reasoning_effort"` for a non-o-series model name — our local filesystem path is
neither an o-series nor a GPT-5 model — so `_check_valid_arg` raises `UnsupportedParamsError`
(HTTP 400) on every call. Verified live:

```python
litellm.get_optional_params(model="openai//Users/.../Qwen3.8-Flash-Next-MLX-oQ4",
                             custom_llm_provider="openai", reasoning_effort="medium")
# -> UnsupportedParamsError: openai does not support parameters: ['reasoning_effort']
```

`HostedVLLMChatConfig.get_supported_openai_params()` (`llms/hosted_vllm/chat/transformation.py:92`)
explicitly extends the base list with `reasoning_effort` (and `thinking`), so switching only the
**new** aliases' `litellm_params.model` prefix to `hosted_vllm/<path>` — same `api_base`, same
`api_key`, same upstream — makes the parameter survive validation and land as a genuine top-level
key in the JSON body sent to `:8011`. Verified live with the exact CFG-11 combination:

```python
litellm.get_optional_params(model="hosted_vllm//Users/.../Qwen3.8-Flash-Next-MLX-oQ4",
                             custom_llm_provider="hosted_vllm",
                             reasoning_effort="medium", enable_thinking=True)
# -> {'stream': False, 'reasoning_effort': 'medium', 'extra_body': {'enable_thinking': True}}
```

`enable_thinking` is not a recognized litellm/OpenAI parameter name under **either** prefix — it
falls into the catch-all in `add_provider_specific_params_to_optional_params()`
(`utils.py:4798-4855`) and is swept into `extra_body`, which both the `openai` SDK client path
(`llms/openai/openai.py:478-480`) and the `hosted_vllm` raw-httpx path
(`llm_http_handler.py:399,448-449`) flatten onto the top-level outgoing JSON body identically. This
is exactly why Phase 9 saw `reasoning_effort` → 400 and `enable_thinking` → 200 through the
unmodified `flashnext` alias: one is a recognized, provider-whitelisted param; the other rides
through as an unrecognized pass-through. The existing `flashnext` and `flashnext-codex` entries are
untouched — the regression baseline is preserved by construction (CFG-13; verified mechanically
by `build_candidate.sh`'s Proof 2/3 and `validate_config.sh`'s rung 3).

## 4. Why no `drop_params` (CFG-14)

`litellm.drop_params` / `drop_params: true` / `additional_drop_params` are never set anywhere in
this candidate, checked mechanically by `validate_config.sh`'s rung 2. Two independent reasons:

1. It is **unnecessary** — the `hosted_vllm/` prefix above makes `reasoning_effort` a genuinely
   supported parameter; there is nothing to drop.
2. It is **banned as project policy regardless**. `drop_params` converts a rejected parameter into
   a silent no-op that still returns HTTP 200 — the exact failure shape ("설정했다" without
   "작동한다", success asserted without being observed) this project has already been bitten by
   more than once. A validator or a config that manufactures false confidence is worse than one
   that has no answer at all.

(One execution-time note, recorded for the historical record: the earliest draft of the alias
block's own comment happened to contain the literal substring "drop_params" while describing this
very policy — which would have failed this rung's own grep check against the clean candidate.
Reworded before shipping; see `phase-10/config/aliases-candidate.yaml`'s history.)

## 5. CFG-12: the `flashnext-act` decision

PRB-02 passed in Phase 9: a client-sent `enable_thinking: false` returns HTTP 200, not rejected,
and 09-01's `enable_thinking: true` positive control showed the parameter is genuinely *applied* by
the model, not merely tolerated by the gateway (`phase-09/GATE-VERDICT.md` §5). On that basis,
`flashnext-act` is created.

**Stating the redundancy plainly rather than resolving it silently:** `enable_thinking`'s default
is already `false`. `flashnext-act` is therefore expected to be **behaviorally indistinguishable**
from the unmodified `flashnext` alias — Phase 11's `cline-act` wrapper could equally well point at
plain `flashnext` and nothing downstream would observably differ. `flashnext-act` is created anyway
for three reasons: explicitness (the config states the mode's intent instead of relying on an
implicit default), symmetry with `flashnext-plan`, and — the reason that actually matters for
Phase 11 — so that the shipped Plan/Act pair shares the *same* `hosted_vllm/` provider prefix,
removing a confound from Phase 11's `cline-plan`/`cline-act` A/B before it can be introduced (a
prefix-driven request-shape difference would otherwise be entangled with the reasoning-parameter
difference the A/B is actually trying to measure).

Plan 10-04 measures whether `flashnext-act` is in fact indistinguishable from `flashnext`. **A
"no measurable difference" result there is the expected outcome, not a failure of this alias.**

## 6. The weaker-proof disclosure

`flashnext-plan` deploys the combination Phase 9 calls `et-medium`
(`enable_thinking:true` + `reasoning_effort:medium`). `phase-09/PRB-03-ORACLE.md` §2b measured its
`prompt_tokens` delta from `unspecified` at exactly **−2**, identical to `medium` alone —
`enable_thinking:true` did not widen that margin at all. §4 of that document rules `et-medium` out
as a reach probe: a −2 margin is too tight to survive incidental prompt drift and could be flipped
by an unrelated system-prompt revision (the whole observed `VALIDATED.md`-to-fresh baseline shift
was only −10 tokens across an entire measurement session, and −2 sits well inside that noise band).

Reach is instead proven with:
- **`flashnext-reach-xhigh`** (`reasoning_effort: xhigh`, no `enable_thinking`), whose delta is
  **+40** — comfortably outside any plausible incidental drift, and using the same `hosted_vllm/`
  prefix as `flashnext-plan` so the comparison isolates the injected parameter with the provider
  path held constant.
- The `:8011`/`:4000` cross-checks (plan 10-04), which corroborate that the gateway path introduces
  no confound beyond the injected parameters.

**What is deployed is therefore not what carries the wide-margin proof.** Every downstream document
(plan 10-04's VRF-01/02 scripts, plan 10-06's requirement mapping) must say so explicitly rather
than presenting `et-medium`'s own −2 margin as if it were the reach evidence.

## 7. The oracle is a delta, never an absolute

`phase-09/PRB-03-ORACLE.md` §5 records an unexplained, deliberately-not-chased baseline shift: the
absolute `prompt_tokens` values moved from `VALIDATED.md`'s 23/21/51/63 (unspecified/medium/low/
xhigh) to 09-RESEARCH.md's and Phase 9's fresh 13/11/41/53 — a constant **−10** offset — while every
delta from `unspecified` stayed bit-for-bit identical (medium −2, low +28, xhigh +40) across both
measurement sessions, weeks apart. Any reader comparing absolute `prompt_tokens` numbers across
documents in this project must read them as deltas from that document's own `unspecified` baseline,
never as portable constants. This is what makes the oracle usable at all across sessions where the
absolute baseline is not stable.

## 8. Residual risks handed to plan 10-03

- **The scratch boot (rung 4) proves startup validity, not runtime behavior.** A config that boots
  cleanly on 127.0.0.1:4010 has been shown to pass litellm's own pydantic `LiteLLM_Params`
  validation at process start — it has not been shown to produce correct completions, correct
  `reasoning_content`, or correct token accounting. That is plan 10-04's job (CFG-16, VRF-01/02),
  strictly downstream of and separate from this plan's ladder.
- **MUTANT-4 finding (schema-invalid `litellm_params: null`):** measured, not assumed. In this
  execution, rung 4 **did** catch it, but not the way a config-schema validator would — litellm
  does not have a graceful pydantic rejection for this shape. `proxy_server.py:4394`'s
  `load_config()` does `for k, v in model["litellm_params"].items():` with no None-check, so a
  `null` `litellm_params` raises an **unhandled `AttributeError`** inside uvicorn's ASGI lifespan
  startup, which prints "Application startup failed. Exiting." and the process dies within ~2
  seconds without ever binding the port (see
  `phase-10/results/20260901T051025Z-validate/mutant4-ladder.tsv` and `mutant4-scratch-boot.log`
  for the actual traceback). `validate_config.sh`'s rung 4 was fixed during this plan's own
  execution to detect this: it now polls whether the scratch process is still alive on every tick,
  not just whether `/v1/models` responds — the first version of the ladder would have technically
  still caught this case, but only after burning the full 90-second timeout waiting for a process
  that was already gone.
  This is a positive result for rung 4's reach on this particular schema-invalid shape, but it is
  one data point on one mutation class, caught by an *unhandled exception*, not by validation — a
  different, less-clean litellm error path might not crash the process at all (e.g. logging and
  continuing with a partially-loaded model list). Plan 10-03 should not read a clean scratch boot as
  an unconditional guarantee against every possible pydantic/config-loading misconfiguration, only
  against the ones actually exercised by this self-test (unclosed YAML flow mapping, `drop_params`
  family, baseline drift, and this one null-params shape).
- **MUTANT-5 finding (deletion overreach into `flashnext`) — CFG-17 fold-in, 2026-09-01:** once the
  candidate started performing a real deletion (the deprecated `qwen-*` block) rather than pure
  insertion, a new failure mode became possible that the original four mutants never exercised: a
  `build_candidate.sh` regression that deletes the right block but *also* corrupts `flashnext` or
  `flashnext-codex` along the way. MUTANT-5 seeds exactly that — the CFG-17-compliant candidate
  (deprecated block already absent) with `flashnext`'s `api_base` additionally changed
  `8011 → 8013` — and asserts rung 3 (the CFG-13 baseline check) catches it, mechanical and
  enforced like MUTANT-1/2/3, not a measurement like MUTANT-4. Observed: **CAUGHT** at rung 3 (see
  `phase-10/results/20260901T052644Z-validate/mutant5-ladder.tsv` and `selftest.tsv`). This is the
  negative control proving the deletion mechanism itself is bounded — without it, nothing would
  have demonstrated that a deletion bug couldn't silently reach into the aliases CFG-13 requires to
  survive.
