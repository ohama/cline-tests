# cline smoke test under the sandbox (03-04 Task 1)

**This was the phase's ONLY real `cline` invocation that reached and ran cline's/Bun's own code.**
One earlier attempt crashed inside Node's own process bootstrap (before any cline/Bun code ran) due
to a harness plumbing choice, not the sandbox or cline itself, and is not counted -- see below.

**Outcome: (C) BLOCKED-NEEDS-HUMAN.** No sandbox change was made. Full reasoning: `verdict.txt` in
this directory.

## The exact command chained (final, working form)

```
bash -c 'set -a; . phase-01/config/cline-invocation.env; set +a; \
  npm install -g cline@3.0.53 >/dev/null 2>&1 && \
  phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" --version' \
  > workspace/scratch-repo/.cline-smoke-version.out \
  2> workspace/scratch-repo/.cline-smoke-version.err
```

(Output was redirected to a path INSIDE the whitelist -- `workspace/scratch-repo/`, an
`ALLOWED_REPOS.json` entry -- rather than directly to `phase-03/results/`, then copied here from
the unsandboxed parent shell afterward. See "Why the output path changed" below.)

## Result

- Exit code: **1**
- stdout: (empty) -- see `version.out`
- stderr -- see `version.err`:
  ```
  resolved allow list: ['/Users/ohama/projs/cline-tests/workspace/scratch-repo', '/Users/ohama/.cline']
  error: An unknown error occurred (Unexpected)
  ```

`error: An unknown error occurred (Unexpected)` is confirmed by static `strings` inspection
(`bun-error-strings-evidence.txt`, zero additional invocations) to be Bun's own generic runtime
catch-all error message, not a cline-specific or sandbox-specific message -- it does not name a
path or an errno. `~/.cline/` had no files modified by this run, meaning the failure happened
before Bun's runtime ever touched cline's own data directory.

## Why the output path changed from the plan's literal form

The plan's literal invocation redirects output directly to
`phase-03/results/<ts>-cline-smoke/version.{out,err}`. The FIRST attempt used exactly that form and
crashed with **SIGABRT (exit 134)** inside Node's own process bootstrap
(`node::InitializeOncePerProcessInternal`, before any cline/Bun code executed) -- see
`attempt1-crashed.out` / `attempt1-crashed.err` / `attempt1-crashed.exitcode`. This is the exact
same root cause plan 03-03 already found and fixed for its F8 case (plain `node` invocation): a
sandboxed process whose inherited stdout/stderr fd is a regular file under a path the profile does
NOT punch through crashes Node's own bootstrap with no diagnostic. Per Rule 3 (blocking issue), the
fix -- redirecting to an in-whitelist path instead of an unpunched one, exactly 03-03's precedent --
was applied before running the real (second) attempt. This is a pure harness/plumbing fix: it does
not touch `EXTRA_ALLOW_PATHS`, `config.env`, or any security boundary, and because the first
attempt's crash happened before a single line of cline's own code ran, it is not counted as "the
budgeted invocation" -- the second attempt is.

## Pre- and post- config guard results

| Step | Result | File |
|---|---|---|
| Pre-flight `verify_sandbox.sh` (before any cline call) | PASS, 4/4 CRITERION, 0 crashed | `../<pre-cline-ts>-pre-cline/` |
| `verify_config.sh` immediately after the smoke test | **FAIL** (`models[]` stripped, expected drift) | `verify_config-1.txt` |
| `apply_provider_config.sh` heal | OK | `apply_provider_config.txt` |
| `verify_config.sh` re-check | PASS | `verify_config-2.txt` |
| `check_versions.sh` (drift evidence) | PASS, cline pinned 3.0.53, no drift across its own 2 internal invocations | `check_versions.txt` |
| `verify_config.sh` after `check_versions.sh` (its own internal `cline config --json` re-stripped providers.json, exactly as 01-04 predicted) | **FAIL** (`models[]` stripped again) | `verify_config-3-post-checkversions.txt` |
| `apply_provider_config.sh` heal (2nd time) | OK | `apply_provider_config-2.txt` |
| `verify_config.sh` final re-check | **PASS** (final state) | `verify_config-4-final.txt` |
| `verify_sandbox.sh` re-run after everything above | PASS, 4/4 CRITERION, 16/16 cases, 0 crashed -- unchanged | `verify_sandbox-post.txt`, `post-verify-sandbox/` |

providers.json is left verified-correct (final state: PASS). The `verify_config.sh`
FAIL/heal/PASS cycle happening twice is expected, documented Phase 1 drift behavior
(01-01/01-04/01-06 decision log), not a new finding of this plan.

## Sandbox state

`grep -n EXTRA_ALLOW_PATHS phase-03/sandbox/config.env` after this task shows the value unchanged
(still empty/default). No widening was made. `phase-03/sandbox/verify_sandbox.sh` still exits 0
with all four CRITERION lines PASS after this entire task.

## Files in this directory

- `verdict.txt` -- full classification reasoning (read this first)
- `attempt1-crashed.{out,err,exitcode}` -- the first, uncounted, crashed attempt
- `version.{out,err,exitcode}` -- the second (real, counted) attempt
- `bun-error-strings-evidence.txt` -- static `strings` evidence identifying the Bun error family
- `verify_config-*.txt`, `apply_provider_config*.txt`, `check_versions.txt` -- Phase 1 config guard
  transcripts, in chronological order
- `verify_sandbox-post.txt`, `post-verify-sandbox/` -- the post-flight standing-gate re-run
