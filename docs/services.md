# Phase 5 Kanban·Telegram 서비스화 기록 (SVC-01~05)

## 1. 결론 (한 줄)

두 launchd 상시 에이전트가 존재한다 — `com.ohama.kanban`(`127.0.0.1:3484` 서빙, 실제 HTTP 응답
확인됨)과 `com.ohama.telegram-connect`(등록됐지만 토큰 슬롯이 비어 있어 의도적으로 무력(inert))
— 둘 다 `KeepAlive` 로 감독되고, 둘 다 스스로 회복하며, 둘 다 loopback 전용이다.

## 2. 무엇을 만들었나

두 launchd 서비스 모두 같은 골격을 공유한다: `ProgramArguments[0]` 은 항상 `/bin/bash`, `[1]` 은
`phase-05/services/` 아래의 래퍼 스크립트다 — 바이너리를 직접 물리지 않는다.

`com.ohama.kanban.plist` 의 `ProgramArguments`:
```
/bin/bash
/Users/ohama/projs/cline-tests/phase-05/services/run_kanban_service.sh
```
래퍼 안의 실제 exec 줄(`run_kanban_service.sh`):
```
exec "$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh" -- \
  "$KANBAN_BIN" --no-open --host "$KANBAN_HOST" --port "$KANBAN_PORT"
```

`com.ohama.telegram-connect.plist` 의 `ProgramArguments`:
```
/bin/bash
/Users/ohama/projs/cline-tests/phase-05/services/run_telegram_service.sh
```
래퍼 안의 실제 exec 줄(토큰이 있을 때만 도달, `run_telegram_service.sh`):
```
exec "$PROJECT_ROOT/phase-03/sandbox/run_sandboxed.sh" -- \
  "$CLINE_BIN" connect telegram -k "$TOKEN" -i --no-tools \
  --provider "$CLINE_PROVIDER" --model "$CLINE_MODEL" --cwd "$SANDBOX_WORKDIR"
```

**왜 래퍼를 두고 바이너리를 직접 물리지 않았나** — 아래 세 가지가 각각 독립적인, 바이너리 단독
호출로는 흡수할 수 없는 문제를 해결하기 때문이다:
- **THE CWD RULE** — launchd 가 설정하는 프로세스 cwd 가 `workspace/ALLOWED_REPOS.json` 안에
  이미 있지 않으면 Bun/Node 부트스트랩이 경로 정보 없는 일반 오류로 죽는다(겉보기엔 샌드박스가
  더 엄격해진 것처럼 보인다) — `docs/headless-wrapper.md` §6 이 이미 증명한 함정이다. 두 plist
  모두 `WorkingDirectory` 를 명시하고, 두 래퍼 모두 자체적으로 `cd` + 단언을 한 번 더 한다(벨트
  앤 브레이시스).
- **self-daemonize 트랩** — `cline connect telegram` 은 `-i`(`--interactive`) 없이 부르면
  기본적으로 자기 자신을 백그라운드로 분기(fork)해 launchd 가 감독하는 부모 프로세스는 즉시
  종료된다. `KeepAlive` 아래서 이건 부모의 크래시루프이거나, `ThrottleInterval` 마다 새 고아
  봇 자식을 하나씩 새는 것 둘 중 하나다. `-i` 는 이 래퍼에서 절대 빠질 수 없는 리터럴이다.
- **빈 토큰 throw** — 토큰이 비어 있으면 실제 `cline` 호출까지 절대 가지 않는다. 대신 유한한
  `/bin/sleep <초>` 루프로 조용히 대기한다(`sleep infinity` 는 이 머신 `/bin/sleep` 이 거부하는
  단어라 즉시 리턴 → 100% CPU 스핀이 되므로 금지, `exit 0`/`exit 1` 은 `KeepAlive` 아래서 둘 다
  진짜 크래시루프이므로 금지).

## 3. 왜 이렇게 골랐나

- **`-i` 는 필수다** — 없으면 launchd 는 이미 종료한 부모 프로세스를 계속 감독하는 셈이 되고,
  실제 봇 자식은 아무도 감독하지 않는 상태로 계속 돈다.
- **`--no-tools` 는 이 표면에 대한 `--auto-approve false` 태세의 정직한 번역이다** —
  `--auto-approve` 자체가 `cline connect telegram` 의 플래그로 아예 존재하지 않는다. 이걸
  그대로 복사해 넘겼다면 인식되지 않는/무시되는 플래그가 되어 도구가 기본값(활성)인 채로 조용히
  켜져 있었을 것이다 — 의도의 정반대. `docs/headless-wrapper.md` §4/§8 이 이미 정리한 결정을
  이 커넥터 표면에 그대로 이어받은 것이다.
- **빈 토큰 분기는 exit 하지 않고 block 한다** — `KeepAlive: true` 아래서 `exit 0` 과 `exit 1`
  둘 다 진짜 크래시루프다(재시작 주기가 `ThrottleInterval` 이냐 아니냐의 차이일 뿐). 유한한
  `/bin/sleep` 이 유일하게 안전한 선택이다.
- **`--port 3484` 는 고정이지 기본값이 아니다** — kanban 의 다른 잘 알려진 기본 포트는 이 파일
  어디에도, 이 phase 어디에도 등장하지 않는다(ROADMAP Phase 6 criterion 3).
- **`--no-passcode` 는 의도적으로 넘기지 않았다** — kanban 은 기본적으로 원격 접근 패스코드를
  자동 생성한다; Phase 6 의 NET-02 는 이걸 없애는 게 아니라 그 위에 쌓아 올릴 것이다.
- **로그는 `~/.cline/logs/` 아래에 산다** — launchd 가 stdio fd 를 자체적으로 열고, 그 fd 를
  샌드박스 처리된 자식이 exec 을 넘어 그대로 물려받는다. 오직 `~/.cline` 만 샌드박스 프로파일에서
  읽기+쓰기로 펀치돼 있고, 펀치되지 않은 경로로 샌드박스된 stdio 를 리다이렉트하면 맨
  `SIGABRT` 가 난다 — 이 프로젝트에서 다섯 번 재현된 패턴이다.
- **readiness 게이트는 flashnext 자기 자신을 본다** — `:8000/health` 가 `status == "healthy"`
  이고 `loaded_model` 이 null 이 아님을 요구하고, 거기에 더해 litellm 이 `flashnext` alias 를
  실제로 광고하는지까지 3단으로 판정한다. litellm 의 `:4000` 만 단독 TCP 로 찔러보지 않는 이유는:
  litellm 은 flashnext 로드 여부와 무관하게 자기 리스너를 먼저 연다 — 그래서 TCP 단독 체크는
  SVC-04 가 다루는 정확히 두 시나리오(flashnext 가 내려간 채 프록시만 살아있는 경우; 그리고
  부팅 시점에 104GiB 모델이 아직 로딩 중인데 프록시는 몇 초 만에 바인딩되는 경우)에서 즉시
  "준비됨"을 잘못 보고했을 것이다. 이 게이트가 listening-but-not-ready 업스트림을 실제로
  거부한다는 증거는 05-03 의 `notready-*` 산출물에 있다.

## 4. 한계 — 재부팅은 실제로 하지 않았다

**이 절이 이 문서에서 가장 눈에 띄어야 한다.**

무엇이 증명됐나 (proxy):
- 두 plist 모두 `RunAtLoad: true`
- 두 plist 모두 `~/Library/LaunchAgents/` 아래 실제로 존재
- 두 라벨 모두 활성 상태(`launchctl print-disabled` 목록에 없음)
- 각 라벨에 대해 `bootout` → (라벨이 조회되지 않는 상태 유지 확인) → `bootstrap` → healthy 확인
  까지 실제로 한 사이클씩 집행됐다 — 즉 잡 정의가 존재하고, 활성화돼 있으며, 프로세스가 이미
  떠 있지 않은 콜드 스타트 상태에서 정확히 시작한다는 것 — 로그인/부팅 시 launchd 가 부트스트랩
  하는 것과 같은 경로다.

무엇이 증명되지 않았나:
- 실제 macOS 재부팅을 가로지르는 진짜 동작(로그인 세션 순서, 이 두 서비스가 뜨는 시점에 `:4000`
  이 이미 열려 있는지 여부)
- 스택 자신의 재부팅 이후 헬스 상태에 대해서는 아무것도

이 두 서비스와 무관한, 별개의 재부팅 전제조건: 실제 재부팅은 `iogpu.wired_limit_mb` 를
초기화하고, `phase-02/infra/preflight.sh` 는 이 값이 잘못돼 있으면 하드 실패한다 — 그래서
재부팅 후에는 flashnext 가 다시 건강해지기 전에 `sudo sysctl` 재적용이 필요하다.

두 번째, 더 작은 정직한 한계: readiness 게이트는 완전한 `POST /v1/chat/completions` 왕복까지는
가지 않는다(`phase-02/infra/verify_no_regression.sh` Check 6 이 하는 방식). 그게 유일하게
결정적인 프로브이긴 하지만, 서비스가 뜰 때마다 실제 추론 1회(TTFT 수십 초)를 태우는 비용이라
readiness 루프 안에서는 받아들일 수 없다. 이 게이트가 실제로 세우는 것은 "flashnext 가 로드된
모델을 보고하고 AND litellm 이 그 alias 를 광고한다"이며, 배제하지 못하는 것은 그 둘을 모두
만족하면서도 실제 완성(completion) 은 실패하는 스택이다. 그 구분이 중요할 때는
`phase-02/infra/verify_no_regression.sh` 를 돌려라 — 완전한 왕복까지 하는 게이트다.

잔여 위험: flashnext 의 실제 콜드부트 시간이 `UPSTREAM_WAIT_TIMEOUT`(300초)를 넘으면 래퍼는
exit 1 하고 launchd 가 `ThrottleInterval` 이후 전체 사이클을 재시도한다 — 약 5.5분에 한 번
스폰, 자기-해소적(self-resolving)이며 크래시루프가 아니다. 올려야 할 노브는
`phase-05/services/config.env` 의 `UPSTREAM_WAIT_TIMEOUT` 이다.

**이 phase 는 두 라벨이 부팅을 가로질러 정말로 동일하게 확인됐다는 문구를 이 저장소 어디에도
쓰지 않는다 — 실제 전원 순환(power cycle)이 일어나기 전까지는.** 위에 적은 proxy 증거와 그
proxy 가 증명하지 못하는 것의 경계를 대신 정확히 남긴다.

### Task 3 결정 기록

**결정 (2026-08-30): `accept-proxy`.** 사람이 세 옵션(proxy 수용 / 지금 재부팅 / 다음 자연
재부팅에 위임) 중 `accept-proxy` 를 선택했다 — 위에 이미 적은 proxy 증거를 그대로 수용하고,
실제 재부팅은 수행하지 않았다.

이 결정이 criterion 1 의 재부팅 절에 대해 의미하는 바:
- 수용된 것은 §4 에 이미 적은 그 proxy 증거 그대로다 — 두 plist 모두 `RunAtLoad: true`, 두
  plist 모두 `~/Library/LaunchAgents/` 아래 실제로 존재, 두 라벨 모두 활성 상태, 그리고 라벨마다
  `bootout` → (라벨이 조회되지 않는 상태 유지 확인) → `bootstrap` → healthy 확인까지 실제로 한
  사이클씩 집행됐다는 것 — 즉 잡 정의가 존재하고, 활성화돼 있으며, 프로세스가 이미 떠 있지 않은
  콜드 스타트 상태에서 정확히 시작한다는 것이며, 이는 로그인/부팅 시 launchd 가 부트스트랩하는
  것과 같은 경로다.
- 이것이 증명하지 못하는 것도 그대로 남는다 — 실제 macOS 재부팅을 가로지르는 진짜 동작(로그인
  세션 순서, 이 두 서비스가 뜨는 시점에 `:4000` 이 이미 열려 있는지 여부)은 여전히 관측된 적이
  없다.
- 실제 재부팅을 하지 않은 이유: 재부팅은 `iogpu.wired_limit_mb` 를 초기화하고,
  `phase-02/infra/preflight.sh` 는 이 값이 잘못돼 있으면 하드 실패하므로, flashnext 가 다시
  건강해지기 전에 특권(`sudo`) `sysctl` 재적용이 필요하다 — 이 phase 는 그 트레이드를 사람 대신
  결정하지 않는다.

`accept-proxy` 결정 이후에도 criterion 1 의 재부팅 절은 여전히 proxy 로만 증명된 상태다 — 실제
관측된 상태로 격상되지 않았다. 사람이 이 머신을 다음에 자연스럽게 재부팅할 일이 있다면, 그
시점이 이 절을 실제로 관측할 수 있는 기회다(단, 이 phase 는 그것을 필수 후속 작업으로 만들지
않는다 — 사람이 proxy 를 수용하기로 이미 선택했기 때문이다).

## 5. 운영

**재시작:**
```
phase-02/infra/restart_service.sh com.ohama.kanban 3484
phase-02/infra/restart_service.sh com.ohama.telegram-connect none
```

**내리기(take-down):**
```
launchctl bootout gui/<UID>/com.ohama.kanban
launchctl bootout gui/<UID>/com.ohama.telegram-connect
```
(`<UID>` 는 `id -u`. `bootout` 은 비동기다 — 아래 8절 하우스 룰 참고.)

**완전 제거:**
1. `launchctl bootout gui/<UID>/<label>`
2. `rm ~/Library/LaunchAgents/<label>.plist`
3. `~/local-llm-settings/sync.sh` 의 `LABELS` 배열에서 해당 라벨 제거
4. `~/local-llm-settings/sync.sh` 재실행(인자 없음, live → mirror 방향만)

**상시 게이트:**
```
bash phase-05/services/verify_services.sh
```
read-only, 재실행 가능. Phase 6 은 네트워크 노출 전/후 이 스크립트를 그대로 호출해야 한다.

## 6. 텔레그램 토큰 주입

토큰 슬롯은 이 phase 내내 비어 있다 — **이 프로젝트는 어떤 시점에도 토큰을 생성/조회/조작하지
않는다.** 나중에 커넥터를 활성화하려면:

1. **스테이징 원본**(`phase-05/plists/com.ohama.telegram-connect.plist`, 절대 `~/Library/
   LaunchAgents/` 라이브 파일도, `~/local-llm-settings/` 도 아님)의 `TELEGRAM_BOT_TOKEN` 을
   편집한다. 토큰은 **BotFather** 에서 발급받는다 — 이 프로젝트가 생성하지 않는다.
2. `bash phase-05/services/install_services.sh com.ohama.telegram-connect`
3. `bash phase-02/infra/restart_service.sh com.ohama.telegram-connect none`
4. 재시작 직후 orphan sweep 과 포트맵을 다시 돌린다 — 토큰이 있는 커넥터는 RPC 호스트를
   **연다**(Phase 6 인계 잔여 항목).
5. **이 재시작의 커넥터 로그(`~/.cline/logs/telegram-connect.log` / `.err`)에서 `unknown
   option` 문자열을 반드시 감시한다** — 이 재시작이 실제 호출 줄이 처음으로 파싱되는 순간이기
   때문이다(빈 토큰 idle 분기는 이 파싱 경로를 한 번도 실행한 적이 없다). `cline connect
   telegram` 은 원샷 `cline <prompt>` 모드와 완전히 다른 플래그 표면이다 — **`-P` 짧은 플래그가
   아예 없고**, **`-m` 은 `--model` 이 아니라 `--bot-username` 에 바인딩돼 있다** — 그래서
   `--provider`/`--model` 은 반드시 풀네임으로 남아 있어야 한다. 이 둘을 줄여 쓰면 토큰 주입
   이후 첫 실행이 `ThrottleInterval` 마다 한 번씩 영구 `unknown option` 크래시루프가 된다.

## 7. 로그

`~/.cline/logs/` 아래 네 파일(`kanban.log`/`.err`, `telegram-connect.log`/`.err`). launchd 는
이 파일들을 절대 회전(rotate)하지 않는다. 관측된 정상 성장 패턴: kanban 은 평범한 서버 출력,
telegram 은 시작마다 알림 한 줄. 상시 게이트가 10MB 를 넘으면 WARN(FAIL 아님)을 낸다. 수동
자르기 명령은 `: > <파일>` 이며, launchd 가 fd 를 계속 붙잡고 있는 동안에도 안전하다. 회전은
이 phase 에서 만들지 않았다 — 다른 세 서비스(flashnext/litellm/role-shim)와 동일한 기존 갭이다.

## 8. 하우스 룰

`docs/infra-hardening.md` §6 의 규칙을 그대로 재진술한다(재도출하지 않는다):
- 절대 `kill`/`pkill` 로 서비스를 내리지 않는다. `launchctl load`/`unload`/`kickstart` 도 쓰지
  않는다.
- 항상 `bootout` → 확인 → `bootstrap` → `launchctl print` 확인 순서.
- `bootout` 은 비동기다 — 항상 teardown 을 폴링한다. `restart_service.sh` 가 이미 이 폴링을
  내장하고 있으니 이 헬퍼만 쓴다.
- `~/local-llm-settings/` 미러는 절대 손으로 편집하지 않는다. 방향은 항상 live → mirror
  (`sync.sh`, 인자 없이).

Phase 5 고유 두 가지 추가:
- **절대 `cline kanban` (cline 자체의 kanban 런처 서브커맨드) 을 호출하지 않는다** — 핀 밖으로
  자동 설치되는 드리프트 경로다.
- **샌드박스된 프로세스의 stdio 를 펀치되지 않은 경로로 절대 겨누지 않는다** — 맨 `SIGABRT`
  가 난다.

## 9. 증거

| ROADMAP 기준 | 경로 |
|---|---|
| 1 (라벨 running, 재부팅 절은 proxy) | `phase-05/results/20260830T024606Z-phase-close/criteria.md` |
| 2 (kill → KeepAlive 부활) | `phase-05/results/20260830T020530Z-svc01-kanban/svc03.txt`, `phase-05/results/20260830T021706Z-svc02-telegram/svc03.txt` |
| 3 (flashnext 다운 상태에서 크래시루프 없는 재시도) | `phase-05/results/20260830T014424Z-svc04/deadport-rc.txt`, `notready-*.txt`, `recovery-wait.txt` |
| 4 (SVC-05, 미러 반영) | `phase-05/results/20260830T023144Z-svc05/synccheck-after.txt`, `mirror-state-md.txt` |
| 전체 게이트 스윕(phase-close) | `phase-05/results/20260830T024606Z-phase-close/` |

## 10. 미룬 것 / Phase 6 인계

- **`workspace/scratch-repo` 는 자기 자신의 git 저장소가 아니다** — kanban 의 git-root 탐색은
  바깥 repo 로 해석되지만 샌드박스는 `scratch-repo` 만 펀치한다(05-RESEARCH.md Pitfall 6). 이
  phase 에서 의도적으로 유예했고 별도 태스크를 만들지 않았다 — 한 줄짜리 수정은 그 안에서
  `git init` 하는 것이다.
- **`--allowed-user-id` 는 cline 3.0.53 에서 선택 사항이다** — CLI 자체가 이걸 강제하지
  않으므로, Phase 6 의 criterion 4 는 CLI 보장이 아니라 래퍼 레벨 강제가 필요하다.
- **토큰이 주입된 커넥터의 RPC 공존 잔여 항목** — 6절의 5단계 참고, 고치는 방법은
  `--rpc-address` / `CLINE_RPC_ADDRESS`.
- Phase 6 은 네트워크를 여는 것 앞뒤로 `verify_services.sh` 를 호출해야 한다 — 이건 명시적인
  초대(invitation) 다.

**Phase 6 handoff — 위 `--allowed-user-id` 항목은 이제 해소됐다.** 06-02 에서
`run_telegram_service.sh` 에 프리플라이트 가드를 추가해, 토큰이 있는데 숫자형
`TELEGRAM_ALLOWED_USER_ID` 가 없으면 `cline` 을 절대 실행하지 않고 즉시 거부(`ABORT-NET04`)한다.
CLI 자체(cline 3.0.53)는 여전히 이 플래그 없이도 시작한다 — 보장하는 지점은 CLI 가 아니라 이
래퍼다. 전체 설명은 `docs/network-exposure.md` §4d 참고.

## 11. Phase 7 인계 — 벤치 배치가 이 두 서비스 옆에서 돈 적이 있다

Phase 7 은 `harbor run --env docker` 로 cline-bench 과제를 실행하는 동안 이 두 서비스를 단 한
번도 재시작하지 않았다 — 벤치가 도는 동안에도, 끝난 뒤에도 `verify_services.sh` 는 계속
`CASES 15/15` 를 유지했다. 벤치 과제가 실제로 flashnext 에 요청을 보냈다면 같은
`--max-num-seqs 1` 큐를 Kanban/Telegram 과 공유해 실측 지연이 발생했을 것이나, Phase 7 이
실행한 유일한 과제는 flashnext 에 도달하지 못해(`model_turns=0`) 이 경합이 실제로는 관측되지
않았다. 자세한 내용과 한계는 `docs/cline-bench.md` 참고.

---
*Phase: 05-kanban-telegram-services*
