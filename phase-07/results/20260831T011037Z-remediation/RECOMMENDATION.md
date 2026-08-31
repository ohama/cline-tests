# Recommendation

Plan `07-14` (gap closure, wave 13). Built on `CANDIDATE-MATRIX.md` in this same directory. No
production file is touched by this document — 07-15 executes whatever the user selects at the
Task 3 checkpoint.

## 1. The answer, in one paragraph

None of the five characterized remedies (A: lower `contextWindow`, B: cap tool-output size, D:
reduce the `max_tokens` floor, E: reduce memory contention) closes any of the three measured
deficits, for reasons that are arithmetic or directly evidenced, not merely inferred: A does not
close either forensically-detailed task because the confirmed defect (M4 — compaction reports
"completed" but prunes zero messages, in 2/2 real captures) means an earlier trigger only adds
tokens sooner, it never removes any; B and D would arithmetically close `telegram-plugin-refactor`
and `v-edit-workspace-tests`/`discord-trivia-approval-keyerror` respectively if they existed, but
neither is reachable through any configuration surface this project has found (a 9-flag CLI
surface and three separate `maxTokens` probes, none of which moved the observed value); E does not
address any task's actual terminal cause (all 3 died of the context ceiling, never of the OOM
events that were present in 2 of them, all of which the task recovered from via retry). The one
candidate that is genuinely open — C, `--compaction basic` instead of the default `agentic` — is
untested by construction: no capture in this project has ever run cline with `--compaction basic`,
so it cannot be scored as helpful or unhelpful, only as unknown.

## 2. Recommended action

**No change** to `settings.contextWindow` (leave it at 29,000).

**Reason:** the evidence does not merely fail to support lowering it — it argues against expecting
benefit from it. The confirmed non-pruning behavior of `agentic`-mode compaction on real workloads
(M4, `CANDIDATE-MATRIX.md` §1) means a lower `contextWindow` changes *when* an ineffective
operation fires, not *whether* it helps: both real completed compaction events grew the tracked
token count (49,750 > 38,626; 48,554 > 28,009) rather than shrinking it, so triggering the same
non-reducing operation earlier or more often does not create headroom — if anything it accelerates
the point at which the next (still non-reducing) compaction attempt is due. This is a determinate
negative finding about the specific lever `apply_provider_config.sh` controls, not an indeterminate
one: the evidence is not silent on whether lowering `contextWindow` helps, it says it plausibly
doesn't, for a mechanism-level reason independent of which trial value is picked.

This is explicitly **not** the same claim as `accept-limit` (recording that this hardware cannot
serve these tasks). `accept-limit` implies a hardware ceiling; but two of the three deficits are
narrow (123 and 459 tokens) and the one candidate that targets the actual confirmed defect —
switching compaction strategy — is completely untested, not disproven. Calling this "hardware
cannot do it" would overclaim in the opposite direction from calling "lower `contextWindow` fixes
it." The honest position is: document what was found, change nothing on the `contextWindow` axis
because the evidence argues against it, and leave the one open lever (compaction strategy) named
and unexplored for a future decision — which is exactly what `doc-only` is for.

**A secondary, non-binding operational note** (Candidate E): avoid running bench or production
tasks concurrently with heavy Docker/colima memory load. This costs nothing and removes a plausible
(though causally unproven) confound for any *future* capture, even though it would not have saved
any of the 3 tasks actually measured here (E does not close M1/M2/M3 — see matrix). This is offered
as color, not as the formal recommendation, and does not require its own canonical option.

## 3. Cost of the recommendation

Recommending no `contextWindow` change costs nothing directly — it is the current shipped state.
The cost is opportunity cost: the next real bench task with a similar shape (a large single-tool
read, or a long multi-tool-call session) will very likely die the same way, because nothing about
the confirmed mechanism (M4, non-pruning compaction) changes. `BCH-01` stays `not_met`. This is
stated in measured terms, not asserted as free: 3/3 reached-the-model tasks in the one post-fix
bench run captured so far died at the ceiling, and this recommendation does not change that number
going forward.

## 4. Falsification condition

**This recommendation is wrong if a fresh, real (non-synthetic) capture of a completed
`auto_compaction` event shows `messagesAfter < messagesBefore` and `tokensAfter < tokensBefore`** —
i.e., if compaction is ever observed to actually prune messages on a real multi-tool-call agent
workload, not just on the synthetic filler-file regression. That single observation would
reinstate lowering `contextWindow` as a live, evidence-backed option, because the mechanism this
recommendation rests on (compaction adds without removing) would no longer hold in general — it
would mean the two real captures examined here (07-11's two tasks) were themselves the anomaly,
not the rule. The specific check: `grep '"phase":"completed"'` on a fresh `.compaction.json` or
`cline.txt` capture, comparing `messagesBefore`/`messagesAfter` and `tokensBefore`/`tokensAfter`.

## 5. What this does NOT claim

This analysis is about why three specific tasks died. **It does not establish that not changing
`contextWindow` makes cline-bench pass**, and it does not change the fact that **zero tasks have
passed** cline-bench on this stack to date (N=4, M=3 reached-the-model, P=0 — unchanged across
07-12's audit and 07-13's reclassification). This recommendation is a statement about one
candidate (lowering `contextWindow`) being unlikely to help, evidenced by a confirmed defect in a
different subsystem (compaction pruning) — it is not a claim that the underlying problem is solved,
partially solved, or bounded. 07-15 must not propagate "no change needed" into any wording that
implies the 32K-ceiling failures are resolved or expected to stop recurring.

## 6. Scope check against the Core Value

`PROJECT.md`'s Core Value — **"Cline이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는
것"** (Cline compacts itself before hitting the 32K wall, so tasks don't die mid-way) — is recorded
as `✅ 달성됨 (2026-08-30)` on the strength of the Phase 1 synthetic filler-file regression
(`phase-01/results/exp-verify29k/`: 18 filler files, 3+ compactions, 0 server 400s).

**This phase's real-agent evidence qualifies that record; it does not overturn the synthetic
result, but it does contradict its implicit generalization to real agent workloads.** The synthetic
regression's own compaction events (5/5) genuinely shrank both token count and message count —
that measurement was correct and remains correct for the workload it tested (uniform ~1,440-token
filler files, read one at a time, no large single-tool-result jumps). But on the two real bench
tasks with detailed forensics, the identical `auto_compaction` mechanism (same notice schema, same
producer, confirmed in `RECLASSIFICATION.md` §4) did not prune on either of its 2 real completed
events, and 3/3 reached-the-model bench tasks died at the ceiling.

**Recommended wording change for 07-15/07-16 to consider (not made here — this plan does not edit
`PROJECT.md`):** qualify the Core Value's "달성됨" note to state explicitly that it was measured
under a synthetic, uniform-file-read regression, and that the one real-agent verification attempted
so far (Phase 7 cline-bench) shows the same compaction mechanism failing to prune in its only 2
captured real invocations, correlated with 3/3 reached-the-model task deaths. The Core Value should
not read as fully generalized to real agent workloads until either a real-workload regression
passes or the non-pruning finding is contradicted by a fresh capture (§4's falsification
condition).
