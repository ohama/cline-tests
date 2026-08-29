---
name: gsd:resolve-model-profile
description: Centralize model resolution for GSD agents from orchestrators
trigger: All orchestrator commands before spawning agents
consumers:
  - execute-phase
  - plan-phase
  - quick
  - debug
  - new-project
  - new-milestone
  - audit-milestone
  - research-phase
  - verify-work
  - map-codebase
---

# Model Profile Resolution

Resolves the correct model for a GSD agent based on project config and model profiles.

## Usage

Before spawning any agent, resolve its model:

```bash
MODEL=$(node .claude/hooks/gsd-config.js --model {agent-name})
```

## Resolution Flow

```
1. Read .planning/config.json -> get model_profile (quality/balanced/budget)
2. If not set -> default to "balanced"
3. Read .claude/get-shit-done/config/model-profiles.json
4. Look up agent in selected profile
5. Return model (opus/sonnet/haiku)
6. If agent not found -> return "sonnet"
```

## Profiles Reference

| Profile | Use Case | Cost |
|---------|----------|------|
| quality | High accuracy, complex reasoning, production code | High |
| balanced | Good performance, reasonable cost (default) | Medium |
| budget | Fast iteration, simple tasks, experimentation | Low |

## Agent Model Assignments

Check `model-profiles.json` for current assignments. Key agents:

| Agent | quality | balanced | budget |
|-------|---------|----------|--------|
| gsd-planner | opus | sonnet | sonnet |
| gsd-executor | opus | sonnet | haiku |
| gsd-verifier | opus | sonnet | haiku |
| gsd-debugger | opus | sonnet | sonnet |
| gsd-roadmapper | opus | sonnet | haiku |

## Orchestrator Integration Pattern

Every orchestrator MUST use this pattern before spawning agents:

### Step 1: Resolve Model

```bash
MODEL=$(node .claude/hooks/gsd-config.js --model gsd-planner)
```

### Step 2: Use in Task Tool

```markdown
Use the Task tool with:
- subagent_type: gsd-planner
- model: {resolved model from step 1}
```

## Runtime Profile Switching

Users can switch profiles via `/gsd:set-profile`:

```bash
# Check current profile
node .claude/hooks/gsd-config.js model_profile

# Set new profile (updates .planning/config.json)
# This is done by the set-profile command
```

## Fallback Behavior

If any error occurs during resolution:

1. Log error to `~/.claude/logs/gsd-hooks.log`
2. Return "sonnet" as safe default
3. Continue execution (never block on profile resolution)

## Adding New Agents

When adding a new agent to GSD:

1. Add to `model-profiles.json` under all three profiles
2. Document rationale in the `_rationale` section
3. Update this skill's agent table

## Validation

The config helper validates:

- Profile exists (quality/balanced/budget)
- Agent exists in profile
- Returns valid model (opus/sonnet/haiku)

Invalid inputs fall back to defaults rather than failing.

## Integration with gsd-config.js

This skill documents the model resolution logic implemented in:

```
.claude/hooks/gsd-config.js --model {agent-name}
```

The helper handles:
- Config file loading
- Profile lookup
- Model resolution
- Error fallback
