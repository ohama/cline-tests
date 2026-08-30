# Phase 7: cline-bench 동작 검증 - Research

**Researched:** 2026-08-30
**Domain:** Harbor (harbor-framework/harbor, formerly laude-institute/harbor) — the agent-eval CLI that drives `cline-bench`'s official task suite in local Docker containers; container↔host networking under colima; Cline CLI's context-window fallback behavior when unconfigured
**Confidence:** HIGH on install method, task inventory, Docker networking, and the tool-use/sandbox question (all verified live on this exact machine or against real upstream source at today's `main`). MEDIUM on the exact BASE_URL propagation mechanism and the `openai` vs `openai-compatible` provider-slug question (traced deep into harbor's source but not confirmed by an actual live `harbor run`, since a real run was out of scope for research). LOW/flagged on wall-clock cost, which is genuinely unknowable without a live smoke test — treated as the phase's first required action, not a research gap to paper over.

## Summary

`harbor` is real, actively maintained (4,767 GitHub stars, `harbor-framework/harbor`, Apache-2.0, described by its own docs as "the official successor to Terminal-Bench," published by the Laude Institute). **It is not the CNCF/goharbor.io container-registry project** — same name, unrelated software, worth stating explicitly since the name collision is real and Googling "harbor" surfaces the registry first. It installs as a plain PyPI package (`uv tool install harbor`, confirmed live on PyPI as `harbor==0.22.0`) and is **not currently installed on this machine** (`which harbor` → not found), matching what the orchestrator's live check already found. `cline-bench` itself is a thin task-definition repo (`github.com/cline/cline-bench`) that ships zero runner code — `harbor` is the actual execution engine. This corrects prior project research: **the live repo contains exactly 14 task directories today**, not the "~89-task pool" figure carried forward from earlier research (that number describes a different, larger internal Cline benchmark referenced in a blog post, not what's in the public repo). Running 5–8 of 14 is 36–57% of the entire available official pool — a much bigger commitment than "a small subset of 89" implied, worth saying plainly to whoever plans this phase.

Two of this phase's presumed central risks turned out, on live verification, to **not** be real obstacles at all, and one turned out to be a real obstacle the prior research hadn't found. First, host reachability: this Mac's Docker runs via **colima** (not Docker Desktop), and a live test (`docker run --rm alpine ... curl http://host.docker.internal:4000/`) proved that a container reaches litellm's `:4000` — which is bound **strictly to `127.0.0.1`**, unchanged since Phase 2 — cleanly, with a real `200 OK` and the live `flashnext` model list back. Colima proxies `host.docker.internal` (resolving to `192.168.5.2` in the VM) straight through to the host's loopback interface; no host bind change, no new listener, nothing to touch. Second, the tool-use collision the orchestrator flagged as possibly central: reading harbor's actual `cline-cli` agent adapter source shows it invokes `cline ... --yolo` (full auto-approve) **inside the ephemeral Docker container it creates**, completely independent of this project's host-side `cline` binary, `run_headless.sh`, sandbox-exec whitelist, or the still-unresolved `--auto-approve false`/`--no-tools` escalation decision carried unresolved through Phases 4→5→6. **The container is Harbor's sandbox boundary, not `sandbox-exec`.** Running cline-bench requires zero change to this project's shipped host posture and does not, by itself, force the escalation decision that phase-close docs for Phases 4–6 keep flagging as still-pending — it can be answered "not applicable to this run" rather than "decided."

The real, newly-discovered obstacle is the **container's Cline instance is unconfigured**. Harbor's `cline-cli` adapter installs `cline@nightly` from npm by default (not this project's pinned `3.0.53`, though `--agent-kwarg cline-version=3.0.53` can pin it) into a fresh `~/.cline/data` inside the throwaway container, and its documented flag surface exposes only `--thinking` and `--max-consecutive-mistakes` — **no way to set `contextWindow`.** This project's entire Phase 1 exists because an unconfigured Cline falls back to `contextWindow = maxInputTokens = 128,000` for any `openai-compatible`-family model (verified against `cline/cline`'s live `main` branch, `builtins.ts`, same code path `cline-analysis.md` already documented). Compaction is on by default (`--compaction` defaults to `agentic`, matching this project's own pin), but it won't fire until ~115,200 tokens — far past the point where this stack's model server already hard-rejects any request with `prompt + max_tokens > 32,768` (a decision Phase 1 already made and validated: the server enforces the ceiling, no gateway-side guard needed). In plain terms: **the exact fallback bug this whole project was built to catch will very likely reproduce inside every cline-bench container**, and the realistic failure mode is an early, clean `400` a few turns into a task — not a graceful agent failure. That is legitimate, disclosable data for BCH-03 (a real "실패" with an explained cause), not a broken harness — but it means "5-8 tasks pass" is not a safe planning assumption, and the plan must decide up front whether cline-bench is being used to prove *task completion* or to prove *pipeline plumbing end-to-end under real conditions, including this known limitation*.

**Primary recommendation:** Treat this phase as two decisions plus one action, in order. (1) Install `harbor` in `bench/cline-bench/` exactly as its README prescribes (`uv venv --python 3.13 && source .venv/bin/activate && uv tool install harbor`), keeping the whole tree outside `ALLOWED_REPOS.json` (already true — `bench/` is already excluded and `bench/runs/CANARY.txt` already exists and already passes SBX-04's live sandbox-denial check from Phase 3). (2) Run **exactly one** smoke task first — `01k7a12sd1nk15j08e6x0x7v9e-discord-trivia-approval-keyerror` (easy, 29-line instruction, 2048 MB, fits colima's current 4 GiB VM without resizing) — with `-a cline-cli -m openai-compatible:flashnext --env docker`, `BASE_URL=http://host.docker.internal:4000/v1`, `API_KEY=<any non-empty string>`, `--agent-kwarg cline-version=3.0.53`, and read the resulting `agent/cline.txt` + `verifier/reward.txt` before committing to anything else. That one run answers, empirically and cheaply, the two things this research could not fully settle from source alone (whether `-P openai-compatible` actually reaches this stack correctly, and how many turns actually happen before a context-related failure), and it directly determines whether the remaining 4–7 tasks are worth an hour or worth an evening. (3) Only after that, decide the task list and write the pass/fail/duration table — do not schedule "5-8 tasks overnight" before the smoke result is in hand.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|---------------|
| `harbor` | latest on PyPI is `0.22.0`; pin whatever `uv tool install harbor` resolves on the day of the run and record it in the run's `config.json` (harbor's own job output already does this) | The actual eval-execution CLI (`harbor run -p <task> -a <agent> -m <provider:model> --env docker`) — cline-bench is only task data, harbor is the runner | Official, actively maintained (harbor-framework org, 4,767★, Apache-2.0), explicitly what cline-bench's own README instructs |
| `cline-bench` (git checkout) | `github.com/cline/cline-bench`, `main`, pin the commit SHA at checkout time into the run's own `config.json` | Provides the 14 task directories (`instruction.md`, `task.toml`, `environment/Dockerfile`, `solution/solve.sh`, `tests/`) that harbor executes | The only public, cline-specific benchmark; matches PROJECT.md's explicit decision to use an official harness over a self-authored one |
| `uv` | 0.11.14 (already installed, confirmed live) | Creates the pinned Python 3.13 venv cline-bench requires (`uv venv --python 3.13`) and installs `harbor` into it (`uv tool install harbor`) | Host's system `python3` is 3.14.6; cline-bench requires exactly 3.13. `uv python list` already shows `cpython-3.13.13-macos-aarch64-none` available — zero extra install needed |
| `docker` (via `colima`) | Docker 29.5.2 client, colima-managed daemon (confirmed live: `docker info` → `Name: colima`) | Runs each task's `environment/Dockerfile` as an isolated container; the `cline-cli` agent (and its own fresh `cline` install) runs *inside* that container | Already running; no new install needed. Colima's default profile is `4 CPUs / 4 GiB / 20 GiB disk` (confirmed live via `colima list`) |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `--agent-kwarg cline-version=3.0.53` | Pins the container-side `cline` install to this project's validated version instead of harbor's default `cline@nightly` | Every invocation — an un-pinned `nightly` install inside the container is one more uncontrolled variable stacked on top of the already-known contextWindow fallback risk |
| `--agent-kwarg thinking=none` (or omit) | The only documented way to touch reasoning effort through harbor's adapter (`--thinking`/`reasoning-effort` alias) | Leave at whatever cline's own default is unless a task clearly benefits; this project's own constraints already ruled out `high`/heavy `enable_thinking` |
| `bash phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline` | Standing gate, already explicitly handed to this phase in `docs/network-exposure.md` §9 | Before and after the bench run — confirm `CASES 24/24` unchanged |
| `phase-01/config/verify_config.sh` | Standing gate | Before/after — a `harbor` invocation does not touch the host's `cline`/`providers.json` at all (it never calls the host binary), but the gate is cheap and the house rule is "call it around any `cline`-adjacent activity" |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `--env docker` (local) | `--env daytona` (cloud) | Needs `DAYTONA_API_KEY` (not present, costs money, explicitly the path PROJECT.md ruled out — "인터넷 노출 없음" and "실토큰 트라이얼 거절" are already the project's posture from Phase 6). Not considered further. |
| Official `cline-bench` tasks | Hand-authoring test tasks | PROJECT.md's own decision log already rejects this ("자작 테스트는 내가 아는 것만 검증한다") — not revisited here |
| `-m openai-compatible:flashnext` | `-m openai:flashnext` (harbor README's literal example) | See Pitfall 3 below — `openai` is not a registered Cline provider id in the live `cline/cline` source; `openai-compatible` is, and it's this project's own already-validated provider id |

**Installation (host-side, inside `bench/cline-bench/`, outside `ALLOWED_REPOS.json`):**
```bash
cd /Users/ohama/projs/cline-tests/bench
git clone https://github.com/cline/cline-bench.git   # record the resulting commit SHA
cd cline-bench
uv venv --python 3.13
source .venv/bin/activate
uv tool install harbor
which harbor   # README expects .venv/bin/harbor; if it instead lands in ~/.local/bin, that's uv's normal
               # `uv tool install` behavior (isolated tool venv, not the just-activated project venv) —
               # not a bug, just confirm it's actually reachable and record the real path
harbor --version
```

## Architecture Patterns

### Recommended Project Structure
This matches `.planning/research/ARCHITECTURE.md` §7 almost exactly — that design already anticipated this phase correctly, and Phase 3 already built the sandbox side of it (see Pitfall 6). Nothing here needs to change; this section just confirms it against live facts.

```
bench/                                   ← already exists (git-tracked, empty besides runs/CANARY.txt)
  cline-bench/                           ← new: clean checkout of github.com/cline/cline-bench
    .venv/                               ← uv venv, python 3.13, harbor installed into it
    tasks/                               ← 14 official task dirs (confirmed count, 2026-08-30)
  runs/
    CANARY.txt                           ← already exists — SBX-04 sentinel, do not remove
    <UTC-timestamp>-<label>/
      config.json                        ← task IDs run, cline-bench commit SHA, harbor version, MODELID used
      prompts/                           ← this project's OWN capture layer, see Don't Hand-Roll below
      jobs/                              ← harbor's own native output, copied/symlinked in verbatim
        <job-timestamp>/
          config.json
          result.json                    ← aggregate reward
          <task-id>__<hash>/
            config.json
            result.json                  ← per-trial reward, timing, cost
            agent/
              cline.txt                  ← full Cline conversation log (primary prompt+result artifact — verify raw system prompt presence empirically, see Open Questions)
              setup/                     ← install logs
              command-0/, command-1/     ← exact shell commands harbor ran, incl. env
            verifier/
              reward.txt                 ← 1 or 0
              test-stdout.txt / test-stderr.txt
      summary.md                         ← human rollup: BCH-03's pass/fail + duration table
  latest → runs/<most-recent>            ← convenience symlink only
```

**Why `bench/cline-bench/` and not repo root:** `ALLOWED_REPOS.json`'s own comment (already in the file, written in Phase 3) states explicitly: *"the repo root ... must NEVER be added as an entry, because bench/ lives under it and SBX-04 (criterion 4) requires bench/ to be unreachable from inside the sandbox."* Nothing in this repo's sandboxed surfaces should ever point at `bench/` — that invariant already holds and this phase must not weaken it just because `harbor` itself is a new, unsandboxed host process (see Pitfall 6).

### Pattern: harbor's own `jobs/` output is the source of truth; this project's role is capture + honesty, not re-implementation
**What:** Don't parse or re-derive pass/fail from `agent/cline.txt` transcripts by hand. `verifier/reward.txt` (literal `1` or `0`) is harbor's own scoring output, already binary and unambiguous. `result.json` (per-trial) carries timing.
**When to use:** Building the BCH-03 summary table — just walk each trial directory's `result.json`/`reward.txt` and tabulate; do not hand-write a grader.
**Example (from harbor's own documented Quick Commands, README, verified live):**
```bash
LATEST=$(ls -td jobs/2026-*/ | head -1)
cat "${LATEST}"*/verifier/reward.txt          # 1 = pass, 0 = fail
grep -c "PASSED\|FAILED" "${LATEST}"*/verifier/test-stdout.txt
tail -50 "${LATEST}"*/agent/cline.txt          # last agent actions
```

### Anti-Patterns to Avoid
- **Editing `environment/Dockerfile` or `task.toml` inside a task to "make it pass."** That stops being an official-task run and starts being a self-authored one, defeating PROJECT.md's own reason for using cline-bench at all.
- **Treating a `400`/context-overflow failure as a harness bug and suppressing it from the BCH-03 table.** Given the fallback-to-128k finding above, at least some failures of this exact shape are expected and explainable — report them as what they are (a real, disclosed limitation of running an unconfigured Cline instance against a 32K-ceiling backend), not as noise to exclude.
- **Running all 5–8 tasks in one unattended batch before a single smoke result exists.** See Pitfall 4/Summary — the cost and success rate are both unknown until one task has actually been observed end-to-end.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pass/fail grading | A custom test-output parser | `verifier/reward.txt` (harbor's own binary score) | Already exact, already file-based, already what BCH-03 needs |
| Task selection/orchestration loop | A custom Python/shell runner that drives cline-cli directly | `harbor run -p <task> ...` invoked once per selected task (a simple shell loop over task directories) | Harbor already handles container lifecycle, timeouts, log capture, teardown; hand-rolling this duplicates a maintained tool for no benefit |
| Result directory structure | A bespoke schema | Harbor's native `jobs/<timestamp>/<task>__<hash>/{agent,verifier}/` layout, copied into `bench/runs/<UTC>-<label>/jobs/` verbatim | ARCHITECTURE.md's own layout already treats harbor's output as authoritative and additive, not replaced |

**Key insight:** The only thing this project needs to add on top of harbor is (a) the outer timestamped-run wrapper directory so multiple runs are diffable/self-describing (ARCHITECTURE.md's own stated reason — full-suite completion is out of scope, so any two runs may cover different task subsets and need their own `config.json`), and (b) explicit verbatim prompt capture if `agent/cline.txt` turns out not to include the raw system/user prompt (see Open Questions) — everything else is upstream's job.

## Common Pitfalls

### Pitfall 1: Container-side Cline is unconfigured and will very likely hit the exact 128k-fallback bug this project's Phase 1 was built to catch
**What goes wrong:** Harbor's `cline-cli` adapter (`src/harbor/agents/installed/cline/cline.py` in `harbor-framework/harbor`, read directly) installs a fresh `cline` into each container's own `~/.cline/data` and invokes it as `cline -P <provider> -k $API_KEY -m $MODELID --json --yolo [--thinking ...] [--max-consecutive-mistakes ...] -- <prompt>`. There is no flag, agent-kwarg, or env var in the adapter's documented surface that sets `contextWindow`. Verified live against `cline/cline`'s actual `main` branch (`sdk/packages/llms/src/providers/builtins.ts`): any provider whose `spec.family === "openai-compatible"` (which `openai-compatible` — this project's own provider id — is) falls back to `contextWindow = maxInputTokens = 128_000` when no explicit config overrides it. This is the identical bug class `cline-analysis.md` already catalogued (`#12520`, `#13457`). Compaction is on by default (`--compaction` defaults to `agentic` per this project's own `docs/cline-config-pins.md`, itself already re-verified against `cline --help` output), but it won't trigger until ~90% of 128,000 ≈ 115,200 tokens — far past this stack's real, already-enforced ceiling (`prompt + max_tokens > 32,768` → HTTP 400 from the model server, a decision Phase 1 already validated and deliberately did not duplicate with a second gateway-side guard).
**Why it happens:** Harbor's adapter is generic across ~10+ agents and was never built to know about this project's specific 32K/compaction tuning; it exposes only `--thinking` and `--max-consecutive-mistakes` as configurable CLI flags.
**How to avoid:** Cannot be fully avoided without patching harbor's source (explicitly out of scope — PROJECT.md rules out upstream PRs, and patching would also stop this being an "official" run). The honest posture: expect early-turn `400`s on at least some tasks, especially instruction.md bodies that embed large boilerplate (the `terraform-azurerm` sample task's `instruction.md` includes a full VS-Code-style `<environment_details>` block with open-tabs/visible-files lists — not a small prompt). Run the single smoke task first specifically to observe how many turns actually happen before this fires, and report the failure honestly as "context-window-mismatch failure," distinct from "the model failed the task on its merits," in the BCH-03 table.
**Warning signs:** `agent/cline.txt` shows a `400`-class HTTP error a few turns in with no preceding sign of the model actually struggling with the task; `verifier/reward.txt` is `0` but `test-stdout.txt` shows the solution was barely attempted.

### Pitfall 2: The task pool is 14, not ~89 — running 5-8 is not "a small sample"
**What goes wrong:** Prior project research (`FEATURES.md` §3, carried from `cline-analysis.md`) cited an "89-task pool" figure for cline-bench. A live `git clone` of `github.com/cline/cline-bench` today (2026-08-30) shows **exactly 14 task directories**. The 89-task figure describes a different, larger Terminal-Bench-2.0-derived internal set referenced in a Cline blog post — not what's in the public repo this project actually points at.
**Why it happens:** Two different numbers were conflated across research passes; neither was re-verified against the live repo until now.
**How to avoid:** Plan against 14 as the real denominator. 5–8 tasks is 36–57% of everything publicly available — a defensible "partial run" per PROJECT.md's own stated rationale (per-task timeout vs. TTFT), but it should be described that way, not as "a small slice of a large pool."
**Warning signs:** none at runtime — this is a planning-input correction, not a live failure mode.

### Pitfall 3: `harbor`'s own README example (`-m openai:model-id`) may not be the right provider slug for this stack
**What goes wrong:** cline-bench's README documents `-m openai:your-model-id` as the pattern for "OpenAI-compatible endpoints (local LLMs, Ollama, vLLM)." But `harbor`'s `cline.py` adapter does no provider-id validation or remapping (only `vercel → vercel-ai-gateway` is special-cased) — whatever string precedes the `:` in `-m <string>:<model>` is passed straight through as `cline -P <string> ...`. A live read of `cline/cline`'s `builtins.ts` on `main` shows the registered builtin provider ids include `openai-compatible`, `openai-native`, and `openai-codex` — **no bare `openai` id was found** in the builtin spec-override table. This project's own validated, already-proven CLI invocation uses `-P openai-compatible` (`docs/cline-config-pins.md`, confirmed live against the host's real `cline --help`/binary).
**Why it happens:** cline-bench's README is written for the general case (any provider Cline recognizes); it may rely on an alias-resolution path elsewhere in the CLI (`apps/cli/src/utils/provider-auth.ts` or similar) that this research traced into but could not fully resolve from source alone — not enough to assert either way with HIGH confidence.
**How to avoid:** Use `-m openai-compatible:flashnext` (not `-m openai:flashnext`) for the actual invocation — it maps to exactly this project's own already-validated provider id and requires no unverified alias behavior. This also naturally uses harbor's generic `API_KEY` env fallback (the `PROVIDER_API_KEY_ENVS` dict in `cline.py` only special-cases `anthropic/gemini/google/openai/openrouter/cline/xai`; `openai-compatible` isn't in that list, so it correctly falls through to the generic `API_KEY` the README's own BASE_URL examples already document).
**Warning signs:** Check the smoke run's `agent/command-1/command.txt` (harbor logs the exact command it ran, including the resolved `-P` value) and `agent/cline.txt`'s first few lines — a bad provider id would show as an immediate auth/connection error unrelated to `flashnext`, easy to distinguish from Pitfall 1's context-overflow failure.

### Pitfall 4: Wall-clock cost is genuinely unknown until observed — do not schedule "5-8 tasks overnight" up front
**What goes wrong:** Two forces point in opposite directions and neither dominates without a live data point. If Pitfall 1 fires early and often, tasks fail *fast* (a handful of ~64s-TTFT turns, then a clean `400` — plausibly under 5-10 minutes each). If it doesn't fire (or fires late), tasks can run to their full `task.toml` budget — most of the 14 tasks set `[agent] timeout_sec = 1800.0` (30 min), three set `3600.0` (1 hour) — and Docker local execution is **sequential only** (confirmed in harbor's own README: "Docker (local): ... uses your machine resources," contrasted explicitly with Daytona's parallel cloud execution). 5-8 tasks at up to 30-60 min each, run one after another, against a single-sequence model server already shared by every other Cline surface on this machine, spans anywhere from well under an hour to several hours — genuinely "overnight" territory in the worst case.
**Why it happens:** No prior live run exists on this stack; every number available (TTFT, tok/s, timeouts) is a per-turn or per-task ceiling, not a measured end-to-end total, and Pitfall 1 changes which ceiling actually binds.
**How to avoid:** Run exactly one task first, in the foreground, and read its actual wall-clock time and turn count from `result.json`/`agent/cline.txt` before deciding how many of the remaining tasks to run and whether to run them sequentially in one sitting or across sessions. Prefer the two "easy"-difficulty tasks (`discord-trivia-approval-keyerror`, `telegram-plugin-refactor`) and the "medium" tasks at `memory_mb ≤ 4096` (`every-plugin-api-migration`, `police-sync-segfault`, `intercept-axios-error-handling`, `orpc-client-workspace`, `healthchain-prefetch-removal`, `suave-http-data-bleeding`, `filmarchiver`) for the remaining slots — skip `terraform-azurerm-deployment-stacks` (hard, `memory_mb=8192`, `timeout_sec=3600`) unless colima is deliberately resized first (see Pitfall 5).
**Warning signs:** if the smoke task's Docker image build alone (before any LLM turn happens) takes more than a few minutes, budget accordingly — some tasks (e.g. the `.NET`-toolchain sample seen in `suave-http-data-bleeding`) pull and build non-trivial images independent of model latency.

### Pitfall 5: colima's default VM (4 GiB RAM / 20 GiB disk) doesn't fit every task, and this machine's system memory is already thin
**What goes wrong:** `task.toml`'s `[environment] memory_mb` ranges from 2048 to 8192 across the 14 tasks; colima's live profile (`colima list`, confirmed) is `4 CPUs / 4 GiB memory / 20 GiB disk`. The one `memory_mb=8192` task (`terraform-azurerm-deployment-stacks`) exceeds the VM's total memory outright and would need `colima stop && colima start --memory 8` (or similar) before it could even start. Separately, this machine's actual physical RAM is already committed almost entirely to `flashnext` at 32K (~120 GB of ~137 GB, per `PITFALLS.md`'s own prior measurement of as little as ~0.7 GiB system-wide free at one point) — colima's VM memory draws from the same physical pool (a distinct constraint from the GPU-wired budget, already documented in this project's own prior research as Pitfall 4 there).
**Why it happens:** cline-bench's task authors sized `task.toml` for a machine that isn't also running a 104 GiB local model.
**How to avoid:** Do not resize colima up to fit the 8192 MB task; simply exclude it from the selected 5-8 (see Pitfall 4's task list). If colima ever needs resizing for other work, do it as a deliberate, separate decision — not an incidental side effect of trying to fit one bench task in.
**Warning signs:** `docker: Error response from daemon` mentioning memory limits, or a container OOM-killed immediately after start, or (worse) system-wide sluggishness/swap thrashing while `flashnext` is also live — the latter is a "stop immediately" signal, not something to push through.

### Pitfall 6: Phase 3's `sandbox-exec` is architecturally irrelevant to this phase — don't try to wrap `harbor` in it
**What goes wrong (avoided, but worth stating so a plan doesn't accidentally re-introduce it):** `harbor` is a plain host-side Python process (installed via `uv tool install`) that talks to the Docker daemon; it never invokes this project's own `cline` binary, never touches `~/.cline/data/settings/providers.json`, and the agent it actually runs (`cline-cli`, freshly installed **inside** the ephemeral container) is launched with `--yolo` (full auto-approval) by harbor's own adapter code — confirmed directly in `cline.py`'s `run_flags` list. The container's own filesystem/process isolation is the security boundary for that agent's tool calls, not `phase-03/sandbox/run_sandboxed.sh`.
**Why it happens (why the confusion is natural):** Every other Cline surface in this project (headless wrapper, Kanban, Telegram) *does* go through `run_sandboxed.sh`, so it's a reasonable first assumption that a bench run should too.
**How to avoid:** Do not route `harbor run ...` through `run_sandboxed.sh` — it isn't invoking `cline` on the host at all, so there's nothing for that wrapper to wrap. Correspondingly, this phase does **not** need to make the `--auto-approve true` vs. `--hook-command` escalation decision that `docs/headless-wrapper.md` §4 and `docs/network-exposure.md` §9 keep flagging as still-pending from Phase 4 through Phase 6 — it can be recorded as "not applicable: cline-bench's agent runs inside Harbor's own Docker sandbox, never through this project's shipped host surfaces," which is a different, honest answer from either "decided yes" or "decided no." Whoever plans Phase 7 should still surface this explicitly rather than silently not mentioning the still-open host-posture question at all, since three prior phases went out of their way to keep it visible.
**Warning signs:** none expected if `harbor run` is invoked directly, unsandboxed, from a normal shell in `bench/cline-bench/`.

### Pitfall 7: `bench/` must stay excluded from `ALLOWED_REPOS.json` — already true, must not regress
**What goes wrong (status: already prevented, confirm don't undo it):** `ALLOWED_REPOS.json`'s existing comment and Phase 3's live-verified SBX-04 test both already establish that `bench/` (and therefore `bench/runs/CANARY.txt`) is unreadable from inside the sandbox (`phase-03/results/20260829T203455Z-phase-close/sbx/P3.txt`: `cat: .../bench/runs/CANARY.txt: Operation not permitted`). This has nothing to do with `harbor`'s own Docker containers (a completely different isolation mechanism, see Pitfall 6) — it protects against a *sandboxed host-side `cline` process* (headless wrapper, Kanban, Telegram) reading prior bench prompts/results, per the roadmap's own SBX-04 rationale.
**How to avoid:** Simply don't add `bench/` or the repo root to `ALLOWED_REPOS.json` while building this phase. Re-run `phase-03/sandbox/verify_sandbox.sh` at phase-close as the standing gate already prescribes — it re-checks this exact canary.
**Warning signs:** `verify_sandbox.sh`'s CRITERION 4 (SBX-04) flipping from PASS.

### Pitfall 8: This phase does not touch kanban at all — the known `.gitconfig` sandbox blocker is irrelevant here
**Confirmed, not a risk:** `docs/network-exposure.md` §9 hands Phase 7 a known blocker — the live kanban server's sandbox denies `~/.gitconfig`, blocking git-backed project registration (`kanban task list --column in_progress` exits 1). Nothing in cline-bench's execution model touches Kanban, Telegram, or this project's shipped host `cline` — `harbor` is a standalone process talking only to Docker and to litellm's `:4000`. **Say this plainly rather than silently ignoring the handoff note**: this phase does not register anything with kanban, so the blocker does not recur here. It remains Phase 3/8's problem, not Phase 7's.

## Code Examples

### The recommended smoke-task invocation (first thing this phase should actually run)
```bash
# Source: this project's own PROVIDER pin (docs/cline-config-pins.md) + cline-bench's own
# documented BASE_URL/API_KEY pattern (github.com/cline/cline-bench README, "Additional Provider
# Examples" section) + this research's live-verified host.docker.internal reachability test.
cd /Users/ohama/projs/cline-tests/bench/cline-bench
source .venv/bin/activate

export API_KEY="local-any-value"                        # this stack accepts any non-empty api_key
export BASE_URL="http://host.docker.internal:4000/v1"    # NOT localhost — container-side, verified live

harbor run \
  -p tasks/01k7a12sd1nk15j08e6x0x7v9e-discord-trivia-approval-keyerror \
  -a cline-cli \
  -m openai-compatible:flashnext \
  --agent-kwarg cline-version=3.0.53 \
  --env docker
```

### Verifying host.docker.internal reachability independently (already run live during this research, safe to re-run as a preflight)
```bash
# Read-only GET against litellm's own model list; no generation call, no cost, no state change.
docker run --rm alpine:3.20 sh -c \
  "apk add --no-cache curl >/dev/null 2>&1 && curl -s http://host.docker.internal:4000/v1/models"
# Expected: JSON containing {"id":"flashnext", ...} among the model list — confirmed live 2026-08-30.
```

### Building the BCH-03 table from harbor's native output
```bash
# Source: cline-bench README's own "Quick Commands" section, adapted to walk multiple trials.
for trial in "$RUN_DIR"/jobs/*/*/; do
  task_id=$(basename "$trial" | sed 's/__.*//')
  reward=$(cat "$trial/verifier/reward.txt" 2>/dev/null || echo "N/A")
  duration=$(python3 -c "import json;print(json.load(open('$trial/result.json')).get('duration_sec','N/A'))" 2>/dev/null)
  echo "$task_id | reward=$reward | duration=${duration}s"
done
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| cline-bench described as using "Terminal-Bench-style" custom runner (prior project research's framing) | cline-bench uses **Harbor**, "the official successor to Terminal-Bench" — a distinct, actively developed general-purpose agent-eval framework maintained by the Laude Institute, not something cline-bench built itself | Confirmed by live repo README today; this is how the repo has been shaped since at least its current `main` | Harbor's generality (10+ supported agents, multiple cloud backends) is also why its Cline-specific config surface is thin — this project is not the intended primary audience for that adapter's design, which explains Pitfall 1 |

**Deprecated/outdated:**
- The "~89-task pool" figure from prior project research — superseded by the live count of 14 (Pitfall 2).

## Open Questions

1. **Does `agent/cline.txt` actually include the raw system/user prompt, or only the visible transcript?**
   - What we know: Harbor's README calls it "Full Cline conversation log," and `agent/command-1/stdout.txt` is explicitly documented as "Same as cline.txt (tee'd)" — i.e. it's the tee'd stdout of the actual `cline --json ...` invocation, which should include whatever NDJSON/stream events Cline itself emits.
   - What's unclear: whether Cline's own `--json` stream includes the literal system prompt text it constructed (with this project's own headless wrapper research, `docs/headless-wrapper.md`, Cline's NDJSON stream types were catalogued for the *host* binary but the exact event shape for a **system-prompt-echo** was never confirmed either way there).
   - Recommendation: check empirically on the smoke run — `grep -i "you are cline\|system" bench/cline-bench/jobs/*/*/agent/cline.txt` or similar. If the raw prompt isn't present, this project already has everything needed to add a lightweight request-logging shim at litellm/role-shim (`:4000`/`:8011`) — visibility into the request Cline actually sends is a capability this project's own architecture research (`ARCHITECTURE.md` §2) already assumed would exist for the 32K guard, so it "doubles as prompt capture at no extra cost" if needed, per that same research.

2. **Does `-P openai-compatible` (via `-m openai-compatible:flashnext`) actually resolve correctly through harbor's adapter and Cline's own CLI, end to end?**
   - What we know: harbor's `model_name.split(':', 1)` is fully generic and passes the pre-colon string straight through as `-P`; `openai-compatible` is a real, live-confirmed builtin provider id in `cline/cline`'s source, and it's this project's own already-validated id.
   - What's unclear: whether `BASE_URL`/`API_KEY` (exported in the invoking shell) actually reach the container's `cline` process for this exact provider path — this research traced the plumbing (`harbor.agents.factory.resolve_env_vars` reading `${VAR}` templates from `AgentConfig.env`) far enough to be confident the *mechanism* for env-var passthrough exists and is used elsewhere in harbor for exactly this purpose, but did not trace the literal per-agent-registration line that wires `BASE_URL`/`API_KEY` specifically into `cline-cli`'s default env template.
   - Recommendation: the smoke run settles this directly — `agent/command-1/command.txt` (harbor logs the exact resolved command+env) and whether the run actually reaches `flashnext` (visible as real generated tokens in `cline.txt`, at this stack's known ~64s TTFT/~17 tok/s pace, vs. an immediate auth/connection error) are both directly observable.

3. **Exact number of agentic turns cline-bench tasks typically need, and how that interacts with Pitfall 1's early-400 risk.**
   - What we know: task difficulty ranges easy→hard, instruction.md length ranges 14-156 lines, `[agent] timeout_sec` ranges 1800-3600s.
   - What's unclear: whether a typical task completes (or fails on its own merits) within the handful of turns Pitfall 1 suggests will fit under the real 32,768-token ceiling before compaction would even be relevant.
   - Recommendation: this is precisely what the mandated single smoke run is for — do not extrapolate from other researched numbers (TTFT, tok/s, timeouts) without one real observed trajectory.

## Sources

### Primary (HIGH confidence — live, direct verification, 2026-08-30)
- `docker run --rm alpine:3.20 ... curl http://host.docker.internal:4000/` and `/v1/models` — run live against the actual live stack during this research; confirmed `200 OK` and the real `flashnext` model list, with `lsof`/`netstat` re-confirmed before/after showing no new listeners and no change to the `127.0.0.1`-only binds
- `which harbor`, `docker --version`, `docker info`, `colima status`, `colima list`, `uv --version`, `uv python list`, `pip3 show harbor-cli` — live shell commands, this session
- `curl https://pypi.org/pypi/harbor/json` — confirms the real PyPI package identity/version (`harbor 0.22.0`, "A framework for evaluating and optimizing agents and models using sandboxed environments")
- `gh api repos/laude-institute/harbor` (redirects to `harbor-framework/harbor`) — 4,767 stars, Apache-2.0, `harborframework.com` homepage, confirms this is a real, actively pushed (`pushed_at` = 2026-08-29) project
- `git clone --depth 1 https://github.com/harbor-framework/harbor.git` and `git clone --depth 1 https://github.com/cline/cline-bench.git` into scratchpad, read directly: `src/harbor/agents/installed/cline/cline.py` (full adapter source — `--yolo`, env dict, CLI_FLAGS, npm/nightly default install), `src/harbor/agents/model_connection.py`, `src/harbor/agents/factory.py`, `src/harbor/utils/env.py`, `src/harbor/environments/docker/docker.py` + its `docker-compose-*.yaml` files, `src/harbor/models/task/config.py` (`network_mode` default = `PUBLIC`), and all 14 `tasks/*/task.toml` + `instruction.md` files in `cline-bench`
- `curl https://raw.githubusercontent.com/cline/cline-bench/main/README.md` — full README fetched directly (installation, env vars, local-Docker vs. Daytona invocation examples, `jobs/` output schema)
- `curl https://raw.githubusercontent.com/cline/cline/main/sdk/packages/llms/src/providers/builtins.ts` — confirmed live the `openai-compatible` fallback (`contextWindow=maxInputTokens=128_000`) and the registered builtin provider id list (`openai-compatible` present, bare `openai` absent)
- This project's own prior live-verified docs, re-read directly: `docs/headless-wrapper.md` (full), `docs/network-exposure.md` §9, `docs/services.md` §10, `docs/cline-config-pins.md`, `.planning/STATE.md` (handoff notes across Phases 4-6), `ALLOWED_REPOS.json`, `phase-03/results/20260829T203455Z-phase-close/sbx/*` (live SBX-04 CANARY test evidence)

### Secondary (MEDIUM confidence)
- `WebFetch` of `harborframework.com` — confirmed install method and Laude Institute/Terminal-Bench lineage, but the page's own content didn't cover Docker networking specifics (source code was used instead, promoted to Primary above)
- `.planning/research/FEATURES.md` §3, `.planning/research/ARCHITECTURE.md` §7, `.planning/research/PITFALLS.md` Pitfall 8, `.planning/phases/03-sandbox-repo-whitelist/03-RESEARCH.md` Open Question 3 — this project's own prior research, reused where not contradicted by today's live re-verification (the 89-task figure was the one thing contradicted, see Pitfall 2)

### Tertiary (LOW confidence, flagged for validation)
- The exact `BASE_URL`/`API_KEY` env-template wiring for `cline-cli` specifically (Open Question 2) — traced the general mechanism in harbor's source but not the literal per-agent registration line

## Metadata

**Confidence breakdown:**
- Standard stack (harbor install, cline-bench structure): HIGH — live PyPI/GitHub verification, source read directly
- Docker networking (host.docker.internal via colima): HIGH — live test performed and reproduced twice during this research
- Tool-use/sandbox question (Pitfall 6): HIGH — read the literal adapter source showing `--yolo` inside the container
- Context-window fallback risk (Pitfall 1): HIGH that the mechanism exists and would apply; MEDIUM on exactly how it manifests in practice (turn count before failure) until the smoke run happens
- Wall-clock cost: LOW by design — stated as unknowable without a live run, which is the explicit recommendation, not a gap left unaddressed

**Research date:** 2026-08-30
**Valid until:** Re-verify task count/README/provider-id findings if this phase doesn't execute within ~2 weeks — both `cline-bench` and `harbor` are active repos with recent pushes (`harbor` pushed 2026-08-29, one day before this research) and could gain/lose tasks or change adapter flags between now and execution.
