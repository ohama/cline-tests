# Anti-overclaim sweep — Plan 12-08 (phase close, milestone close)

Sentence-cited sweep over the eleven documents this phase corrected plus the two `qanda/` entries
`verify_docs.sh` treats as self-corrected (`qanda/001`, `qanda/003`), `qanda/004` (already corrected
before this phase, restated by several of the eleven), and `phase-11/PHASE-11-FINDINGS.md` where
`docs/` now restates its own summary claims. Each check below quotes the sentence(s) in the current,
post-wave-2 text that satisfy the claim, with file and line. This audit reads the prose as a reader
would — the thing a grep cannot check is a paragraph that is individually true and collectively
misleading — not as `phase-12/verify_docs.sh` reads it.

One genuine `FAIL` was found while conducting this audit (claim 6, below). It was **fixed in the
document**, then re-audited, per this plan's own rule ("A FAIL is fixed, not annotated") — not
worked around, and not left for the mechanical sweep to catch, because the mechanical sweep had no
assertion registered for it and did not catch it. `phase-12/verify_docs.sh` was re-run after the fix
and still reports `CASES 134/134`, exit 0 (`phase-12/results/CURRENT_GREEN_RUN`).

## 1. No document implies the A/B showed thinking helps — the single most important line.

**PASS**, after reading every paragraph in all eleven documents that mentions the A/B, not just the
disclosure-quartet strings `verify_docs.sh`'s `AB_DISCLOSURE` class checks for.

> "override 의 근거는 A/B 가 정확도 개선을 찾았기 때문이 **아니다** — 두 arm 이 동등하게
> 시도된 구간(과제 01–06, N=5)에서 arm A 와 arm C 모두 **25/30** 으로 정확히 같았고, 셀
> 단위 순열검정은 **p=0.563** 으로 우연과 구별되지 않았다"
— `docs/plan-act-reasoning-implementation.md:7-9`

> "게이트 ② (A/B): 정확도 개선을 **찾지 못했다**. 동일 반복수로 비교 가능한 과제(01–06)에서
> arm A 25/30, arm C 25/30 — 순열검정 p=0.563, 우연과 구별 불가. 사전 등록된 판정 규칙의
> 기계적 출력은 `revert` 였다. **사람이 이를 override 해 `keep` 으로 확정했다** — 개선이
> 증명돼서가 아니라, 규칙의 두 번째 근거였던"
— `docs/plan-act-reasoning-design.md:15-18`

> "게이트 ② (A/B): 정확도 개선 없음(arm A 25/30, arm C 25/30, p=0.563) — `keep` 은 사람이
> 사전 등록 규칙의 `revert` 출력을 override 한 결과이며, 개선이 증명됐다는 뜻이 아니다."
— `docs/plan-act-reasoning-diagrams.md:16-17`

> "이유를 정확히 읽을 것 — A/B 가 이 별칭을 더 낫다고 판정해서가 아니다. 두 arm 모두 같은
> 반복수로 시도한 과제들에서 arm A(사고 끔) 25/30, arm C(`medium`) 25/30 — 정확도 차이가
> 전혀 없었다(permutation test p=0.563). 사전 등록된 규칙의 산출은 `revert` 였다. 사람이
> 그 산출을 **override** 해서 `keep` 으로 결정했다"
— `docs/manual/01-cli.md:216-219`

> "결정은 `keep` 입니다 ... 이 결정은 **인간이 규칙의 출력을 오버라이드해서** 나왔습니다 —
> 규칙 자체는 `revert` 를 출력했습니다 (동일 조건에서 arm C 가 arm A 를 앞서지 못했습니다).
> 오버라이드의 근거는 **정확도가 아니라**"
— `qanda/001-testing-plan-act-with-cline-cli.md:170-172`

> "이제는 결정이 났습니다 — **`keep`**, 사람이 규칙의 `revert` 출력을 오버라이드해서 나온
> 결정입니다. 오버라이드의 근거는 정확도가 아니라 `providers.json` 부작용이 격리 가능해졌다는
> 것입니다(바로 위 내용). 정확도 근거는 그대로 `revert` 를 지지합니다 — 동일 조건에서 arm A
> 25/30, arm C 25/30 (p=0.563), 사고가 도움이 됐다는 증거는 없습니다."
— `qanda/003-how-the-wrappers-work.md:158-162`

`docs/cline-config-pins.md` and both `howto/` guides mention the shipped `flashnext-plan` alias and
its mechanism repeatedly but never state or imply an A/B outcome anywhere (confirmed: `grep -c
'A/B\|AB-RESULTS' docs/cline-config-pins.md howto/fast-and-deep-mode.md
howto/thinking-and-reasoning-effort.md` → `0` for all three) — silence, not a hedge that could be
misread. Every sentence found above that states an accuracy result attaches `25/30`/`p=0.563` and
names the decision as a human override on a ground other than accuracy, in the same breath, every
time. No sentence in any of the eleven documents, read as a paragraph rather than as a string match,
leaves the impression that the A/B found `flashnext-plan` more accurate.

## 2. No document implies the A/B was fully run.

**PASS.**

> "task 08 전체, arm B 전체, task 07 의 arm C 5회 중 4회는 시도되지 않았다(66/88 셀). 근거:
> `phase-11/AB-RESULTS.md` §8·§11."
— `docs/plan-act-reasoning-design.md:20-21`

> "실행됨(66/88 셀) — 개선 없음(동등 구간 25/30 대 25/30, p=0.563); keep 은 인간의 override,
> 근거는 `providers.json` 부작용 봉쇄(정확도와 무관)"
— `docs/plan-act-reasoning-implementation.md:314`

No document among the eleven states or implies a full 88-cell run, a full 8-task run, or that arm B
ran at all — confirmed by grepping all eleven for `8개 과제`, `모든 과제`, `전체 과제`, `88개`,
`88 개` and finding zero hits. `qanda/003-how-the-wrappers-work.md:154-155`'s "A/B 가 완주한 유일한
이유는 하네스 안에만 있던 수리 루프 덕분입니다" was read carefully for this claim specifically,
because "완주" ("ran to completion") could be misread as "ran the full authorised 88 cells" — it is
not. Read in context, the sentence is about the harness surviving 31 consecutive `providers.json`-
corrupting calls without the run itself crashing, not about task/cell coverage; the same paragraph's
very next sentences (`:158-162`, quoted under claim 1) give the accurate 66/88-adjacent accounting
(equal-N slice only) and cite `AB-RESULTS.md` §11 for the full picture. It does not imply full
coverage, but it is a genuinely ambiguous word choice worth naming here rather than silently passing
it — this is exactly the class of sentence a grep cannot catch and a human reading has to weigh.

## 3. No document lets `flashnext-reach-xhigh`'s wide reach margin be read as the shipped `flashnext-plan`'s.

**PASS.**

> "이 별칭이 지고 있는 증명은 다르다 — 반드시 밝혀야 하는 마진 차이. reach 는 **넓은 마진으로
> 증명되었다 — `flashnext-reach-xhigh` 에서, +40**, 그런데 이 별칭은 한 번도 출하된 적이 없다
> ... 실제로 출하된 `flashnext-plan` 자신의 마진은 **−2** 다 — 명시적으로, 더 약하고
> 보강적인 증명이다. 이것을 '출하된 별칭의 reach 가 넓은 마진으로 증명됐다'로 뭉뚱그리면
> 안 된다 — 그렇지 않았다."
— `docs/cline-config-pins.md:187-191`

`phase-10/PHASE-10-FINDINGS.md` §4.1's own wording ("the shipped arm's −2 ... is the weaker of the
two proofs this phase produced") is carried forward accurately, not softened, into the one document
whose job is to state the pin. No document states or implies the −2 margin is itself a wide-margin
proof.

## 4. No document says the `providers.json` side effect is fixed, resolved, or cannot happen.

**PASS.**

> "봉쇄(containment)는 하루치 기록밖에 없다. commit `017c65e`, 오늘(2026-09-10), 실 운영
> 기록 없음. '고쳤다'/'해결됐다'라고 쓰지 않는다 — **2026-09-10 기준 봉쇄됨, 장기 노출
> 대기 중**이라고 쓴다."
— `docs/plan-act-reasoning-implementation.md:327-329`

> "'격리한다'라고만 쓴다 — 이 부작용이 없어졌다는 말은 쓰지 않는다. 근본 쓰기 자체는
> 소스에서 사라지지 않았다 — 래퍼 밖에서 맨손 `cline -m` 을 부르면 지금도 공유 파일을
> 바꾼다. 이 격리는 커밋 `017c65e`(2026-09-10, 오늘) 로 들어왔고, 하루도 안 된 코드로
> 실사용 이력이 없다."
— `docs/manual/01-cli.md:195-198`

> "🔴 '고쳐졌다'가 아니라 '격리됐다'고 해야 합니다. cline 자체의 기동 경로에 있는
> 무조건적인 쓰기는 그대로입니다 ... 이 격리는 하루밖에 안 됐고 프로덕션 실적이 없습니다"
— `qanda/003-how-the-wrappers-work.md:149-151`

Grep-verified zero surviving instances of "fixed"/"resolved"/"고쳐졌다"/"해결됐다" attached to the
`providers.json` write anywhere in the eleven documents (the four hits for those literals that exist
at all are all *denials* — "write X, not Y" — quoted above, or about unrelated topics: `design.md:245`
is `contextWindow`, a different, already-closed Phase 1 item).

## 5. No document says cline omits reasoning from context; the two claims stay separate.

**PASS.**

> "소스 판독은 재첨부가 **있다**는 것을 보여준다 — 다만 토큰 비용이 0이라 게이트는 통과"
— `docs/plan-act-reasoning-diagrams.md:243`

> "`shouldIncludeReasoningHistory`(`sdk/packages/llms/src/providers/ai-sdk.ts:284-289`, 재확인)"
  ... "소스는 누적됨을 확인(`shouldIncludeReasoningHistory`); 그 위에서 토큰비용은 실측 0"
— `docs/plan-act-reasoning-implementation.md:122,311`

Every corrected occurrence pairs the architecture fact ("재첨부됨"/"누적됨", reasoning IS re-attached)
with the separate, still-true cost fact ("토큰 비용은 0"/"delta=0") in the same sentence or the
immediately adjacent one — never merged into a single claim, and never stated as "재첨부 없음" or
"컨텍스트에서 빠진다" anywhere live (the false form survives only inside the two appendix-preserved
originals, `docs/plan-act-reasoning-implementation.md` §9 and `-diagrams.md`'s appendix, both below
their respective `부록 — 정정 전 기록` markers and excluded from FORBIDDEN scanning by design).

## 6. No document says `-m` does not persist.

**FAIL, found during this audit — fixed, then re-audited to PASS.**

**Found:** `howto/fast-and-deep-mode.md:161-162` (pre-fix) read: "`-m` 은 **호출마다** 모델을
고른다. `providers.json` 을 건드리지 않으므로 검증된 `contextWindow: 29000` 설정이 안전하다." —
this is the exact false claim claim 6 exists to rule out (`-m` in fact rewrites `providers.json`'s
`model` field unconditionally on every call, measured 31/31, 100%, per Phase 11). No `FORBIDDEN`
literal was registered for this sentence in `phase-12/verify_docs.sh` — the mechanical sweep never
saw it, because wave 1's assertion table was written against the eleven documents' *known* debt, and
this specific sentence in this specific howto guide was not among the strings anyone had flagged. It
was caught only by reading the file's "방법 2" section as a user would, immediately after re-reading
`qanda/001`'s and `qanda/004`'s corrected accounts of the same mechanism and noticing the contradiction.

**Fix applied** (this session, before this audit's verdict was recorded): the sentence now reads (in
part) "`-m` 은 **호출마다** 모델을 고른다 — 그러나 **`providers.json` 의 `model` 필드를 매 호출마다
무조건 덮어쓴다**(cline 자신의 시작 경로에 있는 동작, Phase 11 검증에서 31/31, 100% 확인;
`qanda/004-does-cline-always-write-providers-json.md`). 방금 위 명령처럼 래퍼 없이 직접 부르면 이
쓰기가 격리되지 않고 공유 파일에 그대로 남는다 ... 격리하려면 아래 방법 3을 쓴다" —
`howto/fast-and-deep-mode.md:161-168`. `phase-12/verify_docs.sh` re-run after the fix: `CASES
134/134`, exit 0 (no new `FAIL[DOCS]` introduced; the literal substring `A/B` was deliberately kept
out of the fix to avoid an unrelated `AB_DISCLOSURE` trigger on a sentence that has nothing to do
with the A/B's accuracy result, per `phase-12/SCOPE-DECISIONS.md` item 8's own convention and
`12-05-SUMMARY.md`'s precedent for the same file).

**Re-audited, now PASS:**

> "`-m` 값이 그대로 파일에 기록됩니다. 이 호출은 `if` 안에 있지 않습니다 — 기동 경로에
> 무조건 있고, 헤드리스 실행도 이 지점을 지납니다."
— `qanda/004-does-cline-always-write-providers-json.md:62-63`

> "🔴 버그가 아니라 조사 범위의 문제였습니다. 한 모듈에서 쓰기가 없다는 것을 '어디에도
> 쓰기가 없다'로 일반화했습니다."
— `qanda/004-does-cline-always-write-providers-json.md:78-79`

> "`cline -m <별칭>` 은 문서상 '호출 단위 오버라이드'지만, **실제로는 설정 파일에 영구
> 기록**합니다."
— `qanda/001-testing-plan-act-with-cline-cli.md:16`

## 7. No document says `--thinking` does not exist in this project's cline.

**PASS.**

> "CFG-11 전제 정정. `cline@3.0.53` 시점엔 `--thinking` 이 CLI 에 없다고 믿었다. 지금 설치된
> 3.0.60+ 에서는 실재하는 플래그(`none|low|medium|high|xhigh`)이고, litellm 이 클라이언트
> kwargs 를 `litellm_params` **뒤에** 병합하기 때문에 클라이언트가 보낸 값이 별칭이 주입한
> `reasoning_effort` 를 **덮어쓴다**. 이게 정확히 `phase-11/cline-plan`/`cline-act` 가 이
> 플래그를 무조건 거부하는 이유다"
— `docs/cline-config-pins.md:215-219`

> "REFUSED: cline-plan does not accept '--thinking'. Reasoning effort is injected server-side by
> the litellm alias. litellm merges client kwargs AFTER the alias's litellm_params ... so a
> client-sent reasoning_effort OVERRIDES the alias — using --thinking silently bypasses this
> wrapper's guarantee."
— `docs/manual/01-cli.md:161-165` (the wrapper's own verbatim refusal message, quoted exactly)

The flag exists, is refused by the wrapper (not because it doesn't exist, but because a client-sent
value would silently override the alias injection), and the refusal happens before litellm is ever
reached — all three facts stated together, nowhere contradicted.

## 8. No document presents absolute `prompt_tokens` values as portable facts.

**PASS.**

> "절대 `prompt_tokens` 오라클 값 — **23/21/51/63 → 13/11/41/53** 로 원인 불명인 채 이동했다"
— `docs/cline-config-pins.md:232`

> "**절대값을 믿지 말고 델타를 봐라.** 절대값은 시간이 지나며 이동했다 (23/21/51/63 →
> 13/11/41/53). 원인은 규명되지 않았지만 **델타는 비트 단위로 보존**됐다."
— `howto/thinking-and-reasoning-effort.md:172-173`

Both drifted absolute pairs are cited every place they appear as historical facts that moved, with
the delta named as the stable, portable oracle — never as a value a reader should expect to
reproduce.

## 9. No document claims the wrapper makes misuse impossible.

**PASS.**

> "`phase-11/WRAPPER-DESIGN.md` §7 이 정직하게 적어 둔 한계: `-` 로 시작하는 프롬프트는
> 무조건 거부된다(우회 수단 없음 — 다시 써야 한다); `--auto-approve`, `--hooks-dir`,
> `-s/--system`, `--zen`, `--tui`, `--acp`, `--worktree`, `--retries`, `--kanban`, `--update`,
> `--data-dir`, `--config`, `-k/--key`, `-v/--verbose` 등 실제 `cline` 플래그 약 15개는 이
> 래퍼로는 도달할 수 없게 설계돼 있다; 설정 가드는 **중단만 하고 스스로 고치지 않는다** ...
> 정확한 주장은 '넓고 확장 가능한 위험 인자 부류를 거부하고, 소스에서 막지 못하는 유일한
> 부작용을 격리한다' 이지, '오용이 불가능해졌다' 가 아니다."
— `docs/manual/01-cli.md:200-209`

The dash-prefixed-prompt refusal, the ~15 unreachable real flags, and the config guard's abort-not-
heal behaviour are all three named explicitly, in the one document (USE-04's manual) most likely to
be read as an operational guarantee, with the overclaim it exists to rule out spelled out and denied
in the same sentence.

## Verdict

**9/9 PASS** — one of the nine (claim 6) reached PASS only after a real `FAIL` was found by this
hand audit, fixed in the document (`howto/fast-and-deep-mode.md:161-168`), and re-verified both by
re-reading the corrected sentence and by re-running `phase-12/verify_docs.sh` (`CASES 134/134`, exit
0, no regression). Claim 1 — the audit's own most important line — is satisfied everywhere the A/B
is mentioned across all eleven documents and both self-corrected `qanda/` entries, with the
override's real ground (containment, not accuracy) stated in the same breath as the `25/30`/`p=0.563`
figures every time. Claim 2's ambiguous "완주" wording in `qanda/003` was weighed and found, on
reading the surrounding paragraph, not to overclaim task coverage — noted here rather than silently
passed, because a grep would not have flagged it either way and a future reader deserves the reasoning,
not just the verdict.
