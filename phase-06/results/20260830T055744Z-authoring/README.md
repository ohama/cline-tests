# 06-03 Task 3: Offline self-validation against the still-CLOSED posture

Captured: 2026-08-30T05:57:44Z (UTC, this directory's own timestamp prefix)

This directory proves both `phase-06/net/setup_tailscale_serve.sh` and
`phase-06/net/verify_network.sh` behave correctly while the network is still
closed — nothing about the live Tailscale Serve config, kanban's bind, or
any of the five live pids was changed by anything below. The only live
command that touched Tailscale state at all was Step D's single
scratch-port rollback probe (against port 59999, never the real
`TS_SERVE_PORT=8444`), and that probe is proven, byte-for-byte, to have
changed nothing.

## Step A — setup_tailscale_serve.sh --check is a genuine no-op

```
bash phase-06/net/setup_tailscale_serve.sh --check --out-dir "$RD/setup-check"
```

- Exit code: 0
- All six pre-flight assertions (P1-P6) PASSed, printed the exact single
  command `--apply` would run
  (`/opt/homebrew/bin/tailscale serve --bg --https=8444 http://127.0.0.1:3484`),
  and exited without mutating anything.
- `cmp "$RD/setup-check/serve-status-before.json" "$RD/setup-check/serve-status-after.json"`
  exits 0 — byte-identical.

## Step B — verify_network.sh is a genuine, non-vacuous negative control

```
bash phase-06/net/verify_network.sh --out-dir "$RD/gate-closed" \
    --baseline phase-06/results/20260830T051403Z-baseline
```

- Exit code: 1 (not 0, not 2)
- `CASES 13/15`, `CRASHED 0`
- The FAIL-id set, extracted and sorted, is EXACTLY:
  - `kanban-serve-entry-present`
  - `tailnet-https-200`

  — the two checks that can only pass once 06-04 has actually created the
  Serve entry. Every other check (1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14,
  15) PASSed. This is the proof that the gate can genuinely detect the
  absence of the thing Phase 6 is about to create — a gate that fails for
  the wrong reason (or never fails at all) would be worse than no gate.

## Step C — forced-failure probes for the two safety-critical checks

Both probes point the relevant constant at a bogus/mutated value via a
scoped environment override or a temp file copy — never editing
`phase-06/net/config.env` or `phase-06/net/expected_serve_baseline.json`
themselves.

### C1 — `no-new-public-exposure`

```
env EXPECTED_FUNNEL_KEY="bogus-host.tail318f12.ts.net:9999" \
    bash phase-06/net/verify_network.sh --out-dir "$RD/forced-failure/c1-funnel-key" \
    --baseline phase-06/results/20260830T051403Z-baseline
```

- `CHECK: FAIL no-new-public-exposure -- FAIL: AllowFunnel={'ohama-2.tail318f12.ts.net:8443': True} expected exactly {'bogus-host.tail318f12.ts.net:9999': true}`
- The real `AllowFunnel` key was never touched — only the *expectation* was
  overridden, and only for this one subprocess's environment.

### C2 — `preexisting-serve-entries-untouched`

A scratch copy of `expected_serve_baseline.json` was made (outside the
repo, under the session scratchpad) with the `:10000` handler's proxy
target hand-mutated to `http://127.0.0.1:1234`, then pointed to via
`EXPECTED_SERVE_BASELINE`:

```
env EXPECTED_SERVE_BASELINE=<scratch-copy> \
    bash phase-06/net/verify_network.sh --out-dir "$RD/forced-failure/c2-baseline" \
    --baseline phase-06/results/20260830T051403Z-baseline
```

- `CHECK: FAIL preexisting-serve-entries-untouched -- DRIFT:Web[ohama-2.tail318f12.ts.net:10000] drifted: live={'Handlers': {'/': {'Proxy': 'http://127.0.0.1:8788'}}} base={'Handlers': {'/': {'Proxy': 'http://127.0.0.1:1234'}}}`
- `cmp phase-06/net/expected_serve_baseline.json <(git show HEAD:phase-06/net/expected_serve_baseline.json)`
  confirmed the real, committed baseline file was never touched by this probe.

Both probes recorded a FAIL for exactly their targeted check id and left
the real config and the real baseline file untouched.

## Step D — rollback-syntax validation against the scratch port

The fail-closed path gets the same rigor as the two probes above, because
a wrong rollback stays invisible until the exact moment it is needed (a
live failure inside 06-04).

1. **Before capture**: `rollback/serve-before.json` — confirmed no handler
   for port 59999 exists in `Web` or `TCP`.
2. **Unclaimed confirmation**: `lsof -nP -iTCP:59999 | wc -l` == 0
   immediately before use.
3. **The probe itself** — the pinned rollback form, run against the scratch
   port only:
   ```
   tailscale serve --https=59999 off
   ```
   - exit code: 1 (`rollback/rollback-exitcode.txt`)
   - stdout: empty (`rollback/rollback-stdout.txt`)
   - stderr (`rollback/rollback-stderr.txt`, warning-line included verbatim
     for the record):
     ```
     Warning: client version "1.96.4-t41cb72f27" != tailscaled server version "1.96.5-t4ee448d3a-g74ffbefc2"
     error: failed to remove web serve: handler does not exist

     try `tailscale serve --help` for usage info
     ```
   - **This is the SUCCESS signal**: the syntax was ACCEPTED (parsed
     correctly as a valid `--https=<port> off` invocation) and failed only
     because there is genuinely nothing bound to port 59999 to remove.
     There is no unknown-flag / bad-usage parse error anywhere in the
     output — the pinned rollback form (`TS_SERVE_ROLLBACK_CMD` in
     `phase-06/net/config.env`) is confirmed correct for this tailscale
     version (1.96.4).
4. **After capture**: `rollback/serve-after.json` —
   `cmp rollback/serve-before.json rollback/serve-after.json` exits 0:
   byte-identical. The three pre-existing handlers (`:443`, `:10000`,
   `:8443`) and the single `AllowFunnel` key are untouched.

**Pinned rollback command** (never re-derived, from
`phase-06/net/config.env`):

```
"$TAILSCALE_BIN" serve --https="$TS_SERVE_PORT" off
```

`grep -rcE 'serve[[:space:]]+reset' phase-06/net/` == 0 — the destructive
`reset` verb appears nowhere under `phase-06/net/` as a rollback or
otherwise.

## Conclusion

- No Tailscale mutation occurred against the real config during authoring.
  The only live-mutating command run anywhere in this plan was Step D's
  single `serve --https=59999 off` probe against the confirmed-unclaimed
  scratch port, and it is proven byte-for-byte to have changed nothing
  (there was nothing there to change).
- `setup_tailscale_serve.sh --check` (and its no-argument default) are
  provable no-ops.
- `verify_network.sh` is a provable, non-vacuous gate: it fails in exactly
  the two places that depend on 06-04 having run, passes everywhere else,
  and both of its safety-critical checks (`no-new-public-exposure`,
  `preexisting-serve-entries-untouched`) are proven to genuinely detect
  drift when fed a wrong expectation.
- The pinned rollback form is proven accepted by this tailscale version
  against a scratch port, with the three pre-existing entries byte-identical
  afterward — 06-04 may now trust it without re-deriving or re-testing it.
- `git diff --stat phase-05/ phase-03/ phase-02/ phase-01/` is empty —
  nothing outside `phase-06/` was touched by this plan.
