# Phase 4: 헤드리스 CLI 래퍼 - Research

**Researched:** 2026-08-30
**Domain:** Wrapping a Bun-compiled CLI agent (`cline` 3.0.53) for one-shot headless execution under a macOS Seatbelt sandbox (Phase 3's `run_sandboxed.sh`)
**Confidence:** HIGH — every load-bearing claim below was reproduced live on this machine during this research session (not inferred from docs), with before/after config-drift healing and a final clean `git status` / `verify_sandbox.sh` 16/16 PASS.

## Summary

This phase inherited one real blocker from Phase 3: the actual `cline` binary crashed with a
generic, path-less Bun runtime error (`error: An unknown error occurred (Unexpected)`) when run
under `run_sandboxed.sh`, and Phase 3 explicitly declined to guess a fix. This research resolves
that blocker completely, with live evidence, and the fix requires **zero changes to Phase 3's
sandbox artifacts** — no `EXTRA_ALLOW_PATHS` widening, no `gen_sandbox_profile.py` edit, no human
sign-off needed. **The root cause is the wrapper's own process working directory, not a missing
punch-through.** `sandbox-exec` denies `file-read-metadata`/`file-read-data` on any path that is
under `$HOME` but not inside a whitelisted subpath — and when the wrapper is invoked with its OS
process `cwd` outside the whitelist (e.g. the repo root), Node/Bun's own startup machinery (path
resolution of `process.cwd()`, ancestor-directory `stat()` calls, and file-existence probes for
config files like `.npmrc`) hits that deny and Bun surfaces it as its generic catch-all error
before a single line of `cline`'s own code runs. **Fix: always launch the sandboxed `cline`
process with its OS-level working directory set to a path already inside `ALLOWED_REPOS.json`**
(`workspace/scratch-repo` is the existing candidate) — this alone, with the completely unmodified
profile `run_sandboxed.sh` already generates, produces a clean `cline --version` → `3.0.53`, exit
0. Bisection (fully-permissive-read vs fully-permissive-write control profiles) confirmed the
failure is a **read** issue, and further isolation confirmed it is specifically resolved by fixing
the process's cwd — no metadata-only allow rule, and none of Phase 3's four pre-declared
`EXTRA_ALLOW_PATHS` candidates (`~/.npm`, `~/.cache`, `~/.config/cline`,
`~/Library/Caches/cline`), were needed once cwd was correct.

A second, more consequential finding surfaced while verifying criterion 3 empirically: **`cline
--auto-approve false` in `--json` (no-TTY) headless mode does not pause for approval — it
immediately and unconditionally rejects every single tool call** with
`{"error":"Tool \"<name>\" requires approval in a TTY session"}`, before the call ever reaches the
OS/sandbox layer. This was reproduced live. It means a wrapper that hard-codes
`--auto-approve false` (as HLS-02 requires) **cannot get any real agentic work done** — every task
will burn iterations failing every tool call and self-abort. It also means **criterion 3, if
tested through the literal `--auto-approve false` wrapper, would trivially "pass" for the wrong
reason** (Cline's own TTY gate, not Phase 3's sandbox, is what blocks the attempt) — exactly the
false-positive risk the phase brief warned about, just one layer higher than expected. The
resolution, directly supported by Phase 3's own documented interface contract (its example
invocation in `docs/sandbox-whitelist.md` §5 literally uses `--auto-approve true`), is to treat
"prove the sandbox works" and "ship the default-safe wrapper" as two different invocations: the
shipped wrapper always carries `--auto-approve false` (satisfies HLS-02, grep-able, safe by
default — a task that needs tool use will visibly self-abort rather than silently do nothing,
which is itself informative NDJSON output for HLS-01), while criterion 3's proof uses a clearly
labeled, non-default, `--auto-approve true` test invocation — mirroring how Phase 3 itself proved
kernel-level denial with unwrapped `/bin/cat`/`node` rather than through Cline's own approval
layer. This research includes live, reproduced, unambiguous NDJSON evidence for exactly this test:
a real sandboxed `cline` run whose `read_files` tool call returned
`"error":"Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'"`,
`"success":false`, and whose `run_result.finishReason` was `"completed"` (not aborted/crashed) —
this is the exact, positive, decisive signal for criterion 3.

**Primary recommendation:** Build the wrapper as a thin script that (a) always `cd`s into (or is
invoked with cwd already set to) an `ALLOWED_REPOS.json`-listed directory before calling
`phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" ... --json --auto-approve false ...`, matching
the literal invocation contract Phase 3 already documents; (b) classifies the NDJSON stream using
the same nested-`error.message` tolerance Phase 1's `parse_result.py` already had to add, plus a
new check for the sandbox-denial signature (`"success":false` + `EPERM`/`Operation not permitted`
in a tool `output`/`error` field) and the 32K terminal-failure signature (`MAX_KV_SIZE` in the
error message, per `docs/32k-compaction-policy.md`); and (c) ships a **separate**,
clearly-labeled, non-default verification invocation (`--auto-approve true`, out-of-sandbox
prompt) as the actual proof artifact for criterion 3, since the shipped `--auto-approve false`
default cannot exercise that code path at all.

## Standard Stack

Not applicable in the conventional "libraries" sense — this phase wraps a single fixed vendor
binary. The load-bearing pieces are Phase 1's and Phase 3's own already-built artifacts:

| Component | Version/Path | Purpose | Why it's the only option |
|---|---|---|---|
| `cline` | `3.0.53`, pinned at `/opt/homebrew/bin/cline` | The agent being wrapped | Pinned project-wide; every decompiled constant/NDJSON shape this project relies on is version-specific |
| `phase-03/sandbox/run_sandboxed.sh` | as-is | The sanctioned sandbox entry point | Documented interface contract (`docs/sandbox-whitelist.md` §5); `exec`s `sandbox-exec` so exit code/stderr pass through untouched |
| `phase-01/config/cline-invocation.env` | as-is | Canonical flags (`CLINE_COMMON_FLAGS`, `CLINE_BIN`, etc.) | Single source of truth for provider/model/compaction pins; Phase 5 plists source the same file |
| `workspace/scratch-repo` | existing `ALLOWED_REPOS.json` entry | Default sandboxed working directory | Already documented in Phase 3's interface contract as "usable as the default working directory" — this research found it is now *load-bearing*, not just convenient (see Pitfall 1) |
| `phase-01/parse_result.py` | as-is (reference implementation) | NDJSON classifier pattern to imitate | Already solved the flat-vs-nested `error.message` shape problem the wrapper's classifier will hit again |

No new third-party dependency needs to be installed. The wrapper itself should be a plain bash
script (matching the house style of `run_regression.sh` / `run_sandboxed.sh`) or a small Python
script if NDJSON post-processing logic gets non-trivial — either is consistent with existing
phase-01/phase-03 conventions; there is no framework recommendation to make here.

## Architecture Patterns

### Recommended invocation shape

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$REPO_ROOT/phase-01/config/cline-invocation.env"; set +a

# HLS-03: must run only inside the sandbox.
RUN_SANDBOXED="$REPO_ROOT/phase-03/sandbox/run_sandboxed.sh"

# Pitfall 1 (this research): the sandboxed process's OS-level cwd must
# already be inside ALLOWED_REPOS.json, or Bun's own startup crashes with a
# generic, path-less error before cline's code ever runs. -c/--cwd (cline's
# own "agent working directory" flag) is a SEPARATE, ADDITIONAL thing and
# does not substitute for this — set both to the same allowed path.
WORKDIR="$REPO_ROOT/workspace/scratch-repo"   # or whichever repo the task targets

# HLS-02: --auto-approve false is HARD-CODED here, never left to the CLI's
# own default of true (grep-able per ROADMAP criterion 2).
cd "$WORKDIR" && "$RUN_SANDBOXED" -- "$CLINE_BIN" $CLINE_COMMON_FLAGS \
  --json --auto-approve false -t "${WRAPPER_TIMEOUT:-1800}" -c "$WORKDIR" \
  "$PROMPT" > "$OUT_NDJSON" 2> "$OUT_STDERR"
```

### Pattern: classify, don't just relay, the NDJSON stream

Do not treat "wrapper produced NDJSON, exit code whatever" as the whole of HLS-01. Distinguish, in
order of how they actually appear on the wire (all reproduced live this session):

1. **Real task completion** — `run_result.finishReason == "completed"`, no tool `output.success ==
   false` entries with `EPERM`/`Operation not permitted`. Ordinary success.
2. **Sandbox denial (criterion 3's positive signal)** — some tool's `content_end.output` contains
   `"success":false` and an `error`/`result.stderr` string containing `EPERM` or
   `Operation not permitted`. `run_result.finishReason` is typically still `"completed"` (Cline
   itself handles the tool failure gracefully and reports it in prose) — **do not use
   `finishReason` alone to detect this case.**
3. **32K terminal failure (`docs/32k-compaction-policy.md` policy)** — an `agent_event` of
   `{"type":"error", ...}` whose message (see extraction note below) contains `MAX_KV_SIZE`, paired
   with `run_result.finishReason == "error"`. Classify as **terminal, not retryable**: restart the
   task, do not wait/retry in place.
4. **Auto-approve-false self-abort** — every tool call's `content_end.output.error` (or nested
   `output` array entries) reads `Tool "<name>" requires approval in a TTY session`, ending in
   `run_result.finishReason == "aborted"` and a top-level `{"type":"run_aborted","reason":
   "external_abort",...}` event. This is the **expected, correct** behavior of the shipped wrapper
   whenever the prompt needs any tool use — it is not a bug, but the wrapper's classifier should
   label it distinctly from (1)-(3) so operators don't mistake "cline correctly refused to act
   unattended" for "the run crashed."
5. **Crash** — exit code >128 (signal death, e.g. 134/SIGABRT) with sparse/no NDJSON. Not a
   denial; classify separately (same discriminator Phase 3's `assert_denied.sh` already uses).

### Anti-Pattern: relying on `run_result.finishReason` alone to detect sandbox denial

`finishReason` is `"completed"` in the exact same shape whether the agent's tools all succeeded or
some failed with EPERM and the model reported the failure in text. The denial signal lives in the
per-tool `content_end` events' `output`, not in the top-level `run_result`. A classifier that only
checks `finishReason` will silently treat a denied out-of-sandbox attempt as an ordinary success.

### Anti-Pattern: assuming `--auto-approve false` alone yields a "safe but functional" headless agent

It does not — it yields a wrapper that cannot use any tool at all, headless. If the phase's intent
is a wrapper that both (a) never silently auto-approves in production and (b) can still be proven
to respect the sandbox, these must be two different invocations (see Pitfall 2 below), not one.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Config/version drift guards | A new pre-flight check | `phase-01/config/verify_config.sh`, `phase-01/config/check_versions.sh`, `phase-01/config/apply_provider_config.sh` | Already handle the exact `providers.json` `models[]`-stripping drift this research re-triggered twice; re-implementing would just re-discover the same bug |
| Sandbox profile generation/enforcement | Any custom `sandbox-exec` invocation | `phase-03/sandbox/run_sandboxed.sh` exactly as documented | It's the sanctioned interface; hand-rolling a parallel wrapping path is exactly the "wrapper that appears sandboxed but isn't" risk the phase brief warns about |
| NDJSON parsing / nested error extraction | A naive `event.message` read | The pattern in `phase-01/parse_result.py`'s `_error_event_message()` | Already discovered and fixed the flat-vs-nested (`event.error.message`) shape bug live; the wrapper will hit the same nested shape (confirmed again this session) |
| Standing verification of the sandbox before trusting it | An ad-hoc smoke check | `phase-03/sandbox/verify_sandbox.sh` | 0/1/2 exit contract already defined; documented as required before Phase 4/5/6/7 trust `run_sandboxed.sh` |

**Key insight:** every piece of infrastructure this phase needs (config guard, version guard,
sandbox generation/enforcement, standing verification) was already built and verified by Phase 1
and Phase 3. This phase's actual new work is genuinely small: the wrapper script itself, its
NDJSON classifier, and the criterion-3 test artifact.

## Common Pitfalls

### Pitfall 1: Sandboxed `cline` crashes with a generic Bun error unless the process's OS-level cwd is inside the whitelist — THE INHERITED BLOCKER, NOW SOLVED

**What goes wrong:** `phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" --version`, run from the
repo root (or anywhere under `$HOME` outside `ALLOWED_REPOS.json`), fails:
```
resolved allow list: ['/Users/ohama/projs/cline-tests/workspace/scratch-repo', '/Users/ohama/.cline']
error: An unknown error occurred (Unexpected)
```
exit 1, no stdout, no path/errno named — exactly Phase 3's documented open item.

**Root cause, confirmed live via `log stream --predicate 'eventMessage CONTAINS "deny"'`
correlated with the sandboxed invocation:**
```
kernel[...] (Sandbox) 3 duplicate reports for Sandbox: node(...) deny(1) file-read-metadata /Users/ohama
```
`node` here is `cline`'s own `#!/usr/bin/env node` launcher script, denied `file-read-metadata`
(a `stat()`-class check) on `/Users/ohama` itself — an **ancestor** of the whitelisted
`~/.cline` and `~/projs/cline-tests/workspace/scratch-repo` paths, but not itself inside any
`(allow ... (subpath ...))` rule. SBPL's `subpath` allow only covers the target and its
descendants, never its ancestors — so any operation that needs to `stat()`/`realpath()`/`getcwd()`
its way *up* to an allowed path (which Node/Bun's startup does routinely: resolving
`process.cwd()`, checking for `.npmrc`/config files by walking upward from cwd, resolving
`~/.cline`) hits the `(deny file-read* (subpath "$HOME"))` rule the moment it touches `$HOME`
itself or any other un-punched-through ancestor.

**Decisive isolation test (reproduced twice, byte-identical unmodified profile both times):**
```
# from repo root (NOT in ALLOWED_REPOS.json):
$ sandbox-exec -f <unmodified generated profile> -- "$CLINE_BIN" --version
error: An unknown error occurred (Unexpected)      # exit 1

# from workspace/scratch-repo (IS in ALLOWED_REPOS.json), same unmodified profile:
$ sandbox-exec -f <same profile> -- "$CLINE_BIN" --version
3.0.53                                             # exit 0
```
A read/write bisection (temporarily granting full `file-write*` under `$HOME` vs. full
`file-read*` under `$HOME`, one at a time, cwd still at repo root) confirmed it is specifically a
**read** dependency, not a write dependency. None of Phase 3's four pre-declared
`EXTRA_ALLOW_PATHS` candidates (`~/.npm`, `~/.cache`, `~/.config/cline`,
`~/Library/Caches/cline`) fixed it in isolation or combined — the missing read access is the cwd
chain itself, not any specific Cline/npm cache directory.

**How to avoid:** the wrapper must set the OS-level process working directory (via a real `cd`
before invoking `run_sandboxed.sh`, not merely `cline`'s own `-c/--cwd` flag) to a path already
listed in `ALLOWED_REPOS.json` — `workspace/scratch-repo` is the existing, already-documented
candidate. **No change to `phase-03/sandbox/config.env`, `EXTRA_ALLOW_PATHS`, or
`gen_sandbox_profile.py` is needed or recommended.** This is a pure invocation-hygiene fix with
zero security-boundary impact — confidently the cheapest and most correct resolution available.

**Warning sign this regresses:** if a future wrapper invocation is ever launched from a script
whose own cwd is outside the whitelist (e.g. a launchd plist with no explicit
`WorkingDirectory`, or a cron/systemd-style invocation that inherits some other cwd), this exact
crash will reappear and will look, superficially, identical to a real sandbox tightening. Add an
explicit assertion at the top of the wrapper (`[[ "$PWD" == "$WORKDIR" ]] || cd "$WORKDIR"`) rather
than trusting the caller's cwd.

**Confidence: HIGH.** Reproduced deterministically multiple times this session with the exact
unmodified artifact `run_sandboxed.sh` generates; isolated via a clean bisection; verified the
fix requires no security-relevant file changes (`git status` clean, `EXTRA_ALLOW_PATHS` untouched,
`verify_sandbox.sh` still 16/16 PASS afterward).

### Pitfall 2: `--auto-approve false` in `--json`/headless mode rejects every tool call outright — it does not pause, wait, or hang

**What goes wrong:** Live reproduction, `cline -P openai-compatible -m flashnext --compaction
agentic --json --auto-approve false -t 90 -c <sandboxed-workdir> "Read the file at ~/.zshrc..."`
(sandboxed, correct cwd per Pitfall 1) produces, immediately after the first model response
proposes a tool call:
```json
{"type":"content_end","contentType":"tool","toolName":"read_files","toolCallId":"...",
 "output":{"error":"Tool \"read_files\" requires approval in a TTY session"},
 "error":"{\"error\":\"Tool \\\"read_files\\\" requires approval in a TTY session\"}","durationMs":0}
```
The model retries with a different tool (`run_commands`, then `read_files` again), each rejected
identically, and after 3 iterations the run self-terminates:
```json
{"type":"done","reason":"aborted", ...}
{"type":"run_aborted","reason":"external_abort","message":"aborted by another client"}
```
`run_result.finishReason: "aborted"`. Total wall time ~31s (well within the `-t 90` budget — it
does **not** hang waiting for approval; it fails fast).

**Why it happens:** cline 3.0.53's top-level CLI (`cline <prompt>`) has no per-tool or
programmatic approval mechanism — the full confirmed flag surface (`docs/cline-config-pins.md`,
captured from `cline --help` on this exact binary) is: `-c/--cwd`, `--compaction`,
`--auto-approve <boolean>`, `-m/--model`, `-P/--provider`, `-t/--timeout`, `--id`, `--config`,
`--data-dir`. There is **no** granular allow/deny flag at this level. `--hook-command` — which
*does* accept a JSON-in/JSON-out approval contract (`{"action":"allow"}`/`{"action":"deny",
"message":...}`) — exists only on `cline connect <channel>` (the Telegram/Discord connector
subcommands), confirmed absent from the top-level `cline --help` output; it cannot be combined
with the one-shot headless prompt mode this phase wraps.

**Consequence for the phase:** a wrapper that (correctly, per HLS-02) hard-codes
`--auto-approve false` cannot complete any task requiring tool use. This is not a defect in the
wrapper — it is what the requirement, taken literally, produces. **Do not read this as "the
wrapper is broken" during planning/verification; read it as "the shipped default is intentionally
inert for tool-using tasks," and design criterion 1 (HLS-01, "NDJSON is returned") to accept the
`aborted`/tool-rejected NDJSON stream as valid, non-crash output** — it is real NDJSON, it is a
real one-shot run, and it correctly reflects the safety posture HLS-02 asks for. If a prompt needs
zero tool calls (e.g. "say hello"), it still completes normally under `--auto-approve false`.

**How to avoid conflating this with criterion 3:** because every tool call is rejected identically
regardless of whether its target is inside or outside the sandbox, a criterion-3 test run under
the shipped `--auto-approve false` default would "pass" (the file access never happens) for a
reason that has nothing to do with Phase 3's sandbox — it would prove the TTY gate, not the
Seatbelt profile. See "How to test criterion 3" below for the resolution.

**Confidence: HIGH.** Live-reproduced with full NDJSON capture; cross-checked against
`.planning/research/PITFALLS.md` §5 and `STACK.md` §5-6, which independently documented (via
`cline --help` and source inspection, not live testing) that direct-CLI auto-approve defaults to
`true` and that connectors are the only surface with `--hook-command`; this session's live test is
the first confirmation of what actually happens when `false` is passed with no TTY.

### Pitfall 3: HLS-02 and criterion 3 must be satisfied by *different* invocations, not one

Direct consequence of Pitfall 2. **How to test criterion 3 decisively and cheaply:**

1. Do **not** attempt to prove criterion 3 through the shipped `--auto-approve false` wrapper —
   it structurally cannot reach the sandbox layer for any tool call.
2. Use a **separate, explicitly non-default, clearly-labeled** test invocation with
   `--auto-approve true` (exactly the form Phase 3's own interface-contract doc already shows as
   its worked example — `docs/sandbox-whitelist.md` §5: `run_sandboxed.sh -- cline --auto-approve
   true ...`), a prompt naming a path outside `ALLOWED_REPOS.json` (e.g. `$HOME/.zshrc`), and the
   cwd fix from Pitfall 1.
3. Live evidence of exactly this, reproduced this session (`-t 90`, ~39s wall time, one real model
   round trip plus two tool-call turns):
   ```json
   {"type":"content_end","contentType":"tool","toolName":"read_files",
    "output":[{"query":"/Users/ohama/.zshrc:1-2","result":"",
               "error":"Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'",
               "success":false}]}
   ...
   {"type":"content_end","contentType":"tool","toolName":"run_commands",
    "output":[{"query":"head -n 2 /Users/ohama/.zshrc",
               "result":"[Command exited with code 1]\n\n[stderr]\nhead: /Users/ohama/.zshrc: Operation not permitted\n",
               "error":"Command exited with code 1","success":false}]}
   ...
   {"type":"run_result","finishReason":"completed", ...}
   ```
   The model's own final text even correctly self-diagnoses: *"My tools run sandboxed to the
   working directory... file access is denied at the OS/permission level."* This is the exact
   `EPERM`/`Operation not permitted` signature Phase 3's `assert_denied.sh` already treats as the
   only valid "DENIED" (as opposed to crashed/succeeded) signal — reusing that same discriminator
   in the wrapper's classifier keeps the two phases' notions of "denied" consistent.
4. **This one real invocation is sufficient and decisive** — it is a positive, unambiguous
   result, distinguishable from all three confounds the phase brief worried about:
   - **not** a crash (exit 0, full clean NDJSON, no signal death);
   - **not** the model "simply declining" (the model *did* attempt both `read_files` and a shell
     fallback; both were mechanically denied by the OS, and the model's own summary correctly
     attributes this to sandboxing rather than choosing not to try);
   - **not** the 32K terminal failure (a completely different error string —
     `litellm.BadRequestError`/`MAX_KV_SIZE`, not `EPERM` — and would show
     `finishReason:"error"`, not `"completed"`).
5. Cost: one real model round trip (~10-15s TTFT observed at short context here, well under the
   64s TTFT figure quoted for long-context runs — this prompt was short) plus one retry turn,
   total ~40s wall time, one `npm install -g cline@3.0.53` reinstall-chain, one
   `providers.json`-strip/heal cycle. Bounded and cheap relative to Phase 1's full regression runs.

**Recommendation for the plan:** ship this as a small, permanently-labeled verification script
(e.g. `phase-04/verify_sandbox_via_cline.sh`, analogous to `phase-03/sandbox/verify_sandbox.sh`),
never invoked by the production wrapper path, whose own header comment states plainly that it uses
`--auto-approve true` deliberately and why (testing the kernel boundary, not the approval gate) —
so a future reader never mistakes it for a security regression.

### Pitfall 4: Cline's own error-event NDJSON shape is nested, not flat — the classifier must handle both

**What goes wrong:** `phase-01/parse_result.py` was originally written assuming
`{"type":"error","message":"..."}` (flat) per its own `01-RESEARCH.md`-era prediction, but the
**actual, live-observed** shape from real cline 3.0.53 runs (both Phase 1's 32K regression and
this session's own two live NDJSON captures) is nested:
```json
{"type":"agent_event","event":{"type":"error","error":{"name":"Error","message":"...","stack":"..."},"errorClass":"unknown","recoverable":true,"iteration":N}}
```
The error text lives at `event.error.message`, not `event.message`. A classifier written against
the flat shape silently falls through to "unrecognized"/"other" on every real error — exactly the
outcome-② (32K terminal failure) case a wrapper most needs to catch correctly per
`docs/32k-compaction-policy.md`.

**How to avoid:** copy `phase-01/parse_result.py`'s `_error_event_message()` pattern (check flat
`event.get("message")` first, fall back to `event.get("error", {}).get("message")`) rather than
re-deriving it. This session's own two live captures both used the nested shape, confirming it is
still current in 3.0.53 (not a one-off).

### Pitfall 5: Reusing `verify_sandbox.sh`'s crash-vs-denial discriminator, not exit code alone

Phase 3's entire justification for the `(allow default)`+deny-`$HOME` design (rather than `(deny
default)`) is that a naive "non-zero exit = blocked" test conflates a SIGABRT crash (dyld/Node
bootstrap failure, exit 134, no diagnostic) with an actual kernel denial (exit 1, `EPERM`/
`Operation not permitted` in stderr or a tool's output). This project's discriminator — used by
`assert_denied.sh` and now confirmed to also appear cleanly in real cline NDJSON tool output — is:
**only an explicit `EPERM`/`Operation not permitted` string counts as DENIED; any signal death
(exit > 128) is a crash, not a denial, and must not be reported as a successful block.** The
wrapper's own classifier (and any Phase 4 verification script) must apply the same rule, not just
check `exit != 0`.

### Pitfall 6: Config/version drift from every real `cline` invocation

Every real invocation of `cline` in this research session (whether `--version`, or a full task run)
was followed by checking `phase-01/config/verify_config.sh` — it failed (`models[]` stripped) after
the two full task-run invocations (not after plain `--version` calls, which is a new, useful
observation: `--version` alone appears not to touch `providers.json`, only real task execution or
`cline config` subcommands do). `phase-01/config/apply_provider_config.sh` heals it idempotently.
**Any Phase 4 plan that runs real `cline` invocations (for the wrapper's own tests, or for the
criterion-3 verification script) must budget a `verify_config.sh` → heal → re-verify cycle
around them**, exactly as Phase 1's `run_regression.sh` already does, and must re-pin the version
(`npm install -g cline@3.0.53`) immediately before each invocation in the same shell command,
since `CLINE_NO_AUTO_UPDATE=1` alone does not reliably prevent background self-update (documented
Phase 1 finding, not newly discovered, but reconfirmed live: `check_versions.sh` still reported no
drift this session, consistent with the reinstall-then-launch chaining pattern working as
designed).

### Pitfall 7: `log show` (historical) does not surface sandbox denials on this host; `log stream` (live) does, cleanly, with real (non-`<private>`) paths

Phase 3's own smoke test tried `log show --last 10m --predicate 'eventMessage contains "deny("'`
after the fact and got nothing, concluding the diagnostic avenue was exhausted without `sudo`.
**This research found the correct technique: start `log stream` (not `log show`) *before*
triggering the sandboxed invocation, and correlate live.** This surfaced the exact denied path and
operation (`node(...) deny(1) file-read-metadata /Users/ohama`) with **no `<private>` redaction**
and **no elevated privileges** — contrary to the reasonable assumption that macOS's privacy
redaction would hide it. This is a reusable diagnostic technique for any future sandbox-denial
investigation in this project: `log stream --style compact --predicate 'eventMessage CONTAINS
"deny"' > logfile & sleep 2; <trigger the denial>; sleep 2; kill %1; grep deny logfile` — no sudo,
no `dtruss`/`fs_usage` needed. One caveat observed: the kernel appears to deduplicate/throttle
repeated identical `(process-image, operation, target)` denial tuples within a short window
(`"3 duplicate reports for ..."`), so a *second*, *different* denial in the same brief session may
not log a fresh line even though it is real — confirmed indirectly (a later, different EPERM
failure surfaced cleanly through cline's own NDJSON output with no corresponding fresh `log
stream` line). Don't treat "no log stream line" as proof "nothing was denied" once one denial has
already fired in the same window; corroborate with the process's own exit code/stderr/NDJSON too.

## Code Examples

### Verified NDJSON event schema (this session's live captures, cline 3.0.53)

Top-level event types seen: `hook_event`, `agent_event`, `run_result`, `run_aborted` (and
`run_start`, seen in `.planning/research/STACK.md`'s separately-captured example but not in this
session's captures — possibly conditional on some startup path; treat its presence as optional,
not guaranteed, in the classifier).

`agent_event.event.type` values observed across this session + Phase 1's stored results:
`iteration_start`, `iteration_end`, `usage`, `content_start`, `content_end`, `error`, `notice`
(compaction only, not seen live this session but present in `phase-01/tests/fixtures/
outcome1_compacted.ndjson`), `done`.

```json
// Successful tool call:
{"type":"agent_event","event":{"type":"content_end","contentType":"tool","toolName":"read_files",
 "toolCallId":"...","output":[{"query":"...","result":"<content>","success":true}]}}

// Sandbox-denied tool call (criterion 3's positive signal):
{"type":"agent_event","event":{"type":"content_end","contentType":"tool","toolName":"read_files",
 "output":[{"query":"/Users/ohama/.zshrc:1-2","result":"",
            "error":"Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'",
            "success":false}]}}

// TTY-approval-gate rejection (expected under the shipped --auto-approve false default):
{"type":"agent_event","event":{"type":"content_end","contentType":"tool","toolName":"read_files",
 "output":{"error":"Tool \"read_files\" requires approval in a TTY session"}}}

// 32K terminal failure (docs/32k-compaction-policy.md):
{"type":"agent_event","event":{"type":"error","error":{"name":"Error",
 "message":"litellm.BadRequestError: OpenAIException - Error code: 400 - {'detail': 'Request needs N context tokens (P prompt + M max generation), but MAX_KV_SIZE is 32768.'}..."}}}
// followed by: {"type":"run_result","finishReason":"error",...}
```

### Minimal reproducer for Pitfall 1 (cwd fix), verbatim commands used

```bash
set -a; . phase-01/config/cline-invocation.env; set +a
# FAILS (cwd = repo root, outside ALLOWED_REPOS.json):
phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" --version
# → exit 1, "error: An unknown error occurred (Unexpected)"

# WORKS (cwd = an ALLOWED_REPOS.json entry), same unmodified profile:
( cd workspace/scratch-repo && \
  /Users/ohama/projs/cline-tests/phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" --version )
# → exit 0, "3.0.53"
```

## State of the Art

| Old assumption (Phase 3 handoff) | Current finding | Impact |
|---|---|---|
| Bun startup failure needs an `EXTRA_ALLOW_PATHS` widening (candidate: `~/.npm`, `~/.cache`, `~/.config/cline`, `~/Library/Caches/cline`) | Needs zero sandbox-profile changes; needs a cwd fix in the wrapper only | Removes the "human sign-off to widen the boundary" blocker entirely — nothing to widen |
| `--auto-approve false` "just works" headless, only differing from `true` in whether tool calls execute silently | It rejects every tool call outright with no TTY; run self-aborts after repeated failures | Wrapper design must treat criterion-3 verification as a separate invocation from the shipped default |
| Criterion 3 can be tested through the same invocation the wrapper ships | Must use a separate `--auto-approve true` test invocation (matches Phase 3's own documented example) | Plan must include two invocation forms, not one, and document why |

**Deprecated/outdated:** none — this is all first observation of the actual runtime behavior, not
a change from a previously-documented state.

## Open Questions

1. **Why does the run self-abort (`reason: "external_abort", message: "aborted by another
   client"`) after repeated `--auto-approve false` tool-call rejections, rather than continuing
   until `--retries`/`-t` is exhausted?**
   - What we know: it happened at iteration 3 (2nd `read_files` rejection, 1st was iteration 1,
     `run_commands` rejection was iteration 2), well under the default `--retries 6` and the `-t
     90` timeout (actual wall time ~31s).
   - What's unclear: whether this is a hard-coded "N consecutive tool-approval failures aborts the
     task" rule distinct from `--retries` (which is documented as "max consecutive mistakes"), or
     some other internal threshold.
   - Recommendation: not blocking for Phase 4 — the wrapper's classifier should treat
     `run_aborted`/`finishReason:"aborted"` as its own distinct, expected-under-`--auto-approve
     false` outcome regardless of the exact trigger count; don't build logic that depends on a
     specific iteration count.

2. **Does `run_start` reliably appear as the first NDJSON event, or was its absence in this
   session's captures a fluke?**
   - What we know: `.planning/research/STACK.md`'s independently-captured example shows
     `run_start` as literally the first line; this session's two live captures both start with
     `hook_event`/`agent_start` instead, no `run_start` anywhere in either stream.
   - What's unclear: whether this is version drift, a flag-dependent difference (e.g. `-v` was
     used in STACK.md's capture but not here), or environment-dependent.
   - Recommendation: the wrapper's classifier should not assume `run_start` is present — key off
     `run_result` (always present, confirmed across every capture this session and in all of
     Phase 1's stored results) as the definitive end-of-stream/outcome record instead.

3. **Is there any way to get real agentic work done headlessly while still literally satisfying
   "`--auto-approve false`, not the CLI default"?**
   - What we know: no per-tool/programmatic approval flag exists on the top-level `cline <prompt>`
     command in 3.0.53; `--hook-command` exists only on `cline connect <channel>`.
   - What's unclear: whether a future cline version adds this, or whether there's an undocumented
     mechanism (e.g. feeding structured approval responses via stdin in `--json` mode) that this
     research didn't probe because it would have required guessing at an unconfirmed protocol.
   - Recommendation: treat the shipped wrapper as intentionally safe-but-inert for tool-using
     prompts this milestone (consistent with the phase's own stated scope: "서비스화는 이번
     마일스톤에서 하지 않는다" / not turned into a service this milestone) — this is a smoke test
     of Phase 1 + Phase 3 fitting together, not a production autonomous-agent runner. Revisit if a
     later milestone needs the wrapper to actually complete unattended tool-using tasks; the
     honest options at that point are (a) wait for/request an upstream cline feature, or (b) accept
     `--auto-approve true` for production use and rely on the sandbox as the sole safety boundary
     (a real, documented trade-off — flag it to the user explicitly if ever proposed, since it
     changes HLS-02's actual security posture).

## Sources

### Primary (HIGH confidence — reproduced live this session)

- `log stream` correlated with `phase-03/sandbox/run_sandboxed.sh` invocations — identified the
  exact `file-read-metadata` denial on `/Users/ohama` (Pitfall 1)
- Direct `sandbox-exec` bisection (base profile / read-only-widened / write-only-widened / cwd
  variants) — isolated the cwd root cause and ruled out all four pre-declared
  `EXTRA_ALLOW_PATHS` candidates
- Two full live `cline` invocations through `run_sandboxed.sh` with real NDJSON capture:
  one with `--auto-approve false` (Pitfall 2), one with `--auto-approve true` targeting an
  out-of-sandbox path (Pitfall 3 / criterion-3 evidence)
- `phase-01/config/verify_config.sh`, `check_versions.sh`, `apply_provider_config.sh`,
  `phase-03/sandbox/verify_sandbox.sh` — run before/after every real invocation this session to
  confirm no lasting drift or sandbox regression (final state: all PASS, `git status` clean)

### Secondary (HIGH confidence — read directly from this project's own prior, verified research)

- `docs/sandbox-whitelist.md` (Phase 3 deliverable, §5 interface contract, §7 the inherited
  blocker's original writeup)
- `phase-03/results/20260829T202633Z-cline-smoke/{verdict.txt,README.md}` — Phase 3's own
  unresolved smoke-test attempt
- `phase-03/sandbox/{run_sandboxed.sh,gen_sandbox_profile.py,config.env}` — read in full
- `phase-01/config/cline-invocation.env`, `docs/cline-config-pins.md` — confirmed CLI flag surface
  and defaults (`--auto-approve <boolean>` default `true`, full top-level flag list)
- `docs/32k-compaction-policy.md` — terminal-failure classification policy the wrapper must honor
- `phase-01/parse_result.py`, `phase-01/results/*/ndjson.log`,
  `phase-01/tests/fixtures/*.ndjson` — NDJSON schema and the nested-error-shape bug
- `.planning/research/{PITFALLS.md,STACK.md,FEATURES.md,SUMMARY.md}` — pre-existing project
  research on `--auto-approve`/`--hook-command`/connector-vs-CLI default asymmetry, cross-checked
  against and confirmed by this session's live tests

### Tertiary

None — every claim in this document was either reproduced live or read directly from this
project's own prior verified artifacts; no external web search was needed or used.

## Metadata

**Confidence breakdown:**
- Sandbox/Bun startup root cause and fix (Pitfall 1): HIGH — deterministically reproduced,
  isolated via bisection, fix verified to require no security-relevant changes
- `--auto-approve false` headless behavior (Pitfall 2): HIGH — reproduced live with full NDJSON
- Criterion-3 test design and evidence (Pitfall 3): HIGH — reproduced live, positive result
- NDJSON schema (HLS-01): HIGH — cross-confirmed across three independent capture sessions
  (Phase 1's stored results, this session's two live runs)
- Open Question 1 (self-abort trigger) and Open Question 2 (`run_start` presence): LOW — noted,
  not blocking, flagged for the planner rather than guessed at

**Research date:** 2026-08-30
**Valid until:** tied to the `cline@3.0.53` pin — invalid the moment `cline --version` reports
anything else (re-verify per the same rule `docs/32k-compaction-policy.md` §6 already states for
its own conclusions)
