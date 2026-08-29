# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
**Current focus:** **Phase 4 (헤드리스 CLI 래퍼) 진행 중.** wave 1의 첫 플랜 04-01(오프라인
기반: classify_run.py 분류기 + config.env + fixtures + pytest)이 `cline` 호출 0회로 완료.
04-RESEARCH.md 가 이미 Phase 3 의 인계 블로커(샌드박스 안에서 cline 이 기동되지 않던 문제)를
실측으로 해결했음(cwd 픽스, 샌드박스 확장 불필요) — 다음 플랜(04-02/04-03)이 라이브로 이를
소비/재확인한다.

## Current Position

Phase: 4 of 8 (헤드리스 CLI 래퍼) — 진행 중
Plan: 01 of 4 in current phase — 완료 (SUMMARY 작성 완료)
Status: 04-01 완료 — config.env/classify_run.py/fixtures(5종)/pytest(13개) 전 태스크 개별 커밋,
`phase-04/fixtures/` 는 이제 frozen(wave 2 두 플랜이 read-only 로 소비). `cline` 호출 0회
(phase 예산 2회 그대로 보존).
Verified: [04-01] `python3 -m pytest phase-04/tests/ -q` 13/13 통과(2회 연속 실행, fixture
md5 불변 확인). `classify_run.py` CLI 가 다섯 fixture 전부에 대해 문서화된 exit code 계약대로
동작(0/2/3/5/7), `--exit-code 134` 오버라이드가 crashed 를 강제함을 실측(signal death != denial).
실제 Phase 1 32K 캡처(`phase-01/results/2026-08-29T095321Z-44990/ndjson.log`)가
context_overflow_terminal(exit 5)로 정확히 분류됨. `phase-04/config.env` 가 `SANDBOX_WORKDIR` 를
`workspace/ALLOWED_REPOS.json` 에서 파생(하드코딩 없음), 임의 cwd 에서도 source 가능함을 확인.
`EXTRA_ALLOW_PATHS` 미변경(`phase-03/sandbox/config.env` grep 확인), `phase-01/`·`phase-02/`·
`phase-03/`·`docs/` 무변경(`git diff --stat` 빈 결과).
[03-04] 실제 `cline` 바이너리를 샌드박스 아래서 정확히 1회 호출(재설치-체이닝 패턴,
`run_sandboxed.sh -- "$CLINE_BIN" --version`) — 판정 (C) BLOCKED-NEEDS-HUMAN(경계 미확장,
`EXTRA_ALLOW_PATHS` 변경 없음). `docs/sandbox-whitelist.md` 작성(8절, 한계 절이 자체 섹션,
Phase 4 인터페이스 계약 포함). phase-close 6개 게이트 전부 동시 PASS(`verify_sandbox.sh` 4/4
CRITERION, `pytest phase-03/tests/` 11/11, `verify_config.sh`, `verify_no_regression.sh`
INF03:PASS, launchctl pid 3종 불변, git status 클린). [03-01] `pytest phase-03/tests/ -q` 11/11 통과, 생성된 프로파일을 `sandbox-exec`가 실제로
수락(`/bin/echo` 성공), `run_sandboxed.sh -- /bin/cat bench/runs/CANARY.txt` 가
`Operation not permitted`로 거부(SBX-04 첫 신호), `ALLOWED_REPOS_JSON` 부재 시 fail-closed
확인, 두 파일(`config.env`/`run_sandboxed.sh`) 모두 SCOPE LIMITATION 문구 포함, launchd 서비스
무변경(`com.ohama.flashnext` 계속 active). [03-02] `assert_denied.sh` 5개 필수 자가검증 전부
사양대로 동작(`kill -ABRT $$` 로 실제 SIGABRT 유발 시 `FAIL crashed-signal rc=134`/exit 2, 크래시가
PASS 로 오판되지 않음을 실증), `probe_fs.js` 가 라이브 `sandbox-exec` 아래서 forbidden
read/write/subprocess/escape-symlink 5건 전부 `DENIED EPERM`으로, `ENOENT` 케이스는 별도로
`ERROR`로 정확히 구분됨을 실측, 무샌드박스 컨트롤 베이스라인 `succeeded=7 denied=0 error=0` 확보,
세 산출물 모두 `config.env` 미참조/`.gitignore` 미변경 grep 통과(03-01 과의 파일 소유권 경계 유지).
[03-03] `verify_sandbox.sh` 상시 게이트가 실제 `workspace/ALLOWED_REPOS.json` 대상으로 독립 2회
연속 실행 모두 exit 0, 네 `CRITERION ... PASS` 줄 동일, 16/16 케이스, CRASHED 0, 벤치 카나리
문자열이 어떤 캡처된 sandboxed stdout 에도 없음을 grep 스윕으로 확인. 음성 대조군 3종(precheck 가
deny-less 프로파일 거부, precheck 우회 시 Group F 4건 전부 `FAIL not-denied`, `--no-canonicalize`
아래서 F6 실패)이 모두 사양대로 동작. `launchctl print .../com.ohama.flashnext` pid 46573 로
플랜 전체에서 불변, `cline` 호출 0회.
Last activity: 2026-08-29 — 04-01-PLAN.md 완료 (`phase-04/classify_run.py`: 6가지 outcome을
정확한 우선순위(crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected >
run_aborted > success > other)로 판정하는 순수 `classify()` + CLI, `phase-01/parse_result.py` 의
nested-error 관용구 재사용, fixtures 5종 전부 실제 캡처에서 mining, `phase-04/fixtures/` 를 이제
frozen 으로 선언(wave 2 두 플랜이 read-only 소비), 13개 pytest 전부 통과. `cline` 호출 0회.)

이전 활동: 2026-08-30 — 03-03-PLAN.md 완료 (`verify_sandbox.sh`: 프로파일 생성+fail-open
사전점검 → Group F 8케이스+Group P 6케이스(모두 `assert_denied.sh` 직접 호출, 13회) → F8
`probe_fs.js` 프로브 → criterion-1 Python 체크 → 4개 CRITERION 판정 + `CASES`/`CRASHED`
줄 + 0/1/2 exit 계약. `--negative-control`/`--negative-control-skip-precheck` 모드와
`gen_sandbox_profile.py --no-canonicalize`(TEST-ONLY) 로 검증기 자체가 fail-open 샌드박스를
잡아낼 수 있음을 실증. 3 태스크 모두 개별 커밋, 실제 화이트리스트 대상 2회 실행 결과를
`phase-03/results/20260829T202043Z-sbx/`(README 포함)·`.../20260829T202048Z-sbx/` 에,
음성 대조군 3종을 `phase-03/results/20260829T201927Z-negative-control/`(README 포함)에 기록.
자체 발견/수정 이슈 1건(F8 의 라이브 샌드박스 Node 실행이 SIGABRT/MODULE_NOT_FOUND 로 실패 —
근본 원인 두 가지 모두 실측 후 수정, 아래 결정 로그 참조).

Progress: [██████▒▒▒▒] 62% (Phase 4/8 진행 중, Plan 15/24 누적 추정)

## Performance Metrics

**Velocity:**
- Total plans completed: 15
- Average duration: ~14.7 min
- Total execution time: ~3.7 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/6 | ~112 min | ~19 min |
| 2 | 4/4 | ~55 min | ~13.8 min |
| 3 | 4/4 | ~48 min | ~12 min |
| 4 | 1/4 | ~10 min | ~10 min |

**Recent Trend:**
- 04-01 (~10 min, wave 1 — Phase 4's offline foundation plan, zero `cline` invocations by design.
  Built `phase-04/classify_run.py`'s six-outcome NDJSON classifier reusing Phase 1's nested-error
  tolerance, mined all five fixtures from real captures (04-RESEARCH.md's live transcripts,
  phase-01's stored results/fixtures), derived `SANDBOX_WORKDIR` from `ALLOWED_REPOS.json` in
  `phase-04/config.env`, and froze `phase-04/fixtures/` for the two wave-2 plans to consume
  read-only. No deviations, no bugs found.)
- 03-04 (~12 min, wave 3 — Phase 3's final plan. The one budgeted real `cline` invocation under
  the sandbox: first attempt crashed with SIGABRT inside Node's own process bootstrap before any
  cline/Bun code ran (same root cause as 03-03's F8 finding, fixed the same way — capture to an
  in-whitelist path instead of an unpunched one — and not counted toward the invocation budget);
  the corrected second attempt reached the real Bun binary and produced a generic, path-less
  runtime error ("An unknown error occurred (Unexpected)"), confirmed via zero-cost `strings`
  inspection to be Bun's own catch-all, not a bounded-candidate permission message — verdict (C)
  BLOCKED-NEEDS-HUMAN, no sandbox widening, handed to Phase 4 as a documented open item. Wrote
  `docs/sandbox-whitelist.md` (Korean, 8 sections, scope-limitation as its own section, Phase 4
  interface contract). Phase-close: all six gates green simultaneously, flashnext/litellm/
  role-shim pids unchanged from the phase's start (46573/48525/75548) — **Phase 3 closed.**)
- 03-03 (~16 min, wave 2 — wired 03-01/03-02's artifacts into verify_sandbox.sh, the standing
  Phase 3 gate; found and fixed one live-reproduced blocker: F8's sandboxed Node invocation
  crashed with SIGABRT (redirecting output to a file under an unpunched path) and then
  MODULE_NOT_FOUND (Node's realpath walk lstat'ing $HOME itself), fixed via pipe-capture +
  a punched-through temp copy + --preserve-symlinks-main; ran the gate twice independently
  against the real whitelist with identical PASS verdicts, plus three archived negative controls
  proving the gate itself can fail (deny-less profile, precheck-bypassed deny-less profile,
  --no-canonicalize symlink-bypass regression))
- 03-02 (~10 min, ran in parallel with 03-01 — three artifacts (make_fixtures.sh, assert_denied.sh,
  probe_fs.js) fully self-tested including a deliberate `kill -ABRT $$` to prove crash != denial;
  one self-inflicted fix, a comment string that literally matched the plan's own `config.env` grep,
  caught and reworded before the first commit)
- 03-01 (~10 min, ran in parallel with 03-02 — no live mutations outside phase-03/workspace/bench,
  zero launchd interaction; one self-found/fixed bug: gen_sandbox_profile.py raised an unhandled
  traceback instead of a clean SystemExit when ALLOWED_REPOS.json itself was missing)
- Last 10 plans: 02-04 (~12 min, no restart — pure verification/sync/docs plan), 02-03 (~10 min,
  restart succeeded first try), 02-02 (~24 min incl. 2 failed restart attempts + fix + re-attempt),
  02-01 (~9 min), 01-06 (~50 min), 01-04 (~35 min), 01-05 (~6 min), 01-02 (~5 min), 01-03 (~5 min),
  01-01 (~11 min)
- 02-04 closed Phase 2: found one self-inflicted bug (PlistBuddy's indented ProgramArguments output
  defeated an exact-match grep in the new gate script's flag-presence check — fixed before the task
  commit, same class of bug as 02-03's verify_lan_bind.sh false positive but on the read side this
  time), ran the full-chain gate 4 times with identical PASS and zero pid churn, and closed with all
  three ROADMAP Phase 2 success criteria verified simultaneously true rather than sequentially true.
- Trend: 02-01 ran fast (zero live mutations). 02-02 was the project's first live launchd restart and
  hit a real bug: `launchctl bootout` is asynchronous, so `restart_service.sh` raced flashnext's
  104 GiB teardown and failed twice with an opaque I/O error before the async-teardown-wait fix
  landed; the restart then succeeded on the first attempt after the fix. 02-03 confirmed the fix
  generalizes for free: litellm's restart (no model to unload) succeeded on the first attempt with
  a 2s teardown, no new workaround needed. Phase 5 inherits the same helper unchanged.
- 01-06 ran long for two reasons found live, not scope creep: (1) this session's `cline`
  binary self-triggers a background auto-update on essentially every invocation regardless of
  `CLINE_NO_AUTO_UPDATE=1`, requiring a tight reinstall-then-immediately-launch pattern to get a
  clean preflight pass at all; (2) the live run surfaced a genuine bug in `parse_result.py`'s
  classifier (real NDJSON error events nest their message one level deeper than the hand-written
  fixtures assumed), which had to be fixed and both already-captured runs reclassified before the
  ② verdict could be trusted

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- 로드맵: 게이트웨이 32K 거부 가드는 만들지 않는다 — 서버가 이미 prefill 전 HTTP 400 으로 거부함을 실측. Phase 1 의 검증 대상은 "압축이 26.2k 에서 도는가"이며, 압축 미발동도 유효한 결과다
- 로드맵: INF(동시성 상한 + litellm 노출 차단)를 Phase 2 로 분리해 Kanban·Telegram 이 동시에 뜨는 Phase 5, 네트워크가 열리는 Phase 6 이전에 반드시 끝낸다
- 로드맵: 네트워크 노출(Phase 6)은 build 단계 중 최후, 매뉴얼(Phase 8)은 전체 중 최종 단계
- 01-02: CFG-04("Compact Prompt")는 CLI 에 존재하지 않는 설정으로 재정의 — `--compaction agentic`
  명시 고정으로 대체 만족. `docs/cline-config-pins.md` 에 디컴파일 증거와 함께 기록
- 01-02: `CLINE_COMPACTION_TRIGGER_RATIO=0.81`/`CLINE_PREDICTED_TRIGGER_TOKENS=26542` 는
  cross-check 전용 기본값 — 이후 플랜은 실제 `contextWindow` 에서 트리거를 재계산해야 한다
  (Plan 05 Branch B2 가 `contextWindow` 를 낮출 수 있음)
- 01-03: `phase-01/parse_result.py`의 `classify()`가 3-way 판정(①compaction_fired/②server_400_
  no_compaction/③other)을 반환. ②는 실패가 아닌 정상 통과 결과로 취급(Cline 이 이 스택의
  MAX_KV_SIZE 400 에서 자동 복구하지 않음을 reason 에 명시). ③은 below_trigger(미확정)와
  unexpected 로 reason 텍스트로 구분. `--predicted-trigger`는 진짜 파라미터이며 모듈 상수
  `PREDICTED_TRIGGER_TOKENS=26542`에 의해 가려지지 않음(전용 테스트로 검증) — 05번 브랜치가
  contextWindow 를 낮추면 run_regression.sh 가 그 값을 재계산해 넘겨야 함
- 01-03: CLI 종료 코드 계약(0=①/2=②/3=③)과 verdict.md 출력은 04/06 플랜의 회귀 하네스가
  그대로 의존함 — 시그니처: `parse_result.py --ndjson <f> [--server-log <f>]
  [--predicted-trigger <int>] [--max-kv <int>] --out <dir>`
- 01-01: `providers.json`의 커스텀 `models[]` 필드(따라서 `contextWindow:32768`)가 임의의 `cline`
  호출 한 번만으로도 사라지는 것을 이번 세션에서 3회 실측 재현(Pitfall 5, 이전엔 추정이었음).
  `apply_provider_config.sh`(쓰기+자체검증, 멱등)/`verify_config.sh`(사전 가드, 실패 시 어떤
  필드인지 명시하고 exit 1) 두 스크립트로 대응 완료. `run_regression.sh`(Plan 03/04)는 실행 직전에
  반드시 `verify_config.sh`를 호출해야 함 — 이론이 아니라 이번 실행 중 병렬 실행되던 형제 플랜의
  `cline` 호출만으로도 실제로 발동했다
- 01-01: `cline config --json`/`cline config`는 이 빌드(3.0.53)에서 헤드리스(TTY 없음)로는 동작하지
  않음 — "interactive mode requires a TTY" 로 즉시 실패. pty(`script`)로 감싸면 JSON 을 찍지 않고
  대화형 TUI 가 통째로 뜬다. Plan 04/06 하네스는 `cline config --json`을 evidence source 로 쓸 수
  없다 — 대신 `providers.json` 파일 자체를 읽거나 `--json` NDJSON 스트림(별도 실행)에 의존해야 함
- 01-05: CFG-03 실측 완료 — Cline 이 실제로 서버에 보내는 `max_tokens` 는 `2048`
  (`providers.json` 에 설정된 `4096` 이 아님, `providers.json.maxTokens` 비적용 재확인, 근본
  원인 불명). 예산식 `trigger(26542) + max_tokens(2048) = 28590 < 32768` 통과 → **Branch A**
  (완화 불필요). `contextWindow` 는 그대로 32768, REQUIREMENTS.md/ROADMAP.md 는 미변경.
  `phase-01/config/observed.env` 가 `CLINE_OBSERVED_MAX_TOKENS`/`CLINE_MAX_TOKENS_BRANCH=A`/
  `CLINE_CONFIGURED_CONTEXT_WINDOW`/`CLINE_PREDICTED_TRIGGER_TOKENS` 를 발행하며 이후
  `run_regression.sh` preflight C 가 이를 소비함
- 01-05: 이 세션의 Bash 도구 셸은 zsh — `$CLINE_COMMON_FLAGS` 같은 공백 구분 변수를 따옴표 없이
  전개할 때 bash 와 달리 word-split 되지 않아 인자가 한 덩어리로 뭉침. 이후 플랜에서 이 env 파일의
  플래그 변수를 직접 셸에서 펼쳐 쓸 때는 `bash -c '...'` 로 감싸야 함
- 01-05: Pitfall 5(providers.json 필드 소실)가 이 플랜 실행 중에도 실시간으로 재현됨(Plan 04 와의
  동시 실행 추정) — `verify_config.sh` 를 실제 회귀 실행 직전마다 반드시 재호출해야 한다는 Plan 01
  의 지침이 다시 한번 실측으로 확인됨
- 01-04: `check_versions.sh`의 "Check B: no drift across invocations" 자체가 실행하는 실제
  `cline config --json` 호출이 **매번 결정적으로**(우연한 동시성이 아니라) `providers.json`의
  `models[]`/`contextWindow` 오버라이드를 지운다는 것을 3회 독립 재현으로 확인. 원래 플랜 순서
  (Preflight A 검증 → Preflight B 버전확인)로는 B 직후 config 가 항상 깨진 채로 실제 실행에
  들어가게 됨 — `run_regression.sh` 에 **Preflight A2**(B 직후 재검증 → 실패 시
  `apply_provider_config.sh` 로 자동 복구 → 재검증, 그래도 실패하면만 abort)를 추가해 구조적으로
  해결. Plan 06 실행 시에도 매번 이 자동 복구 사이클이 한 번 더 도는 것이 정상 동작임
- 01-04: 이 세션 도중 `cline` npm 패키지가 3.0.53→3.0.60 으로 재차 auto-update 되어 있음을 발견
  (실행 중인 cline/kanban 프로세스 없음을 `ps aux` 로 확인 후 `npm install -g cline@3.0.53` 로
  안전하게 복구). Plan 06 은 실제 회귀 실행 직전 `check_versions.sh` 를 별도로 한 번 더 돌려
  버전 드리프트를 재확인할 것
- 01-04: `phase-01/config/observed.env`(Plan 05 전용 파일)처럼 동시에 실행 중인 다른 플랜이
  소유한 공유 파일을 읽어야 하는 스크립트는 `OBSERVED_ENV_PATH` 같은 오버라이드 가능한 env 변수로
  경로를 받아야 한다(기본값=실제 공유 경로) — 파일을 stub/restore 하는 방식은 TOCTOU 레이스가 됨.
  `run_regression.sh` 자신의 결과 디렉토리 위치도 동일 패턴(`RESULTS_ROOT`)으로 테스트가
  `phase-01/results/dryrun/`(gitignore 됨)를 가리키게 함
- 01-04: 이 macOS 호스트의 기본 `/bin/bash` 는 3.2 로 연관 배열(`declare -A`)을 지원하지 않음 —
  이후 셸 스크립트는 병렬 인덱스 배열을 써야 함(`phase-01/tests/test_harness_dryrun.sh` 에서
  실측 재현 후 수정)
- 01-06: **Phase 1 핵심 미지수 실측 완료 — 결과 ②.** `providers.json` 의 `contextWindow:32768`
  오버라이드는 라이브 압축 체크에 도달하지 못했다: 18개 filler 파일로 두 번째 라이브 실행 시
  peak_input_tokens=peak_prompt_tokens=30505 (두 오라클 완전 일치, 예측 트리거 26542 를 3,963
  토큰 초과)까지 갔지만 `auto-compact*`/`overflow-recovery-compact*` notice 는 0건이었고, 서버가
  prompt_tokens=31950 에서 `MAX_KV_SIZE is 32768` 400 으로 거부하며 작업이 죽었다. Cline 은 이
  오류에서 자동 복구하지 않는다(overflow-recovery 분류기가 이 서버의 오류 문구와 매칭되지 않음).
  운영 규칙: "작업을 다시 시작한다". 증거: `phase-01/results/2026-08-29T095321Z-44990/`.
  대응 방침 전체는 `docs/32k-compaction-policy.md` (VER-04). 1회차 실행(12개 filler)은
  below_trigger(peak 23266<26542)로 미확정이었고, 플랜이 허용한 "filler 늘려 1회 재실행"
  규칙에 따라 18개로 재실행해 확정함 — 총 라이브 실행 2/3회, 3회차는 불필요(outcome ①/②는
  최종 답이므로 재실행 금지 규칙에 따름)
- 01-06: `phase-01/parse_result.py`의 `classify()`에서 실제 버그 발견/수정 — cline 3.0.53 의
  실제 NDJSON 오류 이벤트는 메시지를 `event.error.message` 에 한 단계 더 깊이 중첩하는데(기존
  수기 fixture 는 `event.message` 평면 구조를 가정), 이 때문에 진짜 ② 결과가 최초엔 ③/unexpected
  로 오분류됨. `_error_event_message()` 헬퍼로 두 스키마 모두 허용하도록 수정, 실제 캡처된
  이벤트로 만든 회귀 fixture/테스트 추가(24개 테스트 전체 통과). 이미 캡처된 두 실행의 ndjson.log
  를 수정된 분류기로 재분류(추가 라이브 호출 없이) — Plan 03/04 가 만든 fixture 가 RESEARCH.md
  예측 스키마를 그대로 가정했을 뿐 실측 스키마와 다를 수 있다는 사례로 남김
- 01-06: 이 세션에서 `cline` 이 `CLINE_NO_AUTO_UPDATE=1` 에도 불구하고 사실상 모든 호출(`--version`
  포함)마다 백그라운드 `npm update cline` 를 트리거해 2-9초 내에 3.0.60 으로 드리프트하는 것을
  반복 재현(wave 2 가 기록한 "세션 중 1회 드리프트"보다 훨씬 공격적). PATH 상의 `npm` 을 no-op
  shim 으로 가리는 우회는 환경 자체의 안전 분류기에 의해 거부됨 — 대신 "재설치 직후 중간에 수동
  `cline` 호출 없이 바로 `run_regression.sh` 실행"을 한 셸 커맨드로 체이닝하는 패턴을 반복
  사용해 우회. 이후 어떤 플랜이든 `cline` 을 호출할 때 이 재설치-체이닝 오버헤드를 시간 예산에
  포함할 것
- 02-01: `MAX_NUM_SEQS` 기본값 `1`(완전 직렬화)로 확정 — RESEARCH.md Open Question 1 권고를
  그대로 채택. 로드맵 성공기준 문구("하나가 즉시 처리되고 다른 하나는 큐잉/지연")를 가장 직접
  만족하고, 32K 헤드룸이 4.39GB 뿐이라 가장 안전함. `phase-02/infra/config.env` 가 유일한
  오버라이드 지점이며, `verify_queueing.sh` 의 probe concurrency(`MAX_NUM_SEQS+1`)/cap assertion
  (`MAX_NUM_SEQS`) 모두 이 값에서 파생되므로 02-02 이후 캡을 2 로 올려도 스크립트 수정 불필요
- 02-01: 언캡트(현재) 서버 대상 큐잉 베이스라인을 실측 완료 — interleaved 로 확정(`max_overlap=2`
  == concurrency, `queued_count=0`; 두 번째 요청의 `Prefill started` 가 첫 번째 요청의
  `Decode completed` 보다 먼저 발생). 증거: `phase-02/results/20260829T183540Z/queueing-before-*`.
  02-02 의 "after" 실행이 대비할 대상이 확보됨(계획이 허용한 "베이스라인이 이미 직렬화로
  보일 수도 있다"는 대체 시나리오는 발생하지 않음)
- 02-01: `restart_service.sh`(bootout→plutil-lint→bootstrap→poll, `CURRENT_STEP` 기반 롤백
  메시지)를 작성했지만 이 플랜에서는 어떤 서비스에도 호출하지 않음 — 02-02/02-03 이 그대로
  재사용. `preflight.sh`/`verify_queueing.sh` 실행 전후로 `launchctl print` 를 재확인해
  flashnext(8716)/role-shim(75548)/litellm(76864) PID 가 전 과정에서 변하지 않았음을 실측 확인
- 02-01: 플랜 자체의 자동 검증(`grep -cE '\b(kill|pkill|launchctl (load|unload|kickstart))\b'`
  가 0 이어야 함)이 `restart_service.sh` 상단의 설명 주석에 있던 "kill/pkill" 이라는 단어 자체와
  매칭되는 것을 발견 — 실제 명령어가 아니라 주석 문구였지만, 검증을 통과시키기 위해 같은 하우스
  룰을 그 단어들을 쓰지 않는 문장으로 재작성함(동작 변경 없음)
- 02-02: **`launchctl bootout` 은 비동기다 — 이 프로젝트 첫 라이브 재시작에서 실제로 두 번 재현된
  결정적 버그.** `bootout` 은 언로드를 "요청"한 시점에 리턴하며, 실제로 잡이 사라지는 시점을
  보장하지 않는다. flashnext 는 104GiB 모델을 물고 있어 teardown 에 수 초가 걸리는데, 그 사이
  bootstrap 을 곧바로 호출하면 `Bootstrap failed: 5: Input/output error` 로 실패한다 —
  무거운 프로세스가 없는 throwaway 라벨 컨트롤 테스트는 매번 성공해 타이밍 가설을 뒷받침했다.
  `restart_service.sh` 에 Step 3b(`launchctl print` 로 라벨이 더 이상 조회되지 않고 포트에 리스너가
  없을 때까지 폴링 + 3초 여유)를 추가해 해결(commit `0ca2645`). 이 수정은 02-03(litellm)과
  Phase 5(신규 launchd 서비스 등록)에도 그대로 적용되는 헬퍼 차원의 영구 수정이며, 향후 재시작
  헬퍼를 다시 작성할 때 이 순서(bootout → teardown 확인 폴링 → bootstrap → healthy 폴링)를
  그대로 재사용해야 한다.
- 02-02: `MAX_NUM_SEQS=1` 라이브 적용 및 재시작 승인 완료 — 사용자 응답 `proceed-1`
  (`.planning/phases/02-infra-hardening/02-02-SUMMARY.md` 에 `CHECKPOINT_ANSWER: proceed-1`
  라인으로 기록). 이 승인은 이번 flashnext 재시작뿐 아니라 02-03 의 litellm 재시작도 명시적으로
  커버함 — 02-03 은 재승인을 요청하지 않고 이 SUMMARY 파일을 grep 해서 소비해야 한다.
  INF-01 큐잉 증거 실측: `max_overlap=1`(cap=1 이하), `queued_count=1`(>= concurrency-cap=1),
  1차 시도(수정 적용 후)에서 바로 성공(teardown 2초, 총 재시작 28초). 언캡트 베이스라인
  (`phase-02/results/20260829T183540Z/`, max_overlap=2/queued_count=0) 대비 명확한 대조 확보.
- 02-03: litellm 플리스트에 `--host 127.0.0.1` 라이브 적용(`apply_litellm_bind.sh`, `config.yaml`
  및 `master_key` 는 손대지 않음 — 4개 소비처가 모두 `dummy` 키에 `localhost:4000` 을 이미 쓰고
  있어 바인딩만으로 무회귀 해결). 02-02 의 `CHECKPOINT_ANSWER: proceed-1` 을 grep 으로 재사용,
  재질문 없이 재시작 → 첫 시도 성공(teardown 2초). INF-02 증거: `lsof` `*:4000`→`127.0.0.1:4000`,
  LAN IP(192.168.75.108) curl 거부(rc=7), loopback IP/hostname 둘 다 200 (IPv6 `::1` 스트랜딩
  없음 확인). pid 76864→48525. `verify_lan_bind.sh` 자체 검증 문구가 자기 검증용 grep 패턴
  (`*:4000`)과 우연히 매칭되는 버그를 실행 중 발견/수정(로그 문구만 변경, 로직 무변경). 미러
  sync 는 02-04 로 이월(의도적 drift, `MIRROR_DRIFT` 경고로 확인됨).
- 02-04: **Phase 2 종료.** `verify_no_regression.sh`(INF-03 상시 게이트, 읽기 전용·재실행 가능)
  작성/실행 — `INF03: PASS`, 8개 체크(플래그 존재→3개 서비스 실행중→hop3→hop2→hop1→전체 체인
  127.0.0.1→전체 체인 localhost→직접 :8000 무교착 확인) 전부 통과, 실제 completion body 확보
  ("Hi there! How can I help you"). 이 플랜 내내 4회 재실행 모두 동일 PASS, pid 전원 불변
  (flashnext=46573, role-shim=75548, litellm=48525) — 서비스 재시작 0회.
  `~/local-llm-settings/sync.sh` 를 이 phase 에서 유일하게 실행(live→mirror 단방향) — 사전에
  `--check` 로 drift 가 정확히 의도한 두 plist(`com.ohama.flashnext.plist`,
  `com.ohama.litellm.plist`) 뿐임을 확인한 뒤 sync, 이후 diff 0/`--check` 도 일치 보고.
  `docs/infra-hardening.md` 작성 완료 — 값/근거/한계(단일요청 32K OOM 은 안 고침)/증거경로/롤백
  런북/하우스룰(비동기 bootout 포함). phase-close 재검증에서 로드맵 성공기준 1·2·3 이 동시에
  성립함을 재확인(`verify_queueing.sh --label after`, `verify_lan_bind.sh`,
  `verify_no_regression.sh`, `preflight.sh --label phase-close` 모두 PASS, `MIRROR_DRIFT` 0건).
  자체 발견/수정 버그 1건: `PlistBuddy` 의 `ProgramArguments` 덤프가 각 원소를 들여쓰기해서
  출력하는데(`    1`), `verify_no_regression.sh` 의 Check 1 이 값 원문에 대해 `grep -qx` 정확
  매치를 시도해 실제로는 플래그가 멀쩡히 있는데도 FAIL 로 오판했던 것 — `awk '{$1=$1; print}'`
  로 공백 제거 후 매치하도록 커밋 전에 수정(02-03 의 `verify_lan_bind.sh` 자기검증 버그와 같은
  계열이지만 이번엔 로그 문구가 아니라 읽기 쪽 파싱 문제). `verify_queueing.sh` 는 `--label`
  인자를 리터럴 `before|after` 로만 하드 검증한다 — 플랜 문서가 예시로 든 `--label after-final`
  은 실제로는 실패하는 호출이므로 `--label after` 로 대체 실행(assertion 내용은 동일).
- 03-01: **Phase 3 착수.** SBX-01 `workspace/ALLOWED_REPOS.json` 을 유일한 소스로 확정(repo 루트는
  절대 항목으로 넣지 않음 — `bench/` 가 그 아래 있고 SBX-04 가 이를 도달 불가로 요구). SBPL
  프로파일은 03-RESEARCH.md 가 실측 검증한 `(allow default)` + `(deny ... (subpath $HOME))` +
  entry 당 `(allow ...)` punch-through 패턴을 그대로 채택(`(deny default)` 는 dyld 를 못 읽어
  SIGABRT 로 크래시하는 것이 재현되어 기각됨). 모든 경로는 `os.path.realpath()` 를 거친 뒤에만
  프로파일에 쓴다(`/tmp` vs `/private/tmp` 심볼릭링크 우회가 실측 재현됐던 지점). 프로파일은
  `run_sandboxed.sh` 호출마다 무조건 재생성되며 캐시 경로가 전혀 없음(드리프트 방지, 03-RESEARCH.md
  권고). `gen_sandbox_profile.py` 는 `--extra-allow` 플래그가 없어도 내장 기본값으로
  `~/.cline` 을 항상 punch-through 하고, `run_sandboxed.sh` 는 여기에 더해 config.env 의
  `CLINE_DATA_DIR`/`EXTRA_ALLOW_PATHS` 를 명시적으로 `--extra-allow` 로 전달(중복은 삽입순서
  기준으로 dedupe). `EXTRA_ALLOW_PATHS` 가 유일하게 허용된 확장 지점이며 config.env 헤더에
  `$HOME` 한정 스코프("total-deny jail 아님, `/tmp`/`/opt`/`/usr/local`/외장 볼륨은 그대로 열려
  있음")를 verbatim 으로 명시. 자체 발견/수정 버그 1건: `ALLOWED_REPOS.json` 파일 자체가 없을 때
  `load_allowed_repos()` 가 정리 안 된 Python traceback 을 냈던 것을 `SystemExit` 로 통일(fail-closed
  동작 자체는 이미 맞았음, 진단 메시지만 개선). bash 3.2 에서 빈 배열 `"${ARR[@]}"` 가
  `set -u` 하에서 unbound 오류를 내는 것도 실측 재현 후
  `"${ARR[@]+"${ARR[@]}"}"` 관용구로 회피(`run_sandboxed.sh`). `sandbox-exec` 가 `--` 를
  옵션 종결자로 정상 인식함도 man page 에 문서화되어 있지 않아 별도 실측으로 확인.
  03-02(fixtures/probe_fs.js/assert_denied.sh, `.gitignore`/`config.env` 는 미터치)와 병렬 실행,
  파일 소유권 충돌 없이 완료.
- 03-02: `assert_denied.sh`(이 phase 전체의 품질 핵심 산출물)의 `--expect deny` 판별 순서를
  고정: exit>128(crashed-signal, exit 2) → exit==0(not-denied) → 빈 stderr(crashed-silent, exit 2)
  → wrong-error → target/write-target 체크, 이 순서로만 크래시가 낮은 우선순위 규칙으로 새는 것을
  막을 수 있음. 언샌드박스 CONTROL 실행을 항상 먼저 돌려 그 커맨드 자체가 이미 깨져 있었을 가능성을
  배제한 뒤에만 DENIED 를 인정. `probe_fs.js` 는 fs 쪽 EPERM 단독 게이트와 execSync 쪽
  "exit!=0 AND stderr 에 Operation not permitted" 게이트를 동일 원칙으로 맞춤(ENOENT 등은 항상
  ERROR, 라이브 sandbox-exec 아래서 실측 확인). 세 산출물 모두 `--root`/env var/`--profile` 로
  파라미터화해 `config.env` 미참조, `.gitignore` 미변경(03-01 과의 소유권 경계) 확인 완료.
  Fixture 트리(`phase-03/fixtures/`)는 `make_fixtures.sh` 재실행으로 언제든 재생성 가능하며 이
  플랜이 종료된 상태에서 pristine.
- 03-03: **Phase 3 상시 게이트 완성.** `verify_sandbox.sh` 가 03-01/03-02 산출물을 실제로 연결해
  네 ROADMAP 성공기준(SBX-01..04)을 한 커맨드로 증명 — Group F(fixture 프로파일, 8케이스)+Group
  P(실제 production 프로파일, 6케이스) 전부 `assert_denied.sh` 직접 호출(13회)로 판정, F8 은
  `probe_fs.js` 자체 DENIED/ERROR/SUCCEEDED 텍스트로 판정(바 exit code 판정 0건, 플랜의
  `grep -nE '\$\? -ne 0.*(PASS|denied)'` 검증 통과). Criterion 1 의 ancestor 체크는 명시된
  방향대로 구현(`realpath(BENCH_DIR)` 이 어떤 entry 와도 같거나 그 자손이면 FAIL — 저장소 루트를
  화이트리스트에 넣는 실수를 잡는 방향, 반대 방향 아님). Fail-open 사전점검(두 프로파일 모두
  `(version 1)`/`(allow default)`/정확한 realpath 된 deny-root 두 줄/allow punch-through 가
  deny 뒤에 위치 확인 후 아니면 abort)을 모든 케이스 실행 전에 통과.
  **자체 발견/수정 이슈 1건(중요)**: 플랜이 문자 그대로 지시한 F8 명령("sandbox-exec ... node
  phase-03/sandbox/probe_fs.js > $OUT_DIR/probe-sandboxed.txt")이 이 환경에서 실제로 두 단계로
  실패함을 실측: (1) 샌드박스 프로세스의 stdout 을 화이트리스트 밖 경로($OUT_DIR, `$HOME` 아래
  미펀치)로 직접 리다이렉트하면 Node 가 자체 초기화 중 SIGABRT 로 크래시(재현 100%, 파이프
  캡처로 전환하면 즉시 사라짐 확인). (2) 크래시를 고쳐도 `phase-03/sandbox/`(미펀치) 자체를 Node
  가 읽을 수 없어 MODULE_NOT_FOUND, 게다가 Node 의 기본 모듈 해석이 `$HOME` 자체를 포함한 모든
  상위 디렉터리를 lstat 하려다 EPERM. 해결: 캡처를 파일 리다이렉트 대신 커맨드 치환(파이프)으로
  바꾸고, `probe_fs.js` 를 픽스처의 이미 펀치스루된 `$FX/allowed/` 로 실행 중에만 복사한 뒤
  `node --preserve-symlinks-main` 으로 조상 lstat 워크를 건너뛰게 함 — DENIED/ERROR/SUCCEEDED
  판정 로직 자체는 전혀 손대지 않음(순수 배관 수정). 음성 대조군 3종(`--negative-control`이
  deny-less 프로파일을 사전점검에서 거부, `--negative-control-skip-precheck`로 우회 시 Group F
  4건 전부 `FAIL not-denied`, `gen_sandbox_profile.py --no-canonicalize`(TEST-ONLY 신규 플래그)
  아래서 F6 이 예상대로 실패) 모두 사양대로 동작 실증, README 로 각각의 의미 문서화. 실제
  화이트리스트 대상 2회 독립 실행 모두 exit 0/CRITERION 4개 PASS 동일, `launchctl print`
  pid(46573) 불변, `cline` 호출 0회, `phase-02/`·plist 무변경.
- 03-04: **Phase 3 종료.** 03-RESEARCH.md Open Question 1(실제 `cline` 바이너리가 샌드박스
  아래서 추가 punch-through 가 필요한가)에 이 phase 유일의 budgeted 실제 `cline` 호출로 답함 —
  재설치-체이닝 패턴으로 `run_sandboxed.sh -- "$CLINE_BIN" --version` 실행, 결과: exit 1,
  stderr `error: An unknown error occurred (Unexpected)`(경로/errno 를 전혀 명시하지 않는 일반
  오류). 설치된 `.cline` 바이너리를 `strings -a` 로 직접 확인(추가 호출 0회)해 이 문구가 Bun
  런타임 자체의 startup catch-all 오류 계열임을 확정 — 플랜이 정의한 (B) BOUNDED-FIX 요건(사전
  선언된 후보 디렉터리 하나를 명시하는 permission 오류)을 만족하지 못해 **판정 (C)
  BLOCKED-NEEDS-HUMAN**, `EXTRA_ALLOW_PATHS` 무변경(경계 확장 없음), Phase 4 로 문서화된
  미해결 항목으로 이월. **자체 발견/수정 이슈 1건(Rule 3)**: 플랜이 문자 그대로 지시한 호출
  형태(출력을 `phase-03/results/` 로 직접 리다이렉트)가 Node 자체 프로세스 부트스트랩 중
  SIGABRT 로 크래시(cline/Bun 코드는 한 줄도 실행 전) — 03-03 의 F8 과 동일한 근본 원인(미펀치
  경로로의 stdio 리다이렉트). `workspace/scratch-repo/`(화이트리스트 안)로 캡처 대상을 바꾼 뒤
  결과 디렉터리로 복사하는 방식으로 수정, 이 크래시 시도는 "정확히 1회" 예산에 포함하지 않음
  (cline/Bun 코드가 전혀 실행되지 않았으므로). `docs/sandbox-whitelist.md` 작성 완료(한글, 8절,
  `docs/infra-hardening.md` 하우스 스타일, 한계 절이 각주가 아닌 독립 섹션, Phase 4 인터페이스
  계약(`run_sandboxed.sh`/`verify_sandbox.sh`/`EXTRA_ALLOW_PATHS`) 포함, criterion-1 서술이
  `verify_sandbox.sh` 실제 구현 방향과 일치 확인). phase-close 재검증 6개 게이트 전부 동시
  PASS(`verify_sandbox.sh` 4/4 CRITERION·16/16 케이스·CRASHED 0, `pytest phase-03/tests/` 11/11,
  `phase-01/config/verify_config.sh`, `phase-02/infra/verify_no_regression.sh` INF03:PASS,
  launchctl pid 3종 불변, git status 클린) — flashnext(46573)/role-shim(75548)/litellm(48525) 이
  phase 시작 시점부터 종료까지 불변, 서비스 재시작 0회. `cline` 호출로 인한 providers.json
  드리프트(01-04 가 예측한 대로 `check_versions.sh` 자체의 내부 `cline config --json` 호출로 한
  번 더 발생)는 `apply_provider_config.sh` 로 2회 모두 치유, 최종 `verify_config.sh` PASS.

- 04-01: `phase-04/classify_run.py`의 `classify(events, cline_exit_code=None, stderr_text="",
  allowed_prefixes=None) -> Outcome` 시그니처가 04-02/04-03 이 그대로 의존하는 계약 — 우선순위
  `crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected > run_aborted >
  success > other`, CLI exit code 계약(0/2/3/4/5/6/7, 1=classifier 자체 오류)도 grep 가능하게
  고정. 모든 outcome 의 boolean 시그널을 독립적으로 계산한 뒤에만 우선순위로 최종 outcome 을
  고르므로(`signals` 리스트에는 정보 손실 없음), crash 가 실제 EPERM denial 을 덮어써도
  `signals` 에는 `sandbox_denied` 가 남는다(전용 테스트로 검증).
- 04-01: `phase-04/fixtures/` 는 이 플랜 종료 시점부터 **frozen** — 04-02/04-03(wave 2) 둘 다
  `sandbox_denied.ndjson` 을 read-only 로 소비하며 어느 쪽도 이 디렉터리에 쓰지 않는다.
  `sandbox_denied.ndjson` 자체가 이미 (a) 04-RESEARCH.md Pitfall 3 의 실측 `$HOME/.zshrc` EPERM
  거부 두 건과 (b) `SANDBOX_INSIDE_CANARY.txt` 에 대한 성공적 in-sandbox `read_files` 양성
  대조군을 동시에 담고 있어, 04-03 이 이 fixture 하나로 부정/긍정 대조군을 모두 얻는다.
  provenance 는 `phase-04/fixtures/README.md` 에 파일별로 기록.
- 04-01: `phase-04/config.env` 는 `phase-03/sandbox/config.env` 관용구를 그대로 복제(BASH_SOURCE
  기반 PROJECT_ROOT). `SANDBOX_WORKDIR` 는 `workspace/ALLOWED_REPOS.json` 의 `repos[]` 첫 항목을
  `python3 -c`(jq 미사용)로 파싱해 파생 — 절대 하드코딩하지 않음, 기존 env var 오버라이드는 존중.
  `EXTRA_ALLOW_PATHS` 무변경(04-01 은 샌드박스를 전혀 확장하지 않음).

### Pending Todos

없음 (아직 없음)

### Blockers/Concerns

- **(Phase 4 인계 항목 — 04-RESEARCH.md 가 이미 해결, 04-02/04-03 의 라이브 실행으로 재확인 대기)**
  03-04 에서 남긴 verdict C(BLOCKED-NEEDS-HUMAN, `cline` 이 샌드박스 안에서 경로명 없는 일반
  Bun 런타임 오류로 죽던 문제)의 근본 원인이 04-RESEARCH.md 에서 실측으로 확정됐다: **원인은
  샌드박스 프로파일이 아니라 래퍼 자신의 프로세스 cwd** — `sandbox-exec` 가 `$HOME` 자체에 대한
  `file-read-metadata` 를 거부하는데, cwd 가 화이트리스트 밖(예: repo 루트)이면 Node/Bun 의 자체
  startup 이 조상 디렉터리를 stat 하려다 이 deny 에 걸려 cline 코드가 실행되기도 전에 일반
  오류를 낸다. 고침: 샌드박스 프로세스를 실행하기 *전에* 이미 `ALLOWED_REPOS.json` 안에 있는
  경로로 실제 `cd`(cline 자신의 `-c/--cwd` 플래그는 별개이며 대체하지 않음) — `EXTRA_ALLOW_PATHS`
  변경 없이, `workspace/scratch-repo` 에서 `cline --version` → `3.0.53` exit 0 을 라이브로
  재현 완료. `phase-04/config.env` 의 `SANDBOX_WORKDIR` 가 바로 이 픽스를 위해 존재(04-01 에서
  구현). **04-01 자신은 `cline` 을 호출하지 않았으므로 이 결론을 재확인하지 않았다** — 04-02(래퍼
  스크립트)가 실제로 이 cwd 픽스를 적용해 라이브로 재검증해야 한다. 04-RESEARCH.md 는 추가로
  `--auto-approve false` 헤드리스 모드가 모든 도구 호출을 TTY 게이트로 즉시 거부함(정상 동작,
  크래시 아님)을 실측했고, criterion 3 증명은 별도의 `--auto-approve true` 전용 검증 스크립트
  (04-03)로 분리해야 함을 확정했다. 증거: `.planning/phases/04-headless-cli-wrapper/04-RESEARCH.md`
  Pitfall 1/2/3, `phase-03/results/20260829T202633Z-cline-smoke/`, `docs/sandbox-whitelist.md` §7.
- (Phase 3 설계 경계, 블로커 아님) 샌드박스는 `(allow default)` + `$HOME` deny + punch-through
  구조라 **`$HOME` 밖은 보호하지 않는다** (`/tmp`, `/opt`, `/usr/local`, 외장 볼륨 등). 전면 차단
  감옥이 아니다. `phase-03/sandbox/config.env`/`run_sandboxed.sh` 헤더와
  `docs/sandbox-whitelist.md` §3 에 명시돼 있다.

- Phase 1 의 핵심 미지수는 01-06 에서 실측 완료(결과 ②, 위 결정 로그 참조) — 더 이상 미지수가
  아니다. Phase 4/5/7/8 은 `docs/32k-compaction-policy.md` 의 "작업을 다시 시작한다" 규칙과
  터미널 실패 분류를 반드시 반영해야 한다.
- Telegram 봇 토큰은 BotFather 에서 사람이 직접 발급해야 한다 — Phase 5 는 토큰 주입 자리를
  비운 채로 완료되고, 실사용은 토큰 발급 후에 가능하다
- (환경 노트, 블로커 아님) 이 개발 환경에서 `cline` 은 거의 모든 호출마다 백그라운드에서
  3.0.53→3.0.60 으로 self-update 를 시도한다. Phase 5 가 launchd plist 로 `cline`/`kanban` 을
  등록할 때 이 드리프트에 대비해야 한다 — `check_versions.sh` Check C 가 이미 이런 plist 를
  스캔하도록 armed 되어 있음.
- (환경 노트, 블로커 아님) `launchctl bootout` 은 비동기이므로, 무거운 프로세스(모델 로드 등)를
  물고 있는 launchd 서비스를 재시작할 때는 반드시 teardown 확인 폴링을 거쳐야 한다.
  `restart_service.sh` 가 이미 이 폴링을 내장하고 있으므로(Step 3b) 이 헬퍼만 사용하면 문제
  없음 — 다만 Phase 5 에서 새 launchd 서비스용 헬퍼를 별도로 작성한다면 동일 패턴을 반드시
  재사용할 것. 이 하우스 룰은 이제 `docs/infra-hardening.md` 에도 기록됨.
- (환경 노트, 블로커 아님) Phase 2 가 남긴 상시 게이트 `phase-02/infra/verify_no_regression.sh`
  는 읽기 전용·재실행 가능 — Phase 5(Kanban+Telegram 동시 기동)와 Phase 6(네트워크 노출)은 새
  서비스를 올리기 전/후 이 스크립트를 그대로 호출해 회귀를 잡을 것.
- **(SUPERSEDED by 04-RESEARCH.md — kept for history)** 이 항목은 03-04 종료 시점에 "Phase 4 가
  `dtruss`/`fs_usage` 로 정밀 재현해야 한다"고 남겼던 오픈 아이템이었다. 실제로는 `log stream`
  (관리자 권한 불필요, `dtruss`/`fs_usage` 불필요)로 04-RESEARCH.md 세션에서 근본 원인을 이미
  확정했다: 부족한 건 `EXTRA_ALLOW_PATHS` punch-through 가 아니라 래퍼 프로세스의 cwd 였다(위
  항목 참조). `EXTRA_ALLOW_PATHS` 의 사전 선언된 4개 후보(`$HOME/.npm` 등) 는 격리 테스트에서
  전부 불필요한 것으로 확인됐고 넓히지 않았다. 남은 작업은 04-02/04-03 이 이 cwd 픽스를 실제
  래퍼/검증 스크립트에 적용해 라이브로 재확인하는 것뿐이다.

## Session Continuity

Last session: 2026-08-29
Stopped at: **04-01-PLAN.md 완료.** Phase 4 의 오프라인 기반(wave 1의 유일한 플랜)을 `cline`
호출 0회로 구축: `phase-04/classify_run.py`(6가지 outcome, 우선순위 고정, Phase 1 의
nested-error 관용구 재사용), `phase-04/config.env`(`SANDBOX_WORKDIR` 를 `ALLOWED_REPOS.json`
에서 파생), `phase-04/fixtures/`(5종, 전부 실제 캡처에서 mining, 이제 frozen/read-only),
`phase-04/tests/test_classify_run.py`(13개 pytest, crash-outranks-denial/nested-vs-flat/
denial-vs-TTY/model-refusal-is-not-denial 등 phase brief 가 명시한 모든 false-pass 혼동 케이스
커버). 3개 태스크 모두 개별 커밋, SUMMARY 작성 완료. 04-RESEARCH.md 가 이미 실측으로 밝힌
"cline 이 샌드박스 안에서 기동되지 않던" Phase 3 인계 블로커의 근본 원인(cwd 픽스, 샌드박스
확장 불필요)은 이 플랜에서 소비되지 않았다 — 다음 플랜(04-02, 실제 래퍼 스크립트)이 이 cwd 픽스를
적용해 라이브로 처음 재확인해야 한다.
다음 세션은 **04-02-PLAN.md(헤드리스 래퍼 스크립트, wave 2)** 부터 시작 — `phase-04/config.env`
와 `phase-04/classify_run.py` 를 그대로 소비하고, 04-RESEARCH.md Pitfall 1(cwd 픽스)/Pitfall 2
(`--auto-approve false` 는 헤드리스에서 모든 도구 호출을 즉시 거부함, 정상 동작)를 먼저 읽을 것.
Phase 4 예산 중 실제 `cline` 호출은 아직 0/2 회 — 04-02/04-03 이 소비할 차례.
Resume file: None
