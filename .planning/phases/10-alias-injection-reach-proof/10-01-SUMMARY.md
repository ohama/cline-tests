---
phase: 10-alias-injection-reach-proof
plan: 01
subsystem: infra
tags: [litellm, hosted_vllm, yaml, bash, validation-ladder, reasoning_effort, enable_thinking]

# Dependency graph
requires:
  - phase: 09-preflight-gates
    provides: "PRB-01..04 gate verdicts (Phase 10 진행), the low(+28)/xhigh(+40) reach-probe oracle
      (PRB-03-ORACLE.md §4), and probe_lib.sh's preflight/postflight safety envelope"
provides:
  - "phase-10/config/config.yaml.candidate — the exact bytes proposed for 10-03 to install,
    mechanically proven to be a pure insertion over the live file"
  - "phase-10/build_candidate.sh — deterministic, idempotent, re-runnable candidate generator"
  - "phase-10/validate_config.sh — 4-rung pre-install ladder ending in a real litellm scratch boot"
  - "phase-10/selftest_validate_config.sh — negative controls proving the ladder actually rejects
    bad configs, not merely asserted to"
  - "phase-10/ALIAS-DESIGN.md — the human-facing design record for plan 10-02's checkpoint"
affects: ["10-02 (backup/rollback rehearsal + human checkpoint)", "10-03 (maintenance window install)",
  "10-04 (CFG-16 reasoning-content verification, VRF-01/02 scripts)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure line-insertion config generation (head/block/tail), never a YAML load+dump round-trip,
      to preserve a hand-annotated operational config's comments"
    - "4-rung fail-fast validation ladder ending in a real-binary scratch boot on a throwaway port,
      gated by liveness-checking the background process, not just polling the HTTP endpoint"
    - "Mutation self-test with a positive control run in the same session as the negative controls"

key-files:
  created:
    - phase-10/config/aliases-candidate.yaml
    - phase-10/build_candidate.sh
    - phase-10/config/config.yaml.candidate
    - phase-10/config/candidate-provenance.txt
    - phase-10/config/insertion-proof.txt
    - phase-10/validate_config.sh
    - phase-10/selftest_validate_config.sh
    - phase-10/ALIAS-DESIGN.md
    - phase-10/results/CURRENT_VALIDATE_RUN
  modified:
    - .planning/phases/10-alias-injection-reach-proof/10-01-PLAN.md

key-decisions:
  - "flashnext-reach-xhigh created as a verification-only alias (not shipped) because et-medium's
    -2 prompt_tokens margin is unusable as a reach probe (PRB-03-ORACLE.md §4)"
  - "flashnext-act created despite expected behavioral redundancy with plain flashnext, for
    explicitness and to hold the hosted_vllm/ prefix constant across the shipped pair ahead of
    Phase 11's A/B"
  - "validate_config.sh's rung 4 liveness check added mid-execution after observing the ladder take
    90s to notice a scratch process had already crashed"

patterns-established:
  - "Candidate configs for this project live under phase-N/config/*.candidate, never touch
    agent-stack/ or local-llm-settings/, and are proven via mechanical diff/deep-equal checks
    rather than by inspection"

# Metrics
duration: 25min
completed: 2026-09-01
---

# Phase 10 Plan 01: Candidate Config + Pre-Install Validation Ladder Summary

**Authored a pure-insertion `hosted_vllm/`-prefixed candidate litellm config and a 4-rung
pre-install validation ladder, then proved the ladder actually rejects bad configs by seeding and
observing 4 real mutants (3/3 deterministic mutants caught, 1 measurement) — without touching the
live stack at any point.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-01T04:50Z (orchestrator baseline capture)
- **Completed:** 2026-09-01T05:13Z
- **Tasks:** 3/3
- **Files modified:** 8 created, 1 plan doc corrected

## Accomplishments

- `phase-10/config/config.yaml.candidate`: 3 new `hosted_vllm/`-prefixed aliases
  (`flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh`) inserted after the `flashnext-codex`
  block, proven a pure insertion by 3 independent mechanical checks (zero removed diff lines,
  byte-identical head range through the anchor, `yaml.safe_load` deep-equal of both pre-existing
  `flashnext`/`flashnext-codex` entries against the live file).
- `phase-10/validate_config.sh`: a 4-rung ladder (YAML parse → `drop_params` ban → CFG-13 baseline
  deep-equal → real litellm 1.86.1 binary boot on 127.0.0.1:4010, probed with `GET /v1/models`
  only) that reuses `phase-09/probe_lib.sh`'s `preflight()`/`postflight()` verbatim for the
  stack-unchanged mechanism, rather than reimplementing PID/hash snapshotting.
- `phase-10/selftest_validate_config.sh`: seeded 4 deliberately broken configs plus a clean
  positive control in one session. MUTANT-1 (unclosed YAML), MUTANT-2 (`drop_params`), and
  MUTANT-3 (baseline `api_base` drift) were all `CAUGHT` at their expected rung. MUTANT-4
  (`litellm_params: null`) was also `CAUGHT`, but as a measurement, not an assertion — see
  Deviations below for what that revealed about rung 4's actual failure mechanism.
- `phase-10/ALIAS-DESIGN.md`: the human-facing record plan 10-02 will show at its checkpoint —
  the `hosted_vllm/` mechanism with line citations, the CFG-14 `drop_params` ban rationale, the
  CFG-12 `flashnext-act` decision and its expected redundancy, the weaker-proof disclosure for
  the shipped `et-medium` combination vs. the `flashnext-reach-xhigh` probe, the delta-not-absolute
  oracle framing, and the MUTANT-4 residual risk for plan 10-03.

## Task Commits

1. **Task 1: Author the alias block and a deterministic candidate builder** - `b577c6d` (feat)
2. **Task 2: Build the pre-install validation ladder, ending in a real litellm boot on a scratch
   port** - `d9e1a26` (feat)
3. **Task 3: Break the ladder on purpose, then write the alias design record** - `cc5407c` (test)

**Plan metadata:** (this commit, docs(10-01))

## Files Created/Modified

- `phase-10/config/aliases-candidate.yaml` - the exact block inserted (3 new aliases + comments)
- `phase-10/build_candidate.sh` - anchor-driven, idempotent candidate generator; aborts if the
  anchor isn't found exactly once
- `phase-10/config/config.yaml.candidate` - the candidate bytes, never installed
- `phase-10/config/candidate-provenance.txt` - anchor line + live/candidate sha256 record
- `phase-10/config/insertion-proof.txt` - the 3 pure-insertion proofs' raw output
- `phase-10/validate_config.sh` - the 4-rung ladder, with a mid-execution liveness-check fix (see
  Deviations)
- `phase-10/selftest_validate_config.sh` - the negative-control self-test
- `phase-10/ALIAS-DESIGN.md` - design record for the human checkpoint
- `.planning/phases/10-alias-injection-reach-proof/10-01-PLAN.md` - corrected two verify-line bugs
  discovered while executing Task 1 (see Deviations)

## Decisions Made

- **`flashnext-reach-xhigh` is verification-only, not shipped.** `et-medium` (the combination
  `flashnext-plan` ships) has a `prompt_tokens` delta of exactly −2 (`PRB-03-ORACLE.md` §2b, §4),
  too tight to trust as a reach probe. `xhigh` alone has a +40 delta and shares the same
  `hosted_vllm/` prefix as `flashnext-plan`, isolating the injected parameter from the provider
  path. Downstream documents must not present `et-medium`'s own margin as reach evidence — it
  isn't the arm that was used to prove reach.
- **`flashnext-act` is created despite expected behavioral redundancy with plain `flashnext`**
  (CFG-12). `enable_thinking`'s default is already `false`, so no observable difference is
  expected — it exists for explicitness and so the shipped Plan/Act pair shares one provider
  prefix ahead of Phase 11's A/B. Plan 10-04 measures this; "no measurable difference" is the
  expected, not failing, result.
- **Candidates are generated by pure line insertion, never a YAML load+dump round-trip** — the
  live file's operational comments (including 🔴-flagged history) would not survive a re-dump even
  if the `model_list` data stayed semantically identical.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's own mandated comment block collided with its own CFG-14 grep check**
- **Found during:** Task 1, running the plan's own verify block against the freshly built candidate
- **Issue:** The literal alias-block text specified in the plan's Task 1 `<action>` included the
  comment "drop_params is deliberately NOT used anywhere (CFG-14)." — which contains the exact
  substring the plan's own `grep -ci drop_params` check (and Task 2's Rung 2) bans. Inserted
  verbatim, this would have failed Task 1's own verify step and made Rung 2 falsely reject the
  clean candidate in Task 2/3.
- **Fix:** Reworded the comment in `phase-10/config/aliases-candidate.yaml` to "Silent
  parameter-dropping settings are deliberately NOT used anywhere in this file (CFG-14...)" —
  same meaning, no literal substring collision.
- **Files modified:** `phase-10/config/aliases-candidate.yaml`
- **Verification:** `grep -ci drop_params phase-10/config/config.yaml.candidate` → `0`, confirmed
  before and after every subsequent ladder run in this plan.
- **Committed in:** `b577c6d` (Task 1 commit)

**2. [Rule 1 - Bug] The plan's `grep -c 'hosted_vllm/'` verify line counts prose, not just entries**
- **Found during:** Task 1, same verify pass
- **Issue:** The mandated comment block cites `hosted_vllm/` twice in prose (once explaining the
  prefix choice, once citing `llms/hosted_vllm/chat/transformation.py:92`). An unanchored
  `grep -c 'hosted_vllm/'` therefore counts 5 matching lines, not the 3 the plan's verify line
  expected — a bug in the check, not in the candidate.
- **Fix:** Corrected the check to `grep -c '^      model: hosted_vllm/'`, which counts only the
  actual `litellm_params.model:` entries — the invariant CFG-11 actually cares about. Recorded
  the fix directly in `10-01-PLAN.md`'s verify block for the historical record.
- **Files modified:** `.planning/phases/10-alias-injection-reach-proof/10-01-PLAN.md`
- **Verification:** `grep -c '^      model: hosted_vllm/' phase-10/config/config.yaml.candidate` →
  `3`, matches the 3 new aliases exactly.
- **Committed in:** `b577c6d` (Task 1 commit)

**3. [Rule 1/2 - Bug / Missing correctness] Rung 4 took 90s to notice a scratch process had already
crashed**
- **Found during:** Task 3, observing MUTANT-4's actual behavior (not assumed)
- **Issue:** `validate_config.sh`'s original Rung 4 only polled `curl -sf .../v1/models`. When
  seeded with `litellm_params: null`, the real litellm 1.86.1 binary crashes on an **unhandled**
  `AttributeError: 'NoneType' object has no attribute 'items'` inside its own
  `proxy_server.py:4394` (`load_config()` does `model["litellm_params"].items()` with no
  None-check) and exits within ~2 seconds — but the ladder still burned the full 90-second timeout
  before declaring failure, because it never checked whether the background process was still
  alive.
- **Fix:** Added a `kill -0 "$SCRATCH_PID"` liveness check to the poll loop; the ladder now fails
  in ~2s with an explicit "scratch litellm process exited before ever serving /v1/models" message
  instead of a generic 90s timeout message.
- **Files modified:** `phase-10/validate_config.sh`
- **Verification:** Re-ran the full self-test after the fix; total self-test wall time dropped
  from what would have been ~92s (dominated by MUTANT-4's timeout) to under 10s; MUTANT-4's
  `ladder.tsv` row now reads "scratch litellm process (pid N) exited after 2s...".
- **Committed in:** `cc5407c` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (2 plan-verify bugs, 1 missing-correctness fix to the ladder
itself). All were necessary for the plan's own verify blocks and the ladder's own usefulness to
hold true; no scope creep.

## Issues Encountered — external, not acted on

While executing, `git status` revealed **uncommitted, pre-existing edits** to
`.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` (not made by this execution) adding a new
requirement **CFG-17** — remove the 6 deprecated `qwen-*` aliases (live config lines 34–50) from
the live config, folded explicitly into this plan's scope by the edited ROADMAP text ("10-01-PLAN.md
— 후보 설정 작성(신규 별칭 추가 **+ CFG-17 deprecated 6개 삭제**)").

**This was not acted on**, for two reasons:
1. The authoritative `10-01-PLAN.md` (the file this execution was instructed to follow, explicitly
   over any summary) contains no CFG-17 task, and its own `must_haves.truths` states "every line of
   the live file survives unchanged in the candidate" — a pure-insertion invariant that a deletion
   of lines 34–50 would directly contradict. Silently expanding scope to satisfy an out-of-band,
   uncommitted doc edit would have violated this plan's own stated contract without a decision from
   the plan's owner.
2. This is an architectural-scope change (insertion-only → insertion+deletion), not a bug, gap, or
   blocker fixable within the current plan's design — exactly the class of change this execution's
   instructions require stopping for rather than resolving unilaterally.

`.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` were left exactly as found (modified,
unstaged, not committed by this execution) so the orchestrator can decide whether to amend
`10-01-PLAN.md` (already executed — would need a follow-up plan or a 10-01b), fold CFG-17 into
plan 10-03's maintenance window (which the edited ROADMAP text itself suggests: "이 페이즈의
유지보수 창에 합류"), or otherwise reconcile. Also noticed, unrelated: commit `f817155`
("docs(howto): add thinking/reasoning_effort verification guide") landed in this repository's
history during this execution window from what appears to be a separate, concurrent session —
does not touch any file this plan modified.

## User Setup Required

None — no external service configuration required. Nothing was installed; nothing to configure.

## Next Phase Readiness

**Ready for plan 10-02** (backup/rollback rehearsal + human checkpoint): `config.yaml.candidate`
exists, is proven a pure insertion, and has passed its own validation ladder (4/4 rungs) with the
ladder itself proven to catch bad configs (3/3 deterministic mutants caught; 1 measurement
recorded). `ALIAS-DESIGN.md` is ready to show the human at that checkpoint.

**Blockers/concerns to carry forward:**
- **CFG-17 reconciliation is unresolved** (see Issues Encountered above) — the orchestrator/user
  needs to decide how the deprecated `qwen-*` alias removal joins this phase's sequence before
  plan 10-03's maintenance window is finalized, since ROADMAP.md as currently (uncommittedly)
  edited expects it there.
- **MUTANT-4's residual risk** (recorded in `ALIAS-DESIGN.md` §7): rung 4 caught this particular
  schema-invalid shape only because litellm's own config loader throws an *unhandled* exception for
  it, not because of graceful validation. A clean scratch boot is necessary but not proven
  sufficient evidence of config correctness for every possible misconfiguration shape — only the
  four classes actually exercised by this self-test.
- Live stack fully unchanged throughout this plan: pids 46573 (flashnext) / 75548 (role-shim) /
  48525 (litellm) all match the orchestrator's pre-execution baseline; live config sha256
  `12e102cf66e50f5a...` and `providers.json` sha256 `5cf3800da31de885...` both match; port 3000
  never bound; port 4010 released after every ladder run; `verify_config.sh` exits 0.

---

## Addendum (2026-09-01, post-execution): CFG-17 reconciliation resolved

The "CFG-17 reconciliation is unresolved" blocker recorded above, in the original execution's
"Issues Encountered" and "Blockers/concerns to carry forward" sections, has been resolved. This
addendum records how, by whom, and when — the original text above is left exactly as this plan's
execution wrote it, per this project's standard of not rewriting history.

**Resolved by:** orchestrator-directed corrective work against this plan's already-committed
artifacts (not a new plan, not a re-execution of 10-01). Requested directly by the user.

**When:** 2026-09-01, after this plan's own execution (commits `b577c6d`/`d9e1a26`/`cc5407c`/
`95bffd3`) and after CFG-17 itself was added to `REQUIREMENTS.md`/`ROADMAP.md` and committed as
`dbe79bc`.

**What changed:**
- `phase-10/build_candidate.sh` now also deletes the six deprecated `qwen-*` aliases (previously a
  pure insertion; now insertion + one verified deletion). The deletion is anchor-driven, not a
  hardcoded line range, and aborts loudly if the block found doesn't structurally match CFG-17's
  six named aliases exactly, or if it mentions `flashnext` anywhere.
- `phase-10/config/config.yaml.candidate` was regenerated: 73 lines (was 90), containing
  `flashnext`, `flashnext-codex`, `flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh` — the
  six `qwen-*` aliases are gone. Rebuild is idempotent (verified: two consecutive runs produce
  byte-identical sha256 `d7278a9f...`).
- `phase-10/config/insertion-proof.txt` was deleted and replaced by
  `phase-10/config/candidate-proof.txt`. Proof 1 is now a **stronger** claim than before: not "zero
  lines removed" but "every removed line is individually classified as the deprecated comment
  header or one of the 6 named `qwen-*` aliases, and nothing else" (16 lines, enumerated one by
  one). Proofs 2 and 3 are mechanically unchanged; Proof 3 additionally asserts the six deprecated
  names are absent from the candidate.
- `phase-10/validate_config.sh` required **no changes** — confirmed rather than assumed. Rung 3
  (CFG-13) only ever compared `flashnext`/`flashnext-codex`, both unaffected by the deletion. Rung
  4's alias checklist (`flashnext`, `flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh`)
  contains no `qwen-*` name either. Re-ran the full ladder against the regenerated candidate anyway,
  including the real scratch boot on 127.0.0.1:4010: all 4 rungs PASS (run dir
  `phase-10/results/20260901T052358Z-validate`).
- `phase-10/selftest_validate_config.sh` gained **MUTANT-5** (`deletion-overreach`): the
  CFG-17-compliant candidate with `flashnext`'s `api_base` additionally corrupted — the negative
  control for the deletion mechanism itself, proving it can't silently reach into the aliases
  CFG-13 protects. Rung 3 catches it, enforced (not a measurement) like MUTANT-1/2/3. Also, while
  re-running the self-test, found and fixed a real bug (Rule 1): MUTANT-1's original anchor was the
  deprecated `qwen-local` inline flow-mapping entry, which CFG-17's deletion removes — the mutant
  generator would raise `SystemExit` and silently produce no mutant file at all, and the ladder
  would then run against a stale leftover config, giving a false `CAUGHT` reading for the wrong
  reason. Retargeted MUTANT-1 at `flashnext`'s own block-style `litellm_params:` line (guaranteed to
  survive every future candidate under CFG-13); re-verified it independently raises a real
  `yaml.parser.ParserError` before wiring it back into the self-test. Full re-run: clean candidate
  PASS, MUTANT-1/2/3/4/5 all `CAUGHT` at their expected rung (MUTANT-4 remains a recorded
  measurement, not an enforced check) — run dir `phase-10/results/20260901T052644Z-validate`.
- `ALIAS-DESIGN.md` gained a new §2 ("What is being removed, and why (CFG-17)") covering the
  justification (the config's own stated deletion condition, met per server logs: 0 `qwen-*`
  requests vs. 163 `flashnext` requests since the current `litellm` instance started) and why it
  rides this plan's maintenance window rather than a separate restart. Sections were renumbered
  1→1, 2→3, 3→4, 4→5, 5→6, 6→7, 7→8 to make room; internal cross-references were updated to match.
  **The "`ALIAS-DESIGN.md` §7" reference in this SUMMARY's "Blockers/concerns" section above (for
  the MUTANT-4 finding) is now stale — that content lives at §8 as of this addendum.** §9 gained a
  parallel MUTANT-5 finding.
- `10-01-PLAN.md`'s `must_haves`, Task 1's `<action>`/`<verify>`/`<done>`, and the plan-level
  `<verification>`/`<success_criteria>` were annotated in place (dated 🔴 notes, not rewrites) to
  state that the pure-insertion invariant is superseded by "insertion + the CFG-17 deletion," with
  CFG-13's byte-identical guarantee on `flashnext`/`flashnext-codex` named as the invariant that
  still holds.

**Stack safety throughout this corrective work:** the live config's sha256
(`12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c`) and the three tracked pids
(46573/75548/48525) were reconfirmed identical before this work started and after it finished.
Nothing under `/Users/ohama/agent-stack/` or `~/local-llm-settings/` was written; no service was
restarted; port 3000 was never bound; port 4010 was released after every ladder/self-test run
(confirmed via `lsof`); `providers.json` was not touched. This corrective work produced a candidate
only — installation remains plan 10-03's job.

---
*Phase: 10-alias-injection-reach-proof*
*Completed: 2026-09-01*
