# Phase 7 handoff to Phase 8

Generated: 2026-08-30T10:33:07Z

## Standing gate command

Phase 8 (or anyone else) can re-run this phase's own gate over the committed run directory at
any time, at zero model spend:

```bash
bash phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07
```

Expected result, unchanged since this sweep: `CASES 10/10`, `VERIFY_BENCH: PASS`.

## Host-posture escalation question — not applicable to this phase

Phases 4, 5, and 6 each kept visible an unresolved question: whether to flip the headless
wrapper's `--auto-approve` posture from its current `false` to `true`. This phase did not
decide that question, and could not have needed to — harbor's `cline-cli` agent runs with
full auto-approval **inside its own throwaway Docker container**, never through
`phase-03/sandbox/run_sandboxed.sh`, and never invokes the host `cline` binary at all. The
question is recorded here as **not applicable to Phase 7**, not as decided. It remains open
for whoever next changes the shipped host surfaces.

## kanban `~/.gitconfig` sandbox blocker — still open, untouched

Phase 6 handed over an unresolved blocker: the live kanban server's sandbox refuses to read
`~/.gitconfig`, so no git-based project can be registered with kanban under the current
sandbox posture (`docs/network-exposure.md` §9). This phase did not recur it and did not fix
it — Phase 7 registers nothing with kanban and never invokes it. It remains exactly as Phase 6
left it, unchanged, and is still Phase 3/8's item to resolve.

## Removal recipe location

The literal, complete removal recipe for everything this phase installed lives in
`docs/cline-bench.md` §7 (제거 방법):

```bash
uv tool uninstall harbor
rm -rf bench/cline-bench
docker image prune
```

`bench/runs/` (this phase's evidence, including the SBX-04 canary) is deliberately excluded
from that recipe.

## What Phase 8 inherits, in one place

- `docs/cline-bench.md` — the full Phase 7 record, including §4 한계 (limits) and §9 the
  sentences the manual must not contain.
- `bench/runs/20260830T093657Z-phase07/` — the one run directory, its `summary.md` (BCH-03),
  and `prompts/INDEX.md` (BCH-02).
- `phase-07/results/20260830T103307Z-phase-close/criteria.md` — the three ROADMAP criteria and
  the three BCH requirements, each mapped to evidence and a status that is not promoted beyond
  what actually happened.
- Both inherited open questions above, answered in writing rather than silently dropped.

---
*Phase: 07-cline-bench-verification*
