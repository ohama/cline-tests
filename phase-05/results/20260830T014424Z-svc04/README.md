# 05-03 SVC-03/SVC-04 prove-before-register verdict

Evidence directory: `phase-05/results/20260830T014424Z-svc04/`

Everything below ran in the FOREGROUND, started and torn down by hand-recorded
pids. Nothing was registered with launchd (`launchctl bootstrap` count under
`phase-05/`: 0). The live 104 GiB flashnext (46573), role-shim (75548) and
litellm (48525) were never stopped, restarted, or otherwise disturbed —
confirmed unchanged before/after every task via `launchctl print
gui/$(id -u)/com.ohama.<label> | grep -m1 pid`. `EXTRA_ALLOW_PATHS` was
confirmed empty (`bash -c 'source phase-03/sandbox/config.env; [ -z
"$EXTRA_ALLOW_PATHS" ]'` exits 0) at the end of the plan. `cline`
invocations used: 0 (budget: 0).

## Preflight (both standing gates, before anything started)

- `bash phase-02/infra/verify_no_regression.sh --out-dir pre-inf03/` -> `INF03: PASS`
- `bash phase-03/sandbox/verify_sandbox.sh --out-dir pre-sandbox/` -> `VERIFY_SANDBOX: PASS`, 16/16 CASES, CRASHED 0

Both re-run at the end of the plan (`final-inf03/`) still print `INF03: PASS`.

## Deviation found and fixed before Task 1's evidence was captured

`phase-05/services/wait_for_upstream.sh`'s outer retry loop hand-accumulated
`WAITED` by only the tail-of-loop sleep amount. Stage 1 (TCP) is itself a
bounded retry (`wait_for_port.sh` called with `TIMEOUT_S=$INTERVAL_S`), so
when TCP is the failing stage every outer iteration already spends up to
`INTERVAL_S` seconds *inside* that call before the outer loop's own tail
sleep adds another `INTERVAL_S` on top. The first, unfixed run of case (a)
below (`UPSTREAM_WAIT_TIMEOUT=30`) measured **72s actual wall time** against
a 30s configured timeout — 2.4x over — while `deadport.err` still printed
"timed out after 30s" (the WAITED accounting itself was wrong, not just the
message). This was never caught in 05-01's live checks because those forced
stage 2/3 failures only, where TCP passes near-instantly every iteration —
Task 1's dead-port case is the first exercise of stage 1 as the failing
stage. Fixed by switching `WAITED` to `$SECONDS`-based real wall-clock
accounting (commit `4ef64d2`, before Task 1's evidence commit). Sanity-
verified post-fix: default pass against the live stack still exits 0 in
~0.08s; forced stage-1 failure now bounds to the configured 10s (measured
10.18s); forced stage-2 failure unchanged at the configured 10s (measured
9.66s). All numbers below are from the POST-FIX script.

A second, unrelated slip during Task 3: the first kanban-wrapper invocation
had its stdio redirected to `$RES` (under `phase-05/results/`, outside the
sandbox's allowed workspace) and the sandboxed child crashed with the
documented native SIGABRT class (bare "Native stack trace", no app code
reached) — the same failure family as 03-03 F8 / 03-04 / 04-02 / 04-04, just
triggered by a different unpunched path this time. Not a script bug: fixed
by re-running with stdio redirected to the already-proven-safe
`$HOME/.cline/logs/` path (same pattern Task 1's case (c) used successfully)
and copying the logs into `$RES` afterward. `EXTRA_ALLOW_PATHS` was not
touched; no sandbox widening.

## Task 1 — SVC-04 dead-port, listening-but-not-ready, recovery, stdio pre-check

### (a) Hard-down: FLASHNEXT_PORT=1 (refused), UPSTREAM_WAIT_TIMEOUT=30

- Exit code: `1` (`deadport-rc.txt`)
- Elapsed: ~36-41s wall against a 30s configured timeout (`deadport.err`: "timed out after 36s"; outer shell wall-clock measured 41s including startup/sampling overhead) — bounded, not instant, not never.
- `%cpu`: every sample in `deadport-ps.txt` (8 samples over the run) is `0.0` — a poll, not a spin.
- `deadport.err`: exactly 2 lines — one timeout line naming the failing stage (`1-tcp(127.0.0.1:1)`), no more.
- 3484 never listened during the run (`deadport-lsof.txt` empty); no `kanban` process was ever spawned (verified via `ps aux` grep).

### (b) Listening-but-not-ready — the decisive case

A throwaway `python3 -m http.server 8999 --bind 127.0.0.1` (preflight-checked
free via `lsof`, pid captured as `$HTTPPID`) makes the TCP stage genuinely
succeed while the backend behind it is not flashnext.

**Sub-case 1 (health stage rejects):** `FLASHNEXT_PORT=8999`,
`FLASHNEXT_HEALTH_URL=http://127.0.0.1:8999/health`, timeout=20.
Exit code `1`, elapsed ~25s, `notready1.err` names
`stage 2-flashnext-health(http://127.0.0.1:8999/health)` as the failure —
not the TCP stage, which passed. 3484 never listened.

**Sub-case 2 (alias stage rejects):** real `:8000/health` (unmodified),
`LITELLM_MODELS_URL=http://127.0.0.1:8999/` (a 200 whose body has no
`flashnext`), timeout=20. Exit code `1`, elapsed ~21s, `notready2.err` names
`stage 3-litellm-alias(flashnext)` as the failure. 3484 never listened.

Both sub-cases combined: `notready-ps.txt` has 9 samples total (>= 3 per
sub-case), every `%cpu` sample `0.0` — the poll loop paces itself correctly
even when the TCP stage passes and a later stage fails; no busy-loop
regression. `notready-rc.txt` is `1` / `1`. `notready-stage.txt` records
both stage names explicitly. The throwaway HTTP server was torn down by its
captured `$HTTPPID`; `lsof -nP -iTCP:8999 -sTCP:LISTEN` confirmed empty
afterward.

### (c) Recovery against PRODUCTION targets + launchd-shaped stdio pre-check

Run with **no probe overrides** (`UPSTREAM_WAIT_TIMEOUT=60` only) and stdio
redirected exactly as the plist will (`>>$HOME/.cline/logs/kanban.log
2>>$HOME/.cline/logs/kanban.err`, punched/allowed path, directory
pre-created). The standalone `wait_for_upstream.sh 10 2` reading: exit 0 in
0s (`recovery-wait.txt`). The wrapper's own readiness wait passed within one
interval and `exec`'d into the real `kanban` binary — pid preserved through
the whole chain (wrapper pid == kanban pid), listening on
`127.0.0.1:3484` (`recovery-lsof.txt`). `grep -c 'Abort trap'
kanban.err` = 0, same for `'Unexpected'` — the launchd-shaped stdio
redirect to a PUNCHED path (`$HOME/.cline/logs/`, confirmed
`(allow file-read*/file-write* (subpath ".../\.cline"))` in the live
sandbox profile) does NOT reproduce the SIGABRT this project has hit four
times before at unpunched paths. Torn down by the recorded pid; 3484
confirmed free afterward.

### What (a) + (b) + (c) together prove, and what they do NOT

**Proven:** the launchd-visible behaviour of SVC-04 — the wrapper absorbs
the flashnext-not-ready window (including the case where a proxy in front
of it is already accepting connections, which a bare TCP check could never
distinguish from real readiness), so the retry cadence under `KeepAlive` is
one process spawn per roughly `(UPSTREAM_WAIT_TIMEOUT + ThrottleInterval)`,
never a tight crash loop, and the service starts as soon as flashnext
genuinely reports a loaded model through to the alias litellm advertises.

**NOT proven:** the readiness gate stops short of a full
`POST /v1/chat/completions` round-trip (that costs a real inference on
every service start, ~64s TTFT observed elsewhere in this project) — it
says nothing about kanban's own in-flight behaviour when a live agent turn
loses its provider mid-request. No task exists in Phase 5 for that; it is
deferred (documented as a residual in `wait_for_upstream.sh`'s own header
and repeated here).

## Task 2 — Empty-token idle proof (telegram wrapper)

Ran `TELEGRAM_BOT_TOKEN= bash phase-05/services/run_telegram_service.sh`
with launchd-shaped stdio redirection, observed for ~96s (6 samples, 15s
spacing, exceeding the 90s minimum):

| # | pid | %cpu | etime | connect-telegram count |
|---|-----|------|-------|------------------------|
| 1 | 48236 | 0.0 | 00:18 | 0 |
| 2 | 48236 | 0.0 | 00:33 | 0 |
| 3 | 48236 | 0.0 | 00:48 | 0 |
| 4 | 48236 | 0.0 | 01:03 | 0 |
| 5 | 48236 | 0.0 | 01:18 | 0 |
| 6 | 48236 | 0.0 | 01:34 | 0 |

All four required observations held: (1) pid unchanged across every sample —
no restart loop; (2) `%cpu` 0.0 on every sample — no spin (the numeric
`/bin/sleep`, never `sleep infinity`); (3) log line count identical at start
and end (`idle-logcount.txt`: 0 stdout / 2 stderr both times — exactly the
one startup notice plus the injection recipe, nothing after); (4)
`pgrep -f 'connect telegram'` was `0` on every sample — the real `cline`
binary was never invoked. (A broad `pgrep -f cline` self-matches this
execution harness's own shell wrapper, whose sourced snapshot script
contains the substring "cline-tests" from this repo's own path — a harness
artifact, not a `cline` process; recorded and explained in
`idle-pgrep.txt` so it does not read as a false pass.) Killed by the
recorded pid afterward, confirmed gone.

Static invariants (cannot be observed at runtime while the token slot is
empty): `grep -n 'connect telegram' run_telegram_service.sh` shows exactly
one invocation line carrying `-i --no-tools` as literal adjacent tokens;
`grep -c -- '--enable-tools\|--auto-approve' ...` is `0`.

## Task 3 — Port inventory, RPC coexistence verdict

Started the kanban wrapper once more against the real upstream (no
overrides beyond `UPSTREAM_WAIT_TIMEOUT=60`), captured the full TCP
inventory once 3484 was listening (pid 49330, preserved through the exec
chain), then took it down by that pid.

`kanban-ports.txt` (the process's own TCP fd set): **exactly one** TCP
endpoint — `127.0.0.1:3484 (LISTEN)`. No other port, no ESTABLISHED
connections. `listen-all.txt` (machine-wide) confirms port 3000 does not
appear anywhere on the host, and no pid started by this phase holds any
port other than 3484 (`port3000-check.txt` empty).

### Research Open Question 2 verdict (kanban/telegram local RPC coexistence)

- **Resolved for the shipped configuration:** with the token slot empty, the
  telegram service opens no socket at all (Task 2's evidence: zero
  `%cpu`, zero new log lines, zero `connect telegram` processes for the
  whole observation window) and starts no RPC host. A port clash between
  the two Phase 5 services is therefore structurally impossible in the
  configuration this phase ships, not merely unobserved.
- **Measured:** kanban itself holds exactly one TCP endpoint —
  `127.0.0.1:3484` — and nothing else. This is the concrete input Phase 6
  needs: kanban's footprint is a single fixed port, never `auto`, never
  3000.
- **Residual, handed to Phase 6 by name:** once a real token is injected,
  the telegram connector DOES start an RPC host. Re-run this same
  inventory (`lsof -nP -p <pid> -iTCP`) with both services live before
  opening anything to the network. If the connector's RPC address collides
  with kanban's 3484 or with anything else already bound, the sanctioned
  fix is `--rpc-address <host:port>` / `CLINE_RPC_ADDRESS` (confirmed
  present on the connector's flag surface via `strings` in an earlier
  phase) — never moving kanban off 3484, never port 3000.

## Process hygiene — final state

- `lsof -nP -iTCP:3484 -sTCP:LISTEN` — empty at the end of the plan.
- `lsof -nP -iTCP:8999 -sTCP:LISTEN` — empty (throwaway HTTP server torn down).
- No `run_kanban_service.sh` / `run_telegram_service.sh` / `wait_for_upstream.sh` / `wait_for_port.sh` / `python3 -m http.server 8999` processes remain (`ps aux` swept clean).
- flashnext=46573, role-shim=75548, litellm=48525 — unchanged from the plan's start to its end.
- `bash phase-02/infra/verify_no_regression.sh` (re-run at the end): `INF03: PASS`.
- `bash -c 'source phase-03/sandbox/config.env; [ -z "$EXTRA_ALLOW_PATHS" ]'` — exits 0.
- `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` — empty.
- `cline` invocations used: **0**.
