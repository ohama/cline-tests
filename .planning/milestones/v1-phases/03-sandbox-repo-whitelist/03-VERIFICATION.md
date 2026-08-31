---
phase: 03-sandbox-repo-whitelist
verified: 2026-08-29T20:42:13Z
status: passed
score: 4/4 ROADMAP criteria verified (SBX-01..04); 4/4 plan-level truths-groups verified
notes:
  - "Outcome C from plan 03-04's single budgeted cline smoke test (BLOCKED-NEEDS-HUMAN) is NOT a
     Phase 3 gap — none of the four ROADMAP criteria require the real cline binary to run under the
     sandbox, and all four are independently proven at the kernel level with /bin/cat, /bin/sh and
     node. It IS a real, unresolved blocker for Phase 4's own success criterion 3, which requires
     running the real agent under this sandbox. This is documented below as a carried-forward open
     item for Phase 4, not buried in a SUMMARY."
---

# Phase 3: Sandbox Repo Whitelist Verification Report

**Phase Goal:** 원격에서 트리거될 수 있는 어떤 것(헤드리스 래퍼, Kanban, Telegram)도 이 안전망이
갖춰지기 전에는 실제 저장소에 연결되지 않는다.

**Verified:** 2026-08-29T20:42:13Z
**Status:** passed
**Re-verification:** No — initial verification

This is a security control that Phases 4-7 will build on and expose to the network. Verification
below was performed adversarially: the standing gate was re-run independently, its negative controls
were re-exercised, its assertion-helper source code was read line-by-line against the false-pass
discrimination spec, and every "PASS" claim in the phase's SUMMARYs was checked against actual
kernel-level behavior rather than trusted from the summary text.

## Goal Achievement

### Observable Truths (ROADMAP Phase 3 success criteria, SBX-01..04)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `ALLOWED_REPOS.json` exists and holds the allowed-repo list (SBX-01) | VERIFIED | `workspace/ALLOWED_REPOS.json` read directly: one entry (`workspace/scratch-repo`), repo root never listed, `_comment` states the single-source-of-truth rule. `verify_sandbox.sh`'s criterion-1 check independently confirms: entries parse, resolve to existing dirs, and none is `realpath(bench/)` or an ancestor of it. |
| 2 | Reads/writes outside the whitelist actually fail, reproducibly (SBX-02) | VERIFIED | Re-ran `verify_sandbox.sh` myself: F2 (read outside), F3 (write outside, file absent afterward), F8 in-process probe (`inproc-read-forbidden DENIED`, `inproc-write-forbidden DENIED`) all PASS. Directly reproduced `run_sandboxed.sh -- /bin/cat bench/runs/CANARY.txt` → `Operation not permitted`, rc=1. |
| 3 | `execute_command` targeting outside-whitelist paths is blocked by `sandbox-exec` (SBX-03) | VERIFIED | F4 (shell exec of `cat` on forbidden path) and F8 (`subproc-read-forbidden DENIED`, `subproc-write-forbidden DENIED` via Node `execSync`) both PASS on my own re-run. Same kernel mechanism as criterion 2 (verified as a single collapsed enforcement point per 03-RESEARCH.md). |
| 4 | Bench results dir is unreadable from inside the sandbox (SBX-04) | VERIFIED | P3 (`cat bench/runs/CANARY.txt` denied), P4 (`cat bench/runs/*` denied, and canary string absent from all captured output) both PASS. I independently confirmed the canary string `SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX` appears in exactly one file across all of `phase-03/results/` — a README documenting the assertion target — and in zero captured sandboxed stdout files. |

**Score:** 4/4 truths verified.

### Standing Gate — independent re-run

`bash phase-03/sandbox/verify_sandbox.sh --out-dir phase-03/results/verify-agent-check` (run by
this verifier, not copied from a SUMMARY):

```
CASE F1..F8 PASS (8/8, including F8's 7-way probe)
CASE P1..P6 PASS (6/6)
criterion-1-check: PASS entries=1 bench_real=/Users/ohama/projs/cline-tests/bench
CRITERION 1: PASS
CRITERION 2: PASS F2=PASS F3=PASS F8=PASS
CRITERION 3: PASS F4=PASS F8=PASS
CRITERION 4: PASS P3=PASS P4=PASS CANARY-LEAK=PASS
CASES 16/16
CRASHED 0
VERIFY_SANDBOX: PASS
EXIT=0
```

Result matched exactly across two independent runs performed by the executing plans (03-03's
`20260829T202043Z-sbx` and `20260829T202048Z-sbx`) and my own third, adversarial run. The transient
evidence directory I generated (`verify-agent-check`) was deleted after inspection to avoid littering
the phase's evidence trail with a duplicate of what 03-03 already archived; `git status --short`
confirms no residue.

### Negative controls — re-exercised, not just read

The plan requires the gate to be provably falsifiable. I re-ran all three controls myself rather than
trusting the archived transcripts in `phase-03/results/20260829T201927Z-negative-control/`:

1. `verify_sandbox.sh --negative-control` → fed a deny-less `(version 1)\n(allow default)` profile.
   Result: `NEGATIVE-CONTROL PASSED: profile sanity pre-check correctly rejected the fail-open
   profile`, exit 0 (i.e. the gate's own pre-check catches it before any case runs).
2. `verify_sandbox.sh --negative-control --negative-control-skip-precheck` → pre-check bypassed,
   Group F run for real against the fail-open profile. Result: all four deny cases
   (`F2-negctl`, `F4-negctl`, `F5-negctl`, `F7-negctl`) individually reported `FAIL not-denied`;
   `NEGATIVE-CONTROL PASSED: ... the verifier correctly detected the fail-open sandbox`. No deny
   case reported a spurious PASS.
3. Canonicalization-regression control (`gen_sandbox_profile.py --no-canonicalize`) — reproduced
   manually, independent of the archived transcript: generated a fixture profile with realpath
   canonicalization disabled, then ran the F6 case (read via the *canonical* spelling of a
   whitelist entry that was declared through a symlink) against it directly via `assert_denied.sh`.
   Result: `CASE F6-mycheck FAIL not-allowed rc=1` — F6 genuinely flips from PASS to FAIL when
   canonicalization is dropped, proving `os.path.realpath()` is load-bearing and its removal is
   caught by the standing gate, not silently accepted.

All three negative controls behave as designed: a gate that cannot fail proves nothing, and this one
demonstrably can fail, on demand, for the exact two failure modes 03-RESEARCH.md identified as the
highest risk (fail-open profile, dropped canonicalization).

### False-pass discrimination — audited at the source-code level

Read `phase-03/sandbox/assert_denied.sh` in full (184 lines) and `phase-03/sandbox/probe_fs.js` in
full (98 lines) rather than trusting the SUMMARY's description of their behavior.

**`assert_denied.sh` classification order (lines 92-183), confirmed exactly as specified:**
- Line 92-109: an unsandboxed CONTROL run of the same command must exit 0 first (and, for
  `--write-target` cases, must have actually created the file) — otherwise `FAIL control-failed`,
  never a denial verdict.
- Line 139-143: sandboxed exit code `> 128` → `FAIL crashed-signal`, exit 2. Checked **first**, before
  any other deny classification, so a SIGABRT crash can never fall through to a lower-priority
  "denied" verdict.
- Line 145-149: exit code `== 0` → `FAIL not-denied` (fail-open).
- Line 151-155: empty stderr → `FAIL crashed-silent`, exit 2 — a silent non-zero exit is treated as
  inconclusive, not as evidence of a denial.
- Line 157-162: only after all of the above does it require stderr to match
  `Operation not permitted|EPERM|not permitted`; anything else → `FAIL wrong-error`.
- Line 164-171 / 173-179: additional target-naming and write-absence checks before the final
  `PASS denied`.

**`probe_fs.js` (lines 43-70), confirmed exactly as specified:**
- `checkFs`: only `e.code === 'EPERM'` is classified `DENIED`; every other error code (`ENOENT`,
  `EACCES`, etc.) is `ERROR`, never `DENIED`.
- `checkExec`: `DENIED` requires **both** a non-zero/non-null exit status **and** a stderr match on
  `Operation not permitted` — a bare non-zero exit alone is insufficient and falls through to
  `ERROR`.

**Whole-directory sweep for bare-exit-code denial patterns:**
`grep -nE '\$\? -ne 0.*(PASS|denied)' phase-03/sandbox/verify_sandbox.sh` → no matches.
`grep -nE '\$\?[[:space:]]*-ne[[:space:]]*0' phase-03/sandbox/*.sh phase-03/sandbox/*.py
phase-03/sandbox/*.js` → no matches anywhere in the phase-03/sandbox/ tree. The one place a raw
`status !== 0` check exists (`probe_fs.js` line 63) is always AND-combined with the stderr regex, not
used alone.
`grep -c 'assert_denied.sh' phase-03/sandbox/verify_sandbox.sh` → 20 (every allow/deny judgement in
the gate is delegated to the helper or to `probe_fs.js`'s own DENIED/ERROR/SUCCEEDED text; none is
asserted inline from a bare exit code).

### Criterion-1 direction — verified correct, not just claimed correct

Read the actual Python embedded in `verify_sandbox.sh` (around line 539):

```python
if bench_real == real or bench_real.startswith(real + os.sep):
    print("FAIL bench-dir-is-descendant-of-or-equal-to-entry:entry=%s bench=%s" % (real, bench_real))
```

This checks, for every whitelist entry, whether `realpath(BENCH_DIR)` equals or is a descendant of
that entry — i.e. it catches "the repo root (or any ancestor of `bench/`) was whitelisted." This is
the correct direction: the actual threat is a human whitelisting `/Users/ohama/projs/cline-tests`
(under which `bench/` lives), which would silently make `bench/` inherit the punch-through. The
reverse relationship (an entry being placed inside `bench/`) is checked nowhere and correctly is not
what this code guards against — writing it the other way would have accepted the repo-root
misconfiguration without complaint.

`docs/sandbox-whitelist.md` §6 (lines 131-137) describes this exact check in the same direction and
explicitly quotes the code's own comment ("NO entry equals or is an ancestor of realpath(BENCH_DIR)")
— the documentation does not diverge from the implementation.

### SBX-04 canary — genuinely unreadable, confirmed independently

- `cat bench/runs/CANARY.txt` (unsandboxed, as a control) succeeds and prints
  `SBX04-CANARY-MUST-NOT-BE-READABLE-FROM-INSIDE-SANDBOX`.
- `phase-03/sandbox/run_sandboxed.sh -- /bin/cat bench/runs/CANARY.txt` (run directly by this
  verifier): `cat: bench/runs/CANARY.txt: Operation not permitted`, rc=1.
- `grep -rl 'SBX04-CANARY-MUST-NOT-BE-READABLE' phase-03/results/` returns exactly one hit, a README
  that quotes the string as documentation of the assertion target — zero hits in any captured
  sandboxed stdout/stderr transcript.

### Scope-limitation honesty — confirmed in all three required locations

The design is `(allow default)` + deny-`$HOME` + punch-through, which protects only `$HOME`. Checked
each required location directly:

- `phase-03/sandbox/config.env` lines 7-17: a boxed "SCOPE LIMITATION (stated, not hidden)" comment
  at the very top of the file, naming `/tmp`, `/opt`, `/usr/local`, and external volumes/network
  shares as explicitly unprotected, and explaining why `(deny default)` was rejected (SIGABRT with
  no diagnostics).
- `phase-03/sandbox/run_sandboxed.sh` lines 21-27: the same limitation, verbatim in substance, in the
  wrapper's own header comment (item (c) of the documented Phase 4 interface).
- `docs/sandbox-whitelist.md` §3 (lines 37-68): its own numbered top-level section, opening with
  "이 문서에서 가장 눈에 띄어야 하는 절이다" (explicitly the most-prominent section in the doc), with
  the exact SBPL rule shape shown, a bulleted 보호되는 것/보호되지 않는 것 split, and the
  `(deny default)`-rejection rationale repeated. Nothing in the document overstates the protection —
  the "보호되지 않는 것" bullet is stated as plainly as the "보호되는 것" one.

No overstatement of protection was found anywhere in the reviewed artifacts.

### Outcome C (cline smoke test) — assessed honestly

Plan 03-04's single budgeted `cline` invocation (`phase-03/results/20260829T202633Z-cline-smoke/`)
returned verdict **C (BLOCKED-NEEDS-HUMAN)**: `run_sandboxed.sh -- "$CLINE_BIN" --version` exits 1
with a generic, path-less Bun runtime error (`error: An unknown error occurred (Unexpected)`),
confirmed by static `strings -a` inspection to be Bun's own startup catch-all, not a message naming
any specific Cline-owned directory. `EXTRA_ALLOW_PATHS` was correctly left unchanged (still empty) —
the plan's own rule requires widening beyond the pre-declared candidate list to be a human decision,
and this failure mode gives no specific path to bound a fix to.

**Judgment:** this does NOT constitute a Phase 3 gap. None of the four ROADMAP Phase 3 success
criteria mention `cline` by name, and all four are independently proven at the kernel level using
`/bin/cat`, `/bin/sh`, and plain `node` — which 03-RESEARCH.md verified share cline's own
fs/exec/subprocess syscall surface. The mechanism under test (Seatbelt profile enforcement) is
proven; whether the specific `cline`/Bun binary can currently complete its own startup under that
mechanism is a separate, narrower question that this plan correctly declined to guess at.

**However, this is a real, documented blocker Phase 4 inherits, and it is recorded here explicitly so
it is not buried:** Phase 4's own success criterion 3 ("샌드박스 밖 경로를 건드리려는 프롬프트로
실행하면 Phase 3 의 화이트리스트에 의해 거부된다") requires running the real agent under this
sandbox. As of this verification, `cline --version` alone does not complete under
`run_sandboxed.sh` — it fails before any cline/Bun logic executes far enough to reach a
whitelist-related file operation, with a diagnostic too generic to bound a safe fix. Phase 4 cannot
assume `cline` runs cleanly under this sandbox and must budget time to diagnose (the smoke-test
verdict itself suggests `dtruss`/`fs_usage` under elevated privileges, not attempted in Phase 3) and
possibly negotiate a human decision on a bounded `EXTRA_ALLOW_PATHS` widening before its own
criterion 3 can be exercised. This is stated as an open item in `docs/sandbox-whitelist.md` §7 and is
restated here for visibility at the phase-verification level, not just inside a SUMMARY.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `workspace/ALLOWED_REPOS.json` | SBX-01 source of truth | VERIFIED | Exists, parses, 1 entry, repo root never listed, `_comment` present |
| `phase-03/sandbox/gen_sandbox_profile.py` | realpath-canonicalizing SBPL compiler | VERIFIED | 11/11 unit tests pass on independent re-run; `--no-canonicalize` regression control confirms canonicalization is load-bearing |
| `phase-03/sandbox/run_sandboxed.sh` | regenerate-then-exec wrapper | VERIFIED | No `[ -f "$PROFILE_OUT" ]` cache guard (confirmed by direct read); unconditional regen before both `--dry-run` and real exec; fail-closed on generation failure; `exec` used so exit/stderr pass through |
| `phase-03/sandbox/make_fixtures.sh` | idempotent fixture tree | VERIFIED (indirectly, via re-run of verify_sandbox.sh which calls it fresh every run) | Prefix-trap sibling and symlink-spelled entry both present and asserted every run (F5, F6) |
| `phase-03/sandbox/assert_denied.sh` | false-pass-discriminating helper | VERIFIED | Source-audited line-by-line; classification order matches spec exactly |
| `phase-03/sandbox/probe_fs.js` | EPERM-only DENIED classifier | VERIFIED | Source-audited; ENOENT/other codes never counted as DENIED |
| `phase-03/sandbox/verify_sandbox.sh` | standing Phase 3 gate | VERIFIED | Independently re-run, exit 0, 4/4 CRITERION PASS, 16/16 cases, 0 CRASHED; negative-control modes re-exercised and behave correctly |
| `bench/runs/CANARY.txt` | SBX-04 target, outside whitelist | VERIFIED | Tracked in git, denied from inside sandbox, string never leaks into captured sandbox output |
| `docs/sandbox-whitelist.md` | shipped-state doc, scope limitation, Phase 4 interface | VERIFIED | Scope limitation is its own prominent §3; criterion-1 direction described matches code; cline smoke-test outcome C documented as an explicit open item, not buried |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| `run_sandboxed.sh` | `gen_sandbox_profile.py` | unconditional regeneration before every exec | WIRED — verified in source, no cache-guard code path exists |
| `gen_sandbox_profile.py` | `workspace/ALLOWED_REPOS.json` | `--allowed-repos` sourced from `config.env` | WIRED — reproduced live, resolved allow list printed to stderr matches JSON content |
| `run_sandboxed.sh` | `/usr/bin/sandbox-exec` | `exec sandbox-exec -f <profile> -- <command>` | WIRED — confirmed by direct invocation returning real kernel `Operation not permitted` |
| `verify_sandbox.sh` | `assert_denied.sh` | every deny/allow case delegated, never asserted inline | WIRED — 20 call sites, zero inline bare-exit-code judgements found |
| `verify_sandbox.sh` | `probe_fs.js` | sandboxed Node probe asserting DENIED per forbidden label | WIRED — F8 case confirmed PASS with 7/7 correct classifications on independent re-run |
| `verify_sandbox.sh` | `bench/runs/CANARY.txt` | P3/P4 deny cases + canary-string-absence sweep | WIRED — confirmed, canary string appears in zero captured sandboxed output |
| `docs/sandbox-whitelist.md` | `run_sandboxed.sh` / `verify_sandbox.sh` | documented Phase 4 interface contract | WIRED — both scripts named with exact invocation forms and exit-code contracts in §5 |

### Requirements Coverage

| Requirement | Status | Detail |
|-------------|--------|--------|
| SBX-01 | SATISFIED | `ALLOWED_REPOS.json` is the sole source of truth; criterion-1 check confirms it programmatically on every gate run |
| SBX-02 | SATISFIED | Reads/writes outside the whitelist fail with real `EPERM`/`Operation not permitted`, reproduced directly by this verifier |
| SBX-03 | SATISFIED | `execute_command`-shaped denials (shell `cat`, Node `execSync`) blocked identically to in-process reads, same kernel mechanism |
| SBX-04 | SATISFIED | `bench/runs/CANARY.txt` unreadable from inside the sandbox, canary string never leaks into sandboxed output |

Note: `.planning/REQUIREMENTS.md` still shows these four items with unchecked `[ ]` boxes and a
`Pending` status column — this is a stale tracking-document artifact, not a functional gap. All four
requirements are functionally satisfied per the evidence above; the REQUIREMENTS.md checkboxes
simply were not flipped by any of the 03-0x plans. Recommend updating REQUIREMENTS.md's tracking
table in a follow-up (does not block Phase 3 completion).

### Anti-Patterns Found

None found in `phase-03/sandbox/` or `phase-03/tests/`. No `TODO`/`FIXME`/`placeholder` stubs, no
empty-return handlers, no bare-exit-code denial judgements (see false-pass discrimination audit
above), no `[ -f ... ]` profile-cache guard.

### Live-service safety constraints — confirmed honored

- `flashnext` pid 46573, `role-shim` pid 75548, `litellm` pid 48525 — all three checked via `ps` and
  `launchctl print` at the start and end of this verification session: unchanged throughout.
- No `launchctl` mutation, restart, bootout, or bootstrap was issued by this verifier.
- No `cline` invocation was made by this verifier (the phase's one budgeted invocation belongs to
  plan 03-04 and was read from its archived evidence, not repeated).
- `phase-01/config/verify_config.sh` (read-only check, no cline invocation) re-run by this verifier:
  `OK: providers.json holds flashnext @ localhost:4000/v1, contextWindow=32768, no codex alias`,
  rc=0 — confirming providers.json remains healthy after Phase 3's one cline invocation.

### Human Verification Required

None for Phase 3's own four success criteria — all are mechanically verified at the kernel level with
adversarial negative controls proving the verifier itself is falsifiable.

One item is flagged for Phase 4 planning attention (not blocking Phase 3 closure):

1. **cline-under-sandbox startup failure**
   **Test:** Run `phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" --version` (or the real Phase 4
   headless-wrapper invocation) and observe whether the generic Bun startup error recurs.
   **Expected:** Either a clean version print (meaning the earlier failure was transient/environmental)
   or a reproducible, diagnosable failure that Phase 4 can bound a fix for.
   **Why human:** Diagnosing the exact syscall/path behind Bun's generic "An unknown error occurred"
   message requires elevated-privilege tooling (`dtruss`/`fs_usage` under sudo) that was not available
   to the automated smoke test, and any resulting `EXTRA_ALLOW_PATHS` widening beyond the pre-declared
   candidate list is explicitly a human decision per this phase's own design.

### Gaps Summary

No gaps against Phase 3's own goal and four ROADMAP success criteria. All must-haves from all four
plans (03-01 through 03-04) were checked against the actual codebase — not against SUMMARY claims —
and verified: the generator canonicalizes and validates correctly, the wrapper regenerates
unconditionally and fails closed, the assertion helper and probe correctly distinguish crashes from
denials from missing-fixture errors, the standing gate proves all four criteria and is itself
demonstrably falsifiable via three independently-reproduced negative controls, the criterion-1
ancestor check is implemented in the correct (repo-root-catching) direction and documented accurately,
the SBX-04 canary is genuinely unreadable with zero content leakage, and the `$HOME`-only scope
limitation is stated prominently and consistently in all three required locations with no
overstatement of protection anywhere found.

The one open item — outcome C of the `cline` smoke test — is not a Phase 3 gap (no ROADMAP criterion
requires `cline` itself to run under the sandbox) but is a genuine, non-buried blocker that Phase 4
must resolve before its own success criterion 3 can be exercised. It is documented in
`docs/sandbox-whitelist.md` §7 and restated above for visibility.

---

*Verified: 2026-08-29T20:42:13Z*
*Verifier: Claude (gsd-verifier)*
