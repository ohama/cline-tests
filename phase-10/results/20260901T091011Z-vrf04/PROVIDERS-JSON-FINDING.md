# providers.json was touched by the real `cline` binary during this run

**Found:** during Task 1's postflight check, immediately after the two `cline` invocations.

## What happened

`postflight10` reported:

```
FAIL: providers.json sha256 changed (before=5cf3800da31de8855b06e1d1cc85f415d68332dbee2625a587da2b4d8093e0a1
      after=da53de13abdac56b283a8a834a0199760e359fff47a753113552ad368b3cf104)
```

Diffing the two files' contents (not just their hashes) shows the change is confined to a single
field:

```
< "updatedAt": "2026-08-31T23:37:50.252Z",
---
> "updatedAt": "2026-09-01T09:10:32.448Z",
```

on the `providers.openai-compatible` entry, timestamped to 09:10:32Z — inside the window of Run 1
(`cline -P openai-compatible -m flashnext-plan ...`, which started at 09:10:12Z and finished at
09:10:29Z; the write landed a few seconds after the agent loop's own `run_result` line). Every
other byte of the file, including the `model` field (still `"flashnext"`), `baseUrl`,
`contextWindow`, and the untouched `cline` provider entry, is identical.

`bash phase-01/config/verify_config.sh` was re-run against the mutated file and still exits 0 —
the assertions that script makes (`model=="flashnext"`, `baseUrl`, top-level `contextWindow==29000`,
no `models[]`, no `flashnext-codex` substring) never touch `updatedAt`, so the actual pinned
behavior this project depends on is unaffected.

## Why this happened (best explanation, not verified from source at 3.0.60)

`hard_constraints` #1 in `10-05-PLAN.md` cites `apps/cli/src/main.ts:1054-1055` and
`apps/cli/src/commands/program.ts:47-48,225` at **cli-v3.0.53** for the claim that `-m` overrides
the stored provider's model "for one invocation only," implying no persistence. That citation was
not re-verified against the installed **3.0.60** binary (the orchestrator's version-drift warning
for this exact plan). The observed behavior is consistent with cline touching/re-serializing the
selected provider's settings block on every session start (e.g. to record "this provider was last
used at time T") independent of whether `-m` was also passed -- the `model` value itself was not
changed to `flashnext-plan`, only the metadata timestamp was refreshed.

This is not a bug in this plan's own tooling. It is a real, load-bearing observation about the
installed `cline` binary's actual write behavior, exactly of the kind this whole plan exists to
surface (source-cited assumptions from one version do not automatically hold at another).

## Why it was not reverted

An attempt was made to restore `providers.json` to its exact pre-run bytes (verified offline to
reproduce the original sha256 `5cf3800d...` exactly, byte for byte). The write was blocked by this
execution environment's own permission system before it reached disk, both via a direct file copy
and via the file-write tool. This block was not worked around -- per this project's own standing
discipline about respecting guardrails around this exact file, that restriction was treated as
authoritative rather than something to route around. Reading and hashing the file was unaffected;
only writing to it was blocked.

**Net effect:** `providers.json`'s sha256 no longer equals `phase-10/BASELINE.txt`'s recorded value
as of the end of this plan. The field values `phase-01/config/verify_config.sh` hard-asserts are
unaffected and it still exits 0. This is reported plainly in `postflight.txt`, in
`VRF-04-OBSERVATION.md`, and in `10-05-SUMMARY.md` rather than silently left for a future plan to
discover as an unexplained divergence.
