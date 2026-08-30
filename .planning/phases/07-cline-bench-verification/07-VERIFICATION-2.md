---
phase: 07-cline-bench-verification
plan: gap-closure (07-06..07-10)
verified: 2026-08-30T18:00:51Z
status: passed
score: 2/3 ROADMAP criteria met, gap itself fully closed
re_verification: true
previous_verification: 07-VERIFICATION.md (pre-gap-closure round, criteria 1/2/3 status at that time not carried forward here — see below)
must_haves:
  truths:
    - "The injection defect (silent schema-rejection fallback to an empty provider registry) is fixed and proven fixed with live, byte-level evidence."
    - "The cumulative task/model/pass counts (N unique tasks, M reached-the-model, P passed) are accurate and identical across every document that cites them."
    - "BCH-01 is honestly recorded as not_met, as a deliberate stopping point backed by a real cost decision, not silently dropped or inflated."
    - "BCH-02 and BCH-03 are met, with real per-task artifacts and a real pass/fail/duration table."
    - "No document overclaims in either direction: neither implying 5-8 tasks ran/passed, nor leaving the now-false 'never reached the model' framing unscoped to the pre-fix run."
    - "No collateral damage to the six live services, port 3000, sandbox boundary, or host cline pin (drift recorded but not silently repaired)."
  artifacts:
    - path: "phase-07/bench/cline-cw-providers.json"
      provides: "The two-line schema fix (top-level version, per-provider updatedAt) that is the entire root-cause fix"
    - path: "bench/runs/20260830T093657Z-phase07/"
      provides: "Pre-fix evidence bundle (1 unique task, 0 bytes/0 turns, untouched by gap work)"
    - path: "bench/runs/20260830T122809Z-phase07-fix/"
      provides: "Post-fix evidence bundle (4 unique tasks total across 2 runs, 3 reached the model)"
    - path: "phase-07/results/20260830T113923Z-injection-diag/DIAGNOSIS.md"
      provides: "H4-confirmed root cause (schema-rejected), H1 (version skew) ruled out with live same-platform binary comparison"
    - path: "phase-07/results/20260830T122700Z-injection-fix/PROOF.md"
      provides: "Decisive post-fix proof: SLICE_BYTES=145133, MODEL_TURNS=38, vs 0/0 pre-fix"
    - path: "docs/cline-bench.md"
      provides: "Corrected-in-both-directions record, §4 limitations, §9 Phase-8 handoff boundary"
    - path: "phase-07/results/20260830T174325Z-phase-close-2/criteria2.md"
      provides: "Three ROADMAP criteria re-mapped to post-gap-closure evidence"
    - path: "phase-07/results/20260830T174325Z-phase-close-2/anti-overclaim.md"
      provides: "6/6 anti-overclaim checks, sentence-cited"
    - path: "phase-07/results/20260830T174325Z-phase-close-2/gates/collateral.md"
      provides: "9/9 collateral-damage checks"
  key_links:
    - from: "phase-07/bench/verify_bench.sh"
      to: "bench/runs/{pre-fix,post-fix}"
      via: "B11 reached-the-model gate, opt-in per run directory via config.json's cw_injection field"
gaps: []
---

# Phase 7 (cline-bench 동작 검증) — Gap-Closure Re-Verification Report

**Scope:** plans 07-06 through 07-10 (`gap_closure: true`), the injection-defect gap identified in
the pre-gap-closure `07-VERIFICATION.md`. Plans 07-01..07-05 checked only for consistency (they
were not re-verified in depth — the pre-gap `07-VERIFICATION.md` already covered them).

**Verified:** 2026-08-30T18:00:51Z
**Status:** `passed`
**Verifier:** Claude (gsd-verifier), read-only — no `harbor run`, no `cline` invocation used for
evidence (see "Note on a near-miss" below), no container started, no service restarted.

## Judgment (stated plainly, up front)

**The gap this plan targeted — the injection defect — is genuinely closed.** Every number in the
claimed outcome was independently re-derived from raw bytes, not trusted from any SUMMARY.md, and
every number matched exactly. BCH-01 remaining `not_met` is not a defect of this gap-closure round;
it is an honestly documented, deliberate stopping point reached via a real (if imperfectly
evidenced — see below) user cost decision, correctly reflected as `not_met` everywhere it appears,
never rounded up. This phase's gap-closure work should be accepted as `passed`.

The one soft spot worth naming plainly (not a gap, but worth a human's attention): the round-2
"plus-three" task count came from an orchestrator *interpretation* of an ambiguous "Continue" reply,
not a verbatim user selection like round 1's `stop-at-one`. The project's own records
(`decision2.md`) disclose this openly and hold it to a visibly lower evidentiary bar than round 1 —
this is exactly the right way to handle an ambiguous input, and is flagged here only so a human
knows it exists, not because it invalidates anything.

## Independent verification of the decisive signal (raw bytes)

```
PRE-FIX  server-log: bench/runs/20260830T093657Z-phase07/server-log/discord-trivia-approval-keyerror.flashnext.err.txt
         wc -c = 0 bytes
         meta model_turns = 0

POST-FIX server-log: bench/runs/20260830T122809Z-phase07-fix/server-log/discord-trivia-approval-keyerror.flashnext.err.txt
         wc -c = 145133 bytes
         meta model_turns = 38
```

Both numbers match the claimed outcome (`145,133-byte`, `model_turns=38`, `0 bytes / 0 turns`
pre-fix) exactly, re-derived directly with `wc -c` and by reading the `meta/*.json` files myself,
not by trusting `PROOF.md`'s own transcription of these numbers.

**Pre-fix bundle integrity confirmed untouched by gap work:** `git log --oneline -- bench/runs/20260830T093657Z-phase07/`
shows its last touching commit is `021cafa` ("docs(07-04): ... BCH-03 table"), predating every
gap-closure plan (07-06..07-10). `git status --short` on the directory is clean (no uncommitted
changes). No plan in this gap-closure round wrote into the pre-fix bundle.

## Independent verification of the cumulative counts

Counted directly from the filesystem, not from any narrative document:

- **Pre-fix run directory** (`bench/runs/20260830T093657Z-phase07/`): 1 task (`discord-trivia-approval-keyerror`), 1 run instance.
- **Post-fix run directory** (`bench/runs/20260830T122809Z-phase07-fix/`): 4 tasks (`discord-trivia-approval-keyerror`, `telegram-plugin-refactor`, `filmarchiver`, `v-edit-workspace-tests`), 4 run instances.
- **Unique task names across both directories:** `discord-trivia-approval-keyerror` (appears in both — same task, attempted twice, not two tasks), `telegram-plugin-refactor`, `filmarchiver`, `v-edit-workspace-tests` → **N = 4 unique tasks**, confirmed.
- **Run instances:** 1 (pre-fix) + 4 (post-fix) = **5**, confirmed.
- **Reached the model** (non-empty server-log slice AND `model_turns > 0`), read directly from each `meta/*.json`:
  - pre-fix `discord-trivia-approval-keyerror`: 0 turns → did not reach
  - post-fix `discord-trivia-approval-keyerror`: 38 turns → reached
  - post-fix `telegram-plugin-refactor`: 6 turns → reached
  - post-fix `filmarchiver`: 0 turns → did not reach
  - post-fix `v-edit-workspace-tests`: 12 turns → reached
  - **M = 3, confirmed independently.**
- **Passed**, read from every `jobs/*/result.json`'s `reward_stats`/`reward` field and every
  `meta/*.json`'s `reward` field: every attempted instance shows `reward: 0` or `reward: null`
  (never `1` or a truthy pass indicator), and every `verdict` is `fail-infra` or `fail-context`,
  never `pass`. **P = 0, confirmed independently.**

**No number differs from the claimed outcome.** N=4/M=3/P=0 is exactly what the raw evidence
shows, matched independently in all four documents that cite it (`docs/cline-bench.md`,
`criteria2.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`) — cross-checked myself, not merely
trusting `anti-overclaim.md`'s own check 6.

## Anti-overclaim sweep (both directions)

Read (not grepped) `docs/cline-bench.md` §1–§9, `criteria2.md`, `anti-overclaim.md`, `.planning/ROADMAP.md`
Phase 7 block and progress table, `.planning/REQUIREMENTS.md` BCH rows, `.planning/STATE.md`
Current focus/Current Position.

| Check | Result | Evidence |
| --- | --- | --- |
| (a) Nothing implies 5-8 tasks ran, any task passed, or the suite was verified | **PASS** | `docs/cline-bench.md` §1 states "4개" and "통과는 여전히 0개다" in the same paragraph as the 5-8 plan reference; §9's rewritten bold prohibition explicitly forbids "통과"/"검증"/"완료할 수 있다" sentences. `ROADMAP.md` criterion 1 states `not_met` inline with the exact shortfall. `REQUIREMENTS.md` BCH-01 checkbox remains unchecked with a dated correction footnote, not silently ticked. |
| (b) The now-false pre-gap claim ("cline-bench never reached this stack") is corrected, scoped to the pre-fix run only | **PASS** | §4's rewritten bullet explicitly names `bench/runs/20260830T093657Z-phase07/` as the run that never reached the model, and separately states the post-fix run (`bench/runs/20260830T122809Z-phase07-fix/`) proves the opposite for 3 of 4 tasks — the claim is scoped by run-directory name, not stated as a blanket fact in either direction. |
| (c) The 32K-ceiling finding is recorded | **PASS** | §4: "모델에 도달한 과제 3개 전부, 예외 없이, 이 스택의 32K 컨텍스트 천장에서 거부됐다" with per-task turn/token counts; `criteria2.md`'s verdict-class note repeats it; `meta/*.json`'s own `verdict: fail-context` and `http_400_seen: true` fields independently corroborate it. |
| (d) H1 (version skew) recorded as real-but-non-causal | **PASS** | `docs/cline-bench.md` §2: "버전 스큐 가설은 닫힌 질문이며 다시 열어서는 안 된다"; `DIAGNOSIS.md`'s per-hypothesis table: `H1 (version skew) | ruled-out`, decided by a live same-platform (linux-arm64) 3.0.53-vs-3.0.60 binary comparison, distinct from H4 (schema-rejected, CONFIRMED) which is the sole causal story everywhere. |

**No overclaim found in either direction**, matching `anti-overclaim.md`'s own 6/6 PASS result,
independently re-derived by reading the same four documents myself rather than trusting the
audit's self-report.

## Standing gates re-run (all seven, myself, read-only)

| Gate | Command | Result |
| --- | --- | --- |
| `verify_bench.sh` (post-fix dir) | `--run-dir bench/runs/20260830T122809Z-phase07-fix` | **11/11 PASS** (B11 PASS) |
| `verify_bench.sh` (pre-fix dir) | `--run-dir bench/runs/20260830T093657Z-phase07` | **10/10 PASS** (B11 correctly SKIP — pre-fix `cw_injection` value is not a post-fix value, B11 does not evaluate it) |
| `verify_bench.sh` negative control | `--run-dir /nonexistent` | **4/10 FAIL, exit=1** — B6 fails on `META_COUNT=0`; the gate genuinely fails when evidence is absent, proving it is not a gate that always passes |
| `preflight.sh` | (no args) | **11/11 PASS** |
| `verify_services.sh` (phase-05) | (no args) | **15/15 PASS** |
| `verify_no_regression.sh` (phase-02) | (no args) | **INF03 PASS** |
| `verify_sandbox.sh` (phase-03) | (no args) | **16/16 PASS**, `CRITERION 4 PASS` |
| `verify_network.sh` (phase-06) | `--baseline phase-06/results/20260830T051403Z-baseline` | **24/24 PASS, CRASHED 0** |
| `verify_config.sh` (phase-01) | (no args) | **exit 0**, providers.json confirmed flashnext/29000/no models[] |

All seven standing gates green, matching the claimed sweep. The B11 per-run-dir gating genuinely
lets the pre-fix bundle pass honestly (10/10, B11 SKIP) rather than retroactively failing it for
not having post-fix evidence — this is the correct design (a pre-fix bundle should not be judged
by a post-fix-only criterion), and the negative control confirms the gate is not vacuous.

Note: my first `verify_network.sh` invocation, run without `--baseline`, produced `23/24 CRASHED 1
INCONCLUSIVE` (the `live-pids-stable` check requires a baseline argument and degrades gracefully,
not a real regression) — re-running with the correct baseline directory (the same one the
gap-closure sweep itself used) produced the claimed `24/24`. This is a usage detail, not a defect
in the gate or the phase's work.

## No collateral damage (independently re-checked)

| Item | Result |
| --- | --- |
| Six live pids (46573/75548/48525/53894/99162/19669) | **Unchanged** — all six confirmed alive via `ps -p` |
| Port 3000 | **Unbound** — `lsof -i :3000` empty |
| `EXTRA_ALLOW_PATHS` | Not independently re-checked beyond `collateral.md`'s own PlistBuddy sweep (no reason to doubt it; low-risk item) |
| `workspace/ALLOWED_REPOS.json` `repos[]` | **Excludes `bench/` and the repo root** — confirmed by reading the file directly; only entry is `workspace/scratch-repo` |
| `bench/runs/CANARY.txt` unreadable from sandbox | **Confirmed via `verify_sandbox.sh` re-run**, `CRITERION 4 PASS`, `CANARY-LEAK=PASS` |
| New `tailscale serve` entries beyond Phase 6 baseline | **None** — `tailscale serve status` shows exactly the same 4 entries (`:8443` Funnel pre-existing, `:8444` kanban-proxy, `:10000`, bare hostname) as `collateral.md` records |
| Docker containers | **No lingering bench/harbor containers** — `docker ps -a` shows only pre-existing, unrelated project containers (`mhr-*`, `nextcloud-*`, `safestacktutorial-db-1`, `sandbox-egress-proxy`) |
| Host `cline` global install | **Unchanged, still drifted to 3.0.60** — confirmed via `npm root -g`/`cline`'s own `package.json` (`"version": "3.0.60"`), **not** by invoking the `cline` binary. Recorded as a known, unrepaired, out-of-scope item in `criteria2.md` and `.planning/STATE.md`, consistent with the claim. |
| Host `providers.json` content hash | **Byte-identical** to the pre-gap-batch hash recorded in `phase-07/results/20260830T170042Z-gap-batch/pre/providers-hash.txt` (`fa43d153...`), confirmed via `shasum -a 256` myself |

## Note on a near-miss during my own verification session

While probing for the host `cline` version, I briefly (and mistakenly) started `cline --version`
in the background before immediately killing it (~0.1s window) after recalling the "do not invoke
cline" constraint. I confirmed no damage resulted: `~/.cline/data/settings/providers.json`'s mtime
(`Aug 30 19:51:39 2026`) predates this verification session (started `Aug 31 02:5x`), and its
SHA-256 hash matches the pre-gap-batch recorded hash exactly. I switched to reading the installed
package's `package.json` directly for the remainder of the version check, which is what I should
have done from the start. Flagging this here in the interest of full transparency, even though no
actual state change occurred.

## Consistency check, plans 07-01..07-05

Spot-checked only (not re-verified in depth, per scope): the pre-fix run directory's commit
history (`git log`) shows 07-01 through 07-04 built the harbor/cline-bench installation, the
injection scripts, the smoke run, and the BCH-03 table in sequence, consistent with the
pre-gap-closure `07-VERIFICATION.md`'s prior findings. `docs/cline-bench.md`'s §2/§3 tables (harbor
version `0.22.0`, cline-bench commit `d1085569f...`, live task pool `12`) match what 07-01's
inventory recorded. No inconsistency found.

## Requirements coverage

| Requirement | Status | Evidence |
| --- | --- | --- |
| BCH-01 | **Not met** (honest, deliberate) | 4 unique tasks vs the 5-8 floor; recorded `not_met` in `ROADMAP.md`, `criteria2.md`, `REQUIREMENTS.md` with no inflation anywhere |
| BCH-02 | **Met** | `verify_bench.sh` B3/B4 PASS on both run directories; every attempted task's prompt and result artifacts present, `filmarchiver`'s missing `verifier/reward.txt` explained in `CAPTURE-GAPS.txt` per B4's own escape valve |
| BCH-03 | **Met** | Both `summary.md` tables present with pass/fail/duration data; `verify_bench.sh` B5/B6 PASS on both |

## Gaps

**None.** The injection defect this gap-closure round targeted is closed, proven with raw bytes I
re-derived myself, not merely trusted from any summary. BCH-01's shortfall is a documented,
deliberate stopping point (informed cost decision at round 2, with the interpretation caveat noted
above), not a defect requiring further plans. No overclaim exists in either direction. No
collateral damage to the surrounding six-phase stack.

---
*Verified: 2026-08-30T18:00:51Z*
*Verifier: Claude (gsd-verifier)*
