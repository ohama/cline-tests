# Failed restart attempts (pre-fix) — evidence note

This directory was meant to preserve the stderr of the two live restart attempts
of `com.ohama.flashnext` that failed before the async-bootout fix.

**`restart-flashnext.txt` and `restart-flashnext-attempt2.txt` are 0 bytes.**
The capture did not tee the helper's stderr, and the files were later committed
empty (commit `4c34cbc`). They contain no evidence. Do not cite them as if they do.

What actually happened, corroborated by the fix itself and by the service logs:

- Both attempts failed at the `bootstrap` step with `Bootstrap failed: 5: Input/output error`.
  `bootout` had already succeeded, so the service was down at that moment.
- The plan's ROLLBACK block was executed verbatim both times; the service came back
  healthy each time (pids 44357 then 44774), `curl /v1/models` 200.
- A control test on a throwaway label (no heavy process to tear down) bootstrapped
  successfully every time, including under rapid cycling — ruling out plist content,
  the `--max-num-seqs` flag, and the `plistlib` rewrite as causes.
- Root cause: `launchctl bootout` is **asynchronous**. It returns when the unload is
  requested, not when the job is gone. `restart_service.sh` went straight from bootout
  to bootstrap with zero wait, and flashnext holds a 104 GiB model, so teardown takes
  real time. Both ROLLBACK bootstraps succeeded because the `cp -p` + `plutil -lint`
  in between happened to give teardown the seconds it needed.
- Fix: commit `0ca2645` added "Step 3b: wait for teardown" — poll until the label leaves
  the domain and the port frees, settle 3s, then bootstrap. The next attempt printed
  `teardown confirmed after 2s` and succeeded at `waited=28s`.

Real, non-empty evidence for this phase:
- `preflight-pre-restart.txt` (in this directory) — the pre-restart state, 5,285 bytes.
- `../20260829T183540Z/` — the uncapped INF-01 baseline.
- `../20260829T185628Z-inf01/` — the decisive INF-01 run after the fix.
- `../20260829T190346Z-inf02/` — INF-02.
