---
name: gsd:deviation-classifier
description: Automated classification and handling of deviations during execution
trigger: When gsd-executor encounters unexpected work (bugs, missing requirements, blockers)
consumers:
  - gsd-executor
  - quick command
---

# Deviation Classifier

Classify and handle deviations discovered during plan execution.

## Core Principle

**While executing tasks, you WILL discover work not in the plan. This is normal.**

Deviations are not failures - they're expected. The key is consistent classification and handling.

## The Four Rules

### Rule 1: Auto-fix Bugs

**Trigger:** Code doesn't work as intended

**Action:** Fix immediately, track for SUMMARY

**Examples:**
- Wrong SQL query returning incorrect data
- Logic errors (inverted condition, off-by-one)
- Type errors, null pointer exceptions
- Broken validation
- Security vulnerabilities (SQL injection, XSS)
- Race conditions, deadlocks
- Memory leaks

**Process:**
1. Fix the bug inline
2. Add/update tests to prevent regression
3. Verify fix works
4. Continue task
5. Track: `[Rule 1 - Bug] {description}`

**No user permission needed.** Bugs must be fixed for correct operation.

---

### Rule 2: Auto-add Missing Critical Functionality

**Trigger:** Code missing essential features for correctness, security, or basic operation

**Action:** Add immediately, track for SUMMARY

**Examples:**
- Missing error handling (no try/catch)
- No input validation
- Missing null/undefined checks
- No authentication on protected routes
- Missing authorization checks
- No CSRF protection
- No rate limiting on public APIs
- Missing required database indexes
- No logging for errors

**Process:**
1. Add the missing functionality
2. Add tests for the new functionality
3. Verify it works
4. Continue task
5. Track: `[Rule 2 - Missing Critical] {description}`

**Critical = required for correct/secure/performant operation**
**No user permission needed.**

---

### Rule 3: Auto-fix Blocking Issues

**Trigger:** Something prevents completing current task

**Action:** Fix immediately to unblock, track for SUMMARY

**Examples:**
- Missing dependency (package not installed)
- Wrong types blocking compilation
- Broken import paths
- Missing environment variable
- Database connection config error
- Build configuration error
- Missing file referenced in code
- Circular dependency

**Process:**
1. Fix the blocking issue
2. Verify task can now proceed
3. Continue task
4. Track: `[Rule 3 - Blocking] {description}`

**No user permission needed.** Can't complete task without fixing blocker.

---

### Rule 4: Ask About Architectural Changes

**Trigger:** Fix/addition requires significant structural modification

**Action:** STOP, return checkpoint, wait for user decision

**Examples:**
- Adding new database table (not just column)
- Major schema changes
- Introducing new service layer
- Switching libraries/frameworks
- Changing authentication approach
- Adding new infrastructure (queue, cache)
- Changing API contracts (breaking changes)
- Adding new deployment environment

**Process:**
1. STOP current task
2. Return checkpoint with decision needed
3. Include: what found, proposed change, why needed, impact, alternatives
4. WAIT for user decision
5. Fresh agent continues with decision

**User decision required.** These changes affect system design.

---

## Rule Priority

When multiple rules could apply:

```
1. If Rule 4 applies → STOP (architectural decision)
2. If Rules 1-3 apply → Fix automatically
3. If genuinely unsure → Apply Rule 4 (safer to ask)
```

## Edge Case Guidance

| Scenario | Rule | Rationale |
|----------|------|-----------|
| "This validation is missing" | 2 | Critical for security |
| "This crashes on null" | 1 | Bug |
| "Need to add table" | 4 | Architectural |
| "Need to add column" | 1 or 2 | Depends: fixing bug or adding critical field |
| "Missing dependency" | 3 | Blocking issue |
| "Should use different library" | 4 | Architectural choice |

**Key question:** "Does this affect correctness, security, or ability to complete task?"
- YES → Rules 1-3 (fix automatically)
- MAYBE → Rule 4 (return checkpoint)

## Classification Output Format

When tracking deviations, use this structure:

```yaml
deviations:
  - rule: 1
    type: "Bug fix"
    description: "Fixed case-sensitive email uniqueness check"
    task: 4
    commit: "a1b2c3d"
    files:
      - "src/api/auth.ts"

  - rule: 2
    type: "Missing critical"
    description: "Added password strength validation"
    task: 4
    commit: "a1b2c3d"
    files:
      - "src/utils/validation.ts"

  - rule: 3
    type: "Blocking issue"
    description: "Installed missing bcrypt dependency"
    task: 4
    commit: "e4f5g6h"
    files:
      - "package.json"
```

## SUMMARY Documentation

In SUMMARY.md, document deviations:

```markdown
## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed case-sensitive email uniqueness**
- **Found during:** Task 4
- **Issue:** Email comparison was case-sensitive, allowing duplicate registrations
- **Fix:** Added .toLowerCase() before comparison
- **Files modified:** src/api/auth.ts
- **Commit:** a1b2c3d

**2. [Rule 2 - Missing Critical] Added password strength validation**
- **Found during:** Task 4
- **Issue:** No minimum password requirements
- **Fix:** Added regex validation for 8+ chars, uppercase, number
- **Files modified:** src/utils/validation.ts
- **Commit:** a1b2c3d
```

Or if none: "None - plan executed exactly as written."

## Checkpoint Format for Rule 4

When architectural decision needed:

```markdown
## CHECKPOINT REACHED

**Type:** decision
**Plan:** {phase}-{plan}
**Progress:** {completed}/{total} tasks complete

### Checkpoint Details

**Decision needed:**
{What architectural change is being considered}

**Context:**
{Why this came up during execution}

**What I found:**
{Technical details of the issue}

**Proposed change:**
{What you would do}

**Impact:**
- Files affected: {list}
- Breaking changes: {yes/no}
- Rollback difficulty: {easy/medium/hard}

**Alternatives:**
1. {Alternative approach 1}
2. {Alternative approach 2}
3. Defer (add to future phase)

### Awaiting

Select: [proceed | alternative-1 | alternative-2 | defer]
```

## Integration with Executor

The executor applies these rules automatically during task execution:

1. Encounter unexpected situation
2. Classify using this skill's rules
3. Handle according to rule (fix or checkpoint)
4. Track deviation for SUMMARY
5. Continue or wait based on rule
