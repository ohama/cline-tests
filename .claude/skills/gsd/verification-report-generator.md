---
name: gsd:verification-report-generator
description: Unified verification report format and presentation
trigger: After gsd-verifier completes, when creating VERIFICATION.md
consumers:
  - gsd-verifier
  - verify-work command
---

# Verification Report Generator

Generate consistent, structured verification reports.

## Report Structure

Every VERIFICATION.md follows this structure:

```markdown
---
phase: "XX-name"
verified: "YYYY-MM-DDTHH:MM:SSZ"
status: passed | gaps_found | human_needed
score: "N/M must-haves verified"
# Optional sections based on status
gaps: [...]           # If status: gaps_found
human_verification: [...] # If status: human_needed
re_verification: {...}    # If this is a re-verification
---

# Phase {X}: {Name} Verification Report

**Phase Goal:** {goal from ROADMAP.md}
**Verified:** {timestamp}
**Status:** {status}
**Score:** {N}/{M} must-haves verified

## Goal Achievement

### Observable Truths
{Truth verification table}

### Required Artifacts
{Artifact status table}

### Key Link Verification
{Wiring verification table}

### Requirements Coverage
{Requirements mapping table}

### Anti-Patterns Found
{Issues discovered}

### Human Verification Required
{Items needing human testing}

### Gaps Summary
{Narrative of what's missing}

---
_Verified: {timestamp}_
_Verifier: Claude (gsd-verifier)_
```

## Input Processing

Accept verification results in structured format:

```yaml
verification_input:
  phase: "08-auth"
  goal: "Users can register and login securely"

  must_haves:
    truths:
      - text: "User can register with email/password"
        status: verified
        evidence: "Registration endpoint works, user created in DB"
      - text: "User can login with credentials"
        status: failed
        evidence: "Login endpoint returns 500 error"

    artifacts:
      - path: "src/api/auth/register/route.ts"
        expected: "Registration endpoint"
        status: verified
        details: "45 lines, proper validation"
      - path: "src/api/auth/login/route.ts"
        expected: "Login endpoint"
        status: stub
        details: "Only 8 lines, returns hardcoded response"

    key_links:
      - from: "register/route.ts"
        to: "prisma.user.create"
        via: "Direct call"
        status: wired
      - from: "login/route.ts"
        to: "prisma.user.findUnique"
        via: "Expected query"
        status: not_wired
```

## Status Determination

### Status: passed

All checks pass:

```yaml
conditions:
  - all truths: verified
  - all artifacts: verified (exists + substantive + wired)
  - all key_links: wired
  - no blocker anti-patterns
```

### Status: gaps_found

One or more failures:

```yaml
conditions:
  - any truth: failed
  - OR any artifact: missing | stub
  - OR any key_link: not_wired
  - OR blocker anti-patterns found
```

### Status: human_needed

Automated checks pass but human verification required:

```yaml
conditions:
  - all automated checks: pass
  - AND items flagged for human testing
  - Cannot determine goal achievement without human
```

## Table Generation

### Observable Truths Table

```markdown
| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can register | ✓ VERIFIED | Endpoint works, user in DB |
| 2 | User can login | ✗ FAILED | Login returns 500 error |
| 3 | Session persists | ? UNCERTAIN | Needs browser testing |
```

### Required Artifacts Table

```markdown
| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/api/auth/register/route.ts` | Registration | ✓ VERIFIED | 45 lines, validated |
| `src/api/auth/login/route.ts` | Login | ✗ STUB | 8 lines, hardcoded |
| `src/utils/jwt.ts` | JWT utils | ⚠️ ORPHANED | Exists but not imported |
```

### Key Links Table

```markdown
| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| register/route.ts | prisma | user.create | ✓ WIRED | Direct call |
| login/route.ts | prisma | user.findUnique | ✗ NOT_WIRED | No query found |
| login/route.ts | jwt.ts | sign() | ✗ NOT_WIRED | Import missing |
```

## Gaps Formatting

When gaps found, format for `/gsd:plan-phase --gaps`:

```yaml
gaps:
  - truth: "User can login with credentials"
    status: failed
    reason: "Login endpoint is a stub returning hardcoded response"
    artifacts:
      - path: "src/api/auth/login/route.ts"
        issue: "Only 8 lines, no actual authentication logic"
    missing:
      - "Password verification using bcrypt"
      - "User lookup from database"
      - "JWT token generation on success"
      - "Error handling for invalid credentials"
```

### Grouping Related Gaps

When multiple truths fail from same root cause:

```markdown
### Gaps Summary

**Root Cause:** Login endpoint is a stub

This affects multiple truths:
- "User can login" - No actual login logic
- "Session persists" - No session creation without login
- "User can access protected routes" - No valid tokens issued

**Single fix needed:** Implement login endpoint properly
```

## Human Verification Section

Format for items needing human testing:

```markdown
### Human Verification Required

#### 1. Visual Appearance

**Test:** Open registration form in browser
**Expected:** Form matches design mockup, fields align properly
**Why human:** Visual layout cannot be verified programmatically

#### 2. Error Message Clarity

**Test:** Submit form with invalid email
**Expected:** Clear error message appears near email field
**Why human:** Error message quality is subjective

#### 3. Mobile Responsiveness

**Test:** Open on iPhone SE viewport
**Expected:** Form usable without horizontal scroll
**Why human:** Responsive behavior needs visual inspection
```

## Re-verification Section

When this is a follow-up verification:

```yaml
re_verification:
  previous_status: gaps_found
  previous_score: "2/5"
  previous_verified: "2024-01-15T10:00:00Z"
  gaps_closed:
    - "User can login with credentials"
    - "JWT token generated on success"
  gaps_remaining:
    - "Session persists across page reload"
  regressions: []  # Items that passed before but now fail
```

```markdown
## Re-verification Summary

**Previous:** 2/5 must-haves (2024-01-15)
**Current:** 4/5 must-haves

### Gaps Closed (2)
- ✓ User can login with credentials
- ✓ JWT token generated on success

### Gaps Remaining (1)
- ✗ Session persists across page reload

### Regressions (0)
No regressions detected.
```

## Score Calculation

```python
def calculate_score(truths):
    verified = sum(1 for t in truths if t.status == 'verified')
    total = len(truths)
    return f"{verified}/{total}"
```

## Output Examples

### Passed Report

```markdown
---
phase: "08-auth"
verified: "2024-01-18T14:30:00Z"
status: passed
score: "5/5 must-haves verified"
---

# Phase 8: Authentication Verification Report

**Status:** ✓ PASSED

All must-haves verified. Phase goal achieved.
Ready to proceed to next phase.
```

### Gaps Found Report

```markdown
---
phase: "08-auth"
verified: "2024-01-18T14:30:00Z"
status: gaps_found
score: "3/5 must-haves verified"
gaps:
  - truth: "User can login"
    status: failed
    ...
---

# Phase 8: Authentication Verification Report

**Status:** ✗ GAPS FOUND

3/5 must-haves verified. 2 gaps blocking goal achievement.

Run `/gsd:plan-phase --gaps` to create fix plans.
```

## Integration

The gsd-verifier uses this skill to:

1. Accept raw verification results
2. Determine overall status
3. Generate formatted tables
4. Structure gaps for replanning
5. Create VERIFICATION.md file
