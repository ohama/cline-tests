---
phase: 10-alias-injection-reach-proof
plan: 04
subsystem: testing
tags: [litellm, reach-proof, prompt_tokens, watermark-attribution, hosted_vllm, reasoning_effort, oracle]

# Dependency graph
requires:
  - phase: 10-alias-injection-reach-proof
    provides: "10-03's live gateway (config sha256 d7278a9f..., 5 aliases serving), probe_lib10.sh's
      preflight10/postflight10 safety envelope, and phase-09/PRB-03-ORACLE.md's declared reach
      deltas (medium/et-medium -2, xhigh/et-true +40) used here strictly as deltas, never absolutes"
provides:
  - "phase-10/probe_cfg16.sh — CFG-16 answered positively at both :8011 and :4000 (flashnext-plan),
    both field spellings checked, negative control confirms discrimination, at a realistic
    max_tokens:256 (Phase 9 only ever checked this combination's token cost at a truncating
    max_tokens:4)"
  - "phase-10/verify_reach.sh — the VRF-03 re-runnable artifact: 7-arm, 2-sweep,
    watermark-attributed prompt_tokens sweep. Every measured delta matches the declared oracle
    exactly: B-vs-D (VRF-01, shipped) -2, D-vs-F (wide-margin, confound-free) +42, B-vs-F +40,
    G-vs-B (CFG-12) 0"
  - "phase-10/REACH-PROOF.md — the self-contained requirement-mapped verdict document for Phase
    11/12: CFG-16 positive, reach proven with the wide-margin arm, shipped arm reported separately
    and labelled weaker, hosted_vllm/ confound closed at delta=0 on all 3 pairings, CFG-12
    corroborated, 8 falsification conditions named"
affects: ["11-01 (cline-plan/cline-act wrapper work can now cite a closed reach proof and a closed
  provider-prefix confound rather than an open question)", "12-xx (REACH-PROOF.md is the
  documentation source for CFG-16/VRF-01/VRF-02/VRF-03/CFG-12 in the final manual/pins update)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Same-body 2x2-style pairing (A|B, C|D, E|F) as the standard way to separate a provider-prefix
      / gateway-hop confound from a parameter-injection effect, rather than trusting a single
      cross-alias comparison to isolate one cause"
    - "A wide-margin verification-only alias (flashnext-reach-xhigh) built specifically because the
      shipped combination's own margin (-2) was too tight to trust as its own proof -- reach is
      proven once, on the wide-margin arm, and the shipped arm's narrow margin is read as
      corroboration of an already-established mechanism, not as freestanding evidence"

key-files:
  created:
    - phase-10/probe_cfg16.sh
    - phase-10/verify_reach.sh
    - phase-10/REACH-PROOF.md
  modified: []

key-decisions:
  - "No CFG-16-REMEDIATION.md was written -- the negative-alias branch of the plan's four-reading
    logic was never triggered. Both :8011 and :4000 (flashnext-plan) produced the identical
    284-character reasoning text at max_tokens:256, with the flashnext negative control at 0 chars"
  - "The hosted_vllm/ confound was closed in the 'no confound' direction: all three same-body
    pairings (A|B, C|D, E|F) measured delta=0, so VRF-01's -2 and the wide-margin +42 are both read
    as cleanly attributable to the injected parameters, with no correction factor applied anywhere
    in REACH-PROOF.md"
  - "verify_reach.sh was run three times during this plan's execution, not once -- the first run's
    report-writer had a bug (see Deviations) that was caught by reading actual printed output
    rather than trusting a clean exit code, per this phase's own standing lesson about instruments
    that report clean while testing nothing. The two subsequent runs both independently reproduced
    identical numbers, which doubles as unusually strong VRF-03 evidence, at the cost of firing more
    requests against the shared model than the plan's stated 17-request budget anticipated"

patterns-established:
  - "A report-writer helper (p()) that takes multiple line-continuation arguments must join with
    \"$*\", not echo \"$1\" -- the latter silently drops every continuation fragment without any
    error, and can only be caught by reading the actual rendered output, not by a green exit code
    or a passing bash -n"

# Metrics
duration: ~15min
completed: 2026-09-01
---

# Phase 10 Plan 04: Alias Injection Reach Proof Summary

**CFG-16 answered positively at both `:8011` and `flashnext-plan`, and reach proven on a wide,
oracle-exact margin (+42) with the shipped `et-medium` arm's narrow `-2` margin reported separately
and labelled the weaker proof it is — the `hosted_vllm/` provider-prefix confound closes at
delta=0 on all three same-body pairings, so nothing in the reach claim needs a correction factor.**

## Performance

- **Duration:** ~15 min (preflight of the first CFG-16 run, 08:50:07Z, to the Task 3 commit)
- **Started:** 2026-09-01T08:50:07Z
- **Completed:** 2026-09-01T09:02Z (approx; Task 3 commit `f70f283`)
- **Tasks:** 3/3
- **Files modified:** 3 created (2 scripts + 1 evidence doc), 5 measurement run directories, 2
  `CURRENT_*_RUN` pointers

## Accomplishments

- **CFG-16: positive at both endpoints.** `phase-10/probe_cfg16.sh` fired 3 requests at
  `max_tokens: 256` (Phase 9's PRB-03 only ever measured this combination's token cost at a
  truncating `max_tokens: 4`, never its content at a realistic length). `:8011` direct and
  `:4000`'s `flashnext-plan` (called with **no** client-sent reasoning params) both produced the
  identical 284-character reasoning text; the `flashnext` negative control produced 0. Both field
  spellings (`reasoning_content`, `reasoning`) were inspected at every arm — `:8011`'s response
  carries both names at the top level identically; litellm's `:4000` response carries
  `reasoning_content` at the top level and nests `reasoning` one level down inside
  `provider_specific_fields`, an honest and accurate reading, not a false negative. No
  `CFG-16-REMEDIATION.md` was needed.
- **VRF-01/VRF-02/VRF-03: reach proven, oracle-exact.** `phase-10/verify_reach.sh`'s 7-arm,
  2-sweep sweep (14 requests, watermark-attributed to their own `Prefill started` log line)
  reproduced every one of `PRB-03-ORACLE.md`'s declared deltas to the token: `B` (flashnext) vs `D`
  (flashnext-plan) = **-2**; `D` vs `F` (flashnext-reach-xhigh, both `hosted_vllm/`, the
  confound-free wide-margin pairing) = **+42**; `B` vs `F` = **+40**; `G` (flashnext-act) vs `B` =
  **0** (CFG-12, expected). Sweep 1 and sweep 2 agreed on all 7 arms with zero variance;
  `flake-count.txt` = 0.
- **The `hosted_vllm/` confound is closed, in the "no confound" direction.** All three same-body
  pairings (`A|B`, `C|D`, `E|F`) measured **delta = 0**. Neither the provider-prefix swap
  (`openai/` ↔ `hosted_vllm/`) nor the extra `:4000` gateway hop shifts `prompt_tokens` at all —
  every delta reported for VRF-01 and the wide-margin proof is cleanly attributable to the injected
  parameters, with no correction factor required.
- **`phase-10/REACH-PROOF.md` written**, self-contained, with all 8 required sections: what was
  measured (§1), CFG-16 at both endpoints (§2), VRF-01/02 split into the wide-margin proof (§3a)
  and the explicitly weaker shipped-arm proof (§3b) and the log-not-status basis (§3c), the closed
  confound (§4), CFG-12 corroboration (§5), sweep agreement and flake state including the honest
  three-invocation execution note (§6), a requirement-to-evidence map (§7), and 8 named
  falsification conditions (§8).

## Task Commits

1. **Task 1: CFG-16 — does the shipped combination actually produce reasoning, through the
   alias?** - `3b9bdb3` (feat)
2. **Task 2: Build the re-runnable reach proof and resolve the hosted_vllm confound** - `4763fe1`
   (feat)
3. **Task 3: Write REACH-PROOF.md** - `f70f283` (docs)

## Files Created/Modified

- `phase-10/probe_cfg16.sh` - CFG-16 check: 3 requests (`:8011`, `flashnext-plan`, `flashnext`
  control) at `max_tokens:256`, both field spellings, four-reading branch logic including a
  diagnosis-and-`CFG-16-REMEDIATION.md` path (not triggered here)
- `phase-10/verify_reach.sh` - the VRF-03 deliverable: 7-arm × 2-sweep watermark-attributed
  `prompt_tokens` sweep, full reach-report.txt generation (VRF-01/02 banners, wide-margin proof,
  3-pairing confound resolution, CFG-12 check, oracle-referenced delta table)
- `phase-10/REACH-PROOF.md` - the requirement-mapped verdict document
- `phase-10/results/20260901T085007Z-cfg16/`, `.../20260901T085111Z-cfg16/` - both CFG-16 probe
  runs (identical results; second is the `CURRENT_CFG16_RUN` pointer target)
- `phase-10/results/20260901T085412Z-reach/`, `.../20260901T085615Z-reach/`,
  `.../20260901T085700Z-reach/` - all three reach-proof runs, kept as evidence rather than
  discarded (third is the `CURRENT_REACH_RUN` pointer target and the one cited throughout
  `REACH-PROOF.md`)

## Decisions Made

- **No CFG-16-REMEDIATION.md.** The plan's negative-alias branch requires this document only when
  `:8011` is nonempty and `flashnext-plan` is empty; that condition never occurred here — both
  produced identical reasoning content.
- **The confound is closed at delta=0, not at some nonzero offset.** All three same-body pairings
  measured exactly 0; `REACH-PROOF.md` §4 states this as the finding rather than defensively
  hedging that a confound "might still exist but wasn't observed."
- **The shipped `et-medium` arm's `-2` delta is presented as corroboration of an already-established
  mechanism (the wide-margin proof), not as freestanding evidence** — per `PRB-03-ORACLE.md` §4's
  explicit instruction not to let the wide-margin proof's strength bleed into the shipped arm's own
  (weaker) reading.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, self-caught by reading actual output rather than trusting exit code]
`verify_reach.sh`'s report-writer helper `p()` silently dropped every line-continuation argument**

- **Found during:** Task 2, immediately after the first live run, while reading the printed
  `reach-report.txt` output rather than just checking the script's exit code
- **Issue:** `p() { echo "$1" | tee -a "$REPORT"; }` only echoed the first positional argument.
  Several report lines were written across two bash source lines using a trailing `\` continuation
  with the intent that the fragments concatenate — but without an operator between them, bash
  passes them as two separate arguments to `p`, and the second fragment (containing, in several
  cases, the actual computed delta and its oracle comparison) was silently discarded. `bash -n`
  passed and the script exited 0; only reading the rendered `reach-report.txt` text revealed
  several sentences cut off mid-clause with the delta values missing.
- **Fix:** Changed `p()` to `echo "$*"`, which joins all positional arguments with a space —
  matching the intended concatenation.
- **Files modified:** `phase-10/verify_reach.sh`
- **Verification:** the first run's `reach-report.txt` was regenerated offline from its
  already-collected `reach.tsv` (no new HTTP requests) using the corrected join logic, confirming
  the underlying measured data was never affected — only the report's prose. The script was then
  run twice more live with the fix in place, both producing complete, correctly-worded reports on
  the first try.
- **Committed in:** `4763fe1` (Task 2 commit)
- **Named explicitly, per this phase's own recurring-failure-class standard:** a fifth instance in
  this phase (after 10-01's rotted selftest anchor, 10-01's slow-to-notice validation ladder, two
  plans' invalidated "pure insertion" claims, and 10-03's `set -e`-killed outage sampler) of an
  instrument that looked clean (`bash -n` OK, exit 0, "done" printed) while silently not doing part
  of what it claimed. It differs from the prior four in one respect worth naming: this one affected
  report *prose* only, never the underlying measured `reach.tsv` data, and it was caught during
  this same plan's own execution, before being trusted into `REACH-PROOF.md`, by the simple
  discipline of reading the actual rendered output rather than the exit code.

**2. [Rule 1 - process discipline, not a masked bug] `verify_reach.sh` and `probe_cfg16.sh` were
each invoked more times than the plan's own stated request budget (17) anticipated**

- **Found during:** self-review while assembling this summary
- **Issue:** `probe_cfg16.sh` was run twice (6 requests instead of the planned 3) while confirming
  its exit code during development. `verify_reach.sh` was run three times (42 requests instead of
  the planned 14): once with the `p()` bug present, then twice more after the fix — the second of
  those two was itself accidental (re-running to check an exit code, when the code had already been
  captured from the prior invocation's own output). Total requests fired against the shared,
  single-slot model for this plan: 6 + 42 = 48, against a stated budget of 3 + 14 = 17.
- **Why this is recorded as a deviation rather than left silent:** the "polite tenant" standard this
  project holds itself to is explicit about sequential, minimal-request discipline against a model
  shared with Kanban and Telegram; exceeding the stated budget by this much, even with tiny
  (`max_tokens:4`/`256`) requests fired seconds apart, is a real cost that should be named rather
  than smoothed over.
- **Mitigating factor, not an excuse:** every extra invocation was either (a) necessary to catch and
  fix the `p()` bug (Deviation #1) and confirm the fix, or (b) redundant evidence that happened to
  land — all extra runs independently reproduced identical `prompt_tokens` values across every arm,
  which is itself unusually strong (if unintentionally over-provisioned) support for VRF-03's
  re-run property. No arm ever returned an inconsistent or surprising value across any of the
  invocations.
- **Not fixed retroactively** (the requests already happened and cannot be un-fired); recorded here
  and in `REACH-PROOF.md` §6 so a future reader auditing this plan's model usage sees the honest
  count rather than the planned one.
- **Files modified:** none — this is a process note, not a code change.

---

**Total deviations:** 2 (1 real bug in this plan's own new tooling, caught before being trusted
into the evidence document; 1 process-discipline overage in live model requests, named rather than
hidden). Neither affects the correctness of any number reported in `REACH-PROOF.md`.

## Issues Encountered

None beyond the two deviations above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Live state after this plan:** unchanged from 10-03. `/Users/ohama/agent-stack/litellm/config.yaml`
sha256 still `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e`. `com.ohama.litellm`
pid `68670`, `com.ohama.flashnext` pid `46573`, `com.ohama.role-shim` pid `75548` — all three
confirmed unchanged across every one of this plan's five script invocations (`postflight10` clean
every time). `providers.json` sha256 unchanged. `flashnext-codex` never called (confirmed by
grepping every raw request body this plan produced: 0 occurrences). No restart, no config write, no
`sync.sh` run — this plan proved reach without touching the stack, exactly as scoped.

**Ready for Phase 11** (`cline-plan`/`cline-act` wrapper + A/B gate): the reach proof and the
provider-prefix confound are both closed, so Phase 11 can proceed on the assumption that
`flashnext-plan`/`flashnext-act` behave as designed at the gateway layer, without re-litigating
whether the injected parameters actually reach the model.

**Still open, explicitly out of this plan's scope:**
- **VRF-04** (real `cline` CLI execution observing `reasoning` in the actual `--json` NDJSON
  stream) remains unaddressed — this plan proved the gateway delivers the parameters via `curl`,
  not that Cline's own client code reads and surfaces them. `ROADMAP.md`'s own note on VRF-04
  states this gap explicitly; it is carried forward, not silently dropped.
- **`~/local-llm-settings` mirror still diverges from the live config** (unchanged from 10-03,
  `postflight10` reports `diverged-as-expected` in every run of this plan) — plan 10-06's
  `sync.sh` still owns reconciling it; this plan made no attempt to touch it, per its own
  hard constraints.

---

*Phase: 10-alias-injection-reach-proof*
*Completed: 2026-09-01*
