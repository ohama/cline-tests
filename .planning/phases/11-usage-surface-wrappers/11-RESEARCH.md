# Phase 11: 사용 표면 — 래퍼와 A/B 게이트 - Research

**Researched:** 2026-09-02
**Domain:** Cline CLI 3.0.60 invocation surface (drifted from the 3.0.53 this project last verified), litellm alias/kwarg-merge semantics (inherited from Phase 10), cline-bench harness limits (inherited from Phase 07), shell-wrapper + negative-test design
**Confidence:** HIGH on the CLI flag surface and the `--thinking`/`-p` mechanism (re-verified live against the installed 3.0.60 binary by decompiled-string reading, the same methodology Phase 1 already used and documented in `docs/cline-config-pins.md` §3). HIGH on Q1 (cline-bench cannot serve USE-03 as-is — this is a hard, already-measured fact, not a probe). MEDIUM on the exact litellm kwarg-merge-with-conflicting-values behavior (source-verified mechanism from Phase 10, but never exercised end-to-end through a real `cline --thinking` call against a `hosted_vllm/` alias — flagged as an open item with a cheap proposed probe). LOW/OPEN on repetition count and exact `max_tokens` ceiling at 3.0.60 (both need a small empirical check before the A/B plan is finalized).

## Summary

Phase 11 has two independent jobs and this research treats them separately because they fail for different reasons.

**The wrapper job (USE-01/02) is more concrete than the ROADMAP text assumes, and one of its premises has already changed.** `.planning/REQUIREMENTS.md`'s CFG-11 rationale states, in a parenthetical, "Cline 은 `--thinking` 을 쓰지 않는다" ("Cline does not use `--thinking`") — true at 3.0.53 (Phase 4's full flag inventory in `docs/cline-config-pins.md` §2 lists no such flag, and `grep -rn "\-\-thinking"` against `/Users/ohama/projs/cline-src` at tag `cli-v3.0.53` returns nothing). **It is false at the installed 3.0.60**: `cline --help` now lists `-p, --plan` ("Run in plan mode") and `--thinking <level>` ("Set reasoning effort: none|low|medium|high|xhigh"), both re-verified live in this research session. This means USE-02's "catch `--thinking high`" requirement is not a defensive check against a hypothetical flag — it is a check against a flag every installed-CLI user can type today. Decompiling the installed Bun-compiled binary (`strings` on `/opt/homebrew/lib/node_modules/cline/bin/.cline`, the same technique `docs/cline-config-pins.md` §3 already used for CFG-04) shows exactly how both flags are wired: `-p`/`--plan` sets Cline's own `mode:"plan"` (tool-availability/system-prompt axis, restricting tools to a `switchToActModeTool`-only set — nothing to do with the model or reasoning), while `--thinking <level>` is validated client-side against exactly `none|low|medium|high|xhigh` and, if not `none`, sets a client-side `reasoningEffort` string that is threaded straight into an outgoing `reasoning_effort` request field. Phase 10's own source reading of litellm's router (`ALIAS-DESIGN.md` §3, `router.py:2447-2453`) shows client kwargs are spread **after** the alias's `litellm_params` in the merged dict — so a client-sent `reasoning_effort` from `--thinking` would **override** whatever the `flashnext-plan`/`flashnext-act` alias injects. USE-01's wrapper therefore has a real job beyond argument convenience: it must prevent `--thinking` (and, more generally, any raw `-m`) from ever reaching the real `cline` invocation, because either flag can silently defeat the mode/alias pairing the wrapper exists to enforce.

**The A/B job (USE-03) is not answerable with cline-bench as it stands, and this is not a new risk to investigate — it is an already-measured fact from Phase 07.** `bench/runs/20260830T122809Z-phase07-fix/summary.md` and `phase-07/results/.../summary.md` record, for the official 12-task cline-bench pool: 4 tasks attempted, 0 passed, 3 reached the model and died at the 32K context ceiling (`fail-context`, at 21K–37K attempted prompt tokens depending on classifier version), 1 died to an unrelated container bug (`fail-infra`, no model contact). Both tasks labelled `difficulty="easy"` in the pool were among the three that overflowed context; the remaining 8 untried tasks are all `medium`/`hard`, i.e. structurally larger, not smaller. There is no reason internal to this evidence to expect any official cline-bench task to complete inside this stack's 32K/29000-token budget, thinking on or off, and this project's own PHASE-10-FINDINGS.md and STATE.md already carry "실제 부하에서 압축이 프루닝하지 않는다. cline-bench 통과 0개" as an accepted, unresolved v1 defect independent of Plan/Act. Running `flashnext` vs `flashnext-plan` on the same cline-bench task set would very likely produce 0/N vs 0/N — a null result that measures the compaction-pruning defect, not whether `medium` thinking helps. **This research recommends Phase 11 build a small, purpose-built supplementary task set** — short (1–3 turn), objectively gradable prompts that stay well under the 26,100-token compaction trigger by construction — run through the real `cline` binary in the same invocation shape Phase 10's VRF-04 already validated, as the actual USE-03 instrument, with cline-bench kept only as a documented, already-answered "why not" citation rather than a live re-run.

**Primary recommendation:** Build `cline-plan`/`cline-act` as thin, argument-filtering shell scripts (not full agents) that hardcode the mode flag and the alias, explicitly reject or strip any caller-supplied `-m`/`-P`/`--thinking`, and invoke the real `cline` via its absolute path (`/opt/homebrew/bin/cline` or `command cline`) to avoid self-shadowing; extend `verify_config.sh` (or add a sibling script it composes with) with a static grep-based assertion on the wrapper scripts' literal contents plus a stub-`cline`-on-PATH dry-run harness (mirroring Phase 4's `HEADLESS_DRY=1` pattern) so the mismatch/`--thinking` negative tests are mechanically falsifiable by mutation, not merely present; and build USE-03's A/B on a small custom task set run directly through `cline`, not through cline-bench/harbor.

---

## Q1 — Does cline-bench, as it stands, give USE-03 a signal? (highest priority)

**No — this is settled by existing evidence, not a new investigation.**

VERIFIED (`bench/runs/20260830T122809Z-phase07-fix/summary.md`, `phase-07/results/<UTC>-phase-close-2/`):

| task | difficulty | verdict | model_turns | max_prompt_tokens_attempted |
|---|---|---|---:|---:|
| discord-trivia-approval-keyerror | easy | fail-context | 38 | 31,179 |
| telegram-plugin-refactor | easy | fail-context | 6 | 36,155 |
| v-edit-workspace-tests | hard | fail-context | 12 | 30,843 |
| filmarchiver | medium | fail-infra (unrelated Bun/AVX segfault in the container, never reached the model) | 0 | 0 |
| 8 remaining tasks (medium/hard) | — | not-run | — | — |

Root causes, VERIFIED (`bench/runs/20260830T122809Z-phase07-fix/summary.md` §"2026-08-31 정정"): `telegram-plugin-refactor` — compaction fired on time but only summarized, pruned nothing, and one unbounded `read_files` tool call alone added ~11,764 tokens, pushing past the wall; `v-edit-workspace-tests` — compaction fired once then was skipped 4 consecutive turns, climbing slowly to the wall; `discord-trivia-approval-keyerror` — root cause indeterminate. This is the same defect STATE.md's Blockers section already names: "🔴 실제 부하에서 압축이 프루닝하지 않는다. cline-bench 통과 0개."

**Why this makes cline-bench uninformative for USE-03, not merely weak:** both `easy`-difficulty tasks — the cheapest, most likely to fit a budget if anything would — already overflow 32K by turn 6–38, independent of any reasoning parameter. `reasoning_effort:medium`'s only measured effect on `prompt_tokens` is **−2** relative to unspecified (`phase-09/PRB-03-ORACLE.md` §2b, corroborated at the shipped alias in `phase-10/REACH-PROOF.md` §3b) and reasoning-history replay costs **0** additional prompt tokens even across a 2,497-character real trace (`phase-09/PRB-04-FINDINGS.md`, 16/16 `delta=0`). Neither effect is large enough to move a task from "overflows by 5,000–15,000 tokens" to "completes." Running `flashnext` vs `flashnext-plan` on this task set does not test whether thinking helps — it tests whether thinking can rescue a task from a wall it was never close to avoiding, which is not what USE-03 asks.

**Concrete alternative, proposed for the plan to adopt (not yet built — this is the recommendation, not a finished artifact):** a small (10–20 item) custom prompt set, run directly via the real `cline` binary (same invocation shape as `phase-10/probe_vrf04_cline.sh`), with these properties:
- **Single-turn or bounded-turn** (2–3 turns max), so no task approaches the 26,100-token compaction trigger (`phase-01/config/verify_config.sh`'s own printed `trigger` value) let alone the 32,768 `MAX_KV_SIZE` wall — by construction, not by hoping compaction behaves.
- **Objectively gradable**, not subjectively judged — multi-step arithmetic/logic word problems, short code-tracing questions ("what does this 20-line function return for input X"), or small self-contained bug-fix-in-one-file prompts with a fixed expected diff/answer, checkable by a script rather than a human or the same model.
- **Chosen to plausibly benefit from reasoning**, not one-liners like VRF-04's prime-sum prompt (which both arms answered correctly — it wasn't hard enough to separate the arms; §3 of `VRF-04-OBSERVATION.md` says this explicitly: "a single easy arithmetic prompt is not designed to distinguish quality either way").
- **Run through the real `cline` binary**, not raw `curl`, because USE-03 is about the actual shipped surface (a wrapper decision), and Cline's own agent loop (system prompt, tool-call framing, NDJSON parsing) is part of what "thinking" would have to help with or not.

This deliberately departs from "official cline-bench" — the research explicitly flags this as a scope decision for the plan/human to ratify, not something this document unilaterally decides. If the plan prefers to stay strictly within official cline-bench materials, the honest fallback is: run the two already-`fail-context` easy tasks under both arms anyway, and report the (expected) 0/2-vs-0/2 result as itself the answer — "no measurable difference, both arms hit an unrelated ceiling" is a valid, evidence-backed, if unsatisfying, USE-03 disposition. This document recommends against that fallback because it wastes the model-server budget on a foregone conclusion, but names it since USE-03 accepts "no improvement" as a valid pass and this technically qualifies.

**Open item for the plan to resolve empirically:** the exact task list and its correct answers must be authored and validated offline (paper-graded) before any model call — this is plan/execution work, not research. Propose: author 10–15 prompts, dry-run each once per arm at plan time (not research time — that would burn model budget, forbidden by this document's own constraints) to confirm none approach the compaction trigger in practice.

---

## Q2 — What must a wrapper actually do, and what flags exist at the installed 3.0.60?

**VERIFIED, live, in this research session** (`cline --version` → `3.0.60`; `cline --help`, full output captured):

```
Arguments:
  prompt                        Your prompt. Default to start in act mode with auto-approve enabled.

Options:
  -p, --plan                    Run in plan mode
  --json                        Output messages as JSON instead of styled text
  --auto-approve <boolean>      Set tool auto-approval for all tools (default: true)
  -c, --cwd <path>              Working directory
  --thinking <level>            Set reasoning effort: none|low|medium|high|xhigh. Bare --thinking uses
                                 medium; omitted leaves provider default.
  --compaction <mode>           Context compaction mode: agentic|basic|off (default: agentic)
  -P, --provider <id>           Provider id (default: cline)
  -m, --model <model-id>        Model to use for the session with the selected provider
  -t, --timeout <seconds>       Optional timeout in seconds (default: 0 for no timeout)
  --config <path>               Configuration directory (default: ~/.cline)
  --data-dir <path>             Use isolated local state at this directory path (default: ~/.cline/data)
  ... (-i/--tui, --id, -k/--key, -s/--system, -z/--zen, --retries, --acp, --hooks-dir, --worktree,
       --update, --kanban, -v/--verbose, -h/--help)
```

**Two flags did not exist at 3.0.53 and are new drift, both directly relevant to this phase:** `-p, --plan` and `--thinking <level>`. Phase 4's flag inventory (`docs/cline-config-pins.md` §2, captured 2026-08-29 against 3.0.53) lists neither. `cline-src` at `cli-v3.0.53` (left untouched per Phase 10's own decision not to re-pin it) also has zero matches for `--thinking`. **This confirms CFG-11's parenthetical ("Cline 은 --thinking 을 쓰지 않는다") is now literally false as a description of what the CLI can do** — it remains true as a description of what the wrapper *should* do (rely on server-side alias injection, never client-side `--thinking`), but the wrapper must now actively enforce that, not merely benefit from the flag's absence.

**What `-p`/`--plan` actually does, VERIFIED by reading the decompiled binary** (`strings -a /opt/homebrew/lib/node_modules/cline/bin/.cline`, the same technique `docs/cline-config-pins.md` §3 used for CFG-04's TUI-toggle finding — the CLI's real entry point is a ~88MB Bun-compiled Mach-O executable; the npm package's own `@cline/*` dist `.js` files are auxiliary libraries, not the CLI parser, and contain zero occurrences of `--thinking`):

```
mode:M.plan?"plan":M.yolo?"yolo":M.zen?"zen":"act", modeExplicitlySet:!!(M.plan||M.act||M.yolo||M.zen)
...
j.config.extraTools=j.mode==="plan"?[j.switchToActModeTool]:[]
```

`-p` sets Cline's own agent **mode** — a tool-availability/system-prompt axis (Plan mode gets only a `switchToActModeTool`, i.e. it cannot use editing/execution tools) — entirely independent of which model alias or reasoning parameter is used. This is not a naming coincidence with `flashnext-plan`; it is a second, orthogonal thing this project has chosen to name the same way. **This matters for USE-03's design (see Q6): comparing the shipped `cline-plan` wrapper (which sets `-p`) against `cline-act` (which does not) would confound "does thinking help" with "does Plan-mode's tool restriction help/hurt" — the A/B should hold the `-p` flag constant (recommend: omit it in both arms, matching Phase 10's own VRF-04 precedent) and vary only `-m <alias>`.**

**What `--thinking <level>` actually does, VERIFIED by the same method:**

```
if(M.thinking!==void 0){let E=String(M.thinking).trim().toLowerCase();
  if(E==="none"||E==="low"||E==="medium"||E==="high"||E==="xhigh")
    if(C.thinkingExplicitlySet=!0,E==="none")
      C.thinking=!1,C.reasoningEffort=void 0;
    else C.thinking=!0,C.reasoningEffort=E;
  else if(E) C.invalidThinkingLevel=E
}
...
// on invalidThinkingLevel:
E(`invalid thinking level "${n.invalidThinkingLevel}" (expected "none", "low", "medium", "high", or "xhigh")`), process.exitCode=1
```

Client-side validation accepts exactly `none|low|medium|high|xhigh` (case-insensitive) and rejects anything else **before any network call**, exiting nonzero with a clear message. Any accepted value except `none` is threaded straight through as `reasoningEffort`, which downstream code (also found in the same strings dump, in the openai-compatible/custom-provider request-building path) maps onto an outgoing `reasoning_effort` request field — the same field name litellm and this stack's aliases already operate on.

**The exact working invocation, VERIFIED (`phase-10/VRF-04-OBSERVATION.md` §1, §6, reproduced and confirmed still consistent with 3.0.60's flag surface in this session):**

```bash
CLINE_NO_AUTO_UPDATE=1 cline -P openai-compatible -m <alias> --compaction agentic --json -t <timeout> "<prompt>"
```

No `-p`/`--plan` flag is required for reasoning injection — `-m <alias>` alone selects it (Phase 10's own handoff note, §5/§6 of `PHASE-10-FINDINGS.md`/`VRF-04-OBSERVATION.md`, is explicit that "No `-p`/`--plan` flag is needed"). **The ROADMAP's success criterion 1 wording — `cline-plan` must always include `-p -m flashnext-plan` — is therefore a deliberate design choice to pair Cline's own Plan-mode tool restriction with the reasoning-heavy alias, not a technical requirement for the reasoning injection itself.** This research recommends the plan honor the ROADMAP's literal wording for the wrapper contract (both flags together) while keeping the A/B harness (Q1/Q6) on the flag-minimal, `-p`-free shape, for the confound reasons above.

**Where the wrappers should live — recommendation, not yet built:** `/opt/homebrew/bin/cline` is a symlink into the npm-managed `cline` package (`/opt/homebrew/lib/node_modules/cline/bin/cline`) and will be overwritten by any `npm install -g cline@...`/auto-update — nothing should be placed there, and the wrapper scripts must never be named `cline`. This project's own convention (Phase 4's `phase-04/run_headless.sh`, Phase 1's `phase-01/config/*.sh`) is per-phase scripts invoked by relative/absolute repo path, not a global PATH install; this repo has no existing `bin/` directory on `$PATH`. Recommend: `phase-11/cline-plan` and `phase-11/cline-act` (executable shell scripts), invoking the real binary via an explicit absolute path (`/opt/homebrew/bin/cline` resolved once, or `command cline` to bypass any shell function/alias shadowing) — never bare `cline`, which could recurse if a user later does put a same-named wrapper ahead of the real binary on PATH. Document in `docs/manual/01-cli.md` (Phase 12/USE-04) that these are invoked by path, consistent with `phase-04/run_headless.sh`'s existing documented usage pattern.

**Alias-selection note carried from Phase 10, already decided, not open:** `cline-plan` → `flashnext-plan`; `cline-act` → `flashnext-act` (not plain `flashnext`) — `ALIAS-DESIGN.md` §5 explicitly built `flashnext-act` so the shipped Plan/Act pair shares the same `hosted_vllm/` prefix, "removing a confound from Phase 11's `cline-plan`/`cline-act` A/B before it can be introduced." Use `flashnext-act`, not `flashnext`, even though Phase 10 measured them as behaviorally indistinguishable (`REACH-PROOF.md` §5, delta=0) — the equivalence is expected and already confirmed, and using the dedicated alias costs nothing.

**Design implication for USE-03's outcome branch:** REQUIREMENTS.md's USE-03 text says a no-improvement result means "래퍼 기본값을 flashnext 로 되돌리고" (revert the wrapper's default to `flashnext`) — i.e., `cline-plan` itself might need to be repointed away from `flashnext-plan` back to plain `flashnext` after the A/B concludes. **Recommendation: define the target alias for each wrapper in one place (a single variable/constant sourced by both scripts, e.g. a small `phase-11/wrapper.env` analogous to `phase-01/config/cline-invocation.env`), not hardcoded independently in each script**, specifically so this revert — if the A/B calls for it — is a one-line change with an audit trail, not a re-edit of wrapper logic.

---

## Q3 — How can `verify_config.sh` detect a mode/alias mismatch or `--thinking high` usage at all?

**The core problem, stated by the task, is correct and not resolvable by extending the current script's approach.** `phase-01/config/verify_config.sh` (VERIFIED, read in full) asserts four static facts about `~/.cline/data/settings/providers.json`: `baseUrl == http://localhost:4000/v1`, `model == "flashnext"`, top-level `contextWindow == 29000`, no `settings.models[]` override, and no literal `"flashnext-codex"` string anywhere under `~/.cline`. **None of this is where a mode/alias mismatch would live.** A mismatch (`cline -p -m flashnext-act`, or `cline -m flashnext-plan` without `-p`) is a property of a specific invocation's argv, and `providers.json` records neither the mode flag nor which alias a given call used — Phase 10 already established `-m` is a per-invocation override that does not persist the model choice into `providers.json` (`model` there stays `"flashnext"` regardless of which alias any given `cline -m <alias>` call actually used — `VRF-04-OBSERVATION.md` §1). There is no config file to inspect after the fact that would reveal a wrapper mismatch.

**Recommended mechanism — two complementary, both mechanically falsifiable, checks, added to (or composed alongside) `verify_config.sh`:**

**(a) Static assertion on the wrapper scripts' own literal contents.** Grep `phase-11/cline-plan` for the exact required substrings (`-p`, `-m flashnext-plan` or the sourced alias variable) and the exact forbidden ones (no other `-m <value>`, no un-guarded `"$@"`/`$*` passthrough that could carry a caller-supplied `-m`/`-P`/`--thinking` to the real binary); grep `phase-11/cline-act` for the inverse (must NOT contain `-p`/`--plan`, must contain `-m flashnext-act`). This is the same class of check `phase-10/CFG-13-EVIDENCE.md` and `build_candidate.sh` already used to prove byte-level alias preservation — cheap, deterministic, and — per this phase's own explicit warning about Phase 10's five silent instruments (`PHASE-10-FINDINGS.md` §4.6) — must be proven capable of failing, not just shown to pass once. **Mutation test to build alongside it, following Phase 10's own established ladder pattern:** copy the real wrapper, edit the copy to swap in the wrong alias (or drop `-p`), run the static check against the mutant, and confirm non-zero exit with a message naming which assertion failed — exactly the `phase-10/selftest_validate_config.sh` pattern (seed mutants, confirm CAUGHT), applied here to shell scripts instead of YAML.

**(b) A stub-`cline`-on-PATH dry-run harness**, extending this project's own established `HEADLESS_DRY=1` precedent (`phase-04/run_headless.sh`, `docs/headless-wrapper.md`) rather than inventing a new pattern: a test-only fake `cline` executable that does nothing but append its received `argv` to a file and exit 0, placed first on `PATH` (or invoked via a `CLINE_BIN_OVERRIDE`-style env var the wrapper scripts read, mirroring the real `cline` package's own resolver comment found in `bin/cline`: "1. `CLINE_BIN_PATH` env var override"). A test harness runs `cline-plan "test"` and `cline-act "test"` under the stub, then asserts the captured argv contains exactly the required flags and none of the forbidden ones. This is strictly stronger than the static grep (it exercises the actual code path a real invocation would take, including any conditional logic in the wrapper, not just its literal text) and costs zero model-server requests — it never reaches `:4000`/`:8011`. **This directly answers the task's framing ("a dry-run mode? a test harness that invokes the wrappers with a stub?") — build both (a) and (b): the static check catches obviously-wrong literals fast, the stub harness catches wrong *behavior* (e.g., a wrapper that greps its own source correctly but has a bug in the actual invocation line).**

**For `--thinking high` specifically**, given Q2's finding that `--thinking` is a real, user-typeable flag that would override the alias's injected `reasoning_effort` if allowed through: the wrapper's own job is to **never forward `--thinking` (in any form) to the real `cline` invocation**, regardless of what the caller passes. The negative test: seed a "leaky" mutant wrapper that does naive `"$@"` passthrough (a plausible, easy-to-write real bug), run it under the stub harness with `cline-plan --thinking high "test"`, and confirm the static/stub check catches the leaked `--thinking` in the captured argv. The real wrapper should either (i) silently drop any `--thinking*` argument before constructing the real invocation, or (ii) detect it and exit nonzero with an explicit error ("cline-plan does not accept --thinking; the alias controls this") — recommend (ii), since silently dropping a flag the user explicitly typed is exactly the `drop_params`-style silent-success failure mode this project has banned twice already (CFG-14; `ALIAS-DESIGN.md` §4).

---

## Q4 — Which failure does a user actually hit through each alias with `--thinking high`?

**This differs by which alias the wrapper points `-m` at, and the two branches are asymmetric — both source-grounded, one already measured, one not yet exercised end-to-end.**

**Through an `openai/`-prefixed alias (`flashnext`, `flashnext-codex`) — VERIFIED mechanism from Phase 10:** `ALIAS-DESIGN.md` §3 shows `reasoning_effort` is not in `OpenAIGPTConfig.get_supported_openai_params()` for a non-o-series model, so **any** non-`none` `--thinking` value (not just `high` — `low`/`medium`/`xhigh` too) triggers litellm's `UnsupportedParamsError`, HTTP 400, before the request ever reaches the model server. If `cline-act` is ever invoked with a leaked `--thinking high`, the observable failure is **HTTP 400 from litellm**, the same class of error Phase 9/10 already characterized for `reasoning_effort` on this alias family.

**Through a `hosted_vllm/`-prefixed alias (`flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh`) — mechanism is source-verified, the specific "high" case is not yet directly measured end-to-end:** `HostedVLLMChatConfig` whitelists `reasoning_effort`, so litellm's validation passes. Per the router's own merge order (`ALIAS-DESIGN.md` §3, `input_kwargs = {**litellm_params, ..., **kwargs}` — client kwargs spread last, so they win on key collision), a client-sent `reasoning_effort:"high"` from `--thinking high` would **override** the alias's own injected `reasoning_effort:medium` (or none, for `flashnext-act`) and reach the actual model server as `reasoning_effort:"high"`. `howto/thinking-and-reasoning-effort.md` §1 documents, citing `~/local-llm-settings/VALIDATED.md` §4, that the model server itself returns **HTTP 500** with the message `Unexpected reasoning effort high. Supported types are xhigh (default), medium, and low.` for this exact value — a model-level rejection, not a gateway-level one. **This 500 was measured via direct :8011 calls in prior phases' validation work, not via a live `cline --thinking high -m flashnext-plan` invocation through the full Cline→litellm→role-shim→model chain** — this document infers (does not verify) that the same 500 propagates through unchanged, on the basis that (a) Phase 10's `REACH-PROOF.md` §4 already closed the `hosted_vllm/`-vs-`openai/`/gateway-hop confound for `prompt_tokens` (delta=0 across three same-body pairings), giving no reason to expect the gateway to alter error propagation either, and (b) litellm forwards upstream HTTP errors by default (no error-remapping config exists in the live `config.yaml`, confirmed by reading it in this session — no `drop_params`, no custom error handler for either new alias).

**Open item for the plan to resolve empirically, with a proposed probe:** one live request, sequential, model idle, `cline -P openai-compatible -m flashnext-plan --thinking high --json -t 60 "2+2"` (or the raw curl equivalent used in prior phases' probes, which is cheaper and avoids a full agent-loop invocation) — confirm the response is HTTP 500 with the documented message, not something else (e.g., litellm's own reasoning_effort enum validation, seen in the decompiled binary's zod schemas for *other* providers as `z.enum(["high","none"])` or similar restricted sets — those are AI-SDK-side schemas for providers Cline talks to directly, e.g. Anthropic/Mistral, and this stack's `openai-compatible` provider path does not appear to use them, but this has not been independently re-derived from source for the exact `openai-compatible` provider code path at 3.0.60, only inferred from the successful `--json` NDJSON captures already made in VRF-04). This single request is within the "trivial and read-only"-adjacent spirit of this project's probes (one short completion, no state mutation) but was correctly not run in this research session per this task's explicit constraint against issuing completions.

**Design implication:** the wrapper's negative-test coverage should assert **both** branches by alias — a mutant/leaky `cline-act`-shaped invocation with `--thinking high` should be asserted (via the stub harness, Q3) to have constructed an argv that would 400 at litellm; a mutant/leaky `cline-plan`-shaped one should be asserted to have constructed an argv that would 500 at the model. Since the wrapper's actual fix is to **never forward `--thinking` at all** (Q3), the stub-harness assertion doesn't need to make a live call to prove this — it only needs to show the forbidden flag never reaches the constructed command line. The live 500-confirmation probe above is a separate, one-time sanity check that the *documented* failure mode is still accurate at 3.0.60, useful for USE-04's documentation (Phase 12) but not required to make USE-02's wrapper-level test pass.

---

## Q5 — Can repeated `cline -m` calls ever corrupt `model`/`contextWindow`, and what guard is cheap?

**VERIFIED (`PHASE-10-FINDINGS.md` §4.4, `VRF-04-OBSERVATION.md` §3/§6):** a single real `cline -m flashnext-plan` invocation at 3.0.60 rewrote `providers.json`'s `openai-compatible.updatedAt` timestamp (`5cf3800d...` → `da53de13...` file hash) while leaving `model` (`"flashnext"`) and top-level `contextWindow` (`29000`) unchanged — contradicting the 3.0.53-sourced assumption that `-m` has zero persistence side effects. `phase-01/config/verify_config.sh` still exits 0 after this mutation, because it asserts `model`/`contextWindow`/`baseUrl`/absence-of-`models[]`/absence-of-`"flashnext-codex"`, never the file's hash.

**What has and has not been tested:** exactly **one** post-mutation observation exists (one `cline -m flashnext-plan` call, one `cline -m flashnext` control call — `VRF-04-OBSERVATION.md` §1). Whether **N repeated** `-m` calls (as the wrapper will generate continuously, by design) could ever compound into an actual `model`/`contextWindow` change — as opposed to merely re-touching the timestamp each time — has not been measured. This is exactly the kind of claim Phase 1's original `verify_config.sh` was built to catch (its own header cites "RESEARCH.md Pitfall 5 observed manually-added providers.json fields silently disappearing after a few `cline` invocations" as the reason the script exists at all) — "a few invocations" was the historically dangerous regime, and the wrapper is about to create a very large number of them.

**The cheap guard, already in hand and already correctly scoped by Phase 10's own handoff (`PHASE-10-FINDINGS.md` §5):** run `verify_config.sh` — unmodified in its assertions — before and after every wrapper invocation (or at minimum, periodically / at the start of every A/B batch), exactly as `phase-04/run_headless.sh` already does for its own live calls (`docs/headless-wrapper.md` §7: "두 스크립트 모두 매 라이브 실행 전후로 `verify_config.sh` → (필요하면) `apply_provider_config.sh` 로 힐 → 재검증 사이클을 돈다"). **Do not add a hash-based check** — Phase 10 explicitly corrected the project's own constraint away from sha256 toward these two field values, precisely because the hash legitimately moves on every `-m` call and a hash-based guard would false-positive on every single wrapper invocation.

**Open item for the plan to resolve empirically, with a proposed probe:** before shipping the wrappers, run a short repeated-invocation probe — e.g. 5–10 sequential `cline -m flashnext-plan`/`cline -m flashnext-act` calls with a trivial prompt (model idle, sequential, matching the project's existing budget discipline), running `verify_config.sh` after each — to establish whether `model`/`contextWindow` ever drift under volume, not just under N=1. This probe is naturally satisfied by the wrapper's own smoke-testing during plan execution (it does not need a dedicated standalone script) — but the plan should explicitly assert `verify_config.sh` passes after each of several consecutive wrapper calls, not just once, before declaring USE-02's config-integrity side covered.

---

## Q6 — What must the A/B control for?

**Fairness axes, each grounded in an already-measured prior finding:**

1. **Hold Cline's own mode flag constant across arms (see Q2).** Comparing `cline-plan` (which sets `-p`, restricting tools) against `cline-act` (which does not) would confound the reasoning-parameter effect with the tool-availability effect. Recommend: for the A/B specifically (not the shipped wrapper contract), invoke both arms with the flag-minimal shape `cline -P openai-compatible -m <alias> --compaction agentic --json -t <timeout> "<prompt>"`, varying only `<alias>` between `flashnext` and `flashnext-plan`, matching `phase-10/probe_vrf04_cline.sh`'s already-validated shape exactly.

2. **`max_tokens`/completion budget must be generous enough that thinking cannot starve the final answer.** VERIFIED (`phase-09/PRB-03-ORACLE.md` §3, restated in `howto/fast-and-deep-mode.md`'s FAQ): with `max_tokens:300`, `xhigh` reasoning consumed the entire completion budget and returned an **empty** final `content` (`finish_reason:"length"`). `howto/fast-and-deep-mode.md` recommends ≥512 for any thinking-enabled call, and separately, `docs/cline-max-tokens-findings.md` (CFG-03) found that **Cline itself does not honor any configured `max_tokens`/`maxTokens` setting** — the wire value observed at 3.0.53 was a fixed **2048**, regardless of what `providers.json`'s `settings.maxTokens`/`settings.models[].maxTokens` held. **Open item:** this 2048 figure has not been re-verified at 3.0.60 (the version drift risk that applies to every other 3.0.53-sourced claim in this project applies here too) — the plan should re-run CFG-03's own recheck recipe (`docs/cline-max-tokens-findings.md` §6, one trivial one-word-reply call, watermarked server log read) before assuming 2048 still holds. If it does hold, 2048 is the *fixed* per-turn completion budget for both arms (not a knob either arm's design can independently tune through Cline) — worth stating in the A/B report as a shared constraint rather than a chosen parameter, since it cannot be set differently per arm through the wrapper anyway.

3. **The task set's own token budget must leave headroom under the fixed 2048-token completion cap** — a task whose expected answer plus any thinking trace would need more than ~2048 completion tokens risks truncation exactly as in the `xhigh`/300-budget case above, independent of the 32K prompt-side ceiling Q1 discusses. Short, bounded-answer tasks (Q1's recommendation) satisfy this by construction.

4. **The model samples stochastically, not deterministically — VERIFIED.** The Flash-Next model's own `generation_config.json` (`/Users/ohama/projs/qwen38-flash-next-tests/.../generation_config.json`, read directly in this session) declares `"do_sample": true, "temperature": 1.0, "top_k": 20, "top_p": 0.95"`. No `temperature`/sampling override exists anywhere in the live `litellm` config or in any `cline`-side request-shaping code found in this session's decompiled-string search. **This means a single run per task per arm cannot distinguish a real accuracy difference from sampling noise.** Recommend **N≥3 repetitions per task per arm** as a floor (not a ceiling) — the plan should size N against the actual task-set size and the shared `--max-num-seqs 1` budget (every repetition is a fully sequential, queued request competing with Kanban/Telegram), and should prefer more tasks over more repetitions-per-task if forced to choose, since task diversity is what the "does thinking help on genuinely reasoning-shaped problems" question actually needs, while repetition mainly buys confidence in each individual data point.

5. **Timeout (`-t`):** VRF-04 used `-t 600` for a single-turn arithmetic prompt; the A/B's short bounded-turn tasks should need materially less, but should still budget generously enough that a slow thinking-arm generation isn't cut off mid-response — recommend keeping `-t 600` as a safe default carried forward rather than tuning it down, since a timeout-induced truncation would look identical to a genuine wrong-answer failure in the results table unless distinguished.

6. **`CLINE_NO_AUTO_UPDATE=1` should be set for every A/B call**, not because it is proven to prevent drift (CFG-05 is explicitly unresolved and carried to v1.2+, and Phase 10 observed the binary had already moved from 3.0.53 to 3.0.60 silently between phases) but because an A/B run that spans enough wall-clock time for a background auto-update to land mid-run would silently invalidate the "same binary, same flag surface" assumption both arms depend on. Recommend the plan also capture `cline --version` immediately before and immediately after the full A/B batch (VRF-04's own precedent) and treat any mismatch as grounds to discard the run rather than report it.

---

## Q7 — Where should the A/B evidence live, and what makes the decision auditable?

**Follow this project's own already-established, repeatedly-validated documentation pattern** (Phase 07's `summary.md`+`verify_bench.sh`, Phase 10's `REACH-PROOF.md`/`PHASE-10-FINDINGS.md`+`verify_reach.sh`) rather than inventing a new one:

- **A re-runnable script** (e.g. `phase-11/run_ab.sh`) that fires the fixed task set against both aliases, sequential, with the fairness controls from Q6 encoded as constants (not left to be remembered), and writes raw NDJSON + timing + a machine-readable results table to a timestamped `phase-11/results/<UTC>-ab/` directory — mirroring `phase-10/verify_reach.sh`'s own re-run-three-times-and-agree pattern for VRF-03.
- **A findings document** (e.g. `phase-11/AB-RESULTS.md`, analogous to `phase-10/REACH-PROOF.md`) containing: the exact task list and each task's expected/graded answer; a per-task, per-arm, per-repetition raw table (correct/incorrect, wall-clock seconds, `prompt_tokens`/`completion_tokens` if capturable from the server log the way Phase 9/10 already do); an aggregate accuracy-and-median-latency-per-arm summary; and — following `REACH-PROOF.md` §8's and `PHASE-10-FINDINGS.md`'s own established practice — a section stating **what result would have produced the opposite decision**, written before the numbers are looked at rather than fitted after.
- **The decision statement itself**, stated as its own labeled line (not buried in prose): "keep `cline-plan` → `flashnext-plan`" or "revert `cline-plan` → `flashnext`", plus which requirement (USE-03) and ROADMAP criterion it satisfies, plus an explicit note that "no improvement" is being treated as a valid, complete answer per the requirement's own text — not as an unfinished experiment.
- **A phase-close findings document** (`phase-11/PHASE-11-FINDINGS.md`, matching Phase 10's own `PHASE-10-FINDINGS.md` structure: what changed, requirement table, ROADMAP criterion table, a disclosures section for anything weaker than it looks) so Phase 12's documentation work (USE-04/USE-05) has one authoritative source to update the manual and design docs from, rather than needing to re-derive the decision from raw run directories.
- A future reader re-deriving the decision needs, at minimum: the task list + expected answers (to confirm grading wasn't post-hoc), the raw per-repetition table (to recompute the aggregate independently), the fairness-control constants actually used (max_tokens/timeout/mode-flag/alias pair, per Q6), and the `cline --version` bracketing the run (to know which binary produced the numbers). Store all four in the same results directory rather than splitting across phases.

**Minor open item, not blocking:** `PHASE-10-FINDINGS.md` §5 flags `flashnext-reach-xhigh` as dead-or-not-yet-decided configuration once Phase 10's reach questions are closed — Phase 11/12 should note in the A/B findings document whether it is still needed (it is not part of the A/B itself, which only needs `flashnext`/`flashnext-plan`) so the decision isn't silently dropped a second time.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Detecting `cline` binary/flag drift | A new version-pinning mechanism | `phase-01/config/check_versions.sh` (already exists, already the project's standing drift monitor) | Duplicate drift-detection would itself need to be kept in sync with the original |
| Dry-run testing without live model cost | A bespoke mocking framework | The `HEADLESS_DRY=1`/fixture-NDJSON pattern from `phase-04/run_headless.sh` | Already built, already documented, already the project's own precedent for exactly this need |
| Config-integrity guard after repeated `-m` calls | A new hash-based or schema-based checker | `phase-01/config/verify_config.sh`, called before/after, unmodified in its field assertions | Phase 10 already corrected the project away from hash-based checks for this exact reason (§5 above) |
| Mutation-testing a shell script or config | Manual code review only | The seed-a-mutant-and-confirm-CAUGHT ladder pattern from `phase-10/selftest_validate_config.sh`/`build_candidate.sh` | This project has now (Phase 10) found five instruments that silently observed nothing; the only defense demonstrated to work here is deliberately breaking the thing and confirming the check notices |

## Common Pitfalls

### Pitfall 1: Treating cline-bench's 0/4 as a starting point to improve on, rather than a disqualifying confound
**What goes wrong:** running the A/B on cline-bench and reporting "0/4 vs 0/4, no improvement" as if it answered USE-03.
**Why it happens:** the ROADMAP text literally says "cline-bench," and the natural reading is to reuse Phase 07's existing harness.
**How to avoid:** cite Q1's evidence (both `easy` tasks already overflow context by 5,000–15,000 tokens, unrelated to thinking) explicitly in the plan before choosing a task set.
**Warning signs:** any A/B result table where every row is `fail-context` regardless of arm.

### Pitfall 2: Letting a caller-supplied `--thinking`/`-m` reach the real `cline` invocation
**What goes wrong:** a wrapper that does `exec cline -P openai-compatible -m flashnext-plan "$@"` looks correct but silently lets a caller append `--thinking high` or `-m flashnext`, defeating USE-01's entire pairing guarantee (Q2/Q4).
**Why it happens:** `"$@"` passthrough is the easiest way to write a wrapper that "just forwards the prompt."
**How to avoid:** explicit argument parsing that rejects/strips `-m`, `-P`, `--thinking*` before constructing the real invocation; test this with the stub-harness leaky-mutant pattern (Q3).
**Warning signs:** the wrapper script contains `"$@"` or `$*` anywhere after the hardcoded `-m`/`-P` flags.

### Pitfall 3: Comparing `cline-plan` vs `cline-act` (the wrappers) for the A/B instead of `flashnext` vs `flashnext-plan` (the aliases)
**What goes wrong:** the `-p` mode-flag difference (tool availability) confounds with the reasoning-parameter difference (Q2/Q6).
**Why it happens:** the wrappers are the shipped surface, so it's tempting to A/B "the real thing users will type."
**How to avoid:** run the A/B at the flag-minimal `cline -m <alias>` shape, and treat the wrapper-level end-to-end behavior as a separate, already-covered concern (USE-01's own tests).

### Pitfall 4: Assuming 3.0.53-sourced facts (flag surface, max_tokens=2048, `-m` persistence) still hold at 3.0.60 without saying so
**What goes wrong:** silently inheriting a stale citation the way `PHASE-10-FINDINGS.md` §4.3/§4.4 already found happened once (CFG-05 auto-update drift, source citations not re-verified).
**Why it happens:** re-verifying every prior claim at every new phase is expensive, and most claims do still hold.
**How to avoid:** this document already re-verified the flag surface and the `-p`/`--thinking` mechanism live; it explicitly flags `max_tokens=2048` and the `--thinking high`→500 propagation as NOT yet re-verified at 3.0.60, with cheap proposed probes (Q4, Q6.2).

## Open Questions

1. **Does `reasoning_effort:"high"` sent through `flashnext-plan` (via a leaked `--thinking high`) actually produce HTTP 500 all the way through the real `cline`→litellm→role-shim→model chain, or does litellm's own schema intercept it first?**
   - What we know: the model server 500s on `reasoning_effort:"high"` when called directly (VALIDATED.md §4, cited in `howto/thinking-and-reasoning-effort.md`); litellm's kwarg-merge mechanism (source-verified) would let a client value override the alias's injected one; no interposing validation/error-remapping for this value exists in the live config.
   - What's unclear: whether anything in the litellm/`hosted_vllm` request path validates the *value* of `reasoning_effort` (not just its presence) before forwarding.
   - Recommendation: one live probe at plan/execution time (Q4), not required to make USE-02's wrapper-level tests pass, since the wrapper's fix is to block `--thinking` outright regardless of which error it would have produced.

2. **Is `max_tokens=2048` still the fixed wire value Cline sends per turn at 3.0.60?**
   - What we know: measured `2048` at 3.0.53 (`docs/cline-max-tokens-findings.md`), independent of any `providers.json` setting.
   - What's unclear: whether this changed across the 3.0.53→3.0.60 drift, given `--thinking`/`-p` were also added in that span.
   - Recommendation: re-run `docs/cline-max-tokens-findings.md` §6's own recheck recipe once, before finalizing the A/B's task-set answer-length budget.

3. **Does volume (N≥5) of repeated `cline -m` calls ever move `model`/`contextWindow` in `providers.json`, not just `updatedAt`?**
   - What we know: N=1 leaves both fields intact (VRF-04).
   - What's unclear: N=1 is not evidence about N=10+, and the wrapper's whole purpose is to generate many calls.
   - Recommendation: fold this into the wrapper's own execution-time smoke test (Q5) rather than a standalone probe — run `verify_config.sh` after each of several consecutive wrapper invocations during plan execution and record the results.

4. **What is the correct N (repetitions per task per arm) and task-set size for a statistically meaningful USE-03 verdict, given genuinely stochastic sampling (temperature=1.0) and a single-concurrency shared model?**
   - What we know: sampling is not deterministic (generation_config.json, VERIFIED); more tasks likely beats more repetitions for answering "does thinking help on reasoning-shaped problems"; every repetition competes with Kanban/Telegram on the same queue.
   - What's unclear: the exact N/task-count tradeoff that is both affordable and defensible.
   - Recommendation: plan should size this explicitly and state the budget tradeoff in `AB-RESULTS.md`, following this project's practice of naming its own request-budget overages honestly (`PHASE-10-FINDINGS.md` §4.5) rather than leaving the choice implicit.

## Sources

### Primary (HIGH confidence — read directly in this session)
- `cline --version` / `cline --help`, live, installed 3.0.60 — full flag surface captured verbatim above
- `strings -a /opt/homebrew/lib/node_modules/cline/bin/.cline` (the compiled CLI binary) — `-p`/`--plan` mode semantics, `--thinking` client-side validation and `reasoningEffort` threading, `invalidThinkingLevel` error message
- `/opt/homebrew/lib/node_modules/cline/node_modules/@cline/core/dist/index.js` and sibling `@cline/*` packages — confirmed to NOT contain the CLI's own flag parser (auxiliary libraries only)
- `bash phase-01/config/verify_config.sh` (live, read-only, current pass output including the printed `trigger = 26100` value)
- `grep -n "model_name:" /Users/ohama/agent-stack/litellm/config.yaml` and direct read of the `flashnext-plan`/`flashnext-act`/`flashnext-reach-xhigh` blocks (live, read-only) — confirmed injected params match `ALIAS-DESIGN.md`'s record exactly, no `drop_params` anywhere
- `/Users/ohama/projs/qwen38-flash-next-tests/.../generation_config.json` (both variants found) — `do_sample:true, temperature:1.0, top_k:20, top_p:0.95`
- `cd /Users/ohama/projs/cline-src && git describe --tags` → `cli-v3.0.53`; `grep -rn "\-\-thinking"` against it → zero matches
- `phase-01/config/verify_config.sh` (full file read)
- `bench/runs/20260830T122809Z-phase07-fix/summary.md`, `bench/cline-bench/tasks/*/task.toml` (difficulty labels, all 12)

### Secondary (project's own prior-phase documents, MEDIUM-HIGH — internally cross-verified, not independently re-run in this session)
- `phase-10/PHASE-10-FINDINGS.md`, `phase-10/ALIAS-DESIGN.md`, `phase-10/REACH-PROOF.md`, `phase-10/VRF-04-OBSERVATION.md`
- `docs/headless-wrapper.md`, `docs/cline-config-pins.md`, `docs/cline-max-tokens-findings.md`, `docs/cline-bench.md`
- `howto/fast-and-deep-mode.md`, `howto/thinking-and-reasoning-effort.md`
- `.planning/STATE.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`
- `phase-09/PRB-03-ORACLE.md`, `phase-09/PRB-04-FINDINGS.md` (cited via the above, not re-opened directly in this session)

### Tertiary (referenced but not independently re-read in this session)
- `~/local-llm-settings/VALIDATED.md` §4 — cited via `howto/thinking-and-reasoning-effort.md` for the `high`→500 model-server message

## Metadata

**Confidence breakdown:**
- Wrapper flag surface / `-p`/`--thinking` mechanism (Q2): HIGH — re-verified live against the installed binary this session, not carried over from a stale citation
- cline-bench's inability to serve USE-03 (Q1): HIGH — already-measured fact from a completed, verified phase, not a new claim
- `--thinking high` failure mode by alias (Q4): MEDIUM — mechanism verified from source, the specific end-to-end 500 propagation through the full chain not yet live-tested
- A/B fairness controls (Q6): MEDIUM — each individual constraint is source-grounded, but the `max_tokens=2048` figure and the repetition-count sizing are flagged open, needing a cheap pre-plan probe
- `verify_config.sh` extension mechanism (Q3): HIGH on the diagnosis (a config-file check cannot see an invocation), MEDIUM on the specific recommended mechanism (grep + stub harness) since neither has been built or tested yet — this is a design recommendation for the plan, not a verified artifact

**Research date:** 2026-09-02
**Valid until:** re-verify the flag surface and any 3.0.53-sourced figures (`max_tokens=2048`, wrapper invocation shape) if `cline --version` ever reports anything other than `3.0.60` — CFG-05 (auto-update not actually blocked) means this could happen at any time, silently, per `PHASE-10-FINDINGS.md` §4.3/§4.4.
