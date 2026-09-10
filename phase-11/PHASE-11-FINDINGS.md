# PHASE-11-FINDINGS.md — Phase 11 requirement and criterion account

Plan 11-07. This document is the phase's account of itself: what changed on the machine, whether
each requirement and each ROADMAP success criterion was met, every open research item's measured
answer, and — the section that matters most — which of those verdicts are weaker than they look.
Phase 12 (USE-04/USE-05) reads this to write the manual and update the design documents; so does
anyone auditing the v1.1 milestone later.

**Outcome neutrality, stated once, up front, as `phase-10/PHASE-10-FINDINGS.md` states it:** this
document reports the phase as it happened. USE-03's disposition is the recorded decision, whichever
direction it went, not whether an improvement was found — and no improvement was found. That is
recorded as the result, not smoothed into a green row.

---

## §1 What changed on this machine

**The wrappers**, `phase-11/cline-plan` and `phase-11/cline-act`, live at the repo root of
`phase-11/`, sourcing the shared parser/construction logic in `phase-11/wrapper_common.sh` and the
single-source alias file `phase-11/wrapper.env`. Neither wrapper is installed onto `$PATH` or
symlinked anywhere outside this repo; invocation is by explicit path.

**`verify_config.sh`'s new wrapper section** (`phase-01/config/verify_config.sh`, added in plan
11-03): statically inspects both wrapper scripts and `wrapper.env` for the mode/alias pairing, the
forbidden-`flashnext-codex` check, and the construction-site's argument handling, then behaviourally
re-runs both wrappers against `phase-11/testing/stub-cline` to inspect the argv they actually
construct. This is a genuinely new exit path: **exit code 3** ("pre-run config guard failed"),
distinct from the pre-existing providers.json exit 1, so a caller can always tell a wrapper fault
from a providers.json fault apart by exit code alone.

**The two Phase 4 call-site guards.** `phase-04/run_headless.sh` — the shipped, one-shot headless
`cline` invocation path predating this phase — calls `verify_config.sh` twice, once as a pre-run
guard (its own step 3) and once as a post-run guard (step 7). Both calls inherited Phase 11's new
wrapper section automatically, with zero edits to `run_headless.sh` itself, because both simply
invoke the same `verify_config.sh` binary this phase extended. Re-confirmed live today
(`phase-11/selftest_verify_wrappers.sh`'s M2 mutant case): a seeded mode/alias mismatch produces
`ABORT: wrapper mode/alias check failed (verify_config.sh exit 3) — this is NOT a providers.json
drift; healing would not help`, verbatim, from `run_headless.sh`'s own step-3 branch — the two call
sites correctly distinguish a wrapper defect from a providers.json drift and do not attempt to heal
the former.

**The alias `cline-plan` now targets: `flashnext-plan`**, unchanged by this phase's closing
decision (`AB-RESULTS.md` §11, plan 11-07). It was already the shipped default going into this
phase (set in plan 11-01, per Phase 10's alias design); this phase's job was to prove the pairing is
enforced (USE-01/USE-02) and to run and ratify the keep-or-revert A/B (USE-03) — it did not itself
choose the alias's original value.

**Stated plainly: no litellm config, no `providers.json` field, and no service was changed by this
phase's own config-authoring work.** `/Users/ohama/agent-stack/litellm/config.yaml` and its mirror
are byte-identical to their Phase 10 end-state (sha256 `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e`,
unchanged); none of `com.ohama.flashnext` (46573), `com.ohama.role-shim` (75548), or
`com.ohama.litellm` (68670) were restarted at any point in this phase. This is a materially
stronger claim about the litellm config than about `providers.json` — see below.

**`providers.json` was repeatedly, deterministically mutated by `cline -m` calls this phase — this
is the phase's central finding, not a side note.** `cline -m <alias>` rewrote
`~/.cline/data/settings/providers.json`'s `model` field on every invocation observed: once in plan
11-04's Open Item 3 probe (1/1), once in the 11-05 pilot's own `04-C-r1` cell (1/1), and 31 times, at
100% frequency, across the plan 11-06 main A/B's 31 arm-C invocations (`AB-RESULTS.md` §1c,
`providers-drift.tsv`). `contextWindow` never moved in any of these — only `model`. As disclosed in
`AB-RESULTS.md` §1c, plan 11-06 measured this on a mitigation (detect-and-repair inside `run_ab.sh`,
by orchestrator instruction, never a fix to the wrapper). Between plan 11-06 and this plan, the
mechanism was root-caused against the actual installed source (not inferred) and **contained**, not
merely detected: `phase-11/wrapper_common.sh` (commit `017c65e`, today) now copies the real
`providers.json` to a per-invocation `mktemp`, points `CLINE_PROVIDER_SETTINGS_PATH` at the copy,
and traps `EXIT`/`INT`/`TERM` to remove it, so the mutation lands on the scratch copy and the shared
file is never touched by a wrapper-mediated call. `qanda/004-does-cline-always-write-providers-json.md`
carries the full source citation and the isolation measurement (sha `588bd7cc5e15977a...` unchanged
before/after a contained call). The live file currently holds `model=flashnext`,
`contextWindow=29000` — confirmed today, unmutated by any work in this plan (`verify_config.sh`,
`wrapper_argv_test.sh`, and `verify_wrappers.sh` were all re-run today using only the stub binary;
none of them invoke the real `cline` binary or touch the real `providers.json`).

`updatedAt` moving on every `cline -m` call, independent of `model`, was already expected and
disclosed by `phase-10/PHASE-10-FINDINGS.md` §4.4 — that disclosure is not repeated as new here.
What this phase adds is that `model` itself moves too, at 100% measured frequency, contradicting
Phase 10's own single clean observation (VRF-04) — see §5 below for the unresolved contradiction and
its likely resolution.

---

## §2 Requirement table

| Requirement | Disposition | Evidence path |
|---|---|---|
| **USE-01** — `cline-plan`/`cline-act` enforce the mode-alias pairing | Met | `phase-11/wrapper_argv_test.sh` (`test -e`), captured argv rows P1/P2 in `phase-11/results/20260910T073502Z-argv/argv.tsv` (`test -e`) showing `cline-plan` always emits `-p -m flashnext-plan` and `cline-act` always emits `-m flashnext-act` with no `-p`; `phase-11/wrapper_common.sh`'s single construction site (`test -e`) |
| **USE-02** — `verify_config.sh` catches mode/alias mismatch and `--thinking high` | Met | `phase-11/selftest_verify_wrappers.sh` (`test -e`), 9-mutant ladder re-run today: M1–M7 (including M4/M5, the `--thinking`/`-m` leak mutants) all `CAUGHT`, M8/M9 (the legitimate-revert and clean controls) both correctly `PASS`, `phase-11/results/20260902T043511Z-wrapcheck/wrapper-selftest.tsv` (`test -e`) |
| **USE-03** — `medium` vs default A/B recorded; no-improvement → default handling recorded and applied | Met — **override, see §4 disclosures below**, direction is `keep`, not the rule's own `revert` output | `phase-11/AB-RESULTS.md` (`test -e`) §1–§10 (the measured run) and §11 (the ratified `DECISION:` line, the human's verbatim reply, and the override reason) |

---

## §3 ROADMAP Phase 11 criterion table

| Criterion | Evidence path |
|---|---|
| **1** — `cline-plan` always includes `-p -m flashnext-plan`; `cline-act` always includes its act-target alias, confirmed by code | `phase-11/results/20260910T073502Z-argv/argv.tsv` (`test -e`), P1/P2 rows; `phase-11/cline-plan`, `phase-11/cline-act` (`test -e`) |
| **2** — a negative test injecting mode/alias mismatch, and a negative test injecting `--thinking high`, both detected as failures by `verify_config.sh` | `phase-11/results/20260902T043511Z-wrapcheck/wrapper-selftest.tsv` (`test -e`) — M1/M2/M3 (pairing mismatches) and M4/M5 (`--thinking`/`-m` leaks) all `CAUGHT`; `phase-11/selftest_verify_wrappers.sh` (`test -e`) |
| **3** — `flashnext` vs `flashnext-plan` run on the same task set, results tabulated, keep/revert judgement recorded in the document regardless of outcome | `phase-11/AB-RESULTS.md` (`test -e`) §3 (raw per-cell table), §4 (aggregate), §8 (rule applied), §11 (decision) — satisfied by the recorded judgement itself, per the requirement's own "개선 유무와 무관하게" wording, not by which direction the judgement went |

---

## §4 Open research items — measured answers

Four items from `11-RESEARCH.md`, settled (three) or explicitly deferred-and-then-settled (one) by
`phase-11/OPEN-ITEMS.md` (plan 11-04) and `AB-PROTOCOL.md`/`AB-RESULTS.md` (plans 11-05/11-06).

| # | Question | Measured answer | Run path |
|---|---|---|---|
| 1 | Does client-sent `reasoning_effort:"high"` (via `--thinking high`) actually 400 through `openai/`-prefixed aliases and 500 through `hosted_vllm/`-prefixed ones, end-to-end? | **Yes, but not uniformly 400.** `flashnext` (`openai/`): litellm's own `UnsupportedParamsError`, **HTTP 400**. `flashnext-plan` (`hosted_vllm/`): passes litellm, model server rejects the value, **HTTP 500**. A real `cline --thinking high` call against the raw binary (bypassing the wrapper) surfaces the identical model-side 500 message as Cline's own error event, **exit 1**. None of the three consumed a generation-queue slot (value validation precedes queueing). | `phase-11/results/20260902T045814Z-openitems/oi1.tsv`, `oi1-plan-high.json`, `oi1-flat-high.json`, `oi1c-cline-thinking-high-retry.ndjson` |
| 2 | Is `max_tokens=2048` still the fixed per-turn completion budget at the now-installed cline version? | **No — it moved dramatically, from a fixed 2048 (3.0.53) to 20983 (3.0.60/3.0.61) for a like-for-like prompt**, then further shown by plan 11-05/11-06 to be dynamic, sized per-request to land near `contextWindow × 0.9` (26,100), not a second fixed constant. This falsified `11-RESEARCH.md`'s working assumption and forced plan 11-05 to re-derive the A/B's completion-budget fairness control. | `phase-11/results/20260902T045814Z-openitems/oi2-maxtokens.txt`, `oi2.tsv`; `AB-PROTOCOL.md` §3's 278-sample dynamic-budget table |
| 3 | Can repeated `cline -m` calls (N≥5, volume) move `model`/`contextWindow`, not just `updatedAt`, contradicting Phase 10's single-call clean observation? | **A single call already moved `model`** (not N≥5 — the probe's own pre-registered stop condition triggered on call 1 of a planned 6), at both a version (3.0.61, vs VRF-04's 3.0.60) and a `-p`-presence difference from VRF-04's invocation — the two candidates were not disambiguated within plan 11-04's budget. Plan 11-06 later raised the observed count to 31/31 at 100% frequency, and this plan's own commit `017c65e` root-caused it definitively against source (unconditional, present since ≥3.0.53, independent of `-p`) and contained it. `contextWindow` never moved in any of these observations. | `phase-11/results/20260902T050726Z-volume/volume.tsv` (`test -e`); `AB-RESULTS.md` §1c; `qanda/004-does-cline-always-write-providers-json.md` |
| 4 | A/B repetition count and task-set sizing | Deferred to plan 11-05 by design (`11-RESEARCH.md`'s own scope split), then resolved there: N=5 for arms A/C, N=1 for arm B, 8 tasks, 88 authorised invocations, human-approved at the Task 3 checkpoint. The run itself (plan 11-06) only reached 66/88 before the request cap stopped it — see §5 below. | `AB-PROTOCOL.md` §4 (sizing/approval); `AB-RESULTS.md` §1a (why it stopped short) |

---

## §5 Disclosures — what is weaker than it looks

This is the section that matters most, in the spirit of `phase-10/PHASE-10-FINDINGS.md` §4.

### 5.1 The A/B did not use cline-bench

`AB-TASKSET.md` §1's own justification: Phase 07's real attempt at cline-bench measured 4 attempts,
**0 passes**, 3 of them `fail-context` at 21K–37K tokens (including both of the suite's `easy`
tasks) — a benchmark that overflows this stack's context ceiling on an unrelated compaction-pruning
defect before reasoning is ever exercised is not measuring what USE-03 needs measured. The reversal
condition, stated in that document: if the compaction-pruning defect is ever fixed, cline-bench
becomes available again and should be reconsidered as the instrument. **This substitution means
USE-03's evidence is not comparable to any external benchmark result** — the 8-task, single-turn,
machine-graded instrument this phase built answers "does `medium` reasoning change answer quality on
bounded, single-domain tasks," not "does it help on realistic agentic workloads," and a reader must
not treat this run's numbers as if they were cline-bench numbers.

### 5.2 Statistical power — and what "no improvement" does and does not claim

The authorised size was 8 tasks × N=5 for arms A/C (40 cells each), with a pre-registered threshold
of ≥7-of-40 to keep, itself derived from `ceil(cells/6)` on the stated basis that per-cell N=3
against temperature-1.0 sampling "cannot reliably distinguish a smaller gap from noise"
(`AB-PROTOCOL.md` §5). The run actually achieved 35 (arm A) and 31 (arm C) cells, uneven, after the
request cap stopped it at 66/88 — worse resolution than even the authorised design was built to
tolerate. **"No measurable improvement at this resolution" is not the same claim as "no improvement
exists."** A true effect smaller than roughly one-sixth of the smaller arm's cell count would not
have been reliably detected by this design even had it run to completion. Task 08 (both
bug-localisation tasks) and arm B (the prefix control) were never attempted at all; 4 of arm C's 5
task-07 reps were never attempted. The permutation test (p=0.563) is descriptive, not the decision
criterion, and is reported as such.

### 5.3 The shared completion budget, and truncation

`finish_reason=stop` on all 66 collected cells (`AB-RESULTS.md` §4) — the completion-budget
starvation risk `AB-PROTOCOL.md` §3 flagged (Phase 9's fixed-300-token finding) did not materialise
at the measured dynamic budget (~20,800–20,873 tokens this run). No truncation was observed in
either arm. Arm C's completions ran ~68% longer on average (252.4 vs 150.6 mean completion tokens);
per `AB-PROTOCOL.md` §3's own pre-registered instruction, the ~3s/18% median latency gap is not read
as "thinking cost" given this length difference — a meaningful fraction of the extra wall clock is
plausibly just more tokens to stream.

### 5.4 The deployed arm is still not the arm that carried Phase 10's wide-margin reach proof

Inherited, not resolved here, exactly as `phase-10/PHASE-10-FINDINGS.md` §4.1 disclosed: `flashnext-plan`
ships `et-medium` (`enable_thinking:true` + `reasoning_effort:medium`), whose own `prompt_tokens`
delta from `unspecified` is −2 — a margin Phase 9's own oracle document rules out as a reach probe on
its own. Reach was proven with a wide margin on `flashnext-reach-xhigh`, never shipped. This phase's
A/B measures answer quality on the shipped, narrow-margin arm; it does not re-litigate or strengthen
the reach proof itself.

### 5.5 `cline` 3.0.61, CFG-05, and the flag surface

The flag surface (`-p`/`--plan`, `--thinking <level>`, the four whitelisted wrapper options) was
re-verified live against the installed 3.0.61 binary this phase, via the deny-by-default parser
(`phase-11/WRAPPER-DESIGN.md` §3) rather than a blocklist. CFG-05 (auto-update not actually blocked)
remains unresolved: the binary drifted **3.0.53 → 3.0.60 → 3.0.61** across Phases 10 and 11, and, as
recorded in `OPEN-ITEMS.md`'s unplanned finding, the npm package was found **entirely removed from
disk mid-plan** (11-04) — a more severe manifestation than prior "silently changes version/flags"
findings; a running process still held an open handle to the unlinked binary, consistent with an
interrupted self-update. Deny-by-default is this project's structural defence against a *future*
flag appearing unannounced, not a guarantee that the binary will still be present or invocable at
all. It is a defence, not a guarantee.

### 5.6 Budget accounting

| Plan | Stated cap | Actual measured requests (server-log `Generation queued`) |
|---|---:|---:|
| 11-04 | 14 | 3 |
| 11-05 | 10 | 6 |
| 11-06 | 88 | 88 (cap reached — 66/88 authorised invocations completed) |
| **Total** | **112** | **97** |

No plan exceeded its stated cap this phase — the opposite pattern from Phase 10's own §4.5 (48
against 17). Plan 11-06 is the interesting case: it hit its cap exactly, and the cap being reached
mid-sweep is the direct cause of §5.2's reduced resolution — the cap was not raised to finish the
sweep, per this phase's own hard constraints. Reported here in full even though every plan came in
at or under budget, because Phase 10's overage was only noticed after the fact, and the habit of
checking is the point, not just the number this time.

### 5.7 Instruments checked for silently observing less than claimed

Following `phase-10/PHASE-10-FINDINGS.md` §4.6's standing lesson, this phase's own instruments were
checked, specifically: `run_ab.sh`'s cap-abort path was found, live, during plan 11-06's own
execution, to **skip its own `postflight11` call** on the cap-triggered abort branch — unlike every
other abort path in the same script — a real, if narrow, defect (`AB-RESULTS.md` §1a), worked around
in that run by invoking `postflight11` manually against the same run directory within seconds, and
recorded rather than silently patched over the underlying script defect. `phase-11/OPEN-ITEMS.md`'s
own Part A0 explicitly distinguished the wrapper's internally-suppressed guard call
(`VERIFY_CONFIG_NO_WRAPPER_CHECK=1`, always discarded on a passing run) from the probe's own separate
unsuppressed call, rather than assuming the former had been observed when it structurally could not
be. No further under-observing instrument was found in this phase beyond the two named here (the
`run_ab.sh` postflight-skip and, inherited, the `assert_budget`/cap-abort interaction) — the search
consisted of reading every abort/exit branch of `run_ab.sh`, `probe_lib11.sh`, and
`wrapper_common.sh` line by line rather than trusting their exit codes, and re-running
`selftest_verify_wrappers.sh`'s full mutant ladder today rather than trusting the commit message that
described it.

### 5.8 Phase 9's scoping error, and the unexplained Phase 10 contradiction

**Phase 9's scoping error.** Phase 9 read `session-runtime.ts:109-113` (the connectors' — Slack,
Telegram, Kanban — read path for the model field) and correctly found no write there, then
generalized that finding to "cline does not persist `-m`" — without ever checking `apps/cli/src/main.ts`,
the CLI's own startup path, which unconditionally calls `saveProviderSettings({ model:
config.modelId, ... })` and has done so since at least `cli-v3.0.53` (`qanda/004`, `git diff
cli-v3.0.53 cli-v3.0.61 -- apps/cli/src/main.ts` shows only one unrelated line changed). This was a
bug in investigation scope — "no write in this module" was generalized to "no write anywhere" — not
a bug in the code itself, and not caused by version drift.

**Cline's mid-plan self-removal (11-04).** During `probe_open_items.sh`'s first live call, the
installed `cline` binary was found entirely missing from disk (`npm ls -g` showed no package; a
still-running unrelated daemon held an open handle to the unlinked inode), consistent with an
interrupted self-update. Restored via a pinned `npm install -g cline@3.0.60`, which then itself
drifted silently to 3.0.61 during the same plan's retried calls (`OPEN-ITEMS.md`, "Unplanned
finding"). Every measurement made afterward in this phase, including the A/B, ran at 3.0.61.

**The unexplained contradiction, stated as unresolved rather than papered over.** `phase-10/VRF-04-OBSERVATION.md`
observed exactly one `cline -m flashnext-plan` call, at cline 3.0.60, leaving `model` unchanged
(only `updatedAt` moved). Phase 11 observed the same call pattern move `model` on 31/31 (100%)
occasions at cline 3.0.61, against **byte-identical source** for the relevant code path across
3.0.53/3.0.60/3.0.61 (only 3.0.60 was not independently diffed against 3.0.53/3.0.61 in this phase,
but the mechanism — `saveProviderSettings` unconditionally in `main.ts`'s startup path — is not
version-gated in the source that was read). No mechanism is proposed here for why VRF-04's single
observation came back clean; the honest conclusion, given identical-looking source and a 31-sample
observation on one side against a single observation on the other, is that **Phase 10's single
observation is the more likely outlier**, not that the underlying mechanism changed between 3.0.60
and 3.0.61. This is recorded as an open contradiction, not invented an explanation for.

---

## §6 Handoff to Phase 12 (USE-04/USE-05)

**For the manual (`docs/manual/01-cli.md`, USE-04):** the wrappers' invocation path is by explicit
path (`phase-11/cline-plan`, `phase-11/cline-act`; neither is installed on `$PATH`); the four
accepted options are `-t`/`--timeout`, `-c`/`--cwd`, `--json`, and `--`; every other flag beginning
with `-` is refused, by name, on stderr, with exit 2, before the real binary is ever invoked
(deny-by-default, `phase-11/WRAPPER-DESIGN.md` §3). Exit-code table: `0..N` = cline's own exit code
forwarded unchanged; `2` = refused argument (binary never invoked); `3` = pre-run config guard
failed, or the providers.json scratch-copy containment could not be established (binary never
invoked); `4` = post-run config guard failed (cline may have exited 0; this wrapper still surfaces
4). Refusal messages name the exact flag and explain why (`-m`/`-P`/`--thinking`/`-p` each get a
specific, named refusal reason in `phase-11/wrapper_common.sh`).

**For `docs/cline-config-pins.md` (USE-04):** the alias set is `flashnext` (control, no injection),
`flashnext-plan` (shipped Plan default, `enable_thinking:true`+`reasoning_effort:medium`),
`flashnext-act` (shipped Act default, `enable_thinking:false`), `flashnext-codex` (forbidden to
call — kills the model server), `flashnext-reach-xhigh` (verification-only, disposition still open,
carried forward again from `phase-10/PHASE-10-FINDINGS.md` §5 — see below). **Correction needed:**
REQUIREMENTS.md USE-04 and ROADMAP Phase 12 criterion 2 both currently assert flatly that
`--thinking` "이 litellm 에서 400 이 된다" ("becomes a 400 at litellm"). §4 item 1 above measured
this is only true for `openai/`-prefixed aliases (`flashnext`: litellm's own `UnsupportedParamsError`,
HTTP 400). For `hosted_vllm/`-prefixed aliases (`flashnext-plan`, `flashnext-act`,
`flashnext-reach-xhigh`) the value passes litellm and the **model server** 500s instead
(`oi1-plan-high.json`), and a real `cline --thinking high` call against the raw binary (bypassing
any wrapper) surfaces that 500 as Cline's own error event and **exits 1** — never a 400 a user would
see. `docs/cline-config-pins.md` should state the status code per alias prefix, not a single "400"
figure that is only accurate for one of the five live aliases.

**For `docs/plan-act-reasoning-{design,implementation}.md` (USE-05):** the status badge should move
from "제안/계획" to this milestone's measured outcome — implemented (USE-01/USE-02 met, both by
mutant-proven negative tests) and the A/B outcome is **keep, by human override, not by measured
improvement** (`AB-RESULTS.md` §11 — do not summarize this as "the A/B found thinking helps"; it did
not). The shell-function-to-script deviation is recorded in `phase-11/WRAPPER-DESIGN.md` §2: the
design docs' own sketch (`cline-plan() { cline -p -m flashnext-plan "$@"; }`) forwards `"$@"`
verbatim, which lets a caller's `--thinking high` or second `-m` override the alias's injected
parameters (litellm merges client kwargs after `litellm_params`) — exactly the leak the shipped
wrapper exists to refuse; a shell function also cannot be statically inspected by `verify_config.sh`
or invoked by path from another process, both of which USE-02 and this phase's own test harnesses
require. The still-outstanding reasoning-history correction Phase 9 assigned to Phase 12 remains
open and unaddressed by this phase: `docs/plan-act-reasoning-implementation.md:96-100,102` and
`docs/plan-act-reasoning-diagrams.md:187-191` still state Cline does not re-attach reasoning history
to subsequent turns, which Phase 9 source-verified to be false (it does re-attach; the token cost on
this stack is 0, which is why the gate passed anyway) — Phase 9 explicitly deferred the doc edit to
Phase 12/USE-05, and this phase did not touch it either.

**The still-open `flashnext-reach-xhigh` disposition**, inherited from `phase-10/PHASE-10-FINDINGS.md`
§5 and re-confirmed still present and still undecided by `AB-RESULTS.md` §10: it remains configured
(`~/local-llm-settings/config/litellm-config.yaml`, `model_name: flashnext-reach-xhigh`), no arm of
this phase's A/B used it, and whether it is still needed as a verification-only alias or has become
dead configuration is, again, handed to Phase 12 rather than decided here for a second time.

**Closing line, as `phase-10/PHASE-10-FINDINGS.md` did:** this document reports the phase's results.
It does not adjudicate the milestone.
