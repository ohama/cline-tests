---
phase: 10-alias-injection-reach-proof
plan: 03
subsystem: infra
tags: [litellm, launchd, restart, rollback, sha256, maintenance-window, hosted_vllm, reasoning_effort]

# Dependency graph
requires:
  - phase: 10-alias-injection-reach-proof
    provides: "10-01's config.yaml.candidate (proven pure-insertion + CFG-17 deletion) and its
      4-rung validate_config.sh ladder; 10-02's backup, rollback_config.sh, BASELINE.txt, and the
      human-approved CHANGE-BRIEF.md §9 scoped to this exact candidate sha256"
provides:
  - "The live litellm config actually mutated for the first time in this milestone:
    /Users/ohama/agent-stack/litellm/config.yaml now equals the approved candidate"
  - "phase-10/probe_lib10.sh — the Phase 10 safety envelope (preflight10/postflight10) for a
    window where litellm's pid and the live config hash are SUPPOSED to change, reusing
    phase-09/probe_lib.sh's flake_window/record_verdict verbatim"
  - "phase-10/health_check.sh — multi-sample post-restart health (2 launchctl samples >=10s apart,
    3 /v1/models calls >=5s apart, error-log scan, 1 end-to-end completion) closing the
    single-sample port-check blind spot in restart_service.sh"
  - "phase-10/apply_candidate.sh — the gated install+restart+rollback sequence, executed for real"
  - "phase-10/CFG-13-EVIDENCE.md and phase-10/MAINTENANCE-LOG.md — post-install proof and
    operational record"
affects: ["10-04 (CFG-16 reasoning-content verification against the now-live aliases)",
  "10-06 (sync.sh must reconcile the now-diverged ~/local-llm-settings mirror)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Rehearse-then-mutate for restarts, not just config: Restart A on the unmodified config
      turns a downtime estimate into a measurement and proves the restart mechanism BEFORE
      anything is written, so a failed Restart B is unambiguously the config's fault"
    - "Single scripted install+restart+rollback sequence (apply_candidate.sh) so an operator
      mid-outage cannot skip the rollback branch by improvising"
    - "A safety envelope with caller-supplied expectations (restart_expected 0|1, expected live
      sha) rather than a fixed invariant, for the one phase where certain mutations are correct"

key-files:
  created:
    - phase-10/probe_lib10.sh
    - phase-10/selftest_probe_lib10.sh
    - phase-10/health_check.sh
    - phase-10/apply_candidate.sh
    - phase-10/CFG-13-EVIDENCE.md
    - phase-10/MAINTENANCE-LOG.md
  modified:
    - /Users/ohama/agent-stack/litellm/config.yaml
    - .planning/phases/10-alias-injection-reach-proof/10-03-PLAN.md

key-decisions:
  - "Restart A (rehearsal on the unmodified config) ran and passed before any write occurred,
    per the plan's front-loaded-cheap-failure design; its success is what makes the install
    (Restart B) unambiguous rather than a mystery outage"
  - "Restart B's outage duration is recorded as NOT MEASURED, not as zero and not backfilled from
    Restart A's number, once the sampler was found to have died after one sample — see Deviations"
  - "A third, purely diagnostic restart was NOT performed to re-measure Restart B's outage after
    fixing the sampler bug; the install is independently verified healthy by other means, and an
    extra restart solely to satisfy a measurement artifact would violate the polite-tenant /
    minimize-disruption standard this project holds itself to"

patterns-established:
  - "Outage sampler subshells launched from a script that has sourced anything setting `set -e`
    must guard every command whose expected failure mode is the exact condition being measured
    (e.g. `curl ... || true`), or the instrument silently stops recording partway through"

# Metrics
duration: ~65min
completed: 2026-09-01
---

# Phase 10 Plan 03: Maintenance Window — Install Candidate, Restart, Verify Summary

**The live litellm config was mutated for the first time in this milestone — `flashnext-plan`,
`flashnext-act`, `flashnext-reach-xhigh` installed under a `hosted_vllm/` prefix and the 6
deprecated `qwen-*` aliases removed (CFG-17) — via two gated restarts (rehearsal then real),
CFG-13/CFG-14 proven against the installed file, and a genuine sampler-measurement failure on the
second restart caught and named rather than papered over.**

## Performance

- **Duration:** ~65 min (from Restart A's `preflight10` at 08:23:26Z to the final Task 3 commit)
- **Started:** 2026-09-01T08:23:26Z (Restart A T0)
- **Completed:** 2026-09-01 (Task 3 commit `b6fc94c`; a trailing 1-line evidence-clarity fix landed
  as `aee6a2f`)
- **Tasks:** 3/3
- **Files modified:** 6 created (4 scripts + 2 evidence docs), 1 live config mutated, 1 plan doc
  annotated

## Accomplishments

- **Restart A (rehearsal, unmodified config):** `restart_service.sh` exit 0, litellm pid
  48525→67640, flashnext (46573) and role-shim (75548) pids unchanged, `providers.json` untouched,
  live config sha256 still equalled `BASELINE.txt`. Health check 4/4 PASS. Measured outage: **~7s**
  from the 0.5s sampler (last-good 08:23:26Z → first-recovered 08:23:33Z), **8s** upper bound from
  `restart_service.sh`'s own T0/T1 — both well under the ~20s expectation and the 60s hard timeout.
- **Candidate re-validated immediately before install** (Gate 2 of `apply_candidate.sh`): the
  candidate's sha256 was re-checked against `CHANGE-BRIEF.md` §9's approved value (still
  `d7278a9f...` — unchanged since approval, confirmed **before** touching anything), then the full
  4-rung `validate_config.sh` ladder re-ran and passed 4/4, including a fresh real-binary scratch
  boot on 127.0.0.1:4010.
- **Install + Restart B:** candidate copied over the live path, re-hashed and confirmed equal to
  the candidate sha256, then `restart_service.sh` exit 0 (litellm pid 48525→68670), health check
  4/4 PASS, and `/v1/models` confirmed serving all 5 aliases (`flashnext`, `flashnext-codex`,
  `flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh`). `postflight10` clean:
  flashnext/role-shim pids unchanged, `providers.json` unchanged, live config sha256 == candidate.
  **Disposition: INSTALLED** — no rollback was needed or taken.
- **CFG-13 proven three ways** against the installed file (not just the candidate): raw line diff
  with all 16 removed lines individually classified as the CFG-17 header or a named `qwen-*`
  alias; head-range (`head -n 34`) byte identity reproducing `BASELINE.txt`'s exact witness hash;
  `yaml.safe_load` deep-equal of `flashnext`/`flashnext-codex` plus confirmed absence of all 6
  deprecated names. **CFG-14 proven:** `grep -in drop_params` returns nothing (exit 1).
- **`phase-10/probe_lib10.sh` self-tested for real:** clean control exits 0; three seeded
  mismatches (flashnext pid, live-config hash, restart-expectation) all exit non-zero — run twice
  (before and after a mid-execution bugfix, see Deviations), both times 4/4 as expected.

## Task Commits

1. **Task 1: Build and break the Phase 10 safety envelope, then restart litellm on the unmodified
   config** - `9162f1c` (feat)
2. **Task 2: Install the candidate and restart, with the rollback branch wired in** - `648e824`
   (feat)
3. **Task 3: Record CFG-13/CFG-14 evidence and close the maintenance log** - `b6fc94c` (test)
4. **Trailing fix (evidence clarity, non-blocking):** `aee6a2f` (fix) — see Deviations #4

**Plan metadata:** (this commit, docs(10-03))

## Files Created/Modified

- `phase-10/probe_lib10.sh` - Phase 10 safety envelope: `preflight10`/`postflight10` for a window
  where litellm's pid and the live config hash are SUPPOSED to change; sources
  `phase-09/probe_lib.sh` for `flake_window`/`record_verdict` rather than reimplementing them
- `phase-10/selftest_probe_lib10.sh` - proves `postflight10` fails on 3 seeded mismatches and
  passes on the clean control, doctoring only copies of snapshot files
- `phase-10/health_check.sh` - multi-sample post-restart health: 2 launchctl samples ≥10s apart, 3
  `/v1/models` calls ≥5s apart, error-log scan, 1 end-to-end completion via `flashnext`
- `phase-10/apply_candidate.sh` - the gated install+restart+rollback sequence (Gate 1
  preconditions, Gate 2 ladder re-run, Step 3 install, Step 4 Restart B, Step 5 health + alias
  check, Step 6 envelope; rollback branch on any failure from Gate 2 onward)
- `phase-10/CFG-13-EVIDENCE.md` - CFG-13 (3 ways) and CFG-14 proof against the installed file
- `phase-10/MAINTENANCE-LOG.md` - the operational record: timeline, both outage figures (one
  measured, one honestly not), affected surfaces, health evidence, disposition, residual risk
- `/Users/ohama/agent-stack/litellm/config.yaml` - **the live file, mutated**: 3 new
  `hosted_vllm/`-prefixed aliases inserted, 6 deprecated `qwen-*` aliases + their comment header
  removed (CFG-17), `flashnext`/`flashnext-codex` byte-identical to before
- `.planning/phases/10-alias-injection-reach-proof/10-03-PLAN.md` - one dated 🔴 correction (see
  Deviations #3)

## Decisions Made

- **Restart A ran to completion and passed before Restart B was attempted**, exactly as designed —
  this is what let Restart B's success be read unambiguously as "the config was fine" rather than
  "maybe the restart mechanism was already broken."
- **Restart B's outage duration is recorded as NOT MEASURED**, not as "no outage" and not
  backfilled from Restart A's figure, once the sampler was found to have produced only one row.
  See Deviations #2 for the full account.
- **No third restart was performed** to re-measure Restart B after fixing the sampler bug. The
  install's health is independently proven by `health-B.tsv` (4/4 PASS), the alias listing, and
  `postflight10` — none of which depend on the outage sampler. Spending a real, unwarranted outage
  against a shared single-slot model purely to backfill a duration figure would have violated the
  polite-tenant standard for no safety benefit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `postflight10`'s MIRROR-status line compared mirror-before to mirror-after
instead of mirror to live, silently mislabeling the post-install divergence as "in-sync"**

- **Found during:** Task 2, reviewing `postflight10`'s output immediately after the real install
- **Issue:** `phase-10/probe_lib10.sh`'s original MIRROR check compared the mirror config's own
  hash before vs. after the run — which is *always* trivially unchanged, since nothing in this
  phase ever writes the mirror — so it printed `MIRROR: in-sync (unchanged: ...)` even after the
  live config had just changed out from under it, which is exactly the divergence the plan's
  `MIRROR: in-sync | diverged-as-expected` reporting exists to surface.
- **Fix:** Changed the comparison to mirror-vs-live (both taken from the same post-run snapshot).
  Re-running `postflight10` against the installed state now correctly reports
  `MIRROR: diverged-as-expected (mirror=12e102cf... live=d7278a9f...)`.
- **Files modified:** `phase-10/probe_lib10.sh`
- **Verification:** re-ran `postflight10` against the live post-install state; all hard checks
  still OK, MIRROR line now correctly shows the real divergence; `selftest_probe_lib10.sh` re-run
  in full afterward, still 4/4 as expected.
- **Committed in:** `648e824` (Task 2 commit)

**2. [Rule 1 - Bug, caught by the orchestrator, not self-caught] Restart B's outage sampler
produced exactly one row instead of ~16, and this was initially about to be left unexamined**

- **Found during:** Task 2, when the orchestrator compared `outage-B.tsv` (1 row) against
  `outage-A.tsv` (18 rows, real transition) in the same session and flagged it before the SUMMARY
  was written.
- **Issue:** `apply_candidate.sh`'s background outage sampler runs in a subshell that inherits
  `set -e` (picked up when the parent sources `phase-10/probe_lib10.sh` → `phase-09/probe_lib.sh`'s
  `set -euo pipefail`). Its `CODE=$(curl ... 2>/dev/null)` line is a simple command whose exit
  status is curl's; curl exits 7 (connection refused) for every sample taken **while litellm is
  actually down** — precisely the samples the sampler exists to record. Under the inherited `-e`,
  the first such sample silently killed the subshell. It recorded one pre-outage 200 sample and
  stopped. (Restart A's throwaway driver script survived only by accident: its equivalent line
  ended in `|| echo "000"`, which masked the same underlying curl failure.)
- **Fix:** Guarded both the timestamp and curl calls in the sampler with `|| true`. **Not re-run**
  against the live stack — see Decisions above for why.
- **Files modified:** `phase-10/apply_candidate.sh`
- **Verification:** root cause identified by direct code inspection and comparison against
  Restart A's surviving (differently-guarded) equivalent line; the fix is syntactically verified
  (`bash -n`) but not exercised against a real outage in this session.
- **Committed in:** `648e824` (Task 2 commit)
- **Named explicitly, per this phase's own recurring-failure-class standard:** this is the
  **fourth** instance in this phase of an instrument that silently stops exercising the thing it
  exists to observe — after 10-01's rotted selftest-mutant anchor (reported `CAUGHT` while testing
  nothing), 10-01's 90-second-to-notice validation ladder, and two plans' "pure insertion" claims
  invalidated by CFG-17. Recorded in full in `phase-10/results/.../outage-B-analysis.txt` and
  `phase-10/MAINTENANCE-LOG.md`. Restart B's outage duration is reported as **NOT MEASURED**; the
  only honest figure available is `restart_service.sh`'s own 8-second T0/T1 wall-clock bound,
  offered as context, not as a substitute measurement.

**3. [Rule 1 - stale plan text] `10-03-PLAN.md`'s own Task 3 `<verify>` block still described the
pre-CFG-17 "must be empty" `^<` diff check, contradicting this same Task's `<action>` text**

- **Found during:** Task 3, while assembling `CFG-13-EVIDENCE.md` and cross-checking the plan's own
  verify wording
- **Issue:** The `<verify>` block said the `^<` diff result "is empty" and that a re-run should
  print `0` — directly contradicting the Task's own `<action>` text a few lines above, which
  explicitly states (with a 🔴 2026-09-01 marker) that CFG-17 makes an empty result **wrong** and
  the correct expectation is exactly 16 lines, individually classified.
- **Fix:** Followed this phase's established convention — appended a dated 🔴 annotation stating
  what the text originally said, why it's superseded, and the correct expectation (16, classified),
  leaving the original text in place.
- **Files modified:** `.planning/phases/10-alias-injection-reach-proof/10-03-PLAN.md`
- **Verification:** re-ran the literal commands from both the stale and corrected wording:
  `diff ... | grep -c '^<'` → 16 (not 0); `grep -ci drop_params ...` → 0 (this part of the stale
  text happened to already be correct).
- **Committed in:** `b6fc94c` (Task 3 commit)

**4. [Rule 1 - minor, non-blocking] `health_check.sh`'s e2e-completion PASS line didn't literally
contain "chat/completions", so the plan's own literal grep-based verification line couldn't be
satisfied by the already-collected evidence**

- **Found during:** final plan-level `<verification>` pass, item 8
  (`grep -c 'chat/completions' "$RUN"/health-*.tsv` should match the number of health runs)
- **Issue:** The already-collected `health-A.tsv`/`health-B.tsv` genuinely each represent exactly
  one completion request (proven by the accompanying `health-*-completion.json` bodies and by
  direct code inspection of `health_check.sh`, which issues exactly one such curl call per
  invocation), but the TSV's PASS text never spelled out the endpoint, so the literal string match
  returns 0 for both files instead of 1 each.
- **Fix:** Updated the PASS line to explicitly say "one POST /v1/chat/completions" for any future
  run. **Not backfilled into the two already-collected TSVs**, and **not re-run** — doing so would
  cost one more real completion against the shared, single-slot model purely to satisfy grep text,
  for a fact (one completion per run) already independently proven by the completion JSON bodies.
- **Files modified:** `phase-10/health_check.sh`
- **Verification:** `bash -n` passes; the underlying invariant (exactly one completion per health
  check, gated on `in_flight=0`, only through `flashnext`) is verified by direct code reading and
  by the existence of exactly one `health-*-completion.json` per run.
- **Committed in:** `aee6a2f` (standalone fix commit, after Task 3)

---

**Total deviations:** 4 auto-fixed (2 real bugs in this plan's own new tooling — one caught by
self-review, one caught by the orchestrator; 1 stale-plan-text annotation; 1 minor evidence-clarity
fix). None constitutes scope creep; all were necessary for the artifacts' own claims to hold true.

## Issues Encountered

- The Bash tool's execution harness does not reliably populate `BASH_SOURCE[0]` for a `source`
  command issued as a bare top-level command (as opposed to inside an invoked script file) — an ad
  hoc `source phase-10/probe_lib10.sh` typed directly resolved `HERE` to the wrong directory.
  Worked around by driving Restart A through a small throwaway wrapper script invoked via
  `bash <script>` (where `BASH_SOURCE` behaves normally) rather than sourcing at the tool's
  top level; not a defect in any committed artifact, since every committed script is always
  invoked as `bash script.sh` or sourced from within another script file, both of which were
  confirmed to work correctly.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Live state after this plan:** `/Users/ohama/agent-stack/litellm/config.yaml` sha256
`d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e` (the approved candidate).
`com.ohama.litellm` pid `68670` (changed twice during this window, both times verified). Both
`com.ohama.flashnext` (pid `46573`) and `com.ohama.role-shim` (pid `75548`) held their pids across
the entire window. `providers.json` sha256 unchanged from `phase-10/BASELINE.txt`. `/v1/models`
serves 5 aliases. Nothing bound on port 3000 or 4010. `flashnext-codex` was never called.

**Ready for plan 10-04** (CFG-16 reasoning-content verification): the live gateway now actually
serves `flashnext-plan`/`flashnext-act`/`flashnext-reach-xhigh` with the injected parameters —
this plan proves the gateway boots and serves them, not that the parameters reach the model or
change its behavior. That is 10-04's job, explicitly.

**Blockers/concerns to carry forward:**
- **Restart B's outage duration is unmeasured** (see Deviations #2). If a future maintenance
  window reuses `apply_candidate.sh`'s sampler pattern, confirm `outage-*.tsv` has more than one
  row before trusting any duration figure it reports — this is the exact verification this
  session's own execution skipped the first time.
- **MUTANT-4's residual risk** (carried forward from 10-01, restated in `MAINTENANCE-LOG.md`): the
  validation ladder's real-boot rung only catches config shapes that make litellm raise an
  unhandled exception at startup, not a general schema validator.
- **The `~/local-llm-settings` mirror now genuinely diverges from the live config** (by design —
  `postflight10` reports this as `diverged-as-expected`), and stays that way until plan 10-06's
  `sync.sh` regenerates it.

---
*Phase: 10-alias-injection-reach-proof*
*Completed: 2026-09-01*
