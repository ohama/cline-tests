---
name: gsd:context-discussion-guide
description: Structured questioning for phase context gathering
trigger: /gsd:discuss-phase when generating phase-specific gray areas
consumers:
  - discuss-phase command
---

# Context Discussion Guide

Structured approach to gathering phase context through adaptive questioning.

## Purpose

Before planning a phase, understand user's vision through targeted questions about gray areas - things that are unclear from the goal alone.

## Process Overview

```
1. Analyze phase goal
2. Identify domain (UI/API/DB/etc.)
3. Generate 3-4 phase-specific gray areas
4. Conduct 4-question deep dive per area
5. Offer continuation or next area
6. Capture decisions with rationale
7. Generate CONTEXT.md
```

## Gray Area Generation

### Step 1: Parse Phase Goal

From ROADMAP.md:

```markdown
## Phase 3: User Authentication
**Goal:** Implement secure user registration and login
```

### Step 2: Identify Domain

| Domain | Indicators | Common Gray Areas |
|--------|------------|-------------------|
| UI | components, pages, forms | Layout, UX flows, responsiveness |
| API | endpoints, routes, handlers | Error handling, validation, auth |
| DB | schema, models, queries | Relationships, indexes, migrations |
| Auth | login, session, token | Strategy, providers, permissions |
| Integration | external, service, API | Rate limits, fallbacks, caching |

### Step 3: Generate Phase-Specific Gray Areas

**Not generic questions.** Specific to this phase's goal.

Bad (generic):
- "How should errors be handled?"
- "What about security?"

Good (phase-specific):
- "Should registration require email verification?"
- "JWT vs session cookies for auth tokens?"
- "Allow social login (Google, GitHub) or email-only?"

### Step 4: Prioritize Gray Areas

Rank by impact on implementation:

```markdown
1. **Auth strategy** - Affects entire architecture
2. **Registration flow** - Determines user onboarding
3. **Password requirements** - Impacts validation logic
4. **Session management** - Affects frontend state
```

## Question Framework

### The 4-Question Deep Dive

For each gray area, ask up to 4 questions:

#### Question 1: Preference

"What's your preference for {gray area}?"

```markdown
**Auth token strategy:**
- JWT with refresh tokens
- Session cookies with httpOnly
- Both (JWT for API, session for web)
```

#### Question 2: Context

"Any specific requirements or constraints?"

```markdown
"Do you need to support mobile apps or just web?"
"Any compliance requirements (SOC2, HIPAA)?"
```

#### Question 3: Edge Cases

"How should we handle {edge case}?"

```markdown
"What happens if refresh token expires during active use?"
"Should inactive sessions auto-logout? After how long?"
```

#### Question 4: Validation

"Just to confirm - {summary of decision}?"

```markdown
"So we're going with JWT + refresh tokens, 15min access / 7d refresh,
silent refresh before expiry. Is that correct?"
```

### Adaptive Flow

Don't ask all 4 if not needed:

```
User gives detailed answer to Q1
→ Skip Q2, go to Q3 (edge cases)

User says "whatever you recommend"
→ Provide recommendation with rationale
→ Ask if they want to discuss alternatives
```

## Domain-Specific Question Templates

### Authentication Domain

```markdown
#### Gray Area: Auth Strategy

1. **Token type:** JWT vs session cookies vs hybrid?
2. **Token lifetime:** Short (15m) vs long (7d)? Refresh strategy?
3. **Edge case:** What if user is on multiple devices?
4. **Confirm:** {summary}

#### Gray Area: Registration Flow

1. **Verification:** Email verification required?
2. **Fields:** Just email/password or more info upfront?
3. **Edge case:** What if email already exists?
4. **Confirm:** {summary}
```

### UI Domain

```markdown
#### Gray Area: Layout Approach

1. **Structure:** Single page vs multi-page? Sidebar vs top nav?
2. **Responsiveness:** Mobile-first or desktop-first?
3. **Edge case:** What if content doesn't fit? Scroll vs paginate?
4. **Confirm:** {summary}

#### Gray Area: Interaction Style

1. **Feedback:** Inline validation vs submit validation?
2. **Loading:** Skeleton vs spinner vs optimistic?
3. **Edge case:** Long operations - progress indicator?
4. **Confirm:** {summary}
```

### API Domain

```markdown
#### Gray Area: Error Handling

1. **Format:** Standard error structure? Include stack traces?
2. **Codes:** HTTP codes only or custom error codes?
3. **Edge case:** Rate limiting behavior?
4. **Confirm:** {summary}

#### Gray Area: Validation

1. **Location:** Controller vs middleware vs shared?
2. **Library:** Zod vs Yup vs custom?
3. **Edge case:** Nested object validation?
4. **Confirm:** {summary}
```

## Decision Capture

### During Discussion

Track each decision:

```yaml
decisions:
  - area: "Auth strategy"
    question: "Token type"
    decision: "JWT with refresh tokens"
    rationale: "Need to support mobile app later"
    alternatives_considered:
      - "Session cookies - rejected for mobile support"

  - area: "Registration flow"
    question: "Email verification"
    decision: "Required, but allow limited access first"
    rationale: "Reduce friction while ensuring valid emails"
```

### Format in CONTEXT.md

```markdown
---
phase: "03-auth"
discussed: "2024-01-15T10:00:00Z"
areas_covered: 4
decisions_made: 8
---

# Phase 3: Authentication Context

## Vision Summary

{High-level summary of user's vision for this phase}

## Decisions

### Auth Strategy

**Decision:** JWT with refresh tokens
**Rationale:** Need mobile app support in future
**Alternatives considered:** Session cookies (rejected for mobile)

**Details:**
- Access token: 15 minutes
- Refresh token: 7 days
- Silent refresh before expiry
- Revocation on logout

### Registration Flow

**Decision:** Email verification required, limited access until verified
**Rationale:** Balance friction reduction with email validity

**Details:**
- User can register and use basic features immediately
- Email verification required for full access
- Verification link expires after 24 hours
- Resend available after 60 seconds

## Out of Scope

{Things explicitly excluded from this phase}

- Social login (deferred to Phase 5)
- 2FA (deferred to Phase 6)
- Password reset (handled in Phase 4)

## Open Questions

{Anything still unclear - to be resolved during planning}

- Exact rate limiting numbers TBD based on load testing
```

## Conversation Flow Example

```markdown
## Phase 3: User Authentication

I need to understand your vision before planning. Let me ask about
a few gray areas.

### Auth Token Strategy

**What's your preference?**
- A) JWT with refresh tokens (good for API/mobile)
- B) Session cookies (simpler, web-only)
- C) Hybrid (both)
- D) Not sure, recommend something

> User: A, we might add a mobile app later

**Got it - JWT with refresh. Any specific requirements?**
- Token lifetimes?
- Refresh strategy (silent vs manual)?

> User: Silent refresh, maybe 15 min access?

**15 min access with silent refresh. For refresh token:**
- 7 days (typical)
- 30 days (remember me)
- Custom

> User: 7 days is fine

**Perfect. Edge case: if user logs out on one device, should all
devices be logged out?**

> User: No, just that device

**Confirmed:**
- JWT + refresh tokens
- 15min access / 7d refresh
- Silent refresh before expiry
- Per-device logout only

Continue to next area? [Registration Flow / Skip to summary]
```

## Best Practices

1. **Be specific** - Generic questions waste time
2. **Offer options** - Easier than open-ended
3. **Explain trade-offs** - Help informed decisions
4. **Summarize often** - Confirm understanding
5. **Know when to stop** - 3-4 areas is enough
6. **Capture everything** - CONTEXT.md is the record
