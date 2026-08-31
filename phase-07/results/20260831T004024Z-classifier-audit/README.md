# 20260831T004024Z classifier audit

Plan: 07-12 (phase 07-cline-bench-verification gap closure)

Forensic-only audit of `phase-07/bench/run_task.sh`'s `HTTP_400_SEEN` / `fail-context`
classifier against stored evidence in `bench/runs/20260830T122809Z-phase07-fix/` (post-fix, 4
tasks) and `bench/runs/20260830T093657Z-phase07/` (pre-fix, 1 task). Zero live bench runs, zero
model calls, zero writes under `bench/runs/` or `phase-07/bench/`.

Files in this directory:
- `failure-composition.tsv` — per-task, per-event-class counts and timestamps from the raw
  server-log slices.
- `match-provenance.md` — every literal substring that set `HTTP_400_SEEN` for each of the four
  post-fix tasks, classified true-signal / false-positive.
- `CLASSIFIER-AUDIT.md` — the verdict document (label-vs-evidence table, fail-infra/fail-context
  conflict resolution, classifier correctness verdict, milestone-claim impact, limits).
