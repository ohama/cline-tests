# APPLIED

Plan `07-15` (gap closure, wave 14). Dispatches on the selection recorded at
`phase-07/results/20260831T011037Z-remediation/DECISION.md`.

## Selection read and confirmed

```
SELECTION: doc-only
```

Read verbatim from `DECISION.md` before any other action in this plan. This is one of the four
canonical labels the plan recognizes (`doc-only`, `config-change`, `config-change-plus-run`,
`accept-limit`), so no blocker condition applies. `doc-only` dispatches to: **change nothing,
document the findings.**

## What was done

Nothing was changed. Per the plan's dispatch text: "Read `DECISION.md`'s `SELECTION:` FIRST — if
it is `doc-only` or `accept-limit`, skip these live-service checks entirely and go straight to the
dispatch below; the checks exist only to protect a write." Because `doc-only` performs no write,
the live-service in-flight precondition checks (`pgrep` for stray `cline` processes, kanban/
telegram log mtimes) were **not run** — they exist solely to protect a write to
`~/.cline/data/settings/providers.json`, and no such write occurs on this branch. This is a
deliberate skip specified by the plan, not an omission.

- `phase-01/config/apply_provider_config.sh` was **not** invoked.
- `settings.contextWindow` was **not** changed — it remains `29000`.
- No production file under `phase-01/`, `~/.cline/data/settings/`, or anywhere else outside
  `phase-07/results/` was touched.
- No live bench task was run (not authorized — that requires `SELECTION: config-change-plus-run`).
- No model call was made.
- No `cline` or `kanban` binary was invoked at any point in this plan.

## Before / after config state

| | value |
|---|---|
| `settings.contextWindow` before | `29000` (unchanged) |
| `settings.contextWindow` after | `29000` (unchanged) |
| `providers.json` sha256 before | `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214` |
| `providers.json` sha256 after | `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214` |

Before/after hashes are byte-identical — confirmed with a second `shasum -a 256` read at the end
of this plan (see below). The raw copy is preserved at `pre/providers.json.bak` and the pre-hash
at `pre/providers-hash.txt` regardless, per the plan's "before anything else" instruction, even
though the doc-only branch never needed to read them for a diff.

## Rollback command

Not needed — nothing was applied. If this record is ever consulted for a rollback, there is
nothing to roll back: `providers.json` was never written by this plan. Had a change been applied,
the recorded command would have been:

```
cp phase-07/results/20260831T020956Z-apply/pre/providers.json.bak ~/.cline/data/settings/providers.json
```

(plus reverting any edit to `phase-01/config/apply_provider_config.sh`, of which there was none).

## Live-service in-flight precondition checks

**Skipped, as specified.** The plan's Task 1 text explicitly gates these checks to the
config-change branches only ("Live-service precondition — gates the config-change branches
only"). Since `SELECTION: doc-only` was read first and dispatches to "change nothing," the checks
protecting a write were never run because no write was ever going to happen. This is the correct
execution of the plan's own dispatch order, not a shortcut around a required check.

## Residual accepted risk

None applicable to this execution: since no write to `~/.cline/data/settings/providers.json`
occurred, there is no window during which `com.ohama.kanban` or `com.ohama.kanban-proxy` could
pick up an as-yet-unvalidated value. The residual-risk scenario described in the plan (a task
starting mid-apply-window) is specific to the config-change branches and does not arise here.

## Regression (Task 2)

**Skipped: no value changed.** `phase-01/results/exp-verify29k/` (18 fillers completed,
0 server 400s, measured at `contextWindow: 29000`) remains the standing, unmodified proof of the
Core Value — it was never invalidated because the value it was measured at never changed. See
`gates/regression-skip.txt` for the recorded skip marker.

## Live bench run (Task 3)

Not authorized. `DECISION.md` records `SELECTION: doc-only`, not `config-change-plus-run`. Zero
live bench tasks were run in this plan. The gap phase's one-live-run budget remains fully unspent.

## Consciously deferred follow-up (recorded here per DECISION.md, not acted on)

`DECISION.md` separately records that `--compaction basic` (Candidate C in
`CANDIDATE-MATRIX.md`) — the one candidate scored as genuinely promising and untested, because it
targets the confirmed non-pruning defect (M4) directly — was deliberately **not** exercised in
this plan. The user's verbatim answer to that separate question was "후속 과제로 기록만" (record
as a follow-up item only). This plan does not widen scope to test it, synthetically or live; it is
named here only so the deferral is visible from `07-15`'s own output, not solely from
`DECISION.md`.

Also per `DECISION.md`: the earlier `phase-01/results/exp-basic/` run must **not** be cited as
prior testing of `--compaction basic`. That run's `contextWindow` sat inside `models[]`, not at
the `settings` top level, so the project's own known 128k-fallback engaged instead of this stack's
real 29,000/32,768 ceiling. It is void as evidence for that lever.

## Host cline pin

- Before: `3.0.53` (read from `$(npm root -g)/cline/package.json`, file read only — the `cline`
  binary itself was never invoked to obtain this, avoiding the self-update drift vector).
- After: `3.0.53` (unchanged — no `cline` invocation occurred anywhere in this plan, so there is no
  opportunity for drift to have occurred).

## Live run not authorized (Task 3)

`DECISION.md` records `SELECTION: doc-only`, not `config-change-plus-run`. **Live run not
authorized.** No task was run, no new directory was created under `bench/runs/`, and
`gates/memory-context.txt` was not produced (it is only required when a live run occurs). The gap
phase's one-live-run budget remains fully unspent — confirmed by `bench/runs/` containing only its
two pre-existing directories (`20260830T093657Z-phase07/`, `20260830T122809Z-phase07-fix/`) plus
`CANARY.txt`, unchanged.

## Standing gate sweep (Task 3, always run)

All read-only, captured to `gates/`:

| Gate | Result | Expected | File |
|---|---|---|---|
| `phase-01/config/verify_config.sh` | exit 0, OK | contextWindow=29000, no models[] override | `gates/verify_config.txt` |
| `phase-02/infra/verify_no_regression.sh` | exit 0, INF03 PASS | INF03: PASS | `gates/verify_no_regression.txt` |
| `phase-03/sandbox/verify_sandbox.sh` | exit 0, CASES 16/16, CRITERION 4 PASS | 16/16, CRITERION 4 PASS | `gates/verify_sandbox.txt` |
| `phase-05/services/verify_services.sh` | exit 0, CASES 15/15 | 15/15 | `gates/verify_services.txt` |
| `phase-06/net/verify_network.sh --baseline .../20260830T051403Z-baseline` | exit 0, CASES 24/24 | 24/24 | `gates/verify_network.txt` |
| `phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix` | exit 0, CASES 11/11 | pass | `gates/verify_bench-fix.txt` |
| `phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07` | exit 0, CASES 10/10 (B11 SKIP — pre-fix run, expected) | pass | `gates/verify_bench-phase07.txt` |

**All standing gates green.** No new run directory existed to sweep (no live run authorized). The
sweep scripts each create their own timestamped artifact directory under their own phase's
`results/` (e.g. `phase-02/results/20260831T021136Z-inf03/`) as their normal read-verification
side effect — this is the scripts' own documented behavior, not a write this plan made, and none
of it touches `bench/runs/*/meta/`, `phase-01/`, or shipped provider configuration.

## Post-execution safety confirmation

- `providers.json` sha256 after sweep: `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214`
  — unchanged.
- Six live service pids unchanged versus `pre/pids.txt`: `com.ohama.flashnext` 46573,
  `com.ohama.role-shim` 75548, `com.ohama.litellm` 48525, `com.ohama.kanban` 36175,
  `com.ohama.kanban-proxy` 19669, `com.ohama.telegram-connect` 99162 (all confirmed by
  `verify_services.sh`/`verify_bench.sh` B10 passing, and by direct `ps -p` re-check).
- `colima status` → "colima is not running" (left stopped throughout).
- `lsof -i :3000` → empty.
- `~/local-llm-settings/` not touched.
- `bench/runs/20260830T122809Z-phase07-fix/meta/` and `bench/runs/20260830T093657Z-phase07/meta/`
  byte-unchanged (no write occurred; `verify_bench.sh` reads only).
- `git status --short phase-01/` empty.
- Zero `cline`/`kanban` invocations across this entire plan.
