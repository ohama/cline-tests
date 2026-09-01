# Phase 9 Plan 01 — RESULT.md

**Run directory:** `phase-09/results/20260901T014027Z-prb01-02`
**Generated:** 2026-09-01T01:44:48Z (UTC)

This file records fresh measurements for PRB-01 and PRB-02, produced
independently by this phase (09-01). It does **not** declare a gate verdict --
adjudication against 09-RESEARCH.md's prior numbers is deferred to plan 09-04.

## Stack-unchanged evidence

**Service PIDs (before):**
```
com.ohama.flashnext 46573
com.ohama.litellm 48525
com.ohama.role-shim 75548
```
**Service PIDs (after):**
```
com.ohama.flashnext 46573
com.ohama.litellm 48525
com.ohama.role-shim 75548
```

**Config hashes (before):**
```
12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c  /Users/ohama/local-llm-settings/config/litellm-config.yaml
5cf3800da31de8855b06e1d1cc85f415d68332dbee2625a587da2b4d8093e0a1  /Users/ohama/.cline/data/settings/providers.json
```
**Config hashes (after):**
```
12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c  /Users/ohama/local-llm-settings/config/litellm-config.yaml
5cf3800da31de8855b06e1d1cc85f415d68332dbee2625a587da2b4d8093e0a1  /Users/ohama/.cline/data/settings/providers.json
```

**Flake window:** CLEAN (count=0, scanned from log watermark 22440 to EOF)

## PRB-01 — fresh measurements (4 samples)

| label | http_code | content_len | reasoning_len | reasoning_nonempty |
|---|---|---|---|---|
| medium-1 | 200 | 14 | 179 | True |
| medium-2 | 200 | 14 | 179 | True |
| unspecified-1 | 200 | 14 | 0 | False |
| unspecified-2 | 200 | 14 | 0 | False |

Fresh result: `medium` yields a non-empty `reasoning` field on both samples;
the unspecified negative control yields an EMPTY `reasoning` field on both
samples. This is a clean discriminator between "thinking on at medium" and
"thinking always on regardless of effort" -- CONFIRMED, CLEAN flake window,
no retries needed. Full verdicts in `verdicts.tsv`.

## PRB-02 — fresh measurements (3 samples)

| endpoint | param | http_code | reasoning_nonempty |
|---|---|---|---|
| :8011 direct | enable_thinking:false | 200 | False |
| :4000 litellm (flashnext alias) | enable_thinking:false | 200 | False |
| :4000 litellm (flashnext alias) | enable_thinking:true (positive control) | 200 | True |

**Roadmap vs requirement discrepancy note:** ROADMAP Phase 9 success criterion 2
specifies `:8011` direct; REQUIREMENTS.md's PRB-02 text asks "does it pass
**litellm**" (i.e. `:4000`). Both were run rather than choosing one -- see rows
1 and 2 above.

### not-rejected vs applied

`enable_thinking: false` returning HTTP 200 through litellm's
unmodified `flashnext` alias is evidence that litellm does **not reject** the
parameter -- it is NOT, by itself, evidence that the parameter is **applied**,
because `false` is already the model's default and a no-op would look
identical on the wire. The positive control (`enable_thinking: true`, which
differs from the default) returned HTTP 200 with
reasoning_nonempty=True.

**Reading:** the `true` control DID change model behavior (non-empty
`reasoning` field appeared where the model's default -- and the `false`
sample above -- show none). This is evidence the parameter is **applied**, not
merely tolerated. Consequence for **CFG-12** (Phase 10): the evidence supports
building the `flashnext-act` alias with `enable_thinking` wired through --
the parameter has now been shown to move real model behavior through this
exact stack, not just pass litellm's schema check silently.

## Deliberate non-action

`cline` was **not** invoked in this phase. Both PRB-01 and PRB-02 were
answered at the HTTP layer only, per 09-RESEARCH.md Q1 ("Why (a) is not
recommended") -- pointing the real `cline` client at this stack is deferred
to Phase 10 (VRF-04).

## Adjudication deferred

Nothing in this file is a gate verdict. Comparison of these fresh numbers
against 09-RESEARCH.md's prior measurements, and the PRB-01/PRB-04 go/no-go
call for Phase 10, is plan 09-04's job.
