# contextWindow Injectability — Finding (07-02 Task 1)

**Question:** Can the container's Cline (installed fresh by harbor's `cline-cli` adapter,
`--agent-kwarg cline-version=3.0.53`) be told this stack's live `contextWindow=29000` /
`trigger=26100` (×0.9 once, top-level `settings.contextWindow`, per `docs/32k-compaction-policy.md`
§2-3) instead of falling back to `contextWindow=maxInputTokens=128_000`?

**Method:** Read the INSTALLED harbor 0.22.0 adapter source
(`~/.local/share/uv/tools/harbor/lib/python3.13/site-packages/harbor/`) and the INSTALLED cline
3.0.53 compiled binary (`/opt/homebrew/lib/node_modules/cline/bin/.cline`, via `strings`/Python
`.decode("latin1")` regex scans) directly on this machine — not a remote copy. Zero `cline`
invocations, zero `harbor run` invocations (this plan's budget for both is 0).

**VERDICT: INJECTABLE**

Mechanism: `harbor run --extra-docker-compose phase-07/bench/cline-cw-overlay.yaml`, which
bind-mounts a project-authored `providers.json` (top-level `settings.contextWindow=29000`, the
exact schema shape `phase-01/config/apply_provider_config.sh` already proved live works for the
host) into the container at a fixed, task-independent path, and points the container's cline at
it via `CLINE_PROVIDER_SETTINGS_PATH`. Recorded in `phase-07/bench/config.env` as
`CW_INJECTION=applied` and `HARBOR_EXTRA_ARGS=--extra-docker-compose
$PROJECT_ROOT/phase-07/bench/cline-cw-overlay.yaml`.

**Not live-verified.** This plan runs no `harbor run`. 07-03's smoke run is the first live check —
see "What 07-03 must confirm first" at the bottom.

---

## Avenue A — the installed adapter's own `run_flags` / `CLI_FLAGS` / env dict / `PROVIDER_API_KEY_ENVS`

Located the installed file directly (not cloned from GitHub):

```
$ find "$(dirname "$(command -v harbor)")/.." -name cline.py -path '*agents*'
/Users/ohama/.local/bin/../share/uv/tools/harbor/lib/python3.13/site-packages/harbor/agents/installed/cline/cline.py
```

`CLI_FLAGS` (the descriptor-driven CLI surface `--agent-kwarg` exposes for this adapter):

```python
CLI_FLAGS = [
    CliFlag("thinking", cli="--thinking", type="enum",
            choices=["none", "low", "medium", "high", "xhigh"]),
    CliFlag("max_consecutive_mistakes", cli="--max-consecutive-mistakes", type="int"),
]
```

No `contextWindow`-shaped entry anywhere in this list, nor in the constructor's full kwarg
surface (quoted verbatim from the class docstring, matches the constructor's actual kwarg-pop
list): `tarball-url`, `tarball-path`, `github-user`, `commit-hash`, `cline-version`,
`setup-retries`, `setup-retry-delay-sec`, `setup-command-timeout-sec`, `plugin-source`,
`plugin-tarball-url`, `plugin-tarball-path`, `thinking`, `timeout`/`timeout-sec`/
`cline-timeout-sec`, `reasoning-effort`, `max-consecutive-mistakes`. None of these touch context
window, max input tokens, or providers.json.

`PROVIDER_API_KEY_ENVS` (used by `_resolve_api_key`, confirms 07-RESEARCH.md Pitfall 3's finding
that `openai-compatible` falls through to the generic `API_KEY`):

```python
PROVIDER_API_KEY_ENVS = {
    "anthropic": "ANTHROPIC_API_KEY", "gemini": "GEMINI_API_KEY", "google": "GOOGLE_API_KEY",
    "openai": "OPENAI_API_KEY", "openrouter": "OPENROUTER_API_KEY", "cline": "CLINE_API_KEY",
    "xai": "XAI_API_KEY",
}
```
`openai-compatible` is absent — confirmed, matches `config.env`'s existing comment.

The exec-time env dict actually sent into the container for the `cline ... -- <prompt>` run
(`create_run_agent_commands`, exact source):

```python
env = {
    "PROVIDER": provider,
    "API_KEY": api_key,
    "MODELID": model,
    "CLINE_WRITE_PROMPT_ARTIFACTS": "1",
    "CLINE_PROMPT_ARTIFACT_DIR": "/logs/agent",
}
```

Five fixed keys. No `BASE_URL`. No `CONTEXT_WINDOW`/`CLINE_CONTEXT_WINDOW`/anything similar.

The actual `run_flags` list built for the `cline` CLI invocation:

```python
run_flags = ["-P", f"{cline_provider}", "-k", "$API_KEY", "-m", "$MODELID", "--json", "--yolo"]
if self._cline_timeout_sec is not None:
    run_flags.extend(["-t", str(self._cline_timeout_sec)])
```

Six fixed flags (`-P`/`-k`/`-m`/`--json`/`--yolo`, optionally `-t`) plus whatever `CLI_FLAGS`
resolves to. No context-window flag exists to add here even by choice — `cline --help` (3.0.53,
re-quoted from `docs/cline-config-pins.md`, not re-invoked live per house rule) confirms the full
flag surface is exactly `-c/--cwd`, `--compaction`, `--auto-approve`, `-m/--model`, `-P/--provider`,
`-t/--timeout`, `--id`, `--config`, `--data-dir` — no `--context-window`, no `-b/--base-url`.

**Avenue A conclusion:** no contextWindow surface anywhere in the adapter's own flags, kwargs, or
fixed env dict.

## Avenue B — `harbor run --help` / `harbor --help`, full `--agent-kwarg` surface

```
$ harbor --version
0.22.0
```

Relevant excerpt from `harbor run --help` (Agent panel):

```
│ --agent               -a      [aider|antigravity-cli|...|cline-cli|codex|...]  Agent to run   │
│ --model               -m      <str>  Model name for the agent (can be used multiple times)     │
│ --ak,--agent-kwarg            <str>  Additional agent kwarg in the format 'key=value'. You can  │
│                                      view available kwargs by looking at the agent's `__init__` │
│                                      method. Can be set multiple times to set multiple kwargs.  │
```

`harbor`'s own help text is explicit: `--agent-kwarg` is generic across all ~40+ supported agents
and is NOT self-documenting — "look at the agent's `__init__` method" is the only enumeration,
which is exactly Avenue A's `ClineCli.__init__` kwarg-pop list above. There is no separate,
richer per-agent `--help` subcommand that lists `cline-cli`'s kwargs beyond what the source
already shows.

**Avenue B conclusion:** confirms Avenue A is the complete, authoritative kwarg list — nothing
additional surfaces from `--help` alone.

## Avenue C — fixed template vs. arbitrary host-env forwarding; is `BASE_URL`/`API_KEY` in it?

Two separate mechanisms exist in the installed harbor 0.22.0, and it matters which one the
`cline-cli` agent actually uses:

1. **Docker Compose CLI env** (`environments/docker/docker.py` `_compose_env_vars`):
   `env_vars = merge_compose_env(base_env=os.environ if include_os_env else None, ...)` — the
   FULL host `os.environ` (including our shell's exported `API_KEY`/`BASE_URL`) is passed to the
   **`docker compose` command itself**, for `${VAR}` substitution inside compose YAML files
   (e.g. `${CONTEXT_DIR}`, `${PREBUILT_IMAGE_NAME}` in `docker-compose-build.yaml`/
   `-prebuilt.yaml`). Confirmed by reading both shipped compose files — neither declares an
   `environment:` block for the `main` service, so this path does NOT, by itself, inject any host
   env var into the container's own runtime environment.

2. **Per-exec env dict** (`agents/installed/base.py` `_exec`/`exec_as_agent`, called by
   `cline.py`'s `create_run_agent_commands`): exactly the five-key fixed dict quoted in Avenue A,
   turned into `docker compose exec -e KEY=VALUE ...` pairs one-for-one
   (`environments/docker/docker.py` `_compose_exec`):
   ```python
   if env:
       for key, value in env.items():
           exec_command.extend(["-e", f"{key}={value}"])
   ```

**Answer: fixed template, not arbitrary passthrough.** `cline-cli`'s adapter hardcodes exactly
`PROVIDER`/`API_KEY`/`MODELID`/`CLINE_WRITE_PROMPT_ARTIFACTS`/`CLINE_PROMPT_ARTIFACT_DIR` into the
actual `cline` invocation's environment. `API_KEY` IS in that set (as `env["API_KEY"]`, resolved
by `_resolve_api_key` — which also independently falls back to the harbor HOST process's own
`os.environ["API_KEY"]` via `_env_sources() = (self._resolved_env_vars, self._extra_env,
os.environ)`, so our shell's `API_KEY=... harbor run ...` pattern works regardless).

**`BASE_URL` is NOT in that set** — confirmed absent from the fixed dict, and separately confirmed
the compiled cline 3.0.53 binary's only `process.env.BASE_URL` reads are inside the
`connect <platform>` webhook-server subcommands (`slack`/`telegram`/`discord`/`whatsapp`/
`google-chat` connector bootstrapping — an unrelated feature), never in the core
`-P/-k/-m -- <prompt>` single-shot invocation path harbor's adapter actually uses. This settles
07-RESEARCH.md Open Question 2 from the source side, and it changes the picture: for the
`openai-compatible` provider specifically, `baseUrl` is sourced exclusively from
`getProviderConfig()` — i.e. from a persisted `providers.json` entry (confirmed:
`function h8($){...let Z=new E1().getProviderConfig($,{includeKnownModels:!1}),J=Z?.baseUrl...}`
where the calling context is gated by `function j4($){return $==="openai-compatible"}`). Since
nothing in harbor's `cline-cli` adapter ever writes `providers.json` inside the fresh container
(`install()` only installs the npm package; `create_run_agent_commands`'s setup command only
writes `~/.cline/data/globalState.json`, an onboarding-flags file, never `settings/
providers.json`), **an unmodified container-side cline would have no configured `baseUrl` for
`openai-compatible` at all** — a compounding problem beyond the contextWindow question this task
was scoped to, and the same mechanism this VERDICT applies (Avenue E) incidentally also supplies
it. Not a fix bundled outside this plan's scope: Avenue C only asked to check and record this,
which is done here: the mechanism found under Avenue E happens to solve both, and that overlap is
disclosed rather than silently exploited beyond what Avenue E already covers.

## Avenue D — documented Cline env var / config path for context window

`docs/cline-config-pins.md` already records the installed 3.0.53 `--help` surface in full (not
re-invoked here, per house rule / plan budget): no `--context-window` flag exists.

`strings`-equivalent scan of the installed binary for context-window-shaped literals:

```
$ python3 -c "... re.finditer(r'CLINE_CONTEXT', text) ..."   -> 0 matches
$ python3 -c "... re.finditer(r'contextWindow', text) ..."   -> 20 matches, ALL inside
    JSON-schema / provider-settings-object code, e.g.:
    contextWindow: f.number().int().positive().optional()   (provider-settings schema field)
    maxInputTokens: e.contextWindow                          (settings.contextWindow -> maxInputTokens
                                                               mapping when building the LLM handler)
```

Every `contextWindow` occurrence in the binary is a JSON-schema field name or an object literal
key inside provider-settings-object plumbing — never an environment-variable name, never a CLI
flag string, never a `process.env.*` read.

`CLINE_SANDBOX_DATA_DIR` and `CLINE_PROVIDER_SETTINGS_PATH` both exist as real, live-confirmed env
vars (`strings`-confirmed against the same binary: full env-var literal list includes both). Both
are **relocation** vars — they redirect WHERE cline reads/writes its data/settings from, they do
not themselves carry a contextWindow value. `CLINE_SANDBOX_DATA_DIR` relocates the whole data dir
and, as the plan text already anticipated, a container cannot see host paths anyway, so it is
useless alone. `CLINE_PROVIDER_SETTINGS_PATH` is narrower — it relocates only the
`providers.json` path — and is exactly what Avenue E turns out to need: relocation is not
configuration BY ITSELF, but relocation PLUS a bind-mounted file containing the actual
`contextWindow` value at the relocated path IS configuration. That combination is Avenue E, not
Avenue D alone.

**Avenue D conclusion (in isolation, no bind mount):** no env var or config path sets a
contextWindow value by itself. Confirms the plan's own prediction for `CLINE_SANDBOX_DATA_DIR`.

## Avenue E — bind mount we control WITHOUT editing task.toml

Read `harbor/environments/docker/docker.py` and its compose files directly.

`harbor run`/`harbor job start` expose `--extra-docker-compose <path>` (repeatable), a real,
documented, generic CLI flag — **not** a `task.toml` field, **not** a harbor source patch:

```
$ harbor run --help   (Environment panel)
│ --extra-docker-compose  <path>  Additional Docker Compose overlay file. Can be used multiple  │
│                                 times.                                                         │
```

Source wiring, traced end to end:
- `harbor/cli/jobs.py:897-905` declares the Typer option; `:1693-1694`:
  `if extra_docker_compose is not None: config.environment.extra_docker_compose.extend(
  extra_docker_compose)`
- `harbor/models/trial/config.py:214`: `extra_docker_compose: list[Path] = Field(
  default_factory=list)` on `EnvironmentConfig`
- `harbor/environments/docker/docker.py`, the compose-file-list builder (`paths.extend(
  self.extra_docker_compose_paths)`), inserted after the task's own `environment/
  docker-compose.yaml` (if any) and before the env/mounts/egress overlays harbor itself adds —
  i.e. it participates in the SAME multi-file `docker compose -f ... -f ...` merge as every other
  compose file for the `main` service, with no special restriction.

This is a real way in that is neither editing a task file nor patching harbor — Avenue E's own
framing ("If the only way in is editing a task file or patching harbor, the answer is no") is
therefore answered: it is not the only way in, this is a third way, and it is generic
harbor-supplied infrastructure.

**Does it actually reach cline's provider resolution, and not get lost?** Three more source
points, chained:

1. **The env var survives the exec call.** `docker.py` `_compose_exec` (Avenue C, quoted above)
   only ever APPENDS specific `-e KEY=VALUE` pairs to `docker compose exec`; it is standard Docker
   exec semantics — it never clears or replaces the container's own environment. A
   compose-service-level `environment:` entry (Dockerfile-`ENV`-equivalent, set once at container
   creation from our overlay) is therefore inherited by every subsequent `docker compose exec`
   call, INCLUDING the one that runs `cline ... -- <prompt>` with its own fixed 5-key `-e` list —
   the two coexist rather than one erasing the other.
2. **cline's settings-path resolver honors it verbatim** (strings-confirmed against the installed
   3.0.53 binary):
   ```
   function sC(){let C=process.env.CLINE_PROVIDER_SETTINGS_PATH?.trim();
   if(C)return C;
   return E(D(),"settings","providers.json")}
   ```
   If set (non-empty after `.trim()`), used AS-IS. Only falls back to the default
   `~/.cline/data/settings/providers.json` when unset/empty.
3. **cline's own single-shot bootstrap consults it even in headless `--json` mode** — the exact
   invocation shape harbor's adapter uses (`--json --yolo`, non-interactive, `-- <prompt>` at the
   end):
   ```
   ...outputMode==="json"||!process.stdin.isTTY&&!n.interactive... {
     let g=q.getProviderConfig(p,{includeKnownModels:!1}), ...
   }
   ```
   `p` is the `-P`-selected provider id; `q` is the settings-manager instance built from whatever
   path `sC()` resolved. For `openai-compatible` specifically this is also where `baseUrl` comes
   from (Avenue C).

**Mechanism actually used** (see `phase-07/bench/cline-cw-overlay.yaml`,
`phase-07/bench/cline-cw-providers.json`):
- `cline-cw-providers.json` — an entirely new, project-authored file, NOT a copy of the host's
  real `~/.cline/data/settings/providers.json`, NOT read from it, NOT written to it (house rule 6
  compliance: the literal path `~/.cline/data/settings/providers.json` is never targeted, host or
  container — this mechanism exists specifically to route AROUND that path). Contains exactly the
  schema shape `docs/32k-compaction-policy.md` §2 already proved live: top-level
  `settings.contextWindow=29000` (not `settings.models[].contextWindow`), plus
  `baseUrl=http://host.docker.internal:4000/v1` (container-reachable, matching
  `HARBOR_BASE_URL`) and a non-secret placeholder `apiKey` (matches `HARBOR_API_KEY`'s existing
  documented posture — any non-empty key is accepted and none of this stack's keys are treated as
  secrets).
- `cline-cw-overlay.yaml` — a docker-compose overlay for the `main` service only: a read-only
  bind mount of the above file to `/opt/harbor-cline-cw/providers.json` (an absolute path outside
  any task's own `$HOME`, so it does not depend on knowing each of the 12 tasks' own Dockerfile
  `USER`), plus `environment: CLINE_PROVIDER_SETTINGS_PATH: /opt/harbor-cline-cw/providers.json`
  pointing cline at it. `source:` uses `${PROJECT_ROOT}` compose-variable interpolation rather
  than a bare relative path, because a bare relative path in a multi-`-f` merge would resolve
  against harbor's own installed package directory (the first compose file in harbor's internally
  built list), not this overlay file's own directory.
- Wired into `phase-07/bench/config.env` as `HARBOR_EXTRA_ARGS=--extra-docker-compose
  $PROJECT_ROOT/phase-07/bench/cline-cw-overlay.yaml`.

**Avenue E conclusion:** yes, a real, sourced, non-task-file, non-patch bind-mount mechanism
exists and — chained through three independent, directly-quoted points in the installed adapter
and the installed cline binary — is expected to reach cline's actual provider/context-window
resolution for the exact single-shot invocation shape harbor's `cline-cli` adapter uses.

---

## Out of scope (recorded so nobody revisits it mid-run)

- **Patching harbor's source.** Not done, not needed — Avenue E's mechanism is entirely
  CLI-flag-driven.
- **Editing any `task.toml` or `environment/Dockerfile`.** Not done — the overlay is added purely
  via `--extra-docker-compose`, independent of any task's own files, and applies identically to
  whichever of the 12 tasks 07-03/07-04 select.
- **Changing litellm/role-shim configuration.** Not touched, not needed, and would require
  restarting a live service — a Phase 2 posture change this phase is not permitted to make.
- **Writing to the host's own `~/.cline/data/settings/providers.json`.** Never targeted, by
  construction (Avenue E's whole design routes around that literal path via
  `CLINE_PROVIDER_SETTINGS_PATH`).

## What 07-03 must confirm first (this plan does not run it)

1. That `harbor run` with `--extra-docker-compose` actually accepts a relative
   `phase-07/bench/cline-cw-overlay.yaml` path (or that `run_task.sh`'s `--dry-run` prints the
   resolved absolute path correctly) and that `docker compose config` (a read-only, non-mutating
   command) shows the bind mount and env var actually merged into the resolved `main` service
   before any container is created.
2. That the container actually starts with the mount present (`docker compose exec main cat
   /opt/harbor-cline-cw/providers.json` during/after the smoke run, or equivalent evidence in
   `agent/setup/*.log`).
3. That cline's first turns do not show an immediate "provider not configured"/auth-style error
   (which would mean the overlay did not take effect, and the run reverted to the 128k fallback --
   at which point this plan's own contingency already applies: label the resulting failure
   `fail-context` with its turn number and `max_prompt_tokens`, per `run_task.sh`'s verdict rule,
   not an excluded outlier).

If `CLINE_PROVIDER_SETTINGS_PATH` turns out NOT to be honored in this exact single-shot
invocation shape (the one static-analysis gap this FINDING cannot close without a live run), the
practical fallback is unchanged from what a NOT-INJECTABLE verdict would have meant:
`fail-context` becomes a real, disclosable BCH-03 row with a named cause, not a broken harness.
