# RED baseline — phase-12/verify_docs.sh against the real, uncorrected repository

This directory captures `bash phase-12/verify_docs.sh` run with `DOCS_ROOT` at its default (the
real repository root), BEFORE any of the eleven target documents were edited by wave 2.

**A RED result here (exit 5, `red-exit.txt`) is the expected and required outcome at this point
in the phase.** Do not mistake this captured failure for a defect in either the checker or the
documents — it is proof the checker's assertions are pointed at reality, not at nothing:

- `red.txt` — full stdout+stderr of the run (134 total cases, 50 passed, 84 failed).
- `red-exit.txt` — the observed exit code (`5`).

Every one of the eleven target documents produces at least one `FAIL[DOCS]` line in this run:
`docs/plan-act-reasoning-implementation.md`, `docs/plan-act-reasoning-design.md`,
`docs/plan-act-reasoning-diagrams.md`, `docs/manual/01-cli.md`, `docs/cline-config-pins.md`,
`docs/32k-compaction-policy.md`, `docs/cline-max-tokens-findings.md`,
`howto/fast-and-deep-mode.md`, `howto/thinking-and-reasoning-effort.md`,
`qanda/001-testing-plan-act-with-cline-cli.md`, `qanda/003-how-the-wrappers-work.md`. None
produced zero failures — there is no quiet pass here to investigate.

Wave 2's plans are done, per document, exactly when a fresh run of
`bash phase-12/verify_docs.sh` against the real repository stops naming that document in its
`FAIL[DOCS]` lines, and the sweep as a whole exits 0.
