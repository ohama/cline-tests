# 05-06 Task 1 — SVC-05: track both labels in sync.sh and mirror the plists

`~/local-llm-settings/sync.sh` mirrors only the labels named in a hardcoded bash `LABELS=(...)`
array — it does NOT glob `~/Library/LaunchAgents/*.plist`. Before this task, `com.ohama.kanban`
and `com.ohama.telegram-connect` were absent from that array, so `./sync.sh --check` reported
agreement (`✅ 실제 시스템과 일치한다`, exit 0) while two brand-new live plists sat completely
untracked — a vacuous pass of the same shape this project has already had to design around twice
(`check_versions.sh` Check C in 05-02, `verify_no_regression.sh` in Phase 2). `synccheck-before.txt`
captures that vacuous pass as measured fact, not a hypothetical.

## What changed, and why here

`sync.sh` lives at `~/local-llm-settings/sync.sh`, **outside this repo's git history**. This
directory's README is the only place the edit is captured for a future reader of this repo —
`git log` here will never show it.

`sync.sh.before` / `sync.sh.after` / `sync.sh.diff` are the before-copy, after-copy, and unified
diff. The diff touches exactly two spots, both purely additive:

1. `LABELS=(...)` gains `com.ohama.kanban com.ohama.telegram-connect` as a new continuation line,
   keeping the array's existing formatting/line-continuation style.
2. The STATE.md port-row list (also a hardcoded array inside the same script) gains one new row,
   `"3484:Kanban (launchd com.ohama.kanban)"`, appended after the existing rows — nothing removed
   or reordered.

Nothing else in the file changed. `bash -n` on the edited file passed before it was run for real.

## Live → mirror, the only sanctioned direction

`sync.sh` (no arguments) was run once (`sync-run.txt`): it reported updating exactly
`launchagents/com.ohama.kanban.plist` and `launchagents/com.ohama.telegram-connect.plist` — the
two intended plists and nothing else. `~/local-llm-settings/launchagents/` itself was never
hand-edited; only `sync.sh`'s own copy step wrote there.

## Post-sync verification

- `cmp` of both new mirrored plists against their live `~/Library/LaunchAgents/` counterparts:
  byte-identical (both exit 0).
- `./sync.sh --check` now exits 0 with `✅ 실제 시스템과 일치한다` (`synccheck-after.txt`) — the
  vacuous-pass failure mode is closed because both labels are now actually tracked, not because
  the check got weaker.
- Regenerated `~/local-llm-settings/STATE.md` (`mirror-state-md.txt`): both new labels show
  `running`/`✅ 자동`, and the new `3484` port row shows a live listener (`✅`).

## Pre-existing mirror drift (not introduced by this task)

`mirror-git-status-before.txt` and `mirror-git-status-after.txt` both show `~/local-llm-settings`
(a separate git repo, the user's, not ours) already carrying uncommitted modifications to
`SHA256SUMS`, `STATE.md`, `launchagents/com.ohama.flashnext.plist`, and
`launchagents/com.ohama.litellm.plist` — content that a prior `sync.sh` run (Phase 2's INF-03,
per `docs/infra-hardening.md` §4) already copied into the mirror but that was never committed
inside that repo. This task did not create that drift and did not touch those four files beyond
what running `sync.sh` normally regenerates (`SHA256SUMS`/`STATE.md` are always rewritten on every
run). The *new* drift this task introduces is exactly: `sync.sh` itself (our edit) plus the two
newly-untracked plists (`com.ohama.kanban.plist`, `com.ohama.telegram-connect.plist`) — nothing
else changed shape between the before/after git-status captures.

Whether to commit inside `~/local-llm-settings`'s own git repo (either the pre-existing drift or
this task's new files) is the user's call, not this plan's — the mirror content itself was only
ever written by `sync.sh`, never hand-edited, and this repo's job is only to record that the edit
and the sync happened.
