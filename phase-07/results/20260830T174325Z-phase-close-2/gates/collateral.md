# Collateral-damage checklist (round 2, post-gap-closure)

Captured: 2026-08-30T17:5x Z (this Task 3 sweep), after all seven standing gates and the
anti-overclaim audit.

| # | Item | Result | Evidence |
| - | ---- | ------ | -------- |
| 1 | Six live pids unchanged | **PASS** | `flashnext` 46573, `role-shim` 75548, `litellm` 48525, `kanban` 53894, `telegram-connect` 99162, `kanban-proxy` 19669 — all alive, checked against `phase-07/bench/config.env`'s `LIVE_PIDS_STR`. |
| 2 | Port 3000 unbound | **PASS** | `lsof -nP -iTCP:3000 -sTCP:LISTEN` returns empty. |
| 3 | `EXTRA_ALLOW_PATHS` empty in every plist | **PASS** | `PlistBuddy -c "Print :EnvironmentVariables:EXTRA_ALLOW_PATHS"` against all 15 `com.ohama.*.plist` files in `~/Library/LaunchAgents/` — every one reports "Does Not Exist" (never set, consistent with "stays empty"). |
| 4 | `workspace/ALLOWED_REPOS.json` unchanged | **PASS** | `git status --short workspace/ALLOWED_REPOS.json` — no diff. Content still whitelists only `workspace/scratch-repo`; repo root and `bench/` remain excluded (per the file's own `_comment`). |
| 5 | `cat bench/runs/CANARY.txt` unchanged, `verify_sandbox.sh` `CRITERION 4 PASS` | **PASS** | Canary content: `SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX` (unchanged, `git status --short bench/runs/CANARY.txt` empty). `verify_sandbox.sh` this sweep: `CRITERION 4 (SBX-04 bench results dir unreadable from inside the sandbox): PASS P3=PASS P4=PASS CANARY-LEAK=PASS`, `CASES 16/16`, `CRASHED 0` (`gates/verify_sandbox.txt`). |
| 6 | Host `providers.json` content hash unchanged | **PASS** | `shasum -a 256 ~/.cline/data/settings/providers.json` = `fa43d153c0698dd832a2a196f04a5e283ed66690d3191b9dee06484c8de8e708`, byte-identical to the hash 07-09 recorded pre- and post-batch (`phase-07/results/20260830T170042Z-gap-batch/pre/providers-hash.txt`). |
| 7 | Host `cline` version recorded as-is (not repaired) | **PASS (recorded, not silently repaired)** | `/opt/homebrew/lib/node_modules/cline/package.json`: `"version": "3.0.60"` — unchanged from 07-06/07-09's captures. No `npm install -g` was run anywhere in this plan (banned by house rule). Recorded as a known open item in `criteria2.md` and `.planning/STATE.md`. |
| 8 | No lingering bench containers | **PASS** | `docker ps -a` lists 12 containers, none bench/harbor/injection-probe-related (`mhr-*`, `nextcloud-*`, `safestacktutorial-db-1`, `sandbox-egress-proxy` — all pre-existing, unrelated project containers). Consistent with 07-09's finding that harbor deletes each trial's own image/container after the trial. |
| 9 | No new `tailscale serve` entry beyond Phase 6's documented baseline | **PASS** | `tailscale serve status` shows exactly 4 entries: `:8443` (Funnel, pre-existing, not this project's), `:8444` (kanban-proxy, Phase 6 NET-03), `:10000` and the bare tailnet hostname (both pre-existing, not this project's — same as Phase 6's `expected_serve_baseline.json`). No mutating `tailscale`/`funnel`/`serve` command was run by this plan. Independently reconfirmed by `verify_network.sh --baseline "$NET_BASELINE"` → `CASES 24/24`, `CRASHED 0` this sweep (`gates/verify_network.txt`), which already covers this exact no-new-exposure check as one of its 24 cases. |

## Result

**9/9 collateral-damage items PASS.** No live service touched, no host posture change, no network
exposure change, no repair of the pre-existing host `cline` drift, no bench/harbor artifacts left
running.
