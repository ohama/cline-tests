# Anti-overclaim sweep — Plan 07-16 (gap closure 2, final plan)

Sentence-cited sweep over the seven documents this plan touched or is required to check for
consistency: `docs/32k-compaction-policy.md`, `docs/manual/04-32k-operations.md`,
`docs/cline-bench.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`,
`.planning/REQUIREMENTS.md`, `.planning/v1-MILESTONE-AUDIT.md`. Each check below quotes the
sentence(s) in the current (post-07-16) text that satisfy it, with file and line.

## 1. No document states or implies any cline-bench task passed. (P = 0 still.)

**PASS.**

> "모델 서버(flashnext)에 실제로 도달**했고, 통과는 여전히 **0개**다."
— `docs/cline-bench.md:11`

> "**통과 0개**다."
— `docs/manual/04-32k-operations.md:123`

> "**BCH-01 은 여전히 `not_met`이며 체크박스도 그대로 미체크다.**"
— `.planning/REQUIREMENTS.md:92`

No new sentence added by this plan (Task 1/2 diffs) asserts or implies a pass; the corrected
`max_prompt_tokens_attempted` figures added to `docs/cline-bench.md` and
`docs/manual/04-32k-operations.md` describe *how far over* the wall each fatal request landed
(5,435 / 123 / 459 tokens), which is evidence of failure, not of a pass.

## 2. No document states cline-bench verified this stack.

**PASS.**

> "공식 스위트 전체(또는 그 상당 부분)가 검증됐다고 서술하는 어떤 문장도 안 된다"
— `docs/cline-bench.md:250` (§9, untouched by this plan's edits, explicitly forbids this)

> "다음 문장들은 절대 쓰지 않는다: cline-bench 가 통과했다, 공식 스위트가 검증됐다, ...
> BCH-01 이 충족됐다, 이 스택이 cline-bench 과제를 완료할 수 있다."
— `docs/manual/04-32k-operations.md:139-140` (§7, unchanged prohibition list, still literally
present after this plan's §7 addition, which was inserted *before* this list, not over it)

None of this plan's new text (the two-mechanism breakdown, the classifier-fix note) claims
verification of the stack — it only narrates why the three `fail-context` verdicts are
trustworthy, which is a statement about a classifier, not about the stack passing anything.

## 3. No document implies the recommendation is proven to make real bench tasks survive.

**PASS.**

> "29,000 은 '합성 회귀에서 실측 검증된 값'으로 남고, '실제 에이전트 워크로드에서 벽 충돌을
> 막아준다는 값'으로는 재서술되지 않는다."
— `docs/32k-compaction-policy.md:115-116` (§4a, new in this plan)

> "This analysis is about why three specific tasks died. **It does not establish that not
> changing `contextWindow` makes cline-bench pass**"
— `phase-07/results/20260831T011037Z-remediation/RECOMMENDATION.md:78` (07-14, unmodified by
this plan, and this plan's own text does not contradict it anywhere)

`.planning/PROJECT.md`'s Core Value correction explicitly frames the doc-only decision as "이
값을 낮추는 것은 문제의 축이 아니라는 판단" (a judgment about which axis is NOT the fix), not a
claim that leaving the value unchanged fixes anything.

## 4. No document implies 5-8 tasks ran; BCH-01 is `not_met` everywhere it appears.

**PASS.** Grep-verified zero surviving instances of BCH-01 marked `met`/`Complete`, and zero
instances implying 5-8 unique tasks ran, across all seven documents:

> "`not_met` 그대로." / "**BCH-01 은 여전히 `not_met`이며 체크박스도 그대로 미체크다.**"
— `.planning/REQUIREMENTS.md:82,92`; checkbox at `.planning/REQUIREMENTS.md:79` remains `[ ]`

> "`not_met` 은 그대로다."
— `.planning/ROADMAP.md:166`; criterion 1 header at `.planning/ROADMAP.md:159` still reads
"— **`not_met`**:"; Phase 7 progress row at `.planning/ROADMAP.md:233` still reads
"기준 1 `not_met`"

> "실제로 실행된 과제는 여전히 고유 **4개**뿐이다"
— `.planning/ROADMAP.md:160` (unchanged by this plan)

## 5. The synthetic proof of the Core Value is preserved, not erased — and is scoped, not generalised.

**PASS.**

> "**자동 압축은 합성 회귀(균일 필러 파일)에서 정상 작동한다.**" ... "증거:
> `phase-01/results/exp-verify29k/` (필러 18개 완주, 압축 3회 이상, **서버 400 0건**, 8분 22초)."
— `docs/32k-compaction-policy.md:9,12` — the synthetic evidence citation is unchanged from
before this plan; only the claim's stated scope changed (added "합성 회귀에서").

> "✅ **2026-08-30 — 합성 회귀에서 달성됨.**" ... "합성 증명은 지워지지 않는다 — 위 필러
> 회귀는 여전히 유효하고 재현 가능하다."
— `.planning/PROJECT.md:16,23` (the 2026-08-31 correction block explicitly preserves the
synthetic proof in the same paragraph that narrows its generalization)

## 6. If the phase's root-cause conclusion was indeterminate for any task, every document says so for that task and names the missing captures.

**PASS.** `discord-trivia-approval-keyerror`'s proximate mechanism was never forensically
characterized (07-11 scoped its two-task forensics to `telegram-plugin-refactor` and
`v-edit-workspace-tests` only) and every document that lists the three tasks' mechanisms marks
it `indeterminate`/"미측정", not a guessed mechanism:

> "`discord-trivia-approval-keyerror` 는 근인이 측정되지 않았다 (indeterminate)."
— `docs/cline-bench.md:140-141`

> "`discord-trivia-approval-keyerror`: 459 토큰 초과, 메커니즘 미측정)."
— `.planning/REQUIREMENTS.md:87`

> "는 459 토큰 차이로 넘었으나 어느 메커니즘인지는 측정되지 않았다."
— `.planning/v1-MILESTONE-AUDIT.md:93`

> "`discord-trivia-approval-keyerror` 는 459 토큰 차이로 넘었으나 어느 메커니즘인지는
> 측정되지 않았다(indeterminate)."
— `docs/manual/04-32k-operations.md:129-130`

The `v-edit-workspace-tests` skip-guard's own *cause* (why iterations 9-12 skip) is likewise
marked indeterminate, not invented, in the source evidence this plan cites but does not
overwrite:

> "iteration 9~12 네 번 연속으로 `auto-compaction-skipped` 를 냈다(원인 필드 없음,
> indeterminate)"
— `docs/32k-compaction-policy.md:120-121` (§4a, new in this plan); the same "원인 미상,
indeterminate" framing for this skip is repeated in `.planning/v1-MILESTONE-AUDIT.md:91-92`
("건너뛰며(원인 미상, indeterminate)")

No document this plan touched asserts a specific cause for the v-edit skip or for
discord-trivia's mechanism beyond what `CONTEXT-FORENSICS.md`/`CANDIDATE-MATRIX.md` already
support as confirmed vs. indeterminate.

## 7. No retired DOC-04 advice ("token budget caps", "split your task") has been reintroduced without an explicit dated reversal and a matching ROADMAP/REQUIREMENTS update.

**PASS.** The retirement itself is untouched:

> "## 4. \"작업 예산 / 태스크 쪼개기\" 조언은 폐기됐다" ... "**이 조언은 2026-08-30 정정으로
> 폐기됐다**"
— `docs/manual/04-32k-operations.md:82,85` (unchanged by this plan)

This plan's one addition to that section explicitly confirms the retirement stands despite the
new finding, rather than reversing it:

> "이 발견은 위 폐기 결정을 되돌리지 않는다 — 사용자는 이 결과를 보고도 `doc-only`(설정·조언
> 변경 없음)를 선택했다."
— `docs/manual/04-32k-operations.md:94-95` (new in this plan)

`docs/32k-compaction-policy.md` §5 item 2 carries the matching qualifier with the same "not a
reversal" framing:

> "이 정정이 §4 의 폐기된 \"작업 예산 / 태스크 쪼개기\" 조언(`docs/manual/04-32k-operations.md`
> §4, 2026-08-30 폐기)을 되살리는 것은 **아니다**"
— `docs/32k-compaction-policy.md:134-135` (§5, new in this plan)

No ROADMAP/REQUIREMENTS update was needed because no reversal occurred — ROADMAP Phase 8
criterion 4 and REQUIREMENTS DOC-04 are unmodified by this plan (verified: `git diff` for this
plan's REQUIREMENTS.md commit touches only the BCH-01 block and the traceability table, not
the DOC-04 entries).

## 8. Corrected failure classes are consistent across all seven documents.

**PASS.** The three per-task deficits (against `MAX_KV_SIZE=32768`, `prompt + max_tokens`) are
identical everywhere they are cited:

| task | deficit | cited in |
| --- | ---: | --- |
| `telegram-plugin-refactor` | 5,435 | `docs/32k-compaction-policy.md:110`, `docs/manual/04-32k-operations.md:128`, `docs/cline-bench.md:134`, `.planning/v1-MILESTONE-AUDIT.md:90`, `.planning/REQUIREMENTS.md:85` |
| `v-edit-workspace-tests` | 123 | `docs/32k-compaction-policy.md:121`, `docs/manual/04-32k-operations.md:130`, `docs/cline-bench.md:135`, `.planning/v1-MILESTONE-AUDIT.md:92`, `.planning/REQUIREMENTS.md:86` |
| `discord-trivia-approval-keyerror` | 459 | `docs/manual/04-32k-operations.md:130`, `docs/cline-bench.md:133`, `.planning/v1-MILESTONE-AUDIT.md:93`, `.planning/REQUIREMENTS.md:87` |

The classifier-fix headline (0/5 verdicts changed) is likewise stated identically in every
document that mentions it:

> "수리된 분류기로 저장된 5개 실행 인스턴스를 전부 재분류한 결과 **판정은 0건도 바뀌지
> 않았다**"
— `docs/cline-bench.md:143-144`, `docs/manual/04-32k-operations.md:133-134`,
`.planning/v1-MILESTONE-AUDIT.md:95-96` (verbatim); `.planning/REQUIREMENTS.md:89` uses the
byte-identical-meaning paraphrase "재분류한 결과 판정은 **0건 변경**"

N=4/M=3/P=0 remain unchanged everywhere (no document in this sweep states a different count).

## Verdict

**8/8 PASS.** No overclaim in either direction found; the synthetic proof is preserved and
scoped, not erased or generalised; BCH-01/criterion 1 remain honestly `not_met`; the one
indeterminate mechanism (`discord-trivia-approval-keyerror`) is marked as such everywhere it is
discussed; the retired DOC-04 advice was not revived.
