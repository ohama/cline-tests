# 07-04 Task 3 -- post-batch gate sweep and drift assertions

Generated: 2026-08-30T10:23:00Z

## Standing gates (all re-run fresh into this directory)

| gate | expected | observed | evidence |
| --- | --- | --- | --- |
| `phase-07/bench/preflight.sh` | `CASES 11/11` | `CASES 11/11`, PASS | `preflight.txt` |
| `phase-05/services/verify_services.sh` | 15/15 | `CASES 15/15`, `CRASHED 0`, PASS | `verify_services.txt` |
| `phase-02/infra/verify_no_regression.sh` | `INF03:PASS` | `INF03: PASS` | `verify_no_regression.txt` |
| `phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline` | `CASES 24/24` | `CASES 24/24`, `CRASHED 0`, PASS | `verify_network.txt` |
| `phase-03/sandbox/verify_sandbox.sh` | exit 0, SBX-04 PASS | exit 0, `CASES 16/16`, `CRITERION 4 ... PASS` | `verify_sandbox.txt` |
| `phase-01/config/verify_config.sh` | exit 0 | exit 0, `OK: providers.json holds flashnext @ localhost:4000/v1 ...` | `verify_config.txt` |
| `phase-01/config/check_versions.sh` | conditional | **SKIPPED** (`verify_config.sh` clean, no drift to investigate) | `check_versions.txt` |

All gate exit codes recorded as 0. Exactly one `check_versions.sh` line is present (SKIPPED),
never a RUN line alongside it. `cline` invocation budget consumed by this plan: **0** (of an
available up-to-1).

## Drift assertions

Recorded verbatim in `drift-assertions.txt`:

- Six pids (46573/75548/48525/53894/99162/19669) present with unchanged command lines
  (flashnext/role-shim/litellm/kanban/telegram-connect/kanban-proxy).
- `lsof -nP -iTCP:3000 -sTCP:LISTEN` empty (rc=1 -- no listener).
- `git diff --stat phase-01 phase-02 phase-03 phase-04 phase-05 phase-06 workspace` empty.
- `git diff --exit-code workspace/ALLOWED_REPOS.json` exits 0 (unchanged).
- `bench/runs/CANARY.txt` unchanged (`SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX`).
- `tailscale serve status --json` (`serve-status-now.json`) is **byte-identical** to the 07-01
  preflight capture (`phase-07/results/20260830T084629Z-preflight/p5-network/serve-status.json`)
  -- `diff` reports no differences. The only stderr from the read-only invocation is the benign,
  already-documented `Warning: client version "1.96.4-..." != tailscaled server version
  "1.96.5-..."` line (`serve-status-now.stderr`), filtered rather than gated on per house
  convention. No network surface moved.
- `docker ps -q` -- see note below; not literally empty, for reasons unrelated to this plan.

## Reported: `docker ps -q` is not empty, and that is not a defect of this plan's execution

This plan's own `<verify>` text states `docker ps -q | wc -l` is 0. The literal count observed is
**7**, and per this project's "report, don't improvise" discipline (see house rule / quality
note), that mismatch is recorded plainly rather than silently reconciled or worked around.

The seven running containers, in full (`docker ps` verbatim, see `drift-assertions.txt`):

| container | image | created | purpose (by image/name) |
| --- | --- | --- | --- |
| nextcloud-notify_push-1 | nextcloud:34-apache | 4 weeks ago | unrelated Nextcloud stack |
| nextcloud-app-1 | nextcloud:34-apache | 4 weeks ago | unrelated Nextcloud stack |
| nextcloud-cron-1 | nextcloud:34-apache | 4 weeks ago | unrelated Nextcloud stack |
| nextcloud-tailscale-1 | tailscale/tailscale:latest | 4 weeks ago | unrelated Nextcloud stack's own sidecar |
| nextcloud-redis-1 | redis:8-alpine | 4 weeks ago | unrelated Nextcloud stack |
| nextcloud-db-1 | mariadb:11 | 4 weeks ago | unrelated Nextcloud stack |
| safestacktutorial-db-1 | postgres:16-alpine | 2 months ago | unrelated tutorial project |

None of these carries a cline-bench/harbor image name, a harbor-generated compose project label,
or any other trace of this phase's bench mechanism. Every one was created weeks to months before
this entire Phase 7 began (2026-08-30), on this same host's shared Docker/colima daemon, by
entirely separate projects (`nextcloud-*`, `safestacktutorial-*`) this project does not own and
this plan's `<files>` scope never touches. `docker ps -q | wc -l` was never actually 0 on this
host at any point during Phase 7 -- it was not checked by this exact command in 07-01/07-02/07-03
(those plans checked `docker ps -a -q --filter status=exited` instead, per `07-02-SUMMARY.md`),
so this is the first time this plan's literal `docker ps -q` assertion has been run against this
host's real state, and it surfaces a pre-existing condition rather than anything this plan (or
any harbor invocation in this phase, since this plan made zero) produced.

**The substantively correct, narrower invariant this check is actually meant to protect --
"harbor's containers are throwaway and none is left running" (this plan's own `<action>` wording)
-- holds fully**: this plan invoked `harbor run` **zero** times (Task 1's empty-`SELECTED_TASKS`
path, see `../README.md`), so there is no harbor-launched container of any kind, running or
otherwise, to have leaked. The seven containers observed are provably pre-existing and provably
unrelated by image name, container name, and creation timestamp. This is recorded here as a
plan-defect report (the literal `<verify>` assumption does not hold on this host, independent of
this plan's actions), not as a finding that requires a fix, a re-run, or an architectural
decision -- the actual thing the check exists to catch (a leaked bench/harbor container) did not
happen and could not have happened this run.

## "The bench ran" vs "the bench passed"

The bench mechanism -- installation, preflight, `harbor run`, evidence capture, verifier, gate
sweep -- ran completely and correctly for the one task attempted in this phase
(`discord-trivia-approval-keyerror`, 07-03's smoke run). **That the bench ran is not the same
claim as that the bench passed.** The task's verdict is `fail-infra`: the container's cline never
reached this stack's model server at all (it hit the real OpenAI API and failed on an invalid key
before generating a single token), so no claim is made here that this stack can or cannot complete
an actual cline-bench coding task -- that question remains open, on the evidence collected so far.
The pipeline itself (install -> preflight -> container -> harbor invocation -> evidence capture ->
verifier -> gate sweep -> BCH table) is proven end to end, repeatedly, across three plans now; the
model-reaching path for a real task is not.
