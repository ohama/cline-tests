# 20260831T010013Z-reclassify

Plan: `07-13` (gap closure, wave 12). Purely forensic and offline -- zero live bench runs,
zero model calls. `bench/runs/*/meta/*.json` is read-only evidence; this plan writes
`meta-reclassified/` sidecars alongside it (already committed in the prior task commit under
`bench/runs/`) and never mutates the originals.

## Contents

- `fixtures/` -- four small synthetic files used as negative/positive controls against
  `phase-07/bench/classify_lib.sh`'s detector functions. Not real bench evidence.
- `negative-controls.txt` -- expected-vs-actual result for all four controls.
- `RECLASSIFICATION.md` -- old-vs-new verdict table for every stored run instance, plus the
  restated corrected counts.

## Safety snapshot (start of this task)

- Six live pids (checked 3 of the 6 protected ones directly): `46573`
  (`.venv-mlxvlm-new/bin/python3`), `48525` (`agent-stack/venv/bin/python`), `75548`
  (`agent-stack/venv/bin/python`) -- unchanged from the values recorded throughout 07-11/07-12.
- `providers.json` sha256: `534151965f81089b11d96d4af0b8a115b558f38efd42e82a9edd2a76f44fc214`
  (matches the recorded pre-gap hash).
- `colima status` -> "colima is not running".
- `lsof -i :3000` -> empty (port unbound).
- `git status --short bench/runs/*/meta/` -> empty (originals byte-identical) both before and
  after `reclassify_runs.sh` ran (see the prior task commit's message for the exact
  verification transcript).

No live service was started, restarted, or stopped by this task. No `harbor`/`cline` process
was invoked.
