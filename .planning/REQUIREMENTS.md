# Requirements: v1.1 Plan/Act ↔ reasoning_effort

**Defined:** 2026-09-01
**Core Value (v1.1):** Plan 모드에서만 사고가 켜지고, 그것이 **실제로 도달했음이 증명**된다

설계·계획 근거: `docs/plan-act-reasoning-design.md` · `-implementation.md` · `-diagrams.md`

## v1.1 Requirements

### PRB — 사전 확인 (게이트, 스택 무변경)

- [ ] **PRB-01**: `reasoning_effort: medium` 이 `:8011` 직결에서 실제로 응답에 `reasoning` 필드를
  만드는지 확인되고 결과가 기록된다
  <br>🔴 **게이트.** `reasoning` 이 비면 medium 은 사고를 켜지 않는다는 뜻이고, 그 경우
  이 마일스톤은 구현 없이 종료한다(정당한 결과)
- [ ] **PRB-02**: `enable_thinking: false` 가 litellm 을 통과하는지 확인된다 →
  `flashnext-act` 별칭 생성 여부가 이 결과로 결정된다
- [ ] **PRB-03**: effort 별 `prompt_tokens` 차이(미지정 23 / medium 21 / low 51 / xhigh 63)가
  재확인되어 도달 증명 오라클로 쓸 수 있음이 확립된다
- [ ] **PRB-04**: 사고 트레이스가 다음 턴 컨텍스트로 되돌아오는지 실측된다
  <br>🔴 **게이트.** 누적되면 v1 의 "실제 부하에서 압축이 프루닝하지 않는다"와 겹쳐
  치명적이므로 마일스톤을 폐기한다

### CFG — 별칭과 주입

- [ ] **CFG-11**: `flashnext-plan` 별칭이 `reasoning_effort: medium` 을 주입한다
  (Cline 은 `--thinking` 을 쓰지 않는다)
- [ ] **CFG-12**: PRB-02 가 통과를 확인한 경우에만 `flashnext-act` 별칭이 만들어진다.
  통과하지 못하면 만들지 않고 그 사실이 기록된다
- [ ] **CFG-13**: 기존 `flashnext` 별칭은 변경되지 않는다 (회귀 판정 기준선)
- [ ] **CFG-14**: `drop_params: true` 를 쓰지 않는다 — 파라미터를 조용히 버려 200 을 만드는
  실패 모드이며, 이 프로젝트가 두 번 당한 것과 같은 종류다
- [ ] **CFG-15**: 변경이 `~/local-llm-settings` 에 반영되고 `sync.sh` 결과에 나타난다

### VRF — 도달 증명

- [ ] **VRF-01**: 동일 사용자 메시지를 `flashnext` 와 `flashnext-plan` 으로 각각 보냈을 때
  서버 로그의 `prompt_tokens` 가 **다르다** — 주입이 실제로 도달했다는 증거
- [ ] **VRF-02**: 판정 근거가 서버 측 증거이지 HTTP 200 응답이 아니다
- [ ] **VRF-03**: 재실행 가능한 검증 스크립트로 남는다 (일회성 확인이 아님)

### USE — 사용 표면과 문서

- [ ] **USE-01**: `cline-plan` / `cline-act` 래퍼가 모드와 별칭의 짝을 강제한다
- [ ] **USE-02**: `verify_config.sh` 가 짝 불일치와 `--thinking high` 사용을 잡아낸다
- [ ] **USE-03**: `medium` vs 기본 A/B 결과가 기록된다. 개선이 없으면 래퍼 기본값을
  `flashnext` 로 되돌리고 그 판단을 남긴다
- [ ] **USE-04**: `docs/manual/01-cli.md` 에 사용법이, `docs/cline-config-pins.md` 에 별칭과
  파라미터가 고정값으로 기록된다. **`--thinking` 이 현재 400 이라는 사실**도 명시된다
- [ ] **USE-05**: `docs/plan-act-reasoning-design.md` / `-implementation.md` 가 실측 결과로 갱신된다

## Future Requirements (v1.2+)

- **`--compaction basic` 검증** — 근인 행렬이 지목한 유일한 유망 미테스트 지렛대
- **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 듣지 않는 문제의 실질적 해결
- **Kanban·Telegram 표면 적용** — 커넥터의 `mode: act|plan` 옵션 활용
- **Phase 1 VERIFICATION.md 보강** — v1 의 유일한 미검증 페이즈

## Out of Scope

| Feature | Reason |
|---------|--------|
| `allowed_openai_params` 로 `--thinking` 통과시키기 | 별칭 주입이 더 단순하고 Cline 무수정. 400 을 만나지 않는다 |
| `drop_params: true` | 파라미터를 조용히 버린다. 200 이 나오지만 아무 일도 안 일어난다 |
| role_shim 에서 프롬프트로 모드 추론 | Cline 내부 시스템 프롬프트 문자열에 결합. 자동 업데이트(CFG-05 미해결)로 조용히 깨진다 |
| Cline 포크 | 별칭으로 충분하다. v1 에서 contextWindow 때 검토했다가 설정으로 해결된 전례 |
| `thinking_budget` 으로 사고 길이 제한 | drafter 부착 상태에서 500. 이 구성에서 불가능 |
| `reasoning_effort: high` | 모델이 500 으로 거부 (`:8011` 직결 실측) |
| Kanban·Telegram 표면 | 사용자 결정 2026-09-01. CLI 만 |
| `--compaction basic`, CFG-05 | 사용자 결정 2026-09-01. v1.2+ 로 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PRB-01 | Phase 9 | Pending |
| PRB-02 | Phase 9 | Pending |
| PRB-03 | Phase 9 | Pending |
| PRB-04 | Phase 9 | Pending |
| CFG-11 | Phase 10 | Pending |
| CFG-12 | Phase 10 | Pending |
| CFG-13 | Phase 10 | Pending |
| CFG-14 | Phase 10 | Pending |
| CFG-15 | Phase 10 | Pending |
| VRF-01 | Phase 10 | Pending |
| VRF-02 | Phase 10 | Pending |
| VRF-03 | Phase 10 | Pending |
| USE-01 | Phase 11 | Pending |
| USE-02 | Phase 11 | Pending |
| USE-03 | Phase 11 | Pending |
| USE-04 | Phase 12 | Pending |
| USE-05 | Phase 12 | Pending |

**Coverage:**
- v1.1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-01*
