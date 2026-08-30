---
phase: 05-kanban-telegram-services
plan: 01
subsystem: infra
tags: [launchd, sandbox, kanban, cline-connect-telegram, readiness-gate, bash]

# Dependency graph
requires:
  - phase: 01-cline-config-and-32k-compaction
    provides: phase-01/config/cline-invocation.env (CLINE_BIN/KANBAN_BIN/CLINE_PROVIDER/CLINE_MODEL pins)
  - phase: 02-infra-hardening
    provides: phase-02/infra/restart_service.sh (async-bootout-aware restart helper, reused only by reference in comments, never re-forked)
  - phase: 03-sandbox
    provides: phase-03/sandbox/run_sandboxed.sh (sole sanctioned sandbox entry point) and EXTRA_ALLOW_PATHS convention
  - phase: 04-headless-cli-wrapper
    provides: phase-04/config.env (SANDBOX_WORKDIR/ALLOWED_REPOS_JSON derivation) and THE CWD RULE pattern (cd + prefix-match assertion) reused verbatim
provides:
  - "phase-05/services/config.env — single source of truth for every Phase 5 label/port/timeout, reusing (not re-deriving) SANDBOX_WORKDIR/ALLOWED_REPOS_JSON from phase-04/config.env"
  - "phase-05/services/wait_for_port.sh — generic bounded TCP-connect primitive, no fixed sleep, at-most-one-progress-line-per-minute"
  - "phase-05/services/wait_for_upstream.sh — the SVC-04 readiness gate: TCP(:8000) -> flashnext /health loaded_model -> litellm alias advertised, tail-of-loop pacing on any failed stage"
  - "phase-05/services/run_kanban_service.sh — the future com.ohama.kanban ProgramArguments[1]: CWD-rule assertion, bounded readiness wait, exec-chain into run_sandboxed.sh"
  - "phase-05/services/run_telegram_service.sh — the future com.ohama.telegram-connect ProgramArguments[1]: empty-token idle branch (no spin, no exit), real invocation carries -i/--no-tools/--provider/--model long forms"
affects: [05-03, 05-04, 05-05, phase-close-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "wait-then-exec launchd wrapper: a bounded readiness gate runs before the real command is exec'd, so launchd's own KeepAlive/ThrottleInterval never has to fight a tight crash loop against a not-yet-ready upstream"
    - "idle-not-exit for an absent required secret: an empty TELEGRAM_BOT_TOKEN blocks in a bounded numeric sleep loop rather than exiting, keeping launchd's reported state honestly 'running' without ever invoking the real command"
    - "single shared config.env per phase, pre-set-then-source ordering to reuse an upstream phase's own path derivation instead of re-deriving it in a second place"

key-files:
  created:
    - phase-05/services/config.env
    - phase-05/services/wait_for_port.sh
    - phase-05/services/wait_for_upstream.sh
    - phase-05/services/run_kanban_service.sh
    - phase-05/services/run_telegram_service.sh
  modified: []

key-decisions:
  - "The readiness gate probes flashnext's own /health endpoint (loaded_model non-null) plus litellm's /v1/models alias advertisement, never a bare TCP probe of litellm's :4000 — litellm binds its listener independent of whether flashnext has loaded, so a TCP-only probe would report ready in exactly the scenario SVC-04 exists to cover"
  - "Pacing always happens at the tail of the outer wait_for_upstream.sh loop, regardless of which of the three stages failed — stage 1's own internal bounded wait_for_port.sh call cannot be relied on as the loop's only pacing once the TCP port is already open, since a stage-2/3 failure would then spin curl/python3 subprocesses for the whole timeout budget"
  - "The telegram wrapper's real invocation uses --provider/--model long forms exclusively; cline connect telegram has no -P short flag at all (verified live: unknown option '-P') and -m means --bot-username, not --model, on this subcommand's flag surface — copying the one-shot prompt-mode short flags here would crash-loop on the first launch after a real token is injected"
  - "Comments that needed to reference banned literal strings (\"cline kanban\", \"--auto-approve\", \"-P \", \"sleep infinity\") for explanatory purposes were reworded to break the exact substring/regex match the plan's own grep-based verification checks for, while preserving the explanatory meaning — same technique 02-01 used for its kill/pkill comment"

patterns-established:
  - "Pattern: a Phase 5 service wrapper's shape is CWD-rule assertion -> (optional secret-presence idle gate) -> bounded upstream readiness wait -> exec-chain through run_sandboxed.sh, in that fixed order, cheapest/safest checks first"

duration: 25min
completed: 2026-08-30
---

# Phase 5 Plan 01: Kanban/Telegram launchd wrapper scripts + shared readiness gate Summary

**Authored the two SVC-03/SVC-04 launchd wrappers (`run_kanban_service.sh`, `run_telegram_service.sh`) plus their shared `config.env`/`wait_for_port.sh`/`wait_for_upstream.sh`, live-verified the 3-stage readiness gate against the running flashnext/litellm stack (pass + two forced failure modes), and registered nothing.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-30T (session start, first file reads)
- **Completed:** 2026-08-30
- **Tasks:** 3/3
- **Files created:** 5

## Accomplishments
- `phase-05/services/config.env`: single source of truth for every Phase 5 label/port/timeout; reuses `SANDBOX_WORKDIR`/`ALLOWED_REPOS_JSON` from `phase-04/config.env` via the pre-set-then-source idiom (never re-derives); documents the `$HOME/.cline/logs/` sandboxed-stdio SIGABRT fix and the flashnext-not-litellm readiness-target rationale as load-bearing comment blocks.
- `phase-05/services/wait_for_port.sh`: generic bounded TCP-connect primitive, live-verified against the open `:4000` (exit 0, instant) and a refused `:1` (exit 1 after ~6s, exactly one timeout line).
- `phase-05/services/wait_for_upstream.sh`: the SVC-04 production readiness gate — TCP(:8000) -> flashnext `/health` (`status==healthy` AND non-null `loaded_model`) -> litellm `/v1/models` advertises `flashnext` — with tail-of-loop pacing on any failed stage. Live-verified three ways against the running stack: all three stages pass (exit 0, ~0.1s), a forced stage-2 failure (health URL repointed at `/v1/models`, exit 1 after the bounded 6s budget), and a forced stage-3 failure (bogus alias, exit 1 after 6s).
- `phase-05/services/run_kanban_service.sh`: enforces THE CWD RULE, waits on the bounded readiness gate (never a raw TCP probe), then `exec`s through `run_sandboxed.sh` so the supervised pid is the real kanban process; `--port 3484` pinned, `--no-passcode`/`--skip-shutdown-cleanup`/`--https`/`--update` all deliberately omitted with reasons documented inline.
- `phase-05/services/run_telegram_service.sh`: the empty-token branch idles in a bounded numeric `/bin/sleep` loop (never `sleep infinity`, never exits) before `cline` is ever touched; the real invocation carries `-i --no-tools` as literal adjacent tokens and `--provider "$CLINE_PROVIDER" --model "$CLINE_MODEL"` as full names (no `-P`, no `-m $CLINE_MODEL`).
- All five files pass `bash -n`; every grep/awk assertion in the plan's per-task `<verify>` blocks and the overall `<verification>` block passed, including the `min_lines` thresholds.
- Live stack undisturbed throughout: flashnext=46573, role-shim=75548, litellm=48525 unchanged before/after every task. `EXTRA_ALLOW_PATHS` confirmed empty. Zero `launchctl bootstrap` under `phase-05/`. Zero `cline` invocations (budget: 0, used: 0); one `kanban --version` sanity check only (permitted, read-only).

## Task Commits

Each task was committed atomically:

1. **Task 1: phase-05/services/config.env + wait_for_port.sh + wait_for_upstream.sh** - `1b6fd84` (feat)
2. **Task 2: phase-05/services/run_kanban_service.sh** - `dc6e8ba` (feat)
3. **Task 3: phase-05/services/run_telegram_service.sh** - `aa3b532` (feat)

**Plan metadata:** (this commit, following)

## Files Created/Modified
- `phase-05/services/config.env` - single source of truth for Phase 5 paths/labels/ports/timeouts
- `phase-05/services/wait_for_port.sh` - generic bounded TCP-connect primitive
- `phase-05/services/wait_for_upstream.sh` - 3-stage production readiness gate (TCP -> flashnext health -> litellm alias)
- `phase-05/services/run_kanban_service.sh` - kanban launchd wrapper: CWD-rule assertion -> readiness wait -> exec into run_sandboxed.sh
- `phase-05/services/run_telegram_service.sh` - telegram connector launchd wrapper: CWD-rule assertion -> empty-token idle branch -> readiness wait -> exec into run_sandboxed.sh

## Decisions Made
- Readiness target is flashnext itself (HTTP `/health`), not a bare TCP probe of litellm's port — see key-decisions above; this is the SVC-04 correctness question, documented as a load-bearing comment block in `config.env` and repeated in `wait_for_upstream.sh`'s header.
- Tail-of-loop pacing applies on any failed stage, not just stage 1's own internal wait — otherwise a stage-2/3 failure (listening-but-not-ready) would spin subprocesses for the entire timeout budget instead of the intended one-poll-per-interval cadence.
- `--provider`/`--model` long forms only on the `connect telegram` invocation; the one-shot prompt-mode `CLINE_COMMON_FLAGS` (`-P`/`-m`) must never be copied onto this surface.
- Several explanatory comments needed to reference literal strings that the plan's own grep-based verification bans as executable-looking substrings (`cline kanban`, `--auto-approve`, a trailing/isolated `-P`, `sleep infinity`). Each was reworded to preserve the explanation while breaking the exact substring/regex match — e.g. "NEVER launch kanban through cline's own launcher subcommand for it" instead of "NEVER invoke `cline kanban`", and "The literal /bin/sleep argument \"infinity\" is BANNED BY NAME" instead of "`sleep infinity` is BANNED BY NAME". No behavioral change, wording-only, same technique 02-01 used for its own kill/pkill comment collision.

## Deviations from Plan

None — plan executed exactly as written. All three tasks matched their `<action>` blocks; every `<verify>` assertion passed (after the wording-only comment fixes above, made before each task's commit, not as a post-commit patch).

## Issues Encountered

Four comment-wording collisions with the plan's own verification greps, all found and fixed before the relevant task's commit (not deviations from scope — the plan's own `<verify>` blocks specify these exact checks):
- Task 2: `grep -c 'cline kanban'` required 0; an explanatory header comment used the literal phrase. Reworded.
- Task 2: `grep -c 'exec .*run_sandboxed\.sh'` required exactly 1 (the real exec line); an explanatory comment about pid-preservation also matched the pattern (`exec -> run_sandboxed.sh's own exec ...`). Reworded.
- Task 2: the `$KANBAN_BIN`-only-on-the-sandboxed-line check flagged a comment that spelled out `$KANBAN_BIN` literally. Reworded to describe it without the `$`-prefixed token.
- Task 3: `-P` check (`grep -cE '(^|[[:space:]])-P([[:space:]]|$)'` required 0), `--auto-approve` check (required 0), and `sleep infinity` check (required 0) all initially matched explanatory prose quoting the exact banned strings/flags. Reworded (see Decisions Made above) without losing the underlying explanation.

All four were caught by running the plan's own verify commands locally before committing, not discovered by the checkpoint/review process.

## User Setup Required

None - no external service configuration required. This plan registers nothing; no plist installation, no `launchctl bootstrap`, no token injection.

## Next Phase Readiness
- `phase-05/services/{config.env,wait_for_port.sh,wait_for_upstream.sh,run_kanban_service.sh,run_telegram_service.sh}` are ready for a later plan (05-04/05-05 per the plan's own scope note) to reference as `ProgramArguments[1]` in the two staged plists.
- `phase-05/services/run_telegram_service.sh`'s empty-token injection recipe already names `phase-05/services/install_services.sh` and `phase-02/infra/restart_service.sh com.ohama.telegram-connect none` — the latter's portless restart path was generalized by the parallel 05-02 plan (`phase-02/infra/restart_service.sh` now accepts `<port|none>`), confirming the two sibling plans' interfaces line up without either having read the other's diff mid-flight.
- No blockers. Live pids (flashnext 46573, role-shim 75548, litellm 48525) unchanged; `EXTRA_ALLOW_PATHS` confirmed empty; `phase-01/`, `phase-03/`, `phase-04/` git diff empty. `phase-02/infra/restart_service.sh` shows as modified in `git status` only because the parallel 05-02 plan owns and edited it during this same session — this plan never touched it.

---
*Phase: 05-kanban-telegram-services*
*Completed: 2026-08-30*
