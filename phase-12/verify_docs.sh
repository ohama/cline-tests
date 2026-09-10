#!/usr/bin/env bash
# phase-12/verify_docs.sh — USE-04/USE-05 / ROADMAP Phase 12's mechanical documentation sweep.
#
# WHY THIS FILE EXISTS AT ALL (read before editing).
# Phase 12's signature failure mode is declaring a document "updated" while the false sentence
# it was supposed to replace is still in it — this project has already done this once in
# miniature (qanda/004 §5 kept calling the containment "a proposal" for hours after it shipped,
# while three other documents cited it as evidence). This script is the defence: it names, per
# file, the exact strings that must be gone and the exact anchors that must be present, and it
# was written BEFORE any of the eleven target documents were edited by wave 2 — so the assertion
# table below cannot be quietly retro-fitted to whatever wave 2 happened to write. See
# phase-12/selftest_verify_docs.sh for the seeded-mutant proof that every assertion class below
# can actually fail, and phase-12/results/CURRENT_RED_RUN for this script's own RED baseline
# against the still-uncorrected repository.
#
# LIVE BODY vs PRESERVED APPENDIX — the central mechanic, and why forbidden-string checks are
# safe here despite phase-08/manual/check_manual_claims.sh's header explicitly refusing to do
# them. That header's hazard is real: a naive forbidden-literal grep collides with prose that
# legitimately names the thing it forbids (this project's own docs/cline-bench.md §9 has to spell
# out its own forbidden sentences in order to forbid them). This sweep does forbidden-string
# checks anyway, because presence-only checking (that gate's own answer) cannot catch this
# phase's actual failure mode — a false sentence left in place beside a correct new one. Three
# mitigations make it safe:
#   1. The corrections in scope all follow docs/32k-compaction-policy.md's own precedent: the
#      pre-correction original is preserved VERBATIM in a collapsed appendix under the marker
#      "부록 — 정정 전 기록", never deleted. FORBIDDEN checks below run only against the LIVE
#      BODY (everything above the first such marker line) — the preserved original, sitting
#      below the marker, is out of the searched region entirely.
#   2. Correction tables paraphrase, they do not quote — docs/32k-compaction-policy.md §7's own
#      "이 정정이 바꾸는 것" table is the model (이전 column: short paraphrases like
#      "models[].contextWindow: 32768", never the verbatim superseded sentence). Every FORBIDDEN
#      literal below is a long, distinctive full sentence that no such paraphrase reproduces.
#   3. An auditable escape hatch: a line carrying the trailing marker "<!-- verify_docs:allow -->"
#      is excluded from FORBIDDEN matching, for the genuine case where a document must name a
#      false sentence in order to disown it. Every use of the escape, anywhere in any in-scope
#      document's live body, is printed with file:line in this script's own summary — a silent
#      exemption would recreate the exact defect this sweep exists to catch, so nothing is silent.
#      Zero uses is the expected state.
#
# APPENDIX_INTEGRITY is the inverse of the forbidden check, and just as load-bearing: for a file
# marked appendix_required below, every FORBIDDEN literal registered for that file must still be
# found in the APPENDIX. A correction that deleted the original instead of preserving it (clean
# live body, no preserved original) fails here, not silently passes. "Nothing deleted, only
# superseded" is mechanically enforced, not a hope.
#
# ABSENCE IS A FAILURE, NOT A SKIP.
# If a target document is missing from DOCS_ROOT, that is a FAIL[DOCS], reported before any of
# its own assertions run. A "file not present, skipping" branch returning 0 would be exactly the
# instrument-that-observes-nothing pattern phase-10/PHASE-10-FINDINGS.md §4.6 catalogues.
#
# AB_DISCLOSURE's residual gap, stated honestly: the trigger for "does this file discuss the A/B"
# is a literal-string match ('A/B' or 'AB-RESULTS'). A document could in principle discuss the
# A/B in pure Korean paraphrase without either literal and dodge this check entirely — the check
# cannot detect that. This is a known, accepted gap: 12-08's human-read audit covers it. This
# script does not attempt to close it mechanically.
#
# USAGE / ENV:
#   DOCS_ROOT=<dir>   root to check documents against (default: this script's own repo root,
#                     i.e. the real repository). Point this at a fixture tree to check seeded
#                     mutants instead — the one variable phase-12/selftest_verify_docs.sh changes.
#
# EXIT CODES: 0 = every assertion passed. 5 = at least one assertion failed. This is a code
# distinct from phase-01/config/verify_config.sh's providers.json exit 1 and
# phase-11/verify_wrappers.sh's exit 3, so a caller can always tell the three faults apart by
# exit code alone.
#
# Deliberately NOT `set -e` (phase-10/PHASE-10-FINDINGS.md §4.6 catalogues an outage sampler
# killed by `set -e` on the exact condition it existed to record; phase-11/verify_wrappers.sh and
# phase-11/wrapper_argv_test.sh make the same choice for the same reason). An aborting checker
# under-reports.
#
# bash 3.2 (macOS default) — no associative-array declarations. Every table below is carried as
# parallel indexed
# arrays populated by add_* helper calls. "${arr[@]}" / "${arr[*]}" on an array that might have
# zero elements is guarded by a `${#arr[@]} -gt 0` check first, the same bash-3.2-under-set-u
# pitfall phase-08/manual/check_manual_claims.sh's own header documents.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_ROOT="${DOCS_ROOT:-$REPO_ROOT}"

MARKER='부록 — 정정 전 기록'
ESCAPE_MARKER='<!-- verify_docs:allow -->'

FAIL_COUNT=0
TOTAL_CASES=0
PASSED_CASES=0
ESCAPE_LOG=()

fail() {
  echo "FAIL[DOCS]: $1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TOTAL_CASES=$((TOTAL_CASES + 1))
}

ok() {
  echo "OK[DOCS]: $1"
  TOTAL_CASES=$((TOTAL_CASES + 1))
  PASSED_CASES=$((PASSED_CASES + 1))
}

CACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/verify_docs.XXXXXX")"
trap 'rm -rf "$CACHE_DIR"' EXIT

# ---------------------------------------------------------------------------
# Assertion tables — bash 3.2 parallel indexed arrays, populated below via add_*.
# ---------------------------------------------------------------------------
FILE_LIST=()
FILE_APPENDIX=()
FORBIDDEN_FILE=()
FORBIDDEN_STR=()
REQUIRED_FILE=()
REQUIRED_STR=()
REQANY_FILE=()
REQANY_LABEL=()
REQANY_ALTS=()

add_file()         { FILE_LIST+=("$1"); FILE_APPENDIX+=("$2"); }
add_forbidden()    { FORBIDDEN_FILE+=("$1"); FORBIDDEN_STR+=("$2"); }
add_required()     { REQUIRED_FILE+=("$1"); REQUIRED_STR+=("$2"); }
add_required_any() { REQANY_FILE+=("$1"); REQANY_LABEL+=("$2"); REQANY_ALTS+=("$3"); }

# ===========================================================================
# docs/plan-act-reasoning-implementation.md (appendix_required=1)
# ===========================================================================
F=docs/plan-act-reasoning-implementation.md
add_file "$F" 1
# Status badge said "planned, not started" — the milestone shipped (aliases Phase 10, wrappers
# Phase 11, A/B ran, decision made keep-by-override). Leaving this on disk is the exact class of
# false-but-undetected sentence this phase exists to prevent (scope decision / research §A1).
add_forbidden "$F" '상태: 계획. 미착수.'
# The primary correction target: Phase 9's PRB-04-FINDINGS.md §3 found Cline DOES re-attach
# reasoning history architecturally (shouldIncludeReasoningHistory); these three sentences assert
# the opposite (research §A2).
add_forbidden "$F" '누적의 증거가 아니다'
add_forbidden "$F" '`reasoning` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다'
add_forbidden "$F" '소스는 "누적되지 않는다" 쪽을 가리키나 결정적이지 않다'
# The naive shell-function sketch phase-11/WRAPPER-DESIGN.md §2 names by name and proves unsafe
# ("$@" forwards --thinking/-m straight through) — superseded by the real deny-by-default script
# (research §A5).
add_forbidden "$F" 'cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }'
# The real reattachment path (source-verified, Phase 9), must be cited by name in its place.
add_required "$F" 'shouldIncludeReasoningHistory'
# The shipped wrapper contract this design doc must reconcile against, not compete with.
add_required "$F" 'phase-11/WRAPPER-DESIGN.md'
# docs/32k-compaction-policy.md's own §7 convention — the single place a reader checks "what
# actually changed".
add_required "$F" '이 정정이 바꾸는 것'
# The preserved-original appendix marker itself must be present (appendix_required=1).
add_required "$F" '부록 — 정정 전 기록'
# An explicit "still open" section, following the same precedent's §8 — not implying full closure.
add_required_any "$F" unresolved-section '미해결|여전히 미해결'

# ===========================================================================
# docs/plan-act-reasoning-design.md (appendix_required=1)
# ===========================================================================
F=docs/plan-act-reasoning-design.md
add_file "$F" 1
# Same stale status badge shape as implementation.md's A1 (research §C1) — "proposal, not yet
# implemented" when v1.1 shipped and both gates were adjudicated.
add_forbidden "$F" '상태: 제안. 아직 구현되지 않았다.'
# Same superseded shell-function sketch as implementation.md's T5/A5, named in the same breath by
# phase-11/WRAPPER-DESIGN.md §2 (research §C4).
add_forbidden "$F" 'cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }'
# Gate ① adjudication citation (context-accumulation kill condition).
add_required "$F" 'phase-09/GATE-VERDICT.md'
# The shipped wrapper contract this design doc must reconcile against.
add_required "$F" 'phase-11/WRAPPER-DESIGN.md'
# flashnext-reach-xhigh's disposition and the --thinking/500-vs-400 correction both live here.
add_required "$F" 'phase-11/OPEN-ITEMS.md'
# Scope decision 4 / research §C3: hosted_vllm/-prefixed aliases surface a 500, not litellm's 400.
add_required "$F" 'hosted_vllm/'
add_required "$F" '이 정정이 바꾸는 것'
add_required "$F" '부록 — 정정 전 기록'

# ===========================================================================
# docs/plan-act-reasoning-diagrams.md (appendix_required=1)
# ===========================================================================
F=docs/plan-act-reasoning-diagrams.md
add_file "$F" 1
# Same stale status badge shape, comma variant as actually written in this file (research §B1).
add_forbidden "$F" '상태: 계획, 미착수.'
# The diagram audience's restatement of the same false-negative reasoning-accumulation claim
# (research §B2) — Phase 9 names this file/range explicitly as a correction target.
add_forbidden "$F" '소스 조사는 "누적되지 않는다" 쪽을 가리킨다'
add_required "$F" 'shouldIncludeReasoningHistory'
add_required "$F" '부록 — 정정 전 기록'
# The token-cost claim (unlike the architecture claim) was right: 0 measured cost is why the gate
# passed despite the architecture misread — must survive the correction, phrased any of these ways.
add_required_any "$F" zero-cost 'delta=0|0 토큰|토큰 비용은 0'

# ===========================================================================
# docs/manual/01-cli.md (no appendix — a manual's job is to be currently true)
# ===========================================================================
F=docs/manual/01-cli.md
add_file "$F" 0
# USE-04 criterion 1: a new subsection documenting the wrappers, distinct from --mode.
add_required "$F" '## 6a'
add_required "$F" 'phase-11/cline-plan'
add_required "$F" 'phase-11/cline-act'
# The anti-conflation anchor: GAP-PLANMODE is about phase-04/run_headless.sh, a different tool,
# not about the phase-11 wrappers (scope decision 4 / research §E1) — must not be silently merged.
add_required "$F" 'phase-04/run_headless.sh'
# §6's existing hedge must survive, not be overwritten by the new §6a.
add_required "$F" 'GAP-PLANMODE'
add_required "$F" 'CLINE_PROVIDER_SETTINGS_PATH'
add_required "$F" 'phase-11/WRAPPER-DESIGN.md'
# The superseded flag is named, not silently deleted — a Phase 8 strings-scan artifact.
add_required "$F" '--mode'
# ...and so is the evidence generation it came from (scope decision 4: static scan vs live probe).
add_required "$F" 'cli-v3.0.53'
add_required "$F" '3.0.61'
add_required_any "$F" exit-codes '종료 코드|exit 2|exit 3|exit 4'

# ===========================================================================
# docs/cline-config-pins.md (no appendix — new content, not a correction of existing text)
# ===========================================================================
F=docs/cline-config-pins.md
add_file "$F" 0
add_required "$F" 'flashnext-plan'
add_required "$F" 'flashnext-act'
# Verification-only, v1.2 removal candidate (scope decision 3) — must be named, not silently
# dropped a third time.
add_required "$F" 'flashnext-reach-xhigh'
# Forbidden to call — kills the model server; must be named as such, not merely absent.
add_required "$F" 'flashnext-codex'
add_required "$F" 'enable_thinking'
add_required "$F" 'reasoning_effort'
add_required "$F" 'hosted_vllm/'
# The six removed aliases, named as historical (research §D1).
add_required "$F" 'qwen-'
# Per-prefix status codes (scope decision 8): openai/-prefixed -> 400, hosted_vllm/-prefixed -> 500.
add_required "$F" '400'
add_required "$F" '500'
add_required "$F" 'phase-10/REACH-PROOF.md'
add_required "$F" 'phase-11/WRAPPER-DESIGN.md'
# The measured dynamic max_tokens value (scope decision 1), not the falsified fixed 2048.
add_required "$F" '20983'
# Absolutes presented as drifted measurements, per research §D3 / overclaim-guard §8.
add_required "$F" '13/11/41/53'
add_required_any "$F" delta-framing '델타|delta'
# providers.json is repeatedly corrected, never "stays" correct (scope decision 7).
add_required_any "$F" per-call-write '호출마다|매 호출|호출할 때마다'

# ===========================================================================
# docs/32k-compaction-policy.md (no appendix_required tag — it already has one from an earlier
# correction round; this phase only adds a further correction, it does not re-derive the shape)
# ===========================================================================
F=docs/32k-compaction-policy.md
add_file "$F" 0
# The §4 live claim: max_tokens is NOT fixed at 2048 (scope decision 1) — falsified by
# phase-11/OPEN-ITEMS.md Open Item 2 (20983) and AB-PROTOCOL.md §3 (dynamic sizing).
add_forbidden "$F" '`max_tokens` 실측값은 `2048`.'
# The §8 live claim, same falsification, restated in the "미해결" section.
add_forbidden "$F" '여전히 미적용(실측 2048 고정)'
# Inverse guard: the historical log evidence at §7/§9 must survive — over-deletion is as much a
# defect as leaving the false claim (over-correction is not correction).
add_required "$F" '2048'
add_required "$F" '20983'
add_required "$F" '278'
add_required "$F" 'phase-11/AB-PROTOCOL.md'
# The earlier 2026-08-30 banner must not be clobbered by the new correction banner.
add_required "$F" '2026-08-30 전면 정정'
add_required_any "$F" new-banner '2026-09-10 정정|2026-09-10 추가 정정'
add_required_any "$F" budget-shape '26,100|26100|contextWindow × 0.9'

# ===========================================================================
# docs/cline-max-tokens-findings.md (appendix_required=1)
# ===========================================================================
F=docs/cline-max-tokens-findings.md
add_file "$F" 1
# CFG-03's own asserted OBSERVED_MAX, same falsification as 32k-compaction-policy.md's F1/F2.
add_forbidden "$F" '**`OBSERVED_MAX = 2048`.**'
add_required "$F" '2048'
add_required "$F" '20983'
add_required "$F" 'phase-11/OPEN-ITEMS.md'
add_required "$F" '부록 — 정정 전 기록'
add_required "$F" '이 정정이 바꾸는 것'
add_required_any "$F" dynamism '동적|per-request|요청마다'

# ===========================================================================
# howto/fast-and-deep-mode.md (no appendix — a howto's job is to be currently true)
# ===========================================================================
F=howto/fast-and-deep-mode.md
add_file "$F" 0
# Written mid-Phase-10/11, describes the alias mechanism and the wrapper as still in progress —
# both shipped since (research §5/open item 3).
add_forbidden "$F" '## 방법 2 — litellm 별칭 (재기동 필요) ⭐ 진행 중'
add_forbidden "$F" '## 방법 3 — 셸 래퍼 (Phase 11 예정)'
add_forbidden "$F" 'Phase 10 이 하고 있다'
add_forbidden "$F" 'Phase 10 이 추가 중'
add_required "$F" '2026-09-10'
add_required "$F" 'phase-11/cline-plan'

# ===========================================================================
# howto/thinking-and-reasoning-effort.md (no appendix)
# ===========================================================================
F=howto/thinking-and-reasoning-effort.md
add_file "$F" 0
# Predates Phase 10/11 shipping the alias-driven link between Plan/Act and reasoning effort —
# now false (research §5/open item 3): they are linked, that is what shipped.
add_forbidden "$F" '바뀔 예정이다'
add_forbidden "$F" '**현재는 아니다.** 소스상 연결이 없다'
add_forbidden "$F" '그 둘을 잇는 것이 v1.1 의 목표다'
add_required "$F" '2026-09-10'
add_required "$F" 'flashnext-plan'

# ===========================================================================
# qanda/001-testing-plan-act-with-cline-cli.md (no appendix — self-correct in place, qanda/004's
# own convention)
# ===========================================================================
F=qanda/001-testing-plan-act-with-cline-cli.md
add_file "$F" 0
# Written before commit 017c65e (the containment fix) and before AB-RESULTS.md §11's ratified
# keep-by-override decision — both now superseded the same day (research open item 3).
add_forbidden "$F" '래퍼의 기본 별칭은 아직 확정 전입니다'
add_forbidden "$F" '사용자 비준을 기다리는 중입니다'
add_required "$F" '2026-09-10'
add_required "$F" 'phase-11/AB-RESULTS.md'

# ===========================================================================
# qanda/003-how-the-wrappers-work.md (no appendix — self-correct in place)
# ===========================================================================
F=qanda/003-how-the-wrappers-work.md
add_file "$F" 0
# Same staleness class as qanda/001 — written before the containment fix landed.
add_forbidden "$F" '**오염을 막지 못합니다. 사후 탐지만 합니다.**'
add_required "$F" 'CLINE_PROVIDER_SETTINGS_PATH'
add_required "$F" '017c65e'
add_required "$F" '2026-09-10'
add_required "$F" 'phase-11/AB-RESULTS.md'

# ---------------------------------------------------------------------------
# live_body / appendix split.
#
# live_body <file> = everything ABOVE the first line matching the literal marker $MARKER.
#   If no such line exists, the live body is the WHOLE file (correct for the manual/howto/qanda
#   documents in the table above, which have no appendix at all).
# appendix <file>  = everything from that marker line onward (empty if the marker is absent).
#
# Degenerate case — more than one marker line in a file: only the FIRST occurrence defines the
# split. Any subsequent marker line is simply appendix content (part of the preserved historical
# record), which is exactly what should happen: the split point is "where the live, currently-true
# document ends", not "every place the word appendix appears".
# ---------------------------------------------------------------------------
compute_live_and_appendix() {
  local file="$1" full="$2" safe live app
  safe="$(printf '%s' "$file" | tr '/.' '__')"
  live="$CACHE_DIR/${safe}.live"
  app="$CACHE_DIR/${safe}.appendix"
  awk -v marker="$MARKER" '
    index($0, marker) { exit }
    { print }
  ' "$full" > "$live"
  awk -v marker="$MARKER" '
    index($0, marker) { found = 1 }
    found { print }
  ' "$full" > "$app"
  LIVE_FILE="$live"
  APPENDIX_FILE="$app"
}

# Every use of the escape hatch, anywhere in a live body, regardless of whether it happens to sit
# on a line a FORBIDDEN check is currently searching for — auditability must not depend on which
# assertions happen to be registered.
escape_audit() {
  local file="$1" live="$2" ln
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    ESCAPE_LOG+=("$file:$ln")
  done < <(grep -nF -- "$ESCAPE_MARKER" "$live" 2>/dev/null | cut -d: -f1)
}

# Class 1: FORBIDDEN — must NOT appear in the live body, escape-marked lines excluded. Exact
# substring matching (grep -qF), never a fuzzy regex — a regex over Korean prose produces false
# positives on correct sentences and would train the reader to ignore this checker.
check_forbidden() {
  local file="$1" live="$2" substr="$3" hits unescaped firstline
  hits="$(grep -nF -- "$substr" "$live" 2>/dev/null || true)"
  if [ -z "$hits" ]; then
    ok "FORBIDDEN $file: forbidden literal absent from live body: '$substr'"
    return
  fi
  unescaped="$(printf '%s\n' "$hits" | grep -v -F -- "$ESCAPE_MARKER" || true)"
  if [ -n "$unescaped" ]; then
    firstline="$(printf '%s\n' "$unescaped" | head -1)"
    fail "FORBIDDEN $file: forbidden literal still present in live body (uncorrected): '$substr' — $firstline"
  else
    ok "FORBIDDEN $file: '$substr' present only on verify_docs:allow-escaped line(s) — exempted, see escape summary"
  fi
}

# Class 2: REQUIRED — must appear anywhere in the file (live body OR appendix; a preserved
# original citing the same evidence artifact should not make this fail).
check_required() {
  local file="$1" full="$2" substr="$3"
  if grep -qF -- "$substr" "$full" 2>/dev/null; then
    ok "REQUIRED $file: required anchor present: '$substr'"
  else
    fail "REQUIRED $file: required anchor missing: '$substr'"
  fi
}

# Class 3: REQUIRED_ANY — at least one alternative (pipe-separated) must appear anywhere in the
# file. Used wherever the true claim can be phrased more than one way.
check_required_any() {
  local file="$1" full="$2" label="$3" alts="$4" alt found=0 hit=""
  local old_ifs="$IFS"
  IFS='|'
  for alt in $alts; do
    if grep -qF -- "$alt" "$full" 2>/dev/null; then
      found=1
      hit="$alt"
      break
    fi
  done
  IFS="$old_ifs"
  if [ "$found" = "1" ]; then
    ok "REQUIRED_ANY $file [$label]: satisfied by '$hit'"
  else
    fail "REQUIRED_ANY $file [$label]: none of the alternatives present ($alts)"
  fi
}

# Class 4: CITED_PATHS_EXIST — every backtick-delimited token in the live body starting with
# docs/, howto/, qanda/, phase- or .planning/ must resolve as a real path AGAINST THE REPO ROOT
# (not DOCS_ROOT — a fixture tree under test still cites real repository evidence artifacts).
# Skips tokens containing '~', a leading '/', or a space, per the plan's own carve-out.
check_cited_paths() {
  local file="$1" live="$2" tok stripped any_miss=0 miss_list=""
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case "$tok" in
      *'~'*|/*|*' '*) continue ;;
    esac
    case "$tok" in
      docs/*|howto/*|qanda/*|phase-*|.planning/*) ;;
      *) continue ;;
    esac
    stripped="$(printf '%s' "$tok" | sed -E 's/[:#][A-Za-z0-9_.-]*$//; s/[.,;:!?)]+$//')"
    if [ ! -e "$REPO_ROOT/$stripped" ]; then
      any_miss=1
      miss_list="${miss_list}|${stripped}"
    fi
  done < <(grep -o '`[^`]*`' "$live" 2>/dev/null | sed 's/^`//; s/`$//')
  if [ "$any_miss" = "0" ]; then
    ok "CITED_PATHS_EXIST $file: all backtick-cited docs/howto/qanda/phase-/.planning paths resolve against $REPO_ROOT"
  else
    fail "CITED_PATHS_EXIST $file: cited path(s) do not exist under $REPO_ROOT: ${miss_list#|}"
  fi
}

# Class 5: TAG_CITATION — if the live body cites cli-v3.0.53, it must also carry the literal
# 'git show cli-v3.0.53:' form (scope decision 6: the cline-src working tree moved to 3.0.61, so a
# bare grep of the live tree for a 3.0.53-era citation would find nothing).
check_tag_citation() {
  local file="$1" live="$2"
  if grep -qF -- 'cli-v3.0.53' "$live" 2>/dev/null; then
    if grep -qF -- 'git show cli-v3.0.53:' "$live" 2>/dev/null; then
      ok "TAG_CITATION $file: cli-v3.0.53 citation carries the required 'git show cli-v3.0.53:' form"
    else
      fail "TAG_CITATION $file: cites cli-v3.0.53 without the required 'git show cli-v3.0.53:' form"
    fi
  else
    ok "TAG_CITATION $file: does not cite cli-v3.0.53 (check not triggered)"
  fi
}

# Class 6: AB_DISCLOSURE — conditional and deliberately outcome-neutral. Triggered only if the
# live body mentions the A/B at all ('A/B' or 'AB-RESULTS'); if triggered, all four elements below
# must be present so no reader can conclude the A/B favoured flashnext-plan. A document that does
# not discuss the A/B is not forced to.
#
# KNOWN GAP, stated here rather than pretended away: this trigger is a literal-string match. A
# document could discuss the A/B in pure Korean paraphrase, using neither 'A/B' nor 'AB-RESULTS',
# and this check would never fire for it. That residual gap is covered by 12-08's human-read
# audit, not by this script — see header.
check_ab_disclosure() {
  local file="$1" live="$2" missing=""
  if grep -qF -- 'A/B' "$live" 2>/dev/null || grep -qF -- 'AB-RESULTS' "$live" 2>/dev/null; then
    grep -qF -- 'p=0.563' "$live" 2>/dev/null || missing="${missing}|p=0.563"
    grep -qF -- '25/30' "$live" 2>/dev/null || missing="${missing}|25/30"
    if ! { grep -qF -- 'override' "$live" 2>/dev/null || grep -qF -- '오버라이드' "$live" 2>/dev/null || grep -qF -- '뒤집' "$live" 2>/dev/null; }; then
      missing="${missing}|override-or-오버라이드-or-뒤집"
    fi
    grep -qF -- 'phase-11/AB-RESULTS.md' "$live" 2>/dev/null || missing="${missing}|phase-11/AB-RESULTS.md"
    if [ -z "$missing" ]; then
      ok "AB_DISCLOSURE $file: mentions the A/B and carries all required disclosure elements (25/30, p=0.563, override, AB-RESULTS.md)"
    else
      fail "AB_DISCLOSURE $file: mentions the A/B but is missing: ${missing#|}"
    fi
  else
    ok "AB_DISCLOSURE $file: does not mention the A/B (check not triggered)"
  fi
}

# APPENDIX_INTEGRITY — for a file registered appendix_required=1: every FORBIDDEN literal
# registered for that file must still be found VERBATIM in the appendix. A correction that
# deleted the original instead of preserving it (clean live body, no preserved original) fails
# here, not silently passes.
check_appendix_integrity() {
  local file="$1" appendix="$2" i n s missing=0 missing_list=""
  n=${#FORBIDDEN_FILE[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${FORBIDDEN_FILE[$i]}" = "$file" ]; then
      s="${FORBIDDEN_STR[$i]}"
      if ! grep -qF -- "$s" "$appendix" 2>/dev/null; then
        missing=1
        missing_list="${missing_list}|${s}"
      fi
    fi
    i=$((i + 1))
  done
  if [ "$missing" = "0" ]; then
    ok "APPENDIX_INTEGRITY $file: every forbidden-literal original is preserved verbatim in the appendix"
  else
    fail "APPENDIX_INTEGRITY $file: appendix is missing preserved original text for: ${missing_list#|} — this is a deletion, not a correction"
  fi
}

# ---------------------------------------------------------------------------
# Main sweep.
# ---------------------------------------------------------------------------
idx=0
n_files=${#FILE_LIST[@]}
while [ "$idx" -lt "$n_files" ]; do
  file="${FILE_LIST[$idx]}"
  appendix_required="${FILE_APPENDIX[$idx]}"
  full="$DOCS_ROOT/$file"

  if [ ! -e "$full" ]; then
    fail "document missing entirely from DOCS_ROOT=$DOCS_ROOT: $file — absence is a failure, not a skip"
    idx=$((idx + 1))
    continue
  fi
  ok "document present: $file"

  compute_live_and_appendix "$file" "$full"
  live="$LIVE_FILE"
  appendix="$APPENDIX_FILE"

  escape_audit "$file" "$live"

  fi_=0
  n_forbidden=${#FORBIDDEN_FILE[@]}
  while [ "$fi_" -lt "$n_forbidden" ]; do
    if [ "${FORBIDDEN_FILE[$fi_]}" = "$file" ]; then
      check_forbidden "$file" "$live" "${FORBIDDEN_STR[$fi_]}"
    fi
    fi_=$((fi_ + 1))
  done

  ri_=0
  n_required=${#REQUIRED_FILE[@]}
  while [ "$ri_" -lt "$n_required" ]; do
    if [ "${REQUIRED_FILE[$ri_]}" = "$file" ]; then
      check_required "$file" "$full" "${REQUIRED_STR[$ri_]}"
    fi
    ri_=$((ri_ + 1))
  done

  ai_=0
  n_reqany=${#REQANY_FILE[@]}
  while [ "$ai_" -lt "$n_reqany" ]; do
    if [ "${REQANY_FILE[$ai_]}" = "$file" ]; then
      check_required_any "$file" "$full" "${REQANY_LABEL[$ai_]}" "${REQANY_ALTS[$ai_]}"
    fi
    ai_=$((ai_ + 1))
  done

  if [ "$appendix_required" = "1" ]; then
    check_appendix_integrity "$file" "$appendix"
  fi

  check_cited_paths "$file" "$live"
  check_tag_citation "$file" "$live"
  check_ab_disclosure "$file" "$live"

  idx=$((idx + 1))
done

# ---------------------------------------------------------------------------
# Escape hatch summary — printed unconditionally, before the final tally, so a reviewer of the
# captured transcript sees every use regardless of overall verdict. Zero uses is expected.
# ---------------------------------------------------------------------------
echo
echo "=== escape hatch summary: ${#ESCAPE_LOG[@]} use(s) of verify_docs:allow ==="
if [ "${#ESCAPE_LOG[@]}" -gt 0 ]; then
  for e in "${ESCAPE_LOG[@]}"; do
    echo "ESCAPE[DOCS]: $e"
  done
fi

# ---------------------------------------------------------------------------
# Final tally and verdict — the house idiom (phase-08/manual/check_manual_claims.sh's own
# "CASES $passed/$total" line), so a reader of a captured transcript can tell "0 failures out of
# 90" apart from "0 failures out of 0" (phase-10/PHASE-10-FINDINGS.md §4.6's distinction).
# ---------------------------------------------------------------------------
echo
echo "CASES $PASSED_CASES/$TOTAL_CASES"

if [ "$FAIL_COUNT" -ne 0 ]; then
  EXIT_CODE=5
  echo "FAIL[DOCS]: $FAIL_COUNT assertion(s) failed against DOCS_ROOT=$DOCS_ROOT — see FAIL[DOCS] lines above" >&2
else
  EXIT_CODE=0
  echo "OK[DOCS]: all documentation assertions passed for DOCS_ROOT=$DOCS_ROOT"
fi
echo "exit code: $EXIT_CODE"
exit "$EXIT_CODE"
