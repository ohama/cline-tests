# Project Milestones: Cline 로컬 서버

## v1 Cline 로컬 서버 (Shipped: 2026-08-31)

**Delivered:** 로컬 Qwen3.8 Flash-Next 를 두뇌로 쓰는 Cline 상시 서버 — 부팅 자동 기동,
32K 컨텍스트 운용, Tailscale 을 통한 iPad/iPhone 접근, 한글 사용 매뉴얼.

**Phases completed:** 1–8 (55 plans total)

**Key accomplishments:**

- **압축 기구를 소스 수준에서 규명했다.** `contextWindow` 가 `providers.json` 의 `settings`
  최상위 필드이고 `models[]` 는 CLI 가 읽지 않음을 `provider-settings.ts:150/266` 로 확정.
  트리거는 `maxInputTokens × 0.9`. 이 발견 전까지 자동 압축은 전혀 발동하지 않고 있었다.
- **세 표면을 launchd 상시 서비스로 올렸다.** Kanban(:3484) · Telegram 커넥터 · 헤드리스 래퍼가
  같은 에이전트 코어와 같은 로컬 모델을 공유하며, 죽으면 스스로 복구한다.
- **원격 접근을 열되 경계를 그었다.** Tailscale 무인증 + LAN 토큰 게이팅, `sandbox-exec` OS 수준
  샌드박스, 저장소 화이트리스트, 포트 3000 금지(기존 공개 Funnel 회피).
- **기존 검증된 추론 스택을 건드리지 않았다.** litellm→role-shim→mlx_vlm.server 체인은
  동시성 상한과 노출 차단이라는 두 줄의 보정 외에는 그대로다.
- **틀린 결론을 두 번 정정하고 기록으로 남겼다.** "압축 불가" → "최상위 설정으로 해결" →
  "합성에서는 작동하나 실제 부하에서는 프루닝하지 않음". 각 단계의 증거와 정정 경위가
  `docs/32k-compaction-policy.md` 에 남아 있다.
- **한글 매뉴얼 5편을 실제 출하된 것 기준으로 썼다.** 과대주장 방지 스윕 8/8 통과.

**Stats:**

- 3,326 files changed, 171,472 insertions
- shell 9,936줄 · python 2,004줄 · docs 2,832줄
- 8 phases, 55 plans, 276 commits
- 3일 (2026-08-29 → 2026-08-31)

**Accepted as tech debt:**

- **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 cline 자동 업데이트를 막지 못한다 (3.0.53↔3.0.60 반복)
- **BCH-01** — cline-bench 고유 4과제, **통과 0개**. 실제 에이전트 부하에서 압축이 프루닝하지 않아
  32K 천장에서 사망. `contextWindow` 는 이 결함의 지렛대가 아님
- **NET-01 / NET-05** — iPad 오프라인·실토큰 시험 거절로 미관측
- **DOC-02** — worktree 불가 (샌드박스 확장 거절)
- **Phase 1 VERIFICATION.md 부재** — 결론이 두 번 뒤집힌 유일한 미검증 페이즈

**What's next:** `--compaction basic` 검증(유일한 유망 미테스트 지렛대), CFG-05 드리프트 해결,
실사용 후 매뉴얼 보정.

---
