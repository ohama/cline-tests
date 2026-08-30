# Phase 5 — ROADMAP criteria to evidence map

Generated at phase-close (05-07 Task 1), re-reading the four ROADMAP Phase 5 success criteria
against the evidence directories produced across 05-03/04/05/06 plus this plan's own sweep.

## Criterion 1

> `launchctl print gui/$UID/<label>` 로 Kanban·Telegram 두 서비스 라벨이 모두 조회되고 상태가
> running 이다; 재부팅 후에도 동일하게 확인된다

**Status: PARTIALLY evidenced — the non-reboot half is PASS by live measurement; the reboot half
is PROXY ONLY, pending the Task 3 human decision. Never write "reboot-verified" for this half
until an actual reboot has happened.**

Non-reboot half (both labels report `running`, pids stable):
- `phase-05/results/20260830T020530Z-svc01-kanban/launchctl-print.txt`,
  `launchctl-print-t20.txt` — kanban pid stable 20s apart
- `phase-05/results/20260830T021706Z-svc02-telegram/launchctl-print.txt`,
  `launchctl-print-20s.txt` — telegram-connect pid stable 20s apart
- `phase-05/results/20260830T024606Z-phase-close/services-gate/` — this sweep's own
  `verify_services.sh` run, `kanban-state-running`/`kanban-pid-settled`/
  `telegram-state-running`/`telegram-pid-settled` all PASS with 3 samples over ~20s

Reboot half (proxy only — see `docs/services.md` §4 for the full honest statement):
- `phase-05/results/20260830T020530Z-svc01-kanban/` — kanban's own bootout -> teardown-confirmed
  -> bootstrap -> healthy cycle
- `phase-05/results/20260830T021706Z-svc02-telegram/takedown.txt` — telegram-connect's own
  bootout -> teardown-confirmed (30s, 6 samples) -> restore cycle
- Both plists carry `RunAtLoad: true` (`phase-05/plists/com.ohama.kanban.plist`,
  `phase-05/plists/com.ohama.telegram-connect.plist`) and live under
  `~/Library/LaunchAgents/`, confirmed enabled (not in `launchctl print-disabled`)
- **What this does NOT prove:** actual behavior across a real macOS reboot (login-session
  ordering, `:4000` readiness at that moment) — no reboot has occurred in this phase.
- **Decision recorded:** see "Task 3 decision" section below, filled in on continuation.

## Criterion 2

> 두 서비스 중 하나를 강제 종료(`kill`)하면 launchd 가 `KeepAlive` 로 다시 살려낸다

**Status: PASS**

- `phase-05/results/20260830T020530Z-svc01-kanban/svc03.txt` — `kill -TERM <exact kanban pid>`,
  revived within 2s, unchanged 15s later
- `phase-05/results/20260830T021706Z-svc02-telegram/svc03.txt` — `kill -TERM <exact telegram
  pid>`, revived within 2s (pid 55660 -> 56315), unchanged 15s later

## Criterion 3

> flashnext 서비스를 잠시 내린 상태에서 두 서비스를 기동해도 크래시루프 없이 재시도를 반복하다
> flashnext 가 뜨면 정상 연결된다

**Status: PASS**

- `phase-05/results/20260830T014424Z-svc04/deadport-rc.txt`,
  `deadport-lsof.txt`, `deadport-ps.txt` — hard dead-port case: exit 1 at ~36-41s against a 30s
  configured timeout, `%cpu` 0.0 every sample, kanban never spawned (no crash loop, bounded
  retry-then-fail)
- `phase-05/results/20260830T014424Z-svc04/notready-*.txt` — listening-but-not-ready case (a
  throwaway TCP listener on :8000 without a real health/alias): health-stage and alias-stage each
  correctly rejected it by name, exit 1 at ~20-25s
- `phase-05/results/20260830T014424Z-svc04/recovery-wait.txt`,
  `recovery-lsof.txt` — no-override recovery run against the real production stack: kanban
  actually bound `127.0.0.1:3484` once flashnext/litellm/role-shim were healthy
- `phase-05/services/wait_for_upstream.sh` — the 3-stage readiness gate all of the above
  exercises (TCP -> flashnext `/health` `loaded_model` -> litellm alias advertisement), reused
  unchanged by `run_kanban_service.sh` and `run_telegram_service.sh`

## Criterion 4

> 두 plist 파일이 `~/local-llm-settings/launchagents/` 에 존재하고, `sync.sh` 실행 결과에
> 반영돼 있다

**Status: PASS**

- `phase-05/results/20260830T023144Z-svc05/sync.sh.diff` — the additive `LABELS` array edit
- `phase-05/results/20260830T023144Z-svc05/synccheck-after.txt` — `sync.sh --check` exits 0
  post-edit (was a vacuous PASS before, captured in `synccheck-before.txt`, with both new plists
  untracked)
- `phase-05/results/20260830T023144Z-svc05/mirror-state-md.txt` — mirror's own regenerated
  STATE.md lists both labels running/boot-enabled plus the new 3484 port row
- `phase-05/results/20260830T024606Z-phase-close/services-gate/` — this sweep's own
  `mirror-labels-tracked`/`mirror-plists-byte-identical` checks, both PASS

## Task 3 decision

Decision id: _pending — recorded verbatim here and in `docs/services.md` §4 by the continuation
agent once the user has chosen._
