# phase-07/bench/install_bench.sh -- run 2026-08-30T08:52:01Z

## Commands run
```
git clone "https://github.com/cline/cline-bench.git" "/Users/ohama/projs/cline-tests/bench/cline-bench"
uv venv --python 3.13 "/Users/ohama/projs/cline-tests/bench/cline-bench/.venv"
uv tool install harbor
```

## cline-bench checkout
- URL: https://github.com/cline/cline-bench.git
- path: /Users/ohama/projs/cline-tests/bench/cline-bench
- commit: d1085569fb0ae3f9613957e6fc2706c6e2f7da9b 2025-12-11 13:39:22 +0900 Update README.md

## harbor
- version: 0.22.0
- executable: /Users/ohama/.local/bin/harbor

## uv / python
- uv version: uv 0.11.14 (Homebrew 2026-05-12 aarch64-apple-darwin)
- python 3.13 interpreter: /Users/ohama/.local/share/uv/python/cpython-3.13-macos-aarch64-none/bin/python3.13
- python 3.13 interpreter downloaded this run: no

## Disk
- free before: 1186 GiB
- free after: 1186 GiB
- measured delta: 0 GiB

## REMOVAL

Complete, literal removal recipe for everything this script installs:

```bash
uv tool uninstall harbor
rm -rf /Users/ohama/projs/cline-tests/bench/cline-bench
```

Deliberately NOT removed by that recipe: `bench/runs/` (this
phase's own evidence, including `bench/runs/CANARY.txt`, the SBX-04
sentinel) is never touched by this removal recipe.

Docker images pulled by task Dockerfiles (during a later plan's
`harbor run`) are reclaimed separately with `docker image prune`.
This script never runs prune automatically -- that is a deliberate,
separate decision for whoever is done using the images, not an
incidental side effect of installing or removing harbor/cline-bench.
