---
name: gsd:atomic-git-workflow
description: Per-task commit protocol with deviation tracking for GSD execution
trigger: After each task completes in gsd-executor, for any code work needing atomic commits
consumers:
  - gsd-executor
  - quick command
---

# Atomic Git Workflow

Encapsulates per-task commit protocol with consistent formatting and deviation tracking.

## Core Principle

**Commit outcomes, not process.**

Git log should read like a changelog of what shipped, not a diary of planning.

## Commit Points

| Event | Commit? | Why |
|-------|---------|-----|
| PROJECT.md + ROADMAP created | YES | Project initialization |
| PLAN.md created | NO | Intermediate |
| RESEARCH.md created | NO | Intermediate |
| **Task completed** | YES | Atomic unit of work |
| **Plan completed** | YES | Metadata (SUMMARY + STATE) |
| Handoff created | YES | WIP state preserved |

## Task Commit Protocol

After each task completion:

### 1. Identify Modified Files

```bash
git status --short
```

### 2. Stage Only Task-Related Files

Stage each file individually - NEVER use `git add .` or `git add -A`:

```bash
git add src/api/auth.ts
git add src/types/user.ts
```

### 3. Determine Commit Type

| Type | When to Use |
|------|-------------|
| feat | New feature, endpoint, component |
| fix | Bug fix, error correction |
| test | Test-only (TDD RED phase) |
| refactor | Code cleanup, no behavior change |
| perf | Performance improvement |
| docs | Documentation changes |
| style | Formatting, linting |
| chore | Config, tooling, dependencies |

### 4. Craft Commit Message

Format: `{type}({phase}-{plan}): {task-description}`

```bash
git commit -m "feat(08-02): create user registration endpoint

- POST /auth/register validates email and password
- Checks for duplicate users
- Returns JWT token on success
"
```

### 5. Record Commit Hash

```bash
TASK_COMMIT=$(git rev-parse --short HEAD)
```

Track for SUMMARY.md generation.

## TDD Commits

Each TDD task produces 2-3 atomic commits:

```bash
# RED - Failing test
git add src/__tests__/jwt.test.ts
git commit -m "test(07-02): add failing test for JWT generation

- Tests token contains user ID claim
- Tests token expires in 1 hour
"

# GREEN - Implementation
git add src/utils/jwt.ts
git commit -m "feat(07-02): implement JWT generation

- Uses jose library for signing
- Includes user ID and expiry claims
"

# REFACTOR (if needed)
git add src/utils/jwt.ts
git commit -m "refactor(07-02): extract token config to constants"
```

## Deviation Tracking

Document deviations applied during task execution:

```yaml
deviations:
  - rule: 1  # Bug fix
    description: "Fixed case-sensitive email uniqueness"
    task: 4
    commit: "a1b2c3d"
    files: ["src/api/auth.ts"]

  - rule: 2  # Missing critical
    description: "Added input validation for password"
    task: 4
    commit: "a1b2c3d"
    files: ["src/api/auth.ts"]

  - rule: 3  # Blocking issue
    description: "Installed missing bcrypt dependency"
    task: 4
    commit: "e4f5g6h"
    files: ["package.json"]
```

## Plan Completion Commit

After all tasks, one metadata commit:

```bash
# Stage planning docs (if commit_docs: true)
git add .planning/phases/XX-name/{phase}-{plan}-PLAN.md
git add .planning/phases/XX-name/{phase}-{plan}-SUMMARY.md
git add .planning/STATE.md

# Commit
git commit -m "docs(08-02): complete user registration plan

Tasks completed: 4/4
- Create registration endpoint
- Add password hashing
- Add duplicate check
- Add JWT response

SUMMARY: .planning/phases/08-auth/08-02-SUMMARY.md
"
```

## Planning Docs Config

Check if planning docs should be committed:

```bash
COMMIT_PLANNING_DOCS=$(node .claude/hooks/gsd-config.js commit_docs true)
# Auto-detect gitignored (overrides config)
git check-ignore -q .planning 2>/dev/null && COMMIT_PLANNING_DOCS=false
```

If `COMMIT_PLANNING_DOCS=false`, skip git operations for planning files.

## Example Git Log

Per-task commits create granular, bisectable history:

```
# Phase 04 - Checkout
1a2b3c docs(04-01): complete checkout flow plan
4d5e6f feat(04-01): add webhook signature verification
7g8h9i feat(04-01): implement payment session creation
0j1k2l feat(04-01): create checkout page component

# Phase 03 - Products
3m4n5o docs(03-02): complete product listing plan
6p7q8r feat(03-02): add pagination controls
9s0t1u feat(03-02): implement search and filters
```

## Benefits

**Context engineering for AI:**
- Git history becomes primary context source
- `git log --grep="{phase}-{plan}"` shows all work
- `git diff <hash>^..<hash>` shows exact changes per task

**Failure recovery:**
- Task 1 committed, Task 2 failed → Next session retries task 2
- Can `git reset --hard` to last successful task

**Debugging:**
- `git bisect` finds exact failing task
- `git blame` traces line to specific task
- Each commit independently revertable

## Anti-Patterns

**Never commit:**
- PLAN.md alone (commit with plan completion)
- RESEARCH.md (intermediate)
- "Fixed typo in roadmap"

**Always commit:**
- Each task completion (feat/fix/test)
- Plan completion metadata (docs)
- Project initialization (docs)

## Validation Checklist

Before each commit:

- [ ] Only task-related files staged
- [ ] Commit type matches change
- [ ] Message format: `{type}({phase}-{plan}): {description}`
- [ ] Body lists key changes (3-5 bullets)
- [ ] Commit hash recorded for SUMMARY
- [ ] Deviations logged if any
