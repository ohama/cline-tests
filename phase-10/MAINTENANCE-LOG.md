# MAINTENANCE-LOG.md — Phase 10 maintenance window, 2026-09-01

Operational record of the one window in this project where `com.ohama.litellm` was restarted and
`/Users/ohama/agent-stack/litellm/config.yaml` was written. Run dir:
`phase-10/results/20260901T082326Z-maintenance/`.

## Timeline (UTC)

| Event | Time (UTC) | Note |
|---|---|---|
| Restart A — T0 (restart_service.sh invoked) | 08:23:26Z | on the **unmodified** live config |
| Restart A — T1 (restart_service.sh returned) | 08:23:34Z | exit 0, `waited=2s` (internal health-poll timer) |
| Restart A — health_check.sh A complete | 08:23:58Z | 4/4 PASS |
| Restart A — postflight10 complete | 08:23:58Z | litellm pid changed (48525→67640) as expected; flashnext/role-shim/providers.json unchanged; live config sha256 still == BASELINE |
| *(gateway serving normally on the unmodified config; scripts/evidence prepared)* | 08:23:58Z – 08:29:55Z | no further live-stack action in this interval |
| Gate 1/Gate 2 (apply_candidate.sh) | 08:29:55Z – 08:29:59Z | preconditions + full validation ladder re-run against exact candidate bytes, 4/4 rungs PASS |
| Install (`cp -p` candidate → live) | 08:29:59Z | live sha256 immediately re-verified == candidate sha256 |
| Restart B — T0 | 08:29:59Z | on the **new** (CFG-11/12/17) config |
| Restart B — T1 | 08:30:07Z | exit 0, `waited=2s` (internal health-poll timer) |
| Restart B — health_check.sh B complete | 08:30:31Z | 4/4 PASS; alias listing (Step 5b) confirmed all 4 new/shipped aliases served |
| Restart B — postflight10 complete | 08:30:31Z | litellm pid changed (48525→68670) as expected; flashnext/role-shim/providers.json unchanged; live config sha256 == candidate sha256 |

**Total plan wall-clock span** (Restart A start → Restart B postflight complete): 08:23:26Z →
08:30:31Z, **≈7m5s**. Of that span, only the two restart windows below constitute actual gateway
downtime (~15–16s combined); the remaining ~6m50s was the gateway serving normally — first on the
unmodified config after Restart A, then briefly during Gate 1/Gate 2's re-validation (which never
touches the live gateway) immediately before Restart B.

## Measured outage — Restart A

**Sampler-measured (the honest number, 0.5s `curl /v1/models` sampler):** last known-good sample
at **08:23:26Z**, first recovered sample at **08:23:33Z** → **≈7 seconds**, ±1s. The ±1s comes
from a resolution limitation discovered in this ad hoc sampler (integer-second, not true
millisecond, epoch capture on macOS's BSD `date`) — documented in full in
`phase-10/results/20260901T082326Z-maintenance/outage-A-analysis.txt`. This does not affect
PASS/FAIL classification (a non-200 sample is still correctly distinguished from a 200 sample),
only the precision of the duration figure.

**`restart_service.sh`'s own wall-clock (the upper bound, T1−T0):** 08:23:26Z → 08:23:34Z = **8
seconds**. This bound includes teardown-wait polling and bootstrap+health-poll overhead outside
the sampler loop's own granularity; `restart_service.sh`'s internal timers separately report
teardown confirmed after 2s and the health poll (`state=running` + port 4000 listening) settling
after 2s.

Both figures are well under the ~20s expectation in `CHANGE-BRIEF.md` §5 and far under the 60s
hard `--timeout` bound — **not** a case of measured downtime materially exceeding expectations.

## Measured outage — Restart B: **NOT MEASURED** (sampler failure — root cause found and fixed)

`outage-B.tsv` contains exactly **one row** (`1788251399873  200`, i.e. 08:29:59.873Z, a healthy
sample taken right at T0) where a working 0.5s sampler across the ~8s Restart B window should have
produced roughly 16 rows, the way Restart A's sampler produced 18. **This must be recorded as a
failed measurement, not as "no outage occurred."** There almost certainly was an outage of roughly
the same magnitude as Restart A's — it was simply not captured.

**Root cause (found, not assumed):** `apply_candidate.sh`'s background sampler runs inside a
subshell that inherits `set -e` from the parent script, which picks it up when it sources
`phase-10/probe_lib10.sh` → `phase-09/probe_lib.sh` (`set -euo pipefail`). The sampler's original
line, `CODE=$(curl ... 2>/dev/null)`, is a simple command whose exit status equals curl's; curl
exits non-zero (7, connection refused) for every sample taken **while litellm is actually down** —
exactly the samples this instrument exists to record. Under the inherited `-e`, the very first such
sample silently killed the subshell, with nothing printed anywhere to say so. It recorded its one
pre-outage 200 sample and then simply stopped. Restart A's sampler (a throwaway driver script, not
a committed artifact) happened to survive only because its equivalent line ended in `|| echo
"000"`, which incidentally masked the same curl failure and kept the loop alive (at the cost of an
unrelated cosmetic bug — curl's own `-w '%{http_code}'` already prints "000" on failure, so that
version double-appended "000" into "000000"; harmless for PASS/FAIL classification, and documented
in `outage-A-analysis.txt`).

**Fix applied** to `phase-10/apply_candidate.sh` (both the timestamp and curl calls in the sampler
now guarded with `|| true`), but **not re-run against the live stack**: doing so would require a
third, purely diagnostic restart of `com.ohama.litellm` solely to re-measure an install that is
already independently verified healthy (health-B.tsv 4/4 PASS, postflight10 clean, all 5 aliases
served) — an unwarranted extra outage against the "polite tenant" standard this project holds
itself to.

**The only honest bound available for Restart B** is `restart_service.sh`'s own T0/T1 window: 8
seconds, exit 0 — in the same ballpark as Restart A's figures, and well under both the ~20s
expectation and the 60s hard timeout. This is offered as context only; it is not derived from a
working sampler and must not be presented as a measurement.

**Named explicitly, per this phase's own standard:** this is the **fourth instance** of the same
failure class this phase has produced — a selftest mutant whose anchor rotted while still
reporting `CAUGHT` (10-01); a validation ladder that took 90s to notice a crashed process instead
of ~2s (10-01); two plans asserting "pure insertion" after CFG-17 made that false (10-01/10-02);
and now an outage sampler that silently stopped measuring the exact event it was built to observe,
in this same plan. It was only caught here because `outage-A.tsv` (18 rows, in the same session)
made the single row in `outage-B.tsv` immediately suspicious — not because the sampler itself
raised any alarm. Full analysis: `outage-B-analysis.txt` in the run dir.

## Affected surfaces

**Affected** (connection-refused for the duration of each restart window above):
- Kanban (`:3484`)
- The Telegram connector
- Any headless wrapper run in flight against `litellm:4000` during either gap

**Not affected** (pid-verified across the entire window, both restarts):
- `com.ohama.flashnext` (pid 46573 throughout) — the 104 GiB resident model set was never dropped;
  no model reload occurred
- `com.ohama.role-shim` (pid 75548 throughout)

## Estimate vs. measurement

`CHANGE-BRIEF.md` §5 predicted each restart would complete "well under 20 seconds," citing the
validation ladder's own 2-second scratch boot as the basis, with a worst-case bound of 2×60s = 120s
total if both restarts hit their hard timeout.

**Actual:** Restart A ≈7–8s (measured); Restart B's `restart_service.sh` wall-clock bound is 8s
(sampler measurement lost — see above). Both are consistent with the prediction and nowhere near
the 60s `--timeout` bound on either restart — the hard timeout was never approached.

## Health evidence

**Why a single-sample port check was never accepted as health, stated explicitly:**
`restart_service.sh`'s own port-bound branch accepts `state=running` AND the port listening on the
**first** sample it takes — a job that binds the port briefly and then crash-loops under
`KeepAlive` could report a false success under that branch alone. `phase-10/health_check.sh` was
built specifically to close this blind spot and was required, and used, for both restarts.

**Restart A** (`health-A.tsv`, 4/4 PASS):
- `launchctl-pid-stability`: PASS — pid=67640 stable across two `launchctl print` samples ≥10s
  apart, both `state = running`
- `v1-models-x3`: PASS — 3 `/v1/models` calls ≥5s apart, all HTTP 200, `flashnext` listed in each
- `errlog-scan`: PASS — no `Traceback`/`ValidationError`/`Error loading` from the pre-restart
  watermark (line 14937) to EOF (8 new lines scanned)
- `e2e-completion`: PASS — one HTTP 200 completion through the unmodified `flashnext` alias
  (`max_tokens: 4`), issued only after confirming `in_flight=0`

**Restart B** (`health-B.tsv`, 4/4 PASS):
- `launchctl-pid-stability`: PASS — pid=68670 stable across two samples ≥10s apart, both
  `state = running`
- `v1-models-x3`: PASS — 3 calls ≥5s apart, all HTTP 200, `flashnext` listed in each
- `errlog-scan`: PASS — no `Traceback`/`ValidationError`/`Error loading` from the pre-restart
  watermark (line 14945) to EOF (8 new lines scanned)
- `e2e-completion`: PASS — one HTTP 200 completion through the unmodified `flashnext` alias
- **Step 5b (this plan's additional check, not part of `health_check.sh` itself):** `/v1/models`
  listed all 5 aliases post-install: `flashnext`, `flashnext-codex`, `flashnext-plan`,
  `flashnext-act`, `flashnext-reach-xhigh`

## Disposition

**Disposition**: INSTALLED

Evidence: `phase-10/results/20260901T082326Z-maintenance/` (`preflight.txt`, `postflight.txt`,
`outage-A.tsv` + `outage-A-analysis.txt`, `outage-B.tsv` + `outage-B-analysis.txt`, `health-A.tsv`,
`health-B.tsv`, `ladder-preinstall.tsv`, `apply.log`, `health-B-aliases.json`); the corrected
`postflight.txt` (see `phase-10/probe_lib10.sh`'s MIRROR-reporting fix, described in this plan's
Task 2 commit) confirms, post-install: `com.ohama.flashnext` (46573) and `com.ohama.role-shim`
(75548) pids unchanged from `BASELINE.txt`; `providers.json` sha256 unchanged; live config sha256
`d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e` (the candidate, exactly);
`bash phase-01/config/verify_config.sh` exits 0.

## Residual risk carried forward

- **MUTANT-4's residual risk (from 10-01, unresolved and re-affirmed here, not fixed by this
  plan):** the validation ladder's rung 4 (real scratch boot) only catches schema-invalid config
  shapes that make litellm's own config loader raise an **unhandled** exception at startup — it is
  not a graceful, general-purpose schema validator. A clean scratch boot is necessary evidence, not
  sufficient proof, against every conceivable misconfiguration shape; only the classes actually
  exercised by `selftest_validate_config.sh`'s 5 mutants have been proven caught.
- **A successful boot proves startup validity only.** Whether the injected `reasoning_effort` /
  `enable_thinking` parameters actually *reach* the model through the `hosted_vllm/` provider path
  and `role-shim` — as opposed to merely being accepted at config-load time — is **unproven until
  plan 10-04**. This plan proves the gateway is up and serving the new aliases; it does not prove
  the new parameters change model behavior.
- **The outage-B sampler defect** (see above): `apply_candidate.sh`'s sampler is fixed for any
  future re-run, but that fix was never exercised for real against a live outage in this session.
  Anyone re-running this script against a future config change should confirm `outage-*.tsv` has
  more than one row before trusting its duration figure — the exact verification this plan's own
  execution skipped the first time.
