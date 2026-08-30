# Task 3 post-gate sweep (07-07)

All seven standing gates re-run after the one `harbor run` in this plan. Six live pids,
port 3000, CANARY.txt, and `git diff` re-asserted directly (not through a sub-gate script).

| Gate | Result |
| --- | --- |
| `preflight.sh` | CASES 11/11, PREFLIGHT: PASS |
| `verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07` (pre-fix) | CASES 10/10, VERIFY_BENCH: PASS, B11 SKIP (pre-fix `cw_injection=applied`, not counted) |
| `verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix` (post-fix, new) | CASES 10/11, VERIFY_BENCH: FAIL (B5 fails -- `summary.md` was never generated for this single-task run dir, out of this plan's scope; **B11: PASS**, the decisive check for this plan) |
| `verify_services.sh` | CASES 15/15, CRASHED 0, PASS |
| `verify_no_regression.sh` | INF03: PASS |
| `verify_sandbox.sh` | CASES 16/16, CRASHED 0, CRITERION 4 (SBX-04) PASS -- re-asserted AFTER the new run directory exists under `bench/runs/` |
| `verify_network.sh --baseline "$NET_BASELINE"` | CASES 24/24, CRASHED 0, PASS |
| `verify_config.sh` | exit 0, clean on first attempt -- `check_versions.sh` NOT run (banned this plan; host `cline` invocation budget is 0) |

## Direct re-assertions (not gate scripts)

- `cat bench/runs/CANARY.txt` -- prints its original single line
  (`SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX`), unchanged.
- Six live pids (46573/75548/48525/53894/99162/19669) all present, unchanged.
- Port 3000: `lsof -nP -iTCP:3000 -sTCP:LISTEN` empty (unbound).
- `git diff --stat phase-01 phase-02 phase-04 phase-05 phase-06 workspace` -- empty.

## Note on the B5 FAIL for the new run directory

`verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix` reports `CASES 10/11` (not
`11/11`) because check B5 (BCH-03: `summary.md` table) fails -- `make_summary.sh` was never run
against this single-task run directory, which is outside this plan's scope (Task 2 only required
running and evidencing one task, not regenerating the suite-level summary). This is expected and
does not affect this plan's decisive signal: **B11 (reached-the-model) reports PASS** for this run
directory, which is the check this plan added and the one `PROOF.md` relies on.
