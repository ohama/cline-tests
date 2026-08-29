---
name: gsd:verify-goal-backward
description: Goal-backward verification methodology for plans and code
trigger: Verifying plans achieve goals (plan-checker), code achieves goals (verifier), or cross-phase integration
consumers:
  - gsd-verifier
  - gsd-plan-checker
  - gsd-integration-checker
---

# Goal-Backward Verification

Start from the desired outcome and work backwards to verify achievement.

## Core Principle

**Task completion ≠ Goal achievement**

A task "create chat component" can be marked complete when the component is a placeholder. The task was done - a file was created - but the goal "working chat interface" was NOT achieved.

## The Three Questions

For any goal, ask:

1. **What must be TRUE** for this goal to be achieved?
2. **What must EXIST** for those truths to hold?
3. **What must be WIRED** for those artifacts to function?

## Verification Levels

### Level 1: Truths (Observable Behaviors)

Derive 3-7 observable facts from the user perspective:

```markdown
Goal: "Users can chat in real-time"

Truths:
- User can see existing messages
- User can send a message
- Messages appear without page refresh
- User sees other users' messages
- Conversation persists across sessions
```

Each truth should be testable by a human using the app.

### Level 2: Artifacts (Required Files)

For each truth, what must EXIST?

```markdown
Truth: "User can see existing messages"

Artifacts:
- src/components/Chat.tsx (renders message list)
- src/api/chat/route.ts (GET endpoint)
- prisma/schema.prisma (Message model)
```

Be specific: `src/components/Chat.tsx`, not "chat component"

### Level 3: Wiring (Connections)

For each artifact, what must be CONNECTED?

```markdown
Artifact: src/components/Chat.tsx

Wiring:
- Component → API: fetch('/api/chat') in useEffect
- API → Database: prisma.message.findMany()
- State → Render: messages.map() in JSX
```

This is where 80% of stubs hide. Pieces exist but aren't connected.

## Must-Haves Structure

Document in YAML for tooling:

```yaml
must_haves:
  truths:
    - "User can see existing messages"
    - "User can send a message"
  artifacts:
    - path: "src/components/Chat.tsx"
      provides: "Message list rendering"
    - path: "src/api/chat/route.ts"
      provides: "Chat API endpoint"
  key_links:
    - from: "Chat.tsx"
      to: "api/chat"
      via: "fetch in useEffect"
    - from: "api/chat"
      to: "prisma"
      via: "prisma.message.findMany()"
```

## Verification Status

For each item, determine status:

| Status | Meaning |
|--------|---------|
| VERIFIED | All supporting artifacts pass all checks |
| FAILED | Missing, stub, or unwired |
| UNCERTAIN | Can't verify programmatically (needs human) |

### Artifact Checks

```bash
# Level 1: Existence
[ -f "$path" ] && echo "EXISTS" || echo "MISSING"

# Level 2: Substantive (not a stub)
lines=$(wc -l < "$path")
grep -c -E "TODO|FIXME|placeholder|not implemented" "$path"

# Level 3: Wired (used somewhere)
grep -r "import.*$artifact_name" src/ | wc -l
```

### Stub Detection Patterns

```bash
# Universal stubs
grep -E "(TODO|FIXME|XXX|HACK|PLACEHOLDER)" "$file"
grep -E "return null|return \{\}|return \[\]" "$file"

# React component stubs
grep -E "return <div>.*</div>" "$file"  # Single div return
grep -E "onClick=\{\(\) => \{\}\}" "$file"  # Empty handler

# API route stubs
grep -E 'return Response.json\(\{ message:' "$file"  # Generic response
```

## Gap Output Format

When gaps found, structure for consumption by `/gsd:plan-phase --gaps`:

```yaml
gaps:
  - truth: "User can see existing messages"
    status: failed
    reason: "Chat.tsx exists but doesn't fetch from API"
    artifacts:
      - path: "src/components/Chat.tsx"
        issue: "No useEffect with fetch call"
    missing:
      - "API call in useEffect to /api/chat"
      - "State for storing fetched messages"
      - "Render messages array in JSX"
```

## Application by Consumer

### gsd-plan-checker

Verifies PLAN.md will achieve phase goal BEFORE execution:
- Derive must-haves from phase goal
- Check plan tasks cover all must-haves
- Identify gaps in plan coverage

### gsd-verifier

Verifies CODE achieves phase goal AFTER execution:
- Load must-haves (from frontmatter or derive)
- Check artifacts exist, are substantive, are wired
- Create VERIFICATION.md with results

### gsd-integration-checker

Verifies PHASES connect properly:
- Check cross-phase wiring (phase 2 uses phase 1 output)
- Verify E2E user flows complete
- Identify integration gaps

## Critical Rules

1. **Never trust SUMMARY claims** - Verify actual code
2. **Existence ≠ Implementation** - Check all 3 levels
3. **Structure gaps in YAML** - Enable automated replanning
4. **Flag for human when uncertain** - Visual, real-time, external services
