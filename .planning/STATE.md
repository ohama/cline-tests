# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
**Current focus:** Phase 1 — Cline 설정 + 압축 검증

## Current Position

Phase: 1 of 8 (Cline 설정 + 압축 검증)
Plan: 03 of 6 in current phase (wave 1 complete: 01-01/01-02/01-03 all done)
Status: In progress
Last activity: 2026-08-29 — 01-01-PLAN.md 완료 (flashnext provider config: apply/verify 스크립트,
config-snapshot). Wave 1 전체(01-01/01-02/01-03) 완료

Progress: [█████░░░░░] 50%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: ~7 min
- Total execution time: ~0.3 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3/6 | ~21 min | ~7 min |

**Recent Trend:**
- Last 5 plans: 01-02 (~5 min), 01-03 (~5 min), 01-01 (~11 min)
- Trend: stable

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
Stopped at: Wave 1 전체 완료 (01-01/01-02/01-03 모두 SUMMARY.md 존재). 01-01은 flashnext provider
config apply/verify 스크립트와 config-snapshot 증거를 남기고 종료. 다음은 Wave 2(01-04 회귀
하네스, 01-05 max_tokens 실측+대응) 진행
Resume file: None
