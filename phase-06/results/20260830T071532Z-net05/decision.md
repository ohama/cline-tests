# 06-05 Task 2 checkpoint decision — recorded verbatim

**Recorded:** 2026-08-30T07:23:55Z (checkpoint answered after Task 1 completed under commit `ef8db88`)

## The question put to the user

Task 2 asked whether to run the project's first real-token Telegram trial — one live
`cline connect telegram` session with a REAL BotFather token — in order to observe what a
Telegram client actually shows during a ~64-second prefill wait and during a compaction pause.
Both options (`decline` default / `approve`) and their full risk statements were presented as
written in `06-05-PLAN.md` Task 2.

## The user's answer, verbatim

> **The user selected `decline`.** No real-token Telegram trial.
>
> - Do NOT inject, request, generate, or fabricate a Telegram bot token. The slot stays EMPTY.
> - Do NOT start a live bot. The telegram-connect service stays inert.
> - Record NET-05's Telegram half honestly as `human_needed`, in the same spirit as Phase 5's
>   reboot-persistence gap: state what the static evidence shows (exactly one non-repeating
>   `sendChatAction("typing")` call site in the pinned cline 3.0.53 binary, fired once per
>   incoming message; Telegram decays typing after ~5s; no resend loop or placeholder message
>   anywhere in the binary; message streaming only engages once output tokens exist, i.e. after
>   the ~64s prefill wait). State plainly that this means the indicator **probably** does not
>   survive the wait — but that it was NOT observed, and must not be written as though it were.
> - Leave a concrete checklist item so the user can resolve it themselves later if they choose,
>   alongside the iPad checklist.

## What was accepted

Nothing new was accepted. The user declined the one genuine escalation this phase offered. No
BotFather token was requested, generated, or fabricated. No live bot was started. The
telegram-connect service (pid namespace, not a live process — it is currently inert, 0 running
connector processes) remains exactly as Phase 5 and 06-02 left it: registered, guarded by the
NET-04 preflight, and idle on an explicitly-empty `TELEGRAM_BOT_TOKEN`.

## What remains unproven

- **Whether the Telegram typing indicator (or any other client-visible signal) survives a real
  ~64-second prefill wait or a compaction-triggered summary call.** This was, and remains,
  genuinely unknown. The static evidence (§B1-B4 of `net05-evidence.md`) supports a *reasoned
  expectation* — one non-repeating `sendChatAction("typing")` call, fired once per incoming
  message, with Telegram's own protocol decaying a typing indicator after roughly 5 seconds, no
  resend loop anywhere in the 88MB binary, and the rich-draft streaming path only engaging once
  output tokens exist (i.e. strictly *after* the wait in question) — so it is **probable, but
  not observed,** that the indicator does not stay visible through the wait. This document
  states that probability plainly and stops there. It does not, and must not, claim the
  indicator was watched and found absent. No agent ever ran the trial; no human ever watched a
  Telegram client during a live wait; nothing about the actual client-rendered behavior was
  observed by anyone in this project.
- What a human sees on the Kanban board (iPad Safari, "In Progress" column) during the same
  kind of wait — this was already `human_needed` per Task 1 regardless of the Task 2 decision,
  and is unaffected by `decline`.

## NET-05 status, both halves, after this decision

| Half | Status | Why |
|---|---|---|
| Kanban status surface exists/answers (server-side) | proven | Task 1, `net05-evidence.md` §A |
| Kanban "In Progress" visually holds during a real long wait (iPad) | `human_needed` | Task 1 §A4 — unaffected by this decision |
| Telegram typing indicator survives a ~64s prefill/compaction wait | **open question — probable-not, but unobserved** | This decision; static evidence only, per §B1-B4 above |
| Telegram conversation visually shows "작업 중" during a real long wait (device) | `human_needed` | Task 1 §C — unaffected by this decision; no client-side evidence is ever agent-fabricable |

**Both NET-05 halves remain `human_needed`.** The Telegram half is additionally an open
research question (probable expectation stated, nothing observed); the Kanban half was already
`human_needed` before this checkpoint and stays so.

## Checklist item for later, if the user chooses to resolve this themselves

This is left here as a standalone, concrete checklist item independent of `06-06`'s formal
iPad checklist (which will also carry a pointer to this same open question in its item 4b):

1. Obtain a bot token from **@BotFather** on Telegram (issue a new bot, or reuse an existing
   test bot — never share a token used for anything else).
2. Get your own **numeric** Telegram user id (e.g. via **@userinfobot**) — the NET-04 guard
   added in 06-02 requires this and will refuse to start without it.
3. Set BOTH `TELEGRAM_BOT_TOKEN` and `TELEGRAM_ALLOWED_USER_ID` in
   `phase-05/plists/com.ohama.telegram-connect.plist`'s `EnvironmentVariables` dict (or hand
   them to an agent to inject into the *live* plist only, per `docs/services.md` §6 — never
   commit a real token).
4. Run `bash phase-05/services/install_services.sh com.ohama.telegram-connect` then
   `bash phase-02/infra/restart_service.sh com.ohama.telegram-connect none`.
5. **Watch `~/.cline/logs/telegram-connect.err` on the first launch** for an argv parsing
   error — the token-present code path has never been executed in this project, so this is a
   known, expected possibility, not a surprise (see `net05-evidence.md` §B3).
6. Send the bot a private message long enough to approach the 26,100-token compaction trigger
   (`settings.contextWindow` is 29000 — do NOT reuse 32768/26542 assumptions) and watch the
   Telegram app at roughly t=10s, t=30s and t=64s. Report — do not assume — what is and is not
   visible at each mark.
7. Afterwards, either leave the service live with the token in place (and update
   `~/local-llm-settings/sync.sh` handling explicitly, since the live plist would then diverge
   from the staged one and carry a secret) or clear the token and restart from the staged plist
   to return to the inert steady state. Confirm `verify_services.sh` 15/15 either way.

## Confirmation this decision changed nothing about the system

- `pgrep -f 'connect telegram' | wc -l` → confirmed 0 below (see `decision-verification.txt`)
- Token slot: still an explicit, present, EMPTY `<string></string>` in both the staged
  (`phase-05/plists/com.ohama.telegram-connect.plist`) and live installed plists — unchanged
  from Task 1's B2 observation, re-confirmed here.
- No `cline` invocation was made for this task or this decision. Phase 6's cumulative `cline`
  budget usage stands at 0 for this plan.
- `git diff --stat phase-05/plists/` — confirmed empty below.
