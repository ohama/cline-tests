# Phase 12: 문서 갱신 — Research

**Researched:** 2026-09-10
**Domain:** documentation correction against measured v1.1 evidence (not a coding domain — no
library/stack research applies; this document adapts the standard template to a line-level
correction inventory, which is what the phase actually needs)
**Confidence:** HIGH on every quoted line/citation (all read from disk today); MEDIUM on the
Phase 11 closure status (one section of one evidence file is still uncommitted); LOW on whether
`howto/`+`qanda/` staleness is in this phase's literal scope (flagged, not resolved)

## Summary

This phase's job is not to write new prose about what v1.1 did — it is to find every sentence in
`docs/` that v1.1's own measurements have made false, and replace each with the true statement plus
its evidence citation. I read every file USE-04/USE-05 name, every evidence artifact the milestone
produced (Phase 9 GATE-VERDICT/PRB-03-ORACLE/PRB-04-FINDINGS, Phase 10 PHASE-10-FINDINGS/ALIAS-DESIGN/
REACH-PROOF/CFG-13-EVIDENCE/VRF-04-OBSERVATION, Phase 11 WRAPPER-DESIGN/OPEN-ITEMS/AB-PROTOCOL/
AB-RESULTS), all four `qanda/` entries, all `howto/` docs, and `docs/32k-compaction-policy.md` (named
in scope explicitly to check for v1.1 drift). Four things came back:

1. **The four known debts are all still exactly where they were recorded**, and I have the exact
   current text of every one, quoted verbatim below, with the replacement text Phase 9/10/11 already
   wrote for Phase 12 to use (in two cases, Phase 9's own PRB-04-FINDINGS.md §4 already drafted the
   correction — Phase 12 should copy it, not re-derive it).
2. **A fifth, previously unflagged debt exists**: `docs/32k-compaction-policy.md` §4 and
   `docs/cline-max-tokens-findings.md` (CFG-03) both assert a fixed wire `max_tokens=2048`. Phase
   11's `OPEN-ITEMS.md` Open Item 2 measured this at **20983** at the now-installed cline 3.0.61, and
   `AB-PROTOCOL.md` §3 further found it is not fixed at all — it is sized dynamically per-request so
   `prompt_tokens + max_tokens ≈ 26,100` (`contextWindow × 0.9`). This falsifies the overshoot
   arithmetic in `32k-compaction-policy.md` §4 as literally written. This is outside USE-04/USE-05's
   named file list — it needs an explicit scope decision (§6 below), not silent inclusion or silent
   omission.
3. **Phase 11 is not closed.** `phase-11/AB-RESULTS.md` has a `git status` of "modified, not
   committed" right now, `11-07-PLAN.md` exists with no `11-07-SUMMARY.md`, and
   `.planning/REQUIREMENTS.md` still marks USE-01/02/03 "Pending" despite the work being functionally
   done. The content I read is coherent and dated 2026-09-10 (today) including a completed §11
   ratified decision — but per this phase's own instructions, it must not be treated as final. The
   plan must re-read `phase-11/AB-RESULTS.md`, `phase-11/OPEN-ITEMS.md`, and (once it exists)
   `phase-11/PHASE-11-FINDINGS.md` at execution time, not trust this snapshot.
4. **The canonical-source question has an answer, not a punt**: `docs/` is the only place status
   badges and pin tables live and the only thing USE-04/USE-05 name; `phase-11/WRAPPER-DESIGN.md`
   says explicitly it is "the corrected replacement" `docs/plan-act-reasoning-design.md`/
   `-implementation.md` "should be reconciled against, not a competing draft" — Phase 12 should point
   to it, not re-derive the wrapper contract. `howto/` teaches procedure ("how do I check"); `qanda/`
   answers one-off questions and self-corrects in place when wrong. Two `qanda/` entries
   (001, 003) and two `howto/` entries (`fast-and-deep-mode.md`, `thinking-and-reasoning-effort.md`)
   are themselves now stale (written mid-milestone, describing Phase 10/11 as future work, or
   predating Phase 11's containment fix) — see §5. They are not named by USE-04/USE-05, so this is
   flagged as a scope question for the plan, not assumed in or out.

**Primary recommendation:** treat §2 below as a literal edit list — for every row, open the named
file at the named lines, confirm the quoted "current text" still matches (things may have moved
again by execution time — re-`grep`/re-`sed -n` before editing, don't trust line numbers blindly),
and replace with the "replacement intent" using the cited artifact as the source of truth. Do not
re-derive any of this from scratch; every correction already exists in a Phase 9/10/11 artifact.

## Canonical Source Map (answers research question 5)

| Layer | Job | Gets updated by Phase 12? | Notes |
|---|---|---|---|
| `docs/` | Design rationale, policy, pinned values — the only durable, indexed reference | **Yes — this is USE-04/USE-05's entire scope** | `docs/manual/01-cli.md`, `docs/cline-config-pins.md`, `docs/plan-act-reasoning-{design,implementation,diagrams}.md` |
| `phase-11/WRAPPER-DESIGN.md` | Authoritative *current* wrapper contract, superseding the design docs' sketch | No (it's not under `docs/`) — but `docs/plan-act-reasoning-design.md`/`-implementation.md`'s L3/T5 sections should point to it, not repeat a corrected sketch | Its own §2 says this explicitly: "Phase 12 owns updating those two design documents (USE-05) — this document is the corrected replacement they should be reconciled against, not a competing draft." |
| `howto/` | "How do I check this myself" procedure, with runnable scripts | Not named by USE-04/USE-05 — **flagged as a scope question**, see §5 | Two of three `.md` docs here are stale (pre-Phase-10/11 tense) |
| `qanda/` | One-off Q&A, self-correcting in place when wrong (see `qanda/004`'s own in-place correction) | Not named by USE-04/USE-05 — **flagged as a scope question**, see §5 | Two of four entries are now stale (pre-containment-fix) |
| `phase-*/` (SUMMARY, FINDINGS, EVIDENCE files) | Raw measurement record, point-in-time, never rewritten after the fact | No — these are historical run records, not living docs | Cited *from* `docs/`, never edited by Phase 12 |

**Do not let Phase 12 create a fourth copy of the same table.** The `medium` delta table, the
field-name-differs-by-layer table, and the "HTTP 200 is not evidence" framing already exist,
worded almost identically, in `howto/thinking-and-reasoning-effort.md`, `howto/fast-and-deep-mode.md`,
and now need to exist in `docs/cline-config-pins.md`. When writing the `docs/cline-config-pins.md`
table, cite `phase-10/REACH-PROOF.md` §3 as the source of record and note that `howto/` documents
the same numbers for a different purpose (self-service verification) rather than re-deriving them.

---

## The Line-Level Inventory

### A. `docs/plan-act-reasoning-implementation.md`

| # | Lines | Current text (verbatim, confirmed on disk 2026-09-10) | What's wrong | Replacement intent | Artifact |
|---|---|---|---|---|---|
| A1 | 1–6 | `> **상태: 계획. 미착수.** 설계 근거는 ...를 따른다.\n> 작성 2026-09-01.` | Status badge says "planned, not started." The milestone shipped: aliases live (Phase 10), wrappers live (Phase 11), A/B ran, decision made (`keep`, override reason). | Replace with a status line reflecting **구현됨 — 배포 결정: keep(override)**, dated, pointing to `phase-11/AB-RESULTS.md` §11 and `phase-11/WRAPPER-DESIGN.md`. Follow the `docs/32k-compaction-policy.md` precedent (§F below): a dated correction banner at the top, narrowed/corrected body, historical framing preserved in place with a note rather than deleted. | ROADMAP Phase 12 criterion 3; USE-05 |
| A2 | 96–100 | `**소스 조사 결과 (2026-09-01, tag \`cli-v3.0.53\`):**\n- \`agentic-compaction.ts:88\` 의 \`reasoningChars\` 는 **압축 요약기 자신의** reasoning 출력을\n  세는 텔레메트리다. 요약문 \`text\` 만 반환되고 reasoning 은 버려진다. **누적의 증거가 아니다.**\n- \`toGatewayRequestMessages()\` (\`compat.ts:306\`) 는 \`message.content\` 배열만 순회한다.\n  \`reasoning\` 을 아웃바운드 메시지에 싣는 코드는 발견되지 않았다.\n- \`runtime-event-adapter.ts:290\` 의 \`reasoning: reasoning.reasoning\` 은 이벤트 구성(표시용)이다.` | **False negative.** This is exactly the primary correction target Phase 9 flagged. The two functions cited (`agentic-compaction.ts:88`, `toGatewayRequestMessages()`) are not on the path that reattaches reasoning; the real path is `shouldIncludeReasoningHistory`/`agentPartToContentBlock`, which **does** reattach. | Replace the three bullets with `phase-09/PRB-04-FINDINGS.md` §3's finding: Cline **does** re-attach reasoning history by default for non-Cerebras providers (`shouldIncludeReasoningHistory`, `sdk/packages/llms/src/providers/ai-sdk.ts:284-289`, calling `isCerebrasProvider` from `model-facts.ts:449`; `agentPartToContentBlock`'s `case "reasoning"` at `agent-message-codec.ts:237`, persisting a `ThinkingContent` block; `message-builder.ts:1213-1214` counts it toward the text budget). State plainly that the *architecture* claim was wrong; the *token-cost* claim ("costs zero on this stack") was right and is unaffected — PRB-04's own §1 replay matrix (16/16 `delta=0`) is why the gate passed anyway. Note the source citations were re-verified at `cli-v3.0.53` (tag now only reachable via `git show cli-v3.0.53:<path>` since `cline-src`'s working tree moved to `cli-v3.0.61` — see Open Item below). | `phase-09/PRB-04-FINDINGS.md` §3–§4 (its §4 literally says "this is the primary correction target — replace with the §3 finding above") |
| A3 | 102 | `**소스는 "누적되지 않는다" 쪽을 가리키나 결정적이지 않다.** 실측으로 확정한다:` | Same false-negative framing, restated as the transition sentence. | Replace with something like: "소스는 **누적된다** 쪽을 가리킨다 — 다만 토큰 비용은 실측으로 0임이 확정됐다 (아래)." | Same as A2 |
| A4 | 191–194 (§6, "❌ role_shim 에서 프롬프트를 보고 모드를 추론하기") | unchanged text, still valid — no correction needed, listed for completeness only | n/a | No edit | `phase-09/PRB-04-FINDINGS.md` §4 explicitly says no correction needed for adjacent sections it checked — don't touch things it didn't flag |
| A5 | 191–194 (§T5, lines ~187–198, the `cline-plan()`/`cline-act()` shell-function sketch) | ```sh\ncline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }\ncline-act()  { CLINE_NO_AUTO_UPDATE=1 cline    -m flashnext-act  "$@"; }\n``` | **Superseded design, not merely stale wording.** `phase-11/WRAPPER-DESIGN.md` §2 names this exact snippet and proves it's unsafe: `"$@"` forwards `--thinking high` and a second `-m` straight through, defeating the whole mechanism (this is literally what Phase 11's `MUTANT-LEAKY` test exists to catch, and what the shipped wrapper's deny-by-default parser exists to prevent). It also can't be statically checked by `verify_config.sh` (a shell function has no file path) and can't be invoked as a subprocess by a test harness. | Replace the sketch with a pointer: "이 설계는 Phase 11 에서 실제 스크립트(`phase-11/cline-plan`/`cline-act`, deny-by-default 파서)로 대체됐다 — 이유는 `phase-11/WRAPPER-DESIGN.md` §2·§3·§4 참조." Do not leave the naive sketch presented as the current design; either delete it or wrap it in the same "정정 전 기록, 원문 보존" pattern `32k-compaction-policy.md` §9 uses, explicitly labelled superseded. | `phase-11/WRAPPER-DESIGN.md` §2 (names this file and section by number) |
| A6 | 217–220 (§T7, "문서" checklist) | `- \`docs/manual/01-cli.md\` — \`cline-plan\` / \`cline-act\` 사용법\n- \`docs/plan-act-reasoning-design.md\` — 설계 문서에 "구현됨" 표시와 실측 결과 반영\n- \`docs/cline-config-pins.md\` — 별칭과 그 파라미터를 고정값 목록에 추가\n- 🔴 \`--thinking\` 은 여전히 400 이라는 사실을 명시. 별칭이 대안이라는 것도` | Not wrong — this is literally Phase 12's own task list, still accurate. | No correction; can stay as a historical "here's what T7 always intended," but should probably get a checkmark/pointer once Phase 12 does it. | n/a |
| A7 | 229, 244 | table/summary rows describing "사고 트레이스가 컨텍스트에 누적된다 → kill condition" as the **gate's own criterion description** | Phase 9 explicitly checked these and found them **not wrong** — they describe what the gate checks, not a source-inspection conclusion. | No edit — do not confuse with A2/A3. | `phase-09/PRB-04-FINDINGS.md` §4, explicit "no edit required there" note |

### B. `docs/plan-act-reasoning-diagrams.md`

| # | Lines | Current text | What's wrong | Replacement intent | Artifact |
|---|---|---|---|---|---|
| B1 | 1–6 | `> ... 시각 요약. 소스 확인 \`cline/cline\` tag \`cli-v3.0.53\`, 실측 2026-09-01.\n> **상태: 계획, 미착수.**` | Same stale status badge as A1. | Same treatment as A1 — dated correction, "구현됨" + pointer to `phase-11/AB-RESULTS.md` §11 and `WRAPPER-DESIGN.md`. Consider also noting the diagrams' §6 mermaid flowchart's stop-points (K1/K2/K4/K6) are historically accurate as *what the plan checked for*, not that they currently apply (K2/K6 resolved: no kill, A/B ran and result was override-to-keep). | Same as A1 |
| B2 | 184–192 (§6 callout, "🔴 Gate ① 이 kill condition 인 이유") | `> 소스 조사는 "누적되지 않는다" 쪽을 가리킨다 — \`toGatewayRequestMessages()\` 는 \`content\`\n> 배열만 순회하고, \`agentic-compaction.ts:88\` 의 \`reasoningChars\` 는 *요약기 자신의* 출력을\n> 세는 텔레메트리다. 다만 결정적이지 않아 실측으로 확정한다.` (this is the specific "lines 187–191" cited by Phase 9's handoff; on today's file this text spans roughly 190–192, the callout box itself starts at 184 — **re-confirm exact line numbers before editing, they may have shifted slightly from Phase 9's citation**) | Identical false-negative claim, restated for the diagram audience. | Same replacement as A2 — reasoning IS reattached architecturally, costs 0 tokens measured. Keep the "누적됨 → 폐기" framing as *what the gate check for*, since that framing itself (unlike this specific sentence) is not wrong. | `phase-09/PRB-04-FINDINGS.md` §4 names this file/line-range explicitly as a correction target |
| B3 | 203 (관련 문서 table, "웹 버전" row pointing at a `claude.ai/code/artifact/...` URL) | unchanged, not evidence-related | Not part of this correction; note only if the artifact link itself is dead (not checked — out of scope, no network access used in this research) | Consider re-publishing if Phase 12 substantially edits this file, so the web mirror doesn't diverge from the corrected doc — but this is a nice-to-have, not a requirement. | n/a |

### C. `docs/plan-act-reasoning-design.md`

| # | Lines | Current text | What's wrong | Replacement intent | Artifact |
|---|---|---|---|---|---|
| C1 | 1–10 | `> **상태: 제안. 아직 구현되지 않았다.** v1 마일스톤 범위 밖이며, 채택 전에 §5 의 두 게이트를\n> 반드시 통과해야 한다.` | Stale status badge, and factually the milestone did adopt this (v1.1, not "out of v1 scope" — that line is now confusing since it correctly says v1 but a reader in 2026-09 needs to know v1.1 shipped it). | Update status to "채택됨(v1.1) — §5 의 두 게이트 모두 판정 완료: 게이트①(컨텍스트 누적) 비폐기(토큰 비용 0), 게이트②(A/B) 개선 없음이나 인간이 override 로 keep." Point to `phase-09/GATE-VERDICT.md` for gate ① and `phase-11/AB-RESULTS.md` §11 for gate ②. | ROADMAP Phase 12 criterion 3 |
| C2 | 204 (§7 recommended order, item 1: "게이트① 컨텍스트 누적 측정 ← '누적됨'이면 설계 폐기") | unchanged, no correction needed | Phase 9 explicitly checked this line and found **no correction needed** — it only names a recommended step, doesn't assert a source-inspection conclusion. | No edit. | `phase-09/PRB-04-FINDINGS.md` §4, explicit "recorded for completeness ... not because it is wrong" |
| C3 | 65 | `즉 **\`cline --thinking <아무 값>\` 은 현재 400 으로 실패한다.** \`high\` 만의 문제가 아니다.` | Still true for the **unaliased** path (client sends `--thinking` directly against `flashnext`/`openai/`-prefixed) — but this section doesn't mention that Phase 11's wrappers now actively **refuse** `--thinking` before it would even reach litellm, and that a user bypassing the wrapper and hitting a `hosted_vllm/`-prefixed alias with `--thinking high` gets a different failure (HTTP 500 from the model server, not 400 from litellm — confirmed live, `phase-11/OPEN-ITEMS.md` Open Item 1, case 1a/1c). | Add a note: "Phase 11 의 래퍼는 `--thinking` 을 파싱 단계에서 거부해 이 문제 자체를 만나지 않게 한다(`phase-11/WRAPPER-DESIGN.md` §4). 래퍼 없이 맨손 `cline`으로 `hosted_vllm/` 별칭에 `--thinking high`를 보내면 400이 아니라 모델 서버의 500이 난다(`phase-11/OPEN-ITEMS.md` Open Item 1)." | `phase-11/OPEN-ITEMS.md` Open Item 1; `phase-11/WRAPPER-DESIGN.md` §4 |
| C4 | 120–127 (§L3, the same shell-function sketch as implementation.md's T5) | ```sh\ncline-plan() { CLINE_NO_AUTO_UPDATE=1 cline -p -m flashnext-plan "$@"; }\ncline-act()  { CLINE_NO_AUTO_UPDATE=1 cline    -m flashnext-act  "$@"; }\n``` | Same superseded-sketch problem as A5 — `phase-11/WRAPPER-DESIGN.md` §2 names **both** this file's §L3 and implementation.md's §T5 in the same breath. | Same treatment as A5: replace or wrap-and-label-superseded, point to `phase-11/WRAPPER-DESIGN.md`. | `phase-11/WRAPPER-DESIGN.md` §2 |
| C5 | 8–10 (top-of-file note) | `> **구현 계획: \`docs/plan-act-reasoning-implementation.md\`.**\n> 그 계획은 이 문서의 L1(\`allowed_openai_params\` 통과)을 쓰지 않는다 ...` | Not wrong, still accurate description of the actual-vs-designed divergence (injection over pass-through). No correction needed. | No edit. | n/a |

### D. `docs/cline-config-pins.md`

This file currently documents **four** Phase-1 pins (CFG-04/05/06/07) and nothing from v1.1. USE-04
requires two additions, neither a correction of existing text — this is new content, structured to
match the file's own existing pattern (a "무엇을 고정했는가" table, then a section justifying it,
then evidence).

| # | What's needed | Where | Content, sourced |
|---|---|---|---|
| D1 | A new row (or new sub-table) for the five live aliases, distinguishing **pins** (must not drift) from **measurements** (may drift) | New §, e.g. "## 7. v1.1 별칭 고정 (CFG-11..17)" | **Pins** (the file's existing §1 pattern — value + requirement + evidence command): `flashnext` unchanged (CFG-13), `flashnext-codex` unreachable/never called (unchanged from Phase 1), `flashnext-plan` injects `enable_thinking:true` + `reasoning_effort:medium` (CFG-11), `flashnext-act` injects `enable_thinking:false` (CFG-12), `flashnext-reach-xhigh` injects `reasoning_effort:xhigh`, **verification-only, not a shipped surface** — and its removal is an **open decision**, not yet made (see Open Items below; do not silently drop it a third time — `phase-10/PHASE-10-FINDINGS.md` §5 and `phase-11/AB-RESULTS.md` §10 both explicitly punt this to "Phase 11/12"). All five live under `hosted_vllm/` prefix except `flashnext`/`flashnext-codex` which stay `openai/` (CFG-13 preserves them byte-identical — `flashnext` at line 22, `flashnext-codex` at lines 29–33 of the live config, per `.planning/REQUIREMENTS.md`'s own note). Six deprecated `qwen-*` aliases (`qwen-local`, `qwen-35b`, `qwen-122b`, `qwen-122b-claude`, `qwen-35b-claude`, `qwen-122b-codex`) were removed (CFG-17) — name them as **historical**, not currently reachable. | `phase-10/ALIAS-DESIGN.md` §1–§2; `phase-10/CFG-13-EVIDENCE.md` Checks 1–4; `phase-10/PHASE-10-FINDINGS.md` §1–§2 |
| D2 | `--thinking` → 400 fact, **plus** the wrapper-refusal fact and the CFG-11 premise correction | Same new section, or a note near the existing §2 flag-surface table | State explicitly, per USE-04's own text: "**`--thinking` 이 litellm 을 거치면 400 이 된다**(`openai/`-접두사 별칭에서; `hosted_vllm/` 접두사에서는 가치 검증이 있어 잘못된 값은 500)." **Then add the 2026-09-02 correction that REQUIREMENTS.md already carries**: at cline 3.0.53, `--thinking` was believed absent from the CLI; **at the now-installed 3.0.60+, `--thinking <level>` is a real flag** (`none|low|medium|high|xhigh`) that, if a user passes it directly to the raw binary, **overrides** the alias's injected value (litellm merges client kwargs after `litellm_params`). This is exactly why the wrapper refuses it outright rather than allowing it through — cite `phase-11/WRAPPER-DESIGN.md` §3/§4 for the deny-by-default rationale and the exact refusal message. | `.planning/REQUIREMENTS.md` CFG-11's 2026-09-02 correction (verbatim quoted in Open Items §3); `phase-11/WRAPPER-DESIGN.md` §4 |
| D3 | Pin-vs-measurement distinction, stated once, explicitly | Same new section, opening paragraph | Follow the file's own existing convention (§1's table already separates "고정" from "요구사항"/"증거 명령"). State: **pins** = alias names and their injected parameter values (`flashnext-plan` always injects `enable_thinking:true`+`reasoning_effort:medium`; this must not silently change) and the `hosted_vllm/` vs `openai/` prefix choice (changing it reopens the 400 problem). **Measurements, not pins** = the absolute `prompt_tokens` values (23/21/51/63 → 13/11/41/53, cause unexplained, **already drifted once**) and the wire `max_tokens` value (2048 → 20983, now known to be dynamic — see §6 below). Judge future drift on **deltas** (medium −2, low +28, xhigh +40 — bit-for-bit stable across three independent measurement rounds per `phase-09/PRB-03-ORACLE.md` §2) and on `model`/`contextWindow` in `providers.json` (per the CFG-05-driven correction already in `.planning/STATE.md`), never on file sha256 or absolute token counts. | `phase-09/PRB-03-ORACLE.md` §2/§5; `.planning/STATE.md` 🔴 section (2026-09-01, the sha256→model/contextWindow correction) |
| D4 | (Optional, but worth a line) `cline-plan`/`cline-act` wrapper existence itself, cross-referenced from here | A one-line pointer in the new section | "래퍼 사용법은 `docs/manual/01-cli.md` §새 절; 래퍼의 정확한 계약은 `phase-11/WRAPPER-DESIGN.md`." Keep this file's job (pins) separate from 01-cli.md's job (usage). | n/a |
| D5 | (Note, not an edit) version-drift interaction | — | This file's §5/§6 describe Phase-1-era CLI version pinning (3.0.53) and a `check_versions.sh` scan that "공허하게 통과" because no launchd plists existed yet at capture time (2026-08-29). By now plists exist and `cline` has drifted to 3.0.60/3.0.61 anyway (CFG-05 unresolved). **No correction is strictly required here** since §8 of `docs/manual/01-cli.md` already owns the "verify the real version, don't trust this pin" warning — but Phase 12 should not add anything to `cline-config-pins.md` that implies the 3.0.53 pin is currently honored. Cross-check against 01-cli.md's own GAP-CLINE-VERSION section rather than duplicating it. | `docs/manual/01-cli.md` §8 (already correct); `.planning/STATE.md` 🔴 "신규 발견" section |

### E. `docs/manual/01-cli.md`

USE-04 criterion 1 requires this file to document `cline-plan`/`cline-act` usage. It currently
does not mention them at all (confirmed — no hits for "cline-plan"/"cline-act"/"flashnext" anywhere
in the file). This is **new content**, not a correction, but there are two adjacent sections whose
existing claims interact with it and should be checked for consistency once the new section lands.

| # | Lines | Current text | Interaction / what's needed | Artifact |
|---|---|---|---|---|
| E1 | 98–108 (§6 "Plan/Act") | `\`--mode <act|plan>\`(기본값 \`act\`)은 설치된 바이너리 안에 실재하는 CLI 옵션이며, 내부 5-모드\ntool-permission 표는 act 와 plan 이 \`enableEditor\` 값 하나만 다르다.\n\n**⚠️ [GAP-PLANMODE]** 이 프로젝트가 실제로 쓰는 헤드리스 원샷 커맨드가 \`--mode\` 를 그대로\n지원하는지는 **미확인**이다 ...` | This section is about a **different flag name** (`--mode <act|plan>`, found by a Phase 8 `strings` scan at 3.0.53) than the one Phase 11 actually exercises (`-p`/`--plan`, confirmed live at 3.0.60, and used by `phase-11/cline-plan`). It is unclear from the evidence gathered whether these are the same underlying feature exposed two ways, or whether `--mode` was dead/unregistered code. **Do not silently merge these under one flag name.** Add a new subsection (e.g. §6a) documenting `cline-plan`/`cline-act` as a **distinct, separate mechanism** from the headless one-shot `phase-04/run_headless.sh`'s own unresolved `--mode` question — GAP-PLANMODE is about `run_headless.sh`, not about `phase-11/cline-plan`, and the two must not be conflated. State plainly: `phase-11/cline-plan`/`cline-act` are interactive-shape wrappers around the raw `cline` binary using `-p`/no-flag + `-m <alias>`; they are a different tool from `phase-04/run_headless.sh`, which remains act-mode-only per §6's existing GAP-PLANMODE hedge (unchanged, still correct — leave it as is). | `phase-11/WRAPPER-DESIGN.md` §5 (what `-p` does and doesn't); `.planning/milestones/v1-phases/08-korean-user-manual/08-RESEARCH.md` §A6b-6 (origin of the `--mode` citation, for anyone reconciling later) |
| E2 | New section content (usage) | — | Add: the two commands (`phase-11/cline-plan [-t|--timeout] [-c|--cwd] [--json] [--] <prompt>`, same for `cline-act`), their exit-code contract (0..N=cline's own, 2=refused arg/nothing invoked, 3=pre-run guard failed/nothing invoked, 4=post-run guard failed — **cline itself may have exited 0**), and — critically, per the "what must not be claimed" list below — that they **write to `providers.json`** every call (contained to a scratch copy as of commit `017c65e`, today, "hours old, not battle-tested" per `AB-RESULTS.md` §11's own words) and **refuse** `--thinking`/`-m`/`-P`/every flag outside `{-t,-c,--json,--}` by deny-by-default, not a blocklist. Quote the refusal message verbatim from `phase-11/WRAPPER-DESIGN.md` §4. | `phase-11/WRAPPER-DESIGN.md` §1, §4, §7 (full contract + honest limitations list — copy from there, don't re-derive) |
| E3 | New content (default alias state) | — | State that `cline-plan` targets `flashnext-plan` (medium reasoning) and this was **kept, not reverted**, per a human override — **not** because the A/B found an accuracy benefit (it did not: no measurable difference, p=0.563) — and cite the actual reason (the `providers.json` side-effect risk became containable). This directly serves ROADMAP criterion 1's "왜" requirement and prevents the overclaim in §6 below. | `phase-11/AB-RESULTS.md` §11 (subject to the in-flight caveat — see Open Items) |
| E4 | 121–136 (§8 GAP-CLINE-VERSION) | unchanged, still accurate — already hedges correctly ("don't trust the 3.0.53 pin, check the real version, don't call `cline --version` directly") | No correction needed. If anything, the new §6a should cross-reference this section rather than repeat the version-checking instructions. | n/a |

### F. `docs/32k-compaction-policy.md` — precedent to follow, and one live falsification found

**This file's own §1–§9 structure is the precedent Phase 12 should copy for the design docs above.**
It shows exactly the pattern needed: a dated correction banner at the very top (`> **2026-08-30 전면
정정.**`), a corrected §1 conclusion, a §7 "이 정정이 바꾸는 것" before/after table, an §8 "미해결"
section stating what's still open, and a collapsed `<details>` §9 appendix preserving the entire
original (wrong) write-up verbatim, labelled "부록 — 정정 전 기록," so nothing is deleted, only
superseded and clearly marked. **Apply this same shape to
`docs/plan-act-reasoning-{design,implementation,diagrams}.md`**: banner correction at top, §7-style
before/after table, superseded content preserved in a collapsed appendix rather than deleted (this
directly answers research question 4).

| # | Lines | Current text | What's wrong | Notes |
|---|---|---|---|---|
| F1 | §4 (around line 69), and cross-referenced from §7's table | `서버 예산은 \`prompt_tokens + max_tokens ≤ 32768\`, \`max_tokens\` 실측값은 \`2048\`.` | `max_tokens` is **no longer 2048** and, more importantly, is **no longer fixed at all**. `phase-11/OPEN-ITEMS.md` Open Item 2 measured **20983** at cline 3.0.60/3.0.61 for an equivalent prompt, and `phase-11/AB-PROTOCOL.md` §3 found across 278 server-log samples that `cline` sizes the completion budget dynamically so `prompt_tokens + max_tokens` lands near **26,100** (`contextWindow × 0.9` — the same number this very document calls the compaction trigger), not near 32,768. This directly changes the §4 overshoot arithmetic (`trigger + 3,100 + max_tokens < MAX_KV_SIZE`) — the "+max_tokens" term is no longer a small, roughly-fixed addend. | **Not in USE-04/USE-05's named file list.** This is a genuine v1.1-era finding that falsifies a v1-era (CFG-03) claim this file and `docs/cline-max-tokens-findings.md` both assert. Flagged as an explicit scope decision for the plan (see §6 below), not silently included or silently dropped. |
| F2 | `docs/cline-max-tokens-findings.md` (CFG-03), whole document | asserts `OBSERVED_MAX = 2048` as *the* wire value, cline-version-independent in its own framing | Same falsification as F1, at the source document. | Same scope flag as F1 — if Phase 12 decides to fix F1, it should fix this file too (they're the same claim, two places), rather than fixing one and leaving the other. |
| F3 | `docs/manual/04-32k-operations.md` §3 (line 74: `trigger + 3,100 + max_tokens < MAX_KV_SIZE`) | states the formula generically, no literal `2048` | Not directly false as written (no hardcoded number to falsify), but its implicit assumption (that `max_tokens` is a small, near-fixed addend you can budget around) is now wrong. | Lower priority than F1/F2 — the formula's *shape* survives, only the mental model behind it needs updating if F1/F2 are touched. |

### G. Other files checked, found not to need edits

- `docs/manual/00-getting-started.md`, `02-kanban.md`, `03-mobile.md` — no mention of aliases,
  `reasoning_effort`, `enable_thinking`, or `--thinking`. No v1.1-driven changes needed.
- `docs/manual/04-32k-operations.md` §1–§2, §5, §7 — describes compaction/overflow/terminal-failure
  behavior unrelated to Plan/Act; unaffected by v1.1 except the max_tokens formula noted in F3.
- `docs/headless-wrapper.md`, `docs/services.md`, `docs/network-exposure.md`,
  `docs/sandbox-whitelist.md`, `docs/infra-hardening.md`, `docs/cline-bench.md` — checked for
  mentions of models/aliases/thinking; none found relevant to USE-04/USE-05's scope.

---

## What Must NOT Be Claimed (research question 6)

A documentation phase writing "up" from raw findings naturally drifts toward overclaiming. Concrete
list of overclaims to actively guard against while writing:

1. **"The A/B showed thinking helps."** It did not. On the equal-N slice, both arms scored
   identically (25/30 per `AB-RESULTS.md` §11's own restatement of §4's figures on the equal-N
   subset). The permutation test returned p=0.563 — indistinguishable from chance. The pre-registered
   rule's mechanical output was `revert`. Any sentence implying the reasoning arm performed better,
   or that `medium` reasoning was validated as beneficial, is false. State the decision as: no
   accuracy benefit found; kept anyway, for an unrelated, newly-resolved safety reason (the
   `providers.json` side effect became containable, not merely detectable).
2. **"The A/B was fully run."** It was not — 66 of 88 authorised cells; task 08 (both
   bug-localisation tasks) and arm B (the prefix control) were never attempted; task 07 ran N=1 for
   arm C vs N=5 for arm A. Don't imply full coverage.
3. **"`flashnext-reach-xhigh` reach-proves the shipped alias."** It doesn't and was never meant to —
   it proves the *mechanism* (`hosted_vllm/` injection reaches the model) with a wide margin (+40,
   `phase-10/REACH-PROOF.md` §3a). The shipped `flashnext-plan`'s own margin is −2, explicitly
   labelled the weaker, corroborating proof in `phase-10/PHASE-10-FINDINGS.md` §4.1 — don't let a
   summary flatten "reach was proven with a wide margin (on a different alias)" into "the shipped
   alias's reach was proven with a wide margin."
4. **"The `providers.json` side effect is fixed / can't happen anymore."** As of today, it is
   *contained* (scratch-copy redirection via `CLINE_PROVIDER_SETTINGS_PATH`, commit `017c65e`), not
   eliminated at the source, and the containment itself is, in `AB-RESULTS.md` §11's own words,
   "hours old, not battle-tested." Don't write "fixed" or "resolved" — write "contained, as of
   2026-09-10, pending longer real-world exposure."
5. **"Cline doesn't attach reasoning to context" / "reasoning accumulation was ruled out."** False,
   per PRB-04-FINDINGS.md §3 — it does attach it, architecturally. What's true is that it costs zero
   measured tokens on this exact stack. Keep these two claims separate; conflating them is the exact
   error being corrected (item A2 above).
6. **"`-m` is a call-scoped override with no persistence."** False as of the `qanda/004` correction —
   `cline` writes `providers.json`'s `model` field unconditionally on every invocation
   (`main.ts:1122` at 3.0.61, `:1119` at 3.0.53, unconditional, no version dependency — confirmed
   identical across `git diff cli-v3.0.53 cli-v3.0.61 -- apps/cli/src/main.ts`). This was originally
   misread from `session-runtime.ts` (a connector's *read* path, not the CLI's own *write* path) — a
   scoping error, not version drift. Any doc still citing "-m 은 영속화하지 않는다" is wrong.
7. **"`--thinking` doesn't exist in this project's `cline`."** It does, as of 3.0.60+, and a user
   invoking the raw binary (bypassing the wrapper) can trigger it — this is exactly why the wrapper
   refuses it. Don't imply the flag is absent; the correct claim is "the wrapper refuses it before it
   reaches litellm."
8. **Absolute `prompt_tokens` values as portable facts.** They drifted once already (23/21/51/63 →
   13/11/41/53), cause unexplained. Any table in the corrected docs should present these as deltas
   ("−2 / +28 / +40 from unspecified") with the absolute values labelled explicitly as
   session-specific measurements, not universal constants.
9. **The wrapper "prevents" mode/alias mismatch as a blanket claim without the honest limitations.**
   `phase-11/WRAPPER-DESIGN.md` §7 lists real, deliberate gaps (dash-prefixed prompts refused
   entirely, ~15 other real `cline` flags unreachable through the wrapper by design, config-guard
   *aborts* rather than *heals*). If USE-04's usage section claims the wrapper "makes misuse
   impossible," soften it to what's actually true: it refuses a wide, extensible class of dangerous
   arguments and detects (now also contains) the one side effect it can't prevent at the source.

---

## Design-doc handling precedent (research question 4, answered)

Follow `docs/32k-compaction-policy.md`'s exact shape (confirmed by reading its full 350 lines):

1. A short, dated correction banner immediately under the title (`> **YYYY-MM-DD 정정.**`), stating
   in one sentence what changed and pointing to where the current content starts.
2. The living conclusion at the top (§1), rewritten to be currently true.
3. A "이 정정이 바꾸는 것" table (its own §7) — one row per downstream artifact/phase affected — as
   the single place a future reader checks "what actually changed."
4. An explicit "미해결" section (§8) naming what's still open, rather than implying full closure.
5. The entire pre-correction original text preserved verbatim inside a collapsed `<details>` block
   at the bottom, explicitly labelled as a historical record of "the evidence for what happens when
   you get the config location wrong" (or the equivalent framing for the reasoning docs: "the
   evidence for what a false-negative source reading looked like, and why the gate still passed"),
   never deleted.

This is directly applicable to `docs/plan-act-reasoning-design.md`/`-implementation.md`/`-diagrams.md`:
banner at top declaring "구현됨, A/B 판정 override-keep, 2026-09-XX", corrected status/§1/§T2 content,
a new "이 정정이 바꾸는 것" table (rows: status badge, §T2/§Gate① source claim, §L3/§T5 wrapper
sketch, §T6/§Gate② outcome), an explicit "여전히 미해결" section (Phase 11's own open items:
`flashnext-reach-xhigh` disposition, containment's newness, version-drift risk), and the original
"제안/계획" content preserved in a collapsed appendix rather than deleted.

---

## Open Items (the plan must resolve these, not this document)

1. **Phase 11 is not closed.** `phase-11/AB-RESULTS.md` is `git status`-modified (uncommitted) as of
   this research session; `11-07-PLAN.md` has no `11-07-SUMMARY.md`; `.planning/REQUIREMENTS.md`
   still shows USE-01/02/03 as "Pending". The content I read (§11's ratified `keep` decision, dated
   today) is internally coherent and directly matches the milestone brief's description — but the
   plan and executor **must re-read `phase-11/AB-RESULTS.md`, `phase-11/OPEN-ITEMS.md`, and
   `phase-11/PHASE-11-FINDINGS.md` (which does not exist yet as of this research) at execution time**,
   not rely on this snapshot, per this phase's own instructions. If `PHASE-11-FINDINGS.md` exists by
   execution time, it likely restates/finalizes what `AB-RESULTS.md` §11 and `OPEN-ITEMS.md` already
   say — treat it as the authoritative summary if present, cross-check against the two source files
   if not.
2. **`flashnext-reach-xhigh`'s fate is an explicit, twice-deferred open decision**, not yet made by
   anyone. `phase-10/PHASE-10-FINDINGS.md` §5 offered it for removal and the reviewer declined to
   decide then; `phase-11/AB-RESULTS.md` §10 checked it's still live and re-punted to "Phase 12."
   Phase 12's plan should either (a) make this decision explicitly (keep as documented
   verification-only tooling, or remove as dead config) and document it in
   `docs/cline-config-pins.md`, or (b) explicitly re-defer it one more time with a stated owner and
   reason — but must not silently ignore it a third time.
3. **Scope question: does Phase 12 touch `howto/` and `qanda/`?** Not named by USE-04/USE-05. Found
   stale: `howto/fast-and-deep-mode.md` (written mid-Phase-9/10, describes the alias mechanism and
   the wrapper as "Phase 10 진행 중"/"Phase 11 예정" — both now shipped) and
   `howto/thinking-and-reasoning-effort.md` line 209–211 ("Cline 의 Plan/Act 모드가 이 설정과
   연동되나? 현재는 아니다... 그 둘을 잇는 것이 v1.1 의 목표다" — now false, they are linked, that's
   what shipped). Also stale: `qanda/001-testing-plan-act-with-cline-cli.md` and
   `qanda/003-how-the-wrappers-work.md`, both dated 2026-09-10 but written **before** commit
   `017c65e` (the containment fix) and before `AB-RESULTS.md` §11's ratified decision — they still
   say "래퍼는 오염을 막지 못한다, 사후 탐지만 한다" and "래퍼의 기본 별칭은 아직 확정 전이다,"
   both now superseded by the same day's later work. `qanda/004` shows this project's own convention
   for handling this (self-correct in place, with a `🔴 이 문서의 이전 판이 틀렸습니다` banner) — if
   Phase 12's scope is extended to these files, follow that convention rather than silently rewriting.
   **Recommendation: raise this explicitly with whoever scopes the plan** rather than assume either
   direction.
4. **Discrepancy: "four `howto/` docs" vs. three found.** The orchestrating context states four
   `howto/` docs were written this milestone; only three `.md` files exist under `howto/`
   (`fast-and-deep-mode.md`, `thinking-and-reasoning-effort.md`, `measuring-thinking-at-8000.md`),
   plus a `README.md` that itself lists exactly these three. If a fourth was intended, it does not
   exist on disk as of this research — the plan should either treat this as three (matching disk
   reality) or ask whoever wrote the brief which fourth doc was meant.
5. **The `--mode <act|plan>` vs. `-p`/`--plan` reconciliation (§E1 above) is unresolved by this
   research.** It's unclear whether Phase 8's `strings`-scanned `--mode <act|plan>` commander literal
   and Phase 11's live-confirmed `-p`/`--plan` flag are the same feature under two names, dead code
   vs. live code, or something else. This doesn't block writing the new `cline-plan`/`cline-act`
   usage section (which should describe the actually-used `-p`/`-m` mechanism), but `01-cli.md` §6's
   existing `--mode` paragraph should not be silently merged with or contradicted by the new section
   without someone actually resolving this — flagged as a question for the plan/executor, not
   resolved here.
6. **`cline-src`'s tag moved.** All of Phase 9's source citations (`ai-sdk.ts:284-289`,
   `agent-message-codec.ts:231/237`, `message-builder.ts:1213-1214`) were read at `cli-v3.0.53`,
   which is **no longer the checked-out working tree** (moved to `cli-v3.0.61` per `qanda/004` §7).
   These citations remain valid and reachable via `git show cli-v3.0.53:<path>` (the tag itself was
   preserved, only the working-tree checkout moved) — when Phase 12 writes the corrected text, cite
   the tag explicitly (`cli-v3.0.53`, via `git show`) rather than implying it's what's currently
   checked out, to avoid a future reader trying to `grep` the live working tree and finding nothing
   (as literally happened once already this milestone, per `qanda/004`'s own "이전 판이 틀렸습니다"
   correction about `strings`-scanning an obfuscated bundle).
7. **F1/F2 (`max_tokens` dynamism) scope decision**, restated from §F above: this is a real,
   evidenced falsification of a v1-era doc claim, discovered during this research, outside
   USE-04/USE-05's literal file list. Needs an explicit in/out decision from the plan, not silent
   handling either way.
8. **Live state check (informational, not a blocker):** as of this research session,
   `~/.cline/data/settings/providers.json`'s `openai-compatible.settings.model` is currently
   `"flashnext"` and `contextWindow` is `29000` (`verify_config.sh` passes) — i.e., the file is
   currently in its pinned, correct state. This is a point-in-time fact, not a pin — the next `cline
   -m` call (including from the wrappers, pre-containment or on any code path the containment
   doesn't cover) will change `model` again. Don't write documentation implying the file "stays"
   correct; it is repeatedly corrected, not stable.

---

## Sources

### Primary (HIGH confidence — read directly from disk, 2026-09-10)
- `docs/manual/01-cli.md`, `docs/cline-config-pins.md`, `docs/plan-act-reasoning-{design,implementation,diagrams}.md`, `docs/32k-compaction-policy.md`, `docs/cline-max-tokens-findings.md`, `docs/manual/{00,02,03,04}-*.md` (full reads)
- `.planning/ROADMAP.md` §Phase 12, `.planning/REQUIREMENTS.md` (USE-04/05, CFG-11's 2026-09-02 correction, requirement-tracking tables), `.planning/STATE.md` (full read)
- `phase-09/GATE-VERDICT.md` (partial), `phase-09/PRB-03-ORACLE.md`, `phase-09/PRB-04-FINDINGS.md` (full, including its §4 Phase-12 handoff)
- `phase-10/PHASE-10-FINDINGS.md` (full), `phase-10/ALIAS-DESIGN.md` (§1–§2), `phase-10/REACH-PROOF.md` (§1–§3), `phase-10/CFG-13-EVIDENCE.md` (Check 1 excerpts)
- `phase-11/WRAPPER-DESIGN.md` (full), `phase-11/OPEN-ITEMS.md` (full), `phase-11/AB-PROTOCOL.md` (§1–§3), `phase-11/AB-RESULTS.md` (full, including uncommitted §11), `phase-11/wrapper.env`, `phase-11/wrapper_common.sh` (excerpts), `phase-11/cline-plan`, `phase-11/cline-act`
- `qanda/001`, `002`, `003`, `004` (full), `qanda/README.md`
- `howto/README.md`, `howto/thinking-and-reasoning-effort.md`, `howto/fast-and-deep-mode.md` (full)
- Live checks: `bash phase-01/config/verify_config.sh` (exit 0, today), `~/.cline/data/settings/providers.json` (read-only cat), `git log --oneline -15` and `git status` in the repo root

### Secondary (MEDIUM confidence)
- `.planning/milestones/v1-phases/08-korean-user-manual/08-RESEARCH.md` (grep excerpts only, for the `--mode` flag's origin)
- `docs/cline-bench.md` (grep excerpts, for the "0/N tasks passed" figure's exact denominator)

### Not yet available (must be re-checked at execution time)
- `phase-11/PHASE-11-FINDINGS.md` — does not exist yet as of this research
- Final committed state of `phase-11/AB-RESULTS.md` and `.planning/REQUIREMENTS.md`'s USE-01/02/03 rows

## Metadata

**Confidence breakdown:**
- Line-level inventory (§A–§F): HIGH — every "current text" cell was read from disk today, every
  replacement cites a specific artifact.
- Canonical-source question: HIGH for docs/ vs howto/ vs qanda/'s *intended* roles (stated in
  `qanda/README.md` and `howto/README.md` themselves); MEDIUM for whether Phase 12 should actually
  touch howto/qanda (genuinely unscoped by USE-04/USE-05, flagged rather than decided).
- Phase 11 closure state: MEDIUM — content read is coherent and matches the milestone brief, but is
  explicitly still uncommitted/in-flight per this phase's own instructions.
- F1/F2 (`max_tokens` dynamism): HIGH that it's true and falsifies existing text; LOW confidence on
  whether it's in scope for this phase.

**Research date:** 2026-09-10
**Valid until:** Re-check before execution if more than a few days pass, or immediately if
`phase-11/PHASE-11-FINDINGS.md` appears, `phase-11/AB-RESULTS.md` is committed with further changes,
or `.planning/REQUIREMENTS.md`'s USE-01/02/03 rows flip to Complete (any of these could add or change
citations this document currently gives as `phase-11/OPEN-ITEMS.md` §11's still-uncommitted content).
