---
phase: 04-headless-cli-wrapper
verified: 2026-08-30T07:15:00Z
status: passed
score: 3/3 ROADMAP truths verified; 4/4 PLAN must_haves sets verified
---

# Phase 4: 헤드리스 CLI 래퍼 Verification Report

**Phase Goal:** Phase 1(설정)과 Phase 3(샌드박스)이 실제로 함께 맞물려 동작하는지 가장 싸고
빠르게 확인하는 단발 스모크 테스트. 서비스화는 이번 마일스톤에서 하지 않는다.
**Verified:** 2026-08-30T07:15:00Z (UTC)
**Status:** passed
**Re-verification:** No — initial verification

## Method

Goal-backward verification against the codebase at `/Users/ohama/projs/cline-tests`, cross-checked
against `must_haves` frontmatter in all four PLAN.md files and the three ROADMAP success criteria.
No trust placed in SUMMARY.md prose — every claim below was independently re-derived from raw
NDJSON, grep output, live gate re-runs, and constructed adversarial fixtures. Zero `cline`
invocations were made by this verification (all criterion-3 gate testing used the script's
`VERIFY_DRY_NDJSON` fixture hook). No launchd service was touched.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 래퍼 스크립트에 프롬프트를 넣어 한 번 실행하면 NDJSON 형식의 결과가 반환된다 | ✓ VERIFIED | `phase-04/results/20260829T214344Z-90746-headless/ndjson.log` — 10 lines, every non-blank line valid JSON, contains exactly one `"type":"run_result"` event with `"finishReason":"completed"`, model reply `"PONG"`. `outcome.json` classifier verdict `success` matches the raw stream exactly (no discrepancy between classifier and raw capture). `cline_exit.txt` = `0`. |
| 2 | 래퍼의 실행 커맨드/코드에 `--auto-approve false` 가 명시적으로 박혀 있다 | ✓ VERIFIED | `grep -c -- '--auto-approve false' phase-04/run_headless.sh` = 1 (line 245, the actual invocation). `grep -c -- '--auto-approve true' phase-04/run_headless.sh` = 0. No default-dependence anywhere in the script. |
| 3 | 샌드박스 밖 경로를 건드리려는 프롬프트로 실행하면 Phase 3 의 화이트리스트에 의해 거부된다 | ✓ VERIFIED | `phase-04/results/20260829T215236Z-verify-cline-criterion3/ndjson.log` (92,683 bytes, real live run): a `read_files` tool call targeting `/Users/ohama/.zshrc` returns `"success":false,"error":"Error reading file: EPERM: operation not permitted, stat '/Users/ohama/.zshrc'"` — a genuine kernel-level denial, not a TTY/model refusal. In the **same** tool call batch, `./SANDBOX_INSIDE_CANARY.txt` returns `"success":true,"result":"1 \| INSIDE-SANDBOX-READABLE-OK"`, proving the sandbox did not fail open. `outcome.json.outcome` = `"sandbox_denied"`, `denied_targets` = `["/Users/ohama/.zshrc"]`, `verdict.txt` = `VERDICT: DENIED`. Classifier verdict matches raw NDJSON exactly. |

**Score:** 3/3 truths verified.

### Required Artifacts (from PLAN.md `must_haves`)

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `phase-04/classify_run.py` | NDJSON→outcome classifier, contains `MAX_KV_SIZE`, ≥150 lines | ✓ VERIFIED | 514 lines. `MAX_KV_SIZE` appears 6×. Precedence order (crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected > run_aborted > success > other) confirmed by code read and by forcing `--exit-code 137` against the `sandbox_denied.ndjson` fixture — result was `crashed`, not `sandbox_denied` (see Anti-Pattern Ladder Testing below). Exported, imported by both wave-2 scripts. |
| `phase-04/config.env` | Phase paths incl. `SANDBOX_WORKDIR` derived from `ALLOWED_REPOS.json`, contains `ALLOWED_REPOS` | ✓ VERIFIED | 54 lines. `ALLOWED_REPOS` appears 4×. Both `run_headless.sh` and `verify_sandbox_via_cline.sh` `source` this file (no hard-coded path in either). |
| `phase-04/fixtures/` | One NDJSON per outcome, frozen, contains `INSIDE-SANDBOX-READABLE-OK` | ✓ VERIFIED | 5 fixtures present (`success_no_tools`, `sandbox_denied`, `tty_approval_rejected`, `context_overflow_32k`, `crashed_truncated`). `sandbox_denied.ndjson` carries both the denied `/Users/ohama/.zshrc` attempt and the successful `SANDBOX_INSIDE_CANARY.txt` canary read in the same fixture. `git diff --stat phase-04/fixtures/` empty — byte-unchanged since 04-01. |
| `phase-04/tests/test_classify_run.py` | pytest coverage, ≥80 lines | ✓ VERIFIED | 185 lines, 13 test functions covering all 6 outcomes plus nested-vs-flat error message, crash-outranks-denial, denial-vs-TTY discrimination, denial-not-suppressed-by-canary, and fixture-immutability. `pytest phase-04/tests/` → **13 passed** (re-run live by this verification). |
| `phase-04/run_headless.sh` | Shipped wrapper, contains `--auto-approve false`, ≥90 lines | ✓ VERIFIED | 293 lines. Header states the safe-but-inert limitation plainly (lines 25-30+). |
| `phase-04/results/` | Timestamped evidence dirs | ✓ VERIFIED | 5 dated result directories present, including the counted-crash retained for the record, the criterion-1/2 live run, the criterion-3 live run, and the phase-close gate sweep. |
| `phase-04/verify_sandbox_via_cline.sh` | Criterion-3 proof gate, TEST-ONLY, ≥100 lines | ✓ VERIFIED | 440 lines. `TEST-ONLY` banner present (line 6). `--auto-approve true` × 4 (1 code line 263 + 3 explanatory comments), `--auto-approve false` × 0 — no drift into the shipped wrapper's flag. |
| `docs/sandbox-whitelist.md` | §7 resolved, contains `해결됨 (Phase 4)` | ✓ VERIFIED | §7's original narrative (Bun startup failure, undiagnosed at Phase 3 close) is preserved verbatim; a new `### 해결됨 (Phase 4)` subsection is appended below it, naming `docs/headless-wrapper.md` and stating the real root cause was process cwd, not a missing punch-through, and that `EXTRA_ALLOW_PATHS` was never widened. |
| `docs/headless-wrapper.md` | Korean operator doc, contains `auto-approve`, ≥80 lines | ✓ VERIFIED | 200 lines, 8 numbered sections. §4 (`한계 — --auto-approve false 는 3.0.53 헤드리스에서 도구 호출을 전부 거부한다`) is its own prominent section, opens with "이 절이 이 문서에서 가장 눈에 띄어야 한다" ("this section must be the most visible in this document"), and explicitly hands the decision to Phase 5. §8 restates it as open work for Phase 5. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `classify_run.py` | `phase-01/parse_result.py` | nested-vs-flat error tolerance | ✓ WIRED | `_error_event_message()` present; `test_nested_and_flat_max_kv_size_both_classify_context_overflow` passes. |
| `config.env` | `workspace/ALLOWED_REPOS.json` | `SANDBOX_WORKDIR` derivation | ✓ WIRED | Confirmed no hard-coded path; both consumers source `config.env`. |
| `run_headless.sh` | `phase-03/sandbox/run_sandboxed.sh` | sole sandbox entry point | ✓ WIRED | Only invocation path found; `RUN_SANDBOXED="$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh"`, used at the one live-call site. |
| `run_headless.sh` | `phase-01/config/cline-invocation.env` | sources `CLINE_BIN`/flags/pin | ✓ WIRED | Sourced at line 84. |
| `run_headless.sh` | `phase-04/classify_run.py` | classifies + propagates exit code | ✓ WIRED | `exit "$CLASSIFY_EXIT"` at end of script, `CLASSIFY_EXIT=$?` captured from the classifier call. |
| `run_headless.sh` | stdout/stderr discipline | NDJSON on stdout, diagnostics on stderr | ✓ WIRED | Every `echo` except one (a file-append, not stdout) is `>&2`; the sole stdout writer is `tee "$RESULTS_DIR/ndjson.log"`; classifier's own output also redirected `>&2`. |
| `verify_sandbox_via_cline.sh` | `phase-03/sandbox/run_sandboxed.sh` | same sanctioned entry point | ✓ WIRED | Confirmed. |
| `verify_sandbox_via_cline.sh` | `phase-04/classify_run.py` | reads `outcome.json` fields, never bare exit code | ✓ WIRED | 8-rung verdict ladder (lines 307-422) reads `tool_attempts`/`signals`/`outcome`, cross-checks raw NDJSON text for leaked content as a defense-in-depth measure. |
| `verify_sandbox_via_cline.sh` | `phase-03/sandbox/assert_denied.sh` | EPERM discriminator reuse | ✓ WIRED | Same `EPERM`/`Operation not permitted`/exit>128 discipline reused (verified by code read and adversarial testing below). |
| `docs/headless-wrapper.md` | `phase-04/run_headless.sh` | documents shipped interface | ✓ WIRED | §2/§3/§6 cite it directly. |
| `docs/headless-wrapper.md` | `phase-04/verify_sandbox_via_cline.sh` | cites criterion-3 evidence | ✓ WIRED | §5 (기준 3 증거). |
| `docs/headless-wrapper.md` | `docs/32k-compaction-policy.md` | restates MAX_KV_SIZE operational rule | ✓ WIRED | Cited in §3 and in `classify_run.py`'s own reason string. |

### Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| HLS-01 (NDJSON returned from one wrapper run) | ✓ SATISFIED | Live run, criterion 1 above. |
| HLS-02 (`--auto-approve false` explicit, not default-dependent) | ✓ SATISFIED | grep evidence, criterion 2 above. |
| HLS-03 (wrapper only runs inside sandbox; whitelist denial proven) | ✓ SATISFIED | Sole invocation path through `run_sandboxed.sh`; live criterion-3 denial with in-whitelist canary control, criterion 3 above. |

Note: `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` still show HLS-01/02/03 and Phase 4's
checkbox as unchecked/Pending — this is expected bookkeeping state before phase-close updates
those files; it does not reflect a gap in the actual deliverables, which is what this report
verifies.

### Adversarial Testing — "Try to Break the Criterion-3 Gate"

Exercised `phase-04/verify_sandbox_via_cline.sh` via `VERIFY_DRY_NDJSON` against every fixture and
one hand-built adversarial fixture, `SKIP_SANDBOX_GATE=1` to keep this fully offline. **A
PASS/DENIED verdict could not be reached from any failure mode tested:**

| Input | Verdict | Exit | Correct? |
|---|---|---|---|
| `crashed_truncated.ndjson` (truncated stream, no `run_result`) | `INCONCLUSIVE — crashed, not denied` | 2 | ✓ |
| `context_overflow_32k.ndjson` (MAX_KV_SIZE terminal death) | `INCONCLUSIVE — 32K MAX_KV_SIZE terminal failure` | 2 | ✓ |
| `tty_approval_rejected.ndjson` (TTY-approval gate blocked before OS) | `NOT_DENIED — the TTY approval gate blocked the tool call before the OS did` | 1 | ✓ |
| `success_no_tools.ndjson` (model never attempted the target — refusal proxy) | `INCONCLUSIVE — the model never attempted the target; a refusal is not a denial` | 2 | ✓ |
| Hand-built fail-open fixture (target read `"success":true`, real-looking content) | `NOT_DENIED — a tool attempt on the target succeeded ... the sandbox failed open` | 1 | ✓ |
| `sandbox_denied.ndjson` (genuine denial + canary) | `DENIED` | 0 | ✓ (only true positive) |
| `sandbox_denied.ndjson` classified with `--exit-code 137` (SIGKILL) forced | `crashed` (verified directly against `classify_run.py`, not just the wrapper) | n/a | ✓ — exit>128 forces `crashed` even over an otherwise-denying stream; `has_crash` short-circuits before `has_denial` is ever consulted. |

Every one of the five requested failure classes (crash, model refusal, TTY-approval rejection,
32K MAX_KV_SIZE death, fail-open sandbox) produces its own distinct, correctly non-passing
verdict. `classify_run.py`'s stated precedence (`crashed > sandbox_denied > context_overflow_terminal
> tty_approval_rejected > run_aborted > success > other`) and its `--exit-code > 128 → crashed`
rule were spot-checked directly against source and confirmed by the forced-exit-code test above.
The gate cannot be gamed into a false PASS by any of the tested inputs.

### Offline Gates Re-Run (live, by this verification)

| Gate | Result |
|---|---|
| `pytest phase-04/tests/` | **13 passed** |
| `bash phase-03/sandbox/verify_sandbox.sh` | **PASS** — `CASES 16/16`, `CRASHED 0`, all 4 `CRITERION ... PASS` |
| `bash phase-01/config/verify_config.sh` | **PASS** (exit 0) — `OK: providers.json holds flashnext @ localhost:4000/v1, contextWindow=32768, no codex alias` |
| `bash phase-02/infra/verify_no_regression.sh` | **PASS** — `INF03: PASS` |

All four pass now, independently re-run by this verification, not merely trusted from commit-time
SUMMARY claims.

### Sandbox Boundary and Byte-Unchanged Check

- `EXTRA_ALLOW_PATHS` in `phase-03/sandbox/config.env`: confirmed empty (`EXTRA_ALLOW_PATHS="${EXTRA_ALLOW_PATHS:-}"`, no override anywhere).
- `git log --oneline 510cca2..HEAD -- phase-03/ phase-02/` (`510cca2` = Phase 3's close commit): **empty** — no Phase 4 commit touched either directory.
- `git diff --stat phase-03/ phase-02/`: **empty** (working tree clean against those paths).

### Live Service PIDs (read-only check, no launchd action taken)

| Service | Expected PID | Observed | Status |
|---|---|---|---|
| flashnext | 46573 | 46573, running (`.venv-mlxvlm-new/bin/python3`) | ✓ unchanged |
| role-shim | 75548 | 75548, running (`agent-stack/venv/bin/python`) | ✓ unchanged |
| litellm | 48525 | 48525, running (`agent-stack/venv/bin/python`) | ✓ unchanged |

No `launchctl`, `kill`, `bootout`, or `bootstrap` command was issued by this verification.

### Anti-Patterns Found

None blocking. No `TODO`/`FIXME`/placeholder patterns found in the shipped artifacts. No stub
tool-call handlers. No orphaned artifacts — every file listed in `must_haves` is imported/sourced
by its declared consumer.

### Honesty Assessment — the `--auto-approve false` safe-but-inert limitation

**Finding confirmed as real and as disclosed:** in cline 3.0.53's headless (`--json`, no-TTY) mode,
`--auto-approve false` does not pause for approval — it rejects every tool call immediately with
`Tool "<name>" requires approval in a TTY session`, and the run self-aborts after a few iterations.
The shipped wrapper (`phase-04/run_headless.sh`) therefore cannot perform any tool-using work
headlessly; it only completes normally for tool-free prompts. This is stated plainly in the
wrapper's own header comment and as its own prominent numbered section, `docs/headless-wrapper.md`
§4, which opens by declaring itself "the section that must be most visible in this document" and
explicitly frames the two honest resolution paths (wait for an upstream approval-hook feature, or
accept `--auto-approve true` with the sandbox as the sole boundary) as **a decision that must be
escalated to a human, never made silently**. §8 restates it as explicit Phase 5 hand-off. Section 4
of `docs/sandbox-whitelist.md` was also checked and is unaffected — this is a cline CLI/TTY-gate
limitation, not a sandbox limitation.

**Judgment against the phase's own scope:** the phase's stated goal is a "단발 스모크 테스트"
(one-shot smoke test) proving Phase 1 config and Phase 3 sandbox interoperate — explicitly NOT
service-ization ("서비스화는 이번 마일스톤에서 하지 않는다"). None of the three ROADMAP success
criteria require the wrapper to perform tool-using work under `--auto-approve false`: criterion 1
only requires an NDJSON result from one run (satisfied by a tool-free prompt); criterion 2 only
requires the literal flag be pinned in code (satisfied regardless of what that flag does at
runtime); criterion 3 is explicitly proven through the separate, clearly-labeled TEST-ONLY
`--auto-approve true` script for exactly this reason — the phase's own plans anticipated that
testing criterion 3 through the shipped wrapper would be a false pass and built around it. Read
literally, **the phase is complete against its three written criteria**; this is not a gap in
Phase 4's own deliverable.

It **is** a real, material constraint for Phase 5, which is scoped to put the Kanban/Telegram
surfaces live as standing services — those surfaces will need to perform actual tool-using agent
work, and the current wrapper cannot do that under its safe default. This is not buried: it is
recorded in three places — `run_headless.sh`'s header, `docs/headless-wrapper.md` §4 (its own
section, opened with an explicit visibility flag) and §8 (explicit Phase 5 hand-off item), and it
requires a human decision before Phase 5 can proceed on tool-using flows. No further action is
needed from this verification beyond confirming the documentation trail exists and is not
softened — which it is not.

### Human Verification Required

None. All three ROADMAP criteria and all four PLAN.md `must_haves` sets were verified
programmatically against live evidence, source code, and adversarial fixture testing.

### Gaps Summary

No gaps found. All three ROADMAP success criteria are verified against real live evidence (not
SUMMARY claims): the classifier's verdicts were independently cross-checked against raw NDJSON for
both live runs and matched exactly. The criterion-3 gate was adversarially tested and could not be
made to produce a false PASS from a crash, a refusal, a TTY rejection, a 32K death, or a
constructed fail-open scenario. The sandbox boundary is unmoved (`EXTRA_ALLOW_PATHS` empty,
`phase-03/`/`phase-02/` byte-unchanged since Phase 3's close), all four standing gates pass on
re-run, and live service PIDs are unchanged. The one substantive limitation found — the shipped
wrapper's inability to do tool-using work under its safe default — is real but out of scope for
Phase 4's own three criteria as written, and is transparently documented and escalated as an open
item for Phase 5 rather than hidden.

---

*Verified: 2026-08-30T07:15:00Z*
*Verifier: Claude (gsd-verifier)*
