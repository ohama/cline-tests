# 05-06 Task 2 — phase-05/services/verify_services.sh: the standing Phase 5 gate

`verify_services.sh` is Phase 5's standing, read-only, re-runnable gate — the same shape as
`phase-02/infra/verify_no_regression.sh` and `phase-03/sandbox/verify_sandbox.sh`. It prints one
`CHECK: PASS|FAIL <name>` line per assertion and follows the house 3-way exit contract
(0 all pass / 1 at least one FAIL / 2 a probe itself crashed — never reported as a pass). It never
calls `check_versions.sh` (that spends a real `cline` invocation) and never sends a termination
signal or touches any of launchd's state-changing subcommands — only the read-only `print`.

## Runs

| Dir | Purpose | Exit |
|---|---|---|
| `run1/` | Both services live, first pass | 0 |
| `run2/` | Both services live, second pass (re-runnability proof) | 0 |
| `negative-control/` | `KANBAN_PORT=39999` override — deliberate failure proof | 1 |

`diff` of the two live runs' `CHECK:` lines is empty — all 15 checks produced byte-identical
PASS/FAIL verdicts across both runs:

```
CHECK: PASS kanban-state-running
CHECK: PASS kanban-pid-settled
CHECK: PASS telegram-state-running
CHECK: PASS telegram-pid-settled
CHECK: PASS kanban-port-listening
CHECK: PASS kanban-http-response
CHECK: PASS anti-orphan-kanban-sandboxed
CHECK: PASS anti-orphan-telegram
CHECK: PASS port-hygiene-no-3000
CHECK: PASS pin-gate-com.ohama.kanban
CHECK: PASS pin-gate-com.ohama.telegram-connect
CHECK: PASS sandbox-boundary-empty-allow-paths
CHECK: PASS log-growth-watch
CHECK: PASS mirror-labels-tracked
CHECK: PASS mirror-plists-byte-identical
```

The negative control (`KANBAN_PORT` overridden to an unused port before sourcing `config.env`'s
own `${KANBAN_PORT:-3484}` idiom) produced exit 1 with exactly the two checks that should fail —
`kanban-port-listening` and `kanban-http-response` (curl `rc=7`, `http_code=000`, connection
refused) — while every other check, including the four pid-sample checks against the real,
unaffected kanban process, still PASSed. This proves the gate can actually fail, not just always
report success.

## One deviation (Rule 1 — plan-authoring trap, not a code bug)

The plan's assertion 4 text said the anti-orphan check should show "`ps -o args= -p <kanban pid>`
... the sandbox-exec/kanban chain." Measured directly against the live kanban pid (53894):
`ps -o args=` shows `node /opt/homebrew/bin/kanban --no-open --host 127.0.0.1 --port 3484` —
**no `sandbox-exec` substring at all.** This is not a bug in the wrapper or the sandbox; it is the
exact same structural fact 05-04's own decision log already established: `sandbox-exec` performs
a real `execve()` into the wrapped command, and `execve()` replaces the process's own recorded
argv, so a post-exec `ps` snapshot can never show the string `sandbox-exec` for the final,
supervised pid regardless of correctness. Writing a grep for that literal string here would have
repeated the same authoring mistake 05-04 already diagnosed and fixed once.

The check was written to prove what the plan's assertion actually needs proven — confinement is
really active on this exact pid — using 05-04's own established method: `vmmap <pid> | grep -i
sandbox` must show `libsandbox.1.dylib` (and `libsystem_sandbox.dylib`) mapped into that pid's own
memory, which it does. Identity (this process really is kanban) is covered separately by a plain
`ps args` substring match on `kanban`, which the true argv does contain. Both sub-checks must pass
for `anti-orphan-kanban-sandboxed` to PASS; both did, in both live runs.

## Live pids (unchanged before, during, and after all three runs)

flashnext=46573 · role-shim=75548 · litellm=48525 · kanban=53894 · telegram-connect=56669
