# Feature Research

> 🔴 **2026-08-30 정정 — 압축/컨텍스트 관련 서술은 무효다.**
> 이 문서는 `models[].contextWindow` 가 Cline 의 압축 임계값에 영향을 주는지 불확실하다고 쓴다.
> 실측 결과: `models[]` 는 **CLI 가 읽지 않는 경로**(VS Code 용 per-model override)이고,
> `settings` **최상위** `contextWindow` 가 `maxInputTokens` 로 매핑되어 트리거를 결정한다
> (`provider-settings.ts:150/266`). trigger = `maxInputTokens × 0.9`.
> 최상위에 29000 을 넣으면 압축이 정상 발동한다 — `phase-01/results/exp-verify29k/`.
> **유효한 문서: `docs/32k-compaction-policy.md`, `.planning/PROJECT.md`.**


**Domain:** Self-hosted, single-user Cline agent server (local model, 32K context, Tailscale-reachable from iPad/iPhone) + Korean user manual + bench-based verification suite
**Researched:** 2026-08-29
**Confidence:** MEDIUM-HIGH (Cline's own docs and repo verified directly; a few surfaces — Kanban touch/mobile behavior, `cline schedule` + local-model interaction, exact cline-bench task count — are undocumented by Cline itself and rated LOW/MEDIUM accordingly)

---

## 0. Reading Guide: How Each Cline Surface/Feature Survives Compact Prompt + Local Model

Compact Prompt is not optional at 32K in this project (per PROJECT.md). Confirmed via Cline's own settings copy (GitHub issue #5924, cross-checked against docs.cline.bot behavior): **"Use Compact Prompt" is "A system prompt optimized for smaller context windows (e.g. 8k or less). Does not support MCP and Focus Chain."** cline-analysis.md's claim that Compact Prompt also disables MTP is a hardware-level fact (MTP drafter is on the inference server, not Cline) — Compact Prompt doesn't touch MTP directly, but the two are correlated in this project only because both are consequences of the 32K squeeze, not because one causes the other. This distinction matters for requirements.

| Surface / Feature | What it does | Works on a local OpenAI-compatible model? | Survives Compact Prompt ON? | Confidence |
|---|---|---|---|---|
| Kanban board | Web UI, per-card git worktree, dependency chains, diff review + inline comments | Yes — model-agnostic, it's a UI over the same agent core | Yes — board mechanics are independent of system-prompt content | HIGH |
| Connectors (Telegram etc.) | Chat-based agent sessions, thread=session, slash commands | Yes — CLI-only feature, model-agnostic | Yes | HIGH |
| Headless `--json` | Streams structured JSONL (`type`, `text`, `ts`, `say`/`ask`, `reasoning`, `partial`) | Yes | Yes | HIGH |
| `cline schedule` (cron agents) | Recurring automated agent runs via a persistent "hub" | Yes, no local-model restriction found in docs | Yes | MEDIUM (docs silent on local-model/context caveats) |
| Plan/Act modes | Separate exploration vs execution modes | Yes | Yes — mode switching is independent of prompt size | HIGH |
| Checkpoints | Shadow git repo, per-tool-use snapshot, 3-way restore, diff compare | Yes | Yes — checkpoints are file-system snapshots, not prompt content | HIGH |
| `.clinerules` | Markdown rules appended to system prompt, project + global, per-rule toggle | Yes | **Degraded, not eliminated** — rules still get appended, but every token of rule text competes directly with the ~13K working budget left after Compact Prompt's system-prompt tax at 32K. Docs don't explicitly except rules from Compact Prompt, so they still cost tokens | MEDIUM |
| Skills | On-demand `SKILL.md` bundles, progressive loading (~100 tok metadata, <5K tok on trigger) | Yes | **Likely survives** — Skills' whole design point is avoiding constant context cost; only metadata (~100 tok/skill) is always resident. Not explicitly tested against Compact Prompt in docs | MEDIUM |
| MCP | External tool/resource servers | Yes in principle | **NO — explicitly disabled by Compact Prompt** ("Does not support MCP") | HIGH |
| Focus Chain | Auto-generated todo list re-injected into context every N messages, survives context-reset/summarization | Yes in principle | **NO — explicitly disabled by Compact Prompt** ("Does not support ... Focus Chain") | HIGH |
| Auto-compact (context compaction) | Summarizes conversation when `maxAllowedSize = max(ctx-40000, ctx*0.8)` is hit | Yes | Yes — compaction is a core-loop mechanism independent of Compact Prompt, this is what makes 32K survivable at all | HIGH |
| `--auto-approve` / YOLO / `--hook-command` | Tool-call approval automation and custom allow/deny scripting | Yes | Yes | HIGH |
| `CLINE_SANDBOX`, `CLINE_SANDBOX_DATA_DIR`, `CLINE_COMMAND_PERMISSIONS` | Env-var based sandboxing and shell command allow/deny glob policy | Yes | Yes | HIGH (found in official CLI reference) |

**Implication for this project:** at 32K with Compact Prompt mandatory, the loadout that remains reliably available is: Plan/Act, Checkpoints, Auto-compact, `.clinerules` (budgeted), Skills (probably), Connectors, Kanban, headless JSON, schedule, sandbox env vars, hook-command gating. What is **structurally lost**: MCP and Focus Chain. Any requirement written assuming Focus Chain progress-tracking or MCP tool servers must be dropped or explicitly re-scoped — this is a hard constraint, not a preference.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features a self-hosted single-user Cline server is useless without.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Cline pointed at the local OpenAI-compatible endpoint (`flashnext`/`:4000`), Context Window field manually set to 32768 | Otherwise Cline silently falls back to the `openai-compatible` 128K fallback (issue #12520 root cause verified in `builtins.ts`/`compat.ts` on current `main`) and compacts at 115.2K instead of 26.2K — exactly the "quiet failure" PROJECT.md is built to prevent | LOW | Must be set in Cline config, not assumed from server declaration |
| Compact Prompt ON | 32K leaves ~13K of working budget after full system prompt; Compact Prompt is ~10% the size | LOW (one toggle) | Table stakes *because* the alternative is starving the agent of task-space, not a nice-to-have |
| Kanban launchd service on `:3484`, boot-persistent | This is the iPad surface; without it there is no touch-usable review UI | LOW-MEDIUM | Confirmed official env var `KANBAN_RUNTIME_HOST=0.0.0.0` needed to bind beyond localhost for remote access |
| Tailscale-only reachability for Kanban and Telegram | Docs explicitly warn: Kanban gives "full access to your git repository and terminal" to anyone who can reach it; Telegram bot is world-reachable by default ("anyone who finds your bot ... will execute tasks on your machine") | LOW (Tailscale already running, iPads already enrolled per PROJECT.md) | This is officially Cline's own recommended pattern for personal remote use — not a project-specific invention |
| `--allowed-user-id` (Telegram) or equivalent `--hook-command` allow/deny gate | Without it, any stranger who discovers the bot token executes shell commands on this Mac | LOW | Confirmed official CLI flag; hook-command receives JSON on stdin, returns `{"action":"allow"}`/`{"action":"deny","message":...}` |
| LAN-path token requirement | PROJECT.md requires it; same WiFi ≠ same trust as Tailscale-authenticated device | LOW-MEDIUM | Not a Cline built-in — must be a thin gateway/reverse-proxy check in front of Kanban/connector ports on the LAN interface |
| Workspace sandbox + repo whitelist | Remote agent, unauthenticated inside Tailscale, must not reach `$HOME` at large | MEDIUM | `CLINE_SANDBOX`, `CLINE_SANDBOX_DATA_DIR`, `CLINE_COMMAND_PERMISSIONS` are the official mechanism; confirmed in CLI reference |
| Visible "waiting" / busy state in any interactive surface | 32K TTFT is 64.3s — an interface with no spinner or "thinking" indicator looks hung, and a user on iPad will force-quit or double-send | LOW | Applies to Kanban card view and Telegram ("typing..." indicator or an explicit ack message) equally |
| Boot-time auto-start (launchd `RunAtLoad`+`KeepAlive`) for Kanban and Telegram connector | PROJECT.md's whole premise is "boots and it's just there" | LOW | Home-rule pattern already established for the inference stack; extend, don't reinvent |
| Regression test proving the 32K guard actually holds (not just configured) | PROJECT.md's Core Value is exactly this — "configured" and "enforced" are different claims, and Cline's own fallback bug is evidence they diverge silently | MEDIUM | This is the single highest-priority table-stakes item; everything else is secondary if this doesn't exist |
| Prompt + result capture from bench runs, saved to files | PROJECT.md requirement is explicit: "테스트의 프롬프트와 결과를 모두 파일로 보존" | LOW-MEDIUM | See §3 below — feasible via `agent/cline.txt` (Harbor's per-trial log) plus `result.json`; needs verification that the raw system+user prompt (not just the transcript) is actually present in `cline.txt` |
| Korean manual covering CLI + web + iPad/iPhone usage | Explicit deliverable in PROJECT.md, usage-only (ops excluded) | MEDIUM | See §4 proposed TOC below |

### Differentiators (What Makes This Setup Actually Good)

Not required for the server to "work," but what separates a merely-functional local Cline box from one that's actually pleasant/trustworthy to use daily from a phone.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Three surfaces sharing one agent core and one model (Kanban / Telegram / headless CLI) | Matches device to task: iPad = visual diff review, iPhone = fire-and-forget chat commands, CLI = scripting/automation — instead of forcing one UI onto every device | MEDIUM | Already decided in PROJECT.md Key Decisions; this is the project's actual thesis, not a stretch feature |
| Dependency-chained Kanban cards (linked cards auto-start on completion of predecessor) | Lets ohama queue a multi-step change from the couch on iPad and let cards progress unattended overnight, checking back only for review | LOW (built into Cline, just needs to be used/documented) | Official feature via ⌘/Ctrl+click; genuinely well-suited to a single 64s-TTFT model where you want to batch turns rather than babysit them |
| Inline diff comments as the review mechanic | Touch-friendly: tap a line, type a comment, it's fed back as agent context — no need to re-type the whole instruction from a phone keyboard | LOW (built-in) | This is the actual answer to "how do you meaningfully review code on an iPad" — most other coding-agent UIs require full re-prompting |
| `hook-command`-based custom allow/deny logic (beyond `--allowed-user-id`) | Lets ohama write one script that enforces both "only me" AND "only inside sandbox/whitelist," instead of relying on Cline's built-ins for both jobs | MEDIUM | Differentiator specifically because PROJECT.md already requires two separate guarantees (identity + scope) that map naturally onto one hook script |
| 32K-guard regression test as a first-class, re-runnable artifact (not a one-time manual check) | Turns "I configured 32K" into "I can prove 32K holds after any Cline upgrade, model swap, or config drift" — directly defends against Cline's own known fallback-bug class (#12520, #13457) recurring silently after an update | MEDIUM-HIGH | This is the most differentiated piece of engineering in the whole project — everyone else running local Cline is exposed to this bug class; this project is the one that catches it |
| cline-bench tasks run locally (Docker, no Daytona) as a second, independent verification layer | Own regression test proves the *guard* works; cline-bench tasks run *through* the guard prove the agent still does useful work under the 32K/Compact Prompt constraint — the two together (own test + official bench) are a stronger claim than either alone | MEDIUM | Confirmed feasible, see §3 |
| Scheduled agent runs (`cline schedule`) for recurring low-stakes tasks (e.g., nightly dependency-update scan) | Lets the server do something proactively rather than purely reactive-to-prompt, without needing a person to remember to trigger it | LOW-MEDIUM | Real official feature (CLI/SDK/Kanban only, explicitly NOT VS Code/JetBrains) — fits a "persistent server" framing well, though PROJECT.md doesn't currently scope this in |

### Anti-Features (Deliberately NOT Building)

For a single-user, Tailscale-only, one-model-fits-in-memory box, these are traps, not missing value.

| Feature | Why It Looks Appealing | Why It's a Trap Here | Alternative |
|---------|------------------------|------------------------|-------------|
| Multi-tenant auth / user accounts / RBAC | "Proper" servers have login systems | One user (ohama). Tailscale identity + a LAN token already answers "who is this," and Cline's own docs treat single-operator trust as the norm for personal Kanban/connector use ("the documentation emphasizes trusting all users with access"). Building auth here is solving a problem that doesn't exist and adds an attack surface (session storage, password reset, etc.) to defend | Tailscale ACL for the tailnet path; a static bearer token for the LAN path (already in PROJECT.md scope) |
| Public webhooks / internet-exposed URL (ngrok, Cloudflare Tunnel, public Discord/WhatsApp webhook) | Cline's own docs list ngrok and Cloudflare Tunnel as "supported" remote-access options | PROJECT.md explicitly rules out internet exposure. A public URL turns "my bot token leaked" into "the internet can drive my shell." Cline's connectors default to zero access control — that's a fine default for a private Telegram bot behind Tailscale, catastrophic behind a public webhook | Tailscale-only for Kanban; Telegram/Slack connectors reached via their own cloud APIs (which don't require inbound exposure) rather than Discord/WhatsApp-style inbound webhooks |
| Model-switching UI / multi-model routing | Feels like flexibility — "let me pick GPT-4 for this task, Qwen for that one" | Only one model fits in memory at a time (Flash-Next, 104 GiB, `iogpu.wired_limit_mb` leaves 4.39 GB headroom at 32K). A model picker implies a promise the hardware can't keep — switching models means an unload/reload cycle measured in tens of seconds to minutes, not a dropdown click. Building UI for a choice that isn't really available just creates a UI that lies | One model, one alias (`flashnext`), documented as fixed in the manual. If a second model is ever wanted, that's a hardware decision (buy more memory / accept unload latency), not a software feature |
| Cloud sync of tasks/conversations/checkpoints | "What if I lose my Mac" instinct | Single machine, single user, no second device runs the agent — there's nothing to sync *to*. Cloud sync would mean either standing up cloud infrastructure (against the no-internet-exposure constraint) or bolting on a sync service that has no consumer | Local shadow-git checkpoints (already built into Cline) are the durability story; back up the Mac like any other machine, not the agent state specifically |
| Telemetry / analytics dashboards | "Good ops hygiene" | This is explicitly out of scope per PROJECT.md ("운영 런북... 별도 문서로 분리") — there's no team to report metrics to, and building dashboards is ops tooling disguised as a feature | The one thing worth "observing" — 32K-guard health — is covered by the regression test, not a dashboard |
| Running cline-bench's full task suite to completion | Feels like "more thorough validation" | Timeout is 2400s per task; at 64.3s TTFT for 32K prompts, a task requiring several agentic turns burns that budget fast, and PROJECT.md already flags full-suite completion as unrealistic on this hardware | Run a deliberately small, representative subset (see §3) and treat cline-bench as a *sampling* check, not exhaustive certification |
| MCP server integration | Looks like "extensibility," and it's a first-class Cline feature | Compact Prompt (mandatory at 32K) explicitly does not support MCP. Building a requirement or manual section around MCP creates a promise that Compact Prompt breaks the moment it's toggled on | Skills (progressive-loading, survives Compact Prompt per docs) for anything that would otherwise be an MCP tool; `.clinerules` for standing instructions |
| Focus Chain-based long-task tracking as a relied-upon mechanism | It's Cline's built-in answer to "don't lose the plan across context resets" — exactly the problem a 32K/frequent-compaction setup has | Also explicitly disabled by Compact Prompt. Depending on it in the manual or requirements sets an expectation the running configuration cannot deliver | Kanban's dependency-chained cards + explicit task decomposition (small tasks bounded by the ~26K compaction trigger) does the same job at the workflow level instead of the prompt-injection level |
| Deep/high `reasoning_effort` or `enable_thinking` by default | "More reasoning = better answers" is the general intuition | Constraints already validated: `reasoning_effort` only has `low`/`medium`/`xhigh` (not `high` — that 500s), `thinking_budget` unavailable with MTP drafter attached, and 64s TTFT already has no room to add more per PROJECT.md decisions | `enable_thinking` stays off (already decided); if reasoning is ever needed, it costs the fast-mode/drafter setup entirely — a separate, larger decision, not a toggle |
| Auto-approve/YOLO as the default for remote connectors | Removes friction, "just let it work" | Docs explicitly warn against this for messenger bridges: "메신저 브리지에 auto-approve나 /yolo를 켜지 말 것. 폰에서는 무엇을 승인하는지 제대로 읽을 수 없다" (a phone screen can't meaningfully review a tool-call approval) | Keep manual approval as default on Telegram; reserve `/yolo` for supervised sessions the user explicitly toggles knowing the risk |

---

## Feature Dependencies

```
32K Context Window pinned in Cline config
    └──requires──> Cline "openai-compatible" fallback bug understood & bypassed (config value set explicitly)
                       └──requires──> knowledge of builtins.ts/compat.ts fallback order (already verified in cline-analysis.md)

Compact Prompt ON
    └──conflicts──> MCP
    └──conflicts──> Focus Chain
    └──enhances──> Auto-compact effectiveness (smaller system prompt = more room before 26.2K compaction trigger)

Gateway-layer 32K request guard
    └──requires──> visibility into the request Cline actually sends (proxy/log at :4000 or :8011)
    └──enhances──> Cline-side context window pin (defense in depth — the PROJECT.md rationale for doing both)

32K-guard regression test
    └──requires──> Gateway-layer guard AND Cline-side pin both in place (tests the combination, not either alone)

cline-bench local run
    └──requires──> Docker + uv (already present per PROJECT.md environment check)
    └──requires──> --env docker (does NOT require DAYTONA_API_KEY)
    └──enhances──> confidence that 32K + Compact Prompt still produces working agent behavior, not just "doesn't blow past 32K"

Prompt+result file capture
    └──requires──> cline-bench's agent/cline.txt (transcript) AND result.json (pass/fail) captured per run
    └──may require──> additional gateway-level request logging if cline.txt doesn't include the raw system prompt (unverified — see Gaps)

Kanban web UI on iPad
    └──requires──> Kanban service bound via KANBAN_RUNTIME_HOST=0.0.0.0 or launched with remote-access config
    └──requires──> Tailscale reachability (already validated: 2 iPads enrolled)
    └──enhances──> the manual's web/iPad chapter can be one coherent flow

Telegram connector on iPhone
    └──requires──> BotFather-issued token (human-only step, cannot be automated — already noted in PROJECT.md)
    └──requires──> --allowed-user-id AND/OR --hook-command for access control
    └──conflicts──> auto-approve/YOLO default (see anti-feature above)

Korean manual
    └──requires──> all three surfaces functionally complete (CLI wrapper, Kanban service, Telegram connector) — writing the manual before the surfaces stabilize means rewriting it
```

### Dependency Notes

- **32K guard test requires both the Cline-side pin and the gateway guard to exist first:** PROJECT.md already decided defense-in-depth for exactly the reason Cline's own fallback bug (#12520) shows config alone is not trustworthy. The regression test's value comes from testing the *combination*, so it must be built last in that chain, not first.
- **Compact Prompt conflicts with MCP and Focus Chain:** this is a hard, documented conflict (Cline settings copy, verified independently via WebSearch), not a project assumption. Any roadmap phase that plans to "use MCP for X" or "rely on Focus Chain for long-task tracking" needs to be redesigned around Skills/`.clinerules`/Kanban dependency-chains instead.
- **The manual depends on all three surfaces being feature-complete:** writing "how to use Telegram" before `--hook-command` gating is finalized, or "how to use Kanban" before `KANBAN_RUNTIME_HOST` binding is decided, produces a document that needs a rewrite. Sequence the manual after the surfaces, not alongside them.
- **cline-bench and the 32K regression test are complementary but independent:** the regression test proves the guard triggers; cline-bench (run through the same guarded path) proves the agent still accomplishes real tasks under the constraint. Neither substitutes for the other.

---

## MVP Definition

### Launch With (v1)

- [ ] Cline configured against `flashnext` (`:4000`) with Context Window explicitly set to 32768 — the single highest-leverage config line in the whole project, directly counters the verified fallback bug
- [ ] Compact Prompt ON — non-negotiable at 32K per PROJECT.md and per Cline's own local-model guidance ("emphasized as essential")
- [ ] Gateway-layer request guard rejecting/trimming any request that would exceed 32K, independent of Cline's own setting
- [ ] Regression test that proves the guard fires (not just that it's configured) — this is the Core Value of the project; nothing else matters if this is missing
- [ ] Kanban service on `:3484`, boot-persistent via launchd, reachable only via Tailscale (`KANBAN_RUNTIME_HOST` bound appropriately, LAN path token-gated)
- [ ] Telegram connector with `--allowed-user-id` set to ohama's Telegram ID, boot-persistent via launchd, token slot left empty for manual BotFather injection (already decided in PROJECT.md)
- [ ] Headless CLI wrapper script with a clean invocation contract (no service wrapper yet — deliberately deferred per PROJECT.md)
- [ ] Workspace sandbox + repo whitelist enforced via `CLINE_SANDBOX`/`CLINE_SANDBOX_DATA_DIR`/`CLINE_COMMAND_PERMISSIONS`
- [ ] A small, representative cline-bench subset run locally via `--env docker` (no Daytona key), with prompts+results captured to files
- [ ] Korean manual v1 covering CLI/web/iPad-iPhone usage (see proposed TOC below)

### Add After Validation (v1.x)

- [ ] `.clinerules` set for standing instructions, sized to fit inside the Compact-Prompt-reduced budget — add once the base loop is proven to hold at 32K reliably
- [ ] Skills for any repeated multi-step workflow (e.g., "run cline-bench subset and file results") — add once it's clear which workflows actually repeat
- [ ] `cline schedule` for a low-stakes recurring task (e.g., nightly lint/dependency check) — add once the interactive path is trustworthy; scheduling failures on a broken base loop just fail silently more often
- [ ] Kanban dependency-chained multi-card workflows for larger changes — valuable once ohama has enough hands-on time with the board to trust queuing unattended work
- [ ] `--hook-command` custom script replacing/augmenting `--allowed-user-id` for combined identity+scope gating — nice hardening once the simpler flag-based gate is proven to work day-to-day

### Future Consideration (v2+)

- [ ] Slack/Discord/other connectors beyond Telegram — PROJECT.md explicitly excludes Discord/WhatsApp webhooks for this milestone; revisit only if a second device/workflow actually needs it
- [ ] Second model / model-switching — blocked by hardware (one model fits in memory); would require accepting unload/reload latency, a decision bigger than a feature
- [ ] Full cline-bench suite completion — explicitly out of scope given 2400s/task timeout vs 64.3s TTFT; revisit only if hardware or model changes shift the economics
- [ ] Ops runbook (restart/log/incident response) — explicitly deferred to a separate document per PROJECT.md's "매뉴얼은 사용법만" decision

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| 32K context pin (Cline-side) | HIGH | LOW | P1 |
| Compact Prompt ON | HIGH | LOW | P1 |
| Gateway-layer 32K guard | HIGH | MEDIUM | P1 |
| 32K-guard regression test | HIGH | MEDIUM | P1 |
| Kanban boot-persistent + Tailscale-only | HIGH | LOW-MEDIUM | P1 |
| Telegram connector + `--allowed-user-id` | HIGH | LOW | P1 |
| Workspace sandbox + whitelist | HIGH | MEDIUM | P1 |
| cline-bench subset (local Docker) + prompt/result capture | MEDIUM-HIGH | MEDIUM | P1 |
| Korean manual v1 (CLI/web/iPad-iPhone) | HIGH | MEDIUM | P1 |
| Headless CLI wrapper | MEDIUM | LOW | P1 |
| LAN token gate | MEDIUM | LOW | P1 |
| `.clinerules` set | MEDIUM | LOW | P2 |
| Skills | LOW-MEDIUM | LOW-MEDIUM | P2 |
| `cline schedule` recurring task | LOW-MEDIUM | LOW | P2 |
| Kanban dependency chains (documented usage) | MEDIUM | LOW (built-in) | P2 |
| `--hook-command` custom gating | LOW-MEDIUM | MEDIUM | P3 |
| MCP integration | — | — | Anti-feature (Compact Prompt conflict) |
| Focus Chain reliance | — | — | Anti-feature (Compact Prompt conflict) |
| Multi-model UI | — | — | Anti-feature (hardware conflict) |
| Cloud sync / telemetry / public webhooks | — | — | Anti-feature (scope/security conflict) |

---

## §3. cline-bench / Verification Feasibility (Answered Concretely)

**Can Harbor run tasks locally with Docker only, without a Daytona API key?**
**YES.** Confirmed directly from the cline-bench README: two environments are supported, `docker` (local, free, sequential, uses local machine resources) and `daytona` (cloud, paid, parallel). `DAYTONA_API_KEY` is documented as "Required: Cloud execution" only — it is not required for `--env docker`. Command shape: `harbor run -p <task-path> -a <agent> -m <provider:model-id> --env docker`. PROJECT.md's environment check (Docker + uv present, Python 3.14.6 with uv resolving cline-bench's 3.13 requirement) is consistent with this being runnable today. **Confidence: HIGH** (directly from repo README).

**Task structure**, confirmed: each task directory contains `instruction.md` (problem statement fed to the agent), `task.toml` (Harbor config — timeouts/resources; exact keys not enumerated in the README), `environment/Dockerfile` (broken initial state container), `solution/solve.sh` (oracle reference solution), and `tests/` (pytest verification suite). **Confidence: HIGH.**

**Can we capture both the prompt sent and the result, to files?**
**PARTIALLY CONFIRMED, PARTIALLY OPEN.** Harbor runs produce a `jobs/<timestamp>/` directory containing `config.json` (job settings), `result.json` (aggregate pass/fail, reward), and a per-trial `<task-id>__<hash>/` folder with `agent/cline.txt` ("Full Cline conversation log") and `verifier/reward.txt` + `verifier/test-stdout.txt`. This gives file-based **results** unambiguously (reward 1.0/0.0, test output). For the **prompt**: the README describes `cline.txt` as the full conversation log, which strongly implies it includes what was sent to the model, but the README does not explicitly confirm the raw system/user prompt (as opposed to just the agent's visible actions/text) is present verbatim. **Recommendation:** treat `cline.txt` as the primary prompt+result artifact, but verify empirically on the first real run (grep for the system prompt content) before relying on it as the sole capture mechanism; if it's insufficient, add a lightweight request-logging shim at the gateway (`:4000`/`:8011`) that already needs to exist for the 32K guard anyway — this doubles as prompt capture at effectively no extra cost. **Confidence: MEDIUM** (results capture HIGH, prompt capture MEDIUM pending empirical check).

**Is there an existing Cline eval that specifically stresses context limits?**
**NO — confirmed absent.** Checked both cline-bench's README and the `cline/cline` repo's `evals/README.md` (three-layer framework: contract tests in `src/core/api/transform/__tests__/`, smoke tests in `evals/smoke-tests/`, e2e/cline-bench tests in `evals/e2e/`). Neither documents any eval targeting context-window boundaries, 32K/128K compaction correctness, or long-context stress. This matches cline-analysis.md's independent conclusion (§4: "Cline을 32k 컨텍스트로 고정하고... 측정한 공개 GitHub 벤치마크는 존재하지 않는다"). **This means the regression test in this project has no upstream equivalent to borrow from or compare against — it must be built from scratch.** **Confidence: HIGH** (absence confirmed across both relevant repo locations).

**Diff-edit eval tooling in the repo:** confirmed to exist at `cline/cline/evals/diff-edits/`, measuring whether models produce SEARCH/REPLACE diffs that apply cleanly (`diffEditSuccess`), with the applied algorithm open-sourced at `evals/diff-edits/diff-apply/diff-06-23-25.ts`. This is a useful reference for *how* Cline structures its own evals (metrics like pass@k, reporters emitting Markdown/JSON) but is not itself a context-limit test and is not required for this project's scope — noted for awareness only. **Confidence: MEDIUM** (structure confirmed via search-derived summaries of the README, not a full raw read of every file).

**Task volume for a "partial run":** cline-bench includes a Terminal-Bench-2.0-derived 89-task CLI-wide evaluation (2400s/task timeout, ~40-50 min for a full parallel run) per cline-analysis.md, plus a distinct e2e layer described in `evals/README.md` as "12 real-world coding problems executed via Docker." These are likely two different task sets at two different granularities (cline-bench proper vs. the in-repo e2e harness) — **treat as two candidate pools to sample from**, not one number. Given the 64.3s TTFT reality, a defensible "partial run" for this project is on the order of 3-5 tasks, chosen for being agentically shallow (few turns) rather than complex/long-running, run sequentially via `--env docker`. **Confidence: MEDIUM** (task counts are corroborated across two independent fetches but not exhaustively verified against the live repo tree).

---

## §4. Korean Manual — Proposed Table of Contents

Scope: usage only (CLI, web/Kanban, iPad/iPhone), explicitly excludes ops (restart/logs/incident response — separate document per PROJECT.md). Structure modeled on how docs.cline.bot itself sequences things (Getting Started → per-surface Usage → Customization → reference), adapted to this project's three fixed surfaces and single fixed model.

```
한글 사용 매뉴얼 — 목차 (제안)

0. 시작하기 전에
   0.1 이 서버가 무엇인가 (한 문단 — 로컬 모델, 32K, 세 표면)
   0.2 내가 신경 쓸 필요 없는 것들 (모델 선택, 인증 설정 — 이미 다 되어 있음)
   0.3 알아야 할 단 하나의 제약: 32K와 64초 대기

1. 아이패드에서 — Kanban 웹 보드
   1.1 처음 접속하기 (Tailscale로 들어가서 브라우저 열기)
   1.2 카드 만들기 — 작업 지시 쓰는 법
   1.3 진행 상황 보기 (카드가 움직이는 것, 대기 상태 읽는 법 — 64초 감안)
   1.4 diff 리뷰하기 — 줄 클릭해서 코멘트 남기기
   1.5 카드 연결하기 (의존 체인) — 여러 작업 순서대로 쌓기
   1.6 완료된 카드 정리하기 (커밋 / PR 열기 / 휴지통으로 이동)
   1.7 터치에서 자주 헷갈리는 것들 (스크롤, 긴 diff, 텍스트 입력)

2. 아이폰에서 — Telegram으로 말 걸기
   2.1 봇에게 말 걸기 — 세션이 뭔지 (메시지 하나 = 세션 하나)
   2.2 새 작업 시작하기 / 이전 작업 이어가기
   2.3 자주 쓰는 명령 (/new, /tools, /whereami, /schedule, /abort)
   2.4 승인/거부하기 — 왜 자동승인(YOLO)을 안 쓰는지
   2.5 결과 받기 — 파일 변경 알림 읽는 법
   2.6 폰에서 절대 할 수 없는 것 (diff를 눈으로 정밀 리뷰하는 것 — 대신 카드로 가서 보기)

3. 터미널에서 — CLI 직접 쓰기
   3.1 기본 호출법 (대화형 vs 헤드리스)
   3.2 헤드리스로 스크립트에 물리기 (--json 출력 읽는 법)
   3.3 예약 작업 (cline schedule) — 있다면, 반복 작업 걸어두기
   3.4 세 표면이 같은 작업을 공유한다는 것 (CLI에서 시작한 걸 아이패드에서 이어보기)

4. 세 표면 공통 — 알아야 할 것
   4.1 왜 기다려야 하는가 — 32K와 64초, 그리고 그게 괜찮은 이유
   4.2 Plan 모드와 Act 모드 — 언제 뭘 쓰나
   4.3 체크포인트 — 되돌리기, git과 무슨 관계인가
   4.4 지금 이 서버에서 못 쓰는 기능 (MCP, Focus Chain) — Compact Prompt 때문
   4.5 작업공간 밖으로 못 나간다는 것 (샌드박스가 왜 있는가, 뭘 못 하게 막는가)

5. 문제가 생겼을 때 (사용자 관점만 — 운영 대응 아님)
   5.1 응답이 안 온다 — 정말 멈춘 건지, 그냥 느린 건지 구분하는 법 (64초 기준)
   5.2 "컨텍스트 초과"라고 뜬다 — 무슨 뜻이고 뭘 해야 하나 (새 작업으로 넘어가기)
   5.3 봇/보드에 접속이 안 된다 — Tailscale 연결부터 확인
   5.4 이 이상은 운영 문서로 (참조만, 내용은 여기 안 담음)
```

**Rationale for this ordering:** docs.cline.bot itself sequences by *surface* first (Getting Started → Usage: IDE/TUI/CLI/Kanban → Customization → reference), not by feature. This manual mirrors that: device-first chapters (iPad, iPhone, terminal) because that's how ohama will actually approach the manual — "I'm on my iPad, what do I do" — followed by a cross-cutting chapter for concepts that apply everywhere (waiting, Plan/Act, checkpoints, what's disabled), ending in a short troubleshooting chapter that explicitly punts to the (separate, out-of-scope) ops runbook rather than duplicating it.

---

## §5. Mobile/iPad Feature Reality Check (Concrete, Per Question 2)

**What the Kanban web UI offers on touch, confirmed from official docs:**
- Creating cards, viewing board state, opening a card's detail view, reading a diff against the base branch scoped by checkpoint, clicking any diff line to leave an inline comment that's fed back to the agent, committing, opening a PR, moving a card to trash.
- Per-card git worktrees are transparent to the user — the value felt on the UI is "cards don't step on each other."
- Dependency chains via ⌘/Ctrl+click to link cards — **this exact interaction (modifier-key+click) is a genuine touch-usability gap**: iPadOS has no reliable Cmd-click equivalent for a web page expecting a desktop modifier-click gesture. **This is a concrete, confirmed "not possible from mobile" finding** — worth flagging to requirements: card-linking may need to be done from a desktop browser or via an alternate UI affordance if one exists (not confirmed either way — docs only describe the desktop gesture).

**What is NOT confirmed as touch/mobile-optimized:** Cline's own docs for both `kanban/core-workflow` and `kanban/remote-access` contain **zero mentions of mobile, touch, or responsive design** despite `remote-access` explicitly walking through Tailscale setup for "phones, tablets, and distant machines." This is a meaningful gap: Cline documents *how to reach* the board from a tablet but never confirms the board's UI was *designed* for touch. **Practical implication for requirements: assume the Kanban UI is a standard responsive web app that works adequately on iPad Safari (modern web frameworks generally do), but budget explicit UX validation time on an actual iPad rather than trusting docs — and treat the Cmd-click card-linking gesture as a known, confirmed gap requiring either a workaround or an explicit "do this part on a laptop" manual note.**

**What Telegram gives vs. what it can't, confirmed:**
- Can: start/continue sessions, run slash commands (`/new`, `/tools`, `/yolo`, `/whereami`, `/cwd`, `/schedule`, `/abort`), approve/deny tool calls, receive text notifications of file changes.
- Cannot: render or meaningfully review a multi-file diff — a chat bubble is not a diff viewer. Official guidance itself steers away from `/yolo` on messenger bridges specifically because "폰에서는 무엇을 승인하는지 제대로 읽을 수 없다" (a phone can't properly read what it's approving) — this is Cline's own docs conceding the review limitation, not a project inference. **Confidence: HIGH**, this is as close to an explicit vendor statement of "this surface has a real limitation" as exists in the source material.

---

## Sources

- `docs.cline.bot/cli/connectors` — connector platforms, Discord slash commands, `--hook-command`, `--allowed-user-id`, default-open-access warning (fetched directly)
- `docs.cline.bot/kanban/core-workflow` — worktrees, dependency-chain linking gesture, diff/inline-comment mechanics (fetched directly)
- `docs.cline.bot/kanban/remote-access` — Tailscale/LAN/SSH-tunnel/Cloudflare/ngrok options, `KANBAN_RUNTIME_HOST=0.0.0.0`, explicit trust-model warning (fetched directly)
- `docs.cline.bot/features/checkpoints` — shadow-git mechanism, 3-way restore, compare UX (fetched directly)
- `docs.cline.bot/features/skills` — SKILL.md format, progressive loading, token costs (fetched directly)
- `docs.cline.bot/running-models-locally/read-me-first` — Compact Prompt as essential for local models, provider setup (fetched directly)
- `docs.cline.bot/llms.txt` — full documentation site tree (fetched directly, used to inform manual TOC ordering)
- `docs.cline.bot/cli/cli-reference` (via search-derived summary) — `--json` schema, `--auto-approve`, `CLINE_SANDBOX`/`CLINE_SANDBOX_DATA_DIR`/`CLINE_COMMAND_PERMISSIONS`
- `docs.cline.bot/cli/scheduling` (via search-derived summary) — `cline schedule` scope, hub persistence, CLI/SDK/Kanban-only limitation
- `docs.cline.bot/customization/cline-rules` (via search-derived summary) — `.clinerules` merge/toggle behavior
- GitHub issue [#5924](https://github.com/cline/cline/issues/5924) — "Use compact system prompt" explicitly stated to not support MCP and Focus Chain (verified quote)
- `github.com/cline/cline-bench` README (fetched directly, two passes) — task structure, Harbor `--env docker` vs `--env daytona`, `DAYTONA_API_KEY` scope, `jobs/` output structure, `agent/cline.txt` + `result.json`
- `github.com/cline/cline/blob/main/evals/README.md` (fetched, search-derived summary) — three-layer eval framework, confirmed absence of context-limit-specific evals, 12-task e2e/cline-bench pool
- `github.com/cline/cline/tree/main/evals/diff-edits` (search-derived) — diff-apply algorithm location, diffEditSuccess metric
- `cline-analysis.md` (this session's earlier research artifact) — Terminal-Bench-2.0 89-task pool, 32K/128K fallback bug root cause in `builtins.ts`/`compat.ts`, TTFT table, compaction threshold formula. Reused per instructions; cross-checked against fresh fetches above where overlapping (no contradictions found).
- `.planning/PROJECT.md` — authoritative project constraints (single user, 32K cap, Compact Prompt decision, Tailscale/LAN policy, sandbox requirement, out-of-scope list)

---
*Feature research for: self-hosted Cline local agent server (single user, 32K/local model, iPad+iPhone reachable) + Korean manual + bench verification*
*Researched: 2026-08-29*
