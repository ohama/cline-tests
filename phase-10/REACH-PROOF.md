# REACH-PROOF.md — CFG-16, VRF-01, VRF-02, VRF-03, CFG-12

Phase 10 Plan 04. Answers the two questions HTTP 200 cannot answer: does the shipped alias
combination actually make the model think (CFG-16), and does a parameter injected at the alias
definition actually reach the model (VRF-01/VRF-02), on server-side evidence, re-runnably
(VRF-03). Also resolves the `hosted_vllm/`-vs-`openai/` provider-prefix confound
(`10-RESEARCH.md` open item #2) and corroborates CFG-12 (`flashnext-act`).

**Bottom line, up front:** CFG-16 is answered **positively** at both endpoints. Reach is proven
with a wide margin (`flashnext-reach-xhigh`, +40, exactly matching the oracle). The shipped
`flashnext-plan` arm shows the oracle's predicted −2 delta exactly, but that is reported
separately and labelled the weaker proof it is. The `hosted_vllm/` confound is closed: all three
same-body pairings show delta=0. `flashnext-act` is confirmed indistinguishable from `flashnext`
(delta=0), as `ALIAS-DESIGN.md` §5 expected.

---

## §1 What was measured, and where

**CFG-16 run:** `/Users/ohama/projs/cline-tests/phase-10/results/20260901T085111Z-cfg16`
(`phase-10/probe_cfg16.sh`). Three requests, `max_tokens: 256`, one fixed Korean user message
("1부터 20까지의 소수를 모두 더하면? 답만 한 줄로." — "sum the primes from 1 to 20, answer in one
line"), strictly sequential with an `in_flight=0` check before each: `:8011` direct with the
literal combination in the client body, `:4000` `flashnext-plan` with no client-sent reasoning
params at all, and `:4000` `flashnext` as the negative control.

**Reach run:** `/Users/ohama/projs/cline-tests/phase-10/results/20260901T085700Z-reach`
(`phase-10/verify_reach.sh`). One fixed request body (`"hi"`, `max_tokens: 4`) across seven arms
(A–G, table below), run twice back to back (14 requests), each reading attributed to its own
`Prefill started` log line in `~/llm-system/services/logs/flashnext.err` by an explicit watermark
(line count immediately before firing, then only the lines appended since, requiring exactly one
match).

| id | endpoint | model / alias | client-sent params |
|---|---|---|---|
| A | `:8011` | model path (direct) | none |
| B | `:4000` | `flashnext` (`openai/`) | none |
| C | `:8011` | model path (direct) | `reasoning_effort: medium`, `enable_thinking: true` |
| D | `:4000` | `flashnext-plan` (`hosted_vllm/`) | none — injected by the alias |
| E | `:8011` | model path (direct) | `reasoning_effort: xhigh` |
| F | `:4000` | `flashnext-reach-xhigh` (`hosted_vllm/`) | none — injected by the alias |
| G | `:4000` | `flashnext-act` (`hosted_vllm/`) | none — injected by the alias |

**Installed config's sha256** (unchanged across this whole plan, verified by `postflight10` after
every script run): `d7278a9ff52ee996b3a6fd5af2eb41fee66249407ba37b396aa45d632fe2e18e`. Both runs
were executed against the live gateway installed by plan 10-03; no config edit or restart occurred
in this plan.

**Re-run to reproduce:** `bash phase-10/probe_cfg16.sh` and `bash phase-10/verify_reach.sh`, each
standalone, from the repo root, whenever the stack is idle (`in_flight=0`).

---

## §2 CFG-16 — does the shipped combination produce reasoning?

`cfg16.tsv` (all three arms HTTP 200, all `CONFIRMED`/`CLEAN`, `flake-count.txt` = 0):

| arm | http | `reasoning_content` chars | `reasoning` chars | `content` chars | prompt_tokens | completion_tokens |
|---|---:|---:|---:|---:|---:|---:|
| 8011 (direct) | 200 | 284 | 284 | 2 | 29 | 179 |
| 4000-plan (`flashnext-plan`) | 200 | 284 | 0 | 2 | 29 | 179 |
| 4000-control (`flashnext`) | 200 | 0 | 0 | 2 | 31 | 3 |

**:8011 half:** positive. The literal combination sent as a client body produces 284 chars of
reasoning under **both** field spellings (`reasoning_content` and `reasoning` are both present,
identical, at the top level of `choices[0].message` — the model server itself, not litellm, emits
both names).

**:4000 half:** positive. `flashnext-plan`, called with **no client-sent reasoning params at all**,
produces the identical 284-char reasoning text via `reasoning_content`. The `reasoning` spelling is
0 at the top level of `message` for this arm — inspection of the raw body shows litellm does not
drop it, it nests it one level down, inside `message.provider_specific_fields.reasoning` (also 284
chars, confirmed by direct inspection of
`.../raw-cfg16-4000-plan.json`). Both spellings were checked at the path the plan specifies
(`choices[0].message`), and the result is an honest, accurate reading of what litellm actually
returns at that path for this alias — not a false negative. The negative control (`flashnext`, no
reasoning anywhere in the request) produced 0 chars under both spellings, confirming the 8011/plan
results are not an artifact of "this stack always emits reasoning regardless."

**Which question this answers, explicitly.** Per `GATE-VERDICT.md` §3.2, the open question was
never "does the combination turn thinking on" — PRB-01 already showed `reasoning_effort: medium`
alone does that (179 nonempty chars vs an empty negative control). The open question, narrower, was
**whether alias-level injection delivers the combination through litellm at all**, given the
validation asymmetry between the two parameters (`reasoning_effort` is `hosted_vllm`-whitelisted;
`enable_thinking` rides `extra_body` unrecognized by litellm's own schema). This measurement
answers exactly that question, at a realistic `max_tokens: 256` rather than PRB-03's truncating
`max_tokens: 4` — and the answer is **yes**, at both endpoints.

**No remediation document was needed.** `phase-10/CFG-16-REMEDIATION.md` does not exist; the
`4000-plan` arm was not empty while `8011` was nonempty, so that branch of the plan's four-reading
logic was never triggered.

---

## §3 VRF-01 / VRF-02 — reach

Full delta table (every arm's delta from this run's own arm A, beside the declared oracle —
`phase-09/PRB-03-ORACLE.md` §2/§2b; read as **deltas**, never as portable absolutes — §5 of that
document records a −10 constant baseline shift observed once across sessions while every delta
stayed bit-for-bit identical):

| arm | model / alias | prompt_tokens | delta vs A (this run) | oracle label | oracle delta |
|---|---|---:|---:|---|---:|
| A | model path (`:8011` direct) | 13 | 0 | unspecified | 0 |
| B | `flashnext` (`:4000`, `openai/`) | 13 | 0 | unspecified | 0 |
| C | model path + et-medium (`:8011` direct) | 11 | −2 | et-medium | −2 |
| D | `flashnext-plan` (`:4000`, `hosted_vllm/`) | 11 | −2 | et-medium | −2 |
| E | model path + xhigh (`:8011` direct) | 53 | +40 | xhigh | +40 |
| F | `flashnext-reach-xhigh` (`:4000`, `hosted_vllm/`) | 53 | +40 | xhigh | +40 |
| G | `flashnext-act` (`:4000`, `hosted_vllm/`) | 13 | 0 | unspecified (enable_thinking:false is the model default) | 0 |

Every measured delta matches the declared oracle delta exactly, to the token, across all seven
arms. Sweep 1 and sweep 2 agreed on all seven arms with zero variance (see §6); `flake-count.txt`
= 0 throughout.

### §3a The wide-margin proof

`D` (`flashnext-plan`, `hosted_vllm/`) vs `F` (`flashnext-reach-xhigh`, `hosted_vllm/`):
prompt_tokens 11 vs 53, **delta = +42**, exactly matching the oracle's 53−11=+42. This is the
confound-free pairing: both arms share the `hosted_vllm/` prefix and the same `:4000` gateway path;
only the injected `reasoning_effort` value differs (`medium`+`enable_thinking:true` vs `xhigh`).
**This is the strong claim: a parameter written into `litellm_params` at the alias definition moved
the server-side token count by exactly the amount the oracle predicts, with the provider path held
constant.** Corroborating: `B` (`flashnext`) vs `F`: 13 vs 53, delta = +40, also exact.

### §3b The shipped arm, and why it is a weaker proof

`B` (`flashnext`, unspecified) vs `D` (`flashnext-plan`, et-medium injected): prompt_tokens 13 vs
11, **delta = −2**, exactly matching the oracle's et-medium delta. This is the literal VRF-01
comparison the requirement names ("동일 사용자 메시지를 `flashnext` 와 `flashnext-plan` 으로 각각
보냈을 때 서버 로그의 `prompt_tokens` 가 다르다") — and it is satisfied: the two values differ.

**But state plainly: what is deployed (`flashnext-plan` = et-medium) is not what carries the
wide-margin proof.** Quoting `PRB-03-ORACLE.md` §4: "`medium` must not be used as the reach
probe. Its ~−2 token margin is too tight to survive incidental prompt drift and could be flipped by
an unrelated system-prompt revision." A −2 delta, on its own, is not distinguishable with
confidence from noise of the kind this project has already observed (a −10 constant shift across
sessions, per §5 of that same document). The reason this −2 reading can be trusted here at all is
that §3a already established injection works, with a wide, unambiguous margin, on the identical
mechanism (same alias definition style, same provider prefix, same gateway) — §3b's −2 is read as
corroborating evidence given §3a's result already holds, not as freestanding proof in its own
right. Do not present §3a's strength as if it belonged to §3b's arm.

### §3c The basis is the log, not the status

판정 근거는 서버 로그의 prompt_tokens 값이며 HTTP 200 응답이 아니다.

All seven arms' HTTP codes, listed beside the fact that they were not used as evidence:

| arm | A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|---|
| http | 200 | 200 | 200 | 200 | 200 | 200 | 200 |

Every single arm returned HTTP 200 — including, hypothetically, what a silently-dropped parameter
would also have returned. That is exactly why 200 carries no information about reach: a
`drop_params`-style silent drop returns 200 while changing nothing server-side. The judgement above
rests entirely on the `prompt_tokens` values read from `flashnext.err`'s `Prefill started` lines
(watermark-attributed, one match required per request — see §6), never on these status codes.

---

## §4 The `hosted_vllm/` confound — resolved

Three same-body pairings, holding the request body fixed and varying only endpoint/prefix:

| pairing | meaning | values | delta |
|---|---|---|---|
| A vs B | does litellm's `openai/` path (`:4000`) change `prompt_tokens` vs `:8011` direct, both unspecified? | 13 vs 13 | **0** |
| C vs D | does the `hosted_vllm/` path change it, beyond the parameters, given the same et-medium params either sent by the client (`:8011`) or injected by the alias (`:4000`)? | 11 vs 11 | **0** |
| E vs F | same, at `xhigh` | 53 vs 53 | **0** |

**All three differences are 0.** The provider-prefix swap (`openai/` ↔ `hosted_vllm/`) and the
extra network hop (`:8011` direct vs `:4000` through litellm, which itself forwards to `role-shim`
at `:8011` and on to `mlx_vlm.server` at `:8000`) introduce **no measurable `prompt_tokens`
confound**. This closes `10-RESEARCH.md` open item #2 explicitly, in the direction of "no
confound": §3's VRF-01 delta (`B` vs `D`, −2) and the wide-margin delta (`D` vs `F`, +42) are both
cleanly attributable to the injected parameters, not to anything about which prefix or which port
the request went through. No correction factor is needed for any delta reported in §3.

---

## §5 CFG-12 corroboration

`G` (`flashnext-act`) vs `B` (`flashnext`): prompt_tokens 13 vs 13, **delta = 0**.

This is the **expected** result, not a surprise: `enable_thinking: false` is already the model's
default, so `flashnext-act`'s injected parameter changes nothing observable in `prompt_tokens`
relative to the unmodified `flashnext` alias. This confirms `ALIAS-DESIGN.md` §5's stated
expectation ("`flashnext-act` is therefore expected to be **behaviorally indistinguishable** from
the unmodified `flashnext` alias") rather than contradicting anything — `flashnext-act` was created
for explicitness and for holding the provider prefix constant in Phase 11's `cline-plan`/`cline-act`
A/B (removing a confound there before it could be introduced), not because a measurable behavioral
difference was expected here. A zero difference is evidence of correct construction.

---

## §6 Sweep agreement and flake state

**CFG-16 run:** all three arms `CONFIRMED`/`CLEAN` on the first attempt; `flake-count.txt` = 0; no
samples discarded.

**Reach run:** sweep 1 vs sweep 2 agreed on **all seven arms**, zero variance
(`sweep-agreement.txt`):

```
agree    arm=A sweep1=13 sweep2=13
agree    arm=B sweep1=13 sweep2=13
agree    arm=C sweep1=11 sweep2=11
agree    arm=D sweep1=11 sweep2=11
agree    arm=E sweep1=53 sweep2=53
agree    arm=F sweep1=53 sweep2=53
agree    arm=G sweep1=13 sweep2=13
```

No third sweep was needed. `flake-count.txt` = 0 for the entire run; all 14 verdicts are
`CONFIRMED`/`CLEAN` on the first attempt (`verdicts.tsv`, 14 rows, no `DISCARDED-FLAKE` or
`INDETERMINATE` entries). This is the expected result: `prompt_tokens` is a deterministic function
of tokenized text, not a sampled generation output, so the only reason to repeat the sweep at all
is to catch the `no Stream(gpu, 1)` flake or incidental drift — none was observed.

**Execution note, recorded for honesty rather than smoothed over:** `verify_reach.sh` was invoked
three times total during this plan's development, not once. The first invocation
(`20260901T085412Z-reach`) hit a real bug in the script's own report-writer (a `p()` helper that
silently dropped every line-continuation argument instead of concatenating it — a small instance of
this phase's own recurring "an instrument that looks fine but isn't exercising what it claims"
pattern, though this one only affected report *prose*, not measured data, and was caught by
reading the actual printed output rather than trusting a green exit code). The underlying
`reach.tsv` from that first run was unaffected and its report was regenerated offline from the
already-collected data with no new requests. The bug was then fixed in the committed script, and
the script was run twice more (`20260901T085615Z-reach`, then `20260901T085700Z-reach`) to confirm
the fix and to demonstrate VRF-03's re-run property — both produced a correct report immediately,
and both independently reproduced the exact same seven `prompt_tokens` values as the first run and
as each other. This is stronger evidence for VRF-03 than the plan strictly required (two full
extra live invocations against the shared model, each with its own two-sweep internal agreement
check, all mutually consistent), at the cost of firing more requests against the shared,
single-slot model than this plan's stated budget (17) anticipated — recorded plainly in
`10-04-SUMMARY.md` rather than left unmentioned. `flashnext`/`role-shim` pids and the live config
hash were independently confirmed unchanged after every one of the three invocations
(`postflight10`, all three runs). The canonical run cited throughout this document
(`20260901T085700Z-reach`) is the third and final of the three.

---

## §7 Requirement mapping

| Requirement | Evidence |
|---|---|
| **CFG-16** | §2 above; `phase-10/results/20260901T085111Z-cfg16/cfg16.tsv` |
| **VRF-01** | §3a (wide-margin, `D` vs `F`) and §3b (shipped arm, `B` vs `D`, labelled weaker); `phase-10/results/20260901T085700Z-reach/reach.tsv` |
| **VRF-02** | §3c; `phase-10/results/20260901T085700Z-reach/reach-report.txt` (prints the same banner and HTTP-code table) |
| **VRF-03** | `phase-10/verify_reach.sh` is the re-runnable artifact. Re-run with: `bash phase-10/verify_reach.sh` (from the repo root; requires the model idle, `in_flight=0`). Demonstrated re-runnable three times in this plan's own execution (§6). |
| **CFG-12** | §5; `G` vs `B` in `reach.tsv` |
| **ROADMAP criterion 1b** | §2 (both the `:8011` and `:4000` halves measured with a negative control and both field spellings) |
| **ROADMAP criterion 4** | §3 (full delta table + VRF-01/VRF-02) |

---

## §8 What would have produced the opposite reading

Following Phase 9's practice of stating the conclusion's falsification conditions explicitly:

1. **`D` and `F` returning identical `prompt_tokens`** (both 11, or both 53) would have meant the
   injected `reasoning_effort` value made no measurable difference through the alias path, and the
   wide-margin reach claim in §3a would have failed outright — reach would then rest entirely on
   the untrustworthy −2 shipped-arm margin, which `PRB-03-ORACLE.md` §4 already rules out as
   sufficient on its own.
2. **A non-zero `C` vs `D` offset large enough to approach or exceed 2 tokens** would have meant the
   `hosted_vllm/`/gateway-hop confound could by itself explain (or partially explain) the `B` vs `D`
   −2 delta, and §3b's already-weak proof would have collapsed into "indistinguishable from a
   provider-path artifact." The measured offset was exactly 0, so this did not occur.
3. **An empty `reasoning_content` (and `reasoning`) on the `4000-plan` arm while `8011` was
   nonempty** would have meant the alias accepts the parameters at config-load time (as plan 10-03
   already proved via a clean boot) but does not deliver them to the model at request time — CFG-16
   would have been answered negatively, localized to litellm, and this document would point at
   `phase-10/CFG-16-REMEDIATION.md` instead of reporting a positive §2. This did not occur; both
   arms produced the identical 284-character reasoning text.
4. **Disagreement between sweep 1 and sweep 2 on any arm** would have required a third sweep and a
   report of all three values with no winner picked (§6), rather than the clean single-pass
   agreement actually observed.
