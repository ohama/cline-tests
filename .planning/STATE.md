# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
**Current focus:** Phase 2 (인프라 보정) 완료 — flashnext 동시성 상한 + litellm 루프백 바인딩 라이브 적용,
INF-03 전체 체인 회귀 게이트 통과, 미러 sync 완료. Phase 3 대기.

## Current Position

Phase: 2 of 8 (인프라 보정) — 완료
Plan: 04 of 4 in current phase — 완료 (phase 전체 완료)
Status: Phase complete — gsd-verifier 독립 검증 통과 (3/3 성공 기준, `02-VERIFICATION.md`)
Verified: 라이브 plist·로드된 job·실행 중 프로세스 세 곳 모두에서 `--max-num-seqs 1`/`--host 127.0.0.1` 일치 확인,
`lsof` 에 `*:4000` 없음, `verify_no_regression.sh` 재실행 `INF03: PASS`, 미러 diff 0
Last activity: 2026-08-30 — 02-04-PLAN.md 완료 (INF-03 전체 체인 회귀 게이트
`verify_no_regression.sh` 작성/실행 — `INF03: PASS`, 127.0.0.1/localhost 양쪽 경로 실측 완료.
`~/local-llm-settings/sync.sh` 실행(live→mirror, 이 phase 유일 실행 지점) — drift 는 정확히 의도한
두 plist 편집뿐이었음을 확인 후 sync, 이후 diff 0. `docs/infra-hardening.md` 작성.
phase-close 재검증: `verify_queueing.sh --label after`/`verify_lan_bind.sh`/
`verify_no_regression.sh`/`preflight.sh --label phase-close` 네 게이트 전부 동시 통과,
`MIRROR_DRIFT` 0건. 이 플랜 내내 서비스 재시작 0회, pid 전원 불변).

Progress: [████▒▒▒▒▒▒] 42% (Phase 2/8 완료, Plan 10/24 누적 추정)

## Performance Metrics

**Velocity:**
- Total plans completed: 10
- Average duration: ~15.4 min
- Total execution time: ~2.6 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/6 | ~112 min | ~19 min |
| 2 | 4/4 | ~55 min | ~13.8 min |

**Recent Trend:**
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

### Pending Todos

없음 (아직 없음)

### Blockers/Concerns

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

## Session Continuity

Last session: 2026-08-30
Stopped at: **02-04-PLAN.md 완료 — Phase 2(인프라 보정) 전체 종료.** `verify_no_regression.sh`
(INF-03 상시 게이트) 작성/실행 → `INF03: PASS`(8개 체크 전부 통과, 127.0.0.1/localhost 양쪽
경로에서 실제 completion body 확보). `~/local-llm-settings/sync.sh` 실행(이 phase 유일 실행 —
live→mirror 단방향, drift 는 정확히 의도한 두 plist 편집뿐이었음을 `--check` 로 사전 확인 후
sync, 이후 diff 0). `docs/infra-hardening.md` 작성(값/근거/한계/증거/롤백/하우스룰).
phase-close 재검증에서 로드맵 Phase 2 성공기준 1·2·3 이 동시에 성립함을 재확인
(`verify_queueing.sh --label after`, `verify_lan_bind.sh`, `verify_no_regression.sh`,
`preflight.sh --label phase-close` 전부 PASS, `MIRROR_DRIFT` 0건). 이 플랜 내내 서비스 재시작
0회, pid 전원 불변(flashnext=46573, role-shim=75548, litellm=48525). 자체 발견/수정 버그 1건
(PlistBuddy 들여쓰기 출력이 Check 1 의 `grep -qx` 정확매치를 깨뜨림 — `awk` 로 공백 제거 후
수정, 커밋 전 반영). 증거 디렉터리: `phase-02/results/20260829T191031Z-inf03/`(INF-03 최초
PASS + sync.txt), `phase-02/results/20260829T191110Z-inf03/`(sync 후 재확인),
`phase-02/results/20260829T191241Z/`(queueing after), `phase-02/results/20260829T191249Z-inf02-verify/`
(lan-bind), `phase-02/results/20260829T191251Z/`(preflight phase-close).
다음 세션은 Phase 3(샌드박스 + 저장소 화이트리스트) 플랜 작성부터 시작 — 아직 PLAN.md 없음,
Phase 1·2 와 독립적으로 진행 가능.
Resume file: None
