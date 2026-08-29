---
name: gsd:wave-executor
description: Wave-aware parallel execution of plans within a phase
trigger: execute-phase when multiple plans exist with wave assignments
consumers:
  - execute-phase orchestrator
---

# Wave Executor

Parallelize plan execution with dependency-aware wave grouping.

## Core Concept

Plans within a phase are assigned to waves. Plans in the same wave execute in parallel. Waves execute sequentially.

```
Wave 1: [Plan A, Plan B, Plan C]  ← Execute in parallel
         ↓ (wait for all)
Wave 2: [Plan D, Plan E]          ← Execute in parallel
         ↓ (wait for all)
Wave 3: [Plan F]                  ← Execute alone
```

## Wave Assignment

Waves are assigned in PLAN.md frontmatter during planning:

```yaml
---
phase: "08"
plan: "02"
name: "User Registration"
wave: 1
depends_on: []
---
```

### Wave Rules

1. **Wave 1:** Plans with no dependencies
2. **Wave N:** Plans that depend on Wave N-1 outputs
3. **Same wave:** Plans that can run independently

### Dependency Analysis

```markdown
Plan A (wave: 1, depends_on: [])
Plan B (wave: 1, depends_on: [])
Plan C (wave: 2, depends_on: [A])
Plan D (wave: 2, depends_on: [B])
Plan E (wave: 3, depends_on: [C, D])
```

## Execution Protocol

### Step 1: Load Phase Plans

```bash
ls .planning/phases/XX-name/*-PLAN.md
```

Parse each plan's frontmatter for wave assignment.

### Step 2: Group by Wave

```javascript
const waves = {
  1: ['08-01-PLAN.md', '08-02-PLAN.md'],
  2: ['08-03-PLAN.md'],
  3: ['08-04-PLAN.md', '08-05-PLAN.md']
};
```

### Step 3: Execute Wave

For each wave (in order):

```markdown
## Execute Wave {N}

Spawn executor agents in parallel:

<invoke name="Task">
  <parameter name="subagent_type">gsd-executor</parameter>
  <parameter name="prompt">Execute plan: 08-01-PLAN.md</parameter>
</invoke>

<invoke name="Task">
  <parameter name="subagent_type">gsd-executor</parameter>
  <parameter name="prompt">Execute plan: 08-02-PLAN.md</parameter>
</invoke>
```

### Step 4: Wait for Wave Completion

All plans in wave must complete before next wave:

```markdown
## Wave {N} Results

| Plan | Status | Duration | Commits |
|------|--------|----------|---------|
| 08-01 | complete | 3m 42s | 4 |
| 08-02 | complete | 2m 15s | 3 |

All plans in Wave {N} complete. Proceeding to Wave {N+1}.
```

### Step 5: Validate Between Waves

Before starting next wave:

1. Verify all SUMMARY.md files created
2. Check git commits exist
3. Validate outputs needed by next wave

```bash
# Check summaries exist
ls .planning/phases/XX-name/*-SUMMARY.md

# Verify commits
git log --oneline -10 | grep "({phase}-"
```

### Step 6: Handle Wave Failures

If any plan in wave fails:

```markdown
## Wave {N} Partial Failure

| Plan | Status | Issue |
|------|--------|-------|
| 08-01 | complete | - |
| 08-02 | failed | Checkpoint: human-action needed |

### Options

1. **Wait:** Resolve 08-02 checkpoint, then retry
2. **Skip:** Mark 08-02 as blocked, continue if no dependencies
3. **Abort:** Stop phase execution

### Impact Analysis

Plans depending on 08-02:
- 08-04 (wave 3) - BLOCKED
- 08-05 (wave 3) - Can proceed (no dependency)
```

## Orchestrator Integration

The execute-phase command uses this pattern:

```markdown
## Phase Execution

### Wave Analysis

```bash
# Extract wave assignments
for plan in .planning/phases/08-auth/*-PLAN.md; do
  grep "^wave:" "$plan" | head -1
done
```

### Execution

Wave 1: 2 plans (parallel)
Wave 2: 1 plan
Wave 3: 2 plans (parallel)

Total: 5 plans across 3 waves
```

## Parallel Agent Spawning

When spawning multiple agents for a wave:

```markdown
Use a SINGLE message with MULTIPLE Task tool calls:

<invoke name="Task">
  <parameter name="subagent_type">gsd-executor</parameter>
  <parameter name="model">{resolved model}</parameter>
  <parameter name="prompt">[Plan A content]</parameter>
</invoke>

<invoke name="Task">
  <parameter name="subagent_type">gsd-executor</parameter>
  <parameter name="model">{resolved model}</parameter>
  <parameter name="prompt">[Plan B content]</parameter>
</invoke>
```

This ensures true parallel execution.

## State Tracking

Update STATE.md with wave progress:

```markdown
## Current Position

Phase: 8 of 12 (Authentication)
Wave: 2 of 3
Plans in wave: 1/1 complete
Overall: 3/5 plans complete
```

## Edge Cases

### Single Plan Phase

No waves needed - execute directly.

### All Plans Wave 1

All independent - maximum parallelism.

### Linear Dependencies

Each plan depends on previous - all different waves (sequential).

### Checkpoint in Wave

If plan hits checkpoint mid-wave:
1. Other plans in wave continue
2. Checkpoint plan waits
3. Wave doesn't complete until all done (including checkpoint resolution)

## Benefits

1. **Speed:** Independent plans run in parallel
2. **Safety:** Dependencies respected via wave ordering
3. **Clarity:** Progress visible per wave
4. **Recovery:** Can restart from specific wave
