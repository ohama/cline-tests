# kanban-pid baseline reconciliation (2026-08-31, 08-06)

`phase-08-01-SUMMARY.md`/`08-04-SUMMARY.md` both left `verify_network.sh` (check 15,
`live-pids-stable`) and `verify_bench.sh` (check B10) failing exactly one check each, because
both compare the live kanban pid against a fixed pre-Phase-8 value of `53894`, which 08-01's
sanctioned live restart (`phase-02/infra/restart_service.sh com.ohama.kanban 3484`) legitimately
changed to `36175`. Both prior plans explicitly left this to whichever plan next "touched" the
two files that own those hardcoded values, rather than editing files outside their own declared
scope.

08-06 is that plan (phase-close for the whole milestone). Two files were updated:

1. `phase-06/results/20260830T051403Z-baseline/inventory.txt` — the file
   `phase-06/net/verify_network.sh --baseline <dir>` reads for check 15. A new
   `=== RECONCILED (2026-08-31, 08-06 phase-close) ===` block was inserted **before** the
   original 2026-08-30T05:14:03Z capture, containing one line with kanban's current pid (36175)
   in the same `ps`-style format the check's parser expects (`grep -F` + `head -1` picks up this
   new line first). The original transcript below — including the historical pid 53894 — is
   byte-for-byte unchanged. `phase-06/results/20260830T051403Z-baseline/README.md`'s "Live
   pids" line was left as originally captured, with a reconciliation footnote added directly
   below it.
2. `phase-07/bench/config.env` — `LIVE_PIDS_STR`'s default was updated in place from
   `... 53894 ...` to `... 36175 ...` (with a dated comment explaining why), since B10 and
   `preflight.sh`'s P1 read this constant as a live expectation, not an audit transcript.

Neither edit touches `phase-03/`, `EXTRA_ALLOW_PATHS`, `ALLOWED_REPOS.json`, or any live
service. No check was removed or weakened — both gates now pass because the recorded
expectation matches the live, sanctioned reality, exactly as `docs/services.md` §5a and
`phase-08/results/20260830T191320Z-kanban-fix/` already documented as fact.

Post-fix: `verify_network.sh` → `CASES 24/24` (was 23/24). `verify_bench.sh` → `CASES 11/11`
(was 10/11). See `gates/exit-codes.txt`, `gates/verify_network.txt`, `gates/verify_bench.txt`.
