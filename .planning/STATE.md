# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
**Current focus:** Phase 1 — Cline 설정 + 압축 검증

## Current Position

Phase: 1 of 8 (Cline 설정 + 압축 검증)
Plan: 04 of 6 in current phase (wave 2 완료: 01-04/01-05 모두 done)
Status: In progress
Last activity: 2026-08-29 — 01-04-PLAN.md 완료 (회귀 하네스: gen_filler.py, growth_prompt.txt,
run_regression.sh 4-preflight 러너, test_harness_dryrun.sh 오프라인 전체 검증 PASS)

Progress: [████████░░] 83%

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: ~12 min
- Total execution time: ~1.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 5/6 | ~62 min | ~12 min |

**Recent Trend:**
- Last 5 plans: 01-04 (~35 min), 01-05 (~6 min), 01-02 (~5 min), 01-03 (~5 min), 01-01 (~11 min)
- Trend: 01-04 ran long because its own offline testing live-reproduced two real environment
  defects (cline auto-update drift, and check_versions.sh's own drift-check call deterministically
  stripping providers.json) that had to be fixed before the harness could be proven — not scope
  creep, the harness doing exactly its job

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

### Pending Todos

없음 (아직 없음)

### Blockers/Concerns

- Phase 1 의 핵심 미지수: `providers.json` 의 `contextWindow: 32768` 오버라이드가 Cline 내부 압축
  임계값을 실제로 바꾸는지는 연구 단계에서 결론 내지 못했다 (MEDIUM-LOW confidence). Phase 1 의
  회귀 테스트로 반드시 실측해야 하며, 압축이 안 뜨는 경우의 대응 방침도 함께 기록해야 한다
- Telegram 봇 토큰은 BotFather 에서 사람이 직접 발급해야 한다 — Phase 5 는 토큰 주입 자리를
  비운 채로 완료되고, 실사용은 토큰 발급 후에 가능하다

## Session Continuity

Last session: 2026-08-29
Stopped at: Wave 2 전체 완료 (01-04/01-05 모두 SUMMARY.md 존재). 01-04 는 gen_filler.py,
growth_prompt.txt, run_regression.sh(4-preflight 러너 + Preflight A2 자동복구), 그리고
test_harness_dryrun.sh(오프라인 전체 파이프라인 PASS)를 남기고 종료. 실행 중 실제 cline
auto-update 드리프트(3.0.60)와 check_versions.sh 자체 유발 Pitfall 5 를 실측 재현/수정함.
다음은 01-06(실제 회귀 실행 + 최종 검증, 라이브 모델 호출 1회 한도)
Resume file: None
