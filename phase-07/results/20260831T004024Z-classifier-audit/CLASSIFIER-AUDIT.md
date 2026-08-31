# Classifier audit: is `fail-context` trustworthy?

Plan 07-12. Evidence-only; no code changed here (that is 07-13's job — see the constraint in
`07-12-PLAN.md`). All claims below are re-derived directly from stored bytes; see
`failure-composition.tsv` and `match-provenance.md` in this same directory for the raw greps and
line numbers this document summarizes.

## 1. Label-versus-evidence table

| task | recorded_verdict | what the evidence supports | correct? | why |
| --- | --- | --- | --- | --- |
| `discord-trivia-approval-keyerror` | `fail-context` (`meta/discord-trivia-approval-keyerror.json`) | A genuine `MAX_KV_SIZE` rejection did occur: `bench/runs/20260830T122809Z-phase07-fix/server-log/discord-trivia-approval-keyerror.flashnext.err.txt:1222` ("Request needs 33227 context tokens (31179 prompt + 2048 max generation), but MAX_KV_SIZE is 32768"), and it is the run's terminal event. It is relayed into `agent/cline.txt:777-779` as `Error code: 400 - {'detail': 'Request needs 33227 conte[xt tokens...]'}`, a true-signal match. But the run's dominant failure class by raw count is METAL/GPU out-of-memory (6 distinct OOM events vs. 1 context rejection — see §2 of `failure-composition.tsv`), and all 3 of the server-log's own `\b400\b` matches (L128, L308, L1218 — timestamp-millisecond coincidences and `generated_tokens=400` decode telemetry) are false positives unrelated to the rejection. | **correct** | The label matches reality (a context rejection genuinely happened and genuinely ended the task), and the match that drove it (`cline.txt:777-779`) is a true signal, not a false positive. It is not "coincidentally-correct" — real evidence supports it — but the *mechanism* that produced it is not trustworthy in general (see §3): the server-log check contributed nothing but noise here, and `grep -q`'s pass/fail semantics mean this task's outcome would be identical with or without the true-signal bytes, given the false positives alone already set the flag. |
| `telegram-plugin-refactor` | `fail-context` | A genuine `MAX_KV_SIZE` rejection occurred: `.../server-log/telegram-plugin-refactor.flashnext.err.txt:168` ("Request needs 38203 context tokens (36155 prompt + 2048 max generation)..."), relayed into `agent/cline.txt:187-189` as a true-signal `Error code: 400` match. The server-log target itself has zero `\b400\b` matches (clean). However `agent/cline.txt` **also** contains 3 unrelated false-positive matches from the benchmark task's own repository source, echoed via file-read tool calls: `message.includes('400')` (L73), `new ApiError(..., 400, ...)` (L170), `case 400:` (L170) — exactly the false-positive vector predicted by this plan's `<why_this_matters>`. | **correct** | Real evidence supports the label (genuine rejection, confirmed numbers match between server log and transcript). But this is the clearest demonstrated case in the dataset of the classifier being exposed to real false-positive bytes (repo source) that would have set `HTTP_400_SEEN=1` on their own, with zero relationship to this run's actual outcome. |
| `filmarchiver` | `fail-infra` | Server-log slice is 0 bytes (flashnext logged no request in this task's wall-clock window). `agent/cline.txt` does not exist for this trial — the agent install step itself failed/timed out (`.../jobs/filmarchiver/.../exception.txt`: `asyncio.wait_for` timeout inside `harbor/agents/installed/cline/cline.py: install`), before any model request was possible. `model_turns=0`. | **correct** | Unambiguous — no evidence of any kind (transcript or server log) exists for this task to dispute; the classifier's `fail-infra` fallback (line 523 of `run_task.sh`, reached when `HTTP_400_SEEN=0`, `MAX_PROMPT_TOKENS<32768`, and `MODEL_TURN_COUNT=0`) is exactly the right branch here. |
| `v-edit-workspace-tests` | `fail-context` | A genuine `MAX_KV_SIZE` rejection occurred: `.../server-log/v-edit-workspace-tests.flashnext.err.txt:338` ("Request needs 32891 context tokens (30843 prompt + 2048 max generation)..."), the run's terminal event, relayed into `agent/cline.txt:212-214` as 4 true-signal `Error code: 400` matches. The server-log target has zero matches (clean, correctly). `agent/cline.txt` has **no false-positive matches** in this task specifically — all 4 hits are true signal. | **correct** | This is the one task among the four whose `1` is produced entirely by true signal with no false-positive contamination found in either target file — the cleanest case in the dataset. |

No task in this dataset is `incorrect` or `coincidentally-correct` as currently labeled. That is a
real finding, not a foregone one: it means the classifier's mechanism is unsound (§3), but in this
specific 4-task run it did not happen to flip any verdict, because every `fail-context` task also
carried an independent true signal in `agent/cline.txt` alongside the noise.

## 2. Resolution of the `discord-trivia-approval-keyerror` fail-infra / fail-context conflict

**Not a contradiction — two different run directories, two different mechanism states, both
statements correct for their own run.**

- `phase-07/results/20260830T093515Z-smoke/ANALYSIS.md` describes
  `bench/runs/20260830T093657Z-phase07/` (started 2026-08-30T09:36:57Z) — the **pre-fix** run,
  captured before 07-07's schema fix to `CLINE_PROVIDER_SETTINGS_PATH` injection. Its own meta
  record, quoted in full:
  ```json
  {
    "task": "discord-trivia-approval-keyerror",
    "wall_clock_sec": 232,
    "reward": 0,
    "model_turns": 0,
    "max_prompt_tokens": 0,
    "http_400_seen": false,
    "verdict": "fail-infra"
  }
  ```
  (`bench/runs/20260830T093657Z-phase07/meta/discord-trivia-approval-keyerror.json`). The
  server-log slice for this run is 0 bytes — flashnext never received a request. The container's
  `cline` instead hit the real OpenAI API and failed on `Incorrect API key provided: local...`,
  quoted verbatim in `bench/runs/20260830T093657Z-phase07/jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/agent/cline.txt`
  by `ANALYSIS.md` itself. `fail-infra` is correct for this run: the request never reached this
  stack's model server at all.

- The milestone audit's table (`.planning/v1-MILESTONE-AUDIT.md` lines 72-74:
  `| discord-trivia-approval-keyerror | 38 | fail-context |`) describes
  `bench/runs/20260830T122809Z-phase07-fix/` (started 2026-08-30T12:28:09Z) — the **post-fix**
  run, captured after 07-07 fixed the missing `version`/`updatedAt` fields in
  `cline-cw-providers.json` that had been causing `ProviderSettingsManager.read()` to silently fall
  back to an empty registry. Its own meta record, quoted in full:
  ```json
  {
    "task": "discord-trivia-approval-keyerror",
    "wall_clock_sec": 1665,
    "reward": 0,
    "model_turns": 38,
    "max_prompt_tokens": 30463,
    "http_400_seen": true,
    "verdict": "fail-context"
  }
  ```
  (`bench/runs/20260830T122809Z-phase07-fix/meta/discord-trivia-approval-keyerror.json`). Here the
  injection worked, the container's `cline` did reach flashnext, ran 38 turns, and was terminated
  by the genuine `MAX_KV_SIZE` rejection documented in §1 above. `fail-context` is correct for this
  run.

Both statements are true of the same task name run at two different points in the project's
timeline, under two different states of the injection mechanism. This is a legitimate
"two-runs-same-name" artifact, not an error in either source document.

## 3. Classifier correctness verdict

**The classifier is unsound.** It reached the right label in all 4 cases audited here, but by a
mechanism that is not trustworthy in general. Concrete, numbered defects, each with the evidence
that proves it (all detail in `match-provenance.md`):

1. **The server-log half of `HTTP_400_SEEN` (`run_task.sh:477-479`, `grep -qE '\b400\b'` against
   `$RUN/server-log/$TASK.flashnext.err.txt`) is both unsound directions at once:**
   - *False-positive*: it fires on decode telemetry (`generated_tokens=400`,
     `discord-trivia...:L1218`) and on log-timestamp millisecond coincidences
     (`21:31:21,400`/`21:35:16,400`, `discord-trivia...:L128,L308`) — bytes with zero relationship
     to context rejection.
   - *False-negative*: the authoritative `MAX_KV_SIZE` rejection line itself never contains a bare
     `400` in any of the 3 tasks that hit it (confirmed in `match-provenance.md` §3) — mlx_vlm's
     server logs its own error string, not an HTTP status line, so this grep target is
     structurally incapable of detecting the one event it is meant to detect. Every real detection
     in this dataset came exclusively from the second target, `agent/cline.txt`.
2. **The `agent/cline.txt` half of `HTTP_400_SEEN` (`run_task.sh:480-482`) fires on the benchmark
   task's own repository source code**, echoed into the transcript by ordinary file-read tool
   calls — demonstrated concretely in `telegram-plugin-refactor` (`message.includes('400')`,
   `new ApiError(..., 400, ...)`, `case 400:`) and more subtly in `discord-trivia-approval-keyerror`
   (a `start_line`/`end_line` file-range tool argument that happens to end in 400). A task whose
   agent merely reads a source file containing an HTTP-400 branch, with no context rejection ever
   occurring, would be misclassified `fail-context` by this mechanism alone.
3. **`grep -q` returns only pass/fail, never which byte matched**, so defects 1 and 2 are
   invisible in normal operation — `meta/*.json`'s `http_400_seen: true` looks identical whether it
   came from the real rejection relay or from decode telemetry, a timestamp, or task source code.
   There is no way to distinguish a trustworthy `fail-context` from an untrustworthy one by reading
   `meta/*.json` alone; this audit only could because it re-ran the greps with context against the
   raw files.
4. **`MAX_PROMPT_TOKENS` (`run_task.sh:473-474`) cannot itself ever confirm a context rejection**,
   because it is extracted only from `prompt_tokens=NNNN`, a token that appears solely on
   *successful* `Request completed:`/`Generation queued:`/`Prefill ...:` lines — never on the
   `Request failed:` rejection line, which spells the same number out in prose instead
   ("N context tokens (P prompt + G max generation)"). Recorded `max_prompt_tokens` values
   (30463 / 21036 / 30696) are all below 32768 even where the real request that got rejected was
   larger (31179 / 36155 / 30843) — this half of the OR condition is dead weight for detecting the
   very failure mode it's named for; every `fail-context` verdict in this dataset was carried
   entirely by `HTTP_400_SEEN`, not by this field.
5. **Neither `make_summary.sh` nor `verify_bench.sh`'s B2 check can catch any of the above.**
   `make_summary.sh` only transcribes the `verdict` field from `meta/*.json` (line 150,
   `verdict = d.get('verdict', 'unknown')`; confirmed by its own comment at lines 67-69 and by
   grep — no `\b400\b`/`MAX_KV_SIZE` pattern appears anywhere in the file). `verify_bench.sh`'s B2
   (lines 144-170) only checks that `verdict` is a member of
   `pass|fail-task|fail-context|fail-infra` — a vocabulary check, not a correctness check; an
   incorrectly-labeled `fail-context` passes B2 exactly as readily as a correct one. A fix at
   07-13 must land in `run_task.sh` itself; neither downstream script provides a second line of
   defense.

None of these defects flipped a verdict in the 4-task dataset audited here (§1) — every
`fail-context` label also had an independent true-signal match in `agent/cline.txt`. But defect 2
is demonstrated as *live, present, real bytes* in `telegram-plugin-refactor`'s own repository
source, not a hypothetical — a task with more such source-level `400` literals and a genuinely
short, non-context failure could be misclassified today without anyone noticing, because nothing
downstream would catch it (defect 5).

## 4. Impact on the milestone claim

The milestone audit's headline — "3/3 reached-the-model tasks died at the 32K ceiling"
(`.planning/v1-MILESTONE-AUDIT.md` lines 66, 72-74) — **survives intact for these three specific
tasks**. Each of the three `fail-context` verdicts (`discord-trivia-approval-keyerror`,
`telegram-plugin-refactor`, `v-edit-workspace-tests`) is backed by a genuine, independently
confirmed `MAX_KV_SIZE` rejection whose numbers match between the raw flashnext server log and the
relayed `agent/cline.txt` transcript, and in each case that rejection was the run's terminal event
— the task did not merely encounter a context rejection somewhere in its history and recover; it
died there. The claim should **not** be softened.

It should, however, be qualified one level down from the headline: the *instrument* that produced
these three labels is not reliable in general (§3), even though it happened to be right here. The
milestone claim should be restated as: "3/3 reached-the-model tasks died at the 32K ceiling,
confirmed by direct inspection of the raw server-log rejection lines and their true-signal
relay into each transcript — not merely by trusting the `fail-context` field, which this audit
found can also be set by unrelated bytes (decode telemetry, log timestamps, and the benchmark
tasks' own repository source code)." The claim is not exaggerated by the existing wording, but any
*future* `fail-context` label produced by this same unfixed classifier should not be trusted
without the kind of byte-level check performed in this plan, until 07-13 lands a fix.

`discord-trivia-approval-keyerror` additionally warrants a footnote: by raw event count its
server-log slice is dominated by METAL/GPU out-of-memory (6 events) rather than context rejection
(1 event) — see `failure-composition.tsv`. The task nonetheless died specifically of the context
ceiling, because it successfully recovered from every OOM event (a new request was queued and
completed after each one, with growing prompt sizes) and only stopped for good at its single,
terminal `MAX_KV_SIZE` rejection. "Died at the 32K ceiling" is the right description of the ending;
"dominated by OOM" is the right description of the noise along the way. Both are true and do not
conflict.

## 5. Limits

- **The colima/wired-memory hypothesis for `discord-trivia-approval-keyerror`'s OOM events is
  indeterminate from stored evidence.** No `vm_stat`, `colima status`, or system memory-pressure
  capture exists anywhere under `bench/runs/20260830T122809Z-phase07-fix/` for this run (checked:
  no file matching `*mem*`/`*colima*` under the run directory, the only textual hit for
  "colima" anywhere under the run directory is an unrelated line in `summary.md` noting that a
  different, excluded task — `terraform-azurerm-deployment-stacks` — was skipped because its
  declared `memory_mb` exceeds colima's VM; it says nothing about memory pressure during
  `discord-trivia-approval-keyerror`'s own run). What *is* known: the 6 OOM events occurred at a range of prompt sizes (15965,
  22722, 25868, 28162, 29262, 29490 tokens, read from the `Generation queued:` line immediately
  preceding each failure) — a spread from ~16k to ~29k tokens, not a tight cluster at "around 20k"
  as this plan's stated prior hypothesis described. This is *consistent with* growing memory
  pressure as context grows, but does not by itself confirm colima (or anything else) was the
  competing consumer; that would require a captured measurement of colima's own memory footprint
  at each OOM timestamp, which was not taken during this run. Per the plan's own instruction, this
  finding is reported as indeterminate rather than inferred.
- **Whether the false-positive vectors identified here (defects 1 and 2 in §3) have ever actually
  flipped a verdict in any run outside this 4-task dataset cannot be determined** without auditing
  every other stored run directory under `bench/runs/` the same way; this plan's scope was limited
  to the four post-fix tasks plus the one pre-fix task needed to resolve §2's conflict.
  `bench/runs/CANARY.txt` and any other run directories were not examined.
  The fix that would settle this for future runs is 07-13's job: make `HTTP_400_SEEN` (or a
  replacement signal) match only on the actual `MAX_KV_SIZE`/context-rejection phrase, not on a
  bare `\b400\b` anywhere in either file.
- **Whether `agent/cline.txt`'s true-signal matches in this dataset were the *first* match `grep
  -q` encountered (as opposed to a false positive earlier in the file) cannot be determined from
  `meta/*.json` and does not matter for this audit's correctness verdict** — `grep -q`'s
  pass/fail output is identical either way, which is itself part of defect 3. This audit
  determined true/false-positive status by scanning every match in the file (`grep -o`), not by
  relying on which one `grep -q` would have stopped at first.
