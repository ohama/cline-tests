# Hooks vs Agents

GSD distinguishes between **hooks** (utility scripts) and **agents** (AI subagents).

## Hooks (Utility Scripts)

Located in `.claude/hooks/`, these are Node.js scripts that run as CLI utilities.

| File | Purpose | Usage |
|------|---------|-------|
| `gsd-config.js` | Config loading, model resolution | `node .claude/hooks/gsd-config.js --model {agent}` |
| `gsd-check-update.js` | Background update check | Called by SessionStart hook |
| `gsd-statusline.js` | Status bar rendering | Called by statusLine hook |
| `gsd-logger.js` | Centralized logging | `require('./gsd-logger')` |

**Hooks are NOT agents.** They:
- Do not have agent definition files in `.claude/agents/`
- Are not spawned via the Task tool
- Run as synchronous Node.js processes
- Do not consume context budget

## Agents (AI Subagents)

Located in `.claude/agents/`, these are AI subagents spawned by orchestrators.

| Agent | Purpose | Spawned By |
|-------|---------|------------|
| `gsd-planner` | Creates PLAN.md files | `/gsd:plan-phase` |
| `gsd-executor` | Executes plans | `/gsd:execute-phase` |
| `gsd-verifier` | Verifies goal achievement | `/gsd:verify-work` |
| `gsd-debugger` | Systematic debugging | `/gsd:debug` |

**Agents ARE spawned via Task tool** with:
- `subagent_type: gsd-{name}`
- `model: {resolved from profile}`
- Full AI context and tools

## Usage Pattern

### Correct: Hooks as utilities
```bash
# Get config value
node .claude/hooks/gsd-config.js commit_docs true

# Resolve model for agent
MODEL=$(node .claude/hooks/gsd-config.js --model gsd-planner)
```

### Correct: Agents via Task tool
```markdown
<invoke name="Task">
  <parameter name="subagent_type">gsd-planner</parameter>
  <parameter name="model">sonnet</parameter>
  <parameter name="prompt">...</parameter>
</invoke>
```

### Wrong: Treating hooks as agents
```markdown
<!-- DO NOT do this -->
<invoke name="Task">
  <parameter name="subagent_type">gsd-config</parameter>  <!-- Not an agent! -->
</invoke>
```

## Summary

| Type | Location | Spawning | Context |
|------|----------|----------|---------|
| Hook | `.claude/hooks/` | `node script.js` | None |
| Agent | `.claude/agents/` | Task tool | AI context |
