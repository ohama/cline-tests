---
phase: 02-infra-hardening
verified: 2026-08-29T19:20:52Z
status: passed
score: 3/3 phase success criteria verified (all 4 plans' must_haves independently confirmed)
---

# Phase 2: 인프라 보정 (Infra Hardening) Verification Report

**Phase Goal:** 이미 상주 중인 `flashnext`/`litellm` 서비스를 건드리지 않던 두 위험 — 무제한 동시
배칭과 무인증 LAN 노출 — 에 대해서만 보정한다.

**Verified:** 2026-08-29T19:20:52Z (live machine, read-only checks only — no service was restarted,
killed, or edited during this verification)
**Status:** passed
**Re-verification:** No — initial verification

## Method

All checks below were run independently against the live machine and the repo, not taken from
SUMMARY.md claims. Live plists were read directly, `launchctl print` and `ps -o command=` were used
to confirm the *loaded/running* process matches the file on disk (not just the file), `lsof` confirmed
actual bind addresses, and both re-runnable gate scripts (`verify_no_regression.sh`,
`verify_lan_bind.sh`) were executed fresh during this verification session and both returned PASS.

## Goal Achievement

### Observable Truths (ROADMAP Phase 2 Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `com.ohama.flashnext.plist` carries `--max-num-seqs` cap; two concurrent requests show one queued/delayed, not OOM | VERIFIED | Live plist `ProgramArguments` ends `--max-num-seqs 1`; `launchctl print gui/501/com.ohama.flashnext` shows identical loaded arguments and `pid = 46573` (matches expected); `ps -o command=` on pid 46573 shows the same flag. Decisive evidence `phase-02/results/20260829T185628Z-inf01/inf01-verdict.txt`: before = `max_overlap=2, queued_count=0`; after = `max_overlap=1, queued_count=1`, `gap_seconds≈-0.019` (second request's prefill started essentially the instant the first's decode completed — a real serialization signature drawn from `flashnext.err` timestamps, not from HTTP 200 counts, per RESEARCH.md Pitfall 3). |
| 2 | `litellm` locked to `127.0.0.1` bind or `master_key`, LAN request refused (curl-reproducible) | VERIFIED | Live plist `ProgramArguments` ends `--host 127.0.0.1`; `launchctl print gui/501/com.ohama.litellm` shows identical loaded arguments and `pid = 48525`; `lsof -nP -iTCP -sTCP:LISTEN` shows `python3.1 48525 ... 127.0.0.1:4000 (LISTEN)` — no `*:4000` entry anywhere. Independently re-ran `bash phase-02/infra/verify_lan_bind.sh` during this verification: fresh run also printed `INF02: PASS` (LAN IP curl → `rc=7` connection refused; loopback IP and `localhost` both → HTTP 200 with flashnext alias present). |
| 3 | After both changes, `flashnext` alias call (litellm → role-shim → mlx_vlm.server) still returns 200 | VERIFIED | Independently re-ran `bash phase-02/infra/verify_no_regression.sh` during this verification (fresh run, this session): printed `INF03: PASS`. Script asserts both hardening flags are still present (`--max-num-seqs` value match, `--host` value match) in addition to the end-to-end 200 + non-empty-content check, so it doubles as a standing regression gate as designed. |

**Score:** 3/3 phase-level truths verified.

### Required Artifacts (all four plans' must_haves)

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `phase-02/infra/config.env` | single override point for `MAX_NUM_SEQS`/`LITELLM_BIND_HOST` | VERIFIED | Contains `MAX_NUM_SEQS="${MAX_NUM_SEQS:-1}"` and `LITELLM_BIND_HOST="${LITELLM_BIND_HOST:-127.0.0.1}"`; both `apply_*.sh` scripts source it, never hardcode. |
| `phase-02/infra/preflight.sh` | service state + `iogpu.wired_limit_mb` + ports + plist sha256 + mirror diff | VERIFIED | Present, substantive; baseline evidence file confirms it produced `iogpu.wired_limit_mb=118784 (expected 118784)`, `PREFLIGHT: PASS`, and byte-identical mirror comparison output. |
| `phase-02/infra/restart_service.sh` | shared bootout→bootstrap→poll restarter, rollback block printed on every non-zero exit | VERIFIED | `trap 'rc=$?; if [ "$rc" -ne 0 ]; then print_rollback "$rc"; fi' EXIT` at line 71 confirms rollback fires on any non-zero exit, not only poll timeout. Step 3b (lines 110-153) implements the teardown-poll-then-settle-then-bootstrap fix. No forbidden verbs (`kill`, `pkill`, `launchctl load/unload/kickstart`) appear anywhere in the script. |
| `phase-02/infra/verify_queueing.sh` | N-request probe self-sized from `MAX_NUM_SEQS`, produces `flashnext.err` interval-overlap evidence | VERIFIED | Present; evidence dirs show it correctly derived `concurrency=2, cap=1` from `config.env` without a second script variant. |
| `phase-02/infra/apply_max_num_seqs.sh` | idempotent plist writer + pre-edit backup + plutil lint | VERIFIED | 3 timestamped `com.ohama.flashnext.plist.*` backups exist in `phase-02/infra/backups/`; live plist confirmed lint-clean and carries exactly one `--max-num-seqs`/`1` pair. |
| `phase-02/infra/apply_litellm_bind.sh` | idempotent writer adding `--host <BIND_HOST>` + backup + lint | VERIFIED | Backup dir contains `com.ohama.litellm.plist.20260829T190346Z`; live plist carries exactly one `--host`/`127.0.0.1` pair. |
| `phase-02/infra/verify_lan_bind.sh` | re-runnable INF-02 proof (LAN refused, loopback 200, lsof bind assertion) | VERIFIED | Re-ran live during this session: `INF02: PASS`. |
| `phase-02/infra/verify_no_regression.sh` | INF-03 gate: end-to-end 200 + both-flags-present assertion | VERIFIED | Re-ran live during this session: `INF03: PASS`. Script greps for both `--max-num-seqs` and `--host` presence (lines 77-86), so it fails loudly if either hardening flag regresses. |
| `docs/infra-hardening.md` | Phase 2 record: what changed, why, evidence paths, rollback runbook | VERIFIED | Exists, documents both before/after `ProgramArguments`, rationale for choosing bind-over-master_key, explicit limitation note (`--max-num-seqs` does not fix the single-request 32K Metal OOM — correctly scoped, not overclaimed), an evidence-path table, and copy-pasteable rollback commands for both services plus the house rules (never `kill`/`launchctl load`/`unload`/`kickstart`; bootout is async). |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Live `com.ohama.flashnext.plist` | loaded launchd job + running process | `launchctl print` / `ps -o command=` | WIRED | All three sources (file, loaded job, running argv) agree on `--max-num-seqs 1`, pid 46573. |
| Live `com.ohama.litellm.plist` | loaded launchd job + running process | `launchctl print` / `ps -o command=` | WIRED | All three sources agree on `--host 127.0.0.1`, pid 48525. |
| `~/Library/LaunchAgents/com.ohama.{flashnext,litellm}.plist` | `~/local-llm-settings/launchagents/` | mirror sync | WIRED | `diff` between live and mirror plists for both services returns no output — byte-identical, confirming `sync.sh` was run after both edits landed (02-04). |
| `phase-02/infra/verify_no_regression.sh` | `http://127.0.0.1:4000/v1/chat/completions` | POST, asserting 200 + non-empty content + both flags present | WIRED | Fresh re-run this session: `INF03: PASS`. |
| `phase-02/infra/verify_lan_bind.sh` | `http://<LAN-IP>:4000/v1/models` | curl asserting rc=7 | WIRED | Fresh re-run this session: `INF02: PASS`, LAN curl returned `curl_rc=7`. |
| `phase-02/infra/restart_service.sh` (commit `0ca2645`) | async-bootout race | poll-until-torn-down + 3s settle before bootstrap | WIRED | Fix confirmed present in the live script body (lines 110-153) and exercised successfully in the decisive INF-01 restart (`teardown confirmed after 2s`, `waited=28s`, first-try success). |

### Requirements Coverage

| Requirement | Status | Notes |
|---|---|---|
| INF-01 | SATISFIED | Live plist + loaded job + queueing-evidence contrast all confirm cap is real and behaviorally proven (max_overlap 2→1, queued_count 0→1). |
| INF-02 | SATISFIED | Live plist + loaded job + `lsof` + fresh `verify_lan_bind.sh` re-run all confirm loopback-only bind with LAN refusal. |
| INF-03 | SATISFIED | Fresh `verify_no_regression.sh` re-run confirms end-to-end 200 with both flags intact. |

(`.planning/REQUIREMENTS.md` still shows these three rows as "Pending" in its status column — this is a
tracking-table staleness issue, not a phase-goal gap; the underlying requirements are demonstrably met
on the live machine. Recommend the orchestrator update this table at phase close.)

### Anti-Patterns Found

None blocking. Two minor documentation-integrity notes surfaced during verification (see below) — neither
affects any of the three phase success criteria, which were all independently re-confirmed live.

1. **Empty "failed restart attempt" evidence files** — `phase-02/results/20260829T184656Z-inf01/restart-flashnext.txt`
   and `restart-flashnext-attempt2.txt` are both 0 bytes. `git show 4c34cbc` shows these were committed
   as a `git copy` of an already-empty file from an unrelated phase-01 artifact
   (`phase-01/results/max-tokens-probe/stderr.log`, also 0 bytes), not actual captured stderr from the
   two live `Bootstrap failed: 5: Input/output error` failures the SUMMARY narrates. The commit message
   and SUMMARY both correctly describe *what happened* (root cause, fix, and that both failed attempts
   rolled back cleanly), and that narrative is independently corroborated by: the fix being genuinely
   present and dated before the successful attempt (`0ca2645`, timestamped ahead of the `185628Z`
   decisive run), and the decisive run's own restart timing (`teardown confirmed after 2s`) being
   consistent with a fix landing after two prior unfixed failures. So the *claim* stands on independent
   evidence, but the specific evidence *files* for the two failures are not real captured output —
   calling them "preserved evidence" overstates what those two files contain. Not a blocker: no phase
   success criterion depends on these two files, and `preflight-pre-restart.txt` in the same directory
   does contain real captured output.
2. **Stray backup file** — `phase-02/infra/backups/l.plist.20260829T190342Z` (35 lines, truncated
   basename, timestamped 4 seconds before the real `com.ohama.litellm.plist.20260829T190346Z` backup)
   appears to be leftover cruft from an early/dry-run invocation of `apply_litellm_bind.sh` during
   development. `apply_litellm_bind.sh`'s current backup-naming logic (`$(basename "$PLIST").$(date ...)`)
   is correct and does not reproduce this truncation, so this is a one-time artifact from before the
   script settled, not an active bug. Cosmetic only.

### Human Verification Required

None. All three phase success criteria were confirmed via live, read-only inspection during this
verification session (plist contents, `launchctl print`, `ps`, `lsof`, and fresh executions of both
re-runnable gate scripts), so nothing here depends on subjective/visual/real-time judgment that only a
human could make.

### Gaps Summary

No gaps against the phase goal. All three ROADMAP success criteria are independently verified live:
(1) the concurrency cap is loaded and its queueing behavior is proven with a real before/after log-timing
contrast, not just HTTP 200 counts; (2) litellm is loopback-bound and LAN requests are refused at the
connection level, reproduced fresh in this session; (3) the full `flashnext` alias chain still returns
200 after both changes, reproduced fresh in this session via the standing regression gate. The
mid-phase async-bootout deviation was diagnosed correctly, fixed durably in the shared restart helper
(confirmed present in the live script), and the fix was exercised successfully before this phase's
decisive evidence was captured. The `~/local-llm-settings` mirror is byte-identical to both live plists,
`docs/infra-hardening.md` fully documents the changes and rollback path, and no forbidden verbs appear
in any of the phase's scripts. Two minor documentation-quality notes (empty evidence-preservation files
for the two failed restart attempts; one stray cruft backup file) are recorded above for completeness
but do not block phase completion — they carry no weight against the goal because the properties they
were meant to document are independently corroborated by evidence that does hold up.

---

_Verified: 2026-08-29T19:20:52Z_
_Verifier: Claude (gsd-verifier)_
