---
name: gsd:health
description: Diagnose GSD project health and detect issues
user-invocable: true
---

# GSD Health Check

Run diagnostics on your GSD project to detect issues before they cause problems.

## Execution Flow

### Step 1: Check GSD Installation

```bash
# Check VERSION file
GSD_VERSION=$(cat .claude/get-shit-done/VERSION 2>/dev/null || echo "NOT FOUND")
echo "GSD Version: $GSD_VERSION"

# Check required directories
ls -d .claude/agents .claude/commands/gsd .claude/skills/gsd .claude/get-shit-done 2>/dev/null
```

**Diagnosis:**
- VERSION not found: CRITICAL - GSD not installed
- Missing directories: CRITICAL - incomplete installation

### Step 2: Check Project Initialization

```bash
# Check .planning directory
ls -la .planning/ 2>/dev/null

# Check required files
ls .planning/PROJECT.md .planning/ROADMAP.md .planning/STATE.md 2>/dev/null
```

**Diagnosis:**
- `.planning/` not found: INFO - project not initialized (run `/gsd:new-project`)
- Missing PROJECT.md: WARN - no project definition
- Missing ROADMAP.md: WARN - no roadmap defined
- Missing STATE.md: WARN - no state tracking

### Step 3: Validate config.json

```bash
# Check if config.json exists and is valid JSON
if [ -f .planning/config.json ]; then
  node -e "JSON.parse(require('fs').readFileSync('.planning/config.json'))" 2>&1
fi
```

**Diagnosis:**
- Invalid JSON: CRITICAL - config.json is malformed
- Missing config.json: INFO - using defaults

### Step 4: Check STATE.md Synchronization

Parse STATE.md and verify:
1. Current phase exists in ROADMAP.md
2. Referenced files exist on disk
3. Progress percentage matches actual SUMMARY.md count

```bash
# Count expected vs actual summaries
PLAN_COUNT=$(find .planning/phases -name "*-PLAN.md" 2>/dev/null | wc -l)
SUMMARY_COUNT=$(find .planning/phases -name "*-SUMMARY.md" 2>/dev/null | wc -l)
echo "Plans: $PLAN_COUNT, Summaries: $SUMMARY_COUNT"
```

**Diagnosis:**
- Phase in STATE.md not in ROADMAP.md: WARN - state/roadmap mismatch
- Progress mismatch: WARN - STATE.md outdated

### Step 5: Detect Orphaned Files

```bash
# Find PLANs without SUMMARYs (incomplete execution)
for plan in .planning/phases/*/*-PLAN.md; do
  summary="${plan/-PLAN.md/-SUMMARY.md}"
  [ ! -f "$summary" ] && echo "Incomplete: $plan"
done

# Find SUMMARYs without PLANs (orphaned)
for summary in .planning/phases/*/*-SUMMARY.md; do
  plan="${summary/-SUMMARY.md/-PLAN.md}"
  [ ! -f "$plan" ] && echo "Orphaned: $summary"
done
```

**Diagnosis:**
- PLAN without SUMMARY: INFO - execution pending or incomplete
- SUMMARY without PLAN: WARN - orphaned summary (plan deleted?)

### Step 6: Check Phase Directory Structure

```bash
# Verify phase directories match roadmap
for dir in .planning/phases/*/; do
  phase_num=$(basename "$dir" | grep -oE '^[0-9]+')
  echo "Phase $phase_num: $dir"
done
```

**Diagnosis:**
- Phase directory not in ROADMAP: WARN - orphaned phase
- ROADMAP phase without directory: INFO - phase not yet created

### Step 7: Validate ROADMAP.md Format

Check ROADMAP.md has parseable structure:
- Phase headers (`### Phase N:`)
- Status markers (Completed/In Progress/Planned)
- Plan checkboxes

**Diagnosis:**
- Unparseable format: WARN - ROADMAP.md may cause issues

### Step 8: Check for Stale Debug Sessions

```bash
# Find old debug sessions
find .planning/debug -name "*.md" -mtime +7 2>/dev/null | head -5
```

**Diagnosis:**
- Old debug files: INFO - consider cleanup with `rm -rf .planning/debug/resolved/`

### Step 9: Check Milestone Archive Integrity

Verify that completed milestones were properly archived.

```bash
# Check if milestones directory exists
ls -la .planning/milestones/ 2>/dev/null

# Check for MILESTONES.md entries
grep -E "^## v[0-9]+\.[0-9]+" .planning/MILESTONES.md 2>/dev/null | while read -r line; do
  version=$(echo "$line" | grep -oE 'v[0-9]+\.[0-9]+')
  echo "Milestone found: $version"
done

# For each milestone in MILESTONES.md, verify archives exist
```

**Archive completeness check for each milestone:**

```bash
check_milestone_archive() {
  local version=$1  # e.g., "1.0"
  local issues=()

  # Check ROADMAP archive
  [ ! -f ".planning/milestones/v${version}-ROADMAP.md" ] && issues+=("Missing v${version}-ROADMAP.md")

  # Check REQUIREMENTS archive
  [ ! -f ".planning/milestones/v${version}-REQUIREMENTS.md" ] && issues+=("Missing v${version}-REQUIREMENTS.md")

  # Check phases archive
  [ ! -d ".planning/milestones/v${version}-phases" ] && issues+=("Missing v${version}-phases/")

  # Output issues
  for issue in "${issues[@]}"; do
    echo "WARN: $issue"
  done
}
```

**Detect orphaned phases (phases that should have been archived):**

```bash
# If milestone v1.0 includes phases 1-4, those phases should be in archive
# Check for phases still in .planning/phases/ that belong to completed milestones

# Get completed milestone phase ranges from MILESTONES.md
grep -E "Phases completed.*[0-9]+-[0-9]+" .planning/MILESTONES.md 2>/dev/null | while read -r line; do
  range=$(echo "$line" | grep -oE '[0-9]+-[0-9]+')
  start=$(echo "$range" | cut -d'-' -f1)
  end=$(echo "$range" | cut -d'-' -f2)

  # Check if these phases are still in .planning/phases/ (should be archived)
  for i in $(seq $start $end); do
    phase_dir=$(printf ".planning/phases/%02d-*" $i)
    if ls -d $phase_dir 2>/dev/null | head -1; then
      echo "WARN: Phase $i should be archived but still in .planning/phases/"
    fi
  done
done
```

**Diagnosis:**
- Missing archive files: WARN - incomplete milestone archival
- Orphaned phases: WARN - phases not moved to archive after milestone completion
- Missing phases archive directory: WARN - phase history not preserved
- MILESTONES.md entry without archives: CRITICAL - data loss risk

### Step 10: Cross-Reference Integrity

Verify that references between planning files are valid.

```bash
# Extract current phase from STATE.md
CURRENT_PHASE=$(grep -E "^Phase:" .planning/STATE.md 2>/dev/null | grep -oE '[0-9]+' | head -1)

# Check if current phase exists in ROADMAP.md
if [ -n "$CURRENT_PHASE" ]; then
  grep -qE "Phase ${CURRENT_PHASE}:" .planning/ROADMAP.md 2>/dev/null || echo "WARN: STATE.md references Phase $CURRENT_PHASE not in ROADMAP.md"
fi

# Check ROADMAP plan references exist as files
grep -oE '\[.\] [0-9]+-[0-9]+:' .planning/ROADMAP.md 2>/dev/null | while read -r plan_ref; do
  plan_id=$(echo "$plan_ref" | grep -oE '[0-9]+-[0-9]+')
  phase_num=$(echo "$plan_id" | cut -d'-' -f1)
  phase_dir=$(find .planning/phases -maxdepth 1 -type d -name "${phase_num}-*" 2>/dev/null | head -1)
  if [ -n "$phase_dir" ]; then
    [ ! -f "${phase_dir}/${plan_id}-PLAN.md" ] && echo "WARN: ROADMAP references ${plan_id} but file not found"
  fi
done

# Check PROJECT.md validated requirements match MILESTONES.md
grep -E "^- ✓.*— v[0-9]" .planning/PROJECT.md 2>/dev/null | while read -r req; do
  version=$(echo "$req" | grep -oE 'v[0-9]+\.[0-9]+')
  grep -qE "^## ${version}" .planning/MILESTONES.md 2>/dev/null || echo "WARN: PROJECT.md references $version not in MILESTONES.md"
done
```

**Diagnosis:**
- STATE.md references non-existent phase: WARN - state/roadmap desync
- ROADMAP references missing plan file: WARN - incomplete phase setup
- PROJECT.md validates milestone not in MILESTONES.md: WARN - inconsistent records

### Step 11: Git State Alignment

Check if planning documents are properly tracked in git.

```bash
# Check for uncommitted planning changes
git status --porcelain .planning/ 2>/dev/null | head -10

# Check if .planning is gitignored
git check-ignore -q .planning 2>/dev/null && echo "INFO: .planning/ is gitignored"

# Check config vs gitignore consistency
if git check-ignore -q .planning 2>/dev/null; then
  COMMIT_DOCS=$(grep -o '"commit_docs"[[:space:]]*:[[:space:]]*true' .planning/config.json 2>/dev/null)
  [ -n "$COMMIT_DOCS" ] && echo "WARN: config.json has commit_docs=true but .planning/ is gitignored"
fi

# Check git tags vs MILESTONES.md
grep -oE 'v[0-9]+\.[0-9]+' .planning/MILESTONES.md 2>/dev/null | sort -u | while read -r version; do
  tag="milestone-${version}"
  git tag -l "$tag" 2>/dev/null | grep -q "$tag" || echo "INFO: Milestone $version has no git tag ($tag)"
done

# Check for untagged milestones
git tag -l 'milestone-v*' 2>/dev/null | while read -r tag; do
  version="${tag#milestone-}"
  grep -qE "^## ${version}" .planning/MILESTONES.md 2>/dev/null || echo "WARN: Git tag $tag has no MILESTONES.md entry"
done
```

**Diagnosis:**
- Uncommitted planning changes: INFO - consider committing
- config.json/gitignore mismatch: WARN - configuration conflict
- Missing git tags: INFO - milestone not tagged
- Orphan git tags: WARN - tag without milestone record

### Step 12: Context Size Monitoring

Check if planning files are growing too large for efficient context usage.

```bash
# Check file sizes
check_file_size() {
  local file=$1
  local warn_lines=$2
  local crit_lines=$3
  local name=$4

  if [ -f "$file" ]; then
    lines=$(wc -l < "$file")
    if [ "$lines" -gt "$crit_lines" ]; then
      echo "CRITICAL: $name is $lines lines (> $crit_lines) - needs archiving/splitting"
    elif [ "$lines" -gt "$warn_lines" ]; then
      echo "WARN: $name is $lines lines (> $warn_lines) - consider cleanup"
    fi
  fi
}

check_file_size ".planning/PROJECT.md" 400 600 "PROJECT.md"
check_file_size ".planning/STATE.md" 150 250 "STATE.md"
check_file_size ".planning/ROADMAP.md" 300 500 "ROADMAP.md"

# Check individual plan sizes
find .planning/phases -name "*-PLAN.md" 2>/dev/null | while read -r plan; do
  lines=$(wc -l < "$plan")
  [ "$lines" -gt 300 ] && echo "WARN: $(basename $plan) is $lines lines - consider splitting"
done

# Count accumulated decisions in PROJECT.md
DECISION_COUNT=$(grep -cE "^\|.*\|.*\|.*\|" .planning/PROJECT.md 2>/dev/null || echo 0)
[ "$DECISION_COUNT" -gt 50 ] && echo "WARN: $DECISION_COUNT decisions in PROJECT.md - consider archiving old decisions"

# Check STATE.md accumulated context size
CONTEXT_LINES=$(sed -n '/Accumulated Context/,/^##/p' .planning/STATE.md 2>/dev/null | wc -l)
[ "$CONTEXT_LINES" -gt 80 ] && echo "WARN: STATE.md accumulated context is $CONTEXT_LINES lines - consider cleanup"
```

**Diagnosis:**
- PROJECT.md > 600 lines: CRITICAL - context overflow risk
- STATE.md > 250 lines: CRITICAL - state bloat
- PLAN.md > 300 lines: WARN - plan too complex, consider splitting
- Too many decisions: WARN - archive old decisions to milestone

### Step 13: Workflow Continuity

Check for interrupted or paused work sessions.

```bash
# Check for HANDOFF.md (paused session)
if [ -f .planning/HANDOFF.md ]; then
  echo "INFO: Found HANDOFF.md - paused work session exists"
  HANDOFF_DATE=$(stat -c %Y .planning/HANDOFF.md 2>/dev/null || stat -f %m .planning/HANDOFF.md 2>/dev/null)
  NOW=$(date +%s)
  DAYS_OLD=$(( (NOW - HANDOFF_DATE) / 86400 ))
  [ "$DAYS_OLD" -gt 7 ] && echo "WARN: HANDOFF.md is $DAYS_OLD days old - stale paused session"
fi

# Check STATE.md status vs actual state
STATE_STATUS=$(grep -E "^Status:" .planning/STATE.md 2>/dev/null | head -1)
if echo "$STATE_STATUS" | grep -qiE "ready to plan|not started"; then
  # Should have no in-progress plans
  IN_PROGRESS=$(find .planning/phases -name "*-PLAN.md" -newer .planning/STATE.md 2>/dev/null | wc -l)
  [ "$IN_PROGRESS" -gt 0 ] && echo "WARN: STATE.md says 'ready to plan' but $IN_PROGRESS plans modified after"
fi

# Check for partially executed plans (PLAN newer than SUMMARY or no SUMMARY)
find .planning/phases -name "*-PLAN.md" 2>/dev/null | while read -r plan; do
  summary="${plan/-PLAN.md/-SUMMARY.md}"
  if [ -f "$summary" ]; then
    # PLAN modified after SUMMARY = re-execution needed?
    if [ "$plan" -nt "$summary" ]; then
      echo "INFO: $(basename $plan) modified after its SUMMARY - re-execution needed?"
    fi
  fi
done

# Check for active debug sessions
ACTIVE_DEBUG=$(find .planning/debug -maxdepth 1 -name "*.md" ! -path "*/resolved/*" 2>/dev/null | wc -l)
[ "$ACTIVE_DEBUG" -gt 0 ] && echo "INFO: $ACTIVE_DEBUG active debug session(s) found"
```

**Diagnosis:**
- HANDOFF.md exists: INFO - resume with `/gsd:resume-work`
- Stale HANDOFF.md: WARN - old paused session, consider cleanup
- State/reality mismatch: WARN - STATE.md outdated
- Plans modified after summary: INFO - may need re-execution
- Active debug sessions: INFO - unresolved debugging

### Step 14: Todo Staleness

Check for stale or abandoned todos.

```bash
# Check todos directory
if [ -d .planning/todos ]; then
  # Count pending todos
  PENDING=$(grep -l "status.*pending" .planning/todos/*.md 2>/dev/null | wc -l)
  TOTAL=$(ls .planning/todos/*.md 2>/dev/null | wc -l)

  echo "Todos: $PENDING pending of $TOTAL total"

  # Find old pending todos (> 7 days)
  find .planning/todos -name "*.md" -mtime +7 2>/dev/null | while read -r todo; do
    if grep -q "status.*pending" "$todo" 2>/dev/null; then
      echo "WARN: Stale todo (>7 days): $(basename $todo)"
    fi
  done

  # Check for too many pending todos
  [ "$PENDING" -gt 20 ] && echo "WARN: $PENDING pending todos - review and prioritize"
fi

# Check inline TODOs in planning docs
TODO_COUNT=$(grep -r "TODO:" .planning/*.md 2>/dev/null | wc -l)
[ "$TODO_COUNT" -gt 10 ] && echo "INFO: $TODO_COUNT inline TODOs in planning docs"
```

**Diagnosis:**
- Stale pending todos (> 7 days): WARN - abandoned work items
- Too many pending todos (> 20): WARN - backlog overflow
- Inline TODOs: INFO - untracked work items

### Step 15: Plan Quality

Check for low-quality or incomplete plans.

```bash
# Check each PLAN.md for required sections
find .planning/phases -name "*-PLAN.md" 2>/dev/null | while read -r plan; do
  plan_name=$(basename "$plan")

  # Check file is not empty/stub
  lines=$(wc -l < "$plan")
  [ "$lines" -lt 20 ] && echo "WARN: $plan_name is only $lines lines - likely incomplete"

  # Check for Tasks section
  grep -qiE "^##.*Tasks|^##.*Implementation" "$plan" || echo "WARN: $plan_name missing Tasks section"

  # Check for at least one task checkbox
  grep -qE "^\s*- \[.\]" "$plan" || echo "WARN: $plan_name has no task checkboxes"

  # Check for success criteria
  grep -qiE "success.*criteria|acceptance.*criteria|done.*when" "$plan" || echo "INFO: $plan_name missing success criteria"
done

# Check for phases with 0 plans
grep -E "^###.*Phase [0-9]+" .planning/ROADMAP.md 2>/dev/null | while read -r phase_line; do
  phase_num=$(echo "$phase_line" | grep -oE 'Phase [0-9]+' | grep -oE '[0-9]+')
  phase_dir=$(find .planning/phases -maxdepth 1 -type d -name "${phase_num}-*" 2>/dev/null | head -1)
  if [ -n "$phase_dir" ]; then
    plan_count=$(find "$phase_dir" -name "*-PLAN.md" 2>/dev/null | wc -l)
    [ "$plan_count" -eq 0 ] && echo "WARN: Phase $phase_num directory exists but has 0 plans"
  fi
done
```

**Diagnosis:**
- Plan < 20 lines: WARN - likely stub/incomplete
- Missing Tasks section: WARN - plan not actionable
- No task checkboxes: WARN - plan not executable
- Missing success criteria: INFO - completion unclear
- Phase with 0 plans: WARN - empty phase directory

### Step 16: Temporal Consistency

Check that timestamps and dates make logical sense.

```bash
# Check SUMMARY dates are after PLAN dates
find .planning/phases -name "*-SUMMARY.md" 2>/dev/null | while read -r summary; do
  plan="${summary/-SUMMARY.md/-PLAN.md}"
  if [ -f "$plan" ]; then
    plan_time=$(stat -c %Y "$plan" 2>/dev/null || stat -f %m "$plan" 2>/dev/null)
    summary_time=$(stat -c %Y "$summary" 2>/dev/null || stat -f %m "$summary" 2>/dev/null)
    if [ "$summary_time" -lt "$plan_time" ]; then
      echo "WARN: $(basename $summary) is older than its PLAN - execution before planning?"
    fi
  fi
done

# Check milestone dates are in order (in MILESTONES.md)
prev_date=""
grep -oE 'Shipped: [0-9]{4}-[0-9]{2}-[0-9]{2}' .planning/MILESTONES.md 2>/dev/null | while read -r line; do
  date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
  if [ -n "$prev_date" ] && [ "$date" \> "$prev_date" ]; then
    echo "INFO: Milestone dates may be out of order: $prev_date before $date"
  fi
  prev_date="$date"
done

# Check STATE.md last activity matches reality
STATE_ACTIVITY=$(grep -E "^Last activity:" .planning/STATE.md 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
if [ -n "$STATE_ACTIVITY" ]; then
  # Find most recent planning file modification
  LATEST_MOD=$(find .planning -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
  if [ -n "$LATEST_MOD" ]; then
    LATEST_DATE=$(stat -c %Y "$LATEST_MOD" 2>/dev/null | xargs -I{} date -d @{} +%Y-%m-%d 2>/dev/null)
    [ "$LATEST_DATE" != "$STATE_ACTIVITY" ] && echo "INFO: STATE.md last activity ($STATE_ACTIVITY) differs from latest file mod ($LATEST_DATE)"
  fi
fi
```

**Diagnosis:**
- SUMMARY older than PLAN: WARN - temporal paradox
- Milestone dates out of order: INFO - check order
- STATE.md activity date stale: INFO - STATE.md needs update

### Step 17: Dependency Graph Validation

Check phase dependencies for issues.

```bash
# Extract dependencies from ROADMAP.md and check for issues
# Look for "Depends on:" or "blocked by" patterns

# Check for circular dependencies
grep -E "Depends on:.*Phase" .planning/ROADMAP.md 2>/dev/null | while read -r line; do
  phase=$(echo "$line" | grep -oB 50 "Phase [0-9]+" | tail -1 | grep -oE '[0-9]+')
  depends_on=$(echo "$line" | grep -oE 'Phase [0-9]+' | grep -oE '[0-9]+')

  # Simple circular check: A depends on B, B depends on A
  if grep -E "Phase ${depends_on}.*Depends on:.*Phase ${phase}" .planning/ROADMAP.md 2>/dev/null; then
    echo "CRITICAL: Circular dependency between Phase $phase and Phase $depends_on"
  fi
done

# Check for dependencies on non-existent phases
grep -oE "Depends on:.*Phase [0-9]+" .planning/ROADMAP.md 2>/dev/null | grep -oE 'Phase [0-9]+' | while read -r dep; do
  dep_num=$(echo "$dep" | grep -oE '[0-9]+')
  grep -qE "^###.*Phase ${dep_num}:" .planning/ROADMAP.md 2>/dev/null || echo "WARN: Dependency on non-existent $dep"
done

# Check for blocked phases where blocker is complete
grep -E "Blocked by|Depends on" .planning/STATE.md 2>/dev/null | grep -oE 'Phase [0-9]+' | while read -r blocker; do
  blocker_num=$(echo "$blocker" | grep -oE '[0-9]+')
  # Check if blocker phase is complete in ROADMAP
  if grep -E "Phase ${blocker_num}:.*Complete|Phase ${blocker_num}:.*✅" .planning/ROADMAP.md 2>/dev/null; then
    echo "INFO: Blocked by $blocker but that phase is complete - unblock?"
  fi
done
```

**Diagnosis:**
- Circular dependency: CRITICAL - workflow deadlock
- Dependency on non-existent phase: WARN - broken reference
- Blocked by completed phase: INFO - can be unblocked

### Step 18: Research/Documentation Freshness

Check for stale research and codebase documentation.

```bash
# Check research files age
if [ -d .planning/research ]; then
  find .planning/research -name "*.md" -mtime +30 2>/dev/null | while read -r file; do
    echo "INFO: Stale research (>30 days): $(basename $file)"
  done
fi

# Check codebase analysis age
if [ -d .planning/codebase ]; then
  find .planning/codebase -name "*.md" -mtime +14 2>/dev/null | while read -r file; do
    echo "INFO: Stale codebase doc (>14 days): $(basename $file)"
  done

  # Check if codebase docs reference files that no longer exist
  grep -hoE '\b[a-zA-Z0-9_/-]+\.(ts|js|py|go|rs|swift|java)\b' .planning/codebase/*.md 2>/dev/null | sort -u | while read -r filepath; do
    [ ! -f "$filepath" ] && [ ! -f "src/$filepath" ] && [ ! -f "lib/$filepath" ] && echo "WARN: Codebase doc references non-existent: $filepath"
  done
fi

# Check PROJECT.md context section age
if grep -q "## Context" .planning/PROJECT.md 2>/dev/null; then
  # Look for LOC counts that might be outdated
  DOCUMENTED_LOC=$(grep -oE '[0-9,]+ (LOC|lines)' .planning/PROJECT.md 2>/dev/null | head -1 | grep -oE '[0-9,]+')
  if [ -n "$DOCUMENTED_LOC" ]; then
    # Simple heuristic: if documented LOC differs by >50% from current, warn
    CURRENT_LOC=$(find . -name "*.ts" -o -name "*.js" -o -name "*.py" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    if [ -n "$CURRENT_LOC" ] && [ "$CURRENT_LOC" -gt 0 ]; then
      DOCUMENTED_NUM=$(echo "$DOCUMENTED_LOC" | tr -d ',')
      DIFF=$(( (CURRENT_LOC - DOCUMENTED_NUM) * 100 / DOCUMENTED_NUM ))
      [ "$DIFF" -gt 50 ] || [ "$DIFF" -lt -50 ] && echo "WARN: PROJECT.md LOC ($DOCUMENTED_LOC) differs >50% from current ($CURRENT_LOC)"
    fi
  fi
fi
```

**Diagnosis:**
- Research > 30 days old: INFO - may be outdated
- Codebase doc > 14 days old: INFO - may need refresh
- Codebase doc references missing files: WARN - documentation rot
- PROJECT.md LOC significantly different: WARN - context outdated

---

## Report Format

Output a health report:

```markdown
## GSD Health Report

**Project:** [from PROJECT.md or directory name]
**GSD Version:** [version]
**Status:** [HEALTHY / ISSUES FOUND / CRITICAL]

### Summary

| Category | Status | Details |
|----------|--------|---------|
| Installation | OK/WARN/CRITICAL | ... |
| Project Files | OK/WARN/CRITICAL | ... |
| Config | OK/WARN | ... |
| State Sync | OK/WARN | ... |
| Phase Structure | OK/WARN | ... |
| Archive Integrity | OK/WARN/CRITICAL | ... |
| Cross-References | OK/WARN | ... |
| Git Alignment | OK/WARN/INFO | ... |
| Context Size | OK/WARN/CRITICAL | ... |
| Workflow Continuity | OK/WARN/INFO | ... |
| Todo Health | OK/WARN/INFO | ... |
| Plan Quality | OK/WARN/INFO | ... |
| Temporal Consistency | OK/WARN/INFO | ... |
| Dependencies | OK/WARN/CRITICAL | ... |
| Doc Freshness | OK/WARN/INFO | ... |

### Issues Found

[If any issues, list them with severity]

| Severity | Issue | Fix |
|----------|-------|-----|
| CRITICAL | [issue] | [how to fix] |
| WARN | [issue] | [how to fix] |

### Recommendations

[List actionable recommendations]

### Quick Fixes Available

[If auto-fixable issues exist, list them]
- [ ] Regenerate STATE.md from artifacts
- [ ] Clean up stale debug sessions
- [ ] Remove orphaned files
- [ ] Fix incomplete milestone archives
- [ ] Archive orphaned phases from completed milestones
- [ ] Trim bloated context files
- [ ] Clean up stale todos
- [ ] Refresh codebase documentation
- [ ] Update PROJECT.md context section
- [ ] Remove stale HANDOFF.md
- [ ] Create missing git tags for milestones
```

---

## Auto-Fix (if user confirms)

If issues found, ask: "Would you like me to fix these issues?"

### Fix: Regenerate STATE.md

If STATE.md is out of sync, regenerate from artifacts using `gsd:state-reconstruction` skill.

### Fix: Clean Stale Debug Sessions

```bash
rm -rf .planning/debug/resolved/
find .planning/debug -name "*.md" -mtime +30 -delete
```

### Fix: Remove Orphaned Files

Ask user confirmation before removing any files.

### Fix: Create Missing Directories

```bash
mkdir -p .planning/phases .planning/todos .planning/debug
```

### Fix: Incomplete Milestone Archives

If MILESTONES.md shows a completed milestone but archives are missing:

**1. Identify the milestone and its phase range:**

```bash
# Parse MILESTONES.md for the problematic milestone
# Example: v1.0 with phases 1-4
VERSION="1.0"
PHASE_START=1
PHASE_END=4
```

**2. Create missing archive directory:**

```bash
mkdir -p .planning/milestones
```

**3. Generate missing ROADMAP archive (if phases still exist):**

If `.planning/phases/` still contains the phases for this milestone, reconstruct the archive:

```bash
# Create ROADMAP archive from existing phase data
cat > .planning/milestones/v${VERSION}-ROADMAP.md << 'EOF'
# Milestone Archive: v${VERSION}

**Status:** ✅ SHIPPED (reconstructed)
**Phases:** ${PHASE_START}-${PHASE_END}

## Phases

[Extract phase details from .planning/phases/]

---
*Reconstructed by /gsd:health fix*
EOF
```

**4. Generate missing REQUIREMENTS archive:**

If REQUIREMENTS.md was not archived but requirements are documented in PROJECT.md:

```bash
# Create minimal REQUIREMENTS archive from PROJECT.md Validated section
cat > .planning/milestones/v${VERSION}-REQUIREMENTS.md << 'EOF'
# Requirements Archive: v${VERSION}

**Archived:** [DATE] (reconstructed)
**Status:** ✅ SHIPPED

## Validated Requirements

[Extract from PROJECT.md Validated section]

---
*Reconstructed by /gsd:health fix*
EOF
```

**5. Archive orphaned phases:**

Move phases that belong to completed milestones from `.planning/phases/` to their archive:

```bash
# Create phases archive directory
mkdir -p .planning/milestones/v${VERSION}-phases

# Move phases to archive
for i in $(seq $PHASE_START $PHASE_END); do
  phase_dir=$(printf ".planning/phases/%02d-*" $i)
  if ls -d $phase_dir 2>/dev/null; then
    mv $phase_dir .planning/milestones/v${VERSION}-phases/
    echo "Moved phase $i to archive"
  fi
done

# Clean up empty phases directory
rmdir .planning/phases 2>/dev/null || true
```

**6. Verify fix:**

```bash
# Confirm archive structure
ls -la .planning/milestones/v${VERSION}-*

# Output
echo "✅ Archive fixed for milestone v${VERSION}"
echo "  - v${VERSION}-ROADMAP.md: $([ -f .planning/milestones/v${VERSION}-ROADMAP.md ] && echo 'OK' || echo 'MISSING')"
echo "  - v${VERSION}-REQUIREMENTS.md: $([ -f .planning/milestones/v${VERSION}-REQUIREMENTS.md ] && echo 'OK' || echo 'MISSING')"
echo "  - v${VERSION}-phases/: $([ -d .planning/milestones/v${VERSION}-phases ] && echo 'OK' || echo 'MISSING')"
```

**7. Commit the fix (if planning docs are tracked):**

```bash
git add .planning/milestones/
git add -u .planning/
git commit -m "fix: reconstruct incomplete v${VERSION} milestone archive

Reconstructed by /gsd:health auto-fix:
- Created missing archive files
- Moved orphaned phases to archive

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### Fix: Orphaned Phases Without Milestone Record

If phases exist in `.planning/phases/` but there's no corresponding milestone entry:

**Option A: Complete the milestone properly**

Run `/gsd:complete-milestone` to properly archive the phases.

**Option B: Manual archive (if milestone already recorded elsewhere)**

```bash
# Determine which milestone these phases belong to
# Check git tags, MILESTONES.md, or ask user

VERSION="X.Y"  # Determine correct version

# Create archive structure
mkdir -p .planning/milestones/v${VERSION}-phases

# Move all orphaned phases
mv .planning/phases/* .planning/milestones/v${VERSION}-phases/

# Clean up
rmdir .planning/phases 2>/dev/null || true

echo "✅ Orphaned phases archived to v${VERSION}-phases/"
```

### Fix: Cross-Reference Desync

If STATE.md references a phase not in ROADMAP.md:

```bash
# Option 1: Update STATE.md to match ROADMAP
# Read current state from ROADMAP and regenerate STATE.md

# Option 2: Add missing phase to ROADMAP (if it should exist)
# Use /gsd:add-phase to properly add the phase
```

### Fix: Git Tag Sync

Create missing milestone tags (with user confirmation):

**Step 1: Identify missing tags and ask user:**

```markdown
다음 마일스톤에 git 태그가 없습니다:

| Milestone | 태그 |
|-----------|------|
| v1.0 MVP | milestone-v1.0 |
| v1.1 Security | milestone-v1.1 |

태그를 생성할까요? [Y] 모두 생성  [S] 선택  [N] 건너뛰기
```

**Step 2: Create tags after user confirmation:**

```bash
# For each confirmed milestone
VERSION="1.0"
MILESTONE_NAME="MVP"

git tag -a "milestone-v${VERSION}" -m "$(cat <<EOF
Milestone v${VERSION}: ${MILESTONE_NAME}

See .planning/MILESTONES.md for details.
EOF
)"

echo "✅ Created tag milestone-v${VERSION}"
```

**Step 3: Ask about push:**

```markdown
생성된 태그를 원격에 푸시할까요? [Y/N]
```

```bash
# If yes
git push origin "milestone-v${VERSION}"
```

### Fix: Context Size - Trim Bloated Files

**Trim STATE.md accumulated context:**

```bash
# Backup first
cp .planning/STATE.md .planning/STATE.md.bak

# Keep only recent decisions (last 10)
# Keep only open blockers
# Clear resolved items
```

Manually edit STATE.md to:
1. Remove old decisions (keep in PROJECT.md)
2. Remove resolved blockers
3. Summarize instead of listing all context

**Trim PROJECT.md decisions:**

Move old decisions to milestone archive:

```bash
# Extract decisions older than current milestone to archive
# Keep only decisions relevant to current/next milestone in PROJECT.md
```

### Fix: Stale HANDOFF.md

If HANDOFF.md is older than 7 days:

```bash
# Option 1: Resume the work
/gsd:resume-work

# Option 2: Discard stale handoff
rm .planning/HANDOFF.md
echo "✅ Removed stale HANDOFF.md"
```

### Fix: Stale Todos

Clean up old pending todos:

```bash
# List stale todos for review
find .planning/todos -name "*.md" -mtime +7 | while read -r todo; do
  if grep -q "status.*pending" "$todo" 2>/dev/null; then
    echo "Stale: $todo"
  fi
done

# After user review, archive or delete
mkdir -p .planning/todos/archived
mv .planning/todos/old-todo.md .planning/todos/archived/

# Or mark as cancelled
sed -i 's/status.*pending/status: cancelled/' .planning/todos/old-todo.md
```

### Fix: Plan Quality Issues

**For stub/empty plans:**

```bash
# Either delete incomplete phase setup
rm -rf .planning/phases/XX-incomplete-phase

# Or run planning workflow to complete it
/gsd:plan-phase XX
```

**For plans missing sections:**

Manually add required sections:
- `## Tasks` with checkboxes
- `## Success Criteria`

### Fix: Dependency Issues

**Circular dependency:**

Edit ROADMAP.md to break the cycle:
1. Identify which dependency can be removed
2. Consider if phases should be merged
3. Update phase order if needed

**Blocked by completed phase:**

```bash
# Update STATE.md to remove blocker reference
# Or update ROADMAP.md phase status
```

### Fix: Stale Documentation

**Refresh codebase docs:**

```bash
# Run codebase mapper to regenerate
/gsd:map-codebase

# Or manually update specific docs
```

**Update PROJECT.md context:**

Manually update the Context section with:
- Current LOC count
- Updated tech stack
- Recent decisions

```bash
# Get current LOC
find . -name "*.ts" -o -name "*.js" -o -name "*.py" 2>/dev/null | xargs wc -l | tail -1
```

---

## Usage Examples

```bash
# Basic health check
/gsd:health

# Health check with auto-fix
/gsd:health --fix
```

---

## Success Criteria

Health check complete when:
- [ ] All 18 diagnostic steps executed
- [ ] Report generated with clear status (HEALTHY/ISSUES FOUND/CRITICAL)
- [ ] Issues listed with severity (CRITICAL/WARN/INFO) and fix suggestions
- [ ] All categories assessed in summary table
- [ ] Auto-fix offered if applicable issues found
- [ ] User understands next steps for any issues found

**Critical issues that block work:**
- Circular dependencies
- Missing critical files (PROJECT.md, STATE.md)
- Context overflow (files too large)
- Invalid config.json

**Warning issues to address soon:**
- Cross-reference mismatches
- Incomplete archives
- Stale handoffs
- Plan quality issues

**Info items for awareness:**
- Uncommitted changes
- Missing git tags
- Stale documentation
