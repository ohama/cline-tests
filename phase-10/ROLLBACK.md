# ROLLBACK.md — putting `/Users/ohama/agent-stack/litellm/config.yaml` back

Short and operational. Written from the rehearsal's actual recorded output, not from intent.
Companion to `phase-10/rollback_config.sh`, `phase-10/BASELINE.txt`, and `phase-10/CHANGE-BRIEF.md`.

## The two-step procedure (copy-pasteable)

**Step 1 — restore bytes** (sha-verified; refuses on a mismatch):

```
bash phase-10/rollback_config.sh phase-10/backups/config.yaml.20260901T053509Z
```

**Step 2 — restart, so the restored bytes actually take effect** (litellm does not reload its
config file on its own — restoring the bytes without this step leaves it serving whatever it
already had loaded in memory):

```
bash phase-02/infra/restart_service.sh com.ohama.litellm 4000 --timeout 60
```

Step 1 prints step 2 itself (but does not run it) on every successful restore, as a reminder.

## The backup

- Path: `phase-10/backups/config.yaml.20260901T053509Z`
- sha256: `12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c`
  (this is also the live config's own sha256 as of this backup — see `phase-10/BASELINE.txt`)
- Taken from `/Users/ohama/agent-stack/litellm/config.yaml`, which is not a git repository; this
  copy inside the project tree, committed to this repo, is the only history this file has.

## Evidence: Step 1 has already been rehearsed on the live path

Run directory: `phase-10/results/20260901T053807Z-rollback-rehearsal`
(commands, exit codes, and before/after hashes are recorded verbatim in that directory's
`rehearsal.log` and `rehearsal.tsv`)

**Positive rehearsal — restore over the still-pristine live path, 2026-09-01T05:38:26Z UTC:**

```
bash phase-10/rollback_config.sh phase-10/backups/config.yaml.20260901T053509Z
```

| | before | after |
|---|---|---|
| live config sha256 | `12e102cf...aaf599c` | `12e102cf...aaf599c` (unchanged) |
| `com.ohama.litellm` pid | `48525` | `48525` (unchanged — nothing restarted) |

Exit code: **0**. Mirror config sha256 (`~/local-llm-settings/config/litellm-config.yaml`) also
unchanged. The CFG-13 byte-identity witness (`head -n 34 | shasum -a 256`) reproduced the exact
value recorded in `BASELINE.txt`. Because the backup is byte-identical to the still-pristine live
file, this restore is a content no-op by construction — which is precisely why it was safe to run
for real, right now, before any mutation exists to roll back.

**Negative control — the integrity refusal actually fires, same session:**

```
cp -p phase-10/backups/config.yaml.20260901T053509Z \
  phase-10/results/20260901T053807Z-rollback-rehearsal/corrupt.bak
echo "# JUNK LINE APPENDED FOR NEGATIVE CONTROL" >> \
  phase-10/results/20260901T053807Z-rollback-rehearsal/corrupt.bak
bash phase-10/rollback_config.sh \
  phase-10/results/20260901T053807Z-rollback-rehearsal/corrupt.bak
```

Observed output:

```
REFUSED: integrity check failed. .../corrupt.bak's bytes do not match the sanctioned backup's recorded sha256.
  recorded (BASELINE.txt, sanctioned backup): 12e102cf66e50f5abc19f6d2dd1f322d548cee25549d65ddb9adbbcd2aaf599c
  actual   (.../corrupt.bak, just computed):  3757f031d624f054ccd14c8f7eb5a23a6d57b20640f548a99d080687e2206db4
  Live file NOT touched.
```

Exit code: **1** (non-zero). Live config sha256 and `com.ohama.litellm` pid both confirmed
unchanged immediately after — the corrupted backup was never written to the live path. This is the
Phase 9 standard applied here: the envelope is believed only once it has been seen to fail, not
merely asserted to.

Both rows (`positive-restore`, `negative-corrupted-backup`) are in
`phase-10/results/20260901T053807Z-rollback-rehearsal/rehearsal.tsv`.

## What `restart_service.sh` (step 2) does on failure by itself

`phase-02/infra/restart_service.sh` is the one sanctioned launchd restart helper in this project
(extended in place since Phase 2, never forked). Before touching anything it runs `plutil -lint`
on the plist; a malformed plist aborts before any `bootout` happens. After `bootout` it polls for
genuine teardown (the label unregistered AND, for a port-bound label, the port free) before
`bootstrap` — `bootstrap` racing an in-flight teardown fails opaquely with `Bootstrap failed: 5:
Input/output error`, which bit this project for real once already (flashnext's 104 GiB model takes
real seconds to tear down). On any non-zero exit at any step, a trap prints its own rollback
recipe to stderr (the plist backup `cp`, `plutil -lint`, `bootout`, `bootstrap`) — this is the
plist-level analog of the config-level rollback documented above; the two are independent (a
config restore does not touch the plist, and a plist rollback does not touch the config file).

## What is NOT rehearsed here, and why

**The restart half of the rollback (step 2 above) is deliberately not exercised in this plan.** It
is exercised for the first time in plan 10-03 Task 1, on the *unmodified* live config — so that if
`restart_service.sh` itself is broken against the `com.ohama.litellm` label today, for any reason
unrelated to this phase's changes, that is discovered while there is still nothing to undo. Running
it here, before the config has actually been mutated, would not prove anything about the restart
path that plan 10-03's own first restart doesn't already prove more cheaply — and it would spend a
restart (and its `:3484`/Telegram outage window) for no additional information.

**Summary of rollback coverage after this plan:**

| Half | Rehearsed here? | Evidence |
|---|---|---|
| Step 1 — sha-verified byte restore | Yes — positive AND negative control | `phase-10/results/20260901T053807Z-rollback-rehearsal/` |
| Step 2 — restart to take effect | No — deferred to plan 10-03 Task 1, on the unmodified config | (n/a yet) |
