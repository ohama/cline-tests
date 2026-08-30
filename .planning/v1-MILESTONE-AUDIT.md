---
milestone: v1
audited: 2026-08-31
status: gaps_found
scores:
  requirements: 33/38 complete, 1 partial, 2 human_needed, 2 not met
  phases: 7/8 verified (Phase 1 has no VERIFICATION.md)
  integration: 7/7 standing gates green, all hops live-confirmed
  flows: 1/3 proven (headless, and only for tool-free prompts)
gaps:
  requirements:
    - "CFG-05: 호스트 cline 이 3.0.60 으로 드리프트 — 오늘 기준 거짓. 추적 표는 이번 감사에서 정정함"
    - "BCH-01: 고유 4개 과제 (5~8 하한 미달, 통과 0개) — 사용자 결정에 의한 정지점"
    - "NET-01 / NET-05: 미관측 (iPad 오프라인, 실토큰 시험 거절)"
    - "DOC-02: worktree 불가 — 사용자가 샌드박스 확장을 명시적으로 거절"
  integration:
    - "Phase 1 만 VERIFICATION.md 없음 — 검증자 도입 전 완료. 게다가 결론이 나중에 뒤집힌 페이즈"
  flows:
    - "iPad → Kanban: 서버측만 증명, 사람이 방문한 적 없음"
    - "iPhone → Telegram: 토큰 슬롯 비어 있음, 전체 경로 미실행"
    - "원격 표면에서 파일 수정 불가 (--no-tools / --auto-approve false) — 의도된 설계이나 PROJECT.md 서두보다 좁음"
tech_debt:
  - phase: 01
    items:
      - "VERIFICATION.md 부재 — 유일한 미검증 페이즈"
      - "Core Value 는 합성 회귀 테스트로만 증명됨. 실제 에이전트 부하에서는 아래 참조"
  - phase: 05
    items:
      - "재부팅 지속성은 프록시 증거 (실제 재부팅 없음; iogpu.wired_limit_mb 재적용 필요)"
  - phase: 06
    items:
      - "기존 공개 Funnel :8443 → 127.0.0.1:3000 존치 (범위 밖). 포트 3000 금지가 보상 통제"
      - "온와이어 시스템 프롬프트 미캡처"
  - phase: 07
    items:
      - "모델에 도달한 3개 과제 전부 fail-context — 압축이 발동했는데도"
  - phase: 08
    items:
      - "--auto-approve 자세 결정이 한 번도 내려지지 않음 (Kanban/Telegram 은 --no-tools 로 우회)"
---

# 마일스톤 v1 감사 — Cline 로컬 서버

**상태:** `gaps_found` — 다만 대부분은 **사용자가 알고 내린 결정**이고, 숨겨진 결함은 아니다.

## 1. 이 감사가 새로 찾은 것

### 1a. CFG-05 는 오늘 기준 거짓이었고, 추적 표가 그걸 반영하지 않고 있었다

`REQUIREMENTS.md` 추적 표는 CFG-05 를 `Complete` 로 표시하고 있었으나, 실측 결과 호스트
전역 설치는 **3.0.60** 이다 (`/opt/homebrew/lib/node_modules/cline/package.json`).
`CLINE_NO_AUTO_UPDATE=1` 은 이 자기-업데이트를 막지 못한다 — 프로젝트 내내 반복 재현됐다.

이 행이 틀린 채 남은 이유는 구조적이다: **Phase 1 은 검증자를 거치지 않은 유일한 페이즈**다.
나머지 일곱 페이즈는 모두 phase-close 에서 요구사항 상태를 실측과 대조했고, 그 과정에서
여러 낡은 행이 정정됐다. Phase 1 은 그 사이클을 한 번도 통과하지 않았다.

**이번 감사에서 정정했다.** 복구는 `ps` 로 실행 중 프로세스 없음 확인 후
`npm install -g cline@3.0.53`. 컨테이너 측 벤치 핀은 별도 설치라 영향 없다.

### 1b. Core Value 는 합성 테스트에서 증명됐고, 실제 에이전트 부하에서는 아니다

`PROJECT.md` 는 Core Value("32K 벽에 닿기 전 압축해서 작업이 죽지 않는 것")를 **달성됨**으로
기록한다. 합성 회귀 테스트 기준으로는 사실이다 — 필러 18개 완주, 압축 3회 이상, 서버 400 **0건**.

그러나 Phase 7 에서 모델에 도달한 **세 과제가 전부** 32K 천장에서 `fail-context` 로 죽었다.
그리고 이건 압축이 안 돌아서가 아니다 — `.compaction.json` 이 세 실행 모두에 존재하고,
`discord-trivia-approval-keyerror` 는 `tokensBefore: 26990` 에서 실제로 압축이 발동했다.

| 과제 | 턴 | 결과 |
| --- | ---: | --- |
| discord-trivia-approval-keyerror | 38 | fail-context |
| telegram-plugin-refactor | 6 | fail-context |
| v-edit-workspace-tests | 12 | fail-context |

즉 **압축은 작동하지만, 큰 도구 출력이 오가는 실제 에이전트 루프에서는 압축+오버슈트 예산을
앞지를 수 있다.** 이건 어느 문서도 과대주장하지 않았고 `docs/cline-bench.md` §4 와
`docs/manual/04-32k-operations.md` §7 이 정직하게 기록하고 있다 — 다만 "해결됨" 이라는 서술을
"임의의 실제 작업에서 해결됨" 으로 읽으면 안 된다.

### 1c. Phase 1 에 VERIFICATION.md 가 없다

여덟 페이즈 중 유일하다. 그리고 **결론이 나중에 뒤집힌 바로 그 페이즈**다(결과 ② → 오설정).
정정 자체는 모든 현재 문서에 올바르게 전파돼 있음을 확인했다(낡은 결론은 `docs/32k-compaction-policy.md`
§9 부록과 01-06 SUMMARY 하단의 명시적 정정 addendum 안에만 존재). 그러나 이 페이즈의 요구사항은
독립 검증을 받은 적이 없고, 1a 가 그 대가다.

## 2. 통합 — 라이브로 재확인, 산문이 아니라

체커가 이번 세션에 직접 재실행한 결과:

| 게이트 | 결과 |
| --- | --- |
| `verify_config.sh` | PASS (top-level 29000, 트리거 26100) |
| `verify_no_regression.sh` | INF03 PASS |
| `verify_sandbox.sh` | 16/16, CRITERION 4/4 |
| `verify_services.sh` | 15/15 |
| `verify_network.sh` | 24/24 |
| `verify_bench.sh` | 11/11 (두 런 디렉터리, B11 양쪽 PASS) |
| `check_manual_claims.sh` | 21/21 |
| `pytest phase-03 phase-04` | 24 passed |

두 체인 모두 홉별로 살아 있음을 확인: `tailscale serve :8444 → 18484 → 3484`,
`litellm :4000 → role-shim :8011 → mlx_vlm :8000`. LAN 거부 `rc=7` 재확인.
포트 3000 미점유. 여섯 서비스 pid 일치.

**교차 페이즈 계약은 실제 배선이다** — Phase 4 래퍼가 Phase 3 `run_sandboxed.sh` 를 유일한
진입점으로 exec 하고, Phase 5 서비스가 Phase 2 `restart_service.sh` 를 재사용하며,
Phase 7 이 Phase 1 의 top-level `contextWindow` 형태를 명시적으로 복제하고 `bench/` 를 제외한다.

## 3. 문서 간 모순 — 없음

압축 결론, cline 버전, worktree 가용성, 벤치 수치(N=4/M=3/P=0), 관측 vs 추론 표기를
전 문서에 걸쳐 대조했다. **낡은 사실을 현재로 주장하는 문서는 하나도 없었다.** 벤치 수치는
원시 파일시스템 증거에서 독립 재도출해 전 문서와 일치했다.

유일한 불일치가 1a 였고, 정정했다.

## 4. E2E 흐름 — 셋 중 하나만 증명됨

| 흐름 | 상태 |
| --- | --- |
| iPad → Tailscale → Kanban | 서버측 증명(200, WS 101). **사람이 방문한 적 없음** — 등록된 iPad 두 대 모두 오프라인. 덧붙여 Kanban CLI 에는 diff 리뷰 명령이 아예 없고 worktree 도 불가라, 실제로 리뷰 가능한 범위는 PROJECT.md 서두보다 좁다 |
| iPhone → Telegram | **전체 미실행.** 토큰 슬롯 비어 있음(라이브 plist 확인), 서비스는 문서화된 idle 분기에 머묾. 사용자가 실토큰 시험을 거절 |
| 헤드리스 → 샌드박스 → 로컬 모델 | **증명됨, 단 도구 없는 프롬프트에 한해.** `--auto-approve false` 가 모든 도구 호출을 즉시 거부 |

**이 배포에서 원격으로 트리거되는 어떤 경로도 파일을 수정할 수 없다** — Telegram 은 `--no-tools`,
헤드리스는 `--auto-approve false`. 의도적이고 세 곳에 명시돼 있지만, PROJECT.md 서두의
"코딩 작업을 시키고 결과를 리뷰한다" 는 현재 배포에서 **리뷰 쪽만** 참이다.

## 5. 열린 항목 전체

1. **CFG-05** — 호스트 cline 3.0.60 드리프트. 지속적 수단 없음, 수동 재설치가 유일
2. **NET-01** — iPad 미방문 (`phase-06/IPAD-CHECKLIST.md`)
3. **NET-05** — Telegram 표시 미관측 (`.../20260830T071532Z-net05/decision.md`)
4. **Telegram 토큰 미주입** — 토큰-존재 경로 미실행, 첫 기동에서 `unknown option` 가능
5. **BCH-01** — 고유 4개(하한 5), 통과 0개. 사용자 결정 정지점
6. **실제 부하에서의 fail-context** — 압축 발동에도 3/3 이 32K 천장에서 사망 (1b)
7. **DOC-02 worktree** — 불가. 정확한 수정안과 비용은 `phase-08/results/20260830T193634Z-widening/DECISION.md`
8. **재부팅 지속성** — 프록시 증거. 실제 재부팅은 `iogpu.wired_limit_mb` 재적용 필요
9. **기존 공개 Funnel** `:8443 → 3000` 존치. 포트 3000 금지가 보상 통제
10. **`--auto-approve` 자세 결정 미결** — Phase 4 부터 이월, 두 표면이 `--no-tools` 로 우회
11. **온와이어 시스템 프롬프트 미캡처**
12. **Phase 1 VERIFICATION 부재** (1c)

## 6. 판단

배선은 적대적 재검증을 견뎠고, 문서의 정직성 규율은 이례적으로 강하다 — 증명되지 않은 것을
증명된 것으로 주장하는 문서를 하나도 찾지 못했다.

`gaps_found` 인 이유는 결함이 숨어서가 아니라, **미충족 항목이 실재하고 그중 다섯은 사용자가
비용을 보고 내린 결정**이기 때문이다. CFG-05 만이 결정이 아닌 환경 드리프트이고, 이번 감사가
추적 표를 사실에 맞췄다.

**사람이 시간을 쓸 만한 순서:**
1. `npm install -g cline@3.0.53` — CFG-05 복구 (몇 분)
2. iPad 로 `https://ohama-2.tail318f12.ts.net:8444/` 접속 — NET-01 종결 (몇 분)
3. Telegram 토큰 주입 — NET-05 와 흐름 2 종결 (BotFather 필요)
4. 1b 를 받아들일지 결정 — 실제 에이전트 작업이 32K 에서 자주 죽는다면 컨텍스트 예산 재설계가 v2 과제
