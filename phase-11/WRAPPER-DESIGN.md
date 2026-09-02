# phase-11/WRAPPER-DESIGN.md — cline-plan / cline-act contract

Authoritative source for USE-01/USE-02. Phase 12's USE-04 manual work should be written from this
document, not re-derived from the wrapper scripts. Evidence quoted below is from
`phase-11/results/20260902T041615Z-argv/` (`$(cat phase-11/results/CURRENT_ARGV_RUN)`), a live run
of `phase-11/wrapper_argv_test.sh` against a stub `cline` — zero model requests.

## 1. The contract

```
cline-plan [-t|--timeout <secs>] [-c|--cwd <path>] [--json] [--] <prompt...>
cline-act  [-t|--timeout <secs>] [-c|--cwd <path>] [--json] [--] <prompt...>
```

Those four option forms — `-t/--timeout`, `-c/--cwd`, `--json`, `--` — are the entire accepted
surface. Everything else that begins with `-` is refused.

**Exit-code contract** (identical across `cline-plan`, `cline-act`, `wrapper_common.sh`):

| Exit | Meaning |
|---|---|
| `0..N` | The real `cline` binary's own exit code, forwarded unchanged |
| `2` | Refused argument or usage error — the real binary was **never invoked** |
| `3` | Pre-run config guard failed — the real binary was **never invoked** |
| `4` | Post-run config guard failed — **not** cline's own exit code; cline may have exited `0` and the wrapper still exits `4` to surface the guard failure |

**Constructed command line — quoted from the actual captured run, not retyped.**

`argv.tsv` row P1, verbatim:

```
P1	cline-plan	cline-plan hello	0	yes	has -p; -m flashnext-plan once; -P openai-compatible; --compaction agentic; last=hello; thinking=0; env recorded	PASS
```

The full argv the stub actually received for that call (`cases-real/P1.argv`, in received order):

```
$ cline-plan "hello"
-> /opt/homebrew/bin/cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 600 hello
```

`argv.tsv` row P2, verbatim:

```
P2	cline-act	cline-act hello	0	yes	has -m flashnext-act once; no -p; no --plan; thinking=0	PASS
```

The full argv (`cases-real/P2.argv`):

```
$ cline-act "hello"
-> /opt/homebrew/bin/cline -P openai-compatible -m flashnext-act --compaction agentic -t 600 hello
```

`argv.tsv` row P3, verbatim (shows `--timeout`/`--json` passing through):

```
P3	cline-plan	cline-plan --timeout 90 --json hello	0	yes	has -t 90; has --json	PASS
```

```
$ cline-plan --timeout 90 --json "hello"
-> /opt/homebrew/bin/cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 90 --json hello
```

Note `-p` and `-m flashnext-plan` are present in every `cline-plan` invocation regardless of what
the caller typed, and absent/swapped-alias for every `cline-act` invocation — that pairing, not
argument convenience, is USE-01's actual job.

## 2. Why scripts, not the design doc's shell functions

`docs/plan-act-reasoning-design.md` §L3 and `-implementation.md` §T5 both sketch:

```sh
cline-plan() { cline -p -m flashnext-plan "$@"; }
```

Three problems, stated plainly:

- **(a) `"$@"` is Pitfall 2** (`11-RESEARCH.md`) — it forwards `--thinking high` and a second `-m`
  straight through to the real binary. A client-sent `reasoning_effort` from `--thinking` overrides
  whatever the alias injects (litellm merges client kwargs *after* `litellm_params`,
  `phase-10/ALIAS-DESIGN.md` §3) — one appended flag defeats the entire mechanism this wrapper
  exists to enforce.
- **(b) a shell function cannot be statically inspected by `verify_config.sh`**, which USE-02
  requires. A function lives only in whatever shell sourced it; there is no file on disk with a
  stable path a checker can grep or execute.
- **(c) a function cannot be invoked by path from another process.** The stub-argv harness (this
  plan) and the A/B (plan 11-05) both need to run the wrapper as a subprocess from a test script;
  a shell function requires the caller's interactive shell to have sourced the defining file first.

Phase 12 owns updating those two design documents (USE-05) — this document is the corrected
replacement they should be reconciled against, not a competing draft.

## 3. Why deny-by-default rather than a blocklist

`-p, --plan` and `--thinking <level>` both appeared in the installed `cline` binary somewhere
between 3.0.53 and 3.0.60 with zero announcement — re-verified live against the installed 3.0.60
binary (`11-RESEARCH.md` Q2), and absent from the 3.0.53 flag inventory this project pinned
earlier (`docs/cline-config-pins.md` §2). CFG-05 records that `cline`'s auto-update is not actually
blocked. Put together: **the binary's own flag surface can change without anyone in this project
being told**, and a blocklist of "known-bad" flags written today is, by construction, a list that
goes stale the very next time the binary drifts — possibly silently, possibly before anyone
notices. `wrapper_common.sh` therefore accepts exactly four option shapes
(`-t/--timeout`, `-c/--cwd`, `--json`, `--`) and refuses every other `-`-prefixed argument
unconditionally, whether or not this project has ever heard of it. A brand-new flag added in
`cline` 3.0.99 would be refused by this parser on day one, with no code change required.

## 4. Why reject rather than strip

Silently dropping a flag the caller explicitly typed is the same silent-success failure shape
CFG-14 bans `drop_params` for (a rejected parameter that still returns HTTP 200 manufactures false
confidence) and `phase-10/ALIAS-DESIGN.md` §4 names again. A user who types `--thinking high` and
gets a silently different, un-announced run has been lied to about what actually executed. Every
refusal in this wrapper: (1) names the specific rejected argument on stderr, (2) prints usage,
(3) exits non-zero, and (4) never invokes the real binary — proven, not assumed, by
`wrapper_argv_test.sh`'s refusal cases, each of which pre-seeds the stub's argv-capture file with a
sentinel and asserts it is byte-unchanged after the wrapper runs. Example, `R1` (`cline-plan
--thinking high "x"`), stderr verbatim:

```
REFUSED: cline-plan does not accept '--thinking'. Reasoning effort is injected server-side by the
litellm alias. litellm merges client kwargs AFTER the alias's litellm_params
(phase-10/ALIAS-DESIGN.md §3), so a client-sent reasoning_effort OVERRIDES the alias — using
--thinking silently bypasses this wrapper's guarantee. See .planning/REQUIREMENTS.md CFG-11,
2026-09-02 correction.
```

## 5. What `-p` actually does, and what it does not

Per `11-RESEARCH.md` Q2 (verified by decompiling the installed 3.0.60 binary): `-p`/`--plan` sets
Cline's own agent **mode** — a tool-availability/system-prompt axis. Plan mode restricts the agent
to a single `switchToActModeTool` and nothing else (`j.config.extraTools=j.mode==="plan"?[j.switchToActModeTool]:[]`
in the decompiled binary). This is **orthogonal** to which model alias is selected and to whether
reasoning is injected at all. `-m <alias>` alone selects the injected `reasoning_effort` /
`enable_thinking` parameters; **no `-p` flag is required** for reasoning to reach the model
(`phase-10/PHASE-10-FINDINGS.md` §5 — Phase 10's own live `cline -m flashnext-plan` runs, with no
`-p`, showed reasoning in the stream).

`cline-plan` pairs `-p` with the plan alias anyway, because ROADMAP Phase 11 criterion 1 says so —
**a deliberate product decision, not a technical requirement of the reasoning injection.** This is
exactly why the USE-03 A/B (plan 11-05) must run **without** `-p` in either arm: comparing
`cline-plan` against `cline-act` head-to-head would confound "does `medium` reasoning help" with
"does Plan mode's tool restriction help or hurt," which is a different question the A/B is not
designed to answer. Holding `-p` constant (absent in both arms) isolates the variable the A/B
actually cares about: the alias.

## 6. The single-source alias and the USE-03 revert path

`phase-11/wrapper.env` is the only file that names `flashnext-plan` / `flashnext-act`. Neither
`cline-plan` nor `cline-act` contains a literal alias string — both read `WRAPPER_PLAN_ALIAS` /
`WRAPPER_ACT_ALIAS` from `wrapper.env` (mechanically verified: `grep -c 'flashnext'` against both
wrapper scripts returns `0`). If USE-03's A/B shows no improvement, REQUIREMENTS.md's specified
revert — `cline-plan` back to plain `flashnext` — is a one-line edit to `wrapper.env`'s
`WRAPPER_PLAN_ALIAS=` line, with a `git diff` as the audit trail. No wrapper logic changes.

## 7. Limitations, honestly

- **Prompts beginning with `-` are refused** (case P4: `cline-plan -- "-weird prompt"` → exit 2).
  There is no escape mechanism through these wrappers for a prompt that must literally start with
  a dash — the caller must rephrase. This is a deliberate, documented trade-off: allowing it would
  mean the real `cline` binary re-parses that leading token as a flag, which is a worse failure
  mode (a silently misinterpreted prompt) than a loud refusal.
- **`--auto-approve`, `--hooks-dir`, `--id`, `-s/--system`, `--zen`, `--tui`, `--acp`,
  `--worktree`, `--retries`, `--kanban`, `--update`, `--data-dir`, `--config`, `-k/--key`,
  `-v/--verbose` and every other real `cline` flag are unreachable through these wrappers by
  design.** A user who needs one of them must call `cline` directly and thereby loses the
  mode/alias pairing guarantee entirely for that invocation. This is the direct cost of
  deny-by-default: it does not merely block the flags this project already knows about, it also
  blocks every legitimate flag it does not special-case.
- **The config guard aborts rather than heals.** On a pre-run guard failure the wrapper prints the
  failure and the exact `apply_provider_config.sh` command to run, and stops — it does not rewrite
  `providers.json` itself. Silent healing is `phase-04/run_headless.sh`'s documented policy for its
  own unattended surface; it is not this wrapper's policy, because an interactive wrapper silently
  rewriting the user's provider config is a hidden side effect the user did not ask for.
  A caller invoking a naive `deny-by-default` wrapper accepts that the wrapper stops rather than
  guesses.
- **Test mode (`CLINE_WRAPPER_TEST=1`) exists and is loud, but is nevertheless a way to point the
  wrapper at a different binary.** It always prints `[TEST MODE] using $CLINE_WRAPPER_TEST_BIN
  instead of $WRAPPER_CLINE_BIN` to stderr — it can never substitute silently — but its mere
  existence is a documented capability a sufficiently motivated caller could misuse. Nothing in
  this plan's evidence exercises the real `cline` binary; that is intentional (zero model
  requests), but it does mean the "loud never silent" guarantee for the substitution mechanism
  itself, not for the argument parser, is the property actually being relied on here.
- **`-m flashnext-codex` is refused only because it is not one of the four accepted option forms
  (deny-by-default), not because of a codex-specific rule.** Row R6 in `argv.tsv` notes this
  explicitly: the codex alias has separately been measured to kill the model server for ~29s, and
  deny-by-default closes that path for free, as a side effect of refusing all `-m` values rather
  than as a targeted fix.

## 8. The interaction plan 11-03 will have to solve

`verify_config.sh` is about to be extended (plan 11-03) to exercise these wrappers as part of its
own checks. These wrappers, in turn, call `verify_config.sh` as their pre-run and post-run config
guard (§1, §7). That is a two-way call graph with an obvious recursion risk if not broken
deliberately.

The brake, already built into this plan's wrapper_common.sh even though nothing reads it yet:

- **`VERIFY_CONFIG_NO_WRAPPER_CHECK=1`** — exported by `wrapper_common.sh` on every internal call
  it makes to `verify_config.sh` (both pre-run and post-run). Plan 11-03 must make
  `verify_config.sh`'s new wrapper-exercising section check for this variable and skip itself when
  it is set, so the wrapper's own guard call does not re-enter the wrapper-checking logic.
- **`CLINE_WRAPPER_TEST=1`** — set by this plan's test harness on every call to the wrapper scripts
  themselves; `wrapper_common.sh` skips its entire config-guard cycle (both pre- and post-run) when
  this is set, so a test run never calls `verify_config.sh` in the first place.

Plan 11-03 must **prove** there is no recursion (e.g., a mutant that removes the
`VERIFY_CONFIG_NO_WRAPPER_CHECK` guard and confirms the resulting infinite loop is caught by a
depth limit or similar, or a live trace showing the call graph terminates) rather than assume the
two flags above are sufficient by inspection alone — this project's own repeated experience (five
silent instruments in Phase 10, `phase-10/PHASE-10-FINDINGS.md` §4.6) is that an guard that looks
right by reading it is not the same as one that has been shown to work.
