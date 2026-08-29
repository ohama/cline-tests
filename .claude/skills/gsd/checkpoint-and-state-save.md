---
name: gsd:checkpoint-and-state-save
description: Unified checkpoint handling and context preservation for execution
trigger: When executor hits checkpoint, when pausing work mid-phase
consumers:
  - gsd-executor
  - pause-work command
---

# Checkpoint and State Save

Unified protocol for handling checkpoints and preserving execution context.

## Checkpoint Types

| Type | Frequency | When to Use |
|------|-----------|-------------|
| human-verify | 90% | Visual/functional verification after automation |
| decision | 9% | Implementation choice requiring user input |
| human-action | 1% | Truly unavoidable manual step (2FA, email link) |

## Checkpoint Return Format

When hitting a checkpoint, return this EXACT structure:

```markdown
## CHECKPOINT REACHED

**Type:** [human-verify | decision | human-action]
**Plan:** {phase}-{plan}
**Progress:** {completed}/{total} tasks complete

### Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | [task name] | [hash] | [key files] |
| 2 | [task name] | [hash] | [key files] |

### Current Task

**Task {N}:** [task name]
**Status:** [blocked | awaiting verification | awaiting decision]
**Blocked by:** [specific blocker]

### Checkpoint Details

[Type-specific content - see below]

### Awaiting

[What user needs to do/provide]
```

## Type-Specific Content

### human-verify (most common)

```markdown
### Checkpoint Details

**What was built:**
[Description of completed work]

**How to verify:**
1. [Step 1 - exact URL/command]
2. [Step 2 - what to check]
3. [Step 3 - expected behavior]

### Awaiting

Type "approved" or describe issues to fix.
```

### decision

```markdown
### Checkpoint Details

**Decision needed:**
[What's being decided]

**Context:**
[Why this matters]

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| [option-a] | [benefits] | [tradeoffs] |
| [option-b] | [benefits] | [tradeoffs] |

### Awaiting

Select: [option-a | option-b | ...]
```

### human-action

```markdown
### Checkpoint Details

**Automation attempted:**
[What you already did via CLI/API]

**What you need to do:**
[Single unavoidable step]

**I'll verify after:**
[Verification command/check]

### Awaiting

Type "done" when complete.
```

## State Capture Protocol

Before returning checkpoint, capture complete state:

### 1. Execution State

```yaml
execution_state:
  phase: "08"
  plan: "02"
  task_current: 3
  tasks_total: 5
  tasks_completed:
    - task: 1
      name: "Create component"
      commit: "a1b2c3d"
      files: ["src/Chat.tsx"]
    - task: 2
      name: "Add API route"
      commit: "e4f5g6h"
      files: ["src/api/chat/route.ts"]
```

### 2. Deviation Log

```yaml
deviations:
  - rule: 1
    type: "Bug fix"
    description: "Fixed null check in auth"
    task: 2
    commit: "i7j8k9l"
```

### 3. Context for Continuation

```yaml
continuation_context:
  checkpoint_type: "human-verify"
  blocked_by: "Need visual verification of chat UI"
  resume_point: "task_3"
  user_decision: null  # Filled after user responds
```

## .continue-here File

Create for mid-plan resumption:

**Location:** `.planning/phases/XX-name/.continue-here.md`

```markdown
---
phase: "08"
plan: "02"
checkpoint_type: human-verify
paused: "2024-01-15T14:30:00Z"
---

# Continuation Point

**Resume:** Task 3 of 5
**Checkpoint:** human-verify (chat UI verification)

## Completed Tasks

| Task | Commit | Summary |
|------|--------|---------|
| 1 | a1b2c3d | Created Chat component |
| 2 | e4f5g6h | Added chat API route |

## Deviations Applied

1. [Rule 1] Fixed null check in auth middleware

## Context for Next Agent

- Chat component renders messages from mock data
- API endpoint created but not connected to DB
- Next: User verifies UI looks correct, then continue with DB integration
```

## STATE.md Update

Update session continuity section:

```markdown
## Session Continuity

Last session: 2024-01-15 14:30
Stopped at: Phase 08 Plan 02 Task 3 (checkpoint: human-verify)
Resume file: .planning/phases/08-chat/.continue-here.md

### Resume Context

- Awaiting: Visual verification of chat UI
- Next step: After approval, continue task 3 (DB integration)
```

## Authentication Gate Handling

Special case of human-action checkpoint:

```markdown
### Checkpoint Details

**Automation attempted:**
Ran `vercel --yes` to deploy

**Error encountered:**
"Error: Not authenticated. Please run 'vercel login'"

**What you need to do:**
1. Run: `vercel login`
2. Complete browser authentication

**I'll verify after:**
`vercel whoami` returns your account

### Awaiting

Type "done" when authenticated.
```

## Continuation Protocol

When spawned as continuation agent:

1. **Verify previous state:**
   ```bash
   # Check commits exist
   git log --oneline -5
   # Read .continue-here.md
   cat .planning/phases/XX-name/.continue-here.md
   ```

2. **Never redo completed tasks** - They're already committed

3. **Handle based on checkpoint type:**
   - human-action: Verify action worked, continue
   - human-verify: User approved, continue next task
   - decision: Implement selected option

4. **If hitting another checkpoint:**
   Return with ALL completed tasks (previous + new)

## Validation Before Return

Before returning checkpoint:

- [ ] Completed tasks table has all commits with hashes
- [ ] Current task clearly identified
- [ ] Blocked by is specific (not generic)
- [ ] Checkpoint details match type requirements
- [ ] Awaiting section is actionable
- [ ] .continue-here.md created
- [ ] STATE.md updated with resume context
