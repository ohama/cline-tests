---
name: gsd:state-reconstruction
description: Recover project state when STATE.md is missing but artifacts exist
trigger: resume-project workflow when STATE.md missing but ROADMAP.md exists
consumers:
  - resume-work command
  - resume-project workflow
---

# State Reconstruction

Recover complete project state from artifacts when STATE.md is missing or corrupted.

## When to Use

```
STATE.md missing or corrupted
  + ROADMAP.md exists
  + Phase directories exist
  = Can reconstruct state
```

## Reconstruction Process

### Step 1: Verify Artifacts Exist

```bash
# Check for roadmap
[ -f .planning/ROADMAP.md ] && echo "ROADMAP exists"

# Check for phase directories
ls -d .planning/phases/*/ 2>/dev/null | wc -l
```

If no ROADMAP.md → Cannot reconstruct (project not initialized)

### Step 2: Parse ROADMAP.md

Extract phase information:

```bash
# Count total phases
grep -c "^## Phase" .planning/ROADMAP.md

# List phases with status
grep -E "^## Phase|Status:" .planning/ROADMAP.md
```

Build phase list:

```yaml
phases:
  - number: 1
    name: "Foundation"
    goal: "Set up project scaffold"
  - number: 2
    name: "Authentication"
    goal: "Implement user auth"
  # ...
```

### Step 3: Analyze Phase Directories

For each phase directory:

```bash
PHASE_DIR=".planning/phases/01-foundation"

# Count plans
ls "$PHASE_DIR"/*-PLAN.md 2>/dev/null | wc -l

# Count completed (has SUMMARY)
ls "$PHASE_DIR"/*-SUMMARY.md 2>/dev/null | wc -l

# Check for verification
ls "$PHASE_DIR"/*-VERIFICATION.md 2>/dev/null

# Check for continuation
ls "$PHASE_DIR"/.continue-here.md 2>/dev/null
```

### Step 4: Determine Current Position

**Algorithm:**

```
1. Find phases with incomplete plans (PLAN without SUMMARY)
2. If found → Current phase = first incomplete
3. If all complete → Check for unverified phases
4. If all verified → Project complete or awaiting next milestone
```

```bash
# Find first phase with incomplete plans
for dir in .planning/phases/*/; do
  plans=$(ls "$dir"*-PLAN.md 2>/dev/null | wc -l)
  summaries=$(ls "$dir"*-SUMMARY.md 2>/dev/null | wc -l)
  if [ "$plans" -gt "$summaries" ]; then
    echo "Incomplete phase: $dir"
    break
  fi
done
```

### Step 5: Check for Checkpoint State

Look for `.continue-here.md` files:

```bash
find .planning/phases -name ".continue-here.md" -type f
```

If found, parse for:
- Which plan was in progress
- Which task was reached
- What checkpoint type
- What user action needed

### Step 6: Reconstruct Decisions

Extract decisions from completed SUMMARYs:

```bash
# Find decision sections in summaries
for summary in .planning/phases/*/*-SUMMARY.md; do
  grep -A 10 "## Decisions Made" "$summary" 2>/dev/null
done
```

Build decisions list:

```yaml
decisions:
  - phase: 1
    plan: 2
    decision: "Use jose library for JWT"
    rationale: "Better ESM support than jsonwebtoken"
```

### Step 7: Reconstruct Progress

Calculate overall progress:

```bash
# Total plans across all phases
total_plans=$(find .planning/phases -name "*-PLAN.md" | wc -l)

# Completed plans (have SUMMARY)
completed_plans=$(find .planning/phases -name "*-SUMMARY.md" | wc -l)

# Progress percentage
progress=$((completed_plans * 100 / total_plans))
```

### Step 8: Generate STATE.md

Create reconstructed STATE.md:

```markdown
---
reconstructed: true
reconstructed_at: "YYYY-MM-DDTHH:MM:SSZ"
---

# Project State (Reconstructed)

> This STATE.md was reconstructed from artifacts.
> Some session history may be missing.

## Current Position

Phase: {current} of {total} ({phase name})
Plan: {current plan} of {plans in phase}
Status: {In progress / Awaiting verification / Phase complete}
Last activity: (reconstructed from git)

Progress: {progress bar}

## Accumulated Decisions

| Phase | Decision | Rationale |
|-------|----------|-----------|
{extracted decisions}

## Blockers / Concerns

{extracted from verification gaps if any}

## Session Continuity

Last session: (unknown - reconstructed)
Stopped at: {derived from artifacts}
Resume file: {.continue-here.md path if exists}

### Reconstruction Notes

- STATE.md was missing, reconstructed from:
  - ROADMAP.md (phase structure)
  - Phase directories (plan/summary counts)
  - SUMMARY.md files (decisions)
  - .continue-here.md (checkpoint state)
  - Git history (last activity)
```

### Step 9: Validate Reconstruction

Before using reconstructed state:

```bash
# Verify git history matches
git log --oneline -20 | grep -E "\([0-9]+-[0-9]+\):"

# Check commit counts match summary claims
for summary in .planning/phases/*/*-SUMMARY.md; do
  # Extract claimed commits from summary
  # Verify they exist in git log
done
```

## Recovery Scenarios

### Scenario A: Clean State

- All phases sequential
- No incomplete plans
- No checkpoints

→ Straightforward reconstruction

### Scenario B: Mid-Plan Checkpoint

- `.continue-here.md` exists
- Some tasks completed, some pending

→ Reconstruct with checkpoint context

### Scenario C: Verification Gaps

- VERIFICATION.md shows gaps
- Replanning may be needed

→ Reconstruct and flag for gap closure

### Scenario D: Corrupted Artifacts

- Mismatched plan/summary counts
- Missing referenced files

→ Reconstruct what's possible, flag issues

## Output Format

Return reconstruction result:

```markdown
## State Reconstruction Complete

**Status:** success | partial | failed

### Reconstructed Position

- Phase: 3 of 5 (Products)
- Plan: 2 of 3 in current phase
- Overall: 7/12 plans complete (58%)

### Checkpoint Found

{If .continue-here.md exists}
- Plan: 03-02
- Task: 3 of 5
- Type: human-verify
- Awaiting: Visual verification of product list

### Decisions Recovered

{count} decisions extracted from SUMMARY files

### Issues Found

{List any inconsistencies or missing data}

### Recommended Action

{What to do next based on reconstructed state}
```

## Integration with Resume-Work

The resume-work command uses this when STATE.md missing:

```markdown
1. Check for STATE.md
2. If missing but .planning/ exists:
   - Invoke state-reconstruction skill
   - Generate reconstructed STATE.md
   - Continue with normal resume flow
3. If reconstruction fails:
   - Report what's missing
   - Suggest recovery options
```
