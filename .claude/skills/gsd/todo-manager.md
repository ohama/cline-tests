---
name: gsd:todo-manager
description: Unified todo lifecycle - capture, list, archive, promote to phase
trigger: /gsd:add-todo, /gsd:check-todos, or internal todo workflows
consumers:
  - add-todo command
  - check-todos command
---

# Todo Manager

Unified todo lifecycle management for GSD projects.

## Directory Structure

```
.planning/todos/
├── pending/
│   ├── 001-add-dark-mode.md
│   ├── 002-optimize-queries.md
│   └── 003-fix-mobile-layout.md
└── done/
    ├── 001-setup-ci.md
    └── 002-add-logging.md
```

## Todo Format

Each todo is a markdown file with frontmatter:

```markdown
---
id: "003"
created: "2024-01-15T10:30:00Z"
area: "ui"
priority: "medium"
source: "conversation"
related_phase: null
---

# Fix Mobile Layout

## Context

During testing, noticed the sidebar overlaps content on mobile devices.

## Details

- Sidebar should collapse to hamburger menu on < 768px
- Content should be full-width on mobile
- Navigation should be bottom-fixed on mobile

## Acceptance Criteria

- [ ] Sidebar collapses on mobile
- [ ] Content readable on iPhone SE
- [ ] No horizontal scroll

## Notes

Discovered while testing Phase 3 outputs.
```

## Capture Protocol

### Step 1: Generate ID

```bash
# Find next ID
last_id=$(ls .planning/todos/pending/*.md 2>/dev/null |
          sed 's/.*\/\([0-9]*\)-.*/\1/' |
          sort -n | tail -1)
next_id=$(printf "%03d" $((last_id + 1)))
```

### Step 2: Determine Area

Areas help categorize todos:

| Area | Examples |
|------|----------|
| ui | Frontend, components, styling |
| api | Backend, endpoints, services |
| db | Schema, queries, migrations |
| infra | Deployment, CI/CD, config |
| docs | Documentation, README |
| test | Test coverage, fixtures |
| perf | Performance, optimization |
| security | Auth, validation, vulnerabilities |

### Step 3: Set Priority

| Priority | Meaning |
|----------|---------|
| high | Blocking or urgent |
| medium | Should do soon |
| low | Nice to have |

### Step 4: Check Roadmap Overlap

```bash
# Check if todo overlaps with existing phase
grep -l "dark mode\|theme" .planning/ROADMAP.md
```

If overlap found, set `related_phase` and note in todo.

### Step 5: Write Todo File

```bash
filename="${next_id}-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]').md"
# Write to .planning/todos/pending/$filename
```

## List Protocol

### Show Pending Todos

```bash
echo "## Pending Todos"
echo ""
for todo in .planning/todos/pending/*.md; do
  id=$(grep "^id:" "$todo" | cut -d'"' -f2)
  area=$(grep "^area:" "$todo" | cut -d'"' -f2)
  priority=$(grep "^priority:" "$todo" | cut -d'"' -f2)
  title=$(grep "^# " "$todo" | head -1 | sed 's/^# //')
  created=$(grep "^created:" "$todo" | cut -d'"' -f2)

  # Calculate age
  age_days=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))

  echo "- [$id] **$title** ($area, $priority) - ${age_days}d old"
done
```

### Filter Options

```markdown
/gsd:check-todos --area=ui
/gsd:check-todos --priority=high
/gsd:check-todos --older-than=7d
```

## Route Protocol

When user selects a todo to work on:

### Option A: Quick Task

For small, self-contained work:

```markdown
Route to /gsd:quick with todo context

1. Read todo details
2. Pass to quick command
3. Mark todo as done after completion
```

### Option B: Add to Phase

For larger work that should be planned:

```markdown
Route to /gsd:add-phase

1. Create new phase from todo
2. Set related_phase in todo
3. Keep todo as reference until phase complete
```

### Option C: Insert into Current Phase

If fits current phase scope:

```markdown
1. Add as task to current plan
2. Mark todo as in-progress
3. Complete after task done
```

## Archive Protocol

When todo is completed:

### Step 1: Update Frontmatter

```yaml
---
id: "003"
created: "2024-01-15T10:30:00Z"
completed: "2024-01-18T14:00:00Z"
completed_by: "phase-04-plan-02"
area: "ui"
priority: "medium"
---
```

### Step 2: Move to Done

```bash
mv .planning/todos/pending/003-fix-mobile-layout.md \
   .planning/todos/done/003-fix-mobile-layout.md
```

### Step 3: Commit

```bash
git add .planning/todos/
git commit -m "chore(todos): complete todo #003 - fix mobile layout"
```

## Aging and Cleanup

### Show Stale Todos

```bash
# Todos older than 14 days
for todo in .planning/todos/pending/*.md; do
  created=$(grep "^created:" "$todo" | cut -d'"' -f2)
  age_days=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
  if [ "$age_days" -gt 14 ]; then
    echo "STALE: $todo ($age_days days)"
  fi
done
```

### Stale Todo Actions

```markdown
For each stale todo:
1. **Promote:** If still important, add to phase
2. **Deprioritize:** Lower priority if not urgent
3. **Archive:** Close as won't-do with reason
```

## Integration with Planning

### During New-Project

```bash
# Check for existing todos
if [ -d .planning/todos/pending ] && [ "$(ls .planning/todos/pending/*.md 2>/dev/null)" ]; then
  echo "Found pending todos - consider including in roadmap"
fi
```

### During Plan-Phase

```bash
# Show related todos
phase_name="authentication"
grep -l "$phase_name" .planning/todos/pending/*.md 2>/dev/null
```

### During Phase Completion

```bash
# Check if any todos were addressed
# Mark as complete if work was done
```

## Output Formats

### List View

```markdown
## Pending Todos (5)

### High Priority
- [001] **Fix login timeout** (api, high) - 2d old

### Medium Priority
- [002] **Add dark mode** (ui, medium) - 5d old
- [003] **Optimize queries** (db, medium) - 3d old

### Low Priority
- [004] **Update README** (docs, low) - 10d old
- [005] **Add more tests** (test, low) - 7d old
```

### Detail View

```markdown
## Todo #003: Optimize Queries

**Area:** db | **Priority:** medium | **Age:** 3 days

### Context
{context from todo file}

### Details
{details from todo file}

### Options
1. Work on this now (/gsd:quick)
2. Add to current phase
3. Create new phase for this
4. Defer (lower priority)
5. Close (won't do)
```

## Best Practices

1. **Capture immediately** - Don't lose ideas
2. **Be specific** - Include context and acceptance criteria
3. **Review weekly** - Process stale todos
4. **Link to phases** - Track what addresses what
5. **Archive, don't delete** - Maintain history
