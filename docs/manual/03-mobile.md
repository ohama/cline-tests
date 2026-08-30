# 03. iPad·iPhone 사용법

근거 문서: docs/network-exposure.md §2·§4a·§4b·§4c·§5·§6, docs/services.md §6,
phase-06/IPAD-CHECKLIST.md.

이 문서는 **사용법**이다 — 왜/어떻게 검증됐는지는 위 근거 문서들을 볼 것, 여기서는 반복하지
않는다.

## 1. Tailscale 접속

진입점은 정확히 하나뿐이다. 다른 주소는 없다:

```
https://ohama-2.tail318f12.ts.net:8444/
```

연결 체인은 세 단계다:

```
tailscale serve :8444 (tailnet 멤버만, ohama100@)
  -> com.ohama.kanban-proxy, 127.0.0.1:18484 (Host/Origin 재작성)
    -> com.ohama.kanban, 127.0.0.1:3484
```

두 애플리케이션(kanban, kanban-proxy) 모두 loopback 이 아닌 인터페이스에 바인딩한 적이 없다.

**성공:** 칸반 보드가 바로 뜬다 — 암호(passcode) 입력창이 없고, 인증서 경고도 없다.

## 2. ⚠️ [GAP-IPAD] iOS 기기에서 실제로 확인된 적은 없다

이 tailnet 주소를 iOS 기기에서 방문해본 사람은 아직 아무도 없다. 두 iPad
(`ipad-mini-6th-gen-wifi`, `ipad165`)는 작업 시점에 둘 다 tailnet 에서 오프라인이었다(각각
마지막 접속 29일 전 / 4일 전). 서버 쪽은 증명됐다(`CASES 24/24`) — 열려 있는 것은 NET-01 의
클라이언트(iPad) 절반이다.

**검증 절차를 여기서 다시 쓰지 않는다.** `phase-06/IPAD-CHECKLIST.md` 를 그대로 따를 것 — 이
문서 하나만 열어서 독립적으로 따라 할 수 있도록 이미 작성돼 있다. 이 gap 을 닫는 것은 사용자
자신의 몫이다.

## 3. LAN 에서는 아예 접근할 수 없어야 정상

```
http://192.168.75.108:3484/
```

**성공 조건은 "가는 길 자체가 없음"이다 — "거부됨"이 아니다.** 무엇이든 응답이 오면(에러
페이지 포함) 그건 LAN 으로 새고 있다는 뜻이고, 즉시 보고해야 한다. kanban/kanban-proxy 어느
쪽도 LAN 인터페이스에 바인딩된 적이 없으므로, 정상적인 결과는 연결 자체가 되지 않는 것이다.

## 4. ⚠️ [GAP-PORT3000] 포트 3000 은 절대 바인딩하면 안 된다

이 프로젝트 이전부터 존재하는, 지금도 살아 있는 **공용(public)** Funnel 핸들러
(`:8443 (Funnel on) -> http://127.0.0.1:3000`)가 있다. 이건 이 프로젝트가 만들지 않았고,
사람의 결정으로 범위 밖에 남아 있다. 이게 왜 위험한가: 포트 3000 에 바인딩하는 것은 무엇이든
— 이 프로젝트가 만든 것이든, 나중에 누군가 "그냥 확인해보려고" 띄운 것이든 — 즉시 Tailscale
로그인 없이 전 세계에서 접근 가능해진다. 이 규칙은 이 phase 한정이 아니라 **영구적**이다.

## 5. Telegram 대화 · 승인/거부

**⚠️ [GAP-TELEGRAM-TOKEN]** 토큰 슬롯은 지금 비어 있다. 커넥터는 등록·감독되고 있지만 의도적으로
무력(inert) 상태다 — 살아 있는 봇이 없다. 실제 토큰이 주입된 코드 경로는 단 한 번도 실행된
적이 없다.

주입 절차는 `docs/services.md` §6 에 있다 — 여기서 그 레시피를 다시 적지 않는다. 다만 실패
방식과 직결된 세 가지 경고는 이 매뉴얼에도 남겨둔다:

- 토큰 주입 후 **첫 재시작**이 실제 호출 줄이 처음으로 파싱되는 순간이다. 커넥터 로그
  (`~/.cline/logs/telegram-connect.log`/`.err`)에서 `unknown option` 을 반드시 감시할 것.
- `--provider`/`--model` 은 반드시 풀네임으로 유지해야 한다 — `cline connect telegram` 에는
  `-P` 짧은 플래그가 아예 없고, `-m` 은 `--model` 이 아니라 `--bot-username` 에 바인딩돼
  있다.
- `TELEGRAM_BOT_TOKEN` 과 `TELEGRAM_ALLOWED_USER_ID` 는 반드시 함께 채워야 한다 — 하나만
  채우면 래퍼가 즉시 큰 소리로 실패한다(설계된 동작).

**승인/거부에 대해:** 커넥터는 `--no-tools` 로 뜬다. 따라서 **읽기·대화 전용**이며, 도구
동작에 대한 승인/거부 프롬프트 자체가 발생하지 않는다 — 도구 호출이 애초에 일어나지 않기
때문이다. 아무도 도달할 수 없는 승인 UI 를 설명하지 않는다.

## 6. ⚠️ [GAP-TELEGRAM-INDICATOR] 긴 대기 중 Telegram 화면에 무엇이 뜨는지는 관측된 적이 없다

실토큰 라이브 트라이얼은 사용자가 거절해서 아무도 실제 Telegram 클라이언트를 지켜본 적이
없다. 정적 근거(타이핑 표시기는 메시지 하나당 딱 한 번만 발화하고, Telegram 자체가 그 표시를
약 5초 뒤에 소멸시키며, 재발화 루프가 전혀 없음)는 ~64초의 프리필 대기를 그 표시기가 버티지
못할 것이라는 **추정**을 줄 뿐, 실제 관측이 아니다.

이 트라이얼을 직접 실행하는 7단계 체크리스트는
`phase-06/results/20260830T071532Z-net05/decision.md` 에 남아 있다.

## 7. 터치의 제약

iPad/iPhone Safari 에는 ⌘+클릭이 없다. "⌘+클릭으로 새 탭에서 연다" 절차를 만나면, 터치에서는
**롱프레스 → "새 탭에서 열기"** 로 바꾸거나, 그 조작만은 Mac 에서 한다. 자세한 내용은
`docs/manual/04-32k-operations.md` §6 을 참고할 것.

## 8. 문제가 있을 때

먼저 서버와 기기를 분리해서 판단한다:

```
bash phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline
```

`CASES 24/24` 가 나오면 서버는 정상이고 문제는 기기 쪽이다.

**롤백** 은 이 한 줄이다:

```
tailscale serve --https=8444 off
```

**`tailscale serve reset` 는 절대 금지다** — 이 프로젝트 이전부터 있던 두 개의 핸들러와
공용 Funnel 키까지 전부 지워버린다. 이 프로젝트가 소유하지 않은 설정이다.

---
*근거: docs/network-exposure.md, docs/services.md, phase-06/IPAD-CHECKLIST.md*
