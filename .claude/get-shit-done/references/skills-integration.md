# Skills Integration

GSD agents integrate with two types of skills:

## GSD Skills (Internal)

Located in `.claude/skills/gsd/`, these are GSD-specific methodologies.

| Skill | Purpose | Used By |
|-------|---------|---------|
| `gsd:verify-goal-backward` | Goal-backward verification | verifier, plan-checker, integration-checker |
| `gsd:deviation-classifier` | Deviation handling rules | executor |
| `gsd:checkpoint-and-state-save` | Checkpoint protocol | executor |
| `gsd:atomic-git-workflow` | Per-task commits | executor |
| `gsd:wave-executor` | Parallel wave execution | execute-phase |
| `gsd:state-reconstruction` | STATE.md recovery | resume-work |
| `gsd:resolve-model-profile` | Model resolution | all orchestrators |
| `gsd:codebase-mapper-orchestrator` | Parallel codebase analysis | map-codebase |
| `gsd:todo-manager` | Todo lifecycle | add-todo, check-todos |
| `gsd:verification-report-generator` | VERIFICATION.md format | verifier |
| `gsd:context-discussion-guide` | Phase context gathering | discuss-phase |

**GSD skills are always available** in a GSD installation.

## Superpowers Skills (External)

Referenced as `superpowers:*`, these are external skills from the superpowers package.

| Skill | Purpose | Used By |
|-------|---------|---------|
| `superpowers:test-driven-development` | TDD methodology | executor (tdd tasks) |
| `superpowers:verification-before-completion` | Evidence-first verification | executor, verifier |
| `superpowers:systematic-debugging` | Debugging methodology | debugger |
| `superpowers:brainstorming` | Design exploration | planner |
| `superpowers:writing-plans` | Plan creation | planner |

### Availability

Superpowers skills are **external dependencies**:

```
Available if:
  - Superpowers package is installed
  - Skills are in .claude/skills/superpowers/ or global location

Not available if:
  - Superpowers not installed
  - Skills not in expected location
```

### Graceful Degradation

When superpowers skills are not available:

1. **Agent continues to function** - Skills are enhancements, not requirements
2. **Core methodology still applies** - GSD skills provide primary guidance
3. **Warning logged** - Debug log notes unavailable skill

### Installation

To install superpowers skills:

```bash
# Check if installed
ls .claude/skills/superpowers/ 2>/dev/null

# Install (if available as package)
# Follow superpowers installation instructions
```

## Skills Reference in Agents

Agents declare skill integration in frontmatter:

```yaml
skills_integration:
  - gsd:verify-goal-backward        # GSD skill (always available)
  - superpowers:verification-before-completion  # External (may not be available)
```

And document usage in `<skills_reference>` section:

```markdown
<skills_reference>
**Primary methodology:** `gsd:verify-goal-backward` skill

This agent also integrates with:
- `superpowers:verification-before-completion` (if available)
</skills_reference>
```

## Priority

When both GSD and superpowers skills apply:

1. **GSD skills are authoritative** for GSD-specific methodology
2. **Superpowers skills enhance** with additional practices
3. **GSD skills provide fallback** if superpowers unavailable
