# Phase 6 네트워크 노출 기록 (NET-01~05)

## 1. 결론 (한 줄)

kanban 은 이제 `https://ohama-2.tail318f12.ts.net:8444/` 로 tailnet 멤버(`ohama100@`)에게만
실제로 도달 가능하다 — 그 외에는 아무것도 바뀌지 않았고, LAN 과 공용 인터넷에는 이 경로로
들어올 길이 전혀 없다.

## 2. 무엇을 열었나

06-04.2 에서 실제로 실행된 명령은 정확히 하나다:

```
tailscale serve --bg --https=8444 http://127.0.0.1:18484
```

(`phase-06/net/setup_tailscale_serve.sh --apply` 가 여섯 개 사전점검(P1-P6, 06-04.1 이 추가한
P5b 포함) 뒤에 이 한 줄만 실행하고, 다섯 개 사후단언(Q1-Q5)으로 결과를 즉시 재확인한다.)

결과로 생긴 항목은 `tailscale serve status --json` 의 `Web` 아래 새 키
`ohama-2.tail318f12.ts.net:8444` 하나뿐이며, 대상은 `http://127.0.0.1:18484`(kanban 자신이
아니라 06-04.1 이 만든 Host/Origin 재작성 프록시)다. 기존 세 핸들러(`:443`, `:10000`, `:8443`)와
`AllowFunnel` 의 유일한 키(`ohama-2.tail318f12.ts.net:8443`)는 이 명령 전후로 byte-identical —
`phase-06/net/expected_serve_baseline.json` 에 동결돼 있다.

kanban 자기 자신은 이 phase 내내 `127.0.0.1:3484` 단독 바인딩을 유지했고, 이 개방을 위해 단 한
번도 재시작되지 않았다(pid `53894` 는 06-01 베이스라인부터 지금까지 불변). 바뀐 것은 kanban
앞에 무엇이 서 있느냐뿐이다.

**연결 체인:**
```
tailscale serve :8444 (tailnet only)
  -> com.ohama.kanban-proxy, 127.0.0.1:18484 (Host/Origin 재작성)
    -> com.ohama.kanban, 127.0.0.1:3484
```
두 애플리케이션(kanban, kanban-proxy) 모두 loopback 이 아닌 인터페이스에 바인딩한 적이 없다.

## 3. 왜 이렇게 골랐나

### 3a. 왜 `tailscale serve` 이고 공용 노출 모드는 절대 아닌가

`tailscale serve` 는 인증된 tailnet 멤버(이 경우 `ohama100@`)로 접근을 제한한다 — 이 phase
전체가 만족해야 하는 NET-01/NET-02 의 전제다. 이 문서와 `phase-06/net/` 의 모든 스크립트는
공용으로 노출하는 그 다른 서브커맨드를 이 phase 의 어떤 산출물에서도 절대 실행하지 않는다 —
`phase-06/net/` 에 그 서브커맨드 이름이 `tailscale` 이라는 단어와 같은 줄에 등장한 적이 한
번도 없고, `verify_network.sh` 자신의 상시 체크(`no-public-exposure-command-in-repo`)가 이
사실을 매 실행마다 재확인한다.

### 3b. 왜 포트 8444 인가

3000, 443, 8443, 10000 은 각각 다음 이유로 제외됐다:
- **3000** — 아래 3c 참고. 절대 바인딩되어서는 안 되는 포트.
- **443, 10000** — 이 프로젝트 이전부터 존재하는 두 개의 tailnet-only 핸들러가 이미 점유 중
  (각각 `127.0.0.1:8787`, `127.0.0.1:8788` 로 프록시). 이 프로젝트 소유가 아니다.
- **8443** — 이 프로젝트 이전부터 존재하는, 유일하게 공용으로 열려 있는(`Funnel on`) 핸들러가
  이미 점유 중(`127.0.0.1:3000` 으로 프록시). 아래 3c 참고.

`8444` 는 `lsof -nP -iTCP:8444` 로 미점유가 확인된 뒤 `phase-06/net/config.env` 에 한 번만
고정됐다.

### 3c. 포트 3000 은 반드시 미바인딩 상태로 남아야 한다 — 그리고 그 이유

**이 Mac 에는 이 프로젝트 이전부터 존재하는, 지금도 살아 있는 공용(public) 항목이 하나 있다:
`:8443 (Funnel on) -> http://127.0.0.1:3000`.** 이것은 이 프로젝트가 만들지 않았고, 사용자의
결정으로 이 phase 의 범위 밖에 있다 — 기록만 하고 절대 건드리지 않는다.

이게 왜 위험한가: `tailscale serve` 와 달리, 이 기존 핸들러는 tailnet 로그인을 요구하지 않는
공용 Funnel 이다. **포트 3000 에 바인딩하는 것은 무엇이든 — 이 프로젝트가 만든 것이든, 나중에
누군가 "그냥 확인해보려고" 띄운 것이든 — 즉시 Tailscale 로그인 없이 전 세계에서 접근 가능해진다.**
`phase-06/net/config.env` 의 `FORBIDDEN_SERVE_PORTS` 에 3000 이 포함돼 있고, `verify_network.sh`
가 매 실행마다 `lsof -nP -iTCP:3000` 이 비어 있음을 재확인한다(`port-3000-unbound` 체크).

**미래의 누군가에게: 포트 3000 이 비어 있는 것을 보고 "친절하게" 무언가를 그 위에 띄우지
말 것 — 그 순간 이미 존재하는 이 공용 Funnel 뒤로 들어가 인증 없이 공개된다.**

### 3d. 왜 kanban 의 바인딩을 절대 바꾸지 않았나

kanban 자신의 원격 접근 패스코드 게이트(`isKanbanRemoteHost()`)는 연결마다 판정되는 게 아니라,
프로세스 시작 시 `--host` 플래그 값 하나로 전역적으로 단 한 번 결정된다. 그래서 LAN 인터페이스에
바인딩해 LAN 용 패스코드를 얻으려 하면, 그 패스코드 게이트가 tailnet 트래픽 앞에도 똑같이
켜져버려 이 phase 가 만들려는 "tailnet 멤버는 무인증" 속성이 깨진다. 프로세스 하나가 두 가지
바인딩 정책(LAN 은 패스코드, tailnet 은 무인증)을 동시에 가질 수 없다 — 그래서 kanban 은 계속
`--host 127.0.0.1 --port 3484` 로만 남고, tailnet 노출은 전적으로 앞단 프록시(`tailscale serve`
+ `kanban-proxy`)가 담당한다.

## 4. 한계 — 두 가지는 사람이 확인해야 한다

**이 절이 이 문서에서 가장 눈에 띄어야 한다.**

### 4a. NET-01 의 iPad 절반

서버 쪽은 증명됐다: tailnet 주소가 신뢰된 인증서와 무-패스코드 상태로 보드를 반환한다는 것이
이 Mac 에서 MagicDNS 이름으로 실측 확인됐다(`phase-06/results/20260830T070109Z-opening2/gate-network/`
의 `CASES 24/24` 실행 — 06-04 자체가 아니다; 06-04 는 kanban 자체 Host 화이트리스트에 막혀
`CASES 13/15` 로 FAIL 하고 즉시 롤백됐으므로 증거 출처가 아니다).

증명되지 않은 것: iPad Safari 가 실제로 이걸 렌더링하는지, 카드와 diff 가 iPad 폭에서 실제로
사용 가능한지. **두 iPad 모두 현재 tailnet 에서 오프라인**(`ipad165` 마지막 접속 4일 전,
`ipad-mini-6th-gen-wifi` 마지막 접속 29일 전)이며 Tailscale 재로그인이 필요할 가능성이 높다.
`phase-06/IPAD-CHECKLIST.md` 를 따를 것.

### 4b. NET-05 의 Telegram 절반

정적 근거(88MB 바이너리 안에 반복 없는 `sendChatAction("typing")` 호출 지점 정확히 1곳, 수신
메시지당 1회만 발화, Telegram 자체 프로토콜이 typing 표시를 약 5초 뒤 소멸시킴, 재발화 루프
전혀 없음, 리치-드래프트 스트리밍은 출력 토큰이 실제로 생긴 뒤에만 시작 — 즉 ~64초 프리필 대기가
끝난 다음)는 typing 표시가 그 대기를 버티지 못할 것이라고 **추정할 근거**를 준다.

06-05 에서 사용자에게 실토큰 라이브 트라이얼 여부를 물었고, **사용자는 거절(decline)했다** —
어떤 봇도 실제로 기동되지 않았고, 아무도 실제 Telegram 클라이언트를 지켜본 적이 없다. 그래서 이
질문은 여전히 열려 있다: 정적 증거상 **확률적으로는 아닐 것**이지만, **관측된 적은 없다.** 이
문서도, 다른 어떤 이 프로젝트 문서도 이걸 "확인됨"으로 격상해 쓰지 않는다.
`phase-06/results/20260830T071532Z-net05/decision.md` 에 사용자가 나중에 직접 이 트라이얼을
수행할 수 있는 7단계 체크리스트가 남아 있다.

### 4c. NET-02 의 해석 — 토큰이 아니라 "길 자체가 없음"

요구사항 문구는 "같은 LAN 의 기기는 토큰 없이 Kanban 에 접근하지 못한다"다. 이 phase 가 실제로
만든 것은 그보다 강하고 단순하다: **LAN 인터페이스에 바인딩된 게 아무것도 없다 — kanban 도,
kanban-proxy 도 — 그래서 애초에 토큰을 두고 말할 대상 자체가 없다.** LAN IP(`192.168.75.108`)
에서 3484/8444/18484 모두 연결 자체가 거부된다(connection refused, 응답 거부가 아니라 경로
없음) — `phase-06/results/20260830T070109Z-opening2/manual/` 에 실측.

이게 요구사항의 의도를 만족시키는 이유: 요구사항이 막으려는 것은 "LAN 기기가 인증 없이 접근하는
것"이고, 접근할 경로 자체가 없는 것은 그 상위 집합이다. 다만 진짜 LAN+패스코드 경로(kanban 이
이미 그 메커니즘을 갖고 있다)는 나중에 별도의, 명시적인 결정으로 여전히 가능하다 — 이 phase 의
부산물로서가 아니라.

### 4d. NET-04 의 메커니즘 — 래퍼의 보장이지, cline 바이너리의 보장이 아니다

보장하는 것은 우리가 launchd 로 감독하는 서비스가 숫자형 allowlist id 없이는 시작을 거부한다는
것이다. 강제하는 지점은 `phase-05/services/run_telegram_service.sh` 다 — 토큰이 있는데
`TELEGRAM_ALLOWED_USER_ID` 가 없거나 비어 있거나 숫자가 아니면 `ABORT-NET04` 를 찍고 exit 1,
`cline` 은 절대 실행되지 않는다. **`cline` 바이너리 자체(3.0.53)는 `--allowed-user-id` 없이도
문제없이 시작한다 — 실측으로 확인됐다.** 요구사항의 의도는 만족되지만, 문자 그대로의 메커니즘은
다르다: 이건 CLI 의 보장이 아니라 우리 래퍼의 보장이다.

## 5. 운영

```
bash phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline
```

이것이 상시 게이트다 — 네트워크 태세를 바꾸는 모든 작업 전/후에 돌릴 것, 그리고
`phase-05/services/verify_services.sh` 와 나란히 돌릴 것. 둘 다 read-only, 재실행 가능. 현재
정상 신호는 `CASES 24/24`(24 개 체크 전부 PASS, NET-01~04 를 아우름).

## 6. 롤백

```
tailscale serve --https=8444 off
```

이 한 줄이 kanban 의 `:8444` 항목을 제거한다(`phase-06/net/config.env` 의
`TS_SERVE_ROLLBACK_CMD`, 06-03 에서 스크래치 포트로 실측 확인됨). **`tailscale serve reset` 은
절대 쓰지 말 것** — 전체 serve 설정을 지워버려 이 프로젝트 이전부터 있던 두 핸들러와 공용 Funnel
키까지 함께 사라진다.

실행 후 확인할 것: `tailscale serve status --json` 이 기존 세 핸들러(`:443`, `:10000`, `:8443`)와
`AllowFunnel` 의 단일 키(`ohama-2.tail318f12.ts.net:8443`)로 정확히 돌아왔는지 —
`phase-06/net/expected_serve_baseline.json` 과 byte-identical 이어야 한다. `verify_network.sh`
는 이 닫힌 상태에서 `CASES 21/24`(06-04.1 이 세운 신호, 프록시가 이미 loopback 에 등록돼 있을
때) 를 보여야 정상이다.

## 7. 토큰과 사용자 ID 주입

`TELEGRAM_BOT_TOKEN` 과 `TELEGRAM_ALLOWED_USER_ID` 두 슬롯은 반드시 함께 채워야 한다 — 하나만
채우면 4d 의 가드가 즉시, 크게 실패한다(`ABORT-NET04`, exit 1). 이건 조용히 무제한 봇이 뜨는
사고를 막기 위한 의도된 설계다. 정확한 절차, 순서, 그리고 `unknown option` 크래시루프 감시
사항은 `docs/services.md` §6 을 그대로 참고할 것 — 여기서 다시 쓰지 않는다.

## 8. 증거

| 무엇 | 경로 |
|---|---|
| 변경 전 베이스라인(4개 상시 게이트 + 네트워크 인벤토리) | `phase-06/results/20260830T051403Z-baseline/` |
| NET-04 증명(래퍼 가드, 실제 launchd 기동 실패 실증 + 원복) | `phase-06/results/20260830T052342Z-net04/` |
| 스크립트 오프라인 자가검증(닫힌 상태 음성 대조군 `CASES 13/15`) | `phase-06/results/20260830T055744Z-authoring/` |
| 첫 개방 시도 — kanban Host 화이트리스트에 막혀 롤백(BLOCKED) | `phase-06/results/20260830T060638Z-opening/` |
| Host/Origin 재작성 프록시 — 루프백 전량 실증, 네트워크는 계속 닫힌 채 | `phase-06/results/20260830T064219Z-proxy/` |
| 개방(2차 시도, 성공) — `CASES 24/24`, NET-01 서버측/NET-02/NET-03 실증 | `phase-06/results/20260830T070109Z-opening2/` |
| NET-05 증거 + 실토큰 트라이얼 거절 결정 기록 | `phase-06/results/20260830T071532Z-net05/` |
| Phase-close 게이트 스윕 + `criteria.md` | `phase-06/results/<UTC>-phase-close/` |

## 9. Phase 7·8 인계

- Phase 7 은 벤치 과제를 돌리기 전/후 `bash phase-06/net/verify_network.sh --baseline
  phase-06/results/20260830T051403Z-baseline` 를 그대로 호출해야 한다 — `CASES 24/24` 가 현재
  정상 신호다.
- Phase 8 의 매뉴얼은 4a/4b 의 두 gap 을 그대로 gap 으로 옮겨 써야 한다 — "확인됨"으로 격상하지
  말 것. iPad 진입점은 반드시 tailnet 주소(`https://ohama-2.tail318f12.ts.net:8444/`)를 써야
  한다(다른 주소가 아니다).
- **2026-08-30 정정 사항을 그대로 유지할 것**: `settings.contextWindow` 는 `29000`, 압축
  트리거는 `26100` — `32768`/`26542`/`models[]` 를 재사용하지 말 것. 압축은 정상 작동한다.
- **Phase 3 소유의 미해결 항목 — Phase 7/8 이 걸려 넘어질 것**: 라이브 kanban 서버의 샌드박스가
  `~/.gitconfig` 파일 읽기를 거부해서, 이 샌드박스 상태로는 어떤 git 기반 프로젝트도 kanban 에
  등록할 수 없다(`kanban task list --column in_progress` 가 exit 1). 06-05 에서 발견됐고
  Rule 4(아키텍처/보안 경계 변경)로 판단해 고치지 않았다 — Phase 3 이 소유한 하드닝된 샌드박스
  allowlist 를 완화하거나, 라이브 서비스를 별도 `GIT_CONFIG_GLOBAL` 로 재기동해야 한다. Phase 7
  이 벤치 과제로 kanban 에 프로젝트를 등록하려 하거나 Phase 8 이 매뉴얼에서 "카드 목록이 보인다"
  이상을 요구하면 즉시 재발한다 — 전체 근본원인은
  `phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt`.
- **kanban-proxy 는 의도적으로 샌드박스되지 않는다.** 소스(`phase-06/net/`)가
  `workspace/sandbox.sb` 로 펀치되지 않은 경로에 있고, 샌드박스하려면 `EXTRA_ALLOW_PATHS` 를
  넓혀야 하는데 이 값은 phase 시작부터 끝까지 빈 값으로 남아야 한다(하우스 룰). 이 프로세스는
  사용자/에이전트가 제공한 코드를 전혀 실행하지 않고 launchd 가 연 로그 fd 외에는 런타임에 어떤
  파일 경로도 건드리지 않으므로, 샌드박스의 실제 위협 모델(에이전트 주도 코드 실행 격리)이
  애초에 적용되지 않는다 — 06-04.1 의 결정, 여기서 재확인.
- **`--no-tools`/`--auto-approve false` 태세는 두 표면 모두 읽기·대화 전용으로 만든다.** kanban
  은 보드를 보여줄 뿐 쓰기 API 를 노출하지 않고, telegram-connect 는 `--no-tools` 로 기동된다
  (`docs/services.md` §3). 즉 원격에서 트리거된 에이전트가 파일을 수정할 수 없다는 뜻이다. 이
  태세를 뒤집는 것(도구 허용)은 `docs/headless-wrapper.md` §4 가 이미 못박은 대로 HLS-02 가
  정의하는 보안 태세 자체의 변경이며, **절대 조용히 결정해서는 안 된다** — 사람에게 반드시
  에스컬레이션해야 하는 결정이다. Phase 6 은 이 결정을 내리지 않았고, Phase 7/8 도 조용히 내려서는
  안 된다.

---
*Phase: 06-network-exposure*
*Completed: 2026-08-30*
