---
phase: 12-documentation-update
plan: 05
subsystem: docs
tags: [litellm, hosted_vllm, reasoning_effort, enable_thinking, alias-config, cline]

# Dependency graph
requires:
  - phase: 12-01
    provides: phase-12/verify_docs.sh (the grader this plan was written against)
  - phase: 10
    provides: flashnext-plan/flashnext-act/flashnext-reach-xhigh alias definitions, REACH-PROOF.md delta measurements, qwen-* removal (CFG-17)
  - phase: 11
    provides: WRAPPER-DESIGN.md deny-by-default rationale, per-prefix --thinking failure modes (OPEN-ITEMS.md Open Item 1)
provides:
  - "docs/cline-config-pins.md §7: v1.1 alias pin table (5 live + 6 removed), flashnext-reach-xhigh's decided verification-only/v1.2-removal disposition, per-prefix --thinking status codes, and the pin-vs-measurement rule"
affects: [12-06 (docs/32k-compaction-policy.md, docs/cline-max-tokens-findings.md — linked, not restated), 12-08 (REQUIREMENTS.md/ROADMAP.md annotation of the imprecise flat-400 wording)]

tech-stack:
  added: []
  patterns: ["pins vs measurements documentation convention: judge future drift on deltas and on named fields (model/contextWindow), never on absolutes or file hashes"]

key-files:
  created: []
  modified:
    - docs/cline-config-pins.md

key-decisions:
  - "Title changed from '(CFG-04, CFG-05, CFG-06)' to '(Phase 1: CFG-04·CFG-05·CFG-06 / v1.1: CFG-11..17)' — the old title no longer covered the file's contents and the exact old literal is a verify_docs.sh anchor that must be gone."
  - "Did not create a fourth copy of the reach-delta table — cited phase-10/REACH-PROOF.md §3 as source of record and noted howto/ carries the same figures for self-service verification."
  - "Deliberately avoided the literal substrings 'A/B' and 'AB-RESULTS' anywhere in this file, since this file's job is pins, not A/B outcome — this keeps verify_docs.sh's AB_DISCLOSURE check in its untriggered state rather than needing to satisfy its four-element disclosure requirement for a topic out of this file's scope."

patterns-established:
  - "Extend an existing pins file with a new numbered section in its own vocabulary (고정/요구사항/증거) rather than inventing a new structure, and state explicitly when no preserved-original appendix is needed because the addition is pure new content, not a correction of existing text."

# Metrics
duration: ~25min
completed: 2026-09-10
---

# Phase 12 Plan 05: v1.1 Alias Pins Summary

**Added §7 to `docs/cline-config-pins.md`: the five live litellm aliases (prefix, injected params, status), the six removed `qwen-*` aliases named as historical, `flashnext-reach-xhigh`'s decided verification-only/v1.2-removal disposition with the +40-vs−2 reach-margin disclosure, `--thinking`'s per-prefix failure mode (400/500/exit 1), and the pin-vs-measurement rule separating what must not drift from what already has.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-09-10T08:50:22Z
- **Tasks:** 2/2 (both `type="auto"`)
- **Files modified:** 1 (`docs/cline-config-pins.md`)

## Accomplishments

- Documented all five live aliases (`flashnext`, `flashnext-codex`, `flashnext-plan`, `flashnext-act`, `flashnext-reach-xhigh`) in a table with prefix, injected parameters, and status, cross-checked read-only against the live `~/local-llm-settings/config/litellm-config.yaml` (`grep -c 'model_name: flashnext'` → 5, exact name match).
- Named the six removed `qwen-*` aliases as historical and no longer reachable (CFG-17).
- Recorded `flashnext-reach-xhigh`'s decision as final (stays, verification-only, v1.2 removal candidate) — closing an item deferred twice — and stated the reach-margin disclosure precisely: the wide-margin proof (+40) belongs to this never-shipped alias, not to the shipped `flashnext-plan` (−2).
- Gave `--thinking`'s three distinct outcomes by prefix (400 on `openai/`, 500 on `hosted_vllm/`, raw `cline --thinking high` exits 1 having seen neither), and flagged that the requirement's own flat "400" wording is imprecise rather than propagating it silently.
- Wrote the pin-vs-measurement rule explicitly: alias names/injected params, the `hosted_vllm/` vs `openai/` prefix, and `providers.json`'s `model`/`contextWindow` are pins; absolute `prompt_tokens` (23/21/51/63 → 13/11/41/53) and the wire `max_tokens` (formerly "fixed 2048", measured 20983, now known dynamic) are measurements that have already drifted and must never be treated as constants. Future drift is judged on deltas and on named fields, never on absolutes or file hashes.
- Stated that `providers.json` is repeatedly corrected, never stable — every uncontained `cline -m` call rewrites `model` (매 호출/호출마다), which the verify_docs.sh `per-call-write` check enforces mechanically.

## Task Commits

1. **Task 1 + Task 2 (combined into one commit)** — `4cac906` (docs)
   The plan's two tasks (alias pin table; `--thinking` failure modes + pin-vs-measurement rule) were both additions to the same new §7 section of the same file, written and verified together before the single commit for this plan.

**Plan metadata:** commit `4cac906` above is this plan's only commit (per the constraint: `git commit -m "..." -- docs/cline-config-pins.md`, explicit pathspec, no `git add .`/`-A`).

## Files Created/Modified

- `docs/cline-config-pins.md` — title corrected, intro note added pointing to the new §7, and §7 (v1.1 별칭 고정, CFG-11..17) added with 8 subsections: live-alias table (7.1), removed qwen-* (7.2), flashnext-reach-xhigh disposition (7.3), per-prefix --thinking failure modes (7.4), pin-vs-measurement rule (7.5), providers.json repeated-correction note (7.6), version-pin interaction cross-reference (7.7), pointer to wrapper usage docs (7.8).

## Decisions Made

- Title literal `(CFG-04, CFG-05, CFG-06)` replaced with `(Phase 1: CFG-04·CFG-05·CFG-06 / v1.1: CFG-11..17)` — required by the plan's own verify command (`grep -n 'CFG-04, CFG-05, CFG-06'` must return nothing) and genuinely necessary since the old title no longer described the file.
- No fourth copy of the reach-delta table was created; `phase-10/REACH-PROOF.md` §3 is cited as source of record, with `howto/thinking-and-reasoning-effort.md` and `howto/fast-and-deep-mode.md` noted as carrying the same figures for a different (self-service verification) purpose.
- The A/B outcome (keep-vs-revert, override reasoning) was deliberately kept entirely out of this file — it is out of scope for a pins document and the plan's own task text never asked for it. No literal "A/B" or "AB-RESULTS" string appears anywhere in the file, so `verify_docs.sh`'s conditional `AB_DISCLOSURE` check stays in its untriggered ("does not mention the A/B") state rather than needing to be satisfied for a topic this file has no business discussing.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' `<action>` content was followed directly; the pre-registered `<verify>` commands in the plan (per-string anchor checks, `v1.2` count, title-literal absence, delta/per-call-write presence, `verify_docs.sh` grep, `git log -1 --stat`) all passed on the first attempt after writing the content, with no fix-up commit needed.

## Issues Encountered

None. The only live check performed was the read-only `grep` against `~/local-llm-settings/config/litellm-config.yaml` (permitted by the plan's constraints as "the only live check needed"); no curl, no wrapper invocation, no model request, no service restart, and no edit to `providers.json`, `phase-11/wrapper.env`, or any litellm config.

## User Setup Required

None — documentation only, no external service configuration required.

## Next Phase Readiness

- `docs/cline-config-pins.md` now satisfies USE-04 criterion 2 and ROADMAP Phase 12 criterion 2 for the alias-pin/`--thinking`/pin-vs-measurement content. `bash phase-12/verify_docs.sh` reports zero `FAIL[DOCS]` lines naming this file (confirmed both before commit and after: `git diff --name-only HEAD~1 HEAD` → only `docs/cline-config-pins.md`).
- `bash phase-01/config/verify_config.sh` still exits 0 after this plan — no stack, config, or `providers.json` mutation occurred.
- Plan 12-08 still needs to annotate `.planning/REQUIREMENTS.md` USE-04 and `.planning/ROADMAP.md` Phase 12 criterion 2's own flat "400" wording — this plan's §7.4 supplies the corrected per-prefix text for 12-08 to point at, but does not itself edit either of those two files (out of this plan's scope by explicit instruction).
- No blockers for sibling wave-2 plans: this plan touched only `docs/cline-config-pins.md`, confirmed by `git status --short` before commit showing the other four in-flight sibling files (`docs/manual/01-cli.md`, `docs/plan-act-reasoning-design.md`, `docs/plan-act-reasoning-implementation.md`, `howto/fast-and-deep-mode.md`, `howto/thinking-and-reasoning-effort.md`) as pre-existing, untouched-by-this-plan modifications belonging to other concurrently-running plans.

---
*Phase: 12-documentation-update*
*Completed: 2026-09-10*
