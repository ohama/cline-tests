---
description: Write and run file-based tests using fslit (.flt format)
trigger: when writing tests, adding test coverage, creating .flt files, or verifying CLI tool behavior
---

# FsLit File-Based Testing

FsLit is a declarative test runner. Each `.flt` file is one self-contained test case: command, input, expected output. No config files needed.

## Running Tests

```bash
# Run all tests
fslit tests/

# Verbose (shows actual vs expected on failure)
fslit -v tests/

# Filter by glob pattern
fslit -f 'parse*' tests/

# Control parallelism
fslit -j 4 tests/
```

Exit codes: `0` = all passed, `1` = failures, `2` = no test files found.

If `fslit` is not on PATH, use `dotnet run --project <path-to-FsLit> --` instead.

## .flt File Format

```
// Test: <description>                  (optional)
// --- Command: <shell command>         (REQUIRED)
// --- Input:                           (optional, fed as temp file)
<content>
// --- Output:                          (optional, expected stdout)
<expected lines>
// --- Stderr:                          (optional, expected stderr)
<expected lines>
// --- ExitCode: N                      (optional)
// --- Timeout: N                       (optional, seconds)
```

Rules:
- One command per file. Use `&&` in shell or separate `.flt` files for multi-step.
- Only `Command` is required. All other sections are optional.
- Trailing blank lines in Input/Output/Stderr are stripped automatically.

## Substitution Variables

Use in `Command` line:

| Variable | Value |
|----------|-------|
| `%input` | Temp file containing Input section |
| `%output` | Temp file for Output section |
| `%s` | Absolute path to the `.flt` file |
| `%S` | Absolute path to the directory of the `.flt` file |

## Output Directives

Lines in `// --- Output:` support these prefixes:

| Prefix | Behavior |
|--------|----------|
| *(none)* | Exact match against next actual line |
| `CHECK-NEXT:` | Same as exact match, explicit sequential intent |
| `CHECK-RE:` | .NET regex match against next actual line |
| `CONTAINS:` | Scan forward for a line containing the substring |
| `CHECK-NOT:` | Fail if pattern found **anywhere** in entire output (global) |

All directives can mix freely:
```
// --- Output:
alpha
CHECK-RE: beta \w+
CONTAINS: target
CHECK-NOT: error
CHECK-NEXT: delta
```

## Stderr Matching

Contains-match semantics: each expected line must appear somewhere in actual stderr. Order irrelevant. Extra lines ignored.

## Examples

### Simple output
```
// Test: echo produces expected output
// --- Command: echo "hello world"
// --- Output:
hello world
```

### Input file
```
// Test: python runs input script
// --- Command: python3 %input
// --- Input:
print(2 + 3)
// --- Output:
5
```

### Error case with exit code
```
// Test: missing file exits with error
// --- Command: cat /nonexistent 2>&1
// --- ExitCode: 1
// --- Output:
CONTAINS: No such file
```

### Stderr + exit code
```
// Test: writes to stderr and fails
// --- Command: echo "err: bad" >&2; exit 42
// --- ExitCode: 42
// --- Stderr:
err: bad
```

### Regex for dynamic output
```
// Test: version output has semver format
// --- Command: mytool --version
// --- Output:
CHECK-RE: v\d+\.\d+\.\d+
```

### Negative assertion
```
// Test: no warnings in output
// --- Command: mytool build
// --- Output:
CONTAINS: success
CHECK-NOT: warning
CHECK-NOT: error
```

## Best Practices

- **One concern per file.** Each `.flt` tests one behavior.
- **Descriptive kebab-case names:** `parse-json-error.flt`, `sort-reverse.flt`
- **Use CONTAINS/CHECK-RE for fragile output** (paths, timestamps, versions).
- **Use CHECK-NOT for safety:** verify absence of errors alongside positive checks.
- **Always specify ExitCode for error tests.**
- **Keep commands portable:** `/bin/sh` syntax, `printf` over `echo -e`, `%input` over heredocs.
