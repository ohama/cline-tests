---
phase: 06-network-exposure
verified: 2026-08-30T07:47:09Z
status: human_needed
score: 3/5 ROADMAP criteria met programmatically; 2/5 (criteria 1 and 5) correctly and honestly deferred to human verification by design
human_verification:
  - test: "On an iPad, open Safari to https://ohama-2.tail318f12.ts.net:8444/ over Tailscale (ohama100@ account), view the card list, open a card and scroll its diff."
    expected: "Board renders with no passcode prompt and no certificate warning; card list and diff are both legible and usable at iPad screen width."
    why_human: "Both registered iPads (ipad-mini-6th-gen-wifi, last seen 29 days ago; ipad165, last seen 4 days ago) are currently offline on the tailnet. Server-side reachability is proven (verify_network.sh CASES 24/24, live-reconfirmed by this verifier), but rendering/usability on actual iPad hardware has never been observed. Checklist: phase-06/IPAD-CHECKLIST.md."
  - test: "Send a request near the ~26,100-token compaction trigger and watch both surfaces during the ~64s prefill wait: (a) does the Kanban card stay in the In Progress column, (b) does Telegram show a persisting typing/working indicator."
    expected: "Kanban: card visibly stays in In Progress without erroring. Telegram: some working indicator is visible across the wait (uncertain by design -- see below)."
    why_human: "Kanban half has server-side proof only (byte-identical board response via loopback and tailnet, phase-06/results/20260830T071532Z-net05/board-fetch-both-paths.txt) -- visual confirmation is still human-only. Telegram half is static-evidence-only: exactly one non-looping sendChatAction('typing') call site in the 88MB binary, Telegram's own protocol expires typing after ~5s, and streaming starts only after prefill ends (~64s) -- this predicts the indicator will NOT survive the wait, but no one has watched a real client. The user explicitly declined a live-token trial in 06-05 (phase-06/results/20260830T071532Z-net05/decision.md). Do not accept any report that claims this was 'observed' prior to this trial actually running."
---

# Phase 6: Network Exposure Verification Report

**Phase Goal:** Tailscale 무인증 + LAN 토큰 게이팅으로, 처음으로 이 시스템을 이 Mac 의 셸 밖에서
접근 가능하게 연다. 포트 3000 에는 어떤 컴포넌트도 절대 바인딩하지 않는다.

**Verified:** 2026-08-30T07:47:09Z
**Status:** human_needed
**Re-verification:** No — initial verification

This report was produced by re-running every standing gate live (not by reading SUMMARY.md
claims), by reading the proxy source and the wrapper scripts directly, by inspecting live
`tailscale serve status --json` and `lsof` output myself, and by attempting to make the
network gate fail (it did, meaningfully, under an injected wrong expected value). All checks
below are dated 2026-08-30T07:4x UTC, this session, on the live system — not copied from prior
evidence directories, except where explicitly cited as historical evidence.

## Goal Achievement

### The single most important check: public exposure

Live `tailscale serve status --json`, captured by me:

```
AllowFunnel: { "ohama-2.tail318f12.ts.net:8443": true }   <- exactly one key, pre-existing, out of scope
Web:
  ohama-2.tail318f12.ts.net:443   -> http://127.0.0.1:8787   (pre-existing, byte-identical to expected_serve_baseline.json)
  ohama-2.tail318f12.ts.net:10000 -> http://127.0.0.1:8788   (pre-existing, byte-identical)
  ohama-2.tail318f12.ts.net:8443  -> http://127.0.0.1:3000   (pre-existing, byte-identical -- the public Funnel)
  ohama-2.tail318f12.ts.net:8444  -> http://127.0.0.1:18484  (the ONE new handler this phase added)
```

Diffed against `phase-06/net/expected_serve_baseline.json`: the three pre-existing `Web`
entries and the single `AllowFunnel` key are byte-identical. Exactly one new handler exists,
targeting the loopback proxy, not kanban directly and not any public-exposure mode.

`grep -rn "tailscale fun""nel" phase-06/net/*` (built as two concatenated strings to avoid
self-matching, same trick `verify_network.sh` check 14 uses) returns nothing anywhere under
`phase-06/net/` — the public-exposure subcommand is never invoked by anything this phase
shipped. `verify_network.sh` check 14 (`no-public-exposure-command-in-repo`) reconfirms this
on every run and PASSed live.

**Verdict: VERIFIED. No silent exposure.**

### Observable Truths (ROADMAP criteria 1-5)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | iPad Safari + Tailscale, card list + diff review works | human_needed | Server half proven live (see below); iPad half genuinely unrun — both iPads offline on tailnet |
| 2 | Same-LAN, no-token access to Kanban is refused | ✓ VERIFIED | LAN IP 192.168.75.108 confirmed live by me; historical curl rc=7 (connection refused) against 3484/8444/18484, reconfirmed by loopback-only lsof today |
| 3 | No project service ever binds port 3000 | ✓ VERIFIED | `lsof -nP -iTCP:3000` empty, run live by me; two independent standing gates (verify_network.sh, verify_services.sh) reconfirm every run |
| 4 | Telegram connector without `--allowed-user-id` fails to start immediately | ✓ VERIFIED | Wrapper-level guard read and confirmed live; historical launchd induced-failure evidence intact; docs state honestly this is the wrapper's guarantee, not cline's |
| 5 | "Working" state visible on both surfaces near 32K | human_needed | Kanban half proven server-side (byte-identical board both paths); Telegram half is static-evidence-only, user declined the live trial — correctly never upgraded to "observed" |

**Score: 3/5 truths programmatically VERIFIED; 2/5 correctly, honestly, and by explicit user
decision left as human_needed — not a defect, a designed and disclosed limitation.**

### Required Artifacts — checked directly, not via SUMMARY claims

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `phase-06/net/kanban_host_proxy.js` | Host/Origin-rewriting loopback proxy | ✓ VERIFIED | Read in full. `server.listen(PROXY_PORT_NUM, PROXY_HOST, ...)` passes explicit `127.0.0.1`; a startup guard independently refuses to run unless `KANBAN_PROXY_HOST === '127.0.0.1'`. `gate()` checks Host then Origin against allowlists and returns 403 **without ever calling `http.request`/`net.connect` upstream** for a rejected request, on both the plain-HTTP and WebSocket-upgrade code paths. |
| `phase-06/net/config.env` (`PROXY_ALLOWED_HOSTS`/`PROXY_ALLOWED_ORIGINS`) | Scoped allowlists | ✓ VERIFIED | Hosts: tailnet name with and without the Serve port, plus the proxy's own loopback identity (needed for the gate's own probes). Origins: the app's own tailnet-facing origin plus loopback. No wildcard, no LAN IP, no third-party domain — not too broad. Includes both bare-hostname and hostname:port forms to tolerate MagicDNS Host-header variance — not too narrow to break the iPad. |
| `phase-06/net/run_kanban_proxy_service.sh` | launchd wrapper, layer-2 loopback guard | ✓ VERIFIED | Independently re-asserts `KANBAN_PROXY_HOST == 127.0.0.1` before ever exec-ing node; exports both `*_NO_AUTO_UPDATE` pin vars; explicitly does NOT run under `run_sandboxed.sh` (documented reason checked, see below) |
| `docs/network-exposure.md` | Full phase record | ✓ VERIFIED | 219 lines. See honesty sweep below. |
| `phase-06/IPAD-CHECKLIST.md` | Standalone human checklist | ✓ VERIFIED | 94 lines. Explicitly warns against pre-writing expected NET-05 observations; explicitly frames NET-02's LAN check as "no response at all," not "an error page." |
| `phase-06/results/<UTC>-phase-close/criteria.md` | Five-criteria mapping | ✓ VERIFIED | See criteria.md review below. |
| `phase-06/net/verify_network.sh` | Standing 24-check gate | ✓ VERIFIED, re-run live | 24/24 PASS, this session. See gate section below. |

### Loopback-only bind — checked live, not from evidence files

```
lsof -nP -iTCP:3484   -> node 53894  127.0.0.1:3484 (LISTEN)   -- kanban, single listener, loopback only
lsof -nP -iTCP:18484  -> node 19669  127.0.0.1:18484 (LISTEN)  -- kanban-proxy, single listener, loopback only
lsof -nP -iTCP:3000   -> (empty)
lsof -nP -iTCP:8444   -> (empty -- Tailscale terminates TLS itself, no local listener expected)
```

No wildcard/LAN listener on either service. `verify_network.sh` checks 6/17 (`kanban-bind-loopback-only`,
`proxy-bind-loopback-only`) and 7/8/22 (LAN-refused checks) reconfirm this mechanically and all
PASSed live.

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `tailscale serve :8444` | `kanban-proxy 127.0.0.1:18484` | `tailscale serve` handler | ✓ WIRED | Confirmed in live `serve status --json`; `tailnet-https-200` and `tailnet-websocket-101` checks PASS live |
| `kanban-proxy` | `kanban 127.0.0.1:3484` | `http.request`/`net.connect` in `kanban_host_proxy.js`, after gate() passes | ✓ WIRED | Read directly in source; `proxy-rewrites-host` check PASS live (200, board markup, no "Host not allowed") |
| `kanban-proxy` gate | 403 rejection | in-process `gate()`, never forwards | ✓ WIRED | `proxy-rejects-unknown-host`/`proxy-rejects-unknown-origin` checks PASS live with exact expected JSON bodies |
| `run_telegram_service.sh` | `cline connect telegram` | `exec` guarded by `ALLOWED_ID` case statement | ✓ WIRED | Read directly: `case "$ALLOWED_ID" in ''|*[!0-9]*) ... exit 1 ;; esac` sits before the `exec` line, after the empty-token idle branch |

### Adversarial gate check: is `verify_network.sh` a rubber stamp?

No. Live run today: **CASES 24/24, PASS.** I then re-ran it with `EXPECTED_FUNNEL_KEY` overridden
to a bogus value (a read-only env override, no tailscale state touched) and it correctly
**FAILed (CASES 23/24)** on the `no-new-public-exposure` check with an accurate diagnostic message.
The gate can fail, and does, on a genuine negative input. Separately, checks 4/9/24 are
documented (and historically evidenced, `phase-06/results/20260830T060638Z-opening/gate-network/run1/`,
CASES 13/15) to fail for real when the network is actually closed or misrouted — this is not a
theoretical negative control, it already happened once during this phase's own development
(06-04's rollback).

### Standing gates — all re-run live by me this session

| Gate | Result |
|---|---|
| `phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline` | **CASES 24/24, PASS** |
| `phase-05/services/verify_services.sh` | **CASES 15/15, PASS** |
| `phase-02/infra/verify_no_regression.sh` | **INF03: PASS** |
| `phase-03/sandbox/verify_sandbox.sh` | **CASES 16/16, PASS** |
| `phase-01/config/verify_config.sh` | **OK** — providers.json flashnext@localhost:4000/v1, contextWindow=29000, compaction trigger 26100 proven live to fire |

### Requirements Coverage (NET-01..05)

| Requirement | Status | Note |
|---|---|---|
| NET-01 (Tailscale reachability, iPad) | Server half `met`, iPad half `human_needed` | Correctly not conflated — criteria.md cites 06-04.2's `20260830T070109Z-opening2` run (CASES 24/24) as the sole evidence source, and explicitly disclaims 06-04's rolled-back `CASES 13/15` run as NOT evidence. Confirmed by reading `06-04.2-SUMMARY.md` line 70 and `06-04-SUMMARY.md` line 69 directly — the timestamps and case counts match exactly what criteria.md and docs/network-exposure.md §4a claim. |
| NET-02 (LAN token gating) | `met`, via stronger "no LAN path" interpretation | Explicitly and correctly disclosed as an interpretation choice, not a literal token implementation, in both criteria.md and docs/network-exposure.md §4c. LAN unreachability confirmed at connection level against both 3484 and 18484 (and 8444), from LAN IP 192.168.75.108 (matches this Mac's live `en0` address, confirmed by me). |
| NET-03 (port 3000 unbound) | `met` | Verified live; two independent standing gates. |
| NET-04 (connector refuses without allowlist id) | `met`, wrapper-level guarantee | `run_telegram_service.sh` read directly: the guard fires before `cline` is ever exec'd. Docs (`docs/network-exposure.md` §4d) state plainly that cline 3.0.53 itself does NOT refuse without the flag (confirmed live per 06-RESEARCH.md Pattern 4, referenced honestly rather than hidden) — the guarantee is the wrapper's alone. |
| NET-05 ("working" indicator visible) | Kanban half `met` (server proof), Telegram half `human_needed`, correctly never upgraded | criteria.md and docs §4b both state the Telegram evidence is static/probabilistic only ("확률적으로는 아닐 것이지만, 관측된 적은 없다") and record the user's explicit decline of the live-token trial (`phase-06/results/20260830T071532Z-net05/decision.md`). No wording anywhere implies the typing indicator was actually watched. |

### Honesty sweep of `docs/network-exposure.md` (219 lines, read in full)

All required topics present and accurately stated:
- **§3c** — port 3000's danger explained: a pre-existing, out-of-scope, still-live public Funnel
  forwards `:8443 -> 127.0.0.1:3000`; anything binding 3000 becomes world-reachable with no
  Tailscale login. Matches what I independently found in live `serve status --json`.
- **§4c** — NET-02 interpretation stated as a deliberate strength-substitution ("no LAN path"
  instead of literal token), not hidden.
- **§4d** — NET-04's wrapper-vs-binary distinction stated in the sentence: "이건 CLI 의 보장이
  아니라 우리 래퍼의 보장이다."
- **§4b** — NET-05's Telegram half stated as unobserved, with the decline recorded and a note
  that no project document upgrades this to "confirmed."
- **§9** — the proxy's deliberate lack of sandboxing is explained (source unpunched under
  `sandbox.sb`; widening `EXTRA_ALLOW_PATHS` is forbidden and stays empty) and independently
  confirmed by me reading `workspace/sandbox.sb` directly (only `workspace/scratch-repo` and
  `~/.cline` are punched; `phase-06/net/` is not).
- **§9** — the `--no-tools`/read-only posture for both surfaces is stated, with an explicit
  warning that reversing it is a human-only, non-silent decision (HLS-02).
- **§9** — the `~/.gitconfig` sandbox-denial finding is recorded and flagged for Phase 7/8,
  not buried. I independently confirmed the underlying reproduction
  (`phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt`): `git` calls
  inside the live kanban sandbox fail with `fatal: unable to access '/Users/ohama/.gitconfig':
  Operation not permitted`, exit 128, because `~/.gitconfig` is outside `sandbox.sb`'s allow
  list. This blocks registering any git-backed project in kanban and is correctly attributed
  to Phase 3's sandbox ownership, not fixed here (correct call — fixing it would mean widening
  the sandbox allowlist, an architecture-boundary change out of this phase's scope).

### No collateral damage — checked live

- `EXTRA_ALLOW_PATHS`: empty in `phase-03/sandbox/config.env` default and not overridden in the
  live environment; `verify_services.sh`'s `sandbox-boundary-empty-allow-paths` check PASSed live.
- Six pids, checked live via `ps -p`, all alive and matching their expected commands:
  flashnext 46573 (mlx_vlm.server venv), role-shim 75548 (agent-stack venv), litellm 48525
  (agent-stack venv), kanban 53894 (node), telegram-connect 99162 (bash), kanban-proxy 19669
  (node).
- `git log --oneline -- phase-02 phase-03 phase-04 phase-05` for the phase-6 commit window shows
  exactly three commits touching phase-05, and none touching phase-02/03/04:
  `b8659aa` (`run_telegram_service.sh` guard + `com.ohama.telegram-connect.plist`),
  `3c50158` (additive `phase-05/services/config.env` constants for the proxy's identity),
  `fae7e3b` (`com.ohama.kanban-proxy.plist` + additive branch in `install_services.sh`).
  All three are the intended, disclosed changes; nothing else in phase-02/03/04/05 was touched.
- `git status --short` shows only new untracked results directories, no modified tracked files
  outside what the commit log above already accounts for.

## Gaps Summary

There are no structural gaps. Every artifact this phase claims to have built exists, is
substantive, and is wired correctly; every standing gate passes live under adversarial
re-verification (including a successful attempt to make the network gate fail); the public
Funnel/AllowFunnel boundary is intact and unmodified; port 3000 is unbound and the reason is
documented; the proxy is loopback-only with in-process, non-forwarding rejection of unknown
Host/Origin; the NET-04 guard is the wrapper's, honestly documented as such; the LAN-unreachability
evidence for NET-02 is positive and connection-level against both services; and the one known
pre-existing defect this phase surfaced (`~/.gitconfig` sandbox denial) is recorded and correctly
handed to Phase 7/8 rather than silently absorbed or silently fixed out of scope.

The only two open items — ROADMAP criteria 1 and 5 — are open by design and by an explicit user
decision (both iPads offline; user declined a live Telegram token trial), and every document in
this phase is scrupulously honest about that rather than overclaiming. `criteria.md` marks
exactly these two `human_needed` and nothing else.

## Why this is scored `human_needed`, not `passed`

Every automatable check in this phase passes, and passes under genuine adversarial pressure, not
just a friendly re-read of SUMMARY.md claims. If this were an internal/infrastructure phase where
criteria 1 and 5 were incidental polish, `passed` (with two items flagged for optional human
confirmation) would be the right call.

It is not. Criteria 1 and 5 are two of the five literal ROADMAP success criteria, and they are
the ones that actually constitute "이 시스템을 이 Mac 의 셸 밖에서 접근 가능하게 연다" from a
human's point of view — the goal is not "the server answers HTTPS on the tailnet" (proven), it is
"a human, on an iPad, can review a diff" and "a human, waiting on a long request, can see it's
still working." Neither of those has ever actually happened. The server-side infrastructure that
would make them possible is proven solid, and the phase's own documentation is unusually careful
never to claim more than that — but the goal's user-facing half is still an open, unexecuted
question, not a rubber-stamped formality. Calling this `passed` would blur exactly the line this
phase's own authors were careful to draw. `human_needed` is the honest status, and the two
required human actions are listed above with checklists already prepared
(`phase-06/IPAD-CHECKLIST.md`, `phase-06/results/20260830T071532Z-net05/decision.md`).

---
*Verified: 2026-08-30T07:47:09Z*
*Verifier: Claude (gsd-verifier)*
