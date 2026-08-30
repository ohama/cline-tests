ROOT_CAUSE: schema-rejected
FIX_AVAILABLE: yes

# Injection Diagnosis (07-06)

## Summary

07-02's `VERDICT: INJECTABLE` (source-derived, never live-tested) does not take effect because
`phase-07/bench/cline-cw-providers.json` fails cline 3.0.53's persisted-settings schema
validation. The schema (identical in 3.0.53 and 3.0.60 -- see Task 1's H1-VERDICT.txt) requires a
top-level `"version": 1` and a per-provider `"updatedAt": <ISO8601 datetime>`, neither of which
our file supplies. `ProviderSettingsManager.read()` uses `Ox.safeParse(i)` -- a SAFE parse, not a
throwing one -- and on failure silently returns `cc()` = `{version:1, providers:{}}`, an EMPTY
providers registry, with **no warning, no exception, no log line anywhere**. With no
`openai-compatible` entry in that empty registry, cline has no configured `baseUrl` for the
provider harbor's adapter selects via `-P openai-compatible`, and falls through to the OpenAI
SDK's own default endpoint (`api.openai.com`) -- exactly matching 07-03's live observation
("Incorrect API key provided... platform.openai.com/account/api-keys").

This was demonstrated **live, container-side, at zero model cost** (R3, `probe/R3/`), not just
inferred from static reads: `cline config --json` exercises the SAME `ProviderSettingsManager.
read()`/write round-trip the real invocation path shares, and inspecting what it writes BACK
reveals the parse outcome. The unmodified `cline-cw-providers.json` (in three shapes -- as-is,
stripped of `_comment`/`lastUsedProvider`, and mounted at the container's own default path) is
uniformly rejected and silently replaced with cline's own built-in `"cline"` provider defaults
(`probe/R3/base.result-file.json`, `probe/R3/a.result-file.json`, `probe/R3/c.result-file.json`).
Adding the two missing required fields (`probe/R3/providers-schema-fixed.json`) makes cline
correctly parse AND RETAIN the full injected entry, unmodified, including `baseUrl`, `apiKey`,
`model`, and `contextWindow` (`probe/R3/schema-fix-supplement-result-file.json`).

## Per-hypothesis table

| Hyp | Verdict | Decided by | Evidence |
| --- | --- | --- | --- |
| H1 (version skew) | ruled-out | Task 1: same-platform 3.0.53-vs-3.0.60-linux binary scan | `h1/H1-VERDICT.txt` |
| H2 (overlay never landed) | ruled-out | 07-03 (env-var survival, docker-exec inheritance) + this plan's R1 (mount survives harbor's own realistic env/mounts override chain, not just a synthetic one) | `probe/R1/exported-config.yaml`, `probe/R1/notes.txt` |
| H3 (CLI args win over persisted settings) | ruled-out | FINDING.md avenue A (adapter's fixed 6-flag `run_flags` list has no baseUrl flag) + this plan's R3 (`cline --help` on the real invocation surface, `probe/R3/cline-help.txt`, confirms no `-b/--baseurl` exists at top level -- that flag exists ONLY on the separate, unused `auth` subcommand) | `probe/R3/cline-help.txt` |
| H4 (settings file read but rejected) | **CONFIRMED** | This plan's R3 (`cline config --json` read/persist round-trip, live, container-side, zero model cost) plus Task 1's static schema read (`h1/schema-requirements-finding.txt`) | `probe/R3/variants.txt`, `probe/R3/base.result-file.json`, `probe/R3/schema-fix-supplement-result-file.json` |
| H5 (file unreadable / needs write access) | ruled-out | This plan's R2 (env var visible, file readable as container's own root user, read-only bind mount) | `probe/R2/cat.txt`, `probe/R2/env-grep.txt` |

H4 is sufficient on its own to explain the observed 07-03 failure. H3 is not an additional
mechanism -- the CLI's fixed flag surface (`-P/-k/-m/--json/--yolo`, confirmed twice: FINDING.md's
static read and this plan's live `--help`) has no way to set `baseUrl` at all on the real
invocation shape, so there is nothing for a CLI flag to "win" against; the observed
apiKey-present/baseUrl-absent shape is the downstream CONSEQUENCE of H4 (no persisted entry
exists to supply a baseUrl), not a competing cause.

## Ranked candidate fixes

1. **Add the two schema-required fields to `phase-07/bench/cline-cw-providers.json`**: top-level
   `"version": 1`, and `"updatedAt": "<ISO8601 datetime>"` inside the `openai-compatible` provider
   entry (alongside the existing `settings` object). **Demonstrated working**, container-side,
   zero model cost: `probe/R3/schema-fix-supplement-result-file.json` shows cline retaining the
   full entry (baseUrl/apiKey/model/contextWindow) unchanged after the same read/persist
   round-trip that silently wipes the current file. Addresses H4 directly. Cost: a two-line JSON
   edit, zero new mechanism, zero new risk to house rule 6 (still never touches the host's real
   settings path). This is the fix 07-07 should apply.
2. *(Not required)* Stripping `_comment`/`lastUsedProvider` -- **demonstrated NOT sufficient
   alone** (R3 variant `a`, `probe/R3/a.result-file.json`, still rejected without the
   version/updatedAt fields present). Zod's default (non-strict) object parsing tolerates unknown
   keys like `_comment`; `lastUsedProvider` is itself a valid optional schema field. Neither is
   the actual rejection cause. **Untested candidate, likely a no-op**: removing them would not by
   itself fix anything, and is not recommended as the sole change.
3. **Untested candidate**: mounting at the container's own default settings path
   (`$HOME/.cline/data/settings/providers.json`) instead of relocating via
   `CLINE_PROVIDER_SETTINGS_PATH`. R3 variant `c` used this path with the UNFIXED file and still
   failed identically (`probe/R3/c.result-file.json`) -- the relocation mechanism itself is not
   the problem (consistent with H2 already being ruled out), so this candidate is expected to add
   no benefit over fix #1 and is not recommended.
4. **Untested candidate**: pinning the container to a different cline version. Not recommended --
   Task 1 confirmed the schema requirement (`version`/`updatedAt`) is IDENTICAL in 3.0.53 and
   3.0.60 (`h1/H1-VERDICT.txt`), so a version change would not avoid this requirement.
5. **Untested candidate**: a harbor `--agent-kwarg`/model-spec surface that sets `baseUrl`
   directly. FINDING.md avenue A/B (07-02) already established none exists for the `cline-cli`
   adapter; this plan's R3 independently re-confirmed cline's own top-level `--help` has no such
   flag either (`probe/R3/cline-help.txt`). Not recommended -- no such surface exists to try.

## What was ruled out and must not be revisited

- **H1 (version skew)**: settled with a real, same-platform (linux-arm64) 3.0.53-vs-3.0.60
  binary-scan control. The injection primitive (`CLINE_PROVIDER_SETTINGS_PATH` resolver,
  `getProviderConfig()`, the persisted-settings schema and its silent-fallback `read()`) is
  present and structurally identical in both versions -- do not re-litigate a build mismatch.
  Evidence: `h1/H1-VERDICT.txt`, `h1/binary-scan-3.0.53.txt`, `h1/binary-scan-3.0.60-linux.txt`.
- **H2 (compose merge / env inheritance)**: 07-03 already independently verified the
  docker-compose overlay merge preserves the env var and `docker exec` inherits container env
  without re-passing `-e`. This plan's R1 extends that coverage to the MOUNT specifically
  surviving harbor's own real (not synthetic) env/mounts override files, including an empty
  `volumes: []` override placed after our overlay. Do not re-verify either half again.
  Evidence: `probe/R1/exported-config.yaml`, `probe/R1/unexported-config.yaml`.
- **H5 (file unreadable)**: R2 directly confirmed the mounted file is readable as the container's
  own default user with a read-only bind mount and zero published ports. Do not re-test
  readability.
  Evidence: `probe/R2/cat.txt`, `probe/R2/id.txt`, `probe/R2/whoami.txt`.
- **H3 (CLI args bypass)**: no CLI flag exists on the real invocation shape to set `baseUrl` at
  all (confirmed twice, statically and live). This is not a live "override" mechanism to guard
  against when applying fix #1 -- there is nothing competing with the persisted settings file for
  `baseUrl` specifically.

## Cost ledger

- Host `cline` invocations: **0**.
- `harbor run` invocations: **0**.
- Container-side model requests issued: **0**. R4 (the one rung permitted to make a real, tiny
  model request against flashnext) was attempted via `--with-model-call` but the invoking agent's
  own auto-mode permission classifier denied the command before any container started or any
  network call was made; left unrun per the classifier's own instruction not to attempt a
  workaround (`probe/R4/skipped.txt`). This is a process constraint on this diagnosis session, not
  a finding about the mechanism -- `bash phase-07/bench/injection_probe.sh --results-dir <dir>
  --with-model-call` remains available to obtain the live flashnext-log-slice confirmation
  directly, in a session without this constraint.
- Container-side `cline` invocations (not counted against the host budget): several, all via
  `docker exec`/`docker run` against throwaway `injection-probe-*` containers, each removed
  immediately after. None reached a real model endpoint -- `cline config --json` never triggers
  generation, and R4 (the only rung that would) was not run.
