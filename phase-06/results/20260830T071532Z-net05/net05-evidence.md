# NET-05 Evidence — Kanban status surface + Telegram open question

Captured: 2026-08-30T07:19:43Z, plan 06-05 Task 1.

## A. Kanban status surface (server-side half of NET-05)

### A1. `kanban task list --column in_progress` — exit code and root cause

Ground-truth result, current live state (`$RD/kanban-list-column-inprogress.txt`):

```
$ kanban task list --project-path workspace/scratch-repo --column in_progress
{
  "ok": false,
  "error": "Task command failed at http://127.0.0.1:3484: Project /Users/ohama/projs/cline-tests/workspace/scratch-repo is not added to Kanban yet."
}
EXIT=1
```

**This is exit 1, not exit 0 as the plan assumed.** Full diagnosis, honestly, rather than forcing
a green result:

- The CLI resolves `--project-path` to a git root and asks the running kanban server (pid 53894)
  whether that repo is a *registered* Kanban workspace. `~/.cline/kanban/workspaces/index.json`
  (this project's global, out-of-repo kanban state, not touched by any prior phase) has
  `"entries": {}` — **no project has ever been registered with this kanban install**, in any
  phase, before this task ran.
- We attempted the one available registration path, `kanban task create` (creates one backlog
  task and, as a side effect, registers the workspace). This surfaced a second, *separate*,
  pre-existing gap: `workspace/scratch-repo` is not its own git repository (its git-root search
  escapes to the outer `cline-tests` repo — this is Phase 5's already-documented Pitfall 6,
  `.planning/STATE.md` 05-04 section, deferred with the exact one-line fix noted: `git init`
  inside `scratch-repo`).
- We tried that one-line fix (`git init` + one commit, entirely inside the gitignored
  `workspace/scratch-repo/` — confirmed via `git status --porcelain workspace/` before and after,
  zero effect on the outer repo). `kanban task create` then got further, but failed at a THIRD,
  deeper layer: the live kanban **server**'s own sandboxed environment (it runs under
  `phase-03/sandbox/run_sandboxed.sh`) denies `~/.gitconfig`, and this git version refuses even
  `git rev-parse --is-inside-work-tree` without touching it:
  ```
  $ bash phase-03/sandbox/run_sandboxed.sh -- git -C .../workspace/scratch-repo rev-parse --is-inside-work-tree
  resolved allow list: ['/Users/ohama/projs/cline-tests/workspace/scratch-repo', '/Users/ohama/.cline']
  fatal: unable to access '/Users/ohama/.gitconfig': Operation not permitted
  exit=128
  ```
  (full transcript: `$RD/kanban-registration-blocker.txt`). This is systemic, not
  path-specific — `~/.gitconfig` sits under `/Users/ohama`, which `workspace/sandbox.sb` denies
  file-read on except two whitelisted subpaths, so **no** git-backed project can ever be
  registered through the currently-running, sandboxed kanban server, regardless of which repo
  path is offered.
- Fixing this for real means either loosening the sandbox's file-read allowlist (a Phase-3-owned,
  hardened security boundary — this whole project has treated widening it as a decision, not a
  drive-by fix) or restarting the live kanban service with a different `GIT_CONFIG_GLOBAL`. Both
  are outside this plan's declared scope (`files_modified: phase-06/results/` only) and outside
  its house rules (no plist/service changes in this plan). **Not fixed — documented instead,**
  per Rule 4 (architectural/security-boundary change, not a local blocking-issue fix).
- **Cleanup:** the partial registration side-effect (`kanban task create`'s client-side
  `~/.cline/kanban/workspaces/index.json` write, which had succeeded locally even though the
  server-side mutation failed, leaving an orphaned `scratch-repo` entry the live server didn't
  recognize — confirmed by a second query returning `"Unknown workspace ID: scratch-repo"`) was
  reverted byte-for-byte back to `{"version":1,"entries":{},"repoPathToId":{}}`
  (`$RD/kanban-workspaces-index-BEFORE-restore.json` /
  `-AFTER-restore.json`, diffed against pristine equal). The `git init` inside
  `workspace/scratch-repo` was also reverted (`.git` removed) so this task leaves **zero net
  footprint** anywhere outside `phase-06/results/`, matching its "read-only work only"
  instruction in spirit even though the registration attempt itself was a write.

**What this exit-1 result still proves, honestly:** the surface exists and answers coherently —
a real HTTP round-trip to the running kanban server, a real, well-formed JSON error (not a
crash, not a hang, not a malformed response), naming the exact reason it can't list yet. It does
**not** prove the literal "exit 0 with a possibly empty list" shape the plan assumed, because
this kanban install has never had a project registered with it in this project's history, and
registering one hits a separate, Phase-3-scoped sandbox gap this plan does not fix. **This is a
genuine, new, tracked finding for Phase 8/handoff: kanban's CLI task-management surface cannot
register any project while the kanban service runs under the current sandbox profile.** It does
not affect NET-05 (Tailscale + Telegram) or any of this phase's other four criteria, and it does
not touch network posture at all.

### A2. Status column vocabulary (documented, agent-verifiable)

```
$ kanban task list --help
  --column <column>      Filter column: backlog | in_progress | review | done. trash is also accepted.
$ kanban task start --help
Start a task session and move task to in_progress.
```
(full output: `$RD/kanban-task-list-help.txt`, `$RD/kanban-task-start-help.txt`)

### A3. Board reachable, byte-for-byte the same board, over BOTH loopback and the tailnet URL

(`$RD/board-fetch-both-paths.txt`)

| Path | Status | First bytes |
|---|---|---|
| `http://127.0.0.1:3484/` | **200** | `<!doctype html>...<title>Kanban</title>...` |
| `https://ohama-2.tail318f12.ts.net:8444/` | **200** | `<!doctype html>...<title>Kanban</title>...` (identical markup) |

Both responses are byte-identical in their captured prefix. This is the same live board,
reachable from a tailnet-authenticated client exactly as it is from the Mac itself.

### A4. What this section proves and does not prove

- **PROVEN:** the Kanban HTTP surface exists, answers 200 with real board markup on both
  loopback and the tailnet address, and its CLI task-management surface responds coherently
  (if not with the exact literal exit-0 shape assumed) — `human_needed` is NOT required for
  "does this surface exist and respond."
- **NOT PROVEN, `human_needed`:** what a human actually SEES on an iPad during a real 64-second
  wait — whether the card visibly sits in "In Progress" without looking stalled/red/errored.
  That is criterion 5's remaining half, and no amount of server-side curl output can substitute
  for an actual screen observation. See the iPad checklist in `06-RESEARCH.md` (§"iPad
  Verification Checklist").

## B. Telegram side — recorded, not asserted

### B1. Static evidence, copied verbatim from `06-RESEARCH.md`

> Disassembling the compiled `cline` binary found exactly **one** call site for the Telegram
> typing indicator (`sendChatAction` action `"typing"`), fired once when a message is received,
> with no periodic refresh loop anywhere in the 88MB binary. Telegram's own protocol lets a
> typing indicator decay after ~5 seconds. There is no placeholder "thinking…" message and no
> evidence of a resend loop.
>
> ```js
> // found once, single call site, inside the Telegram provider class:
> async startTyping($) {
>   let J = this.resolveThreadId($);
>   await this.telegramFetch("sendChatAction", {
>     chat_id: J.chatId,
>     message_thread_id: J.messageThreadId,
>     action: "typing"
>   });
> }
> // only invocation site, fired on incoming private message, fire-and-forget:
> startTypingForPrivateMessage($, J, Y) {
>   if ($.chat.type !== "private" || $.from?.is_bot) return;
>   let X = this.startTyping(J).catch((Z) => {
>     this.logger.warn("Failed to send Telegram typing action", {...});
>   });
>   Y?.waitUntil?.(X);
> }
> ```
>
> A separate `stream()` method exists that incrementally edits a Telegram message via
> `sendRichMessageDraft` as tokens arrive — but this only fires once actual output tokens exist
> to stream, which is *after* the prefill/compaction wait NET-05 is actually asking about, so it
> does not help for the two specific waits named in the requirement.

The ~64s prefill figure and the corrected compaction finding (`settings.contextWindow` is a
TOP-LEVEL field, 29000, trigger 26100, ×0.9 once — compaction WORKS) are both from
`docs/32k-compaction-policy.md` §§2-3 and are restated here only as context for why a
64-second-class wait is the realistic case being asked about; this task made zero new `cline`
invocations to re-derive them (mining existing docs/captures per the plan's own instruction,
not spending budget).

### B2. Current live state of the Telegram service (`$RD/telegram-current-state.txt`)

- `pgrep -f 'connect telegram' | wc -l` → **0** (inert, as expected)
- `~/.cline/logs/telegram-connect.log` tail → empty (nothing has ever run through the real
  invocation path)
- `~/.cline/logs/telegram-connect.err` tail → the expected steady-state idle banner
  (`TELEGRAM_BOT_TOKEN is empty ... intentionally INERT`) interleaved with historical
  `ABORT-NET04` lines from 06-02's own standalone proof runs (pre-existing, not new)
- Both the staged plist (`phase-05/plists/com.ohama.telegram-connect.plist`) and the live
  installed plist (`~/Library/LaunchAgents/com.ohama.telegram-connect.plist`) still carry a
  real, present, EMPTY `<string></string>` for `TELEGRAM_BOT_TOKEN`. Nothing about this task
  changed either plist.

### B3. Standing hazard, carried forward from Phase 5/06-RESEARCH

The token-present code path (`exec "$CLINE_BIN" connect telegram -k "$TOKEN" -i --no-tools
--provider ... --model ... --cwd ...`) has **never been executed in this project.** The
empty-token idle branch has masked it through the whole of Phase 5 and Phase 6 so far. The first
real launch with a real token may fail immediately on an argv parsing error (the exact class of
bug `06-RESEARCH.md` and `docs/services.md` §6 both flag: `-P`/`-m` ambiguity, full-name-only
`--provider`/`--model`). That first launch must be watched for it if the trial is approved.

### B4. Open question — not asserted either way

**Whether the Telegram typing indicator (or anything else) stays visible through a genuine
~64-second prefill wait or a compaction-triggered summary call is unknown.** What is known: one
non-repeating typing call, fired once, ~5s protocol decay, no resend loop, no placeholder
message found anywhere in the 88MB binary. What is unknown: whether some other layer (the RPC
hub, not the per-provider connector code that was grepped) independently re-pings typing, or
whether Telegram's client-side behavior holds "typing…" visible longer than the nominal 5s in
practice. **This document does not say the indicator is sufficient. This document does not say
the indicator is insufficient.** Resolving it requires a real, token-backed trial — see Task 2.

## C. NET-05 status table

| Half | Status | Evidence |
|---|---|---|
| Kanban status surface exists and answers (loopback + tailnet) | **Proven server-side** | §A1, §A3 (both 200, byte-identical board markup); CLI answers coherently even where exit code differs from the plan's assumption |
| Kanban board visually shows "in progress" without looking stalled, on an actual iPad, during a real long wait | **`human_needed`** | `06-RESEARCH.md` iPad checklist step 3/5 — not something any agent-side curl can substitute for |
| Telegram typing indicator survives a ~64s prefill/compaction wait | **Open question, requires a live trial** | §B1-B4; resolved only by Task 2's decision |
| Telegram conversation visually shows "작업 중" during a real long wait, on an actual device | **`human_needed`** (regardless of the Task 2 decision — visual confirmation is never agent-fabricable) | `06-RESEARCH.md` iPad checklist step 5 |
