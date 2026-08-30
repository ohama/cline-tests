DECLINED

Date: 2026-08-31 (session), recorded at 2026-08-30T19:36:34Z (host clock, UTC)
Plan: 08-04, Task 1 (checkpoint:decision) / Task 2 (execution)

## The option the user chose, verbatim

**Option id:** `decline`
**Name:** Decline — keep the boundary as it is

The user's own words selecting this option:

> **The user selected `decline`.** Keep the sandbox boundary exactly as it is.
>
> - **Change NOTHING under `phase-03/`.** No edit to `gen_sandbox_profile.py`, `verify_sandbox.sh`,
>   `test_gen_sandbox_profile.py`, `config.env`, or `workspace/sandbox.sb`. `EXTRA_ALLOW_PATHS`
>   stays EMPTY.
> - Do NOT restart any service — the decline branch requires no regeneration and no restart.
> - Record the outcome honestly: `git worktree add` remains impossible inside the sandbox, with
>   the reproduced cause.
> - **Write the would-be change down in full** so nobody has to re-diagnose this later: the exact
>   `render_profile()` diff, the `verify_sandbox.sh:167` precheck that must move with it, and the
>   four test assertions that break. Include the measured cost (stat metadata under `$HOME`
>   becomes visible; content, listing and writes stay denied) so a future decision can be made on
>   evidence rather than re-derivation.
> - DOC-02 (08-05) will therefore document worktree as unavailable and is only **partially met**
>   — record that plainly, do not promote or soften.

The pros/cons the user weighed (from Task 1's `<options>` block, option id `decline`):

- **Pros:** Zero change to the security boundary; Phase 3's guarantee stays exactly as shipped and
  verified. Everything else in Phase 8 still completes: registration, cards and diff review all
  work from 08-01.
- **Cons:** `git worktree add` stays impossible inside the sandbox, so Kanban's per-task worktrees
  do not work. DOC-02 must record worktree as unavailable, and DOC-02 is then only partially met —
  recorded plainly, not promoted.


## Reproduced cause (why worktree fails today, not guessed)

Three call-shape variants of `git worktree add` were run against the CURRENT (unmodified)
sandbox profile and all three failed identically:

1. pure relative target path (even under an already-allowed sibling directory)
2. target path nested several levels deep under an already-allowed subpath
3. a pre-created, empty target directory passed as the worktree path

All three: `fatal: Invalid path '/Users/ohama': Operation not permitted`, exit 128.

Kernel log (captured via `/usr/bin/log stream`, not the zsh `log` builtin which silently
shadows it and produces no output — see 08-RESEARCH.md §A6b-1):
```
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-data /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-metadata /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) Sandbox: git(23987) deny(1) file-read-metadata /Users/ohama
kernel[...] (Sandbox) Sandbox: git(23987) deny(1) file-read-metadata /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) Sandbox: git(23988) deny(1) file-read-metadata /Users/ohama
```
Repeated `deny(1) file-read-metadata /Users/ohama` is the fatal one — `git worktree add` always
realpath-resolves through `/Users/ohama` itself (the ancestor of the whole project), and this
project's entire work tree lives under `$HOME`. There is no env var, git flag, or call-shape that
avoids this ancestor stat. **No no-widening fix exists for this — that is a reproduction across
three independent call shapes, not an inference.**

## The exact would-be change (NOT applied — recorded only)

Source: 08-RESEARCH.md §A6b-5, measured working in §A6b-4 on a scratch profile only (the real
generator was never touched during diagnosis).

### 1. `phase-03/sandbox/gen_sandbox_profile.py`, `render_profile()` (currently lines 82-97)

Current:
```python
lines.append(f'(deny file-read* (subpath "{protected_root}"))')
lines.append(f'(deny file-write* (subpath "{protected_root}"))')
for p in allow_paths:
    lines.append(f'(allow file-read* (subpath "{p}"))')
    lines.append(f'(allow file-write* (subpath "{p}"))')
```

Would-be replacement:
```python
lines.append(f'(deny file-read-data (subpath "{protected_root}"))')
lines.append(f'(allow file-read-metadata (subpath "{protected_root}"))')
lines.append(f'(deny file-write* (subpath "{protected_root}"))')
for p in allow_paths:
    lines.append(f'(allow file-read* (subpath "{p}"))')
    lines.append(f'(allow file-read-data (subpath "{p}"))')   # NEW -- without this, every
                                                                 # already-allowed repo path
                                                                 # would silently break (§A6b-3)
    lines.append(f'(allow file-write* (subpath "{p}"))')
```

Also would need updating (not applied):
- The docstring's line-count claim (currently `"Emits exactly 2 + 2 + 2*len(allow_paths) lines"`,
  render_profile() lines 87-90) becomes `2 + 3 + 3*len(allow_paths)`.
- The docstring's claim that only wildcard forms are used ("Only the file-read*/file-write*
  wildcard forms are used (never the narrow ... file-read-data forms...)") is no longer true and
  must be rewritten to explain WHY the narrow form is now required: a broader `file-read*` allow
  does NOT override a narrower `file-read-data` deny at any line position (see finding #2 below) --
  each punched path needs its own explicit `file-read-data` allow or it would be silently broken.
- The module docstring at the top of the file (current lines ~9-13, "Profile shape ... an explicit
  `(deny file-read*/file-write* (subpath <protected-root>))` pair, then an `(allow
  file-read*/file-write* (subpath <path>))` pair per punched-through path") describes the OLD
  two-line-pair shape and would need to describe the new deny/allow-metadata/deny triple at the
  root and three-line-per-path punch-through instead.

### 2. `phase-03/sandbox/verify_sandbox.sh`, precheck function (deny_read var at line 167)

Current (line 167):
```bash
deny_read="(deny file-read* (subpath \"$expected_root\"))"
```
This is the line the standing gate's fail-open guard greps for. If the generator changed without
this line moving with it, the gate would hard-fail on every run because the profile would no
longer contain this exact string.

Would-be change: `deny_read` becomes `(deny file-read-data (subpath "$expected_root"))`; add a
new required check for `(allow file-read-metadata (subpath "$expected_root"))` with its own
failure message; leave the existing `deny_write` (`file-write*`) check untouched; keep the
ordering guard (currently computing `deny_line_num` from the deny-read line and comparing against
the first `(allow file-read* (subpath` punch line), and add an equivalent ordering check that the
first `(allow file-read-data (subpath` punch line is also after the new deny line. The comment
"SBPL is last-match-wins" (both in this script and in `gen_sandbox_profile.py`'s own docstring)
would need correcting to state: same-keyword rules are order-dependent (last-match-wins holds
within one operation keyword), but a rule with a MORE SPECIFIC operation keyword is never
overridden by a rule with a BROADER keyword regardless of line order (finding below).

### 3. `phase-03/tests/test_gen_sandbox_profile.py` — four sites that WOULD break, none touched

- `TestRenderProfile.test_exact_text_and_ordering` (current lines 34-49) — asserts the exact
  eight-line text for `protected_root="/Users/ohama"`, `allow_paths=["/Users/ohama/.cline",
  "/p/repo-a"]`. Would need `expected` rewritten to the new ten-line shape (2 root deny/allow +
  1 root deny + 3 lines per each of the 2 allow paths = 2+1+6 = 9 content lines + version/default =
  11 total... exact count per the "2 + 3 + 3*len(allow_paths)" formula above).
- `TestRenderProfile.test_allow_punchthroughs_come_after_deny_root` (current lines 51-63) — does
  `lines.index('(deny file-read* (subpath "/Users/ohama"))')`; this exact string would no longer
  exist in the output, so `lines.index(...)` would raise `ValueError` immediately. Would need to
  look for `(deny file-read-data (subpath "/Users/ohama"))` instead.
- `TestWildcardFormsOnly.test_no_narrow_rule_forms` (current lines 66-74) — currently asserts
  `self.assertNotIn("file-read-data", text)`. This assertion would need to be INVERTED (assert it
  IS present), while `file-write-data`/`file-write-create` stay forbidden. The class docstring
  ("Case 2: only file-read*/file-write* wildcards, never the narrow forms") would need renaming
  since the premise is no longer true for reads.
- `TestEmptyReposList.test_empty_allow_list_still_denies_root` (current lines 202-210) — currently
  asserts `(deny file-read* (subpath "/Users/ohama"))` and `(deny file-write* (subpath
  "/Users/ohama"))`. Would need to assert `(deny file-read-data (subpath "/Users/ohama"))`,
  `(allow file-read-metadata (subpath "/Users/ohama"))`, and the unchanged `(deny file-write*
  (subpath "/Users/ohama"))`.
- A NEW test (not currently present) would additionally be required: for every punched path there
  is a matching `(allow file-read-data (subpath "<path>"))` line — the regression guard for the
  ordering finding below, since without it the fail mode is silent (repos that used to work go
  read-denied with no error).

## The SBPL finding that makes this a code change, not a config value

Not "line order" -- **operation-keyword specificity**. A four-way controlled ordering experiment
(all four run this session, not inferred):

| Experiment | Rule order (summary) | Result inside allowed repo (`ls .`) |
|---|---|---|
| order-test-1 | `deny file-read-data(HOME)` then `allow file-read*(repo)` | DENIED |
| order-test-2 | `allow file-read*(repo)` then `deny file-read-data(HOME)` (reversed) | DENIED |
| order-test-3 | `deny file-read-data(HOME)` then `allow file-read-data(repo)` (same keyword) | ALLOWED |
| order-test-4 | order-test-1 rules + an added explicit `allow file-read-data(repo)` | ALLOWED |

order-test-1 and -2 being identically DENIED regardless of which rule is written first proves
this is not a line-order bug: a specific operation keyword (`file-read-data`) is never covered by
a broader wildcard keyword (`file-read*`) no matter which comes later in the text. This directly
contradicts `gen_sandbox_profile.py`'s own docstring comment ("SBPL is last-match-wins") for the
rule shape this project has never previously emitted (mixed specificity). Same-keyword rules
(order-test-3/4) remain genuinely last-match-wins. This is why widening `$HOME` to
`file-read-data`+`file-read-metadata` is a `render_profile()` code change, not an
`EXTRA_ALLOW_PATHS` config value: it changes what operation each emitted rule targets, not which
paths are punched through.

## Measured cost (evidence, not estimate)

Verified live under a scratch profile carrying exactly the would-be change (never applied to the
real generator or `workspace/sandbox.sb`):

- **Becomes readable:** stat-level metadata for any path under `$HOME` whose name is already
  known — existence, size, permissions, owner, and the three timestamps (`/usr/bin/stat
  /Users/ohama/.gitconfig` succeeds and returns real metadata).
- **Stays denied — content:** `/bin/cat /Users/ohama/.gitconfig` still refused.
- **Stays denied — listing:** `/bin/ls -la /Users/ohama` still refused. A directory listing is
  `file-read-data` on the directory itself, so there is no way to enumerate what exists under
  `$HOME` even with this widening — a path must already be known to be stat'd.
- **Stays denied — unrelated project content:** `cline-analysis.md` at the repo root (an
  unrelated file, not under any punched-through path) stayed unreadable.
- **Writes untouched:** `file-write*` deny at the root is not modified by this change at all.
- All three `git worktree add` call-shape variants succeeded under this scratch profile, with the
  worktree actually present on disk (`.git` gitdir pointer and file content both verified).

## Consequence for DOC-02 (08-05)

`git worktree add` stays impossible inside the sandbox. DOC-02's worktree section must document
this as unavailable in this deployment. **DOC-02 is therefore only partially met** — this is
recorded plainly here and must not be promoted or softened in 08-05's summary.
