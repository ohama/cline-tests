---
name: gsd:codebase-mapper-orchestrator
description: Coordinate parallel codebase analysis agents with direct-write capability
trigger: /gsd:map-codebase command, brownfield detection in new-project
consumers:
  - map-codebase command
  - new-project command (brownfield)
---

# Codebase Mapper Orchestrator

Coordinate parallel mapper agents to analyze codebase and produce structured documents.

## Purpose

Analyze existing codebase to produce `.planning/codebase/` documents that inform planning and execution.

## Output Documents

| Document | Focus Area | Content |
|----------|------------|---------|
| STACK.md | Technology | Languages, frameworks, dependencies |
| ARCHITECTURE.md | Structure | Patterns, layers, data flow |
| CONVENTIONS.md | Standards | Naming, formatting, practices |
| TESTING.md | Quality | Test setup, coverage, patterns |
| STRUCTURE.md | Organization | Directory layout, key files |
| INTEGRATIONS.md | External | APIs, services, databases |
| CONCERNS.md | Issues | Tech debt, risks, improvements |

## Parallel Execution Strategy

### Four Focus Areas

Spawn 4 mapper agents in parallel, each with specific focus:

| Agent | Focus | Outputs |
|-------|-------|---------|
| Mapper 1 | tech | STACK.md |
| Mapper 2 | arch | ARCHITECTURE.md, STRUCTURE.md |
| Mapper 3 | quality | TESTING.md, CONVENTIONS.md |
| Mapper 4 | concerns | CONCERNS.md, INTEGRATIONS.md |

### Direct Write Pattern

Each mapper writes documents directly (not returning content to orchestrator):

```markdown
## Mapper Agent Instructions

Write your analysis directly to the target files:
- .planning/codebase/STACK.md
- etc.

DO NOT return document content in your response.
Return only confirmation of files written.
```

This reduces orchestrator context usage significantly.

## Orchestration Protocol

### Step 1: Ensure Directory

```bash
mkdir -p .planning/codebase
```

### Step 2: Spawn Parallel Mappers

Use SINGLE message with MULTIPLE Task calls:

```markdown
<invoke name="Task">
  <parameter name="subagent_type">gsd-codebase-mapper</parameter>
  <parameter name="prompt">
Focus: tech
Output: .planning/codebase/STACK.md
Analyze: Languages, frameworks, dependencies, build tools
  </parameter>
</invoke>

<invoke name="Task">
  <parameter name="subagent_type">gsd-codebase-mapper</parameter>
  <parameter name="prompt">
Focus: arch
Output: .planning/codebase/ARCHITECTURE.md, STRUCTURE.md
Analyze: Patterns, layers, data flow, directory organization
  </parameter>
</invoke>

<invoke name="Task">
  <parameter name="subagent_type">gsd-codebase-mapper</parameter>
  <parameter name="prompt">
Focus: quality
Output: .planning/codebase/TESTING.md, CONVENTIONS.md
Analyze: Test setup, coverage, naming conventions, code style
  </parameter>
</invoke>

<invoke name="Task">
  <parameter name="subagent_type">gsd-codebase-mapper</parameter>
  <parameter name="prompt">
Focus: concerns
Output: .planning/codebase/CONCERNS.md, INTEGRATIONS.md
Analyze: Tech debt, risks, external services, APIs
  </parameter>
</invoke>
```

### Step 3: Wait for Completion

All mappers must complete before proceeding.

### Step 4: Verify Outputs

Check all 7 documents created with reasonable content:

```bash
# Verify files exist
for doc in STACK ARCHITECTURE STRUCTURE TESTING CONVENTIONS INTEGRATIONS CONCERNS; do
  if [ -f ".planning/codebase/$doc.md" ]; then
    lines=$(wc -l < ".planning/codebase/$doc.md")
    echo "$doc.md: $lines lines"
  else
    echo "$doc.md: MISSING"
  fi
done
```

Minimum expected lines:
- STACK.md: 20+
- ARCHITECTURE.md: 30+
- STRUCTURE.md: 20+
- TESTING.md: 15+
- CONVENTIONS.md: 15+
- INTEGRATIONS.md: 10+
- CONCERNS.md: 10+

### Step 5: Commit Results

```bash
git add .planning/codebase/
git commit -m "docs: map codebase structure and patterns

Documents created:
- STACK.md: Technology stack analysis
- ARCHITECTURE.md: System patterns and layers
- STRUCTURE.md: Directory organization
- TESTING.md: Test infrastructure
- CONVENTIONS.md: Code standards
- INTEGRATIONS.md: External services
- CONCERNS.md: Technical debt and risks
"
```

## Mapper Agent Guidelines

Each mapper agent should:

### 1. Explore Systematically

```bash
# File structure
find . -type f -name "*.ts" | head -50
find . -type f -name "*.tsx" | head -50

# Package analysis
cat package.json | jq '.dependencies, .devDependencies'

# Config files
ls -la *.config.* .*.rc .*.json 2>/dev/null
```

### 2. Sample Key Files

Read representative files, not exhaustive:

```bash
# Entry points
cat src/index.ts 2>/dev/null || cat src/main.ts 2>/dev/null

# Key components (sample 3-5)
head -50 src/components/*.tsx 2>/dev/null | head -200
```

### 3. Write Structured Output

Follow templates from `.claude/get-shit-done/templates/codebase/`:

```markdown
---
analyzed: "YYYY-MM-DDTHH:MM:SSZ"
scope: "full" | "partial"
---

# {Document Title}

## Overview

{High-level summary}

## Details

{Structured analysis}

## Recommendations

{Actionable insights}
```

### 4. Return Confirmation Only

```markdown
## Mapper Complete

**Focus:** tech
**Files written:**
- .planning/codebase/STACK.md (45 lines)

**Key findings:**
- Next.js 14 with App Router
- TypeScript strict mode
- Prisma ORM with PostgreSQL
```

## Partial Refresh

For updating specific areas:

```markdown
/gsd:map-codebase --focus=tech

Only spawns Mapper 1 (tech focus)
Updates STACK.md only
```

## Integration with New-Project

For brownfield projects:

```markdown
1. Detect existing code (package.json, src/, etc.)
2. If brownfield:
   - Invoke codebase-mapper-orchestrator
   - Wait for completion
   - Use results to inform ROADMAP
3. Continue with project initialization
```

## Error Handling

### Mapper Fails

```markdown
## Mapper Failure

**Agent:** Mapper 2 (arch)
**Error:** Context exhausted before completion

**Recovery:**
1. Check partial output in .planning/codebase/
2. Re-run failed mapper with smaller scope
3. Or: manually complete missing sections
```

### Incomplete Output

If document too short:

```markdown
## Verification Warning

TESTING.md: 8 lines (expected 15+)

**Possible causes:**
- No test infrastructure found
- Limited test files in codebase

**Action:** Review manually or accept as-is
```

## Benefits

1. **Speed:** 4 agents analyze in parallel
2. **Context efficiency:** Direct write, not orchestrator relay
3. **Completeness:** 7 structured documents
4. **Reusability:** Can refresh specific areas
5. **Integration:** Informs planning and execution
