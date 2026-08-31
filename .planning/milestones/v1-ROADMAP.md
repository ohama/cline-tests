# Milestone v1: Cline 로컬 서버

**Status:** ✅ SHIPPED 2026-08-31
**Phases:** 1–8
**Total Plans:** 55

## Overview

로컬 Qwen3.8 Flash-Next(litellm :4000)를 두뇌로 쓰는 Cline 상시 서버를 구축했다.
부팅 시 launchd 자동 기동, 32K 컨텍스트 운용, Tailscale 을 통한 iPad/iPhone 접근,
그리고 한글 사용 매뉴얼까지. 기존에 검증된 추론 스택은 건드리지 않고 그 위에 얹었다.

## Phases

### Phase 1: Cline 설정 + 압축 검증
**Plans**: 6 (+6 gap) — CFG-01~07, VER-01~04
압축 임계값을 디컴파일로 확정(`maxInputTokens × 0.9`)하고, `contextWindow` 가
`settings` 최상위 필드임을 소스로 규명했다. 결론이 두 번 정정된 유일한 페이즈.

### Phase 2: 인프라 보정
**Plans**: 4 — INF-01~03
`--max-num-seqs` 동시성 상한, litellm 무인증 LAN 노출 차단.

### Phase 3: 샌드박스 + 저장소 화이트리스트
**Plans**: 4 — SBX-01~04
`sandbox-exec` OS 수준 강제. `.clineignore` 가 `execute_command` 를 막지 못함을 반영.

### Phase 4: 헤드리스 CLI 래퍼
**Plans**: 4 — HLS-01~03
`--auto-approve false` 명시. 설정+샌드박스 조합 스모크 테스트.

### Phase 5: Kanban·Telegram 서비스화
**Plans**: 7 — SVC-01~05
launchd 상시 서비스, KeepAlive 자가 복구, flashnext 미기동 시 크래시루프 회피.

### Phase 6: 네트워크 노출
**Plans**: 8 — NET-01~05
Tailscale 무인증 + LAN 토큰 게이팅. 포트 3000 금지(기존 Funnel 회피).

### Phase 7: cline-bench 동작 검증
**Plans**: 10 + 6 (gap closure) — BCH-01~03
공식 과제 실행, 그리고 `fail-context` 근인 규명 갭 종료.

### Phase 8: 한글 사용 매뉴얼
**Plans**: 6 — DOC-01~04
CLI·웹·iPad/iPhone 사용법 + 32K 운용 주의.

---

## Milestone Summary

**Key Decisions:**
- 게이트웨이 32K 거부 가드를 만들지 않음 — 서버가 이미 prefill 전 HTTP 400 으로 거부함을 실측
- `contextWindow` 는 `providers.json` 의 `settings` **최상위**에 (`models[]` 는 CLI 가 읽지 않음)
- 값은 29,000 유지 (`SELECTION: doc-only`) — 근거는 정정됨
- 기존 Tailscale Funnel(:8443→3000) 존치, 포트 3000 바인딩 금지로 보상 통제
- Compact Prompt 는 CLI 에 없음 → `--compaction agentic` 명시 고정으로 재정의
- 네트워크 노출은 build 단계 중 최후, 매뉴얼은 전체 최종

**Issues Resolved:**
- `contextWindow` 를 `models[]` 에 넣어 압축이 전혀 발동하지 않던 문제 (소스로 규명)
- `providers.json` 필드 소실(Pitfall 5) — 같은 원인. 최상위 필드는 정규화에서 살아남음
- `fail-context` 분류기 불건전 — `grep '\b400\b'` 가 `generated_tokens=400` 과 벤치 소스에 매칭
- `flashnext-codex` 별칭 호출이 모델 서버를 죽이던 문제 (CFG-07 로 차단)

**Issues Deferred:**
- `--compaction basic` — 행렬이 지목한 유일한 유망 미테스트 지렛대. 의식적 보류
- `phase-01/results/exp-basic/` 는 오설정 상태였으므로 `basic` 증거로 무효

**Technical Debt Incurred:**
- **CFG-05**: `CLINE_NO_AUTO_UPDATE=1` 이 자동 업데이트를 막지 못함. 3.0.53↔3.0.60 드리프트 반복
- **Phase 1**: VERIFICATION.md 부재 — 결론이 두 번 뒤집힌 유일한 미검증 페이즈
- **BCH-01**: 고유 4과제, 통과 0개 (5~8 하한 미달) — 사용자 정지 결정
- **NET-01/NET-05**: iPad 오프라인·실토큰 시험 거절로 미관측
- **DOC-02**: worktree 불가 — 샌드박스 확장 거절
- **압축 프루닝**: 실제 부하 2/2건에서 프루닝 없음, 토큰 오히려 증가. `contextWindow` 는 지렛대 아님
- **재부팅 지속성**: 프록시 증거만. 실제 재부팅은 `iogpu.wired_limit_mb` 재적용 필요
- **`--auto-approve` 자세**: 미결정. Kanban/Telegram 은 `--no-tools` 로 우회

---

*For current project status, see .planning/PROJECT.md*
