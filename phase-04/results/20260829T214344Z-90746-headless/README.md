# Phase 4 Plan 2, Task 3 — one live sandboxed `cline` run (criterion 1 evidence)

## Command

```
bash phase-04/run_headless.sh --timeout 180 \
  "Reply with exactly the word PONG and nothing else. Do not use any tools."
```

## Outcome

- **Wrapper exit code:** `0`
- **Classifier outcome:** `success` (see `outcome.json`)
- **`run_result.finishReason`:** `"completed"` (1 `run_result` event present in `ndjson.log`)
- **`cline` process exit code:** `0`
- **Model's reply:** `PONG` (exactly as requested — deliberately tool-free prompt, per
  04-RESEARCH.md Pitfall 2 the correct shape to exercise the happy path under the shipped
  `--auto-approve false` wrapper)
- **Wall time:** `durationMs: 9680` for the cline call itself (from `ndjson.log`'s `run_result`
  event); total wrapper wall time (preflights + reinstall + run + post-run guard) was under a
  minute, well inside the `--timeout 180` budget.

This satisfies the Task 3 pass rule for criterion 1 (HLS-01): a non-empty `ndjson.log` where every
non-blank line parses as JSON, containing at least one `"type":"run_result"` event, with a
classifier outcome of `success` (one of the three valid one-shot outcomes: `success`,
`tty_approval_rejected`, `run_aborted`).

## Config guard (verify_config.sh)

- **Pre-run:** PASS on first check (`config_pre.txt`) — no healing needed before the run.
- **Post-run:** FAILED on first check (`models[] expected length 1, observed None` —
  RESEARCH.md/Phase 1 Pitfall 5, expected and deterministic for any real `cline` invocation),
  healed via `apply_provider_config.sh`, re-verified PASS (`config_post.txt`). This is the
  documented, expected heal cycle, not a failure.

## npm reinstall pin

`npm install -g cline@3.0.53` — see `npm_pin.txt`. Reinstall-then-launch chained in one shell
command with no intervening manual `cline` call (Phase 1 finding: `CLINE_NO_AUTO_UPDATE=1` alone
does not reliably stop the background self-update).

## Sandbox standing gate (Preflight B)

`phase-03/sandbox/verify_sandbox.sh --out-dir <this-dir>/sandbox-gate` run immediately before the
live call: `VERIFY_SANDBOX: PASS`, `CASES 16/16`, `CRASHED 0`, all four `CRITERION ... PASS` lines
present (see `sandbox-gate-console.txt` / `sandbox-gate/`).

## `EXTRA_ALLOW_PATHS` — confirmed NOT changed

```
$ bash -c 'source phase-03/sandbox/config.env; [ -z "$EXTRA_ALLOW_PATHS" ]'
$ echo $?
0
$ git diff --stat phase-03/
(empty)
```

Both confirmed after the run. The cwd fix (Pitfall 1) and the stdio-capture fix (below) required
zero sandbox-boundary changes — exactly as 04-RESEARCH.md predicted.

## THE CWD RULE — applied and confirmed

`workdir.txt` (this run): `PWD=/Users/ohama/projs/cline-tests/workspace/scratch-repo`,
`WORKDIR_OK=OK`. The wrapper `cd`'d into `SANDBOX_WORKDIR` before invoking `run_sandboxed.sh`, and
asserted the resulting `$PWD` is a prefix match of `ALLOWED_REPOS.json`'s `repos[]` entry, exactly
as 04-RESEARCH.md Pitfall 1 requires.

## A first live attempt crashed — different bug, fixed, not counted toward the invocation budget

The **first** attempt at this task (results dir
`phase-04/results/20260829T214124Z-89595-headless-CRASHED-stdio-redirect/`, preserved for the
record) crashed with `Abort trap: 6` (`cline` process exit `134`) before any cline/Bun code ran.
`stderr.log` from that attempt contains only a native C++ stack trace
(`node::InitializeOncePerProcessInternal` / `node::Start`), no application-level diagnostic —
`ndjson.log` was empty.

**Root cause (same class as 03-03's F8 finding and 03-04's cline smoke-test crash, NOT the
inherited Phase 3 Bun-startup blocker):** the wrapper's own `2>"$RESULTS_DIR/stderr.log"` directly
opened a file under an **unpunched path** (`phase-04/results/` is not inside `SANDBOX_WORKDIR` or
`~/.cline`), and the sandboxed process inherited that fd across `exec`. Node's own process
bootstrap SIGABRTs the instant it touches a denied fd, before `cline`'s/Bun's own code executes.
stdout was already safe (piped through `tee`, no filesystem path involved for that fd).

**Fix (`phase-04/run_headless.sh`, committed before the retry):** capture stderr to a scratch file
**inside** `$SANDBOX_WORKDIR` (already whitelisted) instead, then copy the captured content into
`$RESULTS_DIR/stderr.log` and delete the scratch copy — the same fix 03-04 already validated for
this exact failure mode, reused verbatim rather than re-derived. No `EXTRA_ALLOW_PATHS` or
`phase-03/` change involved.

**Why this does not count toward "exactly one live cline invocation":** per 03-04's established
precedent, a crash whose native stack trace shows only Node's own C++ bootstrap frames (no
cline/Bun frame) proves no cline/Bun code ever executed — it is a harness plumbing bug, not a real
task attempt. The corrected second attempt (this directory) is the one, and only, invocation
counted against the phase's budget.

**`cline` task invocations used: 1** (hard cap 2; the crashed pre-cline-code attempt above does
not count, per precedent).

## Task 2 dry-run summary (offline, zero cline invocations, run before this live call)

All five `phase-04/fixtures/*.ndjson` fixtures were replayed through `run_headless.sh` under
`HEADLESS_DRY=1` (results under a scratch `/tmp` root, not committed per the plan's instruction):

| Fixture | Expected exit | Actual exit | Match |
|---|---|---|---|
| `sandbox_denied.ndjson` | 2 | 2 | yes |
| `success_no_tools.ndjson` | 0 | 0 | yes |
| `tty_approval_rejected.ndjson` | 3 | 3 | yes |
| `context_overflow_32k.ndjson` | 5 | 5 | yes |
| `crashed_truncated.ndjson` | 7 | 7 | yes |

- Every dry run wrote an `outcome.json`.
- Dry-run `stdout` was empty in all five cases (the classify step reads `ndjson.log` from disk, not
  stdout, under `HEADLESS_DRY=1`) — vacuously satisfies "stdout is NDJSON-only," including for
  `crashed_truncated.ndjson`, whose deliberately truncated trailing line is not valid JSON by
  design (simulating a killed process) and would otherwise have broken a naive "echo the fixture to
  stdout" implementation.
- Negative control: `SANDBOX_WORKDIR=/tmp/definitely-not-whitelisted` → wrapper exits `1`, message
  names `ALLOWED_REPOS.json`, zero `npm install` invocations (`grep -c 'npm install' *.stderr` ==
  0) — confirms cline is never invoked when the cwd assertion fails.

Two bugs were found and fixed live during this dry-run pass (see plan's `04-02-SUMMARY.md`
Deviations section for full detail):
1. Relative `DRY_FIXTURE` paths resolved against the post-`cd` sandbox workdir instead of the
   invocation cwd (fixed: resolve against `$ORIG_PWD`, captured before the `cd`).
2. Two runs landing in the same UTC second silently reused the same `RESULTS_DIR`, clobbering
   evidence (fixed: insert `$$` (PID) into the directory name, same convention as
   `phase-01/run_regression.sh`).

## Summary

Criterion 1 (HLS-01) is evidenced by this real sandboxed run. The inherited Phase 3 Bun-startup
blocker (04-RESEARCH.md Pitfall 1, the cwd rule) is confirmed resolved live, with zero sandbox
widening. `EXTRA_ALLOW_PATHS` remains empty. Exactly one live `cline` task invocation was spent
from the phase's two-invocation budget.
