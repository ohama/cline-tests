---
phase: 11-usage-surface-wrappers
plan: 01
subsystem: cli-wrappers
tags: [bash, cline-cli, deny-by-default, argv-testing, mutation-testing, litellm-alias]

# Dependency graph
requires:
  - phase: phase-10
    provides: "flashnext-plan / flashnext-act litellm aliases, and the kwarg-merge-order finding (client kwargs override alias litellm_params) that motivates rejecting --thinking rather than tolerating it"
provides:
  - "phase-11/cline-plan and phase-11/cline-act: deny-by-default argument-filtering wrappers around the real cline binary"
  - "phase-11/wrapper.env: single-source alias/provider/compaction/timeout/binary-path config"
  - "phase-11/testing/stub-cline + phase-11/wrapper_argv_test.sh: zero-cost argv-capture test harness, proven able to fail via two seeded mutants"
  - "phase-11/WRAPPER-DESIGN.md: the contract, deny-by-default and reject-not-strip rationale, -p-is-orthogonal-to-reasoning finding, and honest limitations list"
affects: [phase-11 (11-03 verify_config.sh integration, 11-04 wrapper-check proof, 11-05 A/B harness), phase-12 (USE-04 manual, USE-05 design-doc updates)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "deny-by-default argument parsing (whitelist four option forms, refuse every other '-' argument unconditionally) instead of a blocklist of known-bad flags, specifically to survive undocumented CLI drift"
    - "reject-not-strip: every refusal names the flag, exits non-zero, and never invokes the real binary — no flag is ever silently dropped"
    - "single construction site for the real binary invocation, sourced by both wrapper scripts, so they cannot drift apart"
    - "stub-binary argv capture (test-only fake cline that records argv to a file) for zero-cost behavioural testing of a CLI wrapper"
    - "mutation testing a shell wrapper: seed a deliberately broken copy, assert the same test suite catches it, record CAUGHT/MISSED"

key-files:
  created:
    - phase-11/wrapper.env
    - phase-11/wrapper_common.sh
    - phase-11/cline-plan
    - phase-11/cline-act
    - phase-11/testing/stub-cline
    - phase-11/wrapper_argv_test.sh
    - phase-11/WRAPPER-DESIGN.md
    - phase-11/results/20260902T041615Z-argv/ (argv.tsv, argv-mutants.tsv, per-case argv/stdout/stderr, two full mutant wrapper-set copies)
    - phase-11/results/CURRENT_ARGV_RUN
  modified: []

key-decisions:
  - "Deny-by-default (whitelist -t/--timeout, -c/--cwd, --json, --) rather than a blocklist of --thinking/-m/-P/-p, because CFG-05 drift already produced two unannounced new flags (-p, --thinking) between cline 3.0.53 and 3.0.60 -- a blocklist written today would already be stale"
  - "Refusal is always loud (named message, exit 2, usage line, nothing invoked) and never a silent strip, per CFG-14's drop_params ban and ALIAS-DESIGN.md §4"
  - "MUTANT-LEAKY is a wholesale replacement of wrapper_common.sh's parsing+construction (not a one-line patch to the real file), because the real parser's refuse branches would otherwise still intercept --thinking before reaching a patched construction line -- the mutant needed to model 'no filtering happened at all', matching the docs' own naive shell-function sketch"
  - "wrapper_argv_test.sh deliberately avoids set -e (phase-10's own catalogued outage-sampler failure mode), using explicit || capture everywhere a non-zero exit is expected"
  - "Refusal cases pre-seed the stub's argv-capture file with a sentinel string and assert byte-identical before/after, rather than relying on the file's mere absence, so 'the binary was never reached' is a real comparison and not just 'nothing happened to notice'"

patterns-established:
  - "Any future CLI-wrapper work in this project should default to deny-by-default parsing over blocklists when the wrapped binary's flag surface is not contractually stable"
  - "A behavioural test over a CLI wrapper must be proven able to fail (seeded mutant) in the same run that proves the real thing passes -- an all-pass report with no adversarial run behind it is not evidence"

# Metrics
duration: ~35min
completed: 2026-09-02
---

# Phase 11 Plan 01: Wrapper Pair + Argv-Capture Harness Summary

**Deny-by-default `cline-plan`/`cline-act` wrappers with a single shared construction site, proven — by reading a stub's captured argv across 13 cases plus two seeded mutants (a naive `"$@"` passthrough and an alias swap), both CAUGHT — to pair mode and alias correctly and to refuse `--thinking` (all three spellings), `-m`, `-P`, `-p`, and anything else unrecognised without ever invoking the real binary.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3/3 completed
- **Files created:** 8 source/design files + one full timestamped results directory (132 files, mostly per-case argv/stdout/stderr captures and two full mutant wrapper-set copies)
- **Live model requests:** 0 (constraint satisfied — everything ran against `phase-11/testing/stub-cline`)

## Accomplishments

- `phase-11/wrapper.env` is the single file naming `flashnext-plan`/`flashnext-act`/`/opt/homebrew/bin/cline` — neither wrapper script contains a literal alias string (`grep -c flashnext` on both is `0`).
- `phase-11/wrapper_common.sh` implements deny-by-default parsing (four accepted option forms; everything else refused with exit 2 and a named message) and the single construction site for the real invocation, shared by both wrappers.
- `phase-11/testing/stub-cline` + `phase-11/wrapper_argv_test.sh`: a zero-cost argv-capture harness that ran 13 cases against the real wrappers (all PASS) and two seeded mutants (both CAUGHT) in the same script invocation.
- `phase-11/WRAPPER-DESIGN.md`: records the contract with argv quoted verbatim from the actual run, the deny-by-default/reject-not-strip rationale, the `-p`-is-orthogonal-to-reasoning finding the USE-03 A/B design depends on, the single-source revert path, and an honest limitations section.

## Task Commits

1. **Task 1: Single-source config plus the deny-by-default wrapper pair** — `2d09119` (feat)
2. **Task 2: Stub-cline argv capture, the behavioural test, and the leaky mutant that proves it can fail** — `c404461` (test)
3. **Task 3: WRAPPER-DESIGN.md** — `ba0ff61` (docs)

_No plan-metadata commit yet — this document + the STATE.md update are committed together next, per the orchestrator's standard closing commit._

## Files Created/Modified

- `phase-11/wrapper.env` — single-source alias/provider/compaction/timeout/binary-path definitions
- `phase-11/wrapper_common.sh` — deny-by-default parser + single construction site + config guard cycle + `VERIFY_CONFIG_NO_WRAPPER_CHECK=1` recursion brake for plan 11-03
- `phase-11/cline-plan` / `phase-11/cline-act` — thin per-mode entry points, no literal alias strings
- `phase-11/testing/stub-cline` — test-only fake `cline`, aborts loudly if `STUB_ARGV_FILE` unset
- `phase-11/wrapper_argv_test.sh` — 13-case behavioural test + MUTANT-LEAKY + MUTANT-SWAP negative controls
- `phase-11/WRAPPER-DESIGN.md` — the design record for USE-01/02, source for Phase 12's USE-04
- `phase-11/results/20260902T041615Z-argv/` and `phase-11/results/CURRENT_ARGV_RUN` — the evidence run

## The wrappers' final argv construction (observed, not inferred)

`cline-plan "hello"` → `/opt/homebrew/bin/cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 600 hello` (`cases-real/P1.argv`, `argv.tsv` row P1: PASS).

`cline-act "hello"` → `/opt/homebrew/bin/cline -P openai-compatible -m flashnext-act --compaction agentic -t 600 hello` (`cases-real/P2.argv`, row P2: PASS) — no `-p`, no `--plan`, alias swapped.

`cline-plan --timeout 90 --json "hello"` → `... --compaction agentic -t 90 --json hello` (row P3: PASS) — `-t`/`--json` pass through; everything else stays fixed.

## Argv test results (13/13 PASS)

| Case | Invocation | Verdict |
|---|---|---|
| P1 | `cline-plan hello` | PASS — `-p`, `-m flashnext-plan` (once), `-P openai-compatible`, `--compaction agentic`, last=`hello`, `--thinking`×0, `CLINE_NO_AUTO_UPDATE=1` recorded |
| P2 | `cline-act hello` | PASS — `-m flashnext-act` (once), no `-p`/`--plan`, `--thinking`×0 |
| P3 | `cline-plan --timeout 90 --json hello` | PASS — `-t 90`, `--json` present |
| P4 | `cline-plan -- "-weird prompt"` | PASS — refused exit 2 (prompt begins with `-`), stub not invoked, argv file byte-unchanged (documented limitation, §7) |
| R1 | `cline-plan --thinking high x` | PASS — exit 2, stderr names `--thinking`, stub not invoked |
| R2 | `cline-plan --thinking=high x` | PASS — the `=` form caught |
| R3 | `cline-plan --thinking x` | PASS — bare form caught |
| R4 | `cline-act --thinking high x` | PASS |
| R5 | `cline-plan -m flashnext x` | PASS — stderr names `-m` |
| R6 | `cline-act -m flashnext-codex x` | PASS — deny-by-default closes the codex path too, for free |
| R7 | `cline-plan -P openai x` | PASS |
| R8 | `cline-act -p x` | PASS |
| R9 | `cline-plan --auto-approve false x` | PASS — generic refusal, proves whitelist not blocklist |

Every `R*` row recorded `stub_invoked=no`, verified by grepping the row column directly (`awk -F'\t' '$1 ~ /^R/{print $5}'` → all `no`), not by trusting the wrapper's own exit code.

## Mutants seeded and what each proved

**MUTANT-LEAKY** — replaced `wrapper_common.sh` wholesale with a naive `"$@"` passthrough matching `docs/plan-act-reasoning-design.md`'s own L3 sketch (`cline -p -m flashnext-plan "$@"`): no argument filtering at all, original args captured and forwarded verbatim after the fixed prefix. Run through the same 13-case suite, case R1 (`cline-plan --thinking high x`) actually leaked — the stub's captured argv (`cases-mutant-leaky/R1.argv`) reads:

```
-P
openai-compatible
-p
-m
flashnext-plan
--compaction
agentic
-t
600
--thinking
high
x
```

`--thinking high` sitting in the real argv, exactly the failure this whole plan exists to prevent. `argv-mutants.tsv`: `MUTANT-LEAKY R1 R1 1 CAUGHT` — the test detected it (suite exit 1, R1 row FAIL).

**MUTANT-SWAP** — left the parser untouched, changed only `cline-plan`'s `WRAPPER_ALIAS="$WRAPPER_PLAN_ALIAS"` to `WRAPPER_ALIAS="$WRAPPER_ACT_ALIAS"`. Case P1's assertion (`-m` immediately followed by the value of `WRAPPER_PLAN_ALIAS` read from the mutant's own unmodified `wrapper.env`) failed because the actual argv now carried `flashnext-act`. `argv-mutants.tsv`: `MUTANT-SWAP P1 P1 1 CAUGHT`.

Both mutants ran in the same script invocation as the real-wrapper suite, so the exit code the test produced (non-zero, because both a real-suite check and a mutant-catch check gate it) could not be a coincidence of "fails everything."

## Decisions Made

- Deny-by-default over blocklist: the CFG-05 drift argument (`-p`/`--thinking` both appeared unannounced between 3.0.53 and 3.0.60) makes a blocklist a documented liability, not just a style preference.
- Reject, never strip: every refusal path names the argument, prints usage, exits 2, and the construction site is never reached — verified by byte-comparing a pre-seeded sentinel in the stub's argv file before and after every refusal case.
- `wrapper_argv_test.sh` avoids `set -e` throughout and captures every expected-nonzero exit explicitly with `||`, specifically because phase-10's findings catalogue an outage sampler that `set -e` killed on the exact condition it existed to record.
- MUTANT-LEAKY is a full alternate `wrapper_common.sh`, not a one-line diff to the real file, because the real parser's refuse branches for `--thinking` would otherwise still fire before reaching any patched construction-site line — the mutant needed to model "no filtering happened," matching the actual naive-shell-function bug shape from `docs/plan-act-reasoning-design.md`.

## Deviations from Plan

None — plan executed as written. All `must_haves`, all 13 argv-test cases, both mutants, and `WRAPPER-DESIGN.md`'s required contents (verified by grep, not by eye) are present and match the plan's literal specification.

## Issues Encountered

The design's `set -u` requirement (bash 3.2, no `declare -A`) surfaced one real gotcha worth
recording for future scripts in this repo: bare `"${empty_array[@]}"` under `set -u` in bash
3.2.57 raises "unbound variable" (confirmed empirically on this machine), whereas
`"${empty_array[@]:-}"` and `${#empty_array[@]}` do not. `wrapper_argv_test.sh`'s
`argv_has_exact`/`argv_count` helpers use the `:-` form for exactly this reason.

**Shared-index race with the concurrent 11-02 agent.** This plan runs as wave 1 alongside plan
11-02 in the same working tree. `git add .planning/phases/11-usage-surface-wrappers/{11-01-PLAN,11-01-SUMMARY}.md`
was run to prepare this closing commit, but before `git commit` executed, the 11-02 agent's own
commit (`b4eec84`, `feat(11-02): four-state NDJSON grader...`) landed and its git operation swept
up this file (already sitting in the shared index) alongside its own five `phase-11/fixtures/*`
and `phase-11/grade_ab.py`/`selftest_grade_ab.sh` files. The content is unaffected — `git diff
HEAD -- .planning/phases/11-usage-surface-wrappers/11-01-SUMMARY.md` is empty, confirming the
working-tree file matches exactly what got committed — but the provenance is wrong: this file's
history now attributes to a commit message about the A/B grader, not this plan's own work. No
destructive history rewrite was attempted (per this project's own git safety protocol, amending a
commit a concurrent agent may already be building on top of is exactly the kind of operation to
avoid). Recorded here rather than silently left for a future reader to be confused by `git log
--follow` on this file.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `phase-11/wrapper.env`, `phase-11/wrapper_common.sh`, `phase-11/cline-plan`, `phase-11/cline-act` are ready for plan 11-03 to extend `verify_config.sh` against, and for plan 11-05's A/B harness to invoke directly.
- `VERIFY_CONFIG_NO_WRAPPER_CHECK=1` is exported by every internal `wrapper_common.sh` call to `verify_config.sh` (both pre-run and post-run guard), as required by plan 11-03's recursion brake — present in the code now even though nothing reads it yet. Plan 11-03 still owns proving no recursion actually occurs once it makes `verify_config.sh` exercise these wrappers (WRAPPER-DESIGN.md §8 records this as an open interaction to prove, not assume).
- No blockers. Stack state (three service pids, `flashnext.err` line count, `providers.json` sha256, port 3000) was captured before this plan's first task and re-verified identical after the last — no live traffic occurred anywhere in this plan.

---
*Phase: 11-usage-surface-wrappers*
*Completed: 2026-09-02*
