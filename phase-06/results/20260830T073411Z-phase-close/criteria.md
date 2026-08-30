# Phase 6 phase-close — ROADMAP 다섯 성공 기준 매핑

`RD = phase-06/results/20260830T073411Z-phase-close`. 아래 다섯 항목은 ROADMAP.md Phase 6
Success Criteria 1-5 를 그대로 순서대로 옮긴 것이다. 어떤 기준도 격상하지 않았다.

## Criterion 1 — iPad Safari 로 접속해 카드 목록을 보고 diff 를 리뷰할 수 있다

**Status: `human_needed`**

서버 쪽 절반은 실측으로 성립한다 — 증거는
`phase-06/results/20260830T070109Z-opening2/gate-network/run1/` (그리고 동일하게 재현된
`run2/`) 의 **`CASES 24/24` PASS 실행**이다. **06-04 자체는 증거 출처가 아니다** — 06-04 는
kanban 자체의 Host 화이트리스트에 막혀 `CASES 13/15` 로 FAIL 하고 즉시 롤백됐다
(`phase-06/results/20260830T060638Z-opening/gate-network/run1/`). 06-04 의 시도는 개방
메커니즘(`setup_tailscale_serve.sh`)이 정상 동작함을 증명했을 뿐, NET-01 의 증거로 인용되지
않는다.

iPad 쪽 절반은 수행되지 않았다: `phase-06/IPAD-CHECKLIST.md` 가 그 절차를 담고 있으나, 두
iPad(`ipad-mini-6th-gen-wifi`, `ipad165`) 모두 현재 tailnet 에서 오프라인(각각 마지막 접속
29일 전, 4일 전)이라 실행 자체가 아직 안 됐다.

## Criterion 2 — 같은 LAN(비-Tailscale IP)에서 토큰 없이 접근을 시도하면 거부된다

**Status: `met`**

LAN IP(`192.168.75.108`)에서 kanban(3484)과 8444 양쪽 모두에 대한 연결 자체가 거부됨이
실측됐다 — `phase-06/results/20260830T070109Z-opening2/manual/`. 여기에 더해 두 애플리케이션
모두 loopback 전용 바인딩임이 `$RD/gate-network/gate-network-verdict.txt` 의
`kanban-bind-loopback-only`/`proxy-bind-loopback-only`/`lan-refused-kanban-port`/
`lan-refused-serve-port`/`proxy-lan-refused` 다섯 체크로 재확인됐다(모두 PASS, 이번 스윕에서
재실행).

**해석 노트**: 이건 "토큰으로 거부됨"이 아니라 "LAN 으로 가는 길 자체가 없음"이다 — 요구사항의
문자 그대로의 메커니즘(토큰)이 아니라 그보다 강한 것으로 만족시켰다. 자세한 설명은
`docs/network-exposure.md` §4c.

## Criterion 3 — 이 프로젝트가 만든 어떤 서비스도 포트 3000 을 점유하지 않는다

**Status: `met`**

`lsof -nP -iTCP:3000` 이 빈 결과 — 이번 스윕 시점(`$RD/invariants/invariants.txt`)에 재확인,
동시에 두 개의 독립된 상시 게이트가 매번 이걸 재확인한다: `verify_network.sh` 의
`port-3000-unbound` 체크(`$RD/gate-network/verify_network-verdict.txt`)와
`verify_services.sh` 의 `port-hygiene-no-3000` 체크(`$RD/gate-services/verify_services-verdict.txt`).

이 Mac 에는 이 프로젝트 이전부터 존재하는, 여전히 살아 있는 공용(public) Funnel 항목
(`:8443 -> 127.0.0.1:3000`)이 있다 — 이 프로젝트가 만든 게 아니므로 범위 밖이고, 그래서 포트
3000 이 절대 이 프로젝트에 의해 점유돼서는 안 되는 이유가 된다. 전체 설명:
`docs/network-exposure.md` §3c.

## Criterion 4 — `--allowed-user-id` 없이 Telegram 커넥터를 기동하면 즉시 기동 실패한다

**Status: `met`**

실제 launchd 기동 실패로 실측됐다 — `phase-06/results/20260830T052342Z-net04/launchd/`:
임시 라이브 plist 로 토큰은 있고 id 는 없는 상태를 유도해 `restart_service.sh` 가 RC=1 을
반환했고, 90초/9샘플 동안 connector 프로세스가 0 이었으며 `ABORT-NET04` 카운트가 1→4 로
누적됐다(launchd 가 `ThrottleInterval` 마다 재시도하며 계속 거부당함을 증명). 강제 지점은
`run_telegram_service.sh` 로 이름 명시(`docs/network-exposure.md` §4d) — **cline 바이너리
자체가 아니다.** 이번 스윕에서 정적/행위 두 체크(`net04-guard-present`, `net04-guard-refuses`)
모두 재확인 PASS(`$RD/gate-network/verify_network-verdict.txt`).

## Criterion 5 — 32K 근처 요청 중 Kanban 카드와 Telegram 대화 양쪽 모두에서 "작업 중" 상태가 시각적으로 확인된다

**Status: `human_needed`**

Kanban 상태 표면은 서버 쪽으로 실측 성립했다 — 보드가 loopback 과 tailnet 양쪽에서
byte-identical 하게 200 을 반환함이 `phase-06/results/20260830T071532Z-net05/board-fetch-both-paths.txt`
에 증명돼 있다. 시각적 확인("In Progress" 칼럼이 실제 대기 중 유지되는지)은 사람이 직접 봐야
하는 항목이다(criterion 1 과 같은 status) — `phase-06/IPAD-CHECKLIST.md` 4a 항목.

Telegram 쪽은 정적 근거만 있다: 88MB 바이너리 안에 반복 없는 `sendChatAction("typing")` 호출
지점 정확히 1곳, Telegram 자체가 약 5초 뒤 typing 을 소멸시킴, 재발화 루프 없음, 스트리밍은
출력 토큰이 생긴 뒤(프리필 종료 후)에만 시작 — 이는 "확률적으로 버티지 못할 것"이라는 추정만
줄 뿐 관측이 아니다. 06-05 에서 사용자가 실토큰 라이브 트라이얼을 **거절**했다
(`phase-06/results/20260830T071532Z-net05/decision.md`) — 그래서 이 절반은 여전히 열린 질문이며
**절대 "확인됨"으로 격상하지 않는다.**

## 요약

| # | 기준 | Status(위 절 참고) | 핵심 증거 |
|---|---|---|---|
| 1 | iPad Safari + Tailscale, 카드/diff 리뷰 | 사람 확인 필요 | `phase-06/results/20260830T070109Z-opening2/gate-network/` (24/24, 06-04.2), `phase-06/IPAD-CHECKLIST.md` |
| 2 | LAN 비-Tailscale, 토큰 없이 거부 | met | `phase-06/results/20260830T070109Z-opening2/manual/` |
| 3 | 포트 3000 미점유 | met | `$RD/invariants/invariants.txt`, `$RD/gate-network/`, `$RD/gate-services/` |
| 4 | `--allowed-user-id` 없이 기동 실패 | met | `phase-06/results/20260830T052342Z-net04/launchd/` |
| 5 | 32K 근처 "작업 중" 양쪽 표면 확인 | 사람 확인 필요 | `phase-06/results/20260830T071532Z-net05/`, `phase-06/IPAD-CHECKLIST.md` |

**정확히 두 기준(1, 5)만 위 "Status" 절에서 사람이 직접 확인해야 하는 상태로 남아 있다 — 다른
어떤 것도 격상하지 않았다.**
