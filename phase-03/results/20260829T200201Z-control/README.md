# Unsandboxed control baseline

This directory is the control baseline for phase 3's sandbox denial tests,
captured WITHOUT any `sandbox-exec` wrapping.

**What this proves:** every filesystem operation the later denial tests
will assert as *blocked* by the Seatbelt profile is proven here to *work*
when unsandboxed, on this exact host, against these exact fixtures. Without
this baseline, a later "DENIED" result from `probe_fs.js` or
`assert_denied.sh` could just as easily be an artifact of a broken fixture,
a missing file, or a bad permission bit as it could be a real kernel
denial — there would be no way to tell the two apart. With this baseline on
record, every subsequent denial is meaningful: the same command, against
the same fixture, is known to have succeeded when nothing was restricting
it.

## Contents

- `fixture-manifest.txt` — stdout of `phase-03/sandbox/make_fixtures.sh`,
  one line per fixture (path + first line of content / symlink target).
- `probe-output.txt` — unsandboxed `phase-03/sandbox/probe_fs.js` run
  against the fixture tree. Every one of the 7 `PROBE` lines reads
  `SUCCEEDED` (including the forbidden reads/writes and the
  escape-symlink case), and the summary line reads
  `succeeded=7 denied=0 error=0`.
- `host-facts.txt` — `node --version`, `/usr/bin/sandbox-exec` presence,
  and `sw_vers -productVersion` for this host, at capture time.

## Reproducing

```
phase-03/sandbox/make_fixtures.sh
ALLOWED_PATH="<fixtures>/allowed" FORBIDDEN_PATH="<fixtures>/forbidden" \
  node phase-03/sandbox/probe_fs.js
```

`phase-03/sandbox/make_fixtures.sh` is re-run immediately after this
capture to clear the `probe-write.txt`/`probe-subwrite.txt` files the
control run created, restoring the fixture tree to its pristine state.
