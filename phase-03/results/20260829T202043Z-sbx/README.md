# Phase 3 standing-gate evidence run

This is the primary (first of two identical, back-to-back) real runs of
`phase-03/sandbox/verify_sandbox.sh` against the actual production
`workspace/ALLOWED_REPOS.json` — no `--out-dir` override, no `cline`
invocation, no launchd mutation. `sbx-verdict.txt` in this directory is the
run's full transcript; `VERIFY_SANDBOX: PASS`, exit code 0.

A second, independent run landed at
`phase-03/results/20260829T202048Z-sbx/` five seconds later and produced
identical `CRITERION` lines, confirming the gate is genuinely re-runnable
and not order- or state-dependent.

## Criterion -> case mapping

| ROADMAP criterion | Requirement | Proving case(s) | Result |
|---|---|---|---|
| 1 | `ALLOWED_REPOS.json` exists and is the source of truth (SBX-01) | `criterion-1-check` (concrete: file exists, parses, every entry resolves to an existing directory, and no entry equals-or-is-an-ancestor-of `realpath(bench/)`) | PASS |
| 2 | Read/write outside the whitelist actually fails (SBX-02) | `F2` (shell-level read deny), `F3` (shell-level write deny, file confirmed absent afterward), `F8` in-process `fs` checks (`inproc-read-forbidden`, `inproc-write-forbidden`) | PASS |
| 3 | `execute_command` outside the whitelist is blocked by `sandbox-exec` (SBX-03) | `F4` (`/bin/sh -c cat ...`, the `execute_command` shape of the same denial), `F8` subprocess checks (`subproc-read-forbidden`, `subproc-write-forbidden`) — same profile, same mechanism as criterion 2 | PASS |
| 4 | Bench results dir unreadable from inside the sandbox (SBX-04) | `P3` (direct `cat bench/runs/CANARY.txt` denied), `P4` (`cat bench/runs/*` denied), plus a full-directory grep confirming the canary string `SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX` appears in NO captured sandboxed stdout anywhere under this results directory | PASS |

Every "denied" verdict above came from `phase-03/sandbox/assert_denied.sh`
(which requires an unsandboxed control to succeed first, and discriminates
crashed-signal / not-denied / crashed-silent / wrong-error before ever
printing PASS) or, for `F8`, from `probe_fs.js`'s own per-line
DENIED/ERROR/SUCCEEDED text — never from a bare non-zero exit code.

## Real kernel denial messages (quoted, not asserted on trust)

**Criterion 2 (`F2`, shell-level read of a forbidden fixture path):**
```
$ /bin/cat /Users/ohama/projs/cline-tests/phase-03/fixtures/forbidden/secret.txt
cat: /Users/ohama/projs/cline-tests/phase-03/fixtures/forbidden/secret.txt: Operation not permitted
```

**Criterion 3 (`F4`, the same denial via `/bin/sh -c`, the `execute_command` shape):**
```
$ /bin/sh -c "cat .../fixtures/forbidden/secret.txt"
shell-init: error retrieving current directory: getcwd: cannot access parent directories: Operation not permitted
cat: /Users/ohama/projs/cline-tests/phase-03/fixtures/forbidden/secret.txt: Operation not permitted
```
(The `shell-init` line is `/bin/sh` itself failing to read its own cwd —
also a real Seatbelt denial, harmless to the assertion since `assert_denied.sh`
only requires *a* `Operation not permitted`/EPERM message naming the target,
which the second line supplies.)

**Criterion 4 (`P3`, direct read of the bench canary against the real production profile):**
```
$ /bin/cat /Users/ohama/projs/cline-tests/bench/runs/CANARY.txt
cat: /Users/ohama/projs/cline-tests/bench/runs/CANARY.txt: Operation not permitted
```

**Criterion 2+3 collapse (`F8`, `probe_fs.js` in one process, full output):**
```
PROBE inproc-read-allowed SUCCEEDED
PROBE inproc-read-forbidden DENIED EPERM
PROBE inproc-write-forbidden DENIED EPERM
PROBE inproc-write-allowed SUCCEEDED
PROBE subproc-read-forbidden DENIED status=1
PROBE subproc-write-forbidden DENIED status=1
PROBE escape-symlink-read DENIED EPERM
PROBE-SUMMARY succeeded=2 denied=5 error=0
```
This is the case that proves SBX-02 and SBX-03 are the same kernel
mechanism: identical profile, in-process `fs` calls and `execSync`
subprocess calls against the same forbidden path are both denied with
`EPERM`/"Operation not permitted", and the escape-symlink case
(`allowed/escape-link` -> `forbidden/`) proves the kernel resolves symlinks
to their real target before checking, not the spelling used to reach them.

## No live-service mutation, no `cline` invocation

`launchctl print gui/$UID/com.ohama.flashnext` was checked before and after
this plan's two runs:

```
before: state = running, pid = 46573
after:  state = running, pid = 46573
```

Same pid both times — no restart occurred. `git status --short` shows no
modification to `phase-02/` or any `.plist` for the duration of this plan.
No `cline` binary was invoked anywhere in this plan (03-01/02/03 deliberately
defer the single budgeted `cline` smoke test to plan 03-04) — every case
here uses `/bin/cat`, `/bin/sh`, or `node`/`probe_fs.js`.

## Contents

- `sbx-verdict.txt` — full run transcript and the four `CRITERION` lines.
- `fixture.sb`, `production.sb` — the two generated Seatbelt profiles,
  archived exactly as compiled for this run.
- `F1.txt`..`F7.txt`, `P1.txt`..`P6.txt` — one `assert_denied.sh` transcript
  per case (command, exit code, captured stdout/stderr).
- `probe-sandboxed.txt` — the `F8` `probe_fs.js` run, full output.
- `fixture-manifest.txt` — `make_fixtures.sh`'s manifest for this run's
  fixture tree.
- `gen-fixture.stderr`, `gen-production.stderr` — `gen_sandbox_profile.py`'s
  own stderr (the resolved allow-list line) for each profile.

## Reproducing

```
phase-03/sandbox/verify_sandbox.sh
```
