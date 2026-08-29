# Phase 2: 인프라 보정 - Research

**Researched:** 2026-08-30
**Domain:** macOS launchd service hardening for an already-live local-LLM stack (mlx_vlm.server + role-shim + litellm)
**Confidence:** HIGH

## Summary

This phase touches three already-running, `KeepAlive`d launchd services on this exact Mac. Every fact below was read directly off the machine (plists, installed package source, live process args, live logs, an existing backup/rollback toolkit) — nothing here is inferred from documentation or the requirement text.

The single highest-value unknown — whether `--max-num-seqs` is a real flag on the server this plist actually launches — is **resolved positively**. `mlx_vlm.server` (installed as `mlx-vlm==0.6.17` in `.venv-mlxvlm-new`) has `--max-num-seqs` in its own `--help` output and in its argparse source, and the source's own docstring describes exactly the queuing behavior the requirement and the roadmap's success criterion ask for: *"Maximum number of sequences decoded concurrently in the continuous batch. Requests beyond this wait in the queue (backpressure), bounding peak memory. Default: unbounded."* No flag-name substitution is needed — the requirement's assumption is correct.

The second finding changes the shape of INF-02: `litellm` is the *only* one of the three services actually exposed to the LAN today (`lsof` shows `TCP *:4000 LISTEN`; `mlx_vlm.server` is already `--host 127.0.0.1`; `role-shim` hardcodes `127.0.0.1` in its own Python source). And every current consumer of `litellm:4000` — Cline's `providers.json`, `~/.hermes/config.yaml`, `~/.openjarvis/config.toml`, `~/.claude/proxy.env` — already points at `localhost`/`127.0.0.1`, never a LAN IP, and none of them send a real API key (all use the placeholder `dummy`). That makes `--host 127.0.0.1` on the litellm plist the strictly lower-risk fix for INF-02: it changes zero consumer configs. `master_key` would require touching all four of those files to inject a real key or every one of them starts getting 401s — a materially bigger regression surface for the exact same INF-03 you're trying to protect.

Third, this machine already has a mature, three-generation-old operational pattern for exactly this kind of change: `~/local-llm-settings/` (a **mirror**, not a source — `sync.sh` copies **from** `~/Library/LaunchAgents/` **into** it, never the reverse) and a full backup/rollback playbook at `~/llm-system/backups/flashnext-ops-20260829-140905/MANIFEST.md` with a proven `launchctl bootout` → edit → `launchctl bootstrap` → `launchctl print` verify cycle, plus a `scripts/llm_services.sh` that encodes the house rule: **never `kill`, always `bootout`/`bootstrap`, never `load`/`unload`** (the script's own comment calls `load`/`unload` deprecated). Phase 2's plan should reuse this pattern rather than invent a new one.

**Primary recommendation:** Edit `~/Library/LaunchAgents/com.ohama.flashnext.plist` to add `--max-num-seqs 1` and `~/Library/LaunchAgents/com.ohama.litellm.plist` to add `--host 127.0.0.1`, restart both with `launchctl bootout` + `launchctl bootstrap` (never `kickstart`, which does not re-read a changed plist from disk), re-run `~/local-llm-settings/sync.sh` afterward so the mirror stays truthful, and verify with the concrete curl commands below — all before touching anything else, since Phase 5/6 depend on this being done first.

## Standard Stack

Not a library-selection phase — no new dependencies are introduced. The "stack" here is the exact runtime already installed and running:

### Core (verified on this machine)
| Component | Version / Path | Purpose | Evidence |
|---|---|---|---|
| `mlx_vlm.server` | `mlx-vlm==0.6.17`, `.venv-mlxvlm-new/bin/python3` | Serves `flashnext` on `:8000` | `find .../.venv-mlxvlm-new/.../mlx_vlm-0.6.17.dist-info` |
| `litellm` | `1.86.1`, `/Users/ohama/agent-stack/venv/bin/litellm` | OpenAI-compatible router on `:4000` | `litellm --version` |
| `role_shim.py` | hand-written, `/Users/ohama/llm-system/role_shim.py` | Normalizes `developer`/`system` roles between litellm and mlx_vlm on `:8011` | source read in full (below) |
| launchd | macOS 26.3 (Build 25D125), Darwin 25.3.0 | Process supervision for all three | `sw_vers` |
| bash | `/bin/bash` 3.2 (system default) | Any writer/verifier scripts | already documented in phase context |

### Alternatives Considered
| Instead of | Could use | Tradeoff |
|---|---|---|
| `--max-num-seqs` on mlx_vlm.server | An external request-queueing proxy in front of `:8000` | Server flag is native, zero new moving parts, already ships exactly this feature — don't hand-roll a queue |
| `--host 127.0.0.1` on litellm | `master_key` in litellm config | master_key requires updating 4 external consumer configs (all currently send `api_key: dummy`) and doesn't reduce LAN exposure surface — only adds a gate on top of it. Bind is the narrower, more direct fix and matches "not exposed on LAN" more literally than "exposed but gated" |

**No installation needed** — both flags are already present in the installed binaries; this phase is plist edits + service restarts only.

## Architecture Patterns

### Recommended approach: reuse the machine's existing backup→edit→restart→verify cycle

This exact cycle is already proven on this machine (used for the 2026-08-29 Flash-Next cutover, backed by `~/llm-system/backups/flashnext-ops-20260829-140905/MANIFEST.md`):

```
1. snapshot   — capture current plist + config state (this repo's own
                phase-01 pattern: idempotent writer + separate verifier,
                evidence to a timestamped results dir — reuse it)
2. edit       — modify ~/Library/LaunchAgents/*.plist directly (NOT the
                ~/local-llm-settings/ mirror — see Pitfall 1)
3. bootout    — launchctl bootout gui/$(id -u)/<label>
4. bootstrap  — launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist
5. verify     — launchctl print gui/$(id -u)/<label> | grep state
                + curl health checks (INF-03 regression, below)
6. sync       — ~/local-llm-settings/sync.sh   (updates the mirror + STATE.md,
                does NOT touch the live plist — direction is live→mirror only)
```

### Pattern: idempotent writer + separate verifier (established in Phase 1)
**What:** A script that applies the plist edit (safe to re-run, no-ops if already applied) and a *separate* script that only checks/asserts state, producing evidence in a timestamped results directory.
**When to use:** Any change to the protected services in this phase — matches the STATE.md-documented Phase 1 convention and gives Phase 2 the same audit trail Phase 1 has (`phase-01/results/<timestamp>/`).
**Example (writer, idempotent plist patch):**
```bash
#!/bin/bash
# add_max_num_seqs.sh — idempotent
PLIST=~/Library/LaunchAgents/com.ohama.flashnext.plist
VALUE="${MAX_NUM_SEQS:-1}"
if /usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$PLIST" | grep -q -- "--max-num-seqs"; then
  echo "already present, skipping"
  exit 0
fi
# Insert as the last two array elements (order doesn't matter to argparse)
/usr/libexec/PlistBuddy -c "Add :ProgramArguments: string --max-num-seqs" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments: string $VALUE" "$PLIST"
plutil -lint "$PLIST"   # must print "OK" before restart
```

### Anti-Patterns to Avoid
- **Editing `~/local-llm-settings/launchagents/*.plist` and expecting it to take effect:** that directory is a read-only mirror populated *from* `~/Library/LaunchAgents/` by `sync.sh`. Editing it changes nothing live and the next `sync.sh` run will silently overwrite your edit back to whatever `~/Library/LaunchAgents/` has.
- **`kill -9` / `pkill` on the service PIDs:** all three plists have `KeepAlive: true`; `flashnext` additionally has `ThrottleInterval: 60`. A kill just gets relaunched with the *old* plist still in launchd's memory — it does not pick up your edit. Worse, it fights the supervisor and wastes the throttle window.
- **`launchctl load`/`unload`:** deprecated on this launchd generation; the machine's own `llm_services.sh` explicitly avoids them in favor of `bootout`/`bootstrap`.
- **`launchctl kickstart -k <label>` after editing the plist:** `kickstart` restarts the *already-loaded* job definition; it does not re-read the plist file from disk. Only `bootout` (fully unload) followed by `bootstrap` (reload from the file) picks up a `ProgramArguments` change. (`kickstart -k` is the right tool when the plist is unchanged and you only want to bounce the process — e.g., re-applying `iogpu.wired_limit_mb` after a reboot, per `CHANGE-20260829.md`.)

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Concurrency cap for mlx_vlm.server | A queueing reverse-proxy in front of `:8000` | `--max-num-seqs N` (native flag) | Already implemented server-side with exactly the semantics needed (`generation.py` line ~1718: "admit at most `capacity` new requests and leave the rest queued (backpressure)") |
| Backup/rollback of plist + config changes | A new backup script from scratch | The existing `MANIFEST.md`-style snapshot at `~/llm-system/backups/` + `scripts/llm_services.sh {snapshot,stop,start,verify}` | This exact pattern was used for a riskier change (the whole Flash-Next cutover) three days before this phase and is proven to work on this machine |
| Restart-then-confirm-healthy loop | A custom polling script | `launchctl print gui/$UID/<label>` (state/pid) + port-open polling, both patterns already in `llm_services.sh` (`cmd_start`/`cmd_verify`) | Re-implementing this is pure risk for zero benefit — the existing script already handles "loading takes a while" (`sleep` tuned per-service) and diffs old vs. new plist sha256 to catch accidental additional drift |

**Key insight:** This machine's operators (a prior session) already solved "how do I safely restart these exact services" and left the tooling and a full worked example behind. Phase 2's plan should point at and extend that tooling, not reinvent it — especially since `llm_services.sh`'s `SERVICES` array is now stale (still lists the retired `qwen122b`/`qwen36-35b`/`role-shim-35b`/`role-shim`→`:8001` topology from before the 2026-08-29 cutover) and will need a small update to reflect the current `flashnext`/`role-shim`→`:8000`/`litellm` topology if the plan wants to drive restarts through it.

## Common Pitfalls

### Pitfall 1: Editing the wrong copy of the plist
**What goes wrong:** `~/local-llm-settings/launchagents/com.ohama.flashnext.plist` and `~/Library/LaunchAgents/com.ohama.flashnext.plist` are byte-identical *right now* (verified via `diff`), which makes it easy to assume either is authoritative.
**Why it happens:** `sync.sh`'s own header comment even says the directory is "살아 있는 기준점" (a living baseline) — easy to misread as "the place you edit."
**How to avoid:** Always edit `~/Library/LaunchAgents/*.plist` (what launchd actually loads — confirmed via `launchctl print gui/501/com.ohama.flashnext` → `path = /Users/ohama/Library/LaunchAgents/com.ohama.flashnext.plist`). Run `~/local-llm-settings/sync.sh` *after* restarting, to pull the change into the mirror.
**Warning signs:** `sync.sh --check` reporting a diff after you thought you were done.

### Pitfall 2: `--max-num-seqs` caps concurrency, it does not fix the borderline-OOM-at-single-request problem
**What goes wrong:** Assuming this flag makes the 4.39 GB-headroom-at-32K situation fully safe.
**Why it happens:** There is direct log evidence in this exact deployment's `flashnext.err` of a **single, non-concurrent** request (`prompt_tokens=30505`, `in_flight=1`) failing with `[METAL] Command buffer execution failed: Insufficient Memory (kIOGPUCommandBufferCallbackErrorOutOfMemory)` on 2026-08-29 19:05:22 — no second concurrent request involved. That failure mode is orthogonal to what `--max-num-seqs` controls (it bounds *how many* generations run in the GPU's continuous batch at once; it does nothing about one generation being individually too large near the 32768 KV ceiling).
**How to avoid:** Scope INF-01's success test to *concurrency-induced* OOM (two simultaneous requests with small/medium prompts), not to re-proving the already-documented near-ceiling single-request OOM risk — that one is Phase 1's territory (`docs/32k-compaction-policy.md`, "restart the task"). Don't let the Phase 2 verification test send two concurrent ~30K-token requests; that would very plausibly reproduce a real crash rather than demonstrate queuing.
**Warning signs:** A verification curl pair both using large filler prompts near 32K each.

### Pitfall 3: Continuous batching already happens today — the demonstration must show a *behavior change*, not just "it worked"
**What goes wrong:** Sending 2 concurrent small requests today (before any change) already succeeds and even shows `in_flight=2` in the logs — this machine's own historical log (`flashnext.err`, 2026-08-29 15:32 and 16:24) shows exactly that, processed via `backend=continuous_batching` with no cap, no failure. If the "after" test also just shows 2 successful 200s, it proves nothing about queuing.
**Why it happens:** `max_num_seqs=None` (today's default, confirmed unbounded) already lets small concurrent requests interleave successfully in one batch — the risk is specifically *large* concurrent contexts, which is expensive/risky to test directly (Pitfall 2).
**How to avoid:** The queuing behavior is visible in the *timing*, not the status code: with `--max-num-seqs 1`, submit 2 concurrent small requests and compare each request's own `Generation queued` → `Decode started` gap (both logged with a timestamp/`time_to_first_token` in `flashnext.err`). Request A's gap should be near-instant; Request B's `Decode started` should not fire until Request A's generation finishes (visible as a multi-second gap plus B's log line appearing chronologically *after* A's `Request completed` line). Today (uncapped), both requests' `Decode started` lines appear back-to-back regardless of completion order — that contrast **is** the evidence, not the HTTP status.
**Warning signs:** A verification plan whose only pass/fail signal is "both curls returned 200."

### Pitfall 4: `litellm` binds `0.0.0.0` by default; the plist doesn't currently pass `--host` at all
**What goes wrong:** Assuming the config yaml controls binding — it doesn't; `--host`/`--port` are CLI/uvicorn-level, and litellm's own `--help` confirms `--host TEXT  Host for the server to listen on.` The current plist's `ProgramArguments` has no `--host`, so uvicorn's default (`0.0.0.0`) applies — confirmed live via `lsof`: `TCP *:4000 (LISTEN)`.
**Why it happens:** Natural to look in `config.yaml` first since that's where the model routing lives; binding is a separate concern entirely on the CLI invocation.
**How to avoid:** Add `--host` / `127.0.0.1` as two more `ProgramArguments` array entries in `com.ohama.litellm.plist`, same mechanism as the flashnext flag.
**Warning signs:** `curl` to the LAN IP still succeeding after only editing `config.yaml`.

### Pitfall 5: mlx_vlm.server + MTP drafter takes real time to become ready after a restart
**What goes wrong:** Verifying "is it back up" immediately after `bootstrap` and getting a false negative, or worse, sending the INF-03 regression curl into a model that's still loading (104 GiB of weights).
**Why it happens:** The 2026-08-29 cutover's own change log records "45초 만에 준비" (ready in 45s) for a cold load of this exact model+drafter combination — and that's the *good* case; under memory pressure it can be worse.
**How to avoid:** Poll `lsof -ti tcp:8000` (or `launchctl print .../com.ohama.flashnext | grep state`) until the port is open, then wait a further few seconds before firing the regression curl, or use a generous `curl --max-time` and treat a slow-but-200 response as pass rather than racing it. Don't hardcode a short sleep.
**Warning signs:** Regression curl returning connection-refused or a 500/502 in the first ~10s after restart.

### Pitfall 6: `sysctl iogpu.wired_limit_mb` is not plist state — don't worry about it for this phase, but don't touch it either
**What goes wrong:** Conflating "we're restarting flashnext" with "we need to redo the wired-limit sysctl dance."
**Why it happens:** `CHANGE-20260829.md` documents that this sysctl resets **on machine reboot**, not on a `bootout`/`bootstrap` service restart. A launchd service restart alone does not reset it.
**How to avoid:** Only re-check/re-apply `sudo sysctl iogpu.wired_limit_mb=118784` if the *machine* was rebooted during this phase's work, not merely because a service was bootout/bootstrapped. Verify current value with `sysctl -n iogpu.wired_limit_mb` (expect `118784`) before/after as a sanity check, but it is not part of what INF-01/INF-02 need to change.
**Warning signs:** None expected if the machine isn't rebooted mid-phase; flag as a blocker if `sysctl -n iogpu.wired_limit_mb` is ever found not to be `118784` when a flashnext restart is attempted (would mean a reboot happened and the model may fail to load).

## Code Examples

### Current, verbatim `com.ohama.flashnext.plist` `ProgramArguments` (before any edit)
```
/Users/ohama/projs/qwen38-flash-next-tests/.venv-mlxvlm-new/bin/python3
-m
mlx_vlm.server
--model
/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4
--host
127.0.0.1
--port
8000
--draft-model
/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MTP-drafter
--draft-kind
mtp
--max-kv-size
32768
--log-level
INFO
```
Also has `KeepAlive: true`, `RunAtLoad: true`, `ThrottleInterval: 60`, logs to `~/llm-system/services/logs/flashnext.{log,err}`.

### `--max-num-seqs` source of truth (mlx_vlm/server/cli.py, installed 0.6.17)
```python
parser.add_argument(
    "--max-num-seqs",
    type=int,
    default=None,
    help=(
        "Maximum number of sequences decoded concurrently in the continuous "
        "batch. Requests beyond this wait in the queue (backpressure), bounding "
        "peak memory. Default: unbounded. Maps to MLX_VLM_MAX_NUM_SEQS."
    ),
)
...
if args.max_num_seqs is not None:
    os.environ["MLX_VLM_MAX_NUM_SEQS"] = str(args.max_num_seqs)
```
And the admission logic (`mlx_vlm/server/generation.py`):
```python
def get_max_num_seqs():
    """Max sequences allowed in the running batch at once (None = unbounded)."""
    raw = os.environ.get("MLX_VLM_MAX_NUM_SEQS", "")
    ...
# in the GPU loop:
capacity = None if max_num_seqs is None else max(0, max_num_seqs - len(active))
new_items, should_stop = self._collect_pending_requests(
    active=active_batch, capacity=capacity, coalesce_s=coalesce_s,
)
```
`_collect_pending_requests`'s own docstring: *"When `capacity` is set, admit at most `capacity` new requests and leave the rest queued (backpressure), so the running batch never exceeds `--max-num-seqs` concurrent sequences."*

### Current, verbatim `com.ohama.litellm.plist` `ProgramArguments` (before any edit)
```
/Users/ohama/agent-stack/venv/bin/litellm
--config
/Users/ohama/agent-stack/litellm/config.yaml
--port
4000
```
No `--host` → uvicorn default `0.0.0.0`. Confirmed live: `lsof -nP -iTCP -sTCP:LISTEN` shows `TCP *:4000 (LISTEN)`. `config.yaml` has no `general_settings` block and no `master_key` anywhere.

### Restart cycle (verified command family for this launchd generation; matches `llm_services.sh`)
```bash
U=$(id -u)
LA=~/Library/LaunchAgents

# after editing $LA/com.ohama.flashnext.plist and/or $LA/com.ohama.litellm.plist:
plutil -lint "$LA/com.ohama.flashnext.plist"   # must say OK
plutil -lint "$LA/com.ohama.litellm.plist"     # must say OK

launchctl bootout   "gui/$U/com.ohama.flashnext"
launchctl bootstrap "gui/$U" "$LA/com.ohama.flashnext.plist"

launchctl bootout   "gui/$U/com.ohama.litellm"
launchctl bootstrap "gui/$U" "$LA/com.ohama.litellm.plist"

# verify both came back:
launchctl print "gui/$U/com.ohama.flashnext" | grep -E 'state|pid'
launchctl print "gui/$U/com.ohama.litellm"   | grep -E 'state|pid'

# resync the read-only mirror + regenerate its STATE.md:
~/local-llm-settings/sync.sh
```
Rollback (per the existing `MANIFEST.md` pattern, adapted to just these two files):
```bash
cp -p ~/Library/LaunchAgents/com.ohama.flashnext.plist{.bak,}   # restore from your own pre-edit copy
cp -p ~/Library/LaunchAgents/com.ohama.litellm.plist{.bak,}
launchctl bootout   gui/$(id -u)/com.ohama.flashnext
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ohama.flashnext.plist
launchctl bootout   gui/$(id -u)/com.ohama.litellm
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ohama.litellm.plist
```
(Take a `cp plist plist.bak` snapshot as the very first step of the writer script — the machine's `MANIFEST.md` full-stack backup is heavier machinery than a 2-file change needs, but the "snapshot before touching a live KeepAlive service" principle carries over.)

### INF-03 regression: cheapest end-to-end proof the `flashnext` alias still works
```bash
curl -s -m 120 -X POST http://localhost:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"flashnext","messages":[{"role":"user","content":"say hi"}],"max_tokens":8}' \
  -w '\nHTTP_STATUS:%{http_code}\n'
```
Expect `HTTP_STATUS:200` and a non-empty `choices[0].message.content`. Route exercised: `litellm:4000 → role-shim:8011 → mlx_vlm.server:8000`. A short prompt in fast mode (drafter on) should return in low single-digit seconds — the documented 64s TTFT applies to 32K-context deep-mode requests, not this test — but the `-m 120` timeout is kept generous anyway since the phase context flags this as a known slow-path concern.

### INF-02 regression: LAN rejection, reproducible with plain curl from the same machine
```bash
LAN_IP=$(ipconfig getifaddr en0)   # 192.168.75.108 at research time
curl -s -m 5 http://$LAN_IP:4000/v1/models
echo "exit: $?"   # expect curl exit 7 (connection refused) once --host 127.0.0.1 is applied
```
A bind-level restriction rejects by interface regardless of source, so this is testable from the same Mac without a second LAN host — no need to find another device to prove INF-02.

### INF-01 regression: queuing evidence via log timing (see Pitfall 3)
```bash
# after --max-num-seqs 1 is live and the service restarted:
( curl -s -m 60 http://localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
    -d '{"model":"/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4","messages":[{"role":"user","content":"count to 20 slowly"}],"max_tokens":60}' >/tmp/r1.json & )
sleep 0.3
( curl -s -m 60 http://localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
    -d '{"model":"/Users/ohama/projs/qwen38-flash-next-tests/models/Qwen3.8-Flash-Next-MLX-oQ4","messages":[{"role":"user","content":"count to 20 slowly"}],"max_tokens":60}' >/tmp/r2.json & )
wait
grep -E 'Generation queued|Decode started|Request completed' ~/llm-system/services/logs/flashnext.err | tail -8
```
Look for the second request's `Decode started` timestamp landing *after* the first's `Request completed` — that ordering is the queuing proof. (Hitting `:8000` directly, bypassing role-shim/litellm, is fine here since this test only exercises server-side admission, not the routing chain — INF-03 already covers the full chain separately.)

## State of the Art

Not applicable in the usual "library version drift" sense — but one internal-to-this-project fact matters: `~/projs/qwen38-flash-next-tests/scripts/llm_services.sh`'s `SERVICES` array is **stale** relative to the current topology. It still lists the pre-2026-08-29-cutover services (`qwen122b`, `qwen36-35b`, `role-shim-35b`, and `role-shim`→`:8001`) rather than the current `flashnext`(`:8000`)/`role-shim`(→`:8000`)/`litellm` topology. If the phase plan wants to drive restarts through this script rather than raw `launchctl` calls, the array needs a small update first (or the plan should just use raw `launchctl bootout`/`bootstrap` directly, which is simpler for a 2-service change anyway and is what this research recommends).

## Open Questions

1. **What `--max-num-seqs` value to ship (1 vs. 2+)?**
   - What we know: `1` most literally satisfies the roadmap's success criterion wording ("하나가 즉시 처리되고 다른 하나는 큐잉/지연" — one processed immediately, the other queued/delayed) and is the safest choice given only 4.39 GB headroom at 32K. The historical log shows 2 *small*-context concurrent requests already succeeding fine unbounded, so `1` does add latency for legitimate small concurrent use that was previously harmless.
   - What's unclear: whether the roadmap intends "cap at 1" (full serialization) or just "cap at *some* bounded number" (e.g., 2, still bounding worst-case memory below OOM while allowing today's harmless small-concurrent case to keep working).
   - Recommendation: default to `1` for the plan (matches the success-criteria wording most directly and is trivially provably-safe), but flag this as a one-line config choice the planner/user can override — it's an environment variable / single argv value, not an architecture decision.

2. **Exact peak-memory cost of `--max-num-seqs 2` at two concurrent near-32K requests was not empirically measured in this research** (deliberately avoided per Pitfall 2 — sending two real 30K+ prompts concurrently risks reproducing the documented OOM crash on a live, unattended-by-user service). If the plan wants a numeric memory bound at 2 concurrent large contexts, that measurement would need to happen in a controlled verification step with the user's awareness that it may crash the service (recoverable — `KeepAlive` respawns it — but will disrupt any in-flight session).

## Sources

### Primary (HIGH confidence — all direct, on-machine observation during this research session)
- `~/Library/LaunchAgents/com.ohama.flashnext.plist`, `com.ohama.litellm.plist`, `com.ohama.role-shim.plist` — read in full, verbatim
- `launchctl print gui/501/com.ohama.flashnext` — live state, confirms plist path launchd actually uses
- `lsof -nP -iTCP -sTCP:LISTEN` — live confirmation of `:8000`/`:8011` on 127.0.0.1, `:4000` on `*`
- `.venv-mlxvlm-new/bin/python3 -m mlx_vlm.server --help` and `mlx_vlm/server/cli.py` + `generation.py` source (mlx-vlm 0.6.17, installed dist-info confirms version)
- `/Users/ohama/agent-stack/venv/bin/litellm --help` and `--version` (1.86.1)
- `/Users/ohama/agent-stack/litellm/config.yaml` (the live config litellm actually loads, confirmed identical to the `~/local-llm-settings/` mirror via `diff`)
- `/Users/ohama/llm-system/role_shim.py` — full source, confirms hardcoded `127.0.0.1` bind
- `~/llm-system/services/logs/flashnext.err` — live log, including a real OOM crash line and real `in_flight=2` concurrent-request evidence
- `~/llm-system/backups/flashnext-ops-20260829-140905/MANIFEST.md` and `CHANGE-20260829.md` — this machine's own prior backup/rollback/cutover playbook for these same services
- `~/projs/qwen38-flash-next-tests/scripts/llm_services.sh` — this machine's own restart tooling, including its explicit "no kill, no load/unload" house rule
- `~/local-llm-settings/sync.sh` — confirms mirror direction (live → mirror, never the reverse)
- `~/.cline/data/settings/providers.json`, `~/.hermes/config.yaml`, `~/.openjarvis/config.toml`, `~/.claude/proxy.env` — all four confirmed to point at `localhost:4000`, none send a real API key
- `sw_vers` (macOS 26.3 / Darwin 25.3.0), `ipconfig getifaddr en0` (192.168.75.108)

No secondary or tertiary (web-sourced) claims were needed — every fact required for this phase was verifiable directly on the target machine.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — exact installed versions read directly, no assumptions
- Architecture (restart/rollback mechanics): HIGH — reused an existing, previously-executed playbook on this same machine for a strictly riskier change
- Pitfalls: HIGH — every pitfall is backed by either source code read directly or a live log line from this exact deployment, not general launchd/mlx_vlm folklore

**Research date:** 2026-08-30
**Valid until:** This research is tied to the exact installed versions and live config on this machine (mlx-vlm 0.6.17, litellm 1.86.1, the 2026-08-29 Flash-Next topology). It stays valid as long as none of those change before Phase 2 executes — reasonable to assume for a same-session or next-session follow-up; re-verify the plist/config diffs if significant time passes or if any of the three services is touched by unrelated work first.
