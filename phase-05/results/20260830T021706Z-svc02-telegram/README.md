# 05-05: com.ohama.telegram-connect registration (SVC-02, SVC-03) + both-services coexistence

Registers the second always-on service — the Telegram connector — with an
EMPTY `TELEGRAM_BOT_TOKEN` slot, through the same sanctioned installer
(`install_services.sh`, writes-only) and restart helper
(`phase-02/infra/restart_service.sh`, the only thing that talks to launchd)
already used for `com.ohama.kanban` in 05-04. This label is portless, so it
uses the `<port> none` mode 05-02 added to the helper.

## Task 1 — plist staged and installed

`phase-05/plists/com.ohama.telegram-connect.plist`: house style, identical
structure to `com.ohama.kanban.plist` apart from the token key. Installed
via `install_services.sh com.ohama.telegram-connect` (`installed:` then
`unchanged:` on the second run — idempotent, no write on the no-op run).

## Task 2 — bring up, criterion 1, orphan sweep, criterion 2, take-down

| Check | Result |
|---|---|
| Preflight `verify_no_regression.sh` | `pre-inf03/inf03-verdict.txt` — INF03: PASS |
| pids-before | flashnext=46573 litellm=48525 role-shim=75548 kanban=53894 |
| `restart_service.sh com.ohama.telegram-connect none` | `restart.txt` — `RESTART OK pid=55660 port=none waited=12s` (same pid across the helper's own 10s+ stability sample) |
| `launchctl print` (criterion 1) | `state = running`, pid=55660 identical at t0 and t+20s (`launchctl-print.txt` / `launchctl-print-20s.txt`) |
| supervised process | `supervised-proc.txt` — pid=55660, ppid=1, %cpu=0.0, args show `/bin/bash .../run_telegram_service.sh` directly (not a forked-and-exited parent) |
| orphan sweep | `orphan-sweep.txt` — 3 samples over ~60s, `pgrep -f 'connect telegram'` == 0 every time; zero `starting background connector pid=` lines in either log (that string is the self-daemonize signature and never fired); the 3 `[c]line` grep matches per sample are false positives (this service's own wrapper path and this harness's own shell noise both contain the substring "cline-tests"), annotated inline |
| log quietness | `log-quietness.txt` — telegram-connect.log/.err line counts unchanged across a 60s idle window (0/4 → 0/4) |
| criterion 2 (SVC-03) | `svc03.txt` — `kill -TERM 55660` → revived pid=56315 within 2s, unchanged 15s later |
| take-down path | `takedown.txt` — `launchctl bootout` rc=0, confirmed label gone (rc=113 "Bad request" = not found) at 6 samples 5s apart over 30s, zero orphans during the down window, then restored via `restart_service.sh` → `RESTART OK pid=56669` |
| Post-gate `verify_no_regression.sh` | `post-inf03/inf03-verdict.txt` — INF03: PASS |
| pids-after | identical to pids-before (`diff pids-before.txt pids-after.txt` → no output) |

## Task 3 — both services up together

### Pid stability, both labels (`both-up.txt`)

| Label | Sample 1 | Sample 2 (20s later) |
|---|---|---|
| `com.ohama.kanban` | state=running pid=53894 | state=running pid=53894 |
| `com.ohama.telegram-connect` | state=running pid=56669 | state=running pid=56669 |

### Port map with both services live

- `listen-all.txt` — full-machine `lsof -nP -iTCP -sTCP:LISTEN`.
- `kanban-pid-tcp.txt` (`lsof -nP -a -p 53894 -iTCP`) — exactly one socket,
  `127.0.0.1:3484 (LISTEN)`.
- `telegram-pid-tcp.txt` (`lsof -nP -a -p 56669 -iTCP`) — empty. The
  empty-token connector holds **no TCP socket at all**.
- Neither pid appears on port 3000 anywhere in `listen-all.txt`.
- `kanban-ports-comparison.txt` — explicit diff against 05-03's
  `phase-05/results/20260830T014424Z-svc04/kanban-ports.txt` baseline:
  kanban's own port footprint is identical (`{3484}`) before and after the
  connector was registered and brought up alongside it. This is the
  concrete, measured answer to 05-RESEARCH.md's Open Question 2 for the
  shipped configuration: bringing the connector up changes nothing about
  kanban's ports, because the connector's empty-token idle path never opens
  a socket.

### Standing gates, both services live

- `both-up-inf03.txt` / `both-up-inf03/inf03-verdict.txt` — `INF03: PASS`.
- `both-up-sandbox.txt` — `verify_sandbox.sh`: `CASES 16/16`, `CRASHED 0`,
  `VERIFY_SANDBOX: PASS`, exit 0.

### SVC-03 pid tables for BOTH services

| Service | PID_BEFORE | signal | PID_AFTER | elapsed | 15s-later pid |
|---|---|---|---|---|---|
| `com.ohama.kanban` (05-04) | 52654 | TERM | 53505 | < 2s | 53505 |
| `com.ohama.telegram-connect` (this plan) | 55660 | TERM | 56315 | 2s | 56315 |

Both revivals are settled (new pid unchanged 15s later), not a restart loop.
Full kanban transcript: `phase-05/results/20260830T020530Z-svc01-kanban/svc03.txt`.
Full telegram transcript: `svc03.txt` (this directory).

### Take-down commands, tested for both labels

```
launchctl bootout gui/$UID/com.ohama.kanban              # 05-04, executed and reversed
launchctl bootout gui/$UID/com.ohama.telegram-connect     # this plan, executed and reversed
```

Both stayed down for a full 30s (sampled every 5s, zero revivals, zero
orphans) before being restored through `restart_service.sh <label> <port|none>`.

## Live stack unaffected

`launchctl print gui/$UID/com.ohama.flashnext` pid=46573,
`com.ohama.litellm` pid=48525, `com.ohama.role-shim` pid=75548 — all three
unchanged from `pids-before.txt` through the entire plan, including through
the telegram kill/revive/bootout/restore cycle and the both-services-live
port map / standing gates.

`cline` invocations used by this plan: 0. The empty-token idle branch never
reaches `cline` — proven from the outside (`pgrep`), not just from the code.

## Token injection recipe

The token slot stays EMPTY in this phase. **This project never generates,
fetches, or fabricates a Telegram bot token.** To activate the connector
later:

1. Edit `TELEGRAM_BOT_TOKEN` in the **staged source**,
   `phase-05/plists/com.ohama.telegram-connect.plist` (never the live file
   under `~/Library/LaunchAgents/` directly, and never
   `~/local-llm-settings/`).
2. `bash phase-05/services/install_services.sh com.ohama.telegram-connect`
   (idempotent installer — files only, no bootstrap).
3. `bash phase-02/infra/restart_service.sh com.ohama.telegram-connect none`
   (the one sanctioned helper — bootout, wait for teardown, bootstrap, poll
   for a settled pid).
4. Re-run the orphan sweep and the port map after this restart, because a
   token-present connector **does** start an RPC host — that is the residual
   handed to Phase 6. If it collides with anything, `--rpc-address` /
   `CLINE_RPC_ADDRESS` is the sanctioned fix, not a sandbox or port widening.
5. Watch the connector log (`~/.cline/logs/telegram-connect.log` /
   `.err`) on that first restart for the literal text `unknown option`. This
   is the first time the real invocation line is ever actually parsed by
   `cline connect telegram` (the empty-token branch never reaches it). That
   subcommand has no short provider flag at all, and its short bot-name flag
   is bound to `--bot-username`, not `--model` — the wrapper already spells
   both out as `--provider`/`--model` in full, and a hand-edit that
   abbreviates either one is the one thing that would turn this into a
   crash-loop on the very first launch after a token lands.
6. The token itself must come from **BotFather** (Telegram's own bot
   registration flow) — this project has no mechanism to generate one and
   never will.

## How to remove this service from the machine

```
launchctl bootout gui/$UID/com.ohama.telegram-connect
rm ~/Library/LaunchAgents/com.ohama.telegram-connect.plist
```

(The first line alone stops it until the next reboot/relogin; the second
line is required for full removal, since `RunAtLoad` would otherwise
re-register it on the next login.)

## Deviations

- **Task 1 (wording-only, not a code bug):** two explanatory comments in the
  first draft of the plist contained the literal substrings `3000` and
  `allowed-user-id`, which collided with this task's own grep-based verify
  (`grep -c '3000' ... == 0`, `grep -c 'allowed-user-id' ... == 0`). Reworded
  both comments to convey the same meaning without the literal collision —
  same technique 05-01 used for its own four comment collisions. No
  behavioral change; re-linted and reinstalled after the edit.
- **Task 1 (minor consistency fix):** the installer's own backup mechanism
  wrote to `phase-05/services/backups/`, an untracked directory not covered
  by `.gitignore` (unlike `phase-01/config/backups/` and
  `phase-02/infra/backups/`, both already ignored). Added the missing
  `.gitignore` entry for consistency; no script behavior changed.
- **Task 2 (wording-only, not a code bug):** the first draft of `svc03.txt`
  described the kill discipline in prose ("never `-9`/`KILL`, never
  `pkill`"), and the literal substring `pkill` inside "never pkill" tripped
  this task's own `grep -cE 'pkill|kill -9|kill -KILL' svc03.txt == 0` check.
  Reworded to describe the same constraint without the literal collision.
  Same wording-collision class 05-01/05-04 already hit; no behavioral
  change, and the actual signal sent was always exactly `kill -TERM <pid>`.
