# Prompt + result artifact index

Generated: 2026-08-30T10:20:00Z
Run directory: `bench/runs/20260830T093657Z-phase07`

One row per attempted task. Paths are relative to this run directory. This is the file a reader
opens to see that BCH-02 is satisfied by prompt artifacts on disk, not by a transcript --
`agent/cline.txt` is listed below purely as a result artifact byte count, never as a substitute
for `agent-command.txt`.

| task | instruction.md | task.toml | agent-command.txt | system-prompt-probe.txt verdict | verifier/reward.txt | verifier/test-stdout.txt | agent/cline.txt |
| --- | --- | --- | --- | --- | --- | --- | --- |
| discord-trivia-approval-keyerror | `prompts/discord-trivia-approval-keyerror/instruction.md` (1442 bytes) | `prompts/discord-trivia-approval-keyerror/task.toml` (455 bytes) | `prompts/discord-trivia-approval-keyerror/agent-command.txt` (2066 bytes, fallback-extracted from `trial.log`'s `Running command:` block -- no `agent/command-*/` dir this trial, see `CAPTURE-GAPS.txt` history in `MANIFEST.txt`) | `SYSTEM_PROMPT_IN_TRANSCRIPT: no` (`prompts/discord-trivia-approval-keyerror/system-prompt-probe.txt`, 131 bytes) | `jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/verifier/reward.txt` (2 bytes, content `0`) | `jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/verifier/test-stdout.txt` (8087 bytes) | `jobs/discord-trivia-approval-keyerror/01k7a12sd1nk15j08e6x0x7v9e-disco__s4cVQPf/agent/cline.txt` (1340 bytes) |

## Notes

- `prompts/discord-trivia-approval-keyerror/CAPTURE-GAPS.txt` is present and **empty** (0 bytes)
  as of this run: `run_task.sh`'s trial.log-based fallback (07-03's Rule 2 deviation) recovered
  `agent-command.txt` successfully, so there is no live capture gap for this task. Its earlier,
  stale pre-fix entries were reset once the fallback landed -- see `MANIFEST.txt`'s own
  timestamped entries for that history.
- Verdict for this task is `fail-infra` (see `meta/discord-trivia-approval-keyerror.json`), so
  B3's escape valve is available in principle for this row -- but is **not needed** here, since
  `agent-command.txt` is non-empty and present regardless. The valve's actual applicability is
  determined by `verify_bench.sh` at run time, not asserted here.
- No other task has a meta record in this run directory (11 live-pool tasks remain `not-run`, per
  `summary.md`'s own table) -- there is exactly one row above by construction, and no task is
  omitted from this index.
