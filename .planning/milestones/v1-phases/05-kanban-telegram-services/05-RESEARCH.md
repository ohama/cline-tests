# Phase 5: Kanban·Telegram 서비스화 - Research

**Researched:** 2026-08-30
**Domain:** macOS launchd service supervision for two Node/Bun CLI processes (`kanban`, `cline connect telegram`) sitting on top of an already-hardened local inference stack
**Confidence:** HIGH for CLI surface/flags/plist mechanics (static binary analysis + live `--help`/`--version` only); MEDIUM for exact runtime behavior when flashnext is actually down (inferred from code, not yet live-verified); LOW/OPEN for the local "cline host" RPC port allocation between kanban and the telegram connector.

## Summary

This phase registers two new launchd agents on top of infrastructure Phases 1-4 already built and hardened. Both `cline` (3.0.53, pinned) and `kanban` (0.1.70, pinned) are real, separately-installed global npm binaries at `/opt/homebrew/bin/cline` and `/opt/homebrew/bin/kanban`; `cline connect telegram` is a subcommand of the `cline` binary, not a separate package. All the concrete facts below came from reading `~/Library/LaunchAgents/*.plist`, `phase-0{2,3,4}/**`, `docs/*.md`, and from `strings`-ing the two installed binaries plus two safe, version/help-only live invocations (`kanban --version`, `kanban --help`) — no `cline` invocation was made (would have cost a version-drift/providers.json-wipe risk per house rules), and no `kanban` invocation touched cline's config.

The three existing plists (`com.ohama.flashnext/litellm/role-shim`) share one house style: `KeepAlive: true` (bare boolean, not a dict), `RunAtLoad: true`, `ThrottleInterval` 10-60s, absolute binary paths in `ProgramArguments`, `StandardOutPath`/`StandardErrorPath` under a writable log directory, and (for two of three) an explicit `WorkingDirectory`. Phase 5's two new plists should match this house style closely, but need one structural addition none of the three examples have: because both new processes must run through the Phase 3 sandbox (`phase-03/sandbox/run_sandboxed.sh`) and are subject to THE CWD RULE (Phase 4's Pitfall 1: OS-level process cwd must already be inside `ALLOWED_REPOS.json` or Bun/Node dies at startup with a useless generic error), `ProgramArguments` cannot be a bare binary invocation — it needs to point at a small wrapper script that `cd`s into the sandboxed workdir first, then execs through `run_sandboxed.sh`.

Three findings materially change the plan and were not obvious from the roadmap text alone: (1) `cline connect telegram` **self-daemonizes by default** (forks a detached background child and the parent exits almost immediately) — under launchd this is fatal to supervision unless `-i/--interactive` is passed; (2) `kanban` has its **own separate auto-update gate**, `KANBAN_NO_AUTO_UPDATE=1`, which the existing `check_versions.sh` Check C does **not** scan for (it only checks `CLINE_NO_AUTO_UPDATE`) — a real, currently-invisible drift gap; (3) `~/local-llm-settings/sync.sh` mirrors only labels in a **hardcoded bash array** — SVC-05 is unsatisfiable by just running `sync.sh` unless that array is edited to add the two new labels.

**Primary recommendation:** Build one shared "wait-then-exec" wrapper pattern reused by both plists: `cd` into a sandboxed workdir → run a bounded TCP-connect wait loop against `127.0.0.1:4000` (not a fixed sleep) → exec the real command through `run_sandboxed.sh`, with `KeepAlive` staying a bare boolean (matching house style) and the wrapper itself, not launchd, absorbing the "flashnext isn't up yet" window so `ThrottleInterval` never has to fight a tight process-level crash loop. For the empty Telegram token, do **not** register a bare `KeepAlive` job that execs `cline connect telegram` with `-k ""` — it throws synchronously and would crash-loop forever, which is exactly the case ROADMAP's own decision text warns about. Ship a wrapper that detects the empty/placeholder token and idles (not exits) instead, so `launchctl print` genuinely shows `state = running` without ever calling a Telegram API or lying about being connected.

## Standard Stack

Not applicable in the conventional sense (no new libraries to add) — the "stack" here is two already-installed, version-pinned binaries plus the existing launchd/sandbox/restart tooling:

### Core

| Component | Version | Purpose | Why Standard |
|---|---|---|---|
| `cline` | 3.0.53 (pinned, `phase-01/config/cline-invocation.env`) | `connect telegram` subcommand provides the Telegram bridge | Only binary with a `connect` subcommand; confirmed via `strings`, not invoked live for this research |
| `kanban` | 0.1.70 (pinned, same env file) | Local kanban web server (`/opt/homebrew/lib/node_modules/kanban/dist/cli.js`, real 16MB bundle) | Confirmed live: `kanban --version` → `0.1.70`, `kanban --help` → full flag list |
| `phase-03/sandbox/run_sandboxed.sh` | as-is | Sole sanctioned way to run any remotely-triggerable process (Phase 3 goal explicitly names Kanban and Telegram) | `EXTRA_ALLOW_PATHS` stays empty; do not widen |
| `phase-02/infra/restart_service.sh` | as-is, or forked | bootout→poll-teardown→bootstrap→poll-healthy sequence; `launchctl bootout` is async and a naive restart hits `Bootstrap failed: 5: I/O error` | Already solved this exact trap for flashnext; reuse the sequence verbatim per `docs/infra-hardening.md` §6's explicit instruction to Phase 5 |
| `phase-01/config/cline-invocation.env` | as-is | Single source for `CLINE_BIN`, `KANBAN_BIN`, pinned versions, `CLINE_NO_AUTO_UPDATE=1` | Already states "Sourced by ... Phase 5 launchd plists" in its own header comment |

### Supporting

| Component | Purpose | When to Use |
|---|---|---|
| `phase-02/infra/verify_no_regression.sh` | Standing read-only INF-03 gate (full chain litellm→role-shim→mlx_vlm) | Call before/after bringing either new service up, per its own header comment addressed to Phase 5 |
| `phase-03/sandbox/verify_sandbox.sh` | Standing sandbox gate | Call before trusting `run_sandboxed.sh` for the new wrapper scripts |
| `phase-01/config/check_versions.sh` | Version-pin + plist `EnvironmentVariables` scanner (Check C) | Will start doing real work the moment Phase 5's plists exist — **but it does not check `KANBAN_NO_AUTO_UPDATE`, see Pitfalls** |
| `~/local-llm-settings/sync.sh` | Live→mirror one-way sync of tracked launchd plists | Must be edited (its `LABELS=(...)` bash array), not just re-run, or SVC-05 cannot pass |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| A wait-loop wrapper for SVC-04 | `KeepAlive` as a dict (`{SuccessfulExit: false}` etc.) alone | Dict-form `KeepAlive` only changes *when launchd restarts*, not *how fast it crash-loops before flashnext is up*; still needs `ThrottleInterval` tuning and doesn't stop noisy repeated failed-connection attempts in the log. A wrapper that blocks until `:4000` is reachable is strictly better: zero failed launches, `ThrottleInterval` never even engages during the flashnext-not-up window. |
| Invoking `/opt/homebrew/bin/kanban` directly | `cline kanban` subcommand | `cline kanban` calls the same `launchKanban` code path **but has its own auto-install fallback** (`"kanban is not installed. Install it with npm i -g kanban"` → runs `npm install -g kanban@latest` if its own detection thinks kanban is missing/broken) — a silent drift vector off the pinned 0.1.70. Always invoke the standalone binary. |

**Installation:** N/A — both binaries are already installed and pinned; this phase writes plists + wrapper scripts only.

## Architecture Patterns

### Recommended Project Structure

```
phase-05/
├── services/
│   ├── config.env                 # LAUNCH_AGENTS_DIR, MIRROR_AGENTS_DIR, labels, ports, timeouts — mirrors phase-02/phase-04 convention
│   ├── wait_for_port.sh           # shared: poll a host:port with a bounded timeout, no fixed sleep
│   ├── run_kanban_service.sh      # cd into sandboxed workdir -> wait_for_port :4000 -> exec run_sandboxed.sh -- kanban ...
│   ├── run_telegram_service.sh    # cd into sandboxed workdir -> if token empty: idle; else wait_for_port :4000 -> exec run_sandboxed.sh -- cline connect telegram -i ...
│   └── restart_service.sh         # either a thin re-export of phase-02/infra/restart_service.sh, or a fork with its own BACKUP_DIR — decide explicitly, don't silently duplicate logic
├── plists/
│   ├── com.ohama.kanban.plist         # staged copy of what gets installed to ~/Library/LaunchAgents
│   └── com.ohama.telegram-connect.plist
└── results/                       # timestamped evidence dirs, same convention as phase-02/03/04
```

Actual install targets remain `~/Library/LaunchAgents/*.plist` (loaded by launchd) with a mirrored copy in `~/local-llm-settings/launchagents/` (SVC-05) — the `phase-05/plists/` copies above are the versioned staging source, same pattern as `phase-02/infra/backups/`.

### Pattern 1: Wait-then-exec wrapper (the SVC-04 mechanism)

**What:** A tiny bash wrapper is `ProgramArguments[0]` in the plist. It does NOT loop forever on its own — it does one bounded wait (e.g. up to `ThrottleInterval`-sized budget, or a longer one like 300s), then execs the real sandboxed command. If the wait times out, it exits non-zero and lets `KeepAlive`+`ThrottleInterval` retry the whole cycle (still safe — `ThrottleInterval` caps retry frequency exactly like the three existing services already rely on).

**When to use:** Both new plists, to keep `KeepAlive` a bare boolean (house style) rather than inventing a new pattern, while still not hammering flashnext with rapid dead connection attempts before it is up.

**Example (illustrative, not yet written to disk):**
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"
source "$PROJECT_ROOT/phase-01/config/cline-invocation.env"

cd "$SANDBOX_WORKDIR"   # THE CWD RULE — must happen before anything else

# Bounded wait for flashnext's HTTP hop (litellm:4000), not a fixed sleep.
WAITED=0
while ! nc -z -G 2 127.0.0.1 4000 2>/dev/null; do
  if [ "$WAITED" -ge "${FLASHNEXT_WAIT_TIMEOUT:-300}" ]; then
    echo "flashnext still unreachable after ${WAITED}s — exiting, KeepAlive/ThrottleInterval will retry" >&2
    exit 1
  fi
  sleep 5; WAITED=$((WAITED + 5))
done

exec "$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh" -- "$KANBAN_BIN" --no-open --host 127.0.0.1 --port 3484
```

### Pattern 2: Idle-when-token-absent wrapper (the SVC-02 shape)

**What:** For the Telegram connector, the wrapper checks whether `TELEGRAM_BOT_TOKEN` (env var, or a file path if preferred for injection ergonomics) is non-empty. If empty, it logs a clear one-line notice and blocks indefinitely (`exec sleep infinity`, or a coarse poll loop re-checking every N minutes so a later token drop-in *could* be picked up without a manual restart — either is acceptable, `exec sleep infinity` is simplest and matches "leave the token slot empty, registered but obviously inert"). It must NOT exit 0 or non-zero in this branch — either would either not-loop (fine but then `state` isn't "running" in the sense of "doing the job", though technically for `exit 0` under `KeepAlive:true` it *would* immediately relaunch, creating a fast, harmless-but-noisy restart loop that is still a real crash-loop by definition and burns log lines every `ThrottleInterval`). Blocking is the only shape that is both honest and quiet.

**When to use:** `run_telegram_service.sh` only. This directly implements ROADMAP's own instruction to leave the token slot empty "with clear injection instructions" while still passing Success Criterion 1's literal `state = running` requirement for both labels.

### Anti-Patterns to Avoid

- **Bare `ProgramArguments: [KANBAN_BIN, ...]` or `[CLINE_BIN, connect, telegram, ...]` with no wrapper:** breaks THE CWD RULE (no guaranteed sandboxed cwd) and, for kanban, skips the sandbox entirely (Phase 3's own stated goal names Kanban/Telegram as things that must not touch the real repo without the sandbox).
- **`cline connect telegram -k "$TOKEN" -m bot ...` without `-i/--interactive`:** self-daemonizes — the plist's supervised process forks a detached child and exits, so launchd sees a near-instant exit every cycle. Depending on `KeepAlive` shape this either crash-loops the parent (spawning a *new* orphaned child every `ThrottleInterval`, which is a slow leak of undead bot processes) or, worse, looks like intermittent "success" that launchd doesn't retry, while the actual bot process is unsupervised and un-recoverable by `KeepAlive`.
- **Passing `-k ""` and trusting `KeepAlive` + a generous `ThrottleInterval` to "safely" crash-loop forever:** this is explicitly what the phase must avoid — see Pitfalls and the token-less-connector section below.
- **A fixed `sleep N` before exec instead of a poll:** either too short (still races flashnext's ~64s TTFT / cold-load window) or wastefully long on the common case where flashnext is already up. Poll with a bounded timeout, exactly like `restart_service.sh` already does for its own teardown/healthy checks.
- **`kanban --port auto`:** non-deterministic port defeats "known, fixed, non-3000 port" hygiene and makes future Phase 6 Tailscale/reverse-proxy config brittle. Pin `--port 3484` explicitly (matches the CLI's own default, confirmed live) rather than relying on the unstated default.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| launchd bootout/bootstrap race | A new ad-hoc `launchctl unload && launchctl load` script | `phase-02/infra/restart_service.sh` (reused/forked, label+port parameterized already) | Already hit and fixed `Bootstrap failed: 5: Input/output error` from `bootout`'s asynchrony — `docs/infra-hardening.md` §6 tells Phase 5 explicitly to reuse this exact sequence |
| "is flashnext up" check | A custom HTTP client / retry framework | A plain `nc -z` or `curl -sf -m 2 http://127.0.0.1:4000/v1/models` poll loop, same idiom `phase-02/infra/verify_no_regression.sh` already uses | No new dependency, matches an already-reviewed pattern |
| Sandboxing the two new processes | A second, parallel sandbox mechanism | `phase-03/sandbox/run_sandboxed.sh` unchanged, `EXTRA_ALLOW_PATHS` still empty | Phase 3's whole point; a second mechanism would be an unreviewed new attack surface |
| Version-pin drift detection | New ad-hoc grep for `KANBAN_NO_AUTO_UPDATE` in each new plist by hand | Extend `phase-01/config/check_versions.sh` Check C to also require `KANBAN_NO_AUTO_UPDATE=1` for any plist whose haystack matches "kanban" (mirrors the existing `CLINE_NO_AUTO_UPDATE` check almost line-for-line) | Check C is explicitly described in its own header as "armed for reuse" the moment Phase 5 creates plists — but as written today it only verifies the `cline` half of the pin, leaving `kanban`'s own separate auto-update gate unchecked |

**Key insight:** almost everything this phase needs already exists and was built by earlier phases *specifically anticipating* this phase (the restart helper, the sandbox wrapper, the regression gate, the pinned invocation env, even the CWD-rule warning in `docs/headless-wrapper.md` §6). The actual net-new work is: two wrapper scripts, two plists, one `sync.sh` edit, and one `check_versions.sh` extension.

## Common Pitfalls

### Pitfall 1: `cline connect telegram` self-daemonizes by default

**What goes wrong:** Without `-i/--interactive`, the process forks a detached background child (env `CLINE_TELEGRAM_CONNECT_CHILD=1`), prints `[telegram] starting background connector pid=<N>`, and the parent process — the one launchd is actually supervising — exits almost immediately.
**Why it happens:** Confirmed via `strings` on the installed 3.0.53 binary: `maybeRunInBackground(...)` is called unconditionally in `runWithOptions` unless `V.interactive` is true; the option is defined as `.option("-i, --interactive","Keep connector in foreground")`.
**How to avoid:** Always pass `-i` (equivalently `--interactive`) in the plist's `ProgramArguments` (via the wrapper). Confirmed the same self-daemonizing default and the same `-i` escape hatch exists for every other `connect <channel>` subcommand (slack/discord/linear/gchat/whatsapp) — this is a shared base-class behavior (`class P1`), not telegram-specific.
**Warning signs:** `launchctl print gui/$UID/com.ohama.telegram-connect` shows the job cycling through `state = running` → gone → running with a shrinking or empty `pid`, or `ThrottleInterval`-spaced entries in the log that each say "starting background connector pid=..." with a *different* pid every time and no matching "stopped" line (orphaned children accumulating — check with `ps aux | grep cline` for a growing count of `connect telegram` processes not attached to the launchd job's own pid).

### Pitfall 2: `kanban` has its own separate auto-update gate, and the existing drift scanner doesn't check it

**What goes wrong:** `check_versions.sh` Check C (the plist `EnvironmentVariables` scanner) only asserts `CLINE_NO_AUTO_UPDATE=1`. `strings` on the installed `kanban` binary shows `if (env2.KANBAN_NO_AUTO_UPDATE === "1")` guarding its own update path, and kanban's own help output lists `--update`/`update` as a first-class command — i.e. kanban really can self-update, independent of cline's update mechanism, and today nothing but human review would catch a Phase-5 plist that forgot `KANBAN_NO_AUTO_UPDATE=1`.
**Why it happens:** Check C was written in Phase 1 before Phase 5's plists (and this env var) existed; its "armed for reuse" comment assumed the `cline`-side variable was the whole story.
**How to avoid:** Set `KANBAN_NO_AUTO_UPDATE=1` in the kanban plist's `EnvironmentVariables` regardless (defense in depth), and — recommended, not yet done — extend Check C's Python haystack check to require `KANBAN_NO_AUTO_UPDATE=1` too whenever `"kanban"` appears in a plist's `Program`/`ProgramArguments`. This is a small, mechanical change to an existing, already-tested script; flag it explicitly to the planner as in-scope for Phase 5 (it directly protects SVC-01's "재부팅 후에도 동일 버전" implied guarantee, by extension from CFG-06).
**Warning signs:** `check_versions.sh` reports `PASS` even though `kanban --version` has silently drifted off `0.1.70` after a launchd restart.

### Pitfall 3: `~/local-llm-settings/sync.sh`'s label list is hardcoded — SVC-05 fails silently otherwise

**What goes wrong:** SVC-05 requires the new plists to show up "in `sync.sh`'s output". Reading `sync.sh` shows its `LABELS=(...)` bash array is a literal, hand-maintained list (`com.ohama.flashnext com.ohama.role-shim com.ohama.litellm com.ohama.qwen36-35b ...`). It does **not** glob `~/Library/LaunchAgents/*.plist` — a plist for a label not in that array is invisible to `sync.sh` forever, no matter how many times it's run.
**Why it happens:** `sync.sh` was designed for a small, curated, hand-reviewed set of "things this project's live→mirror snapshot cares about," which is reasonable, but means every new tracked service is an explicit opt-in edit, not automatic.
**How to avoid:** Phase 5 must edit `~/local-llm-settings/sync.sh` itself (outside this git repo) to add the two new labels (e.g. `com.ohama.kanban com.ohama.telegram-connect`) to `LABELS=(...)`, then run `./sync.sh` and confirm both plists land under `launchagents/` and `STATE.md`'s launchd table picks them up. Optionally also add a `8000:...`-style row for kanban's `3484` port in the hand-written port table (`STATE.md`'s port section is likewise hardcoded, not auto-discovered — lower priority than the `LABELS` edit but worth doing for STATE.md accuracy).
**Warning signs:** `./sync.sh --check` reports "실제 시스템과 일치한다" (no diffs) even though two new plists clearly exist in `~/Library/LaunchAgents/` and are not yet in the mirror — this is the "vacuous pass" failure mode, exactly analogous to Check C's vacuous pass before any cline/kanban plist existed.

### Pitfall 4: an empty-token Telegram service under bare `KeepAlive` is a real, indefinite crash loop

**What goes wrong:** `readOptions()` in the installed 3.0.53 binary does `if(!X) throw Error("connect telegram requires -k/--bot-token <token>")` where `X` is `botToken (CLI) || process.env.TELEGRAM_BOT_TOKEN`. This throw is synchronous, before any network or RPC-host activity. If the plist directly execs `cline connect telegram` with an empty token under `KeepAlive: true`, the process will exit near-instantly, forever, throttled only by `ThrottleInterval` — a permanent crash loop that never resolves itself (unlike SVC-04's flashnext-not-up-yet case, which resolves once flashnext starts).
**Why it happens:** ROADMAP's decision text explicitly wants the token slot left empty for this phase, and the criteria simultaneously require `state = running` for both labels — these two facts are only reconcilable with a wrapper, not a bare exec.
**How to avoid:** See Architecture Pattern 2 above — the wrapper must detect the empty token and block (not exit, not throw) rather than ever invoking `cline connect telegram` for real. Recommended detection: `[ -z "${TELEGRAM_BOT_TOKEN:-}" ]` on an env var the plist deliberately sets to the empty string, with a comment in the plist/wrapper documenting exactly how to inject a real token later (set the value, then restart via `restart_service.sh` — never edit the mirror or hand-edit around the house rules).
**Warning signs:** Rapidly repeating, identical stderr lines in the telegram connector's log file (`StandardErrorPath`), one per `ThrottleInterval`; `launchctl print` showing a `pid` that changes on every poll.

### Pitfall 5: the sandbox's `PROTECTED_ROOT=$HOME` deny could plausibly hit kanban's own state directory — verified NOT an issue, but only by checking

**What goes wrong (would-be):** `phase-03/sandbox/config.env` denies file-read/write under `$HOME` except for punched-through paths (`ALLOWED_REPOS.json` entries + `$HOME/.cline` always). If kanban stored its own state somewhere else under `$HOME` (e.g. the common `~/Library/Application Support/<app>` convention many Node CLIs use), it would hit the same class of SIGABRT/EPERM failure Phase 4 spent real effort diagnosing for cline's own stdio/cwd handling.
**What was actually found:** Empirically confirmed by listing the real filesystem (no kanban invocation needed) — kanban's actual state lives at `~/.cline/kanban/` (`config.json`, `hooks/`, `workspaces/`), i.e. **inside** the directory `phase-03/sandbox/config.env` already always punches through (`CLINE_DATA_DIR="$HOME/.cline"`). No new `EXTRA_ALLOW_PATHS` entry is needed for this.
**How to avoid:** Nothing to do — documenting this here so a future re-check of the sandbox boundary doesn't have to re-derive it. If a kanban version bump ever relocates this directory, re-verify with `find ~ -maxdepth 3 -iname '*kanban*'` before assuming it's still covered.

### Pitfall 6: `workspace/scratch-repo` is not its own git repository

**What goes wrong:** `git -C workspace/scratch-repo rev-parse --show-toplevel` returns `/Users/ohama/projs/cline-tests` (the outer project repo), not `workspace/scratch-repo` itself — there is no `.git` inside `scratch-repo`. If kanban's cwd is set to `scratch-repo` (reusing Phase 4's `SANDBOX_WORKDIR` convention, which derives from `ALLOWED_REPOS.json`'s first entry), kanban's own git-root discovery will resolve to the *outer* repo, while the sandbox profile only punches through `workspace/scratch-repo` specifically — a real scope mismatch between what kanban thinks its workspace boundary is and what the OS-level sandbox actually allows.
**Why it happens:** `scratch-repo` was created by Phase 3/4 purely as a sandboxed cwd target for one-shot `cline` prompt invocations, which don't care about git-root discovery the way an interactive kanban board (worktrees, dependency chains, PR flows) does.
**How to avoid:** This doesn't block Phase 5's literal SVC criteria (service up / recovers / registered — none of which requires kanban's board to functionally manage a real repo yet), so it is flagged as an **Open Question for the planner**, not a blocking pitfall: either (a) accept it as out of scope since no task will actually be created/started in this phase, or (b) `git init` inside `workspace/scratch-repo` (a one-line, low-risk, reversible fix) so kanban's own toplevel resolution stays correctly scoped inside the sandbox boundary from day one.

### Pitfall 7: `--hook-command` is the only programmatic approval surface, and it does not literally accept `--auto-approve false`

**What goes wrong (if translated carelessly):** ROADMAP's locked decision #1 says "keep `--auto-approve false`... exactly like the Phase 4 wrapper." But `--auto-approve <boolean>` is a flag on the plain `cline <prompt>` invocation (`CLINE_COMMON_FLAGS`), not on `cline connect telegram` — the connector subcommand's actual flag surface for gating tool use is `--no-tools`/`--enable-tools` (tools enabled by default) and, separately, `--hook-command <command>` (a JSON-in/JSON-out approval hook — confirmed via `strings`, and independently confirmed by `docs/headless-wrapper.md` §4, which already flagged this as *the* thing Phase 5 has to resolve). A plist that copies `--auto-approve false` verbatim onto `cline connect telegram` would simply be an invalid/ignored flag, silently leaving tools enabled with no approval gate — the opposite of the locked decision's intent.
**Why it happens:** The flag surface genuinely differs between the one-shot prompt mode (Phase 4) and the connector mode (Phase 5); `docs/headless-wrapper.md` §4 already named this gap and explicitly said it needs a human decision, not a silent default.
**How to avoid:** Translate the decision faithfully onto the surface that exists: pass **`--no-tools`** to `cline connect telegram`, which is the literal "tools disabled, safe-but-inert" equivalent of `--auto-approve false` for this surface (mirrors Phase 4's "refuses to act rather than acts unsupervised" posture exactly). This is consistent with — and directly resolves — the exact fork in the road `docs/headless-wrapper.md` §4/§8 flagged as "must be escalated to a human, never decided silently": ROADMAP's decision #1 is that human decision, already made, in favor of staying inert. Kanban itself needs no equivalent flag in this phase: it is driven by direct human interaction through its own web UI (a human clicking "start" on a task, same trust model as a human at a keyboard), not by an unattended remote trigger, and no task is created in Phase 5 anyway.
**Warning signs:** none observable within Phase 5 itself (no message will ever be sent to the bot, since the token is empty) — this is a "get it right before Phase 6 makes it observable" pitfall, worth a code comment at minimum.

### Pitfall 8: log files under `StandardOutPath`/`StandardErrorPath` are never rotated by launchd

**What goes wrong:** None of the three existing plists use `>>`-append semantics that get rotated — launchd just appends forever to the paths named in `StandardOutPath`/`StandardErrorPath`. A crash-looping service (Pitfall 1 or 4, before the wrapper fixes are in place) can grow these files unboundedly within hours.
**Why it happens:** launchd has no built-in log rotation; this is a known, generic launchd limitation, not specific to this project.
**How to avoid:** Not necessarily Phase 5's job to solve generically (none of the three existing services rotate logs either — an accepted existing gap), but worth pairing with the crash-loop-avoidance work above: if the wrapper designs in Patterns 1/2 are implemented correctly, neither service should ever actually crash-loop, which is a much better mitigation than rotation.

## Code Examples

### Existing plist house style (verbatim, `com.ohama.flashnext.plist`, the fullest example)

```xml
<key>EnvironmentVariables</key>
<dict>
	<key>PATH</key>
	<string>/Users/ohama/projs/qwen38-flash-next-tests/.venv-mlxvlm-new/bin:/usr/local/bin:/usr/bin:/bin</string>
</dict>
<key>KeepAlive</key>
<true/>
<key>Label</key>
<string>com.ohama.flashnext</string>
<key>ProgramArguments</key>
<array>
	<string>/Users/.../python3</string>
	<string>-m</string>
	<string>mlx_vlm.server</string>
	... flags ...
</array>
<key>RunAtLoad</key>
<true/>
<key>StandardErrorPath</key>
<string>/Users/ohama/llm-system/services/logs/flashnext.err</string>
<key>StandardOutPath</key>
<string>/Users/ohama/llm-system/services/logs/flashnext.log</string>
<key>ThrottleInterval</key>
<integer>60</integer>
<key>WorkingDirectory</key>
<string>/Users/ohama/projs/qwen38-flash-next-tests</string>
```

`role-shim.plist` is the sparsest of the three (no `EnvironmentVariables`, no `WorkingDirectory`) — `litellm.plist` and `flashnext.plist` both set `WorkingDirectory`. **Recommendation: Phase 5's two new plists should always set `WorkingDirectory` explicitly** (to the sandboxed workdir), since `docs/headless-wrapper.md` §6 already flags this as the exact crash Phase 5 would resurrect if it didn't ("미래의 launchd/cron 호출자가 `WorkingDirectory` 를 명시하지 않으면 이 크래시가 되살아난다").

All three use `KeepAlive` as a **bare boolean**, never the dict form (`{SuccessfulExit:..., Crashed:...}`) — no precedent exists in this project for the dict form. `ThrottleInterval` ranges 10 (role-shim, litellm) to 60 (flashnext, the heaviest process). Recommend 30-60s for both new services given they, too, are not trivially fast to fail/recover.

### `kanban --help` (live, installed 0.1.70, confirmed 2026-08-30 — cost: one `--help` + one `--version` invocation of `kanban` only, zero `cline` invocations)

```
Usage: kanban [options] [command]

Local orchestration board for coding agents.

Options:
  -v, --version            Output the version number
  --host <ip>              Host IP to bind the server to (default: 127.0.0.1).
  --port <number|auto>     Runtime port (1-65535) or auto.
  --no-open                Do not open browser automatically.
  --skip-shutdown-cleanup  Do not move sessions to done or delete task worktrees
                           on shutdown.
  --https                  Enable HTTPS. Requires both --cert and --key.
  --cert <path>            Path to a TLS certificate PEM file (implies HTTPS).
  --key <path>             Path to a TLS private key PEM file (implies HTTPS).
  --update                 Update Kanban to the latest published version and exit.
  --no-passcode             Disable auto-generated passcode for remote access
                            (for advanced users behind a reverse proxy).
  -h, --help               display help for command

Commands:
  task|tasks               Manage Kanban board tasks from the CLI.
  hooks                    Runtime hook helpers for agent integrations.
  mcp                      Deprecated compatibility command.
  update                   Update Kanban to the latest published version.

Runtime URL: http://127.0.0.1:3484
```

Notable: kanban **auto-generates a passcode for remote access by default** (`--no-passcode` disables it) — this is a built-in mechanism directly relevant to Phase 6's NET-02 (LAN token gating). Recommendation for Phase 5: do **not** pass `--no-passcode` — leave the default (passcode-protected) behavior in place even though it's moot on loopback-only right now, both as defense-in-depth and because Phase 6 will likely want to build on it rather than around it.

Recommended `ProgramArguments` payload (inside the wrapper, after `run_sandboxed.sh --`): `"$KANBAN_BIN" --no-open --host 127.0.0.1 --port 3484`. `--skip-shutdown-cleanup` is deliberately omitted (default: on `bootout`, kanban moves sessions to done and deletes task worktrees on shutdown — acceptable and arguably desirable default for a service that gets stopped/started repeatedly during testing, since Phase 5 doesn't create real tasks anyway).

### `cline connect telegram` option surface (via `strings` on installed 3.0.53 `.cline` binary — no live invocation)

```
Usage: -k <TELEGRAM_BOT_TOKEN> [options]
  -m, --bot-username <name>   Telegram bot username; fetched from token if omitted
  -k, --bot-token <token>     Telegram bot token                              [REQUIRED — throws if absent]
  --provider <id>             Provider override
  --model <id>                Model override
  --api-key <key>              Provider API key override
  --system <prompt>           System prompt override
  --cwd <path>                Workspace / cwd for runtime
  --mode <act|plan>           Agent mode (default: "act")
  -i, --interactive           Keep connector in foreground              [REQUIRED under launchd]
  --no-tools                  Disable tools for Telegram sessions       [recommended, see Pitfall 7]
  --enable-tools               Enable tools (default)
  --allowed-user-id <id>      Only allow this Telegram user ID to use the bot  [digits only; NOT required to start — see Open Questions]
  --hook-command <command>    Run a shell command for connector events   [mutually exclusive with --allowed-user-id]
  --rpc-address <host:port>   RPC address (env CLINE_RPC_ADDRESS or internal default)
```

Recommended real (token-present) invocation shape, for the wrapper to construct once a token is injected: `"$CLINE_BIN" connect telegram -k "$TELEGRAM_BOT_TOKEN" -i --no-tools --provider openai-compatible --model flashnext --cwd "$SANDBOX_WORKDIR"`. Env `CLINE_NO_AUTO_UPDATE=1` must still be set (this is still the `cline` binary).

> **CORRECTION (2026-08-30, plan-check).** An earlier revision of this line read `-P openai-compatible -m flashnext`, copied by analogy from `CLINE_COMMON_FLAGS` in `phase-01/config/cline-invocation.env` — which belongs to the **one-shot `cline <prompt>` surface**, where `-P`/`-m` are genuinely valid. On `cline connect telegram` they are not: verified live that there is **no `-P` short flag at all** (`cline connect telegram -P foobar` → `error: unknown option '-P'`, exit 1, thrown before the `-k` token check is even reached), and **`-m` is bound to `--bot-username`, not `--model`**. The transcribed option table ~20 lines above is authoritative and always was — it lists `--provider <id>` and `--model <id>` with no short aliases. Use the long forms. This mattered: with the short forms, the connector would have hard-failed at argv parsing on the very first launch after a real token was injected, and crash-looped every `ThrottleInterval`.

## State of the Art

Not applicable in the "libraries move fast" sense — this is entirely a snapshot of two specific pinned binaries on one machine at one point in time. The one thing worth flagging as time-sensitive: everything derived from `strings` on the compiled `.cline`/`kanban` binaries is **only valid for exactly these pinned versions** (3.0.53 / 0.1.70), same caveat `docs/cline-config-pins.md` §5 already states for the compaction-trigger constants. If either version drifts, re-derive the flag surface before trusting this document's Code Examples section again.

## Open Questions

1. **Does the real "flashnext down" scenario actually crash kanban's process, or only fail individual in-flight task turns?**
   - What we know: kanban's own web server binds its port and serves the UI independent of any LLM provider call (confirmed: `getUserDataDir`/git-detection/server startup have no synchronous dependency on `:4000` in the code paths inspected); kanban's HTTP-client layer has an explicit `isRetryable` classifier that includes `ECONNREFUSED`/`ETIMEDOUT`/`ECONNRESET`, strongly suggesting graceful retry rather than process death for provider-connectivity failures.
   - What's unclear: this is architectural inference from static analysis, not a live-observed fact. The actual "start kanban/telegram while flashnext is down, then bring flashnext up" sequence (ROADMAP Success Criterion 3) has not been executed.
   - Recommendation: the cheap, decisive test the research focus asked for — do **not** take down the live flashnext service to test this. Instead, point a throwaway instance at a dead port: run `kanban` (or `cline connect telegram -i`) with an isolated `--data-dir`/`--config` (or a temporary `providers.json` override) whose `flashnext` `baseURL` points at a guaranteed-refused port (e.g. `http://127.0.0.1:1`), start it, and confirm (a) the service process itself stays alive and its own port/state stays "running", and (b) only a real task/message attempt surfaces a retryable error rather than killing the process. This isolates the flashnext-down behavior from the pinned-`~/.cline`-config risk (real `cline` invocations against the isolated dir do NOT wipe the real `providers.json`, since `--config`/`--data-dir` are exactly the isolation flags Phase 1 documented and deliberately avoided for its own regression testing — here, deliberately using them is correct, since drift-safety of the real config, not "does real config apply," is what's being tested).

2. **What local port/mechanism does the "cline host" RPC layer that both kanban and `cline connect telegram` depend on actually use, and can the two services run simultaneously without a port clash?**
   - What we know: both surfaces resolve an `rpcAddress`/`authToken` pair via a shared internal layer (minified names collide across the bundle, making static tracing unreliable) before doing any real work; `--rpc-address <host:port>` is overridable via `CLINE_RPC_ADDRESS` for the telegram connector.
   - What's unclear: whether kanban and the telegram connector, run at the same time on the same machine, each spin up their own independent local RPC host (no conflict) or expect to share/discover one (potential port race or connection-refused loop between the two new services themselves, not just against flashnext).
   - Recommendation: empirically verify during planning/execution — bring both services up together (with an empty telegram token so no real bot activity occurs) and confirm via `lsof`/`launchctl print` that neither interferes with the other's port or process. This is a cheap, purely-local check (no flashnext or Telegram API involvement) and should be one of the plan's verification steps regardless of the theoretical answer.

3. **Should `workspace/scratch-repo` become a real git repo (`git init`) for Phase 5, or is the git-root scope mismatch (Pitfall 6) acceptable to defer?**
   - What we know: no task is created/started in this phase, so the mismatch has no observable effect on any SVC criterion.
   - What's unclear: whether the planner wants kanban's board to be minimally *usable* by the end of Phase 5 (beyond just "the process is running"), which would make this worth fixing now rather than later.
   - Recommendation: defer unless the planner decides otherwise; note it so it doesn't get rediscovered from scratch in a later phase.

4. **`--allowed-user-id` is optional today, not required — Phase 6 Success Criterion 4 wants the connector to fail immediately without it.**
   - What we know: confirmed via `strings` — the only enforcement found is mutual exclusivity with `--hook-command`, and a digits-only format check when the flag *is* given. Nothing in the parsed-options path throws when `--allowed-user-id` is simply absent.
   - What's unclear: whether a newer cline version changes this, or whether Phase 6 is expected to add wrapper-level enforcement (check the flag was passed before exec'ing) rather than relying on the CLI itself to refuse.
   - Recommendation: not Phase 5's problem to solve (token stays empty this phase, so the connector never really starts), but flag it now for Phase 6's own research/planning rather than let it be "discovered" live — this document is the natural place to record it since it came directly out of the same `strings` pass.

## Sources

### Primary (HIGH confidence)

- `~/Library/LaunchAgents/com.ohama.{flashnext,litellm,role-shim}.plist` — read directly, verbatim quoted above
- `phase-02/infra/restart_service.sh`, `verify_no_regression.sh`, `config.env` — read directly
- `phase-03/sandbox/run_sandboxed.sh`, `config.env`, `workspace/ALLOWED_REPOS.json` — read directly
- `phase-04/run_headless.sh`, `config.env` — read directly
- `docs/infra-hardening.md`, `docs/headless-wrapper.md`, `docs/cline-config-pins.md` — read directly, quoted where load-bearing
- `phase-01/config/cline-invocation.env`, `check_versions.sh` — read directly, quoted where load-bearing
- `~/local-llm-settings/sync.sh` — read directly, quoted where load-bearing
- `/opt/homebrew/lib/node_modules/kanban/{package.json,README.md,man/kanban.1,dist/cli.js}` — read/`strings`'d directly
- `/opt/homebrew/lib/node_modules/cline/{package.json,bin/.cline}` — `strings`'d only (no execution)
- Live invocations actually performed for this research: `kanban --version`, `kanban --help` (both exit 0, both read-only, no config touched). **Zero `cline` invocations were made** — all `cline`/`connect telegram` flag and behavior claims come from `strings` on the installed binary plus corroboration from `docs/cline-config-pins.md`/`docs/headless-wrapper.md`, which document prior live `cline --help` output from Phase 1/4.
- `~/.cline/kanban/` directory listing (`ls`, no kanban invocation) — confirms kanban's real state location

### Secondary (MEDIUM confidence)

- Behavioral inference about flashnext-down resilience (Open Question 1) — derived from reading kanban's retry-classifier code (`isRetryable` including `ECONNREFUSED`) and the absence of any startup-blocking provider healthcheck in the strings dump, not from a live "flashnext actually down" observation.

### Tertiary (LOW confidence)

- The exact default local RPC port/address shared between kanban and the telegram connector (Open Question 2) — minified-name collisions in the bundle made this untraceable via `strings` alone within this research's time budget; flagged for empirical verification during planning/execution instead.

## Metadata

**Confidence breakdown:**
- Standard stack / binary locations / versions: HIGH — read directly off disk and confirmed live (`--version`)
- Plist house style: HIGH — three real, currently-loaded plists read verbatim
- CLI flag surface (kanban): HIGH — confirmed via live `--help` on the actual installed pinned version
- CLI flag surface (`cline connect telegram`): HIGH for flags/error strings (direct `strings` match, exact quoted throw messages), MEDIUM for exact runtime sequencing (control flow reconstructed from minified code, not executed)
- SVC-04 (flashnext-down resilience) runtime behavior: MEDIUM — architecturally well-supported inference, not live-verified; a cheap decisive test is specified above but was not run as part of this research (would require setting up an isolated config, judged out of scope for research vs. planning/execution)
- SVC-05 (`sync.sh`) mechanics: HIGH — read directly, the hardcoded-array gap is a plain reading of the file
- Pitfalls 1-4 (self-daemonize, KANBAN_NO_AUTO_UPDATE gap, sync.sh array, empty-token crash loop): HIGH — each is either a direct quoted throw/behavior in the binary or a direct reading of an existing script
- Pitfall 7 (`--auto-approve false` doesn't apply to `connect telegram`): HIGH — confirmed absence of the flag in the extracted option list, corroborated independently by `docs/headless-wrapper.md` §4 which names this exact gap

**Research date:** 2026-08-30
**Valid until:** Re-verify if `cline` or `kanban`'s pinned version changes (all `strings`-derived flag/behavior claims are version-specific, per `docs/cline-config-pins.md` §5's own precedent); otherwise treat as valid for the life of this milestone (no fast-moving external dependency involved).
