# Negative controls: proving verify_sandbox.sh can fail

Per 03-RESEARCH.md Pitfall 5, a sandbox that passes because it fails open is
the failure mode a shallow test cannot see. A Phase 3 verification without a
demonstrated ability to fail is unfalsifiable — a PASS from `verify_sandbox.sh`
would be no more informative than a script that always prints PASS. These
three controls make the standing gate falsifiable by construction: each one
deliberately breaks something `verify_sandbox.sh` is supposed to catch, and
records the gate catching it.

**Controls 1 and 2** attack the deny-side of the machinery directly: `Control
1` proves the profile sanity pre-check (the fail-open guard added in Task 1)
rejects a `fixture.sb` that has been replaced with nothing but
`(version 1)\n(allow default)\n` — no deny rules at all — before any case
even runs. `Control 2` proves that if that pre-check is bypassed
(`--negative-control-skip-precheck`), every one of the four Group F deny
cases (F2/F4/F5/F7) individually and correctly reports `FAIL not-denied`
against the same deny-less profile, rather than being fooled into a PASS —
this is `assert_denied.sh`'s own discrimination logic being exercised
against a sandbox that is provably not restricting anything.

**Control 3** attacks the canonicalization step specifically: it generates a
fixture profile with `gen_sandbox_profile.py --no-canonicalize` (a debug-only
flag added in this task that substitutes `os.path.abspath()` for
`os.path.realpath()`), which reproduces 03-RESEARCH.md's actual symlink
bypass by punching through the whitelist entry's symlink *spelling*
(`symlinked/link`) instead of its realpath'd target (`symlinked/real`). Case
`F6` then reads through the canonical path and MUST fail, because the
profile no longer has any rule that matches it — proving that if the
`realpath()` step in `gen_sandbox_profile.py` were ever accidentally
removed, this standing gate would catch the regression rather than silently
passing.

## Contents

- `control-1-precheck.txt` — `verify_sandbox.sh --negative-control`, full
  stdout. Ends with `NEGATIVE-CONTROL PASSED: profile sanity pre-check
  correctly rejected the fail-open profile`.
- `control-2-skip-precheck.txt` — `verify_sandbox.sh --negative-control
  --negative-control-skip-precheck`, full stdout. Shows all four
  `CASE F2-negctl/F4-negctl/F5-negctl/F7-negctl FAIL not-denied` lines and
  ends with `NEGATIVE-CONTROL PASSED: every Group F deny case reported FAIL
  not-denied`.
- `control-3-canonicalization.txt` — fixture manifest, the generated
  `--no-canonicalize` profile text (note it punches through
  `.../symlinked/link`, the symlink spelling, not `.../symlinked/real`), and
  the `F6` case run against it, ending `CASE F6 FAIL not-allowed rc=1` /
  `CONTROL-3 PASSED`.
- `run1-precheck-rejects/`, `run2-skip-precheck-not-denied/`,
  `run3-canonicalization-regression/` — the full per-run evidence
  directories (generated profiles, `assert_denied.sh` per-case transcripts)
  backing the three transcripts above.

## Reproducing

```
phase-03/sandbox/verify_sandbox.sh --negative-control
phase-03/sandbox/verify_sandbox.sh --negative-control --negative-control-skip-precheck
python3 phase-03/sandbox/gen_sandbox_profile.py \
  --allowed-repos phase-03/fixtures/allowed_repos.test.json \
  --protected-root "$HOME" --no-canonicalize --out /tmp/nocanon.sb
phase-03/sandbox/assert_denied.sh --label F6 --profile /tmp/nocanon.sb \
  --expect allow --expect-stdout 'CANON-CANARY-OK' \
  -- /bin/cat "$(cd phase-03/fixtures && pwd)/symlinked/real/canary.txt"
```

`python3 -m pytest phase-03/tests/ -q` still passes after adding
`--no-canonicalize` (11/11) — the debug flag did not change the generator's
default behavior or its tested contract.
