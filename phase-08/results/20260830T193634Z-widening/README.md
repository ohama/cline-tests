# 08-04 sandbox-widening decision run

**Decision: DECLINED** (see `DECISION.md` for the full record, first line `DECLINED`).

## What changed

Nothing. `phase-03/` is byte-identical to git HEAD before this plan ran (`no-change-proof.txt`
shows `git diff --stat phase-03/` empty). `EXTRA_ALLOW_PATHS` stays empty. `workspace/sandbox.sb`
was not regenerated with any new content. No service was restarted — the six live pids are
unchanged from before this plan (see `gates-pre/pids.txt`); no new kanban pid was recorded
because none was needed.

## Rollback

Not applicable — nothing to roll back. If a future decision reverses this and approves the
widening, `DECISION.md` contains the exact `render_profile()` diff, the `verify_sandbox.sh:167`
precheck move, and all four test-assertion breaks needed to do it without re-diagnosing.

## Pointers

- Full diagnosis: `.planning/phases/08-korean-user-manual/08-RESEARCH.md` §A6b (§A6b-0 has the
  reproduced-vs-inferred table; §A6b-2 the reproduction; §A6b-3 the SBPL finding; §A6b-4 the
  measured cost; §A6b-5 the exact would-be code change).
- Permanent record: `docs/sandbox-whitelist.md` §9.
- Handoff to 08-05: `phase-08/results/WORKTREE_STATUS` = `WORKTREE=UNAVAILABLE`.
