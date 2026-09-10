#!/usr/bin/env bash
# phase-12/selftest_verify_docs.sh — seeded-mutant proof that the REAL phase-12/verify_docs.sh
# exits non-zero on each of seven separately-seeded documentation defects, and passes cleanly on
# an unmutated control, all in one session (the phase-11/selftest_verify_wrappers.sh pattern).
#
# WHY THIS EXISTS: an assertion authored after the prose it grades is not a test, it is a
# restatement. verify_docs.sh was written before any of the eleven target documents were edited
# by wave 2 — this script is the other half of that discipline: proving the checker it wrote can
# actually fail, on each class of defect it claims to catch, before wave 2 ever runs.
#
# FIXTURES ARE SYNTHETIC, NOT COPIES OF THE REAL DOCS. The real docs are still uncorrected at
# this point in the phase (that is what phase-12/results/CURRENT_RED_RUN's RED run proves) — this
# script must not depend on wave 2 having run. Each of the eleven fixtures is a few lines long,
# just enough to satisfy every assertion verify_docs.sh registers for that path, including a
# "부록 — 정정 전 기록" appendix carrying the forbidden literals verbatim where the table demands
# one (appendix_required=1).
#
# Mutants are built in a scratch mktemp -d tree, NEVER under phase-12/ or docs/ — the real target
# documents are only ever read (to confirm they exist, never to copy from) by other plans; this
# script never touches them.
#
# Deliberately NOT `set -e`, for the same reason phase-11/selftest_verify_wrappers.sh gives: a
# non-zero exit from a mutant run is DATA to be recorded, not a script bug — `set -e` would abort
# this script on the very condition it exists to observe (phase-10/PHASE-10-FINDINGS.md §4.6).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_DOCS_SH="$REPO_ROOT/phase-12/verify_docs.sh"
RESULTS_ROOT="$REPO_ROOT/phase-12/results"

mkdir -p "$RESULTS_ROOT"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$RESULTS_ROOT/${TS}-mutants"
mkdir -p "$RUN/mutants"

TSV="$RUN/docs-selftest.tsv"
printf 'mutant\tdefect\texpected\tobserved_exit\tverdict\n' > "$TSV"

MUTROOT="$(mktemp -d "${TMPDIR:-/tmp}/verify-docs-selftest.XXXXXX")"
trap 'rm -rf "$MUTROOT"' EXIT

FAIL_ANY=0

# ---------------------------------------------------------------------------
# The clean template: eleven synthetic fixtures, one per target document, each satisfying every
# assertion verify_docs.sh registers for that path against a clean run. Built once, then cp -R'd
# per mutant so each mutant only needs to apply its own single seeded change.
#
# <!-- M1-INSERT-POINT --> in the implementation.md fixture is an inert placeholder (not the
# escape marker, not any forbidden/required literal) that M1 and M7 replace; left untouched, it
# is harmless prose that satisfies nothing and breaks nothing.
# ---------------------------------------------------------------------------
TEMPLATE_DIR="$MUTROOT/template"
mkdir -p "$TEMPLATE_DIR/docs/manual" "$TEMPLATE_DIR/howto" "$TEMPLATE_DIR/qanda"

cat > "$TEMPLATE_DIR/docs/plan-act-reasoning-implementation.md" <<'EOF'
# Plan/Act Reasoning — Implementation (fixture)

> **상태: 구현됨.** shouldIncludeReasoningHistory 재확인 완료. `phase-11/WRAPPER-DESIGN.md` 참조.

## 이 정정이 바꾸는 것

| 대상 | 이전 | 이후 |
| --- | --- | --- |
| 상태 | 계획 | 구현됨 |

## 미해결

- 없음 (fixture).

<!-- M1-INSERT-POINT -->

## 부록 — 정정 전 기록

<details>
<summary>원문</summary>

상태: 계획. 미착수.
누적의 증거가 아니다.
`reasoning` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다.
소스는 "누적되지 않는다" 쪽을 가리키나 결정적이지 않다.
cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }

</details>
EOF

cat > "$TEMPLATE_DIR/docs/plan-act-reasoning-design.md" <<'EOF'
# Plan/Act Reasoning — Design (fixture)

> **상태: 채택됨.** 게이트 판정: `phase-09/GATE-VERDICT.md`. 래퍼 계약: `phase-11/WRAPPER-DESIGN.md`.
> 미결 항목: `phase-11/OPEN-ITEMS.md`. 별칭은 `hosted_vllm/` 접두사를 쓴다.

## 이 정정이 바꾸는 것

| 대상 | 이전 | 이후 |
| --- | --- | --- |
| 상태 | 제안 | 채택됨 |

## 부록 — 정정 전 기록

<details>
<summary>원문</summary>

상태: 제안. 아직 구현되지 않았다.
cline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }

</details>
EOF

cat > "$TEMPLATE_DIR/docs/plan-act-reasoning-diagrams.md" <<'EOF'
# Plan/Act Reasoning — Diagrams (fixture)

> **상태: 구현됨.** shouldIncludeReasoningHistory 확인. 토큰 비용은 0.

## 부록 — 정정 전 기록

<details>
<summary>원문</summary>

상태: 계획, 미착수.
소스 조사는 "누적되지 않는다" 쪽을 가리킨다.

</details>
EOF

cat > "$TEMPLATE_DIR/docs/manual/01-cli.md" <<'EOF'
# CLI 매뉴얼 (fixture)

## 6. Plan/Act

`--mode` 플래그는 예전 cli-v3.0.53(git show cli-v3.0.53:apps/cli/src/main.ts) strings 스캔에서
나왔다. GAP-PLANMODE 는 `phase-04/run_headless.sh` 에 대한 이야기다.

## 6a. cline-plan / cline-act

`phase-11/cline-plan`, `phase-11/cline-act` 사용법. 계약: `phase-11/WRAPPER-DESIGN.md`.
`CLINE_PROVIDER_SETTINGS_PATH` 로 격리. 실측: 3.0.61.

종료 코드: exit 2, exit 3, exit 4.
EOF

cat > "$TEMPLATE_DIR/docs/cline-config-pins.md" <<'EOF'
# Cline Config Pins (fixture)

별칭: flashnext-plan, flashnext-act, flashnext-reach-xhigh, flashnext-codex (호출 금지).
`enable_thinking`, `reasoning_effort`, `hosted_vllm/` 접두사. 제거된 qwen- 별칭들.
상태 코드: openai/ 접두사 400, hosted_vllm/ 접두사 500. 증거: `phase-10/REACH-PROOF.md`,
`phase-11/WRAPPER-DESIGN.md`. 실측 max_tokens 20983. prompt_tokens 델타: 13/11/41/53.
providers.json 은 매 호출마다 다시 쓰인다.
EOF

cat > "$TEMPLATE_DIR/docs/32k-compaction-policy.md" <<'EOF'
# 32K Compaction Policy (fixture)

> **2026-08-30 전면 정정.** 이후 **2026-09-10 추가 정정.**

실측 max_tokens 는 20983 (동적, contextWindow × 0.9 근사). 278 개 로그 샘플. 2048 은 과거 실측값.
근거: `phase-11/AB-PROTOCOL.md`. 트리거 26,100.
EOF

cat > "$TEMPLATE_DIR/docs/cline-max-tokens-findings.md" <<'EOF'
# Cline Max Tokens Findings (fixture)

> 실측 max_tokens 는 동적이다 (20983 관측, 이전 2048 아님).

## 이 정정이 바꾸는 것

| 대상 | 이전 | 이후 |
| --- | --- | --- |
| OBSERVED_MAX | 2048 (고정 가정) | 20983 (동적) |

근거: `phase-11/OPEN-ITEMS.md`.

## 부록 — 정정 전 기록

<details>
<summary>원문</summary>

**`OBSERVED_MAX = 2048`.**

</details>
EOF

cat > "$TEMPLATE_DIR/howto/fast-and-deep-mode.md" <<'EOF'
# Fast and Deep Mode (howto fixture)

2026-09-10 갱신. 별칭은 `phase-11/cline-plan` 로 설정한다. 방법 2/3 는 이제 완료됐다.
EOF

cat > "$TEMPLATE_DIR/howto/thinking-and-reasoning-effort.md" <<'EOF'
# Thinking and Reasoning Effort (howto fixture)

2026-09-10 갱신. `flashnext-plan` 별칭이 Plan/Act 와 thinking 을 이미 연결했다.
EOF

cat > "$TEMPLATE_DIR/qanda/001-testing-plan-act-with-cline-cli.md" <<'EOF'
# Q&A 001 (fixture)

2026-09-10 확인. 래퍼 기본 별칭은 확정됐습니다 (`flashnext-plan`). A/B 결과: 25/30, p=0.563,
override 로 유지. 근거: `phase-11/AB-RESULTS.md`.
EOF

cat > "$TEMPLATE_DIR/qanda/003-how-the-wrappers-work.md" <<'EOF'
# Q&A 003 (fixture)

2026-09-10 확인. `CLINE_PROVIDER_SETTINGS_PATH` 로 오염을 막습니다 (커밋 017c65e). A/B: 25/30,
p=0.563, override. 근거: `phase-11/AB-RESULTS.md`.
EOF

copy_base() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$TEMPLATE_DIR"/. "$dest"/
}

require_seed() {
  # $1 = label, $2 = file, $3 = pattern that MUST be present after the seed edit — fails loudly
  # if the seed itself silently no-op'd (phase-11/selftest_verify_wrappers.sh's own safety net).
  local label="$1" file="$2" pattern="$3"
  if ! grep -qF -- "$pattern" "$file"; then
    echo "FATAL: mutant seed '$label' did not take — expected to find '$pattern' in $file" >&2
    exit 1
  fi
}

run_against_mutant() {
  # $1 = mutant DOCS_ROOT dir, $2 = output file.
  local mdir="$1" outfile="$2"
  ( DOCS_ROOT="$mdir" bash "$VERIFY_DOCS_SH" ) > "$outfile" 2>&1
  return $?
}

excerpt_of() {
  local out="$1" pattern="$2" line
  line="$(grep -m1 -E "$pattern" "$out" 2>/dev/null || true)"
  if [ -z "$line" ]; then
    line="$(grep -m1 'FAIL\[DOCS\]' "$out" 2>/dev/null || true)"
  fi
  if [ -z "$line" ]; then
    line="(no FAIL[DOCS] line found in output)"
  fi
  printf '%s' "$line" | tr -d '\n' | cut -c1-300
}

record_row() {
  # $1 mutant $2 defect $3 expected $4 exit_code $5 excerpt $6 expect_class(nonzero|zero)
  local mutant="$1" defect="$2" expected="$3" rc="$4" excerpt="$5" expect_class="$6" verdict
  if [ "$expect_class" = "nonzero" ]; then
    if [ "$rc" -ne 0 ]; then verdict="CAUGHT"; else verdict="MISSED"; FAIL_ANY=1; fi
  else
    if [ "$rc" -eq 0 ]; then verdict="PASS"; else verdict="FAIL"; FAIL_ANY=1; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$mutant" "$defect" "$expected" "$rc" "$verdict" >> "$TSV"
  echo "$mutant: exit=$rc verdict=$verdict — $excerpt"
}

# ---------------------------------------------------------------------------
# M1 — false string still in the live body. Insert '누적의 증거가 아니다' above the appendix
# marker in the implementation.md fixture. The exact defect this phase exists to prevent.
# ---------------------------------------------------------------------------
M1_DIR="$MUTROOT/m1-forbidden-in-live-body"
copy_base "$M1_DIR"
M1_FILE="$M1_DIR/docs/plan-act-reasoning-implementation.md"
sed -i.bak 's/<!-- M1-INSERT-POINT -->/누적의 증거가 아니다/' "$M1_FILE"
rm -f "$M1_FILE.bak"
require_seed "M1" "$M1_FILE" '누적의 증거가 아니다'
M1_OUT="$RUN/mutants/M1.out"
run_against_mutant "$M1_DIR" "$M1_OUT"; M1_RC=$?
record_row "M1-forbidden-in-live-body" \
  "implementation.md: inserted the forbidden sentence '누적의 증거가 아니다' above the appendix marker" \
  "FORBIDDEN check on docs/plan-act-reasoning-implementation.md" \
  "$M1_RC" "$(excerpt_of "$M1_OUT" 'FAIL\[DOCS\].*누적의 증거')" nonzero

# ---------------------------------------------------------------------------
# M2 — required anchor missing. Delete 'shouldIncludeReasoningHistory' from the same fixture.
# ---------------------------------------------------------------------------
M2_DIR="$MUTROOT/m2-required-anchor-missing"
copy_base "$M2_DIR"
M2_FILE="$M2_DIR/docs/plan-act-reasoning-implementation.md"
sed -i.bak 's/shouldIncludeReasoningHistory/REDACTED_ANCHOR/' "$M2_FILE"
rm -f "$M2_FILE.bak"
if grep -qF -- 'shouldIncludeReasoningHistory' "$M2_FILE"; then
  echo "FATAL: mutant seed 'M2' did not take — shouldIncludeReasoningHistory still present" >&2
  exit 1
fi
M2_OUT="$RUN/mutants/M2.out"
run_against_mutant "$M2_DIR" "$M2_OUT"; M2_RC=$?
record_row "M2-required-anchor-missing" \
  "implementation.md: 'shouldIncludeReasoningHistory' replaced with REDACTED_ANCHOR" \
  "REQUIRED check on docs/plan-act-reasoning-implementation.md" \
  "$M2_RC" "$(excerpt_of "$M2_OUT" 'FAIL\[DOCS\].*shouldIncludeReasoningHistory')" nonzero

# ---------------------------------------------------------------------------
# M3 — A/B disclosure incomplete. In a fixture mentioning A/B (qanda/001), delete 'p=0.563'.
# This is the "no reader may conclude the A/B favoured flashnext-plan" property, made falsifiable.
# ---------------------------------------------------------------------------
M3_DIR="$MUTROOT/m3-ab-disclosure-incomplete"
copy_base "$M3_DIR"
M3_FILE="$M3_DIR/qanda/001-testing-plan-act-with-cline-cli.md"
sed -i.bak 's/25\/30, p=0.563,/25\/30,/' "$M3_FILE"
rm -f "$M3_FILE.bak"
if grep -qF -- 'p=0.563' "$M3_FILE"; then
  echo "FATAL: mutant seed 'M3' did not take — p=0.563 still present" >&2
  exit 1
fi
M3_OUT="$RUN/mutants/M3.out"
run_against_mutant "$M3_DIR" "$M3_OUT"; M3_RC=$?
record_row "M3-ab-disclosure-incomplete" \
  "qanda/001: 'p=0.563' deleted from the A/B-mentioning sentence" \
  "AB_DISCLOSURE check on qanda/001-testing-plan-act-with-cline-cli.md" \
  "$M3_RC" "$(excerpt_of "$M3_OUT" 'FAIL\[DOCS\].*AB_DISCLOSURE')" nonzero

# ---------------------------------------------------------------------------
# M4 — dead citation. Add a backtick-cited path that does not exist.
# ---------------------------------------------------------------------------
M4_DIR="$MUTROOT/m4-dead-citation"
copy_base "$M4_DIR"
M4_FILE="$M4_DIR/docs/cline-config-pins.md"
printf '참고: `phase-99/NOPE.md`.\n' >> "$M4_FILE"
require_seed "M4" "$M4_FILE" 'phase-99/NOPE.md'
M4_OUT="$RUN/mutants/M4.out"
run_against_mutant "$M4_DIR" "$M4_OUT"; M4_RC=$?
record_row "M4-dead-citation" \
  "cline-config-pins.md: appended a citation of \`phase-99/NOPE.md\` (does not exist)" \
  "CITED_PATHS_EXIST check on docs/cline-config-pins.md" \
  "$M4_RC" "$(excerpt_of "$M4_OUT" 'FAIL\[DOCS\].*CITED_PATHS_EXIST')" nonzero

# ---------------------------------------------------------------------------
# M5 — appendix deleted rather than preserved. Remove the preserved original TEXT from inside the
# diagrams.md fixture's appendix, leaving the "부록 — 정정 전 기록" marker/heading itself intact
# (so this mutant isolates APPENDIX_INTEGRITY specifically, not REQUIRED-marker-missing) and the
# live body clean. A clean live body with no preserved original is a deletion, not a correction.
# ---------------------------------------------------------------------------
M5_DIR="$MUTROOT/m5-appendix-content-deleted"
copy_base "$M5_DIR"
M5_FILE="$M5_DIR/docs/plan-act-reasoning-diagrams.md"
sed -i.bak -e '/^상태: 계획, 미착수\.$/d' -e '/소스 조사는 "누적되지 않는다" 쪽을 가리킨다/d' "$M5_FILE"
rm -f "$M5_FILE.bak"
if grep -qF -- '상태: 계획, 미착수.' "$M5_FILE"; then
  echo "FATAL: mutant seed 'M5' did not take — preserved original text still present" >&2
  exit 1
fi
require_seed "M5 (marker survives)" "$M5_FILE" '부록 — 정정 전 기록'
M5_OUT="$RUN/mutants/M5.out"
run_against_mutant "$M5_DIR" "$M5_OUT"; M5_RC=$?
record_row "M5-appendix-content-deleted" \
  "diagrams.md: preserved original text removed from inside the appendix, marker/heading left intact" \
  "APPENDIX_INTEGRITY check on docs/plan-act-reasoning-diagrams.md" \
  "$M5_RC" "$(excerpt_of "$M5_OUT" 'FAIL\[DOCS\].*APPENDIX_INTEGRITY')" nonzero

# ---------------------------------------------------------------------------
# M6 — 3.0.53 citation without the 'git show' form.
# ---------------------------------------------------------------------------
M6_DIR="$MUTROOT/m6-tag-citation-missing-git-show"
copy_base "$M6_DIR"
M6_FILE="$M6_DIR/docs/cline-config-pins.md"
printf '이 값은 cli-v3.0.53 시절 값이다.\n' >> "$M6_FILE"
require_seed "M6" "$M6_FILE" 'cli-v3.0.53'
if grep -qF -- 'git show cli-v3.0.53:' "$M6_FILE"; then
  echo "FATAL: mutant seed 'M6' did not take — 'git show cli-v3.0.53:' unexpectedly already present" >&2
  exit 1
fi
M6_OUT="$RUN/mutants/M6.out"
run_against_mutant "$M6_DIR" "$M6_OUT"; M6_RC=$?
record_row "M6-tag-citation-missing-git-show" \
  "cline-config-pins.md: appended a bare 'cli-v3.0.53' mention with no 'git show cli-v3.0.53:' form" \
  "TAG_CITATION check on docs/cline-config-pins.md" \
  "$M6_RC" "$(excerpt_of "$M6_OUT" 'FAIL\[DOCS\].*TAG_CITATION')" nonzero

# ---------------------------------------------------------------------------
# M7 — escape hatch is auditable, not silent. Take the M1 defect (forbidden sentence inserted in
# live body) and append the verify_docs:allow marker to the SAME line. The checker must now exit
# 0 for that assertion AND report the escape in its own summary with file:line. Verdict is CAUGHT
# only if the escape appears in the transcript — an exit-0-only check would call a silent
# exemption CAUGHT, which is exactly the hole this mutant exists to rule out.
# ---------------------------------------------------------------------------
M7_DIR="$MUTROOT/m7-escape-hatch-must-be-audited"
copy_base "$M7_DIR"
M7_FILE="$M7_DIR/docs/plan-act-reasoning-implementation.md"
sed -i.bak 's/<!-- M1-INSERT-POINT -->/누적의 증거가 아니다 <!-- verify_docs:allow -->/' "$M7_FILE"
rm -f "$M7_FILE.bak"
require_seed "M7 (forbidden text)" "$M7_FILE" '누적의 증거가 아니다'
require_seed "M7 (escape marker)" "$M7_FILE" '<!-- verify_docs:allow -->'
M7_OUT="$RUN/mutants/M7.out"
run_against_mutant "$M7_DIR" "$M7_OUT"; M7_RC=$?
M7_ESCAPE_LINE="$(grep -m1 -E 'ESCAPE\[DOCS\]:.*plan-act-reasoning-implementation\.md:' "$M7_OUT" || true)"
M7_VERDICT="MISSED"
if [ "$M7_RC" -eq 0 ] && [ -n "$M7_ESCAPE_LINE" ]; then
  M7_VERDICT="CAUGHT"
else
  FAIL_ANY=1
fi
printf 'M7-escape-hatch-must-be-audited\t%s\t%s\t%s\t%s\n' \
  "implementation.md: forbidden sentence + verify_docs:allow on the same line" \
  "exit 0 for that assertion AND an ESCAPE[DOCS] line naming file:line in the transcript" \
  "$M7_RC" "$M7_VERDICT" >> "$TSV"
echo "M7-escape-hatch-must-be-audited: exit=$M7_RC verdict=$M7_VERDICT — escape line: ${M7_ESCAPE_LINE:-<none found>}"

# ---------------------------------------------------------------------------
# M8 — CLEAN CONTROL. The unmutated fixture set, run in the same session. Must PASS (exit 0),
# with the escape count reported as 0. Without this, seven CAUGHTs prove only that the script
# fails on everything — the positive-control argument phase-11/selftest_verify_wrappers.sh's own
# M8/M9 make.
# ---------------------------------------------------------------------------
M8_DIR="$MUTROOT/m8-clean-control"
copy_base "$M8_DIR"
M8_OUT="$RUN/mutants/M8.out"
run_against_mutant "$M8_DIR" "$M8_OUT"; M8_RC=$?
M8_ESCAPE_COUNT="$(grep -oE 'escape hatch summary: [0-9]+' "$M8_OUT" | grep -oE '[0-9]+' || echo "?")"
M8_VERDICT="FAIL"
if [ "$M8_RC" -eq 0 ] && [ "$M8_ESCAPE_COUNT" = "0" ]; then
  M8_VERDICT="PASS"
else
  FAIL_ANY=1
fi
printf 'M8-clean-control\t%s\t%s\t%s\t%s\n' \
  "none — unmutated copy of the synthetic fixture set" \
  "must exit 0 with escape hatch count 0 — a checker that fails everything cannot masquerade as a strict one" \
  "$M8_RC" "$M8_VERDICT" >> "$TSV"
echo "M8-clean-control: exit=$M8_RC verdict=$M8_VERDICT — escape count observed: $M8_ESCAPE_COUNT"

echo
echo "docs-selftest.tsv written to: $TSV"
column -t -s "$(printf '\t')" "$TSV" 2>/dev/null || cat "$TSV"

echo
echo "=== overall selftest verdict: $([ "$FAIL_ANY" = "0" ] && echo PASS || echo FAIL) ==="

exit "$FAIL_ANY"
