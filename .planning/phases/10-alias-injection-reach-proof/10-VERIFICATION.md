---
phase: 10-alias-injection-reach-proof
verified: 2026-09-02T01:05:15Z
status: passed
score: 7/7 must-haves verified (all six PLAN.md frontmatters, all seven ROADMAP success criteria)
---

# Phase 10: 별칭 주입과 도달 증명 — Verification Report

**Phase Goal:** `flashnext-plan` (and, per PRB-02, `flashnext-act`) are added to litellm, observed
to work in a real `cline` CLI run, and the injected parameters are proven to have reached the model
by server-side evidence, not an HTTP 200.

**Verified:** 2026-09-02T01:05:15Z
**Status:** passed
**Re-verification:** No — initial verification

## Method

This report is built entirely from re-derived, independently-reproduced evidence, not from trusting
SUMMARY prose or REACH-PROOF.md's tables. Every figure below was recomputed directly against the
live system or the raw JSON/NDJSON artifacts during this pass (commands and outputs shown are the
actual verifier session, not restated from the phase's own documents).

## Goal Achievement — Observable Truths (ROADMAP criteria 1, 1b, 2, 3, 4, 5, 6, 7)

| # | Truth | Status | Evidence (independently reproduced this pass) |
|---|---|---|---|
| 1 | Live config injects `flashnext-plan` with `enable_thinking:true` + `reasoning_effort:medium`, `drop_params` absent | VERIFIED | `grep -in drop_params /Users/ohama/agent-stack/litellm/config.yaml` → no match, exit 1. `diff` of backup vs live shows the exact insertion (39 lines) reproduced live in this session, matching `CFG-13-EVIDENCE.md` byte for byte. |
| 1b | The two-parameter combination actually produces `reasoning` at both `:8011` and `:4000` | VERIFIED | Re-parsed `phase-10/results/20260901T085111Z-cfg16/raw-cfg16-*.json` directly: `:8011` direct has `message.reasoning`=284 chars; `:4000` via `flashnext-plan` has `reasoning_content`/`provider_specific_fields.reasoning`=284 chars; `:4000` via unmodified `flashnext` control = 0 chars in both fields. `cfg16.tsv` matches this exactly. |
| 2 | `flashnext-act` creation decision + PRB-02 basis + stated redundancy | VERIFIED | `ALIAS-DESIGN.md` §5 states the PRB-02 basis and predicts behavioral redundancy with `flashnext`; `REACH-PROOF.md` §5 (`G` vs `B`, delta=0) measures the prediction true. Re-derived from `reach.tsv`: arm G (flashnext-act)=13, arm B (flashnext)=13 — confirmed. |
| 3 | `flashnext`/`flashnext-codex` byte-identical before/after | VERIFIED | Re-ran the diff myself: `head -n 34` of backup vs live is byte-identical (witness hash `06814402...` reproduced independently), `yaml.safe_load` deep-equal logic reproduces the same two MATCH results reported in `CFG-13-EVIDENCE.md`. All 16 removed lines are the CFG-17 deprecated block only — re-enumerated and confirmed to match the doc's classification table exactly. |
| 4 | Differing server-log `prompt_tokens` between `flashnext` and `flashnext-plan`, judged on log not HTTP status | VERIFIED | Re-read `reach.tsv` raw rows directly: B (flashnext)=13, D (flashnext-plan)=11 (delta −2, oracle-matching `medium`); F (flashnext-reach-xhigh)=53, D vs F delta=+42 (oracle-matching). Cross-checked against `raw-reach-1-B.json`'s `usage.prompt_tokens`=13 — matches the log line exactly. `reach-report.txt` prints the log-not-status basis in words, confirmed present. |
| 5 | Re-runnable script + `sync.sh` reflects change; both 2026-09-01 corrections honoured | VERIFIED | `shasum -a 256` of live config and mirror both = `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e` (matches the exact hash specified in the verification brief), `diff` empty. Mirror git log shows commit `a1ffaf6` with a correct, disclosed scope note about ~2 days of swept-in unrelated drift. New aliases confirmed `hosted_vllm/` prefix; existing two kept `openai/`. |
| 6 | Real `cline` CLI run against `flashnext-plan`, NDJSON `reasoning` observed, control alongside | VERIFIED | Re-derived counts myself from raw `ndjson-plan.log`/`ndjson-control.log` (not from `VRF-04-OBSERVATION.md`'s own tables): `jq` shows 274 `agent_event` records in the plan stream containing 146 occurrences of the string `"reasoning"` across `content_start`/`contentType=="reasoning"` events with real multi-token reasoning text (`"The"`, `" user"`, `" is"`, `" asking"`...); the control stream has zero occurrences of `"reasoning"` anywhere. Both reached the same correct final answer. |
| 7 | Deprecated `qwen-*` (6) removed, `flashnext`/`flashnext-codex` preserved | VERIFIED | Same diff as #3 above — all 6 named aliases + comment header are the entirety of the 16 removed lines; nothing else touched. |

**Score:** 7/7 (all ROADMAP criteria, including 1b and 7) verified true against the live system and raw artifacts.

## Required Artifacts (all six plans' `must_haves.artifacts`)

Every artifact listed in the six PLAN.md frontmatters was checked for existence and for its
required `contains` string; all passed (`hosted_vllm` in build_candidate.sh, `drop_params` in
validate_config.sh, `MUTANT` in selftest_validate_config.sh, `CFG-12` in ALIAS-DESIGN.md,
`shasum` in rollback_config.sh, `restart_service.sh` in ROLLBACK.md, `flashnext-plan` in
CHANGE-BRIEF.md, `role-shim` in probe_lib10.sh, `postflight10` in selftest_probe_lib10.sh,
`v1/models` in health_check.sh, `UTC` in MAINTENANCE-LOG.md, `CFG-13` in CFG-13-EVIDENCE.md,
`reasoning_content` in probe_cfg16.sh, `prompt_tokens` in verify_reach.sh, `VRF-02` in
REACH-PROOF.md, `CLINE_NO_AUTO_UPDATE` in probe_vrf04_cline.sh, `VRF-04` in
VRF-04-OBSERVATION.md, `sync.sh` in sync_and_verify.sh, `CFG-15` in PHASE-10-FINDINGS.md).

Beyond existence and grep-level substantiveness, three artifacts' *behavior* was directly
re-executed in this pass rather than trusted from disk:

- `bash phase-10/selftest_validate_config.sh` — re-run live: clean candidate PASS, MUTANT-1/2/3/5
  each CAUGHT at the expected rung, MUTANT-4 (measurement, not enforced) CAUGHT. This confirms the
  anchor-rot bug the task brief warned about was already fixed and the ladder currently works, not
  merely that a stale result exists on disk.
- `bash phase-10/selftest_probe_lib10.sh` — re-run live: clean-control PASS (exit 0),
  seeded-pid-mismatch/seeded-hash-mismatch/seeded-restart-expect-mismatch all correctly FAIL
  (exit 1). The safety envelope genuinely rejects bad state, not just on the day it was written.
- `bash phase-01/config/verify_config.sh` — re-run live: exit 0, confirming `providers.json`'s
  `model`/`contextWindow` invariant (the corrected invariant per the disclosed `da53de13...` hash
  drift) still holds.

## Key Link Verification

All `key_links` regex patterns across the six plans were checked against their `from` files and
matched (`agent-stack/litellm/config\.yaml`, `agent-stack/venv/bin/litellm`,
`phase-02/infra/restart_service\.sh`, `validate_config\.sh`, `rollback_config\.sh`,
`probe_lib\.sh`, `Prefill started|flashnext\.err`, `probe_lib10\.sh`, `PRB-03-ORACLE`,
`-m flashnext`, `phase-10/results/`, `local-llm-settings/sync\.sh`, `REACH-PROOF`,
`VRF-04-OBSERVATION`, `config\.yaml\.candidate`). No orphaned or unwired must-have artifact found.

## Live System Cross-Checks (performed directly, not cited from documents)

| Check | Result |
|---|---|
| `curl http://localhost:4000/v1/models` | Exactly 5 aliases: flashnext, flashnext-codex, flashnext-plan, flashnext-act, flashnext-reach-xhigh |
| Live config sha256 | `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e` — matches expected |
| Mirror config sha256 | Identical to live; `diff` empty |
| `com.ohama.flashnext` pid | 46573 — unchanged |
| `com.ohama.role-shim` pid | 75548 — unchanged |
| `bash phase-01/config/verify_config.sh` | exit 0 |
| Reach numbers re-derived from raw JSON `usage.prompt_tokens` and `reach.tsv` log lines | B=13, D=11 (Δ−2, oracle `medium`), F=53 (D vs F Δ+42, oracle-exact), G=13 (Δ0 vs B, confirms CFG-12 redundancy prediction) |
| VRF-04 reasoning-event re-count from raw NDJSON | 146 `"reasoning"` occurrences across 274 `agent_event`s in the plan stream; 0 in the control stream |
| CFG-13 16-line removal re-enumeration | All 16 lines = CFG-17 deprecated header + 6 named qwen-* aliases; nothing else |

## Anti-Patterns Found

None blocking. The phase's own `PHASE-10-FINDINGS.md` §4.6 discloses six real instrument bugs found
during execution (selftest anchor rot, 90s crash-detection lag, two "pure insertion" prose
assertions made false by CFG-17, the Restart B outage sampler killed by inherited `set -e`, and the
report-writer `p()` helper dropping continuation lines) — all six were confirmed, during this
verification pass, to have been fixed and/or accurately disclosed rather than silently smoothed
over: the selftest and safety-envelope selftest both currently pass on live re-execution, and
REACH-PROOF.md's currently-checked-in prose (re-read in this pass) is intact and readable, not
truncated.

## Requirements Coverage

All ten `.planning/REQUIREMENTS.md`-tracked Phase 10 requirements (CFG-11..16, VRF-01..04) plus the
user-added CFG-17 are given a disposition and evidence path in `PHASE-10-FINDINGS.md` §2/§3, each
independently spot-checked above. `.planning/REQUIREMENTS.md`'s own tracking table still shows these
rows as `Pending`/unchecked — this is **not** a phase gap: `PHASE-10-FINDINGS.md` explicitly and
correctly states "the orchestrator owns REQUIREMENTS.md at phase close" (consistent with Phase 9's
PRB-01..04 rows, which were only flipped to `Complete` after that phase's own gate verdict was
recorded). Recorded here as an orchestrator follow-up, not a plan/phase defect.

## Known, Already-Disclosed Weaknesses (confirmed present and accurately stated — not reported as gaps)

Per the task brief, the following are deliberately excluded from the gap analysis because they are
already disclosed in `PHASE-10-FINDINGS.md` §4 and `.planning/STATE.md`, and this pass confirms the
disclosures are honest and match the underlying data:

- Reach's wide-margin proof rests on `flashnext-reach-xhigh` (+42), not the shipped `flashnext-plan`
  (−2); both figures reproduced independently in this pass and match the labelling in the findings.
- Restart B's outage genuinely has no sampler-measured figure; `outage-B.tsv` really does contain
  exactly one row, confirming "NOT MEASURED" is accurate, not a backfilled estimate.
- `cline` drifted to 3.0.60; Phase 9's `cli-v3.0.53` line citations were correctly not re-claimed
  as re-verified at the new version — VRF-04-OBSERVATION.md §3 states this distinction explicitly.
- `cline -m`'s rewrite of `providers.json`'s `updatedAt` (new hash `da53de13abdac56b...`) is real;
  `model` and `contextWindow` were confirmed still correct via `verify_config.sh` exit 0 in this pass.
- 10-04's 48-vs-17 request overage is stated in `PHASE-10-FINDINGS.md` §4.5 and is consistent with
  the three `-reach` and two `-cfg16` result directories actually present on disk.
- MUTANT-4 is correctly framed as a measurement (litellm's own unhandled `AttributeError`), not an
  enforced guarantee — confirmed by reading `selftest_validate_config.sh`'s own comments and by the
  live re-run above.
- The mirror repo's commit `a1ffaf6` sweeping in ~2 days of unrelated drift is disclosed in
  `mirror-commit-scope-note.txt` with a plausible, checked root cause (uncommitted prior `sync.sh`
  writes); the commit diff itself confirms the extra files (kanban/telegram plists) are present.

## Human Verification Required

None. Every must-have and every ROADMAP criterion in this phase was verifiable programmatically
against the live system or raw recorded artifacts, and was so verified in this pass.

## Gaps Summary

No gaps found. This phase's SUMMARYs, ALIAS-DESIGN.md, CFG-13-EVIDENCE.md, REACH-PROOF.md,
VRF-04-OBSERVATION.md, and PHASE-10-FINDINGS.md all match what was independently re-derived from
the live litellm server, the raw JSON completion bodies, the raw NDJSON `cline` streams, and the
git/hash state of both the live config and its mirror. The two live selftest scripts
(`selftest_validate_config.sh`, `selftest_probe_lib10.sh`) were re-executed during this pass and
both currently pass for real, not merely on the day they were written — directly addressing the
task brief's core concern that instruments in this phase have previously reported clean while
observing nothing. No must_have in any of the six PLAN.md frontmatters was found satisfied in prose
but absent on disk, and no ROADMAP criterion's cited evidence path was missing, empty, or
contradicted its claim.

---

*Verified: 2026-09-02T01:05:15Z*
*Verifier: Claude (gsd-verifier)*
