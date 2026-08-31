# Decision

Plan `07-14` (gap closure, wave 13), Task 3 checkpoint. Recorded by the continuation agent that
resumed this plan after the user answered.

**Decision recorded:** 2026-08-31T02:04:23Z

## Options as presented

The user was shown, in full, before answering:

- The per-task root causes from `CANDIDATE-MATRIX.md` (one line each).
- `RECOMMENDATION.md`'s recommendation — no change to `settings.contextWindow` (leave at 29,000)
  — and its cost, falsification condition, and Core Value scope check.
- The four canonical options exactly as specified in `07-14-PLAN.md` Task 3, with their pros/cons:
  - `doc-only` — document the findings, change no configuration.
  - `config-change` — apply the recommended config change and re-verify, without a bench run.
  - `config-change-plus-run` — apply the recommended change and spend the one permitted live run
    validating it.
  - `accept-limit` — record that this hardware cannot serve these tasks, and change nothing.
- The 🔴 live-effect risk: `com.ohama.kanban` and `com.ohama.kanban-proxy` are running right now,
  `com.ohama.kanban` is a live wrapper around `cline`, and any value written to
  `~/.cline/data/settings/providers.json` by 07-15 takes effect for them immediately, on their next
  request, with no restart — so a real Kanban/Telegram task could execute against an
  as-yet-unvalidated `contextWindow` during the apply → verify → regression window. `doc-only` and
  `accept-limit` avoid this exposure entirely; both `config-change` options carry it.

## User's verbatim reply

> `doc-only`

## Canonical selection

```
SELECTION: doc-only
```

This is the canonical label directly — no resolution or re-confirmation of an off-menu reply was
needed. It matches `RECOMMENDATION.md`'s own recommendation (no change to `settings.contextWindow`;
leave it at 29,000).

**What this means for 07-15:** document the findings; make no change to
`~/.cline/data/settings/providers.json` or any other production configuration. `BCH-01` remains
`not_met`. No live bench run is authorized by this decision.

## Second question: the `--compaction basic` mismatch

The checkpoint's own evidence surfaces an asymmetry that the four canonical options do not resolve:
`CANDIDATE-MATRIX.md` Candidate C (`--compaction basic`) is the one candidate the matrix scored as
genuinely promising and untested (`unknown-from-evidence — the single candidate most directly aimed
at [M4, non-pruning compaction]`) — it targets the confirmed defect directly, unlike Candidates A,
B, D, and E, which the matrix and recommendation rule out on the merits. Yet none of the four
canonical options in this plan's Task 3 provides a path to exercising it: 07-15's apply mechanism
(`phase-01/config/apply_provider_config.sh`) only writes `settings.contextWindow`; it has no branch
for changing the compaction strategy flag. Selecting `doc-only` alone would let this lever go
unrecorded as anything other than an item buried inside `CANDIDATE-MATRIX.md`.

This mismatch was surfaced to the user as a separate question, outside the four-option menu, because
it is not something `07-15`'s existing dispatch mechanism can act on regardless of which of the four
labels was chosen.

**User's verbatim reply (second question):**

> "후속 과제로 기록만" — record it as a follow-up item only.

**Resolution:** Do not widen this phase's scope to exercise `--compaction basic`. Do not run a
synthetic or live test of it as part of this plan or 07-15. It is recorded here as a **consciously
deferred follow-up**, not an oversight:

- **Lever:** `--compaction basic` (cline 3.0.53's alternative to the default `agentic` strategy).
- **Why it was flagged:** it is the only candidate in `CANDIDATE-MATRIX.md` that targets the
  confirmed defect (M4 — `agentic`-mode compaction reports `completed` but adds to, rather than
  prunes, the tracked token count, observed in 2/2 real completed compaction events) rather than
  working around it.
- **Why it was not exercised now:** (1) it falls outside the four canonical options this checkpoint
  was scoped to decide between; (2) `07-15`'s apply mechanism has no code path for it; (3) the user
  explicitly chose not to expand this gap-closure phase's scope to test it, live or synthetically.
- **Status:** open, untested, unevaluated beyond the matrix's `unknown-from-evidence` scoring.
  Whoever picks this up next should treat it as a fresh candidate requiring its own live-run
  authorization, not as something this decision implicitly approved or ruled out.

## Correction to the evidentiary record: `exp-basic` does not count

During this session, an experiment was run at `phase-01/results/exp-basic/` (`run.ndjson`,
2026-08-29) using `--compaction basic`. **This run does NOT constitute prior testing of
`--compaction basic` against a working configuration, and must not be cited as evidence toward the
Candidate C question above, in `CANDIDATE-MATRIX.md`, or anywhere else in this project's record.**

The reason: that run's configuration held `contextWindow` **inside `models[]`**, not at the
`settings` top level. Per this project's own established finding (`07-RESEARCH.md`,
`07-VERIFICATION.md`; the same fallback mechanism this whole project exists to catch), a provider of
family `openai-compatible` with no top-level `contextWindow` override falls back to
`maxInputTokens = 128,000` regardless of what value sits inside `models[]`. So `exp-basic` ran with
the 128k fallback engaged, not with this stack's real 29,000/32,768 constraint — it tells us nothing
about how `basic`-mode compaction behaves against the actual ceiling this project cares about.

**`--compaction basic` has never been tested against a working top-level `contextWindow` config on
this stack.** `CANDIDATE-MATRIX.md`'s own text already states this correctly ("No stored evidence
exists of `--compaction basic`'s behavior on this stack. No run directory, probe, or forensic
capture in this project has ever invoked cline with `--compaction basic`[under a valid config]"),
and `RECOMMENDATION.md` likewise treats Candidate C as untested by construction. This section exists
so that record is not silently contradicted by `exp-basic` being rediscovered later and mistaken for
counter-evidence — `exp-basic` is void for this question, and any future use of `--compaction basic`
as a follow-up (see above) must be run against a correctly top-level-configured
`settings.contextWindow`, not repeat `exp-basic`'s setup.

## Safety verification performed before writing this file

- `shasum -a 256 ~/.cline/data/settings/providers.json` → `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214`
  — unchanged versus the pre-gap hash recorded in this same directory's `README.md` and in
  `07-11-SUMMARY.md`/`07-12-SUMMARY.md`/`07-13-SUMMARY.md`. No write, and no invocation of
  `apply_provider_config.sh`, occurred as part of recording this decision.
- Six live service pids checked via `ps -p`, all present and unchanged from the values recorded at
  this plan's start: `com.ohama.flashnext` 46573, `com.ohama.role-shim` 75548,
  `com.ohama.litellm` 48525, `com.ohama.kanban` 36175, `com.ohama.kanban-proxy` 19669,
  `com.ohama.telegram-connect` 99162.
- `colima status` → "colima is not running"; `docker ps`/`docker info` unreachable (daemon down).
  Colima was not started, and no Docker command was issued beyond a read-only status check.
- `lsof -i :3000` → empty.
- No `cline` or `kanban` invocation was made while producing this document.
