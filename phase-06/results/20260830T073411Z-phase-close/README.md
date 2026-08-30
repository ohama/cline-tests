# Phase 6 close — full gate sweep (06-06 Task 3)

Every standing gate in the project, run in one pass with the network OPEN (`tailscale serve
:8444 -> 127.0.0.1:18484 (kanban-proxy) -> 127.0.0.1:3484 (kanban)`), no mutating `tailscale`
command issued anywhere in this plan.

## Results

| Gate | Command | Result | Evidence |
|---|---|---|---|
| Phase 6 network gate | `verify_network.sh --out-dir gate-network --baseline <06-01 baseline>` | exit 0, `CASES 24/24` | `gate-network/` |
| Phase 5 standing gate | `verify_services.sh --out-dir gate-services` | exit 0, `CASES 15/15` | `gate-services/` |
| INF03 regression | `verify_no_regression.sh --out-dir gate-no-regression` | exit 0, `INF03: PASS` | `gate-no-regression/` |
| Sandbox boundary | `verify_sandbox.sh --out-dir gate-sandbox` | exit 0, 4/4 CRITERION, 16/16 CASES, 0 CRASHED | `gate-sandbox/` |
| Config guard | `verify_config.sh` | exit 0 on first attempt, no heal needed | `gate-config/verify_config-out.txt` |
| Earlier-phase suites | `pytest phase-03/tests/ phase-04/tests/ -q` | 24/24 passed | `gate-config/pytest-out.txt` |
| `check_versions.sh` | not run | optional per plan; not needed since `verify_config.sh` passed on the first attempt with no drift to heal | — |
| Invariants | see below | all PASS | `invariants/` |
| Criteria map | five ROADMAP Phase 6 criteria re-read against 06-01..06-05 evidence | 3 `met`, 2 `human_needed` (criteria 1, 5) | `criteria.md` |

## Invariants (`invariants/`)

- `AllowFunnel` — exactly one key, `ohama-2.tail318f12.ts.net:8443`, unchanged since 06-01 —
  PASS (`invariants/invariants.txt`)
- Port 3000 — zero listeners — PASS
- kanban — listening only on `127.0.0.1:3484` — PASS
- The all-interfaces wildcard-bind IPv4 literal (four zero octets, dotted) anywhere under
  `phase-05/` or `phase-06/` — 0 hits — PASS. **Self-reference note**: this file's own first
  draft of `invariants.txt` briefly created a 1-hit self-match by spelling the searched-for
  literal in its own section header; caught and reworded before this was recorded as evidence
  (see the file's own header text now). This README's own wording above was deliberately phrased
  to avoid the same trap a second time.
- Public-exposure subcommand literal anywhere under `phase-06/net/` — 0 hits — PASS
- `EXTRA_ALLOW_PATHS` — live value empty — PASS. `grep -rn 'EXTRA_ALLOW_PATHS=' phase-06/`
  reports 2 hits, both pre-existing, both self-referential prose inside already-closed 06-04.1/
  06-04.2 evidence READMEs describing the grep command itself (documented, not fixed, in both of
  those plans' own SUMMARYs) — not a new occurrence introduced by this plan, and not part of this
  task's formal `<verify>` gate. The actual guarantee (the environment variable's value staying
  empty) holds and is independently reconfirmed above.
- Six live pids unchanged from the 06-01 baseline except telegram-connect, which restarted in
  06-02 (NET-04 guard proof + restore) and stayed at that same pid through 06-05's `decline`
  decision (no restart in 06-05) — flashnext 46573, litellm 48525, role-shim 75548, kanban 53894,
  telegram-connect 99162, kanban-proxy 19669 — PASS, two samples ~18s apart, both labels
  `state = running` throughout (`invariants/pid-sample-1.txt`, `pid-sample-2.txt`) — no
  crash-looping.
- `git diff --stat phase-01/ phase-02/ phase-03/ phase-04/` — empty — PASS
  (`invariants/git-and-sync.txt`)
- `bash ~/local-llm-settings/sync.sh --check` — exit 0 — PASS (same file)

## `cline` budget

Zero `cline` invocations this plan (Task 1/2 are documentation only; Task 3 ran only read-only
verification scripts and one optional-but-skipped `check_versions.sh`). Phase 6's cumulative
`cline` invocation count across all eight plans stays at 0.

## ROADMAP update

`.planning/ROADMAP.md` Phase 6: all eight plan checkboxes marked `[x]`, phase header marked
`[x]`, Progress table row updated to `8/8` / Complete — with an explicit note that criteria 1 and
5 remain human-verify items, never marked `met`.

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30*
