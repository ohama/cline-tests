# NET-04 standalone refusal proof (no launchd involved)

Both runs invoke `phase-05/services/run_telegram_service.sh` directly by hand
(never through launchd, never through `restart_service.sh`), using
`$NET04_PROBE_TOKEN` from `phase-06/net/config.env` — a deliberately invalid
literal (`000000:NET04-GUARD-PROBE-NOT-A-REAL-TOKEN`) that is never
transmitted anywhere, because in the negative case the guard fires before
`exec` and in the positive case the run is killed before `exec` is ever
reached (see the positive-control note below).

## Negative control — token present, allowed-user-id ABSENT

```
env -u TELEGRAM_ALLOWED_USER_ID \
    TELEGRAM_BOT_TOKEN="$NET04_PROBE_TOKEN" \
    bash phase-05/services/run_telegram_service.sh
```

- exit code: 1 (`negative.rc`)
- duration: 0s (well under the ~2s bound; the guard precedes the up-to-300s
  upstream wait entirely)
- stderr (`negative.err`) contains exactly 1 `ABORT-NET04` line
- `pgrep -f 'connect telegram' | wc -l` == 0 during and after
- no new `cline` process was ever created (`pgrep -fc cline` == 0 both
  before and after)
- `negative.out`/`negative.err` contain no Telegram API text
  (`api.telegram`/`telegram.org` grep: 0 hits)

## Positive control — token present, allowed-user-id PRESENT (123456789)

```
env TELEGRAM_ALLOWED_USER_ID=123456789 \
    TELEGRAM_BOT_TOKEN="$NET04_PROBE_TOKEN" \
    FLASHNEXT_PORT="$TS_SERVE_SCRATCH_PORT" \
    bash phase-05/services/run_telegram_service.sh
```

- The guard did NOT fire: `positive.err` contains 0 `ABORT-NET04` lines.
- **Deliberate safety override, not in the plan text verbatim, documented
  here as a Rule-3 deviation:** the live upstream (flashnext) is genuinely
  healthy right now, so `wait_for_upstream.sh`'s three stages would all pass
  in well under a second and this run would race straight through to
  `exec ... cline connect telegram -k <probe-token> --allowed-user-id
  123456789 ...` — a REAL cline invocation and a real (failing-token) call
  to the live Telegram API. That would violate this plan's explicit "cline
  budget is 0" house rule. To make the "proceeds past the guard into
  wait_for_upstream.sh, then gets killed there" proof deterministic instead
  of a race, `FLASHNEXT_PORT` was overridden to `$TS_SERVE_SCRATCH_PORT`
  (59999, confirmed unclaimed via `lsof` immediately before use — the same
  scratch port `06-01`/`06-03` use to exercise Tailscale Serve syntax) so
  Stage 1 (TCP) of `wait_for_upstream.sh` can never succeed. This guarantees
  the process is parked inside `wait_for_upstream.sh`'s retry loop for the
  entire run — never racing toward `exec` — while still genuinely proving
  the guard did not fire.
- Bounded with `timeout -k 2 15 ...`: run was killed by the timeout bound
  (exit code 124 = SIGTERM sent at 15s, `-k 2` grace before SIGKILL),
  duration ~16s.
- `pgrep -f 'connect telegram' | wc -l` == 0 during and after.
- `pgrep -fc cline` == 0 both before and after — cline was NEVER executed in
  this run.
- The five live upstream/kanban/telegram pids (flashnext 46573, litellm
  48525, kanban 53894, role-shim 75548, telegram-connect 96924) were
  unchanged before and after both controls above.

## Conclusion

The refusal is enforced by `phase-05/services/run_telegram_service.sh`, not
by the cline binary — cline 3.0.53 starts happily without the flag
(re-confirmed live during `06-RESEARCH.md`). The negative control proves the
wrapper refuses, loudly and in well under 2 seconds, before cline is ever
executed. The positive control proves the guard discriminates rather than
always refusing: with a numeric allowed-user-id present, the exact same
guard code path is passed through silently and the wrapper proceeds into the
upstream readiness wait — the next stage of the real startup sequence — and
was deliberately, deterministically killed there rather than being allowed to
reach `exec cline`.
