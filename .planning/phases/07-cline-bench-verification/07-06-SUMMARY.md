---
phase: 07-cline-bench-verification
plan: 06
subsystem: testing
tags: [cline, harbor, docker-compose, providers-json, zod-schema, gap-closure, diagnosis]

# Dependency graph
requires:
  - phase: 07-02
    provides: contextWindow/BASE_URL injection mechanism (VERDICT INJECTABLE, source-derived, never live-verified), cline-cw-overlay.yaml + cline-cw-providers.json
  - phase: 07-03
    provides: live smoke-run evidence that the injection mechanism does NOT take effect (0-byte flashnext slice, container's cline hit the real OpenAI endpoint)
provides:
  - "phase-07/bench/injection_probe.sh (574 lines): re-runnable, idempotent, house-contract probe ladder (R1 compose-merge-replay, R2 container-env-and-mount, R3 settings-parse, R4 reaches-flashnext)"
  - "phase-07/results/20260830T113923Z-injection-diag/DIAGNOSIS.md: ROOT_CAUSE schema-rejected, FIX_AVAILABLE yes, per-hypothesis table, ranked candidate fixes"
  - "Live, container-side (zero model cost) confirmation that cline-cw-providers.json fails cline's persisted-settings schema validation (missing required version/updatedAt fields), causing a silent fallback that explains 07-03's observed failure"
  - "A demonstrated-working candidate fix (add version:1 + per-provider updatedAt) that 07-07 can apply directly"
affects: [07-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "settings-file-round-trip-as-oracle: cline's own `config --json` subcommand has no clean non-interactive report mode, but its read()-then-persist round trip reveals schema-parse success/failure by what it WRITES BACK to the file -- a zero-model-cost way to observe a minified/compiled binary's internal validation outcome without a report-only CLI surface existing"
    - "same-platform-control-before-version-verdict: never attribute a cross-build binary-scan difference to version without first controlling for platform (packed both cline versions for the SAME linux-arm64 target before ruling H1 in or out)"

key-files:
  created:
    - phase-07/bench/injection_probe.sh
    - phase-07/results/20260830T113923Z-injection-diag/DIAGNOSIS.md
    - phase-07/results/20260830T113923Z-injection-diag/h1/H1-VERDICT.txt
    - phase-07/results/20260830T113923Z-injection-diag/h1/schema-requirements-finding.txt
  modified:
    - .gitignore (gitignored the two ~200MB unpacked scratch-cline-* binary trees)

key-decisions:
  - "H1_VERDICT: ruled-out. The confounded darwin-3.0.60-vs-linux-3.0.53 scan pair showed count deltas, so the mandatory same-platform control (packing @cline/cli-linux-arm64@3.0.60) was run; the clean version-only pair shows the same deltas, but direct inspection attributes them to one unrelated feature ('modes') added between versions -- the actual injection primitive is present and structurally identical in both."
  - "ROOT_CAUSE: schema-rejected (H4 confirmed). cline-cw-providers.json is missing two schema-required fields (top-level version:1, per-provider updatedAt ISO datetime); ProviderSettingsManager.read() uses a SAFE parse and silently falls back to an empty providers registry with no warning on validation failure, matching 07-03's observed 'hit the real OpenAI endpoint' failure exactly."
  - "FIX_AVAILABLE: yes, on live container-side evidence (not static reasoning): probe/R3's schema-fix-supplement demonstrated cline correctly retaining the full injected provider entry (baseUrl/apiKey/model/contextWindow) once the two missing fields are added."
  - "R4 (the one rung permitted to spend real, tiny model tokens) was attempted via --with-model-call but the invoking agent's own auto-mode permission classifier denied the command before any container started; left unrun rather than worked around, per the classifier's own instruction."

patterns-established:
  - "When a plan's anticipated CLI surface (a 'config/--version-class subcommand') doesn't actually exist as expected, empirically probe the real command surface live before reporting a plan defect -- a decisive substitute mechanism (the settings-file round-trip) was found and used instead of forcing the originally-imagined mechanism."

# Metrics
duration: ~37min
completed: 2026-08-30
---

# Phase 7 Plan 6: Injection Diagnosis (Gap Closure) Summary

**Diagnosed why 07-02's contextWindow/BASE_URL injection mechanism doesn't take effect: `cline-cw-providers.json` fails cline 3.0.53's persisted-settings schema (missing required `version`/`updatedAt` fields), so `ProviderSettingsManager.read()` silently falls back to an empty providers registry — confirmed live, container-side, at zero model cost, with a demonstrated-working fix (add the two missing fields).**

`ROOT_CAUSE: schema-rejected`. `FIX_AVAILABLE: yes`.

## Performance

- **Duration:** ~37 min
- **Started:** 2026-08-30T11:39:23Z
- **Completed:** 2026-08-30T12:16:12Z
- **Tasks:** 3/3
- **Files modified:** 1 new script (`injection_probe.sh`), 1 `.gitignore` addition, ~130 evidence files under `phase-07/results/20260830T113923Z-injection-diag/`

## Accomplishments

- **Settled H1 (version skew) definitively, against the real container-side build.** Packed `@cline/cli-linux-arm64@3.0.53` (confirmed the correct platform via `docker info`: aarch64/linux) into a scratch tree — hitting the exact trap the plan warned about firsthand (the bare `cline@3.0.53` package's `bin/cline` is a 4446-byte Node resolver script, not the ~142MB compiled ELF binary the platform optional-dep package actually contains). Scanned the genuine binary, found count deltas against the host's 3.0.60 build on two of five items, ran the mandatory same-platform control (`@cline/cli-linux-arm64@3.0.60`), and confirmed via direct inspection that the deltas are an unrelated feature ("modes") added between versions — the injection primitive itself (the `CLINE_PROVIDER_SETTINGS_PATH` resolver, `getProviderConfig()`, the persisted-settings schema and its silent-fallback `read()`) is present and structurally identical in both. **H1_VERDICT: ruled-out.**
- **Surfaced the real root cause while settling H1**, by directly reading the persisted-providers.json schema in both binaries: it requires a top-level `"version": 1` and a per-provider `"updatedAt"` ISO datetime, neither of which `cline-cw-providers.json` supplies — and `read()`'s `Ox.safeParse(i)` silently returns an empty providers registry on any validation failure, with no warning anywhere.
- **Built `phase-07/bench/injection_probe.sh`** (574 lines, re-runnable, idempotent, house `CHECK:`/`CASES`/exit-0-1-2 contract) implementing R1 (compose-merge-replay), R2 (container-env-and-mount), R3 (settings-parse), and R4 (reaches-flashnext, gated behind `--with-model-call`).
- **R1 extended 07-03's own coverage**: reconstructed harbor's REAL multi-file compose merge (including harbor's own auto-generated env/mounts override files, which land AFTER the injection overlay) and confirmed the bind mount survives intact even through an explicit empty `volumes: []` override — a case 07-03 hadn't tested (it only checked env-var survival and `docker exec` inheritance).
- **R2 ruled out H5 directly, live**: in a generic container with the real overlay applied, the env var is visible and the mounted file is readable as the container's own default user, with zero published ports.
- **R3 was the decisive rung, and required live improvisation once the plan's anticipated mechanism didn't exist**: cline 3.0.53 has no non-interactive CLI surface to report a named provider's resolved config (`config` always demands a TTY regardless of file validity; `auth` mutates rather than reports — confirmed live, not assumed). Instead, `cline config --json`'s own read-then-persist round trip was used as the oracle: it exercises the SAME `ProviderSettingsManager.read()` the real invocation path shares, and what it WRITES BACK reveals the parse outcome. Three shapes of the real file (as-is, stripped of `_comment`/`lastUsedProvider`, mounted at the container's default path) were all silently rejected and replaced with cline's own `"cline"` built-in provider defaults; a schema-fix supplement (adding the two missing fields) was correctly parsed and RETAINED in full (`baseUrl`/`apiKey`/`model`/`contextWindow` all intact).
- **Wrote `DIAGNOSIS.md`** with `ROOT_CAUSE: schema-rejected` / `FIX_AVAILABLE: yes`, a full H1–H5 disposition table, five ranked candidate fixes (the top one demonstrated working), what was ruled out and must not be revisited, and a cost ledger.
- **Re-swept all seven standing gates post-probe**, matching pre-probe signatures exactly (`verify_bench` 10/10, `verify_sandbox` 16/16 with SBX-04 PASS, `verify_services` 15/15, `verify_network` 24/24, `verify_no_regression` INF03 PASS, `verify_config` exit 0, `preflight` 11/11).

## Task Commits

Each task was committed atomically:

1. **Task 1: Pre-gates + settle H1 against the real cline 3.0.53 build** - `249d049` (feat)
2. **Task 2: Build injection_probe.sh and settle H2-H5 via the probe ladder** - `331a662` (feat)
3. **Task 3: DIAGNOSIS.md and post-probe standing gate sweep** - `7e9eb89` (docs)

## Files Created/Modified

- `phase-07/bench/injection_probe.sh` — the re-runnable probe ladder (R1–R4)
- `phase-07/results/20260830T113923Z-injection-diag/` — pre-gate transcripts, H1 scan evidence, per-rung probe evidence, `DIAGNOSIS.md`, post-gate transcripts
- `.gitignore` — added `phase-07/results/*/scratch-cline-*/` (the ~400MB of unpacked cline binaries used for H1's static scan; the scan/verdict text evidence is tracked, the raw binaries are not vendored)

## Decisions Made

- **H1_VERDICT: ruled-out**, derived from the mandatory same-platform control (`binary-scan-3.0.53.txt` vs `binary-scan-3.0.60-linux.txt`), not the confounded host comparison. Full rationale with quoted source in `phase-07/results/20260830T113923Z-injection-diag/h1/H1-VERDICT.txt`.
- **ROOT_CAUSE: schema-rejected** (H4 confirmed) — see DIAGNOSIS.md for the full evidentiary chain, decided from a live, container-side, zero-model-cost observation (the settings-file round-trip), not static source reading alone — deliberately avoiding 07-02's original mistake of a purely source-derived verdict.
- **FIX_AVAILABLE: yes** — the candidate fix (add `version`/`updatedAt` to `cline-cw-providers.json`) is demonstrated working, container-side. Recommended for 07-07 to apply directly (ranked fix #1 in DIAGNOSIS.md).
- **R4 left unrun**: attempted via `--with-model-call`, but the invoking agent's own auto-mode permission classifier denied the command before any container started. Per the classifier's own guidance, no workaround was attempted. This is a process constraint on this session, not a finding about the mechanism — R3's live container-side confirmation stands on its own and independently satisfies the plan's `FIX_AVAILABLE: yes` bar ("a rung showed cline resolving the injected baseUrl").
- **H3 (CLI args win over persisted settings) ruled out**, not merely deprioritized: confirmed twice (FINDING.md's static read of the adapter's fixed flag list, and this plan's live `cline --help`) that no CLI flag exists to set `baseUrl` on the real invocation shape at all — there is nothing for a CLI flag to "win" against.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — missing critical functionality] `.gitignore` needed an entry for the ~400MB unpacked cline scratch binaries**
- **Found during:** Task 1 (after packing/unpacking two ~150MB compiled binaries plus supporting webview assets)
- **Issue:** The plan requires "delete nothing from `$SCRATCH`" so later tasks can reuse it, but committing ~400MB of raw binary tarball contents into git would permanently bloat the repository — the established project convention (`bench/cline-bench/` gitignored in 07-01) is to install-not-vendor large third-party downloads.
- **Fix:** Added `phase-07/results/*/scratch-cline-*/` to `.gitignore`; every scan/verdict text file (the actual evidence) remains tracked.
- **Files modified:** `.gitignore`
- **Committed in:** `249d049` (Task 1)

**2. [Rule 1 — bug] docker compose project names must be lowercase; the initial `injection-probe-R2-$$` style names failed**
- **Found during:** Task 2 (first R2 run)
- **Issue:** `docker compose -p "injection-probe-R2-12345"` errors — compose project names must be lowercase alphanumeric/hyphens/underscores. The uppercase rung letter (matching the plan's own example naming, `injection-probe-R2-$$`) broke this.
- **Fix:** Split into a lowercase `proj` (compose project name) and a separately-cased `cname` (container name, which Docker DOES allow uppercase in, and which is what the plan's naming requirement actually targets) for R2/R3/R4.
- **Files modified:** `phase-07/bench/injection_probe.sh`
- **Committed in:** `331a662` (Task 2)

**3. [Rule 1 — bug] `-v` bind-mount source paths must be absolute; a relative `$RESULTS`-derived path broke variant (b)'s bind-mount comparison**
- **Found during:** Task 2 (first R3 run, variant b sub-step)
- **Issue:** `docker run -v "$dir/b-readonly-mount/providers.json:..."` failed with "includes invalid characters for a local volume name" because `$dir` (derived from a relative `--results-dir`) was a relative path, which `docker run -v` cannot resolve as a bind-mount source.
- **Fix:** Resolved `ro_dir` to an absolute path via `cd ... && pwd` before use.
- **Files modified:** `phase-07/bench/injection_probe.sh`
- **Committed in:** `331a662` (Task 2)

**4. [Rule 3 — blocking issue, discovered live] The plan's anticipated R3 mechanism ("a config/--version-class subcommand that does not contact a provider") does not exist in cline 3.0.53**
- **Found during:** Task 2 (building R3)
- **Issue:** Live testing showed `cline config --json` always requires an interactive TTY regardless of file validity, and `cline auth ...` is a mutating (not reporting) command — neither is a usable "report resolved config, no model contact" surface as the plan's `<action>` text anticipated with its own "e.g." hedge.
- **Fix:** Substituted a different, equally zero-model-cost mechanism: `cline config --json`'s own read-then-persist round trip (which exercises the SAME underlying `read()` the real invocation shares) reveals parse success/failure by what gets written back to the settings file. This is a genuine empirical substitution, not an improvised shortcut around a `<verify>` clause — the `<verify>` clause itself (variant line-count/format) is unaffected and was satisfied.
- **Files modified:** `phase-07/bench/injection_probe.sh`
- **Committed in:** `331a662` (Task 2)

---

**Total deviations:** 4 auto-fixed (1 Rule-2 gap-fill, 2 Rule-1 bugs, 1 Rule-3 blocking-mechanism substitution)
**Impact on plan:** All four were necessary to reach a working, evidence-backed diagnosis; none touched a live service, host posture, or spent host `cline`/`harbor run` budget. No scope creep — the R3 mechanism substitution stayed within the rung's stated goal ("settings-parse, no model") and delivered the exact H4-vs-H3 separation the plan asked for, just via a different, empirically-discovered CLI surface.

## Issues Encountered

- R4 (the one rung permitted a real, tiny model call) could not be executed: the invoking agent's own auto-mode permission classifier denied the `--with-model-call` bash invocation before any container started or any network reached flashnext. This is disclosed plainly in `DIAGNOSIS.md`'s cost ledger and `probe/R4/skipped.txt` rather than worked around. `FIX_AVAILABLE: yes` does not depend on R4 — R3's live, container-side confirmation (the schema-fix supplement correctly retaining the full injected entry) independently satisfies the plan's stated bar for a `yes` verdict.
- A large amount of live empirical exploration was required beyond the plan's literal text to find a working R3 mechanism (the anticipated non-interactive "config" surface doesn't exist as such) — documented above as deviation #4, not treated as a plan defect requiring a stop-and-report, since a decisive substitute was found and the underlying `<verify>` contract (variant format/count) was still satisfied.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **07-07** can apply the demonstrated-working fix directly: add `"version": 1` (top level) and a per-provider `"updatedAt"` ISO-8601 datetime string to `phase-07/bench/cline-cw-providers.json`. `DIAGNOSIS.md`'s ranked-fix section names the exact file/fields and points at `probe/R3/schema-fix-supplement-result-file.json` as the demonstrating evidence.
- **07-07** does NOT need to re-investigate H1/H2/H3/H5 — all four are ruled out with named evidence paths in `DIAGNOSIS.md`'s "what was ruled out and must not be revisited" section.
- **07-07** may want to run `bash phase-07/bench/injection_probe.sh --results-dir <new-dir> --with-model-call` directly (in a session without this session's classifier constraint) to obtain the live flashnext-log-slice confirmation R4 was designed to produce, before or as part of a real `harbor run`.
- `injection-probe-cline353:latest` (~2.4GB Docker image, cline 3.0.53 pre-installed) is left on disk from Task 2/3's R3 build step, available for a cheap re-run of R3/R4; not removed by this plan's own cleanup (only containers are guaranteed removed). Noted for 07-10's removal recipe.
- Six live pids (46573/75548/48525/53894/99162/19669), port 3000 (unbound), `bench/runs/CANARY.txt`, and `workspace/ALLOWED_REPOS.json`'s bench-exclusion were all unchanged across every task and the final gate sweep. Host `cline` invocations across the whole plan: 0. `harbor run` invocations: 0.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
