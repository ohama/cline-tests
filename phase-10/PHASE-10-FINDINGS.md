# PHASE-10-FINDINGS.md — Phase 10 requirement and criterion account

Phase 10 plan 06. This document is the phase's account of itself: what changed on the machine,
whether each requirement and each ROADMAP success criterion was met, and — the point of this
document — which of those "Met" verdicts are weaker than they look. Phases 11 and 12 read this;
so does anyone auditing the v1.1 milestone later.

**Outcome neutrality, stated once, up front:** this document reports the phase as it happened.
Where a result came back negative, unresolved, or measured-but-weak, that is recorded as the
result, not smoothed into a green row. It is complete when every requirement has an honest
disposition, not when every requirement is green — and in fact none of them came back negative in
this phase; the weakness that exists here is not in whether things worked, but in how strong the
proof is that they did, and in what several of this phase's own instruments were later found not
to be watching. §4 exists specifically to keep that distinction visible.

---

## §1 What changed on this machine

Three new `model_list` entries were added to the one file `litellm` actually loads,
`/Users/ohama/agent-stack/litellm/config.yaml`, all under a `hosted_vllm/` provider prefix (never
`openai/`, which 400s on `reasoning_effort` for this model): **`flashnext-plan`** (injects
`enable_thinking: true` + `reasoning_effort: medium`, the shipped Plan-mode alias), **`flashnext-act`**
(injects `enable_thinking: false`, the shipped Act-mode alias), and **`flashnext-reach-xhigh`**
(injects `reasoning_effort: xhigh`, verification-only, never a shipped surface). In the same edit,
at the user's explicit instruction (CFG-17), the six deprecated `qwen-*` aliases and their comment
header were deleted from the file's tail; `flashnext` and `flashnext-codex` are byte-identical
before and after (`phase-10/CFG-13-EVIDENCE.md`, three independent proofs). The live file's sha256
is now `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e` (was
`12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c`). The **generated mirror**,
`~/local-llm-settings/config/litellm-config.yaml`, was left diverged by design through plans
10-03/10-04/10-05 and was brought back into agreement by this plan's `sync.sh` run (this
document's own Task 1; see CFG-15 below) — it is now byte-identical to the live file and its own
git repository (the mirror's only version history) carries commit `a1ffaf6`. **`providers.json`
(`~/.cline/data/settings/providers.json`) was never written by this phase's config-change work**
(10-01 through 10-04, and this plan) — but it was written, as a documented side effect of the real
`cline` 3.0.60 binary's own `-m` invocation, during plan 10-05's VRF-04 run: only its
`openai-compatible.updatedAt` timestamp moved (`5cf3800da31de885...` → `da53de13abdac56b...`); the
pinned fields `model` (`flashnext`) and `contextWindow` (`29000`) that
`phase-01/config/verify_config.sh` actually asserts are unaffected, and that script still exits 0.
The backup of the pre-mutation live file lives at
`phase-10/backups/config.yaml.20260901T053509Z` (sha256
`12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c` — equal to the live file's own
hash at capture time). **The maintenance window's disposition is `INSTALLED`** (no rollback was
needed or taken; `phase-10/MAINTENANCE-LOG.md`). Its measured outage figures: Restart A (rehearsal,
unmodified config) is genuinely measured at **≈7 seconds** by a working 0.5s sampler, with
`restart_service.sh`'s own T0/T1 wall-clock giving an **8-second** upper bound; Restart B (the real
install) has **no working sampler measurement at all** — the sampler died on the first
connection-refused sample it took, under an inherited `set -e`, and the only figure available for
Restart B is the same 8-second `restart_service.sh` T0/T1 bound, offered as context, not as a
measurement (see §4.2 below; do not read this as "Restart B also took ~7s").

---

## §2 Requirement table

Ten rows, matching this document's own must-have scope and `.planning/REQUIREMENTS.md`'s Phase 10
requirement-tracking table (which itself lists exactly these ten under Phase 10 — see the note on
CFG-17 immediately below the table).

| Requirement | Disposition | Evidence path |
|---|---|---|
| **CFG-11** — `flashnext-plan` injects both `enable_thinking:true` and `reasoning_effort:medium` together | Met | `phase-10/config/config.yaml.candidate` (lines 48–54); `phase-10/CFG-13-EVIDENCE.md` Check 1 (installed file, identical bytes); live file `/Users/ohama/agent-stack/litellm/config.yaml` |
| **CFG-12** — `flashnext-act` created because PRB-02 passed, with its expected redundancy stated and then measured | Met | `phase-10/ALIAS-DESIGN.md` §5 (the PRB-02 basis and the redundancy prediction); `phase-10/REACH-PROOF.md` §5 (the measured `G` vs `B` delta = 0, confirming the prediction) |
| **CFG-13** — `flashnext` byte-identical, before vs. after | Met | `phase-10/CFG-13-EVIDENCE.md` Checks 1–3 (raw diff classified, head-range byte identity, `yaml.safe_load` deep-equal), run against the **installed** file, not just the candidate |
| **CFG-14** — no `drop_params` in any form | Met | `phase-10/CFG-13-EVIDENCE.md` Check 4 (`grep -in drop_params` → no match, exit 1, against the installed file) |
| **CFG-15** — the change is reflected in `~/local-llm-settings` and in `sync.sh`'s own output | Met | `phase-10/sync_and_verify.sh`; `phase-10/results/20260902T005212Z-sync/sync-check-after.txt` (verbatim `✅ 실제 시스템과 일치한다`, exit 0); mirror commit `a1ffaf6` in `~/local-llm-settings` |
| **CFG-16** — the shipped two-parameter combination actually produces `reasoning` at both `:8011` and `:4000` | Met | `phase-10/REACH-PROOF.md` §2 (`phase-10/results/20260901T085111Z-cfg16/cfg16.tsv`: 284 chars at both endpoints, both field spellings checked, 0 chars at the `flashnext` negative control). No `CFG-16-REMEDIATION.md` exists — the negative branch that would require one was never triggered. |
| **VRF-01** — `flashnext` vs `flashnext-plan`, same message, differing server-log `prompt_tokens` | Met — **see §4.1: the wide-margin proof (`D` vs `F`, +42) is what this rests on, not the shipped arm's own −2 (`B` vs `D`)**, which is reported separately in the same document as the weaker corroborating reading | `phase-10/REACH-PROOF.md` §3a (wide-margin) and §3b (shipped arm, labelled weaker); `phase-10/results/20260901T085700Z-reach/reach.tsv` |
| **VRF-02** — the disposition basis is the server log, not the HTTP 200 status | Met | `phase-10/REACH-PROOF.md` §3c (all 7 arms return HTTP 200 including the arms whose token counts nonetheless differ — the table exists specifically to show 200 carries no information here) |
| **VRF-03** — a re-runnable verification script, not a one-off | Met | `phase-10/verify_reach.sh` (re-run with `bash phase-10/verify_reach.sh` from the repo root, model idle); demonstrated re-run 3 times during 10-04's own execution (see §4.6) |
| **VRF-04** — real `cline` CLI execution, `reasoning` observed in the `--json` NDJSON stream at `flashnext-plan`, alongside a control | Met (positive observation) — **see §4.3 and §4.5: single prompt, single cline version, and CFG-05 means the binary can move under this conclusion** | `phase-10/VRF-04-OBSERVATION.md` §1–§2 (72 `content_start` reasoning events / 198 chars at `flashnext-plan`, 0 at the `flashnext` control, confirmed by two independent extraction methods); `phase-10/results/20260901T091011Z-vrf04/` |

**A note on CFG-17, deliberately not an eleventh row here:** CFG-17 (remove the six deprecated
`qwen-*` aliases) was a real Phase 10 requirement, added by explicit user instruction mid-phase and
fully executed and evidenced — see §1 above, `phase-10/ALIAS-DESIGN.md` §2, and
`phase-10/CFG-13-EVIDENCE.md` Check 1 (all 16 removed lines individually classified). It is not
given its own row in this ten-row table because `.planning/REQUIREMENTS.md`'s own Phase 10
requirement-tracking table (the one this document's must-have text names verbatim) does not list
CFG-17 among the ten rows it tracks either — that table predates CFG-17's addition and this plan
does not own updating it (the orchestrator owns `REQUIREMENTS.md` at phase close). Its disposition,
stated plainly since omission from a table is not the same as omission from the record: **Met** —
zero `qwen-*` requests since the current `litellm` instance's last restart against 163 `flashnext`
requests, confirmed against server logs before the deletion (`phase-10/ALIAS-DESIGN.md` §2), and
the deletion itself proven surgical (nothing but the named six aliases and their header removed) by
`phase-10/CFG-13-EVIDENCE.md` Check 1.

---

## §3 ROADMAP criterion table

Seven rows, per this plan's own scope: 1, 1b, 2, 3, 4, 5, 6.

| Criterion | Evidence path |
|---|---|
| **1** — the real config file gets `flashnext-plan` injecting both parameters together, `drop_params` unset anywhere, confirmed by diff | `phase-10/CFG-13-EVIDENCE.md` Check 1 (diff against installed file) and Check 4 (`drop_params` absence) |
| **1b** — the combination actually produces `reasoning` at both `:8011` and `:4000` curl | `phase-10/REACH-PROOF.md` §2 |
| **2** — `flashnext-act`'s creation/non-creation decision and basis recorded, per the PRB-02 verdict | `phase-10/ALIAS-DESIGN.md` §5; `phase-10/REACH-PROOF.md` §5 |
| **3** — `flashnext` byte-identical before/after | `phase-10/CFG-13-EVIDENCE.md` Checks 1–3 |
| **4** — differing server-log `prompt_tokens` between `flashnext` and `flashnext-plan`, judged on the log not the HTTP status | `phase-10/REACH-PROOF.md` §3 (full delta table), §3c (log-not-status basis) |
| **5** — re-runnable script persists in the repo, **and** `~/local-llm-settings/sync.sh`'s output reflects the change. Both 2026-09-01 corrections honoured: (a) the real file was edited and the mirror regenerated from it, never the reverse — `phase-10/sync_and_verify.sh` only ever runs `~/local-llm-settings/sync.sh` (real → mirror) and this plan's own hard constraint #2 forbids writing the live config; (b) the new aliases use `hosted_vllm/`, not `openai/` — confirmed in `phase-10/config/config.yaml.candidate` lines 50/58/70 and in `phase-10/CFG-13-EVIDENCE.md`'s installed-file diff | `phase-10/verify_reach.sh`; `phase-10/results/20260902T005212Z-sync/sync-check-after.txt` (`✅ 실제 시스템과 일치한다`, exit 0); mirror commit `a1ffaf6` |
| **6** — it is observed to work under a real `cline` CLI execution, and a negative observation would equally satisfy this criterion | `phase-10/VRF-04-OBSERVATION.md` §5 (quotes the requirement's own footnote: "관측 결과가 부정적이어도 이 요구사항은 충족된다"); the observation happened to be positive, which is incidental to satisfying the criterion, not the basis for satisfying it |

**Criterion 7** (CFG-17, deprecated alias removal, riding this phase's maintenance window) is
likewise out of this seven-row table's stated scope, for the same reason as CFG-17 in §2 — see the
note there; its evidence is `phase-10/ALIAS-DESIGN.md` §2 and `phase-10/CFG-13-EVIDENCE.md` Check 1,
and its disposition is Met.

---

## §4 The disclosures — what is weaker than it looks

This is the section that matters most. Six items, each stated plainly rather than buried in a
qualifying clause inside a green row above.

### 4.1 The deployed arm is not the proven arm

`flashnext-plan` ships the combination Phase 9 calls **`et-medium`**
(`enable_thinking:true` + `reasoning_effort:medium`). Its own `prompt_tokens` delta from
`unspecified` is exactly **−2** (`B` vs `D` in `phase-10/REACH-PROOF.md` §3b) — a margin
`phase-09/PRB-03-ORACLE.md` §4 explicitly rules out as a reach probe on its own: too tight to
survive incidental prompt drift (this project has already observed a constant −10 baseline shift
across sessions while every delta stayed bit-for-bit stable, per the same document's §5 — a −2
signal sits well inside that noise band). **Reach was proven, with a wide margin, on
`flashnext-reach-xhigh`** (`D` vs `F`, +42, exactly matching the oracle), a verification-only alias
that is never shipped. The shipped arm's −2 is reported in `REACH-PROOF.md` §3b as corroboration of
an already-established mechanism, given §3a already holds — not as freestanding evidence in its own
right. **State this directly, not as a footnote:** the requirement and criterion 4 above are marked
`Met` on the strength of the wide-margin arm; deploying `et-medium` at `flashnext-plan` is real, and
it does show the oracle-predicted delta, but it is the weaker of the two proofs this phase produced,
and a reader should not treat §2's `Met` row for VRF-01 as if the shipped alias itself carried a
robust margin. It does not.

### 4.2 Restart B's outage was never measured

`phase-10/MAINTENANCE-LOG.md` records Restart A's outage as genuinely measured (≈7s by a working
0.5s sampler, 18 rows collected, 8s upper bound from `restart_service.sh`'s own T0/T1). **Restart
B's sampler died on its very first connection-refused sample** — the exact event it existed to
record — because it ran in a subshell that inherited `set -e` from
`phase-09/probe_lib.sh`, and `curl`'s exit code 7 (connection refused) under `-e` silently killed
the subshell after one pre-outage sample. This was caught only because `outage-A.tsv` (18 rows) sat
next to `outage-B.tsv` (1 row) in the same session and the discrepancy was too obvious to miss — the
sampler itself raised no alarm. **The only honest bound for Restart B is `restart_service.sh`'s own
8-second T0/T1 window**, offered as context, not as a measurement. A future reader must not let
10-03's own careful "NOT MEASURED" quietly turn into "≈7s, same as Restart A" the next time this
document — or any document downstream of it — is summarized. It did not happen here; it is named
explicitly so it does not happen next.

### 4.3 `cline` drifted to 3.0.60, and Phase 9's source citations were not re-verified there

Phase 9's citations for the NDJSON reasoning shape and the reasoning-history reattachment mechanism
(`ai-sdk.ts:284-289`, `agent-message-codec.ts:231`, `message-builder.ts:1213-1214`) were read from
`cline-src` at tag `cli-v3.0.53`. By the time plan 10-05 ran VRF-04, the installed `cline` binary
had already moved to **3.0.60** — `/Users/ohama/projs/cline-src` was deliberately left at
`cli-v3.0.53`, untouched, rather than re-pinned to re-read source at the new version (out of that
plan's scope, and re-pinning risked disturbing state other phases rely on). **VRF-04's observation
is empirical and stands on its own**: the documented v3.0.53 shape
(`content_start`/`contentType=="reasoning"`) was directly observed, live, at 3.0.60, by two
independent extraction methods that agreed with each other (`VRF-04-OBSERVATION.md` §2–§3). But the
*source-level explanation* of why that shape exists — Phase 9's line citations — has not been
re-verified against the code actually running today. Say this distinction plainly: a live
observation at 3.0.60 is not the same claim as a source reading at 3.0.60, and only the former
exists right now.

### 4.4 `cline -m` rewrote `providers.json`, contradicting the 3.0.53 source reading

During plan 10-05's Run 1 (`cline -m flashnext-plan`), the real 3.0.60 binary rewrote
`~/.cline/data/settings/providers.json`'s `openai-compatible.updatedAt` field
(`2026-08-31T23:37:50.252Z` → `2026-09-01T09:10:32.448Z`), directly contradicting a hard constraint
that had been sourced from `cli-v3.0.53` (`-m` documented there as a per-invocation-only override
with no persistence). `model` (`flashnext`) and `contextWindow` (`29000`) both held, and
`phase-01/config/verify_config.sh` still exits 0. **The orchestrator has corrected the project
constraint accordingly** (`.planning/STATE.md`): future phases judge this invariant on `model` and
`contextWindow`, not on the file's sha256. The baseline hash moved
(`5cf3800da31de885...` → `da53de13abdac56b...`) as a direct, disclosed consequence — this document's
own Task 1 re-baseline (`phase-10/BASELINE.txt` post-sync section) records the new hash rather than
silently carrying the old one forward. **This inherits directly into Phase 11**: its
`cline-plan`/`cline-act` wrappers call `-m` repeatedly, so this same timestamp-only rewrite will
recur on every invocation. A restoration attempt was made and blocked by this environment's own
permission system; the block was respected, not routed around (`phase-10/results/20260901T091011Z-vrf04/PROVIDERS-JSON-FINDING.md`).

### 4.5 10-04 fired 48 requests against a 17-request budget

`phase-10/probe_cfg16.sh` was invoked twice (6 requests instead of the planned 3) and
`phase-10/verify_reach.sh` was invoked three times (42 requests instead of the planned 14) during
plan 10-04's own execution — one of the three `verify_reach.sh` runs was needed to catch and fix a
real report-writer bug (§4.6 below), the other two were partly redundant. Total: **48 requests
fired against the shared, single-slot model, against a stated budget of 17** — recorded in
`10-04-SUMMARY.md` and carried forward here rather than left to be forgotten once the phase closed.
Every extra run reproduced identical `prompt_tokens` values across every arm, so no measurement in
`REACH-PROOF.md` is affected by the overage — but the overage itself, against the "polite tenant"
standard this project holds itself to, is a real cost and is named as one.

### 4.6 The ladder's MUTANT-4 is a measurement of reach, not an enforced guarantee — and the phase's five silent-instrument pattern

`phase-10/validate_config.sh`'s rung 4 (real scratch boot) caught MUTANT-4 (`litellm_params: null`)
only because litellm's own loader raises an **unhandled** `AttributeError` for that specific
schema-invalid shape, not because rung 4 is a general-purpose config validator
(`phase-10/ALIAS-DESIGN.md` §8, `phase-10/selftest_validate_config.sh`). It is recorded throughout
this phase's own documents as a measurement of the ladder's reach on one mutation class, never as
an enforced guarantee against every possible misconfiguration — a clean scratch boot proves startup
validity, not correctness.

This sits inside a larger pattern worth naming once, plainly, as a finding about *method* rather
than six separate footnotes scattered across five plans' summaries:

**This phase produced five instruments that reported clean while observing nothing, or nearly
nothing, of what they existed to observe** — every one of them caught only by reading the actual
output rather than trusting an exit code or a "done" message:

1. `phase-10/selftest_validate_config.sh`'s original MUTANT-1 anchor rotted the moment CFG-17
   removed its target line, and would have silently produced no mutant file at all — caught only by
   re-running the self-test after CFG-17 and reading what it actually produced (10-01 addendum).
2. `phase-10/validate_config.sh`'s rung 4 took **90 seconds** to notice MUTANT-4's scratch process
   had already crashed after ~2 seconds, because it only polled the HTTP endpoint and never checked
   whether the background process was still alive (10-01).
3 & 4. Two of this phase's own plan documents (10-01, 10-02) asserted "pure insertion" / "0 lines
   removed" as their own written verification text, made false the moment CFG-17's deletion was
   folded into the same candidate — caught by cross-checking the plan's own prose against what was
   actually built, not by any automated check (10-01/10-02 addenda).
5. `phase-10/apply_candidate.sh`'s Restart B outage sampler was silently killed by an inherited
   `set -e` on the very `curl` connection-refused sample it existed to record, and produced one row
   where ~16 were expected — caught only because a working sampler's output (Restart A's 18 rows)
   happened to sit in the same session for comparison (10-03; see §4.2 above).
6. `phase-10/verify_reach.sh`'s report-writer helper `p()` silently dropped every line-continuation
   argument from several report sentences — including, in some cases, the actual computed delta
   values — while `bash -n` passed and the script exited 0; caught only by reading the rendered
   `reach-report.txt` text rather than the exit code (10-04).

None of these six were caught by an assertion, a green checkmark, or a passing syntax check. Every
one was caught by a human or an agent actually reading what the instrument printed, on purpose,
against a suspicion that the number looked too clean or too thin. That is the phase's most useful
lesson, and it is recorded here as one finding rather than left scattered across five separate
summaries where a future reader would have to notice the pattern themselves.

---

## §5 Handoff

**For Phase 11 (`cline-plan`/`cline-act` wrapper):**

- **The exact working invocation**, confirmed against the real binary in plan 10-05:
  `cline -P openai-compatible -m <alias> --compaction agentic --json -t <timeout> "<prompt>"`,
  with `CLINE_NO_AUTO_UPDATE=1` set (does not guarantee no self-update — CFG-05 — but is still worth
  setting). No `-p`/`--plan` flag is needed; `-m` alone selects the alias and therefore the injected
  parameters.
- **`providers.json` was never touched by this phase's config-mutation work**, and its pinned
  invariant — `model`/`contextWindow`, checked by `phase-01/config/verify_config.sh` — is intact and
  still exits 0. That script's invariant, not the file's sha256, is what Phase 11's wrapper should
  check if it wants to assert `providers.json` is still sane after repeated `-m` calls (see §4.4 —
  the sha256 will legitimately keep moving).
- **`phase-10/verify_reach.sh`** is the standing regression check for reach (VRF-03) — re-run it
  whenever a future change touches the `hosted_vllm/` path or the injected parameters, with the
  model idle.
- **`phase-10/ROLLBACK.md`** is the standing recovery procedure, with its backup path
  (`phase-10/backups/config.yaml.20260901T053509Z`) and both a rehearsed positive-restore and a
  rehearsed negative-refusal outcome on record.
- **Whether `flashnext-reach-xhigh` should be removed from the config** once VRF-01 no longer needs
  it as a reach probe is an open decision, not yet made — it was offered for removal at the plan
  10-02 checkpoint and the reviewer declined to ask for it then; Phase 11/12 should revisit whether
  it is still needed as the milestone's verification-only wide-margin alias, or whether it has
  become dead configuration once this phase's reach questions are closed.
- **The still-open documentation correction Phase 9 assigned to Phase 12**:
  `docs/plan-act-reasoning-implementation.md:96-100,102` and
  `docs/plan-act-reasoning-diagrams.md:187-191` both state Cline does *not* re-attach reasoning
  history to subsequent turns — source-verified in Phase 9 (`agent-message-codec.ts:231`,
  `cli-v3.0.53`) to be a false statement (it does re-attach; the cost is 0 tokens on this stack,
  which is why the gate still passed). Phase 9 recorded this but explicitly did not edit the docs;
  that edit remains Phase 12's (USE-05's) to make.

**Closing line, as required:** this document reports the phase's results. It does not adjudicate
the milestone — whether Plan/Act reasoning injection is worth what it cost is USE-03's A/B in
Phase 12, deliberately not attempted here.
