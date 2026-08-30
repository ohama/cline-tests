# phase-07 Task 3: live cline-bench task inventory + docker->litellm reachability

Run: 2026-08-30, `bench/cline-bench` @ `d1085569fb0ae3f9613957e6fc2706c6e2f7da9b`
(2025-12-11, "Update README.md" -- see Task 2's install evidence).

## Live task count

**The live pool is 12 task directories.** This is measured directly from
`bench/cline-bench/tasks/` (`ls bench/cline-bench/tasks | wc -l` = 12,
`awk -F'\t' 'NR>1{print}' tasks.tsv | wc -l` = 12, both agree). Running 5-8
of the 12 live tasks is **42-67% of the entire public cline-bench suite** --
a much larger share of everything available than "a small sample" would
imply, and worth saying plainly.

**This count is NOT 14.** 07-RESEARCH.md's own live count (captured
2026-08-30, the day before this install) was 14, itself already a
correction from an even older "~89-task pool" figure carried forward from
unrelated prior research. This measurement supersedes 07-RESEARCH.md's 14:
between that research pass and this plan's `git clone` (same day, a few
hours later), the live `cline/cline-bench` repo lost two task directories.
Treat 12 as the real, current denominator for any later plan in this
phase -- not 14, and certainly not 89.

## tasks.tsv

One row per live task directory, tab-separated: `dir_name`, `suffix`,
`difficulty`, `memory_mb`, `timeout_sec` (the `[agent]` value, not
`[verifier]`), `instruction_lines` (measured by python3, counting actual
lines in `instruction.md` rather than shelling out to `wc -l`, which
under-counts a file whose last line has no trailing newline). Sorted by
`memory_mb` ascending, then `instruction_lines` ascending, matching the
plan's own sort spec. Parsed with `tomllib` (stdlib, Python 3.11+; host
`python3` is 3.14.6) -- no TOML regexing.

## candidates.txt

Resolves each `CANDIDATE_SUFFIXES` entry (from `phase-07/bench/config.env`,
itself carried from 07-RESEARCH.md's research-derived preference order) to
its real directory name by exact suffix match against `tasks.tsv`. One
entry, `orpc-client-workspace`, does not resolve -- the live task's real
suffix is `orpc-client-migration` (dir
`01k8251zmv88p0hztas8htr6hw-orpc-client-migration`), evidently renamed
upstream between when the research was written and this checkout. It is
written as `UNRESOLVED orpc-client-workspace` and simply dropped from the
candidate pool, per the plan's own instruction -- not silently ignored,
not guessed at.

`SMOKE_SUFFIX` (`discord-trivia-approval-keyerror`) resolved successfully.

`candidates.txt`'s own header lists every live, non-excluded task absent
from the shortlist (`v-edit-workspace-tests`, `orpc-client-migration`,
`aenet-pytorch-pbc-neighborlist`) as `not-shortlisted: no measured
disqualifier` -- honest labelling per the plan's instruction, so 07-03's
decision plan can offer any of them as a legitimate `custom` pick if the
task budget has room, rather than these three simply vanishing from the
record.

## Excluded task (recorded here, not in candidates.txt -- see note below)

`terraform-azurerm-deployment-stacks`
(`01k7x8zyeg4nzx6ehdb0fg5gfx-terraform-azurerm-deployment-stacks`) is
present in `tasks.tsv` (`difficulty=hard`, `memory_mb=8192`,
`timeout_sec=3600.0`) and confirmed absent from `candidates.txt`'s resolved
candidate list. Reason: `memory_mb=8192` exceeds colima's whole 4 GiB VM
(`colima list`, this directory's `resources.txt`) outright -- and colima
must not be resized as an incidental side effect of this phase (house rule,
07-01-PLAN.md). This is `EXCLUDED_SUFFIXES` in `phase-07/bench/config.env`,
with the same reason recorded inline there.

**Why this section lives in README.md and not in candidates.txt itself:**
this plan's own `<verify>` block for this task asserts
`grep terraform .../candidates.txt` finds nothing -- while the same task's
`<action>` text, taken literally, would have this project write the
excluded task's name (which contains "terraform") directly into
`candidates.txt`'s own header note. Those two instructions are mutually
exclusive for the same file: house rule 9's WORDING-COLLISION TRAP,
encountered live during authoring rather than in existing prose. Resolution
chosen here: satisfy the literal, mechanically-checked `<verify>` grep (the
substance -- confirming the exclusion and recording its `memory_mb`
reason -- is preserved, just relocated to this sibling file in the same
`phase-07/results/<UTC>-inventory/` directory, one directory listing away).
Flagged explicitly in `07-01-SUMMARY.md` as a discovered plan defect, not
silently worked around.

## docker-reachability.txt

Reproduces 07-RESEARCH.md's live `host.docker.internal:4000` reachability
finding, on this exact machine, today: `docker run --rm alpine:3.20 ...
curl ... http://host.docker.internal:4000/v1/models` returns `HTTP 200`
with a real JSON model list containing `flashnext` (and this stack's other
live aliases). A read-only GET: no generation call, no model load, no
state change. Wildcard-bind count (`lsof -nP -iTCP -sTCP:LISTEN | grep -c
'\*:'`) is identical before and after (3 -> 3), and `:4000` remains bound
to `127.0.0.1` only, before and after -- proving reachability holds with
**no Phase 2 posture change**, exactly as 07-RESEARCH.md's own live test
already found the day before.

## resources.txt

`docker system df`, `colima list`, the `alpine:3.20` image size actually
pulled by the probe above (13.7MB), and free-disk before/after. Colima's
preexisting image/container/volume footprint (13 images, 12 containers)
predates this project entirely -- this Mac's colima instance is not
dedicated to this repo. Each selected cline-bench task will build its own
image from `environment/Dockerfile` when a later plan actually runs it
(not this plan) -- budget several GiB per task beyond the ~14MB this probe
consumed.

## Assertions at end of Task 3

Six live pids (46573/75548/48525/53894/99162/19669) unchanged, port 3000
unbound -- checked identically to Task 1/Task 2's own post-condition
sweeps.
