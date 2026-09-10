# Phase 12: Scope Decisions

This is the phase's own record of what is in scope, and why. `.planning/phases/12-documentation-update/12-RESEARCH.md`
raised eight open items and deliberately refused to decide them. Four were decided by the
orchestrator before this plan was written (Section 1); four are settled here, by this plan
(Section 2). Every wave-2 plan reads this document instead of re-deriving any of it — the reasons,
not just the verdicts, are what future readers (and future phases) need.

## Section 1 — decisions inherited (already made, recorded here so the reasons survive)

1. **`max_tokens` dynamism is IN scope.** `docs/32k-compaction-policy.md` §4 and
   `docs/cline-max-tokens-findings.md` assert a fixed wire `max_tokens=2048`. Phase 11 measured
   20983 at cline 3.0.60/3.0.61 and, decisively, that it is not fixed at all — cline sizes the
   completion budget per request so `prompt_tokens + max_tokens` lands near `contextWindow × 0.9`
   (≈26,100). Orchestrator-verified across 278 server-log samples: the sum ranged 9,442–32,013
   with **zero** breaches of the server's 32,768 limit. This falsifies the overshoot arithmetic
   those two documents rest on. Reason for inclusion: leaving a known-false number on disk is
   precisely what this phase exists to prevent, so it goes in even though USE-04/USE-05 do not
   name those files. Evidence: `phase-11/OPEN-ITEMS.md` Open Item 2, `phase-11/AB-PROTOCOL.md` §3,
   `phase-11/PHASE-11-FINDINGS.md` §4 item 2.

2. **`howto/` and `qanda/` staleness is IN scope.** Written this milestone, partly before Phase
   10/11 shipped — the same class of debt as the design docs. `qanda/004` §5 was already corrected
   today (commit `244a598`) after the Phase 11 verifier caught it still calling the containment "a
   proposal." The other entries were checked for the same shape and two were found to have it
   (`qanda/001`, `qanda/003`) — confirmed again in this session (`phase-12/verify_docs.sh`'s RED
   run reports both). Convention to follow: `qanda/004`'s own — self-correct in place with a dated
   banner, not a silent rewrite.

3. **`flashnext-reach-xhigh` stays, documented as verification-only.** Removing it requires
   another litellm restart and another Kanban/Telegram outage; leaving it costs nothing. Recorded
   as a **v1.2 removal candidate**. The docs must not present it as a usage surface. This closes an
   item deferred twice (`phase-10/PHASE-10-FINDINGS.md` §5, `phase-11/AB-RESULTS.md` §10) — this is
   now decided, not handed onward a third time.

4. **`--mode <act|plan>` vs `-p`: the live-confirmed `-p` wins.** `docs/manual/01-cli.md` §6 got
   `--mode` from a Phase 8 binary `strings` scan at 3.0.53; Phase 11 confirmed `-p` by actually
   running the 3.0.61 binary. The distinction worth preserving is **which evidence superseded
   which** — a live invocation beat a static string scan — not just the corrected flag name. This
   does **not** resolve GAP-PLANMODE, which is about `phase-04/run_headless.sh`, a different tool;
   the two must not be conflated (`phase-12/verify_docs.sh` enforces this directly: `01-cli.md`
   must carry both `phase-04/run_headless.sh` and `GAP-PLANMODE` as anchors, alongside the new
   `## 6a` wrapper section and `--mode` itself, so the superseded flag is named, not silently
   deleted).

## Section 2 — open items this plan settles

5. **"Four `howto/` docs" vs three on disk.** Three `.md` files exist
   (`fast-and-deep-mode.md`, `thinking-and-reasoning-effort.md`, `measuring-thinking-at-8000.md`)
   plus a `README.md` that itself lists exactly those three (`howto/README.md`, confirmed by
   re-reading in this session). Decision: **treat it as three** — disk reality wins over the
   brief's count. `measuring-thinking-at-8000.md` was read and found to need no v1.1 correction
   (no forbidden literal registered for it in `verify_docs.sh`) — recording that it was checked,
   so "three" is not mistaken for "we forgot one."

6. **`cline-src`'s tag moved.** The checkout at `/Users/ohama/projs/cline-src` is now
   `cli-v3.0.61` (`git describe --tags` confirms this live, this session; `git log -1 --oneline`
   → `595f1dbf2 fix(core): close imported-session stores before the temp dirs are removed`).
   Every Phase 9 source citation was read at `cli-v3.0.53` and is reachable only via
   `git show cli-v3.0.53:<path>`. Decision: **every corrected doc that cites a 3.0.53 line number
   must carry the `git show cli-v3.0.53:` form** — enforced mechanically by `verify_docs.sh`'s
   `TAG_CITATION` class (if a document's live body contains `cli-v3.0.53`, it must also contain
   the literal `git show cli-v3.0.53:`) — so a future reader does not grep the working tree, find
   nothing, and conclude the citation was invented, which already happened once this milestone
   (`qanda/004`'s own "이전 판이 틀렸습니다" correction about a `strings`-scanned obfuscated bundle).

   Verified resolvable at `cli-v3.0.53` **in this session**, via
   `git -C /Users/ohama/projs/cline-src show cli-v3.0.53:<path>` for each of the five paths named
   by Phase 9's citations:

   - `sdk/packages/llms/src/providers/ai-sdk.ts`
   - `sdk/packages/llms/src/providers/model-facts.ts`
   - `sdk/packages/core/src/runtime/config/agent-message-codec.ts` — note this path; some earlier
     artifacts quote a shorter path for this file. The real path at `cli-v3.0.53` is under
     `sdk/packages/core/src/runtime/config/`, not a shorter one — confirmed by `git show` returning
     content, not an error, at exactly this path.
   - `sdk/packages/core/src/session/services/message-builder.ts`
   - `apps/cli/src/main.ts`

   All five returned content (not "fatal: path ... does not exist") when queried this session.

7. **`providers.json`'s current value is point-in-time, not a pin.** It currently reads
   `model=flashnext`, `contextWindow=29000` (confirmed by live read, this session:
   `bash phase-01/config/verify_config.sh` exits 0 today). Decision: **no document may imply the
   file "stays" correct.** It is repeatedly corrected, not stable — every uncontained `cline -m`
   call rewrites `model` (31/31 measured, `phase-11/AB-RESULTS.md`, `providers-drift.tsv`). What is
   pinned is the pair of values `verify_config.sh` asserts, not the file's hash and not its
   momentary content. `verify_docs.sh`'s `docs/cline-config-pins.md` row enforces a
   `REQUIRED_ANY per-call-write` check (`호출마다|매 호출|호출할 때마다`) so this framing survives
   mechanically, not just as a documentation convention.

8. **A correction the research did not have, surfaced by `phase-11/PHASE-11-FINDINGS.md` §6:**
   `.planning/REQUIREMENTS.md` USE-04 and `.planning/ROADMAP.md` Phase 12 criterion 2 both state
   flatly that `--thinking` "이 litellm 에서 400 이 된다." Measured, that is true only for
   `openai/`-prefixed aliases (`flashnext`: litellm's own `UnsupportedParamsError`, HTTP 400). For
   `hosted_vllm/`-prefixed aliases the value passes litellm and the **model server** returns 500,
   and a raw `cline --thinking high` surfaces that 500 as an error event and exits 1 — a user never
   sees a 400 there. Decision: `docs/cline-config-pins.md` states the status code **per alias
   prefix** (enforced: `verify_docs.sh` requires both the literal `400` and the literal `500` in
   that document, "per-prefix status codes, not a single figure"), and plan 12-08 annotates the
   requirement/roadmap text rather than leaving a now-known-imprecise success criterion
   unremarked. This plan does not itself edit `.planning/REQUIREMENTS.md` or `.planning/ROADMAP.md`
   — that annotation is explicitly plan 12-08's job.

## Section 3 — parallel-execution hazard, recorded because it bit this project before

Phase 11's wave 1 hit a git index race when two agents committed concurrently: `git commit -m` with
no pathspec commits the whole index, including another agent's staged work. Every plan in this
phase commits with explicit pathspecs only (`git commit -m "..." -- <files>`), never `git add .` /
`git add -A`. If a commit fails on `index.lock`, wait and retry — do not remove the lock.

## Mechanical enforcement cross-reference

Every decision above that has a corresponding mechanical check in `phase-12/verify_docs.sh` is
noted inline. This document is the *reasons*; `phase-12/verify_docs.sh` is the *contract*. Wave 2
should read both, but is graded only against the latter.
