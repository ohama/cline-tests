# Phase 3: 샌드박스 + 저장소 화이트리스트 - Research

**Researched:** 2026-08-30
**Domain:** macOS Seatbelt (`sandbox-exec`) process sandboxing wrapped around the `cline` CLI agent core, generated from a single `ALLOWED_REPOS.json` whitelist
**Confidence:** HIGH on the sandbox-exec mechanics (every claim below was produced by actually running `sandbox-exec` on this exact host and reading real exit codes/stderr — nothing is recalled from docs). MEDIUM on the exact `cline` binary's behavior under the sandbox specifically (tested with representative stand-ins — `/bin/cat`, `/bin/sh`, plain `node` — not the literal `cline` Mach-O binary itself, for reasons explained below). LOW/flagged explicitly on cline-bench/Harbor's exact output-path flag (carried forward from prior project research, not re-verified here).

## Summary

This phase's own project-level research (`.planning/research/ARCHITECTURE.md` §5) already concluded, correctly, that Cline offers nothing that amounts to a real security boundary and that `sandbox-exec` wrapping the whole process is the only mechanism actually enforced by the kernel. This phase-level research does two things beyond that: (1) it **corrects two specific claims** made in the earlier project research by statically inspecting the actual installed `cline` binary, and (2) it **empirically proves or disproves** every mechanical assumption the plan will depend on, by building and running real Seatbelt profiles against real file trees on this exact machine (macOS 26.3, Darwin 25.3.0, `sandbox-exec` at `/usr/bin/sandbox-exec`).

**Correction 1 (important):** `CLINE_COMMAND_PERMISSIONS` — cited in `FEATURES.md`/`ARCHITECTURE.md` as a real "shell command allow/deny glob policy" env var, sourced from a WebSearch-derived doc summary — **does not exist anywhere in the installed `cline` 3.0.53/3.0.60 binary.** `strings` over the actual Mach-O executable at `/opt/homebrew/lib/node_modules/cline/bin/.cline` finds zero occurrences; the only match for the substring `COMMAND_PERMISSIONS` is `APPLICATION_COMMAND_PERMISSIONS_UPDATE`, a Discord.js gateway-intent constant bundled inside the binary, unrelated to Cline. `.clineignore` similarly does not exist as a string anywhere in the binary — zero occurrences. Do not design any part of this phase around either mechanism; they are not present in this CLI build (they may exist in the VS Code extension or a different/future version, but not here).

**Correction 2:** `CLINE_SANDBOX` / `CLINE_SANDBOX_DATA_DIR` **do** exist (confirmed live in the decompiled binary), but they only do what `--data-dir` already does per `STACK.md` — they isolate Cline's own **config/data storage location** (`providers.json`, session DB, logs). They have nothing to do with restricting which files the agent's tools can read/write, or which commands `execute_command` can run. The name is misleading; do not build SBX-02/SBX-03 around it.

**What actually holds, verified live:** `sandbox-exec` is present, functional (though its man page marks it `DEPRECATED`), and requires no special entitlement to invoke as a normal user on this host. A Seatbelt profile wrapping a process **does** intercept both (a) a Node/Bun process's own in-process `fs.readFileSync`/`writeFileSync` calls and (b) that same process's `child_process.execSync`-spawned subprocesses — both hit identical kernel syscalls and both were verified denied/allowed identically under one profile. This means **SBX-02 and SBX-03 genuinely collapse into one mechanism**, as ARCHITECTURE.md predicted, now with direct proof rather than a design bet.

The single most important pitfall discovered: a **profile that tries to `(deny default)` and allow-list only the specific paths a binary needs will crash the target process with SIGABRT and zero diagnostic output** the moment the dynamic linker can't read something it needs (found by direct reproduction). The viable, actually-testable pattern is the reverse — `(allow default)` as the base, with explicit `(deny file-read*/file-write* (subpath ...))` for the protected root (recommend `$HOME`) and `(allow file-read*/file-write* (subpath ...))` punch-throughs for each `ALLOWED_REPOS.json` entry. This was verified to correctly deny reads/writes outside the whitelist while leaving the binary itself fully able to run, including as a long-running process performing repeated fs operations over several seconds.

A second critical, concretely reproduced bug: **profile rules must be written using canonicalized (`realpath`'d) paths, not whatever form happens to appear in config.** A deny rule written using the `/tmp/...` symlink form did **not** block access to the same file via its canonical `/private/tmp/...` form — the forbidden read succeeded. The `ALLOWED_REPOS.json → sandbox.sb` generator must realpath every entry before writing it into the profile, or this is an exploitable gap for anything whose original write used a non-canonical path.

**Primary recommendation:** Generate one SBPL profile from one `ALLOWED_REPOS.json`, using an `(allow default)` base with `(deny file-read*/file-write* (subpath <realpath of $HOME>))` plus `(allow file-read*/file-write* (subpath <realpath of each ALLOWED_REPOS entry>))` punch-throughs (and a punch-through for Cline's own data dir), regenerated on every invocation (never cached), and wrap the entire `cline` process invocation in `sandbox-exec -f sandbox.sb`. Test the profile directly against `/bin/cat`/`/bin/sh` and a small stand-in Node script — not by driving a full agent task — for every phase-3 verification step; only smoke-test the real `cline` binary once, at the very end, immediately followed by re-running Phase 1's `apply_provider_config.sh` to heal any config drift the invocation causes.

## Standard Stack

### Core

| Tool | Version (verified on this host) | Purpose | Why standard |
|------|------|---------|---------------|
| `sandbox-exec` | Ships with macOS 26.3 (Darwin 25.3.0), binary at `/usr/bin/sandbox-exec` | Kernel-enforced (Seatbelt/TrustedBSD MAC framework) process sandbox | The only mechanism confirmed (by this research and by ARCHITECTURE.md) that is enforced regardless of what Cline's own JS code does. No competing OS-native alternative exists on macOS short of a full VM (explicitly rejected by ARCHITECTURE.md on memory-headroom grounds) or a dedicated restricted OS user account (explicitly rejected as disproportionate for a single-user machine). |
| SBPL (Sandbox Profile Language, TinyScheme-based) | `(version 1)` dialect, same as used by Apple's own system profiles | The profile format `sandbox-exec -f`/`-p` consumes | No alternative syntax exists for this tool |
| `python3` (already installed, 3.14.6 per `local-llm-settings` research, but any Python 3 works) | n/a | Canonicalize `ALLOWED_REPOS.json` paths via `os.path.realpath()` before emitting SBPL | `realpath` in bash (`readlink -f` doesn't exist on stock macOS `readlink`; BSD `readlink` has no `-f`) is unreliable across shells — Python's `os.path.realpath` is a clean, dependency-free, correct primitive already available on this host |

### Supporting

| Tool | Purpose | When to use |
|------|---------|-------------|
| `strings` + manual read of minified output | Statically verify what a `cline` binary version actually contains, without invoking it (avoids the auto-update / config-drift risk documented in Phase 1) | Use this, not `cline --help`, whenever you need to check whether some claimed cline flag/env-var actually exists in the currently-installed build |
| `log show` / `log stream` (macOS unified logging) | Attempted for capturing Seatbelt denial diagnostics | **Did not prove useful in this research** — `sandbox-exec` denials of file ops surface directly as clean stderr from the denied process itself (e.g., `cat: <path>: Operation not permitted`) or, in the SIGABRT-crash case, as *no* diagnostic at all; `log stream` predicate syntax fought back and wasn't worth the time. Rely on the target process's own stderr/exit code as the primary signal, not unified logging. |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| `sandbox-exec` wrapping the whole `cline` process | Cline's own `CLINE_COMMAND_PERMISSIONS` / `.clineignore` | **Not viable at all** — neither exists in the installed binary (verified). Do not build around them. |
| `sandbox-exec` wrapping the whole `cline` process | Docker/VM-based isolation | Rejected by ARCHITECTURE.md — adds a heavy competing process against the 104 GiB model's memory headroom; `sandbox-exec` needs no extra running process |
| `sandbox-exec` wrapping the whole `cline` process | Dedicated restricted macOS user account | Rejected by ARCHITECTURE.md as disproportionate for a single-user personal machine (would complicate access to the user's own GPU/Tailscale identity); noted only as an escalation ceiling if requirements ever tighten |
| `(deny default)` + narrow allow-list SBPL pattern | `(allow default)` + narrow deny + punch-through SBPL pattern (recommended) | `(deny default)` is the "textbook" safest-looking pattern but **empirically crashes basic Mach-O binaries with SIGABRT and zero diagnostic stderr** the instant the dynamic linker can't read a runtime dependency it needs (reproduced directly, see Pitfalls). It would require enumerating the entire dyld/codesign/runtime read surface, which is impractical and fragile across macOS updates. The `(allow default)` + deny-root + punch-through pattern was verified to work cleanly and is the only one that survived direct testing. |

**Installation:** None needed — `sandbox-exec` ships with the OS; confirmed present and runnable as a normal user with no `sudo` and no additional entitlement on this host.

## Architecture Patterns

### Recommended Project Structure

Reuses the layout ARCHITECTURE.md §5/§7 already proposed for this project — this research does not change it, only adds the verified generation/enforcement mechanics underneath it:

```
~/projs/cline-tests/
  workspace/                          ← sandbox root; the ONLY tree the agent's repos live under
    ALLOWED_REPOS.json                ← SBX-01: single source of truth, list of real repo paths
    <repo-name>/  → symlink to real repo path (generated FROM ALLOWED_REPOS.json, for Kanban UX)
    sandbox.sb                        ← Seatbelt profile, GENERATED fresh from ALLOWED_REPOS.json
                                          on every invocation — never hand-edited, never cached
  bench/                              ← SBX-04: deliberately OUTSIDE the whitelist (see below)
    runs/
```

### Pattern 1: `(allow default)` + deny-root + allow-punch-through SBPL profile

**What:** Rather than a strict-looking `(deny default)` base, start permissive and carve out the protected region explicitly.

**When to use:** Any time the wrapped process is a real-world binary/runtime (Node, Bun, or any signed Mach-O executable) rather than a hand-rolled static binary with no external dependencies.

**Verified-working profile shape** (every line below was actually run on this host and produced the expected allow/deny outcome):

```scheme
(version 1)
(allow default)
;; Deny read/write anywhere under the protected root...
(deny file-read*  (subpath "/Users/ohama"))
(deny file-write* (subpath "/Users/ohama"))
;; ...then punch through exactly the whitelisted repos (each path realpath'd first)
(allow file-read*  (subpath "/Users/ohama/projs/cline-tests/workspace/repo-a"))
(allow file-write* (subpath "/Users/ohama/projs/cline-tests/workspace/repo-a"))
;; ...and Cline's own runtime/data dir, which also lives under $HOME and would
;; otherwise be caught by the deny-root above
(allow file-read*  (subpath "/Users/ohama/.cline"))
(allow file-write* (subpath "/Users/ohama/.cline"))
```

Verified outcomes with this exact pattern (paths substituted for the actual test fixture; see Code Examples for the literal transcript):
- `/bin/cat <file inside an allowed repo>` → succeeds, correct content on stdout, exit 0.
- `/bin/cat <file outside the whitelist>` → fails, `Operation not permitted` on stderr, exit 1.
- `/bin/sh -c "echo x > <file outside the whitelist>"` → fails to create the file (verified with a subsequent unsandboxed `ls`).
- `/bin/sh -c "cat <file outside the whitelist>"` (proxy for `execute_command`) → same denial as the direct `cat` case.
- A Node script doing `fs.readFileSync`/`fs.writeFileSync` in-process against in/out-of-whitelist paths, run under this profile → in-whitelist succeeds, out-of-whitelist throws `EPERM` for both read and write.
- The same Node script also doing `child_process.execSync('cat <outside path>')` → denied identically to the shell case (`e.status` non-zero, denial message on stderr).
- Ran the Node script's fs checks repeatedly across a `setInterval` loop over 3 iterations / 1.5s → denial held on every iteration; no weakening over the life of a long-running process.
- A directory named `.../allowed_extra_should_not_match` sitting as a sibling of an allowed `.../allowed` directory → correctly **denied**, proving `subpath` is component-boundary-aware, not a naive string prefix (`/a/b` does not match `/a/bc`).
- A symlink placed *inside* an allowed directory pointing at a forbidden directory → correctly **denied** when read through — the kernel resolves to the real target path for the check, exactly as ARCHITECTURE.md's "known gotcha" predicted.
- Paths containing spaces, and paths with/without a trailing slash in the `subpath` argument, both worked correctly with no special handling needed beyond normal Scheme-string quoting.

### Pattern 2: `ALLOWED_REPOS.json` → generator → `sandbox.sb`, regenerated every launch

**What:** One JSON file is the only thing a human/automation edits; a small script derives both the Kanban symlink tree (per ARCHITECTURE.md) and the SBPL profile from it, every time, rather than caching a stale profile.

**Why every-launch regeneration, not cached-and-invalidated:** ARCHITECTURE.md already flagged this as the failure mode to design out ("a whitelist that silently fails to regenerate after a repo is added is exactly the 'convenience worked, safety net didn't' failure mode"). Given profile generation is cheap (sub-millisecond JSON parse + string templating), there is no performance reason to cache it, and caching reintroduces exactly the drift risk being designed against.

**Suggested shape (illustrative, not a full implementation):**

```json
{
  "repos": [
    "/Users/ohama/projs/cline-tests/workspace/some-repo",
    "/Users/ohama/projs/another-project"
  ]
}
```

```python
# Source: this research's own tested pattern (verified empirically on this host, 2026-08-30)
import json, os, sys

def load_allowed_repos(path):
    with open(path) as f:
        data = json.load(f)
    resolved = []
    for raw in data["repos"]:
        real = os.path.realpath(raw)          # <-- the canonicalization step that matters
        if not os.path.isdir(real):
            sys.exit(f"ALLOWED_REPOS entry does not resolve to an existing directory: {raw!r} -> {real!r}")
        resolved.append(real)
    # guard against one entry being a sub-path of another (harmless but worth flagging,
    # and a cheap early signal that the JSON has a typo/duplicate)
    for a in resolved:
        for b in resolved:
            if a != b and (a + os.sep).startswith(b + os.sep):
                sys.exit(f"{a!r} is nested under {b!r} - list only the outermost path")
    return resolved

def render_profile(home_realpath, cline_data_dir_realpath, repo_paths):
    lines = ["(version 1)", "(allow default)"]
    lines.append(f'(deny file-read* (subpath "{home_realpath}"))')
    lines.append(f'(deny file-write* (subpath "{home_realpath}"))')
    for p in repo_paths + [cline_data_dir_realpath]:
        lines.append(f'(allow file-read* (subpath "{p}"))')
        lines.append(f'(allow file-write* (subpath "{p}"))')
    return "\n".join(lines) + "\n"
```

### Anti-Patterns to Avoid

- **`(deny default)` as the SBPL base for a real-world binary.** Verified to crash target processes with SIGABRT and *no* stderr the moment the dynamic linker/codesigning subsystem is denied something it needs. A naive test harness checking only "exit code != 0 means the sandbox blocked it" will misreport a **broken, crashed sandbox** as "successfully denying access" — these are not the same thing and must be distinguished (see Pitfalls).
- **Writing profile paths in whatever form happens to be lying around (e.g. `/tmp/...`) instead of realpath'd form.** Verified to create a real bypass: a deny rule against the non-canonical form does not block access via the canonical form.
- **Using `file-write-data` alone instead of the `file-write*` wildcard.** SBPL splits writes into `file-write-data`, `file-write-create`, `file-write-unlink`, etc. — a profile that only restricts `file-write-data` would still let a forbidden *new* file be created. Always use the wildcard forms (`file-read*`, `file-write*`) for both deny and allow rules.
- **Caching a generated `sandbox.sb` and only regenerating it "when something changes."** Regenerate unconditionally on every invocation instead — it's cheap and removes an entire class of drift bugs.
- **Testing the sandbox by driving a full agent task end-to-end.** Every mechanical property needed for Phase 3's success criteria was provable with `sandbox-exec /bin/cat ...` / `/bin/sh -c ...` / a five-line Node script, none of which require the 64s TTFT model round-trip. Reserve a real `cline` invocation for one final, cheap smoke test only (see Common Pitfalls: "cline-specific invocation risk").

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|--------------|-----|
| Path-based file-access restriction inside the agent process | A wrapper script around `cline` that checks tool-call arguments against a whitelist before letting them through | `sandbox-exec` at the OS level | A userspace path-check wrapper can be bypassed by the agent itself once inside the process (e.g. via `execute_command` shelling to a different tool that isn't checked, or simply because the check is advisory, not kernel-enforced). This was the exact reasoning ARCHITECTURE.md already gave, and this research's fs/execSync tests confirm there is no need for such a wrapper — the kernel already catches both paths uniformly. |
| Canonicalizing paths before writing them into a security-relevant config file | A hand-rolled string-manipulation "resolve `..`/symlinks myself" function | `os.path.realpath()` (or equivalent) | Getting this wrong is exactly the bug this research reproduced (`/tmp` vs `/private/tmp`). Use the platform's own canonicalization primitive, not a custom one. |

**Key insight:** every custom "userspace enforcement" idea for this phase (a Node-level path checker, a bash wrapper checking `execute_command` arguments) shares the same fatal flaw — it runs *inside* the same trust boundary as the thing it's trying to constrain, so a sufficiently wrong or manipulated agent step bypasses it. `sandbox-exec` is the only mechanism in this stack that sits outside that boundary, enforced by the kernel; every design decision in this phase should route through it rather than around it.

## Common Pitfalls

### Pitfall 1: `(deny default)` + narrow allowlist silently crashes the target binary instead of cleanly denying it

**What goes wrong:** A profile of the form `(deny default)(allow process-exec*)(allow file-read* (subpath "/bin") ...)` was built to run `/bin/cat`. It crashed with exit code 134 (SIGABRT) and produced **zero output on stdout or stderr** — not even `sandbox-exec`'s own usual denial message. This was reproduced multiple times with different (still incomplete) sets of allowed read paths.

**Why it happens:** The dynamic linker (`dyld`) and the kernel's code-signing verification need to read a broad, not-fully-documented set of system paths (shared cache, various `/System`/`/private/var/db` locations) just to map the executable and its libraries into memory, before the program's own `main()` ever runs. Under a narrow `(deny default)`-based allowlist it's very easy to miss one of these, and the failure mode is a hard process abort rather than a graceful "permission denied" from the program.

**How to avoid:** Do not use `(deny default)` as the base for any profile that wraps a real system binary or runtime (Node, Bun, or `cline` itself). Use `(allow default)` + explicit deny-root + allow-punch-through instead (Pattern 1 above) — verified to work cleanly with `/bin/cat`, `/bin/sh`, and `node` without any of this fragility, because the base "allow everything" already covers whatever dyld/codesigning needs.

**Warning signs:** Any sandboxed process exiting with 134 (or any signal-based exit, i.e. exit code > 128) and *no* stderr output at all — that is a crashed sandbox, not a "successfully denied" one. A verification script that only checks `exit code != 0` will conflate these two very different outcomes and could report a broken sandbox as a passing test.

### Pitfall 2: profile paths must be canonicalized, or deny rules can be silently bypassed

**What goes wrong:** A deny rule written as `(deny file-read* (subpath "/tmp/x"))` (the non-canonical, symlinked form on macOS) did **not** block reading the same file accessed via its canonical path, `/private/tmp/x` — the read succeeded. The reverse direction (deny written canonically, accessed via the alias) correctly denied. The asymmetry is the trap: whichever form is used to *write* the rule is not silently expanded to cover the other form.

**Why it happens:** `/tmp` is a symlink to `/private/tmp` on macOS. The kernel canonicalizes the path being *accessed* at check time, but a rule string written in non-canonical form in the profile is (empirically) not itself expanded to its target before matching.

**How to avoid:** The `ALLOWED_REPOS.json → sandbox.sb` generator must run every path through `os.path.realpath()` (or equivalent) before writing it into the SBPL profile — never write whatever raw string appears in the JSON. This is Pattern 2's `real = os.path.realpath(raw)` step; do not skip it, even though on this specific host `/Users/ohama` itself happens to already be its own realpath (no APFS firmlink surprise was found here) — `/tmp` vs `/private/tmp` alone is enough to make this a live risk for anything touching temp directories, and any future repo added under a symlinked mount (external volume, network share, iCloud Drive folder) would hit the same class of bug.

**Warning signs:** A repo added to `ALLOWED_REPOS.json` using a path that goes through any symlink (most commonly `/tmp`, but also possible for anything under a symlinked home-directory subtree) behaves correctly for the *intended* path but silently fails to actually restrict access via the alternate spelling.

### Pitfall 3: `execute_command` targeting an *allowed* command but a forbidden path is not blocked by command-name allowlisting alone

**What goes wrong:** This phase's requirement (SBX-03) is about paths, not commands, but it's worth stating explicitly since it was a documented concern in ARCHITECTURE.md: even if a command-name allowlist existed (it doesn't, per Correction 1 above), `python -c "print(open('/etc/passwd').read())"` or `cat` are both "allowed commands" whose *arguments* determine whether they touch a forbidden path — a command-level filter is the wrong axis of control.

**How to avoid:** Enforce at the path level via `sandbox-exec`, not at the command-name level. This is what Pattern 1 already does, and it makes the specific command used (`cat`, `python`, `node`, or `cline`'s own in-process reader) irrelevant — the kernel denies the underlying `open()`/`write()` regardless of which program issued it.

### Pitfall 4: any `cline` invocation risks version drift and provider-config corruption — budget for it, don't fight it mid-verification

**What goes wrong:** Documented extensively in Phase 1 (`01-06-SUMMARY.md`, `providers.json drifted... on every single preflight pass`) and reconfirmed live during this research: the currently-installed `cline` is `3.0.60`, not the pinned `3.0.53`, and `providers.json` currently lacks the custom `models[]`/`contextWindow` fields Phase 1 established — both drifted again since Phase 1/2 finished, exactly as documented ("the self-updater will very likely drift it again on the next invocation").

**Why it happens:** Cline's background self-updater fires on nearly every invocation regardless of `CLINE_NO_AUTO_UPDATE=1` in some invocation paths (per Phase 1's findings), and some invocations (even ones that error out, like `cline config --json` without a TTY) still touch and rewrite `providers.json`, stripping non-standard fields.

**How to avoid for this phase specifically:** Do not use a real `cline` invocation as a verification step for SBX-01/02/03/04 — every mechanical property was fully provable with `sandbox-exec` wrapping `/bin/cat`, `/bin/sh -c`, and a throwaway Node script (see Standard Stack/Testing). If a plan step genuinely needs to smoke-test the real `cline` binary under the sandbox (e.g. as a one-time end-to-end sanity check, or naturally as part of Phase 4's headless-wrapper work), treat it exactly like Phase 1 did: chain `CLINE_NO_AUTO_UPDATE=1 npm install -g cline@3.0.53 ... && sandbox-exec -f sandbox.sb cline ...` in one shell invocation, and immediately re-run `phase-01/config/apply_provider_config.sh` afterward to heal any config drift, rather than trying to prevent the drift from happening at all.

**Warning signs:** `cline --version` returning anything other than `3.0.53`; `providers.json` missing the `openai-compatible` provider's custom fields — both are expected, recoverable, and already have an established fix (`apply_provider_config.sh`), not a Phase 3 blocker.

### Pitfall 5: a sandbox that "passes" because it fails open, not because it's actually restrictive

**What goes wrong (risk to design against, not something reproduced here):** A profile with a typo in a `subpath` string, a deny rule that's shadowed by a later broader allow, or a generator bug that emits an empty/near-empty profile could all produce a sandbox that lets everything through while a shallow test (e.g. "does the agent complete its task successfully") reports success.

**How to avoid:** Every verification step for this phase must assert the *negative* case explicitly and check for the specific denial signal (non-zero exit **and** `Operation not permitted`/`EPERM` on stderr referencing the target path), not just "the task didn't crash." Keep the prefix-trap fixture (`<allowed>_should_not_match` sibling directory) and the canonicalization fixture (a path reachable both through a symlink and its canonical form) as *permanent* regression fixtures, not one-off manual checks, since both are exactly the kind of bug that silently regresses a working profile into a fail-open one after a future edit.

**Does `sandbox-exec` fail open or closed?** Verified: closed. Every deny case tested (file read/write, in-process and via subprocess) produced a hard failure (`EPERM`/`Operation not permitted`, non-zero exit) with no case observed where a denied operation silently succeeded. The one fail-open risk is not in `sandbox-exec` itself but in **profile authoring bugs** (Pitfall 2's canonicalization gap is exactly this class of bug) — the tool enforces correctly; the risk is entirely in getting the generated profile text right.

## Code Examples

### Full transcript pattern for the four SBX-02/03 test cases (verified, reusable)

```bash
# Source: this research, run directly on this host, 2026-08-30. Substitute real
# ALLOWED/FORBIDDEN paths and a real sandbox.sb generated per Pattern 2.

# 1. Read inside whitelist -> must succeed
sandbox-exec -f sandbox.sb /bin/cat "$ALLOWED/file.txt"
# exit 0, correct content on stdout

# 2. Read outside whitelist -> must fail with EPERM, not crash
sandbox-exec -f sandbox.sb /bin/cat "$FORBIDDEN/secret.txt"
# exit 1, stderr: "cat: <path>: Operation not permitted"

# 3. Write outside whitelist -> must fail, file must not appear
sandbox-exec -f sandbox.sb /bin/sh -c "echo x > '$FORBIDDEN/newfile.txt'"
ls "$FORBIDDEN"   # <-- run UNsandboxed; newfile.txt must be absent

# 4. execute_command-style denial (the SBX-03 case) -> identical to case 2,
#    just invoked through a shell instead of directly
sandbox-exec -f sandbox.sb /bin/sh -c "cat '$FORBIDDEN/secret.txt'"
# exit 1, same denial
```

### In-process fs denial check (closest proxy to Cline's own tool-loop file access)

```javascript
// Source: this research's own test script, run under sandbox-exec on this host.
// Proves the SBX-02/SBX-03 collapse: Node's own fs.* calls are intercepted
// identically to a subprocess exec, by the same kernel-level Seatbelt policy.
const fs = require('fs');
const { execSync } = require('child_process');

function check(label, fn) {
  try { fn(); console.log(`${label}: SUCCEEDED`); }
  catch (e) { console.log(`${label}: DENIED (${e.code || e.status})`); }
}

check('in-process read, in whitelist',  () => fs.readFileSync(`${ALLOWED}/f.txt`));
check('in-process read, forbidden',     () => fs.readFileSync(`${FORBIDDEN}/f.txt`));
check('in-process write, forbidden',    () => fs.writeFileSync(`${FORBIDDEN}/x.txt`, 'x'));
check('subprocess exec, forbidden',     () => execSync(`cat '${FORBIDDEN}/f.txt'`));
```
Run as: `sandbox-exec -f sandbox.sb node this-script.js` — verified on this host to correctly report "DENIED" for every forbidden case and "SUCCEEDED" for the whitelisted case, both immediately and across repeated calls in a long-running (`setInterval`-driven) process.

## State of the Art

| Old assumption (from prior project-level research, unverified against the live binary) | Corrected finding (this research, verified live) | Impact |
|---|---|---|
| `CLINE_COMMAND_PERMISSIONS` is a real, usable command allow/deny mechanism | Does not exist in the installed binary at all | Any plan step assuming this must be dropped; `sandbox-exec` is the only path-level and command-level enforcement available |
| `.clineignore` is enforced at the Cline tool layer for file tools | Does not exist as a string anywhere in the installed CLI binary | Do not rely on `.clineignore` for anything in this CLI-only deployment; if it exists at all it's VS-Code-extension-only and out of scope |
| `CLINE_SANDBOX`/`CLINE_SANDBOX_DATA_DIR` provide "env-var based sandboxing" | They only relocate Cline's own config/data storage (identical effect to `--data-dir`); no filesystem access restriction | Useful for keeping Cline's own state out of `~/.cline` if ever wanted, but irrelevant to SBX-01..04 |
| A strict `(deny default)` SBPL profile is the "correct"/safest starting point | Crashes real binaries (SIGABRT, no diagnostics) unless the entire dyld/codesign read surface is enumerated | Use `(allow default)` + deny-root + punch-through instead (see Pattern 1) |

**Deprecated/outdated:** `sandbox-exec` itself is marked `DEPRECATED` in its own man page (Apple recommends the App Sandbox / SwiftUI entitlement model for GUI apps instead) but remains fully functional on macOS 26.3 as of this research and has no viable non-VM/non-dedicated-user replacement for wrapping an arbitrary CLI process — this was already ARCHITECTURE.md's conclusion and this research found nothing to contradict it.

## Open Questions

1. **Exact behavior of the real `cline` Mach-O binary (not a stand-in) under this profile.**
   - What we know: `/bin/cat`, `/bin/sh`, and plain `node` (same fs/exec syscall surface Cline's Bun-compiled binary uses) all behave correctly under the recommended profile pattern.
   - What's unclear: whether `cline`'s own startup sequence (hub daemon spawn, npm auto-update check, telemetry, its own credential-store read at `~/.cline/data/settings/providers.json`) needs any additional punch-through beyond the generic Cline-data-dir allow already included in Pattern 2.
   - Recommendation: the plan's verification step should include exactly one real `sandbox-exec -f sandbox.sb cline --version`-class smoke test (see Pitfall 4 for the safe invocation pattern), not skip real-binary testing entirely — but do not use it as the primary test oracle for SBX-02/03, since it's slow, drift-prone, and less precise than the direct tests above.

2. **Whether other paths outside `$HOME` ever need protecting on this specific machine.**
   - What we know: this is a single-user personal Mac; ARCHITECTURE.md already judged a dedicated restricted OS user disproportionate; no external/mounted volumes were found during this research.
   - What's unclear: if an external drive or network share is ever mounted and contains something sensitive, the recommended `$HOME`-rooted deny in Pattern 1 would not cover it.
   - Recommendation: note this as an explicit, accepted scope boundary in the phase's documentation rather than trying to enumerate every mount point defensively; revisit only if the machine's storage layout changes.

3. **Harbor/cline-bench's actual output-directory flag (relevant to SBX-04, owned by Phase 7).**
   - What we know (carried from `FEATURES.md`, not re-verified in this research): Harbor writes to `jobs/<timestamp>/` relative to the invocation's cwd by default; the README doesn't confirm an explicit output-dir override flag.
   - What's unclear: whether Phase 7 will need to `cd` into `bench/` before invoking `harbor run` or can pass a flag to redirect output there directly.
   - Recommendation: Phase 3 doesn't need to resolve this — it only needs `bench/` to never appear in `ALLOWED_REPOS.json`, which was directly verified sufficient to make its contents unreadable from inside the sandbox (same mechanism as any other forbidden directory in the tests above). Flag this as a Phase 7 research item, not a Phase 3 blocker.

## Sources

### Primary (HIGH confidence — live, direct verification on this exact machine, 2026-08-30)
- `sandbox-exec` man page, read directly (`man sandbox-exec`) — confirms DEPRECATED status, `-f`/`-n`/`-p`/`-D` flag syntax
- `sw_vers` / `uname -a` — macOS 26.3 (BuildVersion 25D125), Darwin 25.3.0, run directly on this host
- Every SBPL profile and test transcript in this document — built and executed directly against real file fixtures under this session's scratchpad, and re-verified with a fresh read after each run
- `strings -a` over `/opt/homebrew/lib/node_modules/cline/bin/.cline` (the actual installed Mach-O binary, currently reporting version `3.0.60` per `package.json`) — used to confirm/deny the existence of `CLINE_COMMAND_PERMISSIONS`, `.clineignore`, `CLINE_SANDBOX`, `CLINE_SANDBOX_DATA_DIR` as literal strings in the shipped code
- `~/.cline/data/settings/providers.json`, read directly — confirms current (drifted) config state

### Secondary (MEDIUM confidence — this project's own prior research, itself independently sourced from Cline's live `--help` output and docs, reused here where not contradicted)
- `.planning/research/ARCHITECTURE.md` §5, §6, §7, §8 — sandbox/whitelist architecture, bench-directory placement rationale, build ordering (this research's job was to verify and correct its mechanics, not replace its design)
- `.planning/research/STACK.md` — `cline --help` flag table (`--auto-approve`, `--data-dir`, `--worktree`, etc.), captured live against the real binary in the original project research session
- `.planning/research/PITFALLS.md` — Pitfall 5 (auto-approve defaults), litellm exposure findings, cross-referenced but not re-verified in this session
- `.planning/phases/01-cline-config-compaction-verification/01-06-SUMMARY.md` — documented, reproduced-many-times version-drift/config-drift behavior, reused directly for this phase's "don't fight the drift, budget for it" recommendation

### Tertiary (LOW confidence — carried forward, not independently re-verified this session)
- `.planning/research/FEATURES.md` §"Can Harbor run tasks locally..." — Harbor's `jobs/<timestamp>/` default output path claim, sourced from the cline-bench README via WebSearch/WebFetch in the original project research, not re-fetched here; flagged as an Open Question for Phase 7 to confirm directly

## Metadata

**Confidence breakdown:**
- Standard stack (sandbox-exec presence/behavior): HIGH — every claim reproduced live on this host today
- Architecture (SBPL profile pattern, ALLOWED_REPOS.json → generator flow): HIGH for the mechanics (tested), MEDIUM for the exact generator implementation shape (illustrative, not built/tested as a finished script)
- Pitfalls: HIGH — all five were either directly reproduced (1, 2, 4) or are direct logical consequences of directly-verified mechanics (3, 5)
- Cline-native-mechanism corrections (Don't Hand-Roll, State of the Art): HIGH — based on `strings` over the actual installed binary, not documentation

**Research date:** 2026-08-30
**Valid until:** Treat the `cline`-specific findings (Corrections 1/2, Pitfall 4) as valid only for `cline` 3.0.53/3.0.60 on this exact npm-installed build — re-verify with `strings` against whatever binary is actually installed if this phase is revisited after a deliberate version bump. The `sandbox-exec`/SBPL findings are OS-level and should remain valid for the life of macOS 26.x; re-verify the crash/canonicalization pitfalls if the host is ever upgraded to a materially different macOS major version.
