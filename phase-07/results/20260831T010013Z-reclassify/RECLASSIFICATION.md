# Reclassification: old verdict versus new verdict, every stored run instance

Plan `07-13` (gap closure, wave 12). Produced by `phase-07/bench/reclassify_runs.sh`, which
re-derives every field below from preserved evidence (server-log slice, `agent/cline.txt`,
`verifier/reward.txt`) using `phase-07/bench/classify_lib.sh` -- the same shared rule
`run_task.sh` now uses for live runs. Zero live bench runs, zero model calls, `meta/*.json` left
byte-identical (`git status --short bench/runs/*/meta/` empty before and after).

## 1. Old-versus-new table (all 5 stored run instances across both run directories)

| run_dir | task | old_verdict | new_verdict | changed? | reason | evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `bench/runs/20260830T122809Z-phase07-fix/` | `discord-trivia-approval-keyerror` | `fail-context` | `fail-context` | no | Authoritative rejection phrase matches directly in the server-log slice (1x) and the transcript (3x) -- a genuine signal, not the bare-`400` false positive the old rule also happened to catch this task with. 6 OOM events also present, recorded but not overriding (see precedence note in classify_lib.sh). | `server-log/discord-trivia-approval-keyerror.flashnext.err.txt:1222`; `meta-reclassified/discord-trivia-approval-keyerror.json` |
| `bench/runs/20260830T122809Z-phase07-fix/` | `filmarchiver` | `fail-infra` | `fail-infra` | no | Zero bytes in the server-log slice, no `agent/cline.txt` (install crashed before the agent ran) -- no maxkv, no oom, zero model turns. Falls through every branch to the zero-evidence default. | `server-log/filmarchiver.flashnext.err.txt` (0 bytes); `meta-reclassified/filmarchiver.json` |
| `bench/runs/20260830T122809Z-phase07-fix/` | `telegram-plugin-refactor` | `fail-context` | `fail-context` | no | Authoritative rejection phrase matches in the server-log slice (1x, the true origin) and the transcript (3x, litellm's relay -- 07-12 found the OLD rule's transcript-side bare-400 match here was contaminated by 3 unrelated repo-source `400` literals; the NEW rule's transcript matches are all genuine MAX_KV_SIZE relays, zero contamination). `max_prompt_tokens_attempted=36155` now visible (was invisible under the old accepted-only field, which recorded 21036). | `server-log/telegram-plugin-refactor.flashnext.err.txt:168`; `meta-reclassified/telegram-plugin-refactor.json` |
| `bench/runs/20260830T122809Z-phase07-fix/` | `v-edit-workspace-tests` | `fail-context` | `fail-context` | no | Authoritative rejection phrase matches in the server-log slice (1x) and transcript (3x), all genuine. 1 OOM event also present (the transient METAL/OOM + retry 07-11 identified), recorded but not overriding. `max_prompt_tokens_attempted=30843` (was 30696 accepted-only). | `server-log/v-edit-workspace-tests.flashnext.err.txt:338`; `meta-reclassified/v-edit-workspace-tests.json` |
| `bench/runs/20260830T093657Z-phase07/` | `discord-trivia-approval-keyerror` | `fail-infra` | `fail-infra` | no | Pre-fix run: 0-byte server-log slice (injection not yet working, container hit the real OpenAI API and failed on an invalid API key before ever reaching flashnext) -- zero maxkv, zero oom, zero model turns. | `server-log/discord-trivia-approval-keyerror.flashnext.err.txt` (0 bytes); `meta-reclassified/discord-trivia-approval-keyerror.json` |

**0 of 5 verdicts changed.** This is the expected, required result: 07-12's audit found the old
classifier unsound in mechanism but coincidentally correct on all 4 audited labels (plus the
pre-fix `fail-infra` instance, which no defect touches -- it never involved the `400`/MAX_KV_SIZE
detector at all). A correct classifier must reproduce every one of these labels; it does.

## 2. Restated corrected counts

The corrected classifier does not change the milestone's headline arithmetic:

- **Unique tasks:** 4 (`discord-trivia-approval-keyerror`, `filmarchiver`,
  `telegram-plugin-refactor`, `v-edit-workspace-tests`) -- unchanged, N=4.
- **Reached-the-model (post-fix run only, `bench/runs/20260830T122809Z-phase07-fix/`):** 3
  (`discord-trivia-approval-keyerror`, `telegram-plugin-refactor`, `v-edit-workspace-tests`) --
  unchanged, M=3.
- **Passed:** 0 -- unchanged, P=0. **A corrected failure label does not turn a failure into a
  pass, and none of the 5 instances above changed verdict at all, so this is not merely
  "unaffected by re-classification" as a hypothetical -- it is unaffected because nothing
  changed.**
- **Corrected failure-class breakdown (post-fix run):** `fail-context` x3 (all three
  reached-the-model tasks), `fail-infra` x1 (`filmarchiver`). **`fail-oom` x0** -- the new verdict
  class exists in `classify_lib.sh` and is proven to fire correctly against a synthetic fixture
  (`negative-controls.txt` control 4), but no stored task in either run directory qualifies for it
  (both tasks with OOM events -- `discord-trivia-approval-keyerror` and `v-edit-workspace-tests`
  -- also have a genuine MAX_KV_SIZE rejection, which takes precedence per `classify_lib.sh`'s
  documented rule).

These figures are **identical** to the N=4 / M=3 / P=0 recorded in `docs/cline-bench.md`,
`ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `.planning/v1-MILESTONE-AUDIT.md`. This plan does
not edit those documents (07-15's job); it confirms there is nothing in them to correct as a
result of this classifier fix. The milestone's headline claim ("3/3 reached-the-model tasks died
at the 32K ceiling") is unaffected by this re-classification, on top of already surviving 07-12's
byte-level audit.

**What DID change, even though no verdict did:** two new fields are now visible per fail-context
task that were previously invisible or silently wrong:

| task | max_prompt_tokens (old, accepted-only, unchanged) | max_prompt_tokens_attempted (new) | undercount |
| --- | ---: | ---: | ---: |
| `telegram-plugin-refactor` | 21036 | 36155 | 15,119 |
| `v-edit-workspace-tests` | 30696 | 30843 | 147 |
| `discord-trivia-approval-keyerror` | 30463 | 31179 | 716 |

The first two rows are 07-11's own named handoff, reconfirmed here via the shared detector rather
than manual forensics. The third (`discord-trivia-approval-keyerror`) was not separately
forensically derived by 07-11 (it was outside that plan's two-task scope) but falls out of this
plan's general-purpose `max_prompt_tokens_attempted` field for free.

## 3. Negative-control proof (see `negative-controls.txt` for full expected/actual detail)

All 4 controls MATCH:

1. Decode telemetry (`generated_tokens=400`) alone -> does NOT trigger `fail-context`.
2. Benchmark repo's own HTTP-status source literals (`case 400:`, `new ApiError(...,400,...)`)
   alone -> does NOT trigger `fail-context`.
3. The real `Request needs ... MAX_KV_SIZE is ...` phrase -> DOES trigger `fail-context`, with
   `max_prompt_tokens_attempted` correctly extracted as 36155.
4. A GPU/host memory-exhaustion event alone -> triggers the new `fail-oom` verdict, not
   `fail-context`.

## 4. Named finding handed to 07-14 (not investigated further in this plan -- out of scope)

The orchestrator flagged a lead worth a cheap check: whether cline's `auto_compaction` mechanism
prunes messages on real bench workloads at all, since if it does not, lowering `contextWindow`
alone cannot fix the two genuine context-ceiling deaths (the trigger would just fire earlier
against a history that still doesn't shrink).

**Cheap check performed:** confirmed the record schema is identical between the phase-01 synthetic
run (`phase-01/results/exp-verify29k/run.ndjson`) and the real bench `.compaction.json`/`cline.txt`
notices 07-11 parsed -- both use the exact same `auto_compaction` notice shape:
`{"kind":"auto_compaction","phase":"completed","iteration":N,"tokensBefore":T0,"tokensAfter":T1,
"messagesBefore":M0,"messagesAfter":M1,"maxInputTokens":...}`. The field names and producer
(cline's own instrumentation) are the same in both records, so a direct comparison of their values
is valid -- this is not comparing two different measurement systems.

**Values compared, all 5 `completed` events in the synthetic run and both `completed` events in
the real bench runs (verified directly against `phase-01/results/exp-verify29k/run.ndjson` and
`phase-07/results/20260831T003728Z-context-forensics/compaction-events.tsv`):**

| source | iteration | tokensBefore | tokensAfter | messagesBefore | messagesAfter | pruned? |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| synthetic (exp-verify29k) | 8 | 28409 | 22165 | 15 | 9 | yes |
| synthetic (exp-verify29k) | 10 | 29136 | 22250 | 13 | 9 | yes |
| synthetic (exp-verify29k) | 12 | 29230 | 22045 | 13 | 9 | yes |
| synthetic (exp-verify29k) | 14 | 29010 | 22037 | 13 | 9 | yes |
| synthetic (exp-verify29k) | 16 | 29017 | 22038 | 13 | 9 | yes |
| real bench, `telegram-plugin-refactor` | 6 | 38626 | 49750 | 16 | 16 | **no** |
| real bench, `v-edit-workspace-tests` | 8 | 28009 | 48554 | 16 | 16 | **no** |

**Verified, not hypothetical, within the limits of two real-run data points:** every synthetic
`completed` event (5/5) both shrank the token count and dropped messages; every real-bench
`completed` event (2/2) grew the token count (a summary was added on top, per 07-11) and dropped
zero messages. This is the same directional result 07-11 already reported as a two-data-point
hypothesis; this check adds confirmation that the two record types are directly comparable
(matching schema/producer) and extends the synthetic side from "one run" to "all 5 of its own
completed events, all consistent."

**What this plan does NOT do, and hands to 07-14 by name:** determine WHY compaction behaves
differently between the synthetic and real-bench conditions (candidate variables not isolated
here: prompt size at trigger time, task/tool-call shape, cline version, or something about the
real MCP/agent harness vs the synthetic harness), or draw a remediation conclusion from it. If
this pattern generalizes, 07-14's constraint that "lowering `contextWindow` cannot fix the
observed failures" would need to be weighed as a real possibility, not dismissed -- but this plan
only had 2 real data points before this check and still only has 2 real data points after it
(the check strengthened confidence via schema verification and the synthetic side's internal
consistency, not new real-world evidence). A third real `fail-context` example (07-15's
conditional live run, if it proceeds) remains the specific gap that would firm this up, exactly as
07-11 already flagged.
