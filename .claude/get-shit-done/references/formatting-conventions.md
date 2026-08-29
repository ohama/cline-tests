# Formatting Conventions

Standard formatting conventions for GSD documentation.

## Checkbox Symbols

| Symbol | Usage | Context |
|--------|-------|---------|
| `[ ]` | Unchecked checkbox | Checklists, success criteria |
| `[x]` | Checked checkbox | Completed items in markdown |
| `✓` | Pass/verified | Status indicators, examples |
| `✗` | Fail/missing | Status indicators, examples |
| `⚠️` | Warning | Caution states |

### Examples

**Checklists (use `[ ]`):**
```markdown
- [ ] Task 1 completed
- [ ] Verification passed
- [ ] Summary created
```

**Status tables (use `✓`/`✗`):**
```markdown
| Check | Status |
|-------|--------|
| File exists | ✓ |
| Has exports | ✓ |
| Is imported | ✗ |
```

**Inline status (use `✓`/`✗`):**
```markdown
- Login endpoint ✓
- Logout endpoint ✗ (missing)
```

## File Path Notation

Always use backticks for file paths:

```markdown
✓ Correct: `src/components/Chat.tsx`
✗ Wrong: src/components/Chat.tsx
```

### In tables:

```markdown
| File | Status |
|------|--------|
| `src/api/auth.ts` | Created |
```

### In prose:

```markdown
The component is located at `src/components/Chat.tsx`.
```

## Code Blocks

### Language hints:

```markdown
```bash
npm install
```

```typescript
const x: string = "hello";
```

```yaml
phase: "01"
plan: "02"
```
```

### Inline code:

Use backticks for:
- Commands: `npm run build`
- Function names: `getCurrentUser()`
- Variable names: `userId`
- File names: `package.json`

## YAML Frontmatter

Standard field order:

```yaml
---
name: gsd-agent-name
description: Brief description
tools: Read, Write, Bash
color: green
spawned_by:
  - /gsd:command
skills_integration:
  - gsd:skill-name
  - superpowers:skill-name
---
```

## Tables

### Alignment:

```markdown
| Left | Center | Right |
|------|:------:|------:|
| data | data   | data  |
```

### Minimal borders:

```markdown
| Column 1 | Column 2 |
|----------|----------|
| data     | data     |
```

## Section Headers

Use ATX-style headers:

```markdown
# Top Level (document title only)
## Major Section
### Subsection
#### Detail (rarely needed)
```

## Emphasis

- **Bold** for important terms, status keywords
- *Italic* for introducing new terms
- `Code` for technical terms, commands, file paths

## Lists

### Unordered (use `-`):

```markdown
- Item 1
- Item 2
  - Nested item
```

### Ordered (use `1.`):

```markdown
1. First step
2. Second step
3. Third step
```

## XML-style Tags

For agent prompts, use lowercase with underscores:

```markdown
<role>
Content here
</role>

<success_criteria>
- [ ] Criterion 1
</success_criteria>
```

## Status Keywords

Capitalize status keywords:

- VERIFIED, FAILED, MISSING
- WIRED, ORPHANED, STUB
- BLOCKED, COMPLETE, PENDING

## 한국어 문체

문서 작성 시 "~입니다/~합니다" 경어체가 아닌 **"~이다/~한다" 평서체**를 사용한다.

```markdown
✓ 올바름: 이 파일은 설정을 관리한다.
✗ 잘못됨: 이 파일은 설정을 관리합니다.

✓ 올바름: 빌드 전 stale 파일을 제거해야 한다.
✗ 잘못됨: 빌드 전 stale 파일을 제거해야 합니다.
```
