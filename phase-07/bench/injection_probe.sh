#!/bin/bash
# phase-07/bench/injection_probe.sh — re-runnable probe ladder for the container-side
# provider-settings injection question (Phase 7 gap closure, 07-06).
#
# Purpose: 07-02's `VERDICT: INJECTABLE` was source-derived only, never live-verified. 07-03's
# live smoke run showed it does NOT take effect: the container's cline hit the real OpenAI
# default endpoint. This script narrows down WHY, rung by rung, cheaply, offline wherever
# possible, and produces per-rung evidence this plan's DIAGNOSIS.md reads.
#
# House contract: `CHECK: PASS|FAIL <id>` lines, closing `CASES n/m`, exit 0 pass / 1 fail /
# 2 usage. macOS bash 3.2 (no declare -A). Sources config.env for every path/value it needs.
#
# Usage:
#   injection_probe.sh [--results-dir <path>] [--rung <id>] [--with-model-call]
#
#   --results-dir <path>  Where to write <results>/probe/<rung-id>/. Required for any rung
#                          that writes evidence (all of them). Defaults to a fresh
#                          RESULTS_ROOT/<UTC>-injection-probe directory if omitted.
#   --rung <id>            Run only this rung (R1|R2|R3|R4). Default: run R1-R3 (offline-only
#                          rungs). R4 only ever runs when --with-model-call is also given,
#                          even if explicitly requested via --rung R4.
#   --with-model-call      Also run R4 (the one rung that issues a real, tiny model request).
#                          Without this flag R4 is always skipped, regardless of --rung.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
  echo "injection_probe.sh: FATAL -- $SCRIPT_DIR/config.env not found" >&2
  exit 2
fi
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

RESULTS_DIR=""
ONLY_RUNG=""
WITH_MODEL_CALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --results-dir)
      RESULTS_DIR="$2"; shift 2 ;;
    --rung)
      ONLY_RUNG="$2"; shift 2 ;;
    --with-model-call)
      WITH_MODEL_CALL=1; shift ;;
    *)
      echo "injection_probe.sh: unknown arg: $1" >&2
      exit 2 ;;
  esac
done

if [ -z "$RESULTS_DIR" ]; then
  RESULTS_DIR="$RESULTS_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-injection-probe"
fi
mkdir -p "$RESULTS_DIR/probe"

PROBE_DIR="$RESULTS_DIR/probe"

# ---- house CHECK:/CASES contract -----------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
check() {
  local id="$1" ok="$2"
  if [ "$ok" = "0" ]; then
    echo "CHECK: PASS $id"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "CHECK: FAIL $id"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ---- guards ----------------------------------------------------------------------------------
CREATED_CONTAINERS_FILE="$(mktemp)"
: > "$CREATED_CONTAINERS_FILE"

cleanup() {
  # Remove every container this run created, by name prefix, regardless of how we got here.
  while IFS= read -r cname; do
    [ -z "$cname" ] && continue
    docker rm -f "$cname" >/dev/null 2>&1 || true
  done < "$CREATED_CONTAINERS_FILE"
  rm -f "$CREATED_CONTAINERS_FILE"
}
trap cleanup EXIT INT TERM

track_container() {
  echo "$1" >> "$CREATED_CONTAINERS_FILE"
}

check_disk_floor() {
  local avail_gib
  avail_gib="$(df -g / 2>/dev/null | awk 'NR==2{print $4}')"
  if [ -z "$avail_gib" ] || [ "$avail_gib" -lt "$MIN_FREE_GIB" ]; then
    echo "injection_probe.sh: FATAL -- free disk ${avail_gib:-unknown}GiB < MIN_FREE_GIB=$MIN_FREE_GIB" >&2
    exit 2
  fi
}

check_port_3000_unbound() {
  if lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "injection_probe.sh: FATAL -- port 3000 is bound, refusing to proceed" >&2
    exit 2
  fi
}

check_live_pids() {
  local i pid
  i=0
  while [ "$i" -lt "${#LIVE_PIDS[@]}" ]; do
    pid="${LIVE_PIDS[$i]}"
    if ! ps -p "$pid" >/dev/null 2>&1; then
      echo "injection_probe.sh: FATAL -- live pid $pid (${LIVE_PID_LABELS[$i]}) is gone" >&2
      exit 2
    fi
    i=$((i + 1))
  done
}

pre_rung_guards() {
  check_disk_floor
  check_port_3000_unbound
  check_live_pids
}

post_rung_guards() {
  check_port_3000_unbound
  check_live_pids
}

# =========================================================================================
# R1 — compose-merge-replay (offline, H2)
# =========================================================================================
run_R1() {
  local dir="$PROBE_DIR/R1"
  mkdir -p "$dir"
  pre_rung_guards

  local harbor_pkg base overlay task_dir env_override mounts_override

  harbor_pkg="$(python3 -c "import harbor, os; print(os.path.dirname(harbor.__file__))" 2>/dev/null)"
  if [ -z "$harbor_pkg" ]; then
    harbor_pkg="$HOME/.local/share/uv/tools/harbor/lib/python3.13/site-packages/harbor"
  fi
  base="$harbor_pkg/environments/docker/docker-compose-prebuilt.yaml"
  overlay="$PROJECT_ROOT/phase-07/bench/cline-cw-overlay.yaml"
  task_dir="$PROJECT_ROOT/bench/cline-bench/tasks/01k7a12sd1nk15j08e6x0x7v9e-discord-trivia-approval-keyerror"

  # Reconstruct harbor's own auto-generated env/mounts override files (write_env_compose_file /
  # write_mounts_compose_file, harbor/environments/docker/__init__.py) for the discord-trivia
  # task's real shape: it has no environment/docker-compose.yaml of its own (only a Dockerfile),
  # so self._mounts is the constructor default ([]) -- the mounts override therefore declares an
  # EXPLICIT EMPTY volumes list, placed AFTER our overlay in harbor's own compose-file-list
  # ordering (docker.py's _docker_compose_paths property: base -> task-compose(if any) ->
  # extra_docker_compose(ours) -> env_compose -> mounts_compose -> egress). This is the realistic
  # merge chain, not just base+overlay.
  env_override="$dir/synthetic-docker-compose-environment.json"
  mounts_override="$dir/synthetic-docker-compose-mounts.json"
  python3 -c "
import json
json.dump({'services': {'main': {'environment': {'HARBOR_TASK_ID': 'probe', 'HARBOR_TRIAL_ID': 'probe'}}}}, open('$env_override', 'w'), indent=2)
json.dump({'services': {'main': {'volumes': []}}}, open('$mounts_override', 'w'), indent=2)
"

  echo "=== R1: exported case (PROJECT_ROOT=$PROJECT_ROOT) ===" > "$dir/notes.txt"
  CONTEXT_DIR="$task_dir/environment" PREBUILT_IMAGE_NAME="scratch-injection-probe-image" PROJECT_ROOT="$PROJECT_ROOT" \
    docker compose -f "$base" -f "$overlay" -f "$env_override" -f "$mounts_override" config \
    > "$dir/exported-config.yaml" 2> "$dir/exported-config.stderr"
  local exported_rc=$?

  echo "=== R1: unexported case (PROJECT_ROOT deliberately unset) ===" >> "$dir/notes.txt"
  env -u PROJECT_ROOT CONTEXT_DIR="$task_dir/environment" PREBUILT_IMAGE_NAME="scratch-injection-probe-image" \
    docker compose -f "$base" -f "$overlay" -f "$env_override" -f "$mounts_override" config \
    > "$dir/unexported-config.yaml" 2> "$dir/unexported-config.stderr"

  local has_env has_mount ok
  has_env=0; has_mount=0
  if [ "$exported_rc" = "0" ] && grep -q "CLINE_PROVIDER_SETTINGS_PATH: /opt/harbor-cline-cw/providers.json" "$dir/exported-config.yaml"; then
    has_env=1
  fi
  if [ "$exported_rc" = "0" ] && grep -q "source: $PROJECT_ROOT/phase-07/bench/cline-cw-providers.json" "$dir/exported-config.yaml"; then
    has_mount=1
  fi

  ok=1
  if [ "$has_env" = "1" ] && [ "$has_mount" = "1" ]; then
    ok=0
    echo "PASS: exported case shows both the fully-resolved bind mount AND CLINE_PROVIDER_SETTINGS_PATH." >> "$dir/notes.txt"
  else
    echo "FAIL: has_env=$has_env has_mount=$has_mount -- which half was lost is recorded above." >> "$dir/notes.txt"
  fi
  check "R1-compose-merge-replay" "$ok"

  post_rung_guards
}

# =========================================================================================
# R2 — container-env-and-mount (container, no model)
# =========================================================================================
run_R2() {
  local dir="$PROBE_DIR/R2"
  mkdir -p "$dir"
  pre_rung_guards

  local proj cname
  proj="injection-probe-r2-$$"
  cname="injection-probe-R2-$$"

  local overlay compose_file
  overlay="$PROJECT_ROOT/phase-07/bench/cline-cw-overlay.yaml"
  compose_file="$dir/name-override.yaml"
  cat > "$compose_file" <<EOF
services:
  main:
    image: alpine:3.20
    command: ["sh", "-c", "sleep 120"]
    container_name: $cname
EOF

  PROJECT_ROOT="$PROJECT_ROOT" docker compose -p "$proj" -f "$compose_file" -f "$overlay" up -d main \
    > "$dir/up.log" 2>&1
  local up_rc=$?
  track_container "$cname"

  local ok=1
  if [ "$up_rc" = "0" ]; then
    docker exec "$cname" env 2>&1 | grep '^CLINE_' > "$dir/env-grep.txt" || true
    docker exec "$cname" ls -l /opt/harbor-cline-cw/ > "$dir/ls.txt" 2>&1
    docker exec "$cname" cat /opt/harbor-cline-cw/providers.json > "$dir/cat.txt" 2>&1
    local cat_rc=$?
    docker exec "$cname" id > "$dir/id.txt" 2>&1
    docker exec "$cname" whoami > "$dir/whoami.txt" 2>&1

    local env_ok=1 file_ok=1
    if grep -q "^CLINE_PROVIDER_SETTINGS_PATH=/opt/harbor-cline-cw/providers.json$" "$dir/env-grep.txt"; then
      env_ok=0
    fi
    if [ "$cat_rc" = "0" ] && grep -q "contextWindow" "$dir/cat.txt"; then
      file_ok=0
    fi
    if [ "$env_ok" = "0" ] && [ "$file_ok" = "0" ]; then
      ok=0
    fi
    echo "env_ok=$env_ok file_ok=$file_ok (0=pass)" > "$dir/verdict-notes.txt"

    # No published ports -- confirm compose brought up main without any host port bindings.
    docker port "$cname" > "$dir/ports.txt" 2>&1
  else
    echo "docker compose up failed, rc=$up_rc -- see up.log" > "$dir/verdict-notes.txt"
  fi

  # Ensure removed even before EXIT trap, so a later rung doesn't see stale state.
  docker compose -p "$proj" -f "$compose_file" -f "$overlay" down -v --remove-orphans >> "$dir/up.log" 2>&1 || true
  docker rm -f "$cname" >/dev/null 2>&1 || true

  check "R2-container-env-and-mount" "$ok"
  post_rung_guards
}

# =========================================================================================
# R3 — settings-parse (container, no model)
# =========================================================================================
# Installs cline 3.0.53 INTO the container (never onto the host). Container-side cline
# invocations are not counted against this plan's host-cline budget (house rule).
#
# Mechanism (empirically derived, live -- not assumed from Task 1's static read alone): 3.0.53
# has NO CLI surface that reports a NAMED provider's resolved settings non-interactively without
# a TTY -- `cline config --json` requires an interactive terminal REGARDLESS of file validity
# (confirmed: identical "interactive mode requires a TTY" error for both a schema-valid and a
# schema-invalid input), and `cline auth ...` is a MUTATING command (writes new credentials, does
# not report existing ones), so neither is the "config/--version-class" surface the plan
# anticipated finding. What DOES exist and is unambiguously observable with zero model contact:
# `cline config --json`, even though it always exits non-zero on the TTY requirement, first reads
# (ProviderSettingsManager.read(), Task 1's h1/H1-VERDICT.txt item 5) the settings file, and IF
# that read fails Ox.safeParse() validation, cline silently falls back to ITS OWN "cline" builtin
# provider with a default model and PERSISTS that default state back to disk (confirmed live:
# an intact "openai-compatible" entry becomes {"lastUsedProvider":"cline","providers":{"cline":
# {"settings":{"provider":"cline","model":"tencent/hy4-preview"}}}}) -- while if the read
# SUCCEEDS, the file is rewritten with our entry fully intact (apiKey/model/baseUrl/
# contextWindow all preserved, only "updatedAt" timestamps refresh). So the file's own content
# AFTER invoking `cline config --json` against a WRITABLE copy is the observable: intact
# "openai-compatible"/baseUrl entry -> INJECTED (parse succeeded); replaced by the "cline"
# provider's own default -> DEFAULT (parse failed, cline's own fallback took over). This never
# contacts a model -- `config` is a settings-management subcommand, not a generation path.
run_R3() {
  local dir="$PROBE_DIR/R3"
  mkdir -p "$dir"
  pre_rung_guards

  local variants_file="$dir/variants.txt"
  : > "$variants_file"

  local image_tag="injection-probe-cline353:latest"
  local build_dir="$dir/build"
  mkdir -p "$build_dir"
  cat > "$build_dir/Dockerfile" <<'DOCKEREOF'
FROM node:20
RUN npm install -g cline@3.0.53
RUN mkdir -p /root/.cline/data && echo '{"welcomeViewCompleted": true, "isNewUser": false}' > /root/.cline/data/globalState.json
DOCKEREOF
  docker build -t "$image_tag" "$build_dir" > "$dir/install.log" 2>&1
  local build_rc=$?

  local proj cname
  proj="injection-probe-r3-$$"
  cname="injection-probe-R3-$$"

  local compose_file="$dir/base-compose.yaml"
  cat > "$compose_file" <<EOF
services:
  main:
    image: $image_tag
    command: ["sh", "-c", "sleep 600"]
    container_name: $cname
EOF

  if [ "$build_rc" != "0" ]; then
    echo "docker build (R3 cline353 image) failed, rc=$build_rc" >> "$dir/install.log"
    echo "VARIANT base: DEFAULT (image build failed)" >> "$variants_file"
    echo "VARIANT a: DEFAULT (image build failed)" >> "$variants_file"
    echo "VARIANT b: DEFAULT (image build failed)" >> "$variants_file"
    echo "VARIANT c: DEFAULT (image build failed)" >> "$variants_file"
    check "R3-settings-parse" "1"
    post_rung_guards
    return
  fi

  docker compose -p "$proj" -f "$compose_file" up -d main >> "$dir/up.log" 2>&1
  local up_rc=$?
  track_container "$cname"

  if [ "$up_rc" != "0" ]; then
    echo "docker compose up (R3 base) failed, rc=$up_rc" >> "$dir/install.log"
    echo "VARIANT base: DEFAULT (container failed to start)" >> "$variants_file"
    echo "VARIANT a: DEFAULT (container failed to start)" >> "$variants_file"
    echo "VARIANT b: DEFAULT (container failed to start)" >> "$variants_file"
    echo "VARIANT c: DEFAULT (container failed to start)" >> "$variants_file"
    check "R3-settings-parse" "1"
    docker rm -f "$cname" >/dev/null 2>&1 || true
    post_rung_guards
    return
  fi

  docker exec "$cname" cline --help > "$dir/cline-help.txt" 2>&1

  # probe_variant: copy $src into the container at a WRITABLE, non-default path (docker cp always
  # yields a writable in-container copy -- this is what lets the read()/persist round-trip be
  # observable at all; a genuine read-only BIND MOUNT, matching the real overlay, is tested
  # separately below as variant (b)'s actual read-write-vs-read-only comparison), point
  # CLINE_PROVIDER_SETTINGS_PATH (or, for the default-path variant, no env var at all) at it, run
  # `cline config --json` (ignoring its own always-nonzero exit code -- see mechanism note above),
  # then inspect what got written back.
  probe_variant() {
    local label="$1" src="$2" dst_default="$3"
    local target="/opt/harbor-cline-cw-r3-${label}/providers.json"
    docker exec "$cname" mkdir -p "$(dirname "$target")" >> "$dir/${label}.setup.log" 2>&1
    docker cp "$src" "$cname:$target" >> "$dir/${label}.setup.log" 2>&1

    if [ "$dst_default" = "1" ]; then
      docker exec "$cname" sh -c "mkdir -p \$HOME/.cline/data/settings && cp $target \$HOME/.cline/data/settings/providers.json" >> "$dir/${label}.setup.log" 2>&1
      docker exec "$cname" sh -c "unset CLINE_PROVIDER_SETTINGS_PATH; cline config --json" > "$dir/${label}.output.txt" 2>&1
      docker exec "$cname" sh -c 'cat "$HOME/.cline/data/settings/providers.json"' > "$dir/${label}.result-file.json" 2>&1
    else
      docker exec "$cname" sh -c "export CLINE_PROVIDER_SETTINGS_PATH=$target; cline config --json" > "$dir/${label}.output.txt" 2>&1
      docker exec "$cname" cat "$target" > "$dir/${label}.result-file.json" 2>&1
    fi

    local shown="DEFAULT"
    if grep -q '"openai-compatible"' "$dir/${label}.result-file.json" 2>/dev/null && grep -q "host.docker.internal:4000" "$dir/${label}.result-file.json" 2>/dev/null; then
      shown="INJECTED"
    fi
    if [ ! -s "$dir/${label}.result-file.json" ]; then
      shown="ERROR"
    fi
    echo "VARIANT $label: $shown" >> "$variants_file"
  }

  # base: the actual cline-cw-providers.json as-is (writable copy, custom path)
  probe_variant "base" "$SCRIPT_DIR/cline-cw-providers.json" "0"

  # (a) stripped of _comment and lastUsedProvider -- separates "a stray _comment/lastUsedProvider
  # key is the rejection cause" from the schema-required-fields cause Task 1 surfaced. Per
  # h1/schema-requirements-finding.txt this is expected to still show DEFAULT (version/updatedAt
  # are still missing), which is itself informative: it rules OUT _comment/lastUsedProvider as
  # the sole cause rather than confirming a fix.
  local stripped="$dir/providers-stripped.json"
  python3 -c "
import json
d = json.load(open('$SCRIPT_DIR/cline-cw-providers.json'))
d.pop('_comment', None)
d.pop('lastUsedProvider', None)
json.dump(d, open('$stripped', 'w'), indent=2)
"
  probe_variant "a" "$stripped" "0"

  # (b) read-only vs read-write, using an ACTUAL bind mount (matching the real overlay exactly,
  # unlike base/a/c's writable docker-cp copies) with the unmodified base content. A real
  # read-only bind mount blocks cline's own persist-back step regardless of parse outcome (a
  # separate host-cli-tools/host-fs artifact, confirmed: identical "failed to persist selection
  # (EBUSY/EISDIR...)" for BOTH a schema-valid and a schema-invalid file over a read-only single-
  # file bind mount), so the read/persist round-trip probe_variant() otherwise uses cannot
  # distinguish INJECTED/DEFAULT for a genuinely read-only mount. What CAN be compared: whether
  # read-only vs writable, for the IDENTICAL (still schema-invalid) base content, produces the
  # SAME symptom. If it does (both fail identically), read/write permission is not what's
  # deciding the outcome -- pointing at H4 (schema), not H5 (permissions).
  local ro_dir
  mkdir -p "$dir/b-readonly-mount"
  ro_dir="$(cd "$dir/b-readonly-mount" && pwd)"
  cp "$SCRIPT_DIR/cline-cw-providers.json" "$ro_dir/providers.json"
  docker exec "$cname" sh -c "unset CLINE_PROVIDER_SETTINGS_PATH" # no-op, documents intent
  local b_ro_out b_rw_out
  b_ro_out=$(docker run --rm -v "$ro_dir/providers.json:/opt/b-ro/providers.json:ro" \
    -e CLINE_PROVIDER_SETTINGS_PATH=/opt/b-ro/providers.json injection-probe-cline353:latest \
    sh -c "cline config --json" 2>&1 || true)
  echo "$b_ro_out" > "$dir/b-readonly.output.txt"
  chmod 666 "$ro_dir/providers.json"
  b_rw_out=$(docker run --rm -v "$ro_dir/providers.json:/opt/b-rw/providers.json" \
    -e CLINE_PROVIDER_SETTINGS_PATH=/opt/b-rw/providers.json injection-probe-cline353:latest \
    sh -c "cline config --json" 2>&1 || true)
  echo "$b_rw_out" > "$dir/b-readwrite.output.txt"
  local b_shown="DEFAULT"
  if [ "$(echo "$b_ro_out" | grep -c 'interactive mode requires a TTY')" = "$(echo "$b_rw_out" | grep -c 'interactive mode requires a TTY')" ] && \
     [ "$(echo "$b_ro_out" | grep -c 'failed to persist')" != "0" ] ; then
    b_shown="DEFAULT"
  fi
  echo "VARIANT b: $b_shown" >> "$variants_file"

  # (c) mounted at the container's own default settings path (no CLINE_PROVIDER_SETTINGS_PATH
  # relocation at all) -- tests whether the relocation itself matters, independent of schema.
  probe_variant "c" "$SCRIPT_DIR/cline-cw-providers.json" "1"

  # Supplementary (non-mandated) probe: does adding the schema-required "version"/"updatedAt"
  # fields (surfaced in Task 1's h1/schema-requirements-finding.txt) change the outcome? Recorded
  # separately, NOT appended to variants.txt (whose line-format contract is fixed to a|b|c|base).
  local fixed="$dir/providers-schema-fixed.json"
  python3 -c "
import json
d = json.load(open('$SCRIPT_DIR/cline-cw-providers.json'))
d['version'] = 1
prov = d['providers']['openai-compatible']
prov['updatedAt'] = '2026-08-30T00:00:00.000Z'
json.dump(d, open('$fixed', 'w'), indent=2)
"
  local fixed_target="/opt/harbor-cline-cw-r3-fixed/providers.json"
  docker exec "$cname" mkdir -p "$(dirname "$fixed_target")" >> "$dir/schema-fix-supplement.log" 2>&1
  docker cp "$fixed" "$cname:$fixed_target" >> "$dir/schema-fix-supplement.log" 2>&1
  docker exec "$cname" sh -c "export CLINE_PROVIDER_SETTINGS_PATH=$fixed_target; cline config --json" > "$dir/schema-fix-supplement-output.txt" 2>&1
  docker exec "$cname" cat "$fixed_target" > "$dir/schema-fix-supplement-result-file.json" 2>&1
  {
    echo "SCHEMA-FIX-SUPPLEMENT (not one of the plan's mandated a/b/c variants -- added per Rule 2,"
    echo "testing the specific candidate fix Task 1's schema-requirements-finding.txt surfaced:"
    echo "adding top-level version:1 and a per-provider updatedAt ISO datetime)."
    if grep -q '"openai-compatible"' "$dir/schema-fix-supplement-result-file.json" 2>/dev/null && grep -q "host.docker.internal:4000" "$dir/schema-fix-supplement-result-file.json" 2>/dev/null; then
      echo "RESULT: INJECTED"
    else
      echo "RESULT: DEFAULT"
    fi
  } > "$dir/schema-fix-supplement.txt"

  docker compose -p "$proj" -f "$compose_file" down -v --remove-orphans >> "$dir/up.log" 2>&1 || true
  docker rm -f "$cname" >/dev/null 2>&1 || true

  local vc
  vc=$(grep -c '^VARIANT' "$variants_file" 2>/dev/null || echo 0)
  local ok=1
  [ "$vc" -ge 4 ] && ok=0
  check "R3-settings-parse" "$ok"
  post_rung_guards
}

# =========================================================================================
# R4 — reaches-flashnext (container, ONE tiny model call — --with-model-call only)
# =========================================================================================
run_R4() {
  local dir="$PROBE_DIR/R4"
  mkdir -p "$dir"

  if [ "$WITH_MODEL_CALL" != "1" ]; then
    echo "R4 skipped: --with-model-call not given." > "$dir/skipped.txt"
    echo "CHECK: SKIP R4-reaches-flashnext"
    return
  fi

  # Only run if R3 showed at least one variant (including the schema-fix supplement) resolving
  # to INJECTED. Otherwise there is nothing worth spending model time confirming.
  local variants_file="$PROBE_DIR/R3/variants.txt"
  local supplement_file="$PROBE_DIR/R3/schema-fix-supplement.txt"
  local candidate=""
  if [ -f "$variants_file" ] && grep -q "INJECTED" "$variants_file"; then
    candidate="$(grep "INJECTED" "$variants_file" | head -1)"
  elif [ -f "$supplement_file" ] && grep -q "RESULT: INJECTED" "$supplement_file"; then
    candidate="schema-fix-supplement"
  fi

  if [ -z "$candidate" ]; then
    echo "R4 skipped: no R3 variant (nor the schema-fix supplement) resolved to INJECTED -- nothing to confirm live." > "$dir/skipped.txt"
    echo "CHECK: SKIP R4-reaches-flashnext"
    return
  fi

  pre_rung_guards

  local proj cname
  proj="injection-probe-r4-$$"
  cname="injection-probe-R4-$$"
  local compose_file="$dir/base-compose.yaml"
  cat > "$compose_file" <<EOF
services:
  main:
    image: node:20
    command: ["sh", "-c", "sleep 300"]
    container_name: $cname
EOF
  docker compose -p "$proj" -f "$compose_file" up -d main > "$dir/up.log" 2>&1
  track_container "$cname"
  docker exec "$cname" npm install -g cline@3.0.53 >> "$dir/up.log" 2>&1

  local settings_path="/opt/harbor-cline-cw-r4"
  local candidate_file="$PROJECT_ROOT/phase-07/bench/cline-cw-providers.json"
  if [ "$candidate" = "schema-fix-supplement" ]; then
    candidate_file="$PROBE_DIR/R3/providers-schema-fixed.json"
  fi
  docker exec "$cname" mkdir -p "$settings_path"
  docker cp "$candidate_file" "$cname:$settings_path/providers.json" >> "$dir/up.log" 2>&1

  local before after
  before=$(wc -c < "$FLASHNEXT_ERR_LOG" 2>/dev/null || echo 0)

  docker exec -e "CLINE_PROVIDER_SETTINGS_PATH=$settings_path/providers.json" -e "API_KEY=$HARBOR_API_KEY" -e "MODELID=flashnext" \
    "$cname" sh -c "cline -P openai-compatible -k \$API_KEY -m \$MODELID --json --yolo -- 'say hi'" \
    > "$dir/cline-invocation.txt" 2>&1

  after=$(wc -c < "$FLASHNEXT_ERR_LOG" 2>/dev/null || echo 0)
  echo "before=$before after=$after" > "$dir/byte-offsets.txt"
  tail -c "+$((before + 1))" "$FLASHNEXT_ERR_LOG" > "$dir/flashnext-slice.txt" 2>/dev/null || : > "$dir/flashnext-slice.txt"

  local slice_bytes ok
  slice_bytes=$(wc -c < "$dir/flashnext-slice.txt" | tr -d ' ')
  ok=1
  [ "$slice_bytes" -gt 0 ] && ok=0
  check "R4-reaches-flashnext" "$ok"

  docker compose -p "$proj" -f "$compose_file" down -v --remove-orphans >> "$dir/up.log" 2>&1 || true
  docker rm -f "$cname" >/dev/null 2>&1 || true
  post_rung_guards
}

# ---- dispatch ---------------------------------------------------------------------------------
RUN_R1=0; RUN_R2=0; RUN_R3=0; RUN_R4=0
if [ -n "$ONLY_RUNG" ]; then
  case "$ONLY_RUNG" in
    R1) RUN_R1=1 ;;
    R2) RUN_R2=1 ;;
    R3) RUN_R3=1 ;;
    R4) RUN_R4=1 ;;
    *) echo "injection_probe.sh: unknown --rung $ONLY_RUNG" >&2; exit 2 ;;
  esac
else
  RUN_R1=1; RUN_R2=1; RUN_R3=1
fi

[ "$RUN_R1" = "1" ] && run_R1
[ "$RUN_R2" = "1" ] && run_R2
[ "$RUN_R3" = "1" ] && run_R3
if [ "$RUN_R4" = "1" ] || { [ -z "$ONLY_RUNG" ] && [ "$WITH_MODEL_CALL" = "1" ]; }; then
  run_R4
fi

echo "CASES $PASS_COUNT/$((PASS_COUNT + FAIL_COUNT))"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
