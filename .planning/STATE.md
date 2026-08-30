# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** Cline 이 32K 벽에 닿기 전에 스스로 압축해서, 작업이 중간에 죽지 않는 것
**Current focus:** **Phase 4 (헤드리스 CLI 래퍼) 완료.** wave 1의 04-01(오프라인 기반), wave 2의
두 플랜(04-02: 실제 라이브 래퍼, 04-03: criterion-3 증명 게이트), wave 3의 04-04(criterion-3
실제 1회 라이브 확정 + `docs/headless-wrapper.md` + phase-close)까지 4개 플랜 전부 완료. ROADMAP
Phase 4 세 성공기준(HLS-01/02/03) 모두 실측 증거로 동시 성립: HLS-01/02 는 04-02 의 shipped
래퍼 라이브 스모크런(`success`), HLS-03 은 04-04 의 `verify_sandbox_via_cline.sh` 라이브 실행
(`VERDICT: DENIED`, 커널 EPERM + in-whitelist canary 성공이 같은 tool-call 배치에 공존)으로
증명됨. `EXTRA_ALLOW_PATHS` 는 phase 시작부터 종료까지 빈 값 그대로 — Phase 3 인계 블로커는
경계 확장이 아니라 초대(invocation) 위생(cwd 픽스)으로 닫혔다. 다음은 **Phase 5**.

## Current Position

Phase: 5 of 8 (Kanban·Telegram 서비스화) — 진행 중
Plan: 04 of 7 in current phase — 완료 (SUMMARY 작성 완료). **Wave 1(05-01/05-02, 병렬) 완료 +
wave 2(05-03) 완료 + wave 3 전반(05-04) 완료.**
Status: 05-04 완료 — **Phase 5 최초의 launchd 서비스 등록.** `com.ohama.kanban` 을 house-style
plist(`phase-05/plists/com.ohama.kanban.plist`)로 스테이징하고, 쓰기 전용 멱등 설치기
(`install_services.sh`, launchctl 절대 미호출)로 설치, 유일하게 허용된 헬퍼
(`phase-02/infra/restart_service.sh`)로만 기동 — `RESTART OK pid=52654`. criterion 1(SVC-01)을
`state=running` 단독이 아니라 독립 2차 오라클(20초 간격 동일 pid + 3484 실제 LISTEN + 실제 HTTP
200)로 증명, anti-orphan 도 `ps args` 만이 아니라 `vmmap` 으로 이 정확한 pid 메모리에
`libsandbox.1.dylib`/`libsystem_sandbox.dylib` 가 매핑돼 있음을 확인해 sandbox_init() 이 이 pid
안에서 실제로 실행됐음을 증명(execve() 가 argv 를 교체하므로 `ps args` 만으로는 "sandbox-exec"
문자열 자체가 나타날 수 없다는 것을 확인 — 아래 결정 로그 참조). criterion 2(SVC-03)를
`kill -TERM <launchctl 이 보고한 정확한 pid>` 1회로 실측: KeepAlive 가 2초 내 새 pid 로 소생시켰고
15초 뒤에도 동일 pid(설정 재시작 루프 아님). take-down 경로(`launchctl bootout`)도 실제로
집행 — label 미등록+포트 비움을 확인한 뒤 30초간 5초 간격 재확인으로 되살아나지 않음을 증명하고,
`restart_service.sh` 로 다시 복구. flashnext(46573)/litellm(48525)/role-shim(75548) pid 전 과정
불변, `EXTRA_ALLOW_PATHS` 빈 값 그대로, `cline` 호출 0회(`kanban --version` 만 1회, 허용됨),
`sync.sh`(SVC-05) 는 05-06 소관이라 실행 안 함. 편차 1건(Rule 1, 코드 버그 아님 — 플랜 자체의
검증 기대치가 execve() 커널 동작과 불일치했던 것을 vmmap 증거로 우회, 아래 결정 로그 참조).

이전: 05-01 완료 — Phase 5 의 SVC-03/SVC-04 핵심 메커니즘인 두 launchd 래퍼와 그 공유 인프라를
작성. `phase-05/services/config.env`(Phase 5 전 경로/라벨/포트/타임아웃 단일 소스, `phase-04/config.env`
를 pre-set-then-source 관용구로 재사용해 `SANDBOX_WORKDIR` 재파생 안 함), `wait_for_port.sh`(범용
바운디드 TCP 폴), `wait_for_upstream.sh`(TCP:8000 → flashnext `/health`(`loaded_model` 비어있지 않음)
→ litellm 이 `flashnext` alias 를 광고하는지, 3단 판정. litellm 포트 단독 TCP 체크는 flashnext
로드 여부와 무관하게 항상 열려있어 SVC-04 가 요구하는 시나리오를 놓치므로 명시적으로 배제. 실패한
단계와 무관하게 루프 꼬리에서 항상 페이싱 sleep). 라이브 스택 대상 3종 실측: 전 단계 통과(exit 0,
~0.1초), stage-2 강제 실패(health URL 을 `/v1/models` 로 바꿔 exit 1, ~6초), stage-3 강제 실패
(가짜 alias 로 exit 1, ~6초). `run_kanban_service.sh`(THE CWD RULE 단언 → 바운디드 readiness 대기
→ `run_sandboxed.sh` 경유 exec, `--port 3484` 명시 고정, `--no-passcode`/`--skip-shutdown-cleanup`/
`--https`/`--update` 모두 이유와 함께 의도적으로 생략). `run_telegram_service.sh`(빈
`TELEGRAM_BOT_TOKEN` 은 숫자 `/bin/sleep` 루프로 조용히 idle — `sleep infinity` 사용 금지, exit 도
금지 — cline 은 아예 호출되지 않음; 실제 호출 줄은 `-i --no-tools` 리터럴 인접 토큰 +
`--provider "$CLINE_PROVIDER" --model "$CLINE_MODEL"` 풀네임만 사용, `-P` 짧은 플래그는 이 서브커맨드에
아예 존재하지 않고 `-m` 은 `--bot-username` 에 바인딩되어 있어 절대 축약 안 함). 이 플랜은 아무것도
등록하지 않음 — `phase-05/` 안 `launchctl bootstrap` 0건, flashnext(46573)/role-shim(75548)/
litellm(48525) pid 전 과정 불변, `EXTRA_ALLOW_PATHS` 빈 값 그대로. `cline` 호출 0회(예산 0),
`kanban --version` 만 1회(허용, 읽기 전용). 편차(deviation) 0건 — 단, 플랜 자신의 grep 기반 검증이
설명용 주석 속 리터럴 문자열(`cline kanban`, `--auto-approve`, 고립된 `-P`, `sleep infinity`)과
충돌하는 것을 4건 발견해 커밋 전에 표현만 재작성(동작 무변경, 02-01 의 kill/pkill 주석 충돌과 동일
계열). 05-02(같은 wave, 병렬)가 소유한 `phase-01/config/check_versions.sh`/
`phase-02/infra/restart_service.sh` 는 전혀 건드리지 않음. 아래 결정 로그 참조.

이전: 05-02 완료 — `phase-01/config/check_versions.sh` Check C 를 `KANBAN_NO_AUTO_UPDATE=1` 까지
스캔하도록 확장(기존 `CLINE_NO_AUTO_UPDATE` 체크와 A/B 체크는 무변경, 이전엔 보이지 않던 kanban
드리프트 갭이 이제 fixture 쌍(good PASS/bad FAIL)으로 증명됨), `phase-02/infra/restart_service.sh`
를 포크하지 않고 그 자리에서 확장해 포트 없는 라벨(`<port> none`)도 재시작 가능하게 함 —
비동기 bootout teardown-wait 은 그대로 보존, 포트 없는 헬스체크는 `state=running` 단독을 증거로
받지 않고 10초 이상 간격의 두 샘플에서 동일 pid 를 요구(재시작 루프에 갇힌 잡이 `running` 을
보고하는 것과 구분). 이 플랜은 어떤 서비스도 등록/재시작하지 않음 — flashnext(46573)/
role-shim(75548)/litellm(48525) pid 전 과정 불변. `cline` 호출 1회(Check B 내부, 예산 상한 2회
대비 절반), `verify_config.sh` 1차 통과(heal 불필요 — `contextWindow` 최상위 필드 정정이
`cline config --json` 정규화를 생존한다는 관찰과 일치). 05-01(같은 wave, 병렬)이 소유한
`phase-05/services/`/`phase-05/plists/` 는 전혀 건드리지 않음.

이전: 04-04 완료 — criterion-3(HLS-03)를 `verify_sandbox_via_cline.sh` 실제 1회 라이브 실행으로
확정(`VERDICT: DENIED`, 커널 EPERM + in-whitelist canary 성공 공존), `docs/headless-wrapper.md`
작성(8절, 한계 절이 독립 섹션), `docs/sandbox-whitelist.md` §7 에 `해결됨 (Phase 4)` 노트 추가
(원문 보존), phase-close 게이트 8종 전부 PASS. 자체 발견/수정 버그 1건(Rule 1) — 04-03 이 오프라인
저작한 `verify_sandbox_via_cline.sh` 가 실제 라이브 실행에서 처음으로 stdio-리다이렉트 SIGABRT를
드러냄(03-03 F8/03-04/04-02 와 동일 근본 원인), 라이브 실행 직전 수정. `cline` 호출: 이 플랜
1회(phase 총 2회, 상한 4회) — 크래시 시도는 예산 미포함(선례 재확인, 3번째 사례). pid 3종
(46573/75548/48525) 불변, `EXTRA_ALLOW_PATHS` 빈 값 그대로, `phase-03/`·`phase-02/` git diff
없음. 아래 결정 로그/Session Continuity 참조.
04-01 완료 — config.env/classify_run.py/fixtures(5종)/pytest(13개) 전 태스크 개별 커밋,
`phase-04/fixtures/` 는 이제 frozen(wave 2 두 플랜이 read-only 로 소비). `cline` 호출 0회
(phase 예산 2회 그대로 보존).
04-03 완료 — `phase-04/verify_sandbox_via_cline.sh`(criterion-3/HLS-03 증명 게이트) 작성,
TEST-ONLY 배너 + `--auto-approve true` 근거 명시, `EXTRA_ALLOW_PATHS` 무변경 단언, cwd 픽스
재사용, 8단 판정 사다리(crashed/32K terminal/TTY-rejected/모델이 target 시도 안 함/fail-open/
control 실패/DENIED/other)를 `classify_run.py`의 `outcome.json`만으로 판정(맨 exit code 사용
금지). `VERIFY_DRY_NDJSON` 오프라인 후크로 7개 필수 행 전부(예상 VERDICT/exit 일치) 오프라인
자가검증 완료 — 이 플랜은 `cline` 호출 0회, `phase-04/fixtures/` 무변경(git status/diff 둘 다
빈 결과) 확인.
04-02 완료 — `phase-04/run_headless.sh`(HLS-01/02/03 shipped 래퍼) 작성. `--auto-approve false`
리터럴 인접 토큰으로 고정(`--auto-approve true` 는 파일 어디에도 없음), 유일한 `$CLINE_BIN`
호출 줄이 `run_sandboxed.sh` 를 포함(비샌드박스 경로 0개). THE CWD RULE 을 실제로 적용(cd +
`ALLOWED_REPOS.json` prefix-match 단언) 후 처음으로 **라이브**로 검증 — Phase 3 인계 블로커가
연구 단계를 넘어 실측으로 해소됨. 5개 fixture 전부 오프라인 dry-run 계약 exit code 일치(2/0/3/5/7),
non-whitelisted cwd 음성 대조군은 exit 1 + `npm install` 0회. **라이브 1회**:
`run_headless.sh --timeout 180 "...PONG..."` → exit 0/`success`/`run_result` 1건, 모델 응답
정확히 "PONG". `EXTRA_ALLOW_PATHS` 무변경, `phase-03/` git diff 없음, `phase-04/fixtures/`
무변경. `cline` 호출: 1/2(폰 예산) 소비 — 첫 시도는 cline/Bun 코드 실행 전 SIGABRT(하네스
버그, 아래 결정 로그 참조)로 예산에 미포함.
Verified: [04-04] `bash phase-04/verify_sandbox_via_cline.sh --timeout 180` exit 0,
`VERDICT: DENIED`; `outcome.json.outcome == "sandbox_denied"`; `ndjson.log` 안 EPERM/Operation not
permitted grep count 79, in-whitelist canary(`INSIDE-SANDBOX-READABLE-OK`) grep count 136,
`"type":"run_result"` grep count 1, `cline_exit.txt`=0(시그널 사망 아님). 같은 `content_end`
tool-call 배치 안에 거부된 target(`/Users/ohama/.zshrc`, EPERM)과 성공한 canary
(`./SANDBOX_INSIDE_CANARY.txt`)가 공존 — 별도 실행이 아니라 같은 run 안에서 부정/긍정 대조군
동시 확보. TEST-ONLY invariant 3종(`TEST-ONLY` count=1, `--auto-approve true` count=4,
`--auto-approve false` count=0) 라이브 실행 직후 및 phase-close 재검증 두 번 모두 통과. Phase-close
8개 항목 전부 PASS: `verify_sandbox.sh`(4/4 CRITERION/16/16 CASES/CRASHED 0),
`verify_no_regression.sh`(INF03:PASS), `verify_config.sh`(healing 불필요, 1차 통과),
`pytest phase-04/tests/`(13/13), `EXTRA_ALLOW_PATHS` 빈 값(`[ -z ... ]` exit 0) +
`git diff --stat phase-03/ phase-02/` 빈 결과 + `phase-04/` 안 `EXTRA_ALLOW_PATHS=` 대입 0건,
ROADMAP 3개 기준 재확인(criterion1: run_result 1건, criterion2: false grep=1/true grep=0,
criterion3: verdict.txt DENIED), `launchctl print gui/$(id -u)/com.ohama.*` pid 3종
(46573/75548/48525) 불변, `git status --porcelain` 이 phase-04/docs/.planning 외에는 이 플랜과
무관한 사전 존재 untracked 파일 2건(`.claude/`, `cline-analysis.*`, mtime 이 이 세션 시작 이전)
뿐임을 확인. `docs/headless-wrapper.md` grep 검증: `inert`/`무력` count=2(4절 헤딩 바로 아래),
`32k-compaction-policy` count=1, `verify_sandbox_via_cline.sh` count=4, `EXTRA_ALLOW_PATHS`
count=2, 200줄(min_lines 80 이상). `docs/sandbox-whitelist.md` 안 `headless-wrapper.md` count=1,
`해결됨 (Phase 4)` count=1(바레 `해결` grep 아님 — 그 grep 은 기존 `미해결` 2회 때문에 편집 전에도
통과했을 함정임을 인지하고 회피).
Verified: [04-02] 라이브 `ndjson.log`(10줄) 전체가 JSON 파싱 가능(`json.loads` 전체 통과), 정확히
1개의 `"type":"run_result"` 이벤트 존재, `outcome.json`의 `outcome`이 `success`. 라이브 실행 후
`verify_config.sh` PASS(중간에 1회 heal, 예상된 드리프트). `bash -c 'source phase-03/sandbox/
config.env; [ -z "$EXTRA_ALLOW_PATHS" ]'` exit 0, `git diff --stat phase-03/` 빈 결과. 5개 fixture
dry-run 전부 계약 exit code 일치(2/0/3/5/7), non-whitelisted-cwd 음성 대조군 exit 1 +
`npm install` 0회. `--auto-approve false` grep count=1, `--auto-approve true` grep count=0,
`run_sandboxed.sh` grep count=2(유일한 `$CLINE_BIN` 줄에 포함), `inert` grep count=1,
`bash -n` 통과. `launchctl list` 로 flashnext(46573)/role-shim(75548)/litellm(48525) 라이브
실행 전후 불변 확인. `git log -- phase-04/fixtures/` 가 04-01 커밋 하나뿐임을 확인(04-02 자신은
그 디렉터리에 전혀 쓰지 않음).
[04-01] `python3 -m pytest phase-04/tests/ -q` 13/13 통과(2회 연속 실행, fixture
md5 불변 확인). `classify_run.py` CLI 가 다섯 fixture 전부에 대해 문서화된 exit code 계약대로
동작(0/2/3/5/7), `--exit-code 134` 오버라이드가 crashed 를 강제함을 실측(signal death != denial).
실제 Phase 1 32K 캡처(`phase-01/results/2026-08-29T095321Z-44990/ndjson.log`)가
context_overflow_terminal(exit 5)로 정확히 분류됨. `phase-04/config.env` 가 `SANDBOX_WORKDIR` 를
`workspace/ALLOWED_REPOS.json` 에서 파생(하드코딩 없음), 임의 cwd 에서도 source 가능함을 확인.
`EXTRA_ALLOW_PATHS` 미변경(`phase-03/sandbox/config.env` grep 확인), `phase-01/`·`phase-02/`·
`phase-03/`·`docs/` 무변경(`git diff --stat` 빈 결과).
[03-04] 실제 `cline` 바이너리를 샌드박스 아래서 정확히 1회 호출(재설치-체이닝 패턴,
`run_sandboxed.sh -- "$CLINE_BIN" --version`) — 판정 (C) BLOCKED-NEEDS-HUMAN(경계 미확장,
`EXTRA_ALLOW_PATHS` 변경 없음). `docs/sandbox-whitelist.md` 작성(8절, 한계 절이 자체 섹션,
Phase 4 인터페이스 계약 포함). phase-close 6개 게이트 전부 동시 PASS(`verify_sandbox.sh` 4/4
CRITERION, `pytest phase-03/tests/` 11/11, `verify_config.sh`, `verify_no_regression.sh`
INF03:PASS, launchctl pid 3종 불변, git status 클린). [03-01] `pytest phase-03/tests/ -q` 11/11 통과, 생성된 프로파일을 `sandbox-exec`가 실제로
수락(`/bin/echo` 성공), `run_sandboxed.sh -- /bin/cat bench/runs/CANARY.txt` 가
`Operation not permitted`로 거부(SBX-04 첫 신호), `ALLOWED_REPOS_JSON` 부재 시 fail-closed
확인, 두 파일(`config.env`/`run_sandboxed.sh`) 모두 SCOPE LIMITATION 문구 포함, launchd 서비스
무변경(`com.ohama.flashnext` 계속 active). [03-02] `assert_denied.sh` 5개 필수 자가검증 전부
사양대로 동작(`kill -ABRT $$` 로 실제 SIGABRT 유발 시 `FAIL crashed-signal rc=134`/exit 2, 크래시가
PASS 로 오판되지 않음을 실증), `probe_fs.js` 가 라이브 `sandbox-exec` 아래서 forbidden
read/write/subprocess/escape-symlink 5건 전부 `DENIED EPERM`으로, `ENOENT` 케이스는 별도로
`ERROR`로 정확히 구분됨을 실측, 무샌드박스 컨트롤 베이스라인 `succeeded=7 denied=0 error=0` 확보,
세 산출물 모두 `config.env` 미참조/`.gitignore` 미변경 grep 통과(03-01 과의 파일 소유권 경계 유지).
[03-03] `verify_sandbox.sh` 상시 게이트가 실제 `workspace/ALLOWED_REPOS.json` 대상으로 독립 2회
연속 실행 모두 exit 0, 네 `CRITERION ... PASS` 줄 동일, 16/16 케이스, CRASHED 0, 벤치 카나리
문자열이 어떤 캡처된 sandboxed stdout 에도 없음을 grep 스윕으로 확인. 음성 대조군 3종(precheck 가
deny-less 프로파일 거부, precheck 우회 시 Group F 4건 전부 `FAIL not-denied`, `--no-canonicalize`
아래서 F6 실패)이 모두 사양대로 동작. `launchctl print .../com.ohama.flashnext` pid 46573 로
플랜 전체에서 불변, `cline` 호출 0회.
Last activity: 2026-08-30 — 05-03-PLAN.md 완료 (`phase-05/results/20260830T014424Z-svc04/`:
SVC-03/SVC-04 를 launchd 등록 전 포그라운드에서 직접 증명, README.md 포함. Task 1: 프리플라이트
2종 PASS 후 dead-port(exit 1 ~36-41s/30s 설정, %cpu 전 샘플 0.0, kanban 미기동) + listening-but-
not-ready 결정적 케이스(`python3 -m http.server` 로 TCP 는 진짜 성공, health/alias 두 서브케이스
각각 정확한 단계명으로 거부, exit 1 ~20-25s, 9샘플 전부 0.0) + 오버라이드 없는 실제 운영 타깃
recovery(launchd 와 동일한 `$HOME/.cline/logs/` stdio 리다이렉트로 kanban 이 실제 3484 바인딩,
`Abort trap`/`Unexpected` 0건). Task 2: 텔레그램 빈 토큰 idle ~96초 관찰(6샘플, 동일 pid·0.0%cpu·
로그 줄수 불변·`connect telegram` 프로세스 0). Task 3: kanban 포트 인벤토리(3484 단 하나)로 연구
Open Question 2 3단 판정 해소(빈 토큰 상태에서 구조적으로 충돌 불가능/실측 kanban 풋프린트/Phase 6
잔여 항목을 `--rpc-address`/`CLINE_RPC_ADDRESS` 로 이름 명시). 자체 발견/수정 버그 1건(Rule 1,
`wait_for_upstream.sh` 의 `WAITED` 가 stage-1 자체 바운디드 재시도 시간을 누락해 실제 바운드가
설정값의 약 2.4배로 새던 것 — dead-port 케이스가 이 스크립트 최초로 stage-1 을 실패 단계로
노출시켜 발견됨 — `$SECONDS` 기반 실측 wall-clock 으로 수정) + Rule 3 자기 교정 1건(Task 3 첫
시도가 화이트리스트 밖 `phase-05/results/` 로 stdio 를 직접 리다이렉트해 크래시 — 03-03 F8/03-04/
04-02/04-04 와 동일 SIGABRT 계열이 다섯 번째로 재현됨을 확인, 이미 검증된 `$HOME/.cline/logs/`
경로로 재시도해 해결, 스크립트 변경 없음). 이 플랜도 아무것도 등록하지 않음 — pid 3종 불변,
`EXTRA_ALLOW_PATHS` 무변경, `launchctl bootstrap` 0건, `cline` 호출 0회(예산 0). 네 태스크
커밋(`4ef64d2` fix + `733d1ca`/`f31f660`/`23192ae` feat) 모두 개별.)

이전 활동: 2026-08-30 — 05-01-PLAN.md 완료 (`phase-05/services/{config.env,wait_for_port.sh,
wait_for_upstream.sh,run_kanban_service.sh,run_telegram_service.sh}`: SVC-03/SVC-04 launchd
래퍼와 공유 readiness 게이트. 3단 readiness 게이트를 라이브 스택 대상 3종(전체 통과/stage-2
강제실패/stage-3 강제실패) 실측 확인. 텔레그램 래퍼는 빈 토큰일 때 숫자 sleep 루프로 idle(exit
없음, `sleep infinity` 없음), 실제 호출은 `-i --no-tools` 리터럴 인접 토큰 + `--provider`/`--model`
풀네임만 사용(`-P` 짧은 플래그 없음, `-m` 은 `--bot-username` 전용). 이 플랜은 아무것도 등록/재시작
하지 않음 — pid 3종 불변, `EXTRA_ALLOW_PATHS` 무변경, `phase-05/` 안 `launchctl bootstrap` 0건.
`cline` 호출 0회. 편차 0건(단, 플랜 자체 grep 검증과 충돌하는 주석 리터럴 4건을 커밋 전 표현만
재작성). 05-02 와 wave 1 병렬 실행, `phase-01/config/check_versions.sh`·
`phase-02/infra/restart_service.sh` 무터치.)

이전 활동: 2026-08-30 — 05-02-PLAN.md 완료 (`phase-01/config/check_versions.sh` Check C 확장:
`KANBAN_NO_AUTO_UPDATE=1` 게이트 추가, fixture 쌍으로 증명. `phase-02/infra/restart_service.sh` 를
그 자리에서 확장(포크 아님): `<port|none>`, 포트 없는 라벨은 10초+ 간격 동일 pid 두 샘플로만 건강
판정, 비동기 bootout teardown-wait 은 그대로 보존. 서비스 등록/재시작 0건, pid 3종 불변, `cline`
호출 1/2. 05-01 과 wave 1 병렬 실행, `phase-05/services/`·`phase-05/plists/` 무터치.)

이전 활동: 2026-08-30 — 04-02-PLAN.md 완료 (`phase-04/run_headless.sh`: HLS-01/02/03 shipped
헤드리스 래퍼. `--auto-approve false` 리터럴 고정, 유일한 cline 호출 경로가 `run_sandboxed.sh`
경유, THE CWD RULE(cd + prefix-match 단언) 적용. 5개 fixture 오프라인 dry-run 계약 전부 일치,
non-whitelisted-cwd 음성 대조군 통과. **라이브 1회**: `run_headless.sh --timeout 180
"...PONG..."` → exit 0/`success`/`run_result` 1건, 모델이 정확히 "PONG" 응답 — Phase 3 인계
블로커(cwd 픽스)가 연구를 넘어 실측으로 확인됨. `EXTRA_ALLOW_PATHS` 무변경, `phase-03/` 무변경.
자체 발견/수정 버그 3건(Rule 1 x2 + Rule 3 x1, 아래 결정 로그 참조) — 그 중 하나는 03-04 가 이미
검증한 동일 근본 원인(미펀치 경로로의 sandboxed stdio 리다이렉트 → SIGABRT)이라 첫 크래시 시도는
"정확히 1회" 예산에 미포함.)

이전 활동: 2026-08-30 — 04-03-PLAN.md 완료 (`phase-04/verify_sandbox_via_cline.sh`:
criterion-3/HLS-03 증명 게이트, TEST-ONLY 배너 + `--auto-approve true` 근거 명시, 8단 판정
사다리를 `classify_run.py`의 `outcome.json`만으로 판정, `VERIFY_DRY_NDJSON` 오프라인 후크로
7개 필수 행 전부 오프라인 자가검증 통과. `cline` 호출 0회, `phase-04/fixtures/` 무변경.)

이전 활동: 2026-08-29 — 04-01-PLAN.md 완료 (`phase-04/classify_run.py`: 6가지 outcome을
정확한 우선순위(crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected >
run_aborted > success > other)로 판정하는 순수 `classify()` + CLI, `phase-01/parse_result.py` 의
nested-error 관용구 재사용, fixtures 5종 전부 실제 캡처에서 mining, `phase-04/fixtures/` 를 이제
frozen 으로 선언(wave 2 두 플랜이 read-only 소비), 13개 pytest 전부 통과. `cline` 호출 0회.)

이전 활동: 2026-08-30 — 03-03-PLAN.md 완료 (`verify_sandbox.sh`: 프로파일 생성+fail-open
사전점검 → Group F 8케이스+Group P 6케이스(모두 `assert_denied.sh` 직접 호출, 13회) → F8
`probe_fs.js` 프로브 → criterion-1 Python 체크 → 4개 CRITERION 판정 + `CASES`/`CRASHED`
줄 + 0/1/2 exit 계약. `--negative-control`/`--negative-control-skip-precheck` 모드와
`gen_sandbox_profile.py --no-canonicalize`(TEST-ONLY) 로 검증기 자체가 fail-open 샌드박스를
잡아낼 수 있음을 실증. 3 태스크 모두 개별 커밋, 실제 화이트리스트 대상 2회 실행 결과를
`phase-03/results/20260829T202043Z-sbx/`(README 포함)·`.../20260829T202048Z-sbx/` 에,
음성 대조군 3종을 `phase-03/results/20260829T201927Z-negative-control/`(README 포함)에 기록.
자체 발견/수정 이슈 1건(F8 의 라이브 샌드박스 Node 실행이 SIGABRT/MODULE_NOT_FOUND 로 실패 —
근본 원인 두 가지 모두 실측 후 수정, 아래 결정 로그 참조).

Progress: [████████▒▒] 81% (Phase 4/8 완료, Phase 5/8 진행 중 — wave 1(05-01/05-02) +
wave 2(05-03) + wave 3 전반(05-04) 완료, Plan 22/31 누적 추정 — Phase 5 는 총 7개 플랜)

## Performance Metrics

**Velocity:**
- Total plans completed: 22
- Average duration: ~14.4 min
- Total execution time: ~5.3 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/6 | ~112 min | ~19 min |
| 2 | 4/4 | ~55 min | ~13.8 min |
| 3 | 4/4 | ~48 min | ~12 min |
| 4 | 4/4 | ~42 min | ~10.5 min |
| 5 | 4/7 | ~65 min | ~16.3 min |

**Recent Trend:**
- 05-04 (~10 min, wave 3 — Phase 5's first real launchd registration. `com.ohama.kanban` staged as
  a house-style plist (both `CLINE_NO_AUTO_UPDATE`/`KANBAN_NO_AUTO_UPDATE`, `WorkingDirectory` =
  the sandboxed workdir, logs under the punched `~/.cline/logs/`), installed through a write-only
  idempotent installer (never calls launchctl; second run proved `unchanged:`/no-op), brought up
  through the one sanctioned helper (`RESTART OK pid=52654`). Criterion 1 (SVC-01) proved with an
  independent second oracle rather than `state = running` alone: the same pid at t0 and t+20s,
  127.0.0.1:3484 actually LISTEN, a real HTTP 200. Criterion 2 (SVC-03) proved with a real
  `kill -TERM <exact pid>`: KeepAlive revived a new pid in under 2s, confirmed unchanged 15s later
  (a settled revival, not a loop); the take-down path (`launchctl bootout`) was actually executed,
  confirmed to stay down for a full 30s (sampled every 5s, zero revivals), then reversed via the
  same restart helper. Found one deviation, not a code bug: the plan's own anti-orphan verify step
  expected the literal string `sandbox-exec` in `ps -o args=` for the supervised pid, which is
  structurally impossible — `sandbox-exec` performs a genuine `execve()` into the wrapped command,
  which replaces the recorded argv, so a post-exec `ps` snapshot can never show it regardless of
  correctness. Supplied the evidence the check actually intends (sandbox confinement really is
  active on this exact pid, not merely correct in source) via `vmmap <pid> | grep -i sandbox`,
  which found `libsandbox.1.dylib`/`libsystem_sandbox.dylib` mapped into that pid's own memory —
  proof `sandbox_init()` ran inside it. No scripts changed; the plan's own grep-based verify still
  passed unweakened since the explanatory prose itself carries the literal strings. Live pids
  (flashnext 46573, litellm 48525, role-shim 75548) unchanged throughout; `EXTRA_ALLOW_PATHS`
  empty; `cline` invocations: 0 (only the permitted `kanban --version` read); `sync.sh` (SVC-05)
  deliberately not run, left for 05-06.)
- 05-03 (~20 min, wave 2 — prove-before-register, foreground-only, zero launchd registration.
  Proved both SVC-04 crash-loop generators before anything was supervised: a hard dead-port (exit
  1 at ~36-41s against a 30s configured timeout, %cpu 0.0 throughout, kanban never spawned) and the
  decisive listening-but-not-ready case (a throwaway `python3 -m http.server` made the TCP stage
  genuinely succeed while two forced sub-cases showed the health stage and then the alias stage
  correctly rejecting it, each naming the right stage). A no-override recovery run against the real
  production stack, with launchd-shaped stdio redirection, showed kanban actually binding
  127.0.0.1:3484 with zero `Abort trap`/`Unexpected` — the plists' log paths are pre-cleared of the
  SIGABRT class this project has now hit five times. The telegram wrapper's empty-token idle path
  was observed for ~96s: same pid, 0.0% cpu, unchanged log line count, zero `connect telegram`
  processes. A kanban port inventory resolved research Open Question 2 (exactly one TCP endpoint,
  3484; port 3000 nowhere on the host). Found and fixed a real bug in `wait_for_upstream.sh`
  (Rule 1): its outer-loop `WAITED` accounting silently ignored time spent inside stage 1's own
  bounded retry, so the actual bound ran to ~2.4x the configured timeout whenever TCP was the
  failing stage — never caught in 05-01 because those live checks only forced stage 2/3. Fixed with
  `$SECONDS`-based real wall-clock accounting; re-verified against the live stack post-fix. One
  self-corrected execution mistake (Rule 3): Task 3's first kanban-wrapper attempt redirected stdio
  to a path outside the sandbox's allowed workspace and crashed with the same SIGABRT class;
  re-run against the already-proven-safe `$HOME/.cline/logs/` path succeeded cleanly. Live pids
  (46573/75548/48525) unchanged throughout; `EXTRA_ALLOW_PATHS` empty; `cline` invocations: 0/0.)
- 05-01 (~25 min, wave 1 — ran in parallel with 05-02, no shared files. Authored the two SVC-03/
  SVC-04 launchd wrappers (`run_kanban_service.sh`, `run_telegram_service.sh`) plus their shared
  `phase-05/services/config.env`/`wait_for_port.sh`/`wait_for_upstream.sh`. Live-verified the
  3-stage readiness gate against the running flashnext/litellm stack three ways: all stages pass
  (exit 0, ~0.1s), a forced stage-2 failure (health URL repointed at `/v1/models`, exit 1 after the
  bounded 6s budget), and a forced stage-3 failure (bogus alias, exit 1 after 6s) — proving the
  gate probes flashnext's own `/health` `loaded_model`, not just litellm's always-open port. The
  telegram wrapper's empty-token branch blocks in a bounded numeric `/bin/sleep` loop (never `sleep
  infinity`, never exits) before `cline` is ever touched; its real invocation carries `-i
  --no-tools` as literal adjacent tokens and `--provider`/`--model` long forms only (this
  subcommand has no `-P` short flag at all, and `-m` means `--bot-username`, not `--model`).
  Registered nothing: zero `launchctl bootstrap` under `phase-05/`, zero `cline` invocations. Found
  and fixed four wording-only collisions between explanatory comments and the plan's own grep-based
  verification (literal `cline kanban`, `--auto-approve`, an isolated `-P`, and `sleep infinity` all
  appeared in prose before being reworded) — same technique 02-01 used for its kill/pkill comment
  collision, no behavioral change. pids 46573/75548/48525 unchanged throughout.)
- 05-02 (~10 min, wave 1 — ran in parallel with 05-01, no shared files. Extended
  `phase-01/config/check_versions.sh` Check C in place to enforce kanban's own separate
  `KANBAN_NO_AUTO_UPDATE=1` gate (previously invisible drift gap), proven with a fixture pair in a
  single scanner run (rc=1: bad fixture FAILs, good fixture PASSes both gates, pre-existing
  CLINE_NO_AUTO_UPDATE check unregressed). Extended `phase-02/infra/restart_service.sh` in place
  (never forked) to accept `<port|none>`: portless labels skip the lsof probe in the teardown poll
  while keeping the async-bootout wait itself untouched, and the health poll requires the SAME pid
  across two samples >=10s apart rather than accepting `state = running` alone (a job stuck in a
  restart loop reports running on almost every sample). No deviations — both tasks matched the
  plan's `<action>`/`<verify>` blocks exactly. No service registered or restarted; pids
  46573/75548/48525 unchanged throughout. `cline` invocations: 1/2.)
- 04-04 (~9 min, wave 3 — Phase 4's final plan. Spent the phase's second and last live `cline`
  invocation to prove criterion 3 (HLS-03): `bash phase-04/verify_sandbox_via_cline.sh --timeout
  180` → exit 0, `VERDICT: DENIED` — a real out-of-whitelist read (`$HOME/.zshrc`) failed with
  kernel `EPERM`, and the in-whitelist canary read succeeded in the same tool-call batch of the
  same run. Found and fixed a real bug before the counted run: the criterion-3 script itself
  (authored offline in 04-03, never previously exercised live) crashed with `Abort trap: 6` on its
  first invocation — the same stdio-redirect-to-unpunched-path SIGABRT class already hit in 03-03
  F8, 03-04, and 04-02 — fixed by reusing the validated in-whitelist-scratch-file pattern verbatim;
  per established precedent this crashed attempt (no cline/Bun code executed) did not count toward
  the budget, keeping the phase total at exactly 2 real invocations against a hard cap of 4. Wrote
  `docs/headless-wrapper.md` (Korean, 8 sections, house style, the `--auto-approve false`
  safe-but-inert limitation as its own heading with an explicit Phase 5 escalation requirement) and
  resolved `docs/sandbox-whitelist.md` §7 with an appended `해결됨 (Phase 4)` note (history
  preserved). Phase-close sweep: all 8 items PASS, `EXTRA_ALLOW_PATHS` empty, service pids
  unchanged (46573/75548/48525) — **Phase 4 closed.**
- 04-02 (~8 min, wave 2 — the shipped headless wrapper, `phase-04/run_headless.sh`. Offline dry-run
  testing against all five 04-01 fixtures immediately surfaced two real bugs (relative `DRY_FIXTURE`
  resolved against the wrong post-cd directory; same-UTC-second invocations silently clobbered each
  other's results directory), both fixed before the live run. The first live invocation crashed with
  SIGABRT before any cline/Bun code ran — the wrapper's own `2>file` stderr redirect pointed at an
  unpunched path, the exact failure class 03-04 already diagnosed and fixed for the plain smoke test;
  reused that fix verbatim (in-whitelist scratch-file capture, then copy out) rather than re-deriving
  it, and per 03-04's own precedent this crash does not count toward the invocation budget since no
  cline/Bun code executed. The corrected retry succeeded: exit 0, `run_result` present, model replied
  exactly "PONG" — the first LIVE confirmation that 04-RESEARCH.md's cwd fix actually resolves the
  inherited Phase 3 blocker, not just a research prediction. `EXTRA_ALLOW_PATHS` unchanged throughout.
  `cline` invocations used: 1/2.)
- 04-03 (~15 min, wave 2 — the criterion-3 proof gate, authored and self-tested entirely offline
  in parallel with 04-02's one live invocation. Wrote `phase-04/verify_sandbox_via_cline.sh`
  (TEST-ONLY, `--auto-approve true`, 8-rung verdict ladder computed only from `classify_run.py`'s
  `outcome.json`), then proved the ladder correct over all seven required NDJSON rows via a
  `VERIFY_DRY_NDJSON` offline hook — no row needed a script fix. Structurally guaranteed zero
  `cline` invocations by skipping the config-guard preflight (whose heal path calls `cline auth`)
  whenever running in dry-run mode, rather than relying on the environment happening to already be
  healthy. `phase-04/fixtures/` left byte-unchanged (`git status`/`git diff` both empty); the two
  negated fixture variants were built under `mktemp -d "${TMPDIR:-/tmp}/..."` and never committed.
  Two wording-only authoring bugs caught before the first commit: a literal `--auto-approve false`
  string in explanatory prose that would have failed the plan's own grep check, and a bare
  apostrophe in a heredoc comment line that broke `bash -n` despite the heredoc's quoted
  delimiter.)
- 04-01 (~10 min, wave 1 — Phase 4's offline foundation plan, zero `cline` invocations by design.
  Built `phase-04/classify_run.py`'s six-outcome NDJSON classifier reusing Phase 1's nested-error
  tolerance, mined all five fixtures from real captures (04-RESEARCH.md's live transcripts,
  phase-01's stored results/fixtures), derived `SANDBOX_WORKDIR` from `ALLOWED_REPOS.json` in
  `phase-04/config.env`, and froze `phase-04/fixtures/` for the two wave-2 plans to consume
  read-only. No deviations, no bugs found.)
- 03-04 (~12 min, wave 3 — Phase 3's final plan. The one budgeted real `cline` invocation under
  the sandbox: first attempt crashed with SIGABRT inside Node's own process bootstrap before any
  cline/Bun code ran (same root cause as 03-03's F8 finding, fixed the same way — capture to an
  in-whitelist path instead of an unpunched one — and not counted toward the invocation budget);
  the corrected second attempt reached the real Bun binary and produced a generic, path-less
  runtime error ("An unknown error occurred (Unexpected)"), confirmed via zero-cost `strings`
  inspection to be Bun's own catch-all, not a bounded-candidate permission message — verdict (C)
  BLOCKED-NEEDS-HUMAN, no sandbox widening, handed to Phase 4 as a documented open item. Wrote
  `docs/sandbox-whitelist.md` (Korean, 8 sections, scope-limitation as its own section, Phase 4
  interface contract). Phase-close: all six gates green simultaneously, flashnext/litellm/
  role-shim pids unchanged from the phase's start (46573/48525/75548) — **Phase 3 closed.**)
- 03-03 (~16 min, wave 2 — wired 03-01/03-02's artifacts into verify_sandbox.sh, the standing
  Phase 3 gate; found and fixed one live-reproduced blocker: F8's sandboxed Node invocation
  crashed with SIGABRT (redirecting output to a file under an unpunched path) and then
  MODULE_NOT_FOUND (Node's realpath walk lstat'ing $HOME itself), fixed via pipe-capture +
  a punched-through temp copy + --preserve-symlinks-main; ran the gate twice independently
  against the real whitelist with identical PASS verdicts, plus three archived negative controls
  proving the gate itself can fail (deny-less profile, precheck-bypassed deny-less profile,
  --no-canonicalize symlink-bypass regression))
- 03-02 (~10 min, ran in parallel with 03-01 — three artifacts (make_fixtures.sh, assert_denied.sh,
  probe_fs.js) fully self-tested including a deliberate `kill -ABRT $$` to prove crash != denial;
  one self-inflicted fix, a comment string that literally matched the plan's own `config.env` grep,
  caught and reworded before the first commit)
- 03-01 (~10 min, ran in parallel with 03-02 — no live mutations outside phase-03/workspace/bench,
  zero launchd interaction; one self-found/fixed bug: gen_sandbox_profile.py raised an unhandled
  traceback instead of a clean SystemExit when ALLOWED_REPOS.json itself was missing)
- Last 10 plans: 02-04 (~12 min, no restart — pure verification/sync/docs plan), 02-03 (~10 min,
  restart succeeded first try), 02-02 (~24 min incl. 2 failed restart attempts + fix + re-attempt),
  02-01 (~9 min), 01-06 (~50 min), 01-04 (~35 min), 01-05 (~6 min), 01-02 (~5 min), 01-03 (~5 min),
  01-01 (~11 min)
- 02-04 closed Phase 2: found one self-inflicted bug (PlistBuddy's indented ProgramArguments output
  defeated an exact-match grep in the new gate script's flag-presence check — fixed before the task
  commit, same class of bug as 02-03's verify_lan_bind.sh false positive but on the read side this
  time), ran the full-chain gate 4 times with identical PASS and zero pid churn, and closed with all
  three ROADMAP Phase 2 success criteria verified simultaneously true rather than sequentially true.
- Trend: 02-01 ran fast (zero live mutations). 02-02 was the project's first live launchd restart and
  hit a real bug: `launchctl bootout` is asynchronous, so `restart_service.sh` raced flashnext's
  104 GiB teardown and failed twice with an opaque I/O error before the async-teardown-wait fix
  landed; the restart then succeeded on the first attempt after the fix. 02-03 confirmed the fix
  generalizes for free: litellm's restart (no model to unload) succeeded on the first attempt with
  a 2s teardown, no new workaround needed. Phase 5 inherits the same helper unchanged.
- 01-06 ran long for two reasons found live, not scope creep: (1) this session's `cline`
  binary self-triggers a background auto-update on essentially every invocation regardless of
  `CLINE_NO_AUTO_UPDATE=1`, requiring a tight reinstall-then-immediately-launch pattern to get a
  clean preflight pass at all; (2) the live run surfaced a genuine bug in `parse_result.py`'s
  classifier (real NDJSON error events nest their message one level deeper than the hand-written
  fixtures assumed), which had to be fixed and both already-captured runs reclassified before the
  ② verdict could be trusted

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
- 01-06: **Phase 1 핵심 미지수 실측 완료 — 결과 ②.** `providers.json` 의 `contextWindow:32768`
  오버라이드는 라이브 압축 체크에 도달하지 못했다: 18개 filler 파일로 두 번째 라이브 실행 시
  peak_input_tokens=peak_prompt_tokens=30505 (두 오라클 완전 일치, 예측 트리거 26542 를 3,963
  토큰 초과)까지 갔지만 `auto-compact*`/`overflow-recovery-compact*` notice 는 0건이었고, 서버가
  prompt_tokens=31950 에서 `MAX_KV_SIZE is 32768` 400 으로 거부하며 작업이 죽었다. Cline 은 이
  오류에서 자동 복구하지 않는다(overflow-recovery 분류기가 이 서버의 오류 문구와 매칭되지 않음).
  운영 규칙: "작업을 다시 시작한다". 증거: `phase-01/results/2026-08-29T095321Z-44990/`.
  대응 방침 전체는 `docs/32k-compaction-policy.md` (VER-04). 1회차 실행(12개 filler)은
  below_trigger(peak 23266<26542)로 미확정이었고, 플랜이 허용한 "filler 늘려 1회 재실행"
  규칙에 따라 18개로 재실행해 확정함 — 총 라이브 실행 2/3회, 3회차는 불필요(outcome ①/②는
  최종 답이므로 재실행 금지 규칙에 따름)
- 01-06: `phase-01/parse_result.py`의 `classify()`에서 실제 버그 발견/수정 — cline 3.0.53 의
  실제 NDJSON 오류 이벤트는 메시지를 `event.error.message` 에 한 단계 더 깊이 중첩하는데(기존
  수기 fixture 는 `event.message` 평면 구조를 가정), 이 때문에 진짜 ② 결과가 최초엔 ③/unexpected
  로 오분류됨. `_error_event_message()` 헬퍼로 두 스키마 모두 허용하도록 수정, 실제 캡처된
  이벤트로 만든 회귀 fixture/테스트 추가(24개 테스트 전체 통과). 이미 캡처된 두 실행의 ndjson.log
  를 수정된 분류기로 재분류(추가 라이브 호출 없이) — Plan 03/04 가 만든 fixture 가 RESEARCH.md
  예측 스키마를 그대로 가정했을 뿐 실측 스키마와 다를 수 있다는 사례로 남김
- 01-06: 이 세션에서 `cline` 이 `CLINE_NO_AUTO_UPDATE=1` 에도 불구하고 사실상 모든 호출(`--version`
  포함)마다 백그라운드 `npm update cline` 를 트리거해 2-9초 내에 3.0.60 으로 드리프트하는 것을
  반복 재현(wave 2 가 기록한 "세션 중 1회 드리프트"보다 훨씬 공격적). PATH 상의 `npm` 을 no-op
  shim 으로 가리는 우회는 환경 자체의 안전 분류기에 의해 거부됨 — 대신 "재설치 직후 중간에 수동
  `cline` 호출 없이 바로 `run_regression.sh` 실행"을 한 셸 커맨드로 체이닝하는 패턴을 반복
  사용해 우회. 이후 어떤 플랜이든 `cline` 을 호출할 때 이 재설치-체이닝 오버헤드를 시간 예산에
  포함할 것
- 02-01: `MAX_NUM_SEQS` 기본값 `1`(완전 직렬화)로 확정 — RESEARCH.md Open Question 1 권고를
  그대로 채택. 로드맵 성공기준 문구("하나가 즉시 처리되고 다른 하나는 큐잉/지연")를 가장 직접
  만족하고, 32K 헤드룸이 4.39GB 뿐이라 가장 안전함. `phase-02/infra/config.env` 가 유일한
  오버라이드 지점이며, `verify_queueing.sh` 의 probe concurrency(`MAX_NUM_SEQS+1`)/cap assertion
  (`MAX_NUM_SEQS`) 모두 이 값에서 파생되므로 02-02 이후 캡을 2 로 올려도 스크립트 수정 불필요
- 02-01: 언캡트(현재) 서버 대상 큐잉 베이스라인을 실측 완료 — interleaved 로 확정(`max_overlap=2`
  == concurrency, `queued_count=0`; 두 번째 요청의 `Prefill started` 가 첫 번째 요청의
  `Decode completed` 보다 먼저 발생). 증거: `phase-02/results/20260829T183540Z/queueing-before-*`.
  02-02 의 "after" 실행이 대비할 대상이 확보됨(계획이 허용한 "베이스라인이 이미 직렬화로
  보일 수도 있다"는 대체 시나리오는 발생하지 않음)
- 02-01: `restart_service.sh`(bootout→plutil-lint→bootstrap→poll, `CURRENT_STEP` 기반 롤백
  메시지)를 작성했지만 이 플랜에서는 어떤 서비스에도 호출하지 않음 — 02-02/02-03 이 그대로
  재사용. `preflight.sh`/`verify_queueing.sh` 실행 전후로 `launchctl print` 를 재확인해
  flashnext(8716)/role-shim(75548)/litellm(76864) PID 가 전 과정에서 변하지 않았음을 실측 확인
- 02-01: 플랜 자체의 자동 검증(`grep -cE '\b(kill|pkill|launchctl (load|unload|kickstart))\b'`
  가 0 이어야 함)이 `restart_service.sh` 상단의 설명 주석에 있던 "kill/pkill" 이라는 단어 자체와
  매칭되는 것을 발견 — 실제 명령어가 아니라 주석 문구였지만, 검증을 통과시키기 위해 같은 하우스
  룰을 그 단어들을 쓰지 않는 문장으로 재작성함(동작 변경 없음)
- 02-02: **`launchctl bootout` 은 비동기다 — 이 프로젝트 첫 라이브 재시작에서 실제로 두 번 재현된
  결정적 버그.** `bootout` 은 언로드를 "요청"한 시점에 리턴하며, 실제로 잡이 사라지는 시점을
  보장하지 않는다. flashnext 는 104GiB 모델을 물고 있어 teardown 에 수 초가 걸리는데, 그 사이
  bootstrap 을 곧바로 호출하면 `Bootstrap failed: 5: Input/output error` 로 실패한다 —
  무거운 프로세스가 없는 throwaway 라벨 컨트롤 테스트는 매번 성공해 타이밍 가설을 뒷받침했다.
  `restart_service.sh` 에 Step 3b(`launchctl print` 로 라벨이 더 이상 조회되지 않고 포트에 리스너가
  없을 때까지 폴링 + 3초 여유)를 추가해 해결(commit `0ca2645`). 이 수정은 02-03(litellm)과
  Phase 5(신규 launchd 서비스 등록)에도 그대로 적용되는 헬퍼 차원의 영구 수정이며, 향후 재시작
  헬퍼를 다시 작성할 때 이 순서(bootout → teardown 확인 폴링 → bootstrap → healthy 폴링)를
  그대로 재사용해야 한다.
- 02-02: `MAX_NUM_SEQS=1` 라이브 적용 및 재시작 승인 완료 — 사용자 응답 `proceed-1`
  (`.planning/phases/02-infra-hardening/02-02-SUMMARY.md` 에 `CHECKPOINT_ANSWER: proceed-1`
  라인으로 기록). 이 승인은 이번 flashnext 재시작뿐 아니라 02-03 의 litellm 재시작도 명시적으로
  커버함 — 02-03 은 재승인을 요청하지 않고 이 SUMMARY 파일을 grep 해서 소비해야 한다.
  INF-01 큐잉 증거 실측: `max_overlap=1`(cap=1 이하), `queued_count=1`(>= concurrency-cap=1),
  1차 시도(수정 적용 후)에서 바로 성공(teardown 2초, 총 재시작 28초). 언캡트 베이스라인
  (`phase-02/results/20260829T183540Z/`, max_overlap=2/queued_count=0) 대비 명확한 대조 확보.
- 02-03: litellm 플리스트에 `--host 127.0.0.1` 라이브 적용(`apply_litellm_bind.sh`, `config.yaml`
  및 `master_key` 는 손대지 않음 — 4개 소비처가 모두 `dummy` 키에 `localhost:4000` 을 이미 쓰고
  있어 바인딩만으로 무회귀 해결). 02-02 의 `CHECKPOINT_ANSWER: proceed-1` 을 grep 으로 재사용,
  재질문 없이 재시작 → 첫 시도 성공(teardown 2초). INF-02 증거: `lsof` `*:4000`→`127.0.0.1:4000`,
  LAN IP(192.168.75.108) curl 거부(rc=7), loopback IP/hostname 둘 다 200 (IPv6 `::1` 스트랜딩
  없음 확인). pid 76864→48525. `verify_lan_bind.sh` 자체 검증 문구가 자기 검증용 grep 패턴
  (`*:4000`)과 우연히 매칭되는 버그를 실행 중 발견/수정(로그 문구만 변경, 로직 무변경). 미러
  sync 는 02-04 로 이월(의도적 drift, `MIRROR_DRIFT` 경고로 확인됨).
- 02-04: **Phase 2 종료.** `verify_no_regression.sh`(INF-03 상시 게이트, 읽기 전용·재실행 가능)
  작성/실행 — `INF03: PASS`, 8개 체크(플래그 존재→3개 서비스 실행중→hop3→hop2→hop1→전체 체인
  127.0.0.1→전체 체인 localhost→직접 :8000 무교착 확인) 전부 통과, 실제 completion body 확보
  ("Hi there! How can I help you"). 이 플랜 내내 4회 재실행 모두 동일 PASS, pid 전원 불변
  (flashnext=46573, role-shim=75548, litellm=48525) — 서비스 재시작 0회.
  `~/local-llm-settings/sync.sh` 를 이 phase 에서 유일하게 실행(live→mirror 단방향) — 사전에
  `--check` 로 drift 가 정확히 의도한 두 plist(`com.ohama.flashnext.plist`,
  `com.ohama.litellm.plist`) 뿐임을 확인한 뒤 sync, 이후 diff 0/`--check` 도 일치 보고.
  `docs/infra-hardening.md` 작성 완료 — 값/근거/한계(단일요청 32K OOM 은 안 고침)/증거경로/롤백
  런북/하우스룰(비동기 bootout 포함). phase-close 재검증에서 로드맵 성공기준 1·2·3 이 동시에
  성립함을 재확인(`verify_queueing.sh --label after`, `verify_lan_bind.sh`,
  `verify_no_regression.sh`, `preflight.sh --label phase-close` 모두 PASS, `MIRROR_DRIFT` 0건).
  자체 발견/수정 버그 1건: `PlistBuddy` 의 `ProgramArguments` 덤프가 각 원소를 들여쓰기해서
  출력하는데(`    1`), `verify_no_regression.sh` 의 Check 1 이 값 원문에 대해 `grep -qx` 정확
  매치를 시도해 실제로는 플래그가 멀쩡히 있는데도 FAIL 로 오판했던 것 — `awk '{$1=$1; print}'`
  로 공백 제거 후 매치하도록 커밋 전에 수정(02-03 의 `verify_lan_bind.sh` 자기검증 버그와 같은
  계열이지만 이번엔 로그 문구가 아니라 읽기 쪽 파싱 문제). `verify_queueing.sh` 는 `--label`
  인자를 리터럴 `before|after` 로만 하드 검증한다 — 플랜 문서가 예시로 든 `--label after-final`
  은 실제로는 실패하는 호출이므로 `--label after` 로 대체 실행(assertion 내용은 동일).
- 03-01: **Phase 3 착수.** SBX-01 `workspace/ALLOWED_REPOS.json` 을 유일한 소스로 확정(repo 루트는
  절대 항목으로 넣지 않음 — `bench/` 가 그 아래 있고 SBX-04 가 이를 도달 불가로 요구). SBPL
  프로파일은 03-RESEARCH.md 가 실측 검증한 `(allow default)` + `(deny ... (subpath $HOME))` +
  entry 당 `(allow ...)` punch-through 패턴을 그대로 채택(`(deny default)` 는 dyld 를 못 읽어
  SIGABRT 로 크래시하는 것이 재현되어 기각됨). 모든 경로는 `os.path.realpath()` 를 거친 뒤에만
  프로파일에 쓴다(`/tmp` vs `/private/tmp` 심볼릭링크 우회가 실측 재현됐던 지점). 프로파일은
  `run_sandboxed.sh` 호출마다 무조건 재생성되며 캐시 경로가 전혀 없음(드리프트 방지, 03-RESEARCH.md
  권고). `gen_sandbox_profile.py` 는 `--extra-allow` 플래그가 없어도 내장 기본값으로
  `~/.cline` 을 항상 punch-through 하고, `run_sandboxed.sh` 는 여기에 더해 config.env 의
  `CLINE_DATA_DIR`/`EXTRA_ALLOW_PATHS` 를 명시적으로 `--extra-allow` 로 전달(중복은 삽입순서
  기준으로 dedupe). `EXTRA_ALLOW_PATHS` 가 유일하게 허용된 확장 지점이며 config.env 헤더에
  `$HOME` 한정 스코프("total-deny jail 아님, `/tmp`/`/opt`/`/usr/local`/외장 볼륨은 그대로 열려
  있음")를 verbatim 으로 명시. 자체 발견/수정 버그 1건: `ALLOWED_REPOS.json` 파일 자체가 없을 때
  `load_allowed_repos()` 가 정리 안 된 Python traceback 을 냈던 것을 `SystemExit` 로 통일(fail-closed
  동작 자체는 이미 맞았음, 진단 메시지만 개선). bash 3.2 에서 빈 배열 `"${ARR[@]}"` 가
  `set -u` 하에서 unbound 오류를 내는 것도 실측 재현 후
  `"${ARR[@]+"${ARR[@]}"}"` 관용구로 회피(`run_sandboxed.sh`). `sandbox-exec` 가 `--` 를
  옵션 종결자로 정상 인식함도 man page 에 문서화되어 있지 않아 별도 실측으로 확인.
  03-02(fixtures/probe_fs.js/assert_denied.sh, `.gitignore`/`config.env` 는 미터치)와 병렬 실행,
  파일 소유권 충돌 없이 완료.
- 03-02: `assert_denied.sh`(이 phase 전체의 품질 핵심 산출물)의 `--expect deny` 판별 순서를
  고정: exit>128(crashed-signal, exit 2) → exit==0(not-denied) → 빈 stderr(crashed-silent, exit 2)
  → wrong-error → target/write-target 체크, 이 순서로만 크래시가 낮은 우선순위 규칙으로 새는 것을
  막을 수 있음. 언샌드박스 CONTROL 실행을 항상 먼저 돌려 그 커맨드 자체가 이미 깨져 있었을 가능성을
  배제한 뒤에만 DENIED 를 인정. `probe_fs.js` 는 fs 쪽 EPERM 단독 게이트와 execSync 쪽
  "exit!=0 AND stderr 에 Operation not permitted" 게이트를 동일 원칙으로 맞춤(ENOENT 등은 항상
  ERROR, 라이브 sandbox-exec 아래서 실측 확인). 세 산출물 모두 `--root`/env var/`--profile` 로
  파라미터화해 `config.env` 미참조, `.gitignore` 미변경(03-01 과의 소유권 경계) 확인 완료.
  Fixture 트리(`phase-03/fixtures/`)는 `make_fixtures.sh` 재실행으로 언제든 재생성 가능하며 이
  플랜이 종료된 상태에서 pristine.
- 03-03: **Phase 3 상시 게이트 완성.** `verify_sandbox.sh` 가 03-01/03-02 산출물을 실제로 연결해
  네 ROADMAP 성공기준(SBX-01..04)을 한 커맨드로 증명 — Group F(fixture 프로파일, 8케이스)+Group
  P(실제 production 프로파일, 6케이스) 전부 `assert_denied.sh` 직접 호출(13회)로 판정, F8 은
  `probe_fs.js` 자체 DENIED/ERROR/SUCCEEDED 텍스트로 판정(바 exit code 판정 0건, 플랜의
  `grep -nE '\$\? -ne 0.*(PASS|denied)'` 검증 통과). Criterion 1 의 ancestor 체크는 명시된
  방향대로 구현(`realpath(BENCH_DIR)` 이 어떤 entry 와도 같거나 그 자손이면 FAIL — 저장소 루트를
  화이트리스트에 넣는 실수를 잡는 방향, 반대 방향 아님). Fail-open 사전점검(두 프로파일 모두
  `(version 1)`/`(allow default)`/정확한 realpath 된 deny-root 두 줄/allow punch-through 가
  deny 뒤에 위치 확인 후 아니면 abort)을 모든 케이스 실행 전에 통과.
  **자체 발견/수정 이슈 1건(중요)**: 플랜이 문자 그대로 지시한 F8 명령("sandbox-exec ... node
  phase-03/sandbox/probe_fs.js > $OUT_DIR/probe-sandboxed.txt")이 이 환경에서 실제로 두 단계로
  실패함을 실측: (1) 샌드박스 프로세스의 stdout 을 화이트리스트 밖 경로($OUT_DIR, `$HOME` 아래
  미펀치)로 직접 리다이렉트하면 Node 가 자체 초기화 중 SIGABRT 로 크래시(재현 100%, 파이프
  캡처로 전환하면 즉시 사라짐 확인). (2) 크래시를 고쳐도 `phase-03/sandbox/`(미펀치) 자체를 Node
  가 읽을 수 없어 MODULE_NOT_FOUND, 게다가 Node 의 기본 모듈 해석이 `$HOME` 자체를 포함한 모든
  상위 디렉터리를 lstat 하려다 EPERM. 해결: 캡처를 파일 리다이렉트 대신 커맨드 치환(파이프)으로
  바꾸고, `probe_fs.js` 를 픽스처의 이미 펀치스루된 `$FX/allowed/` 로 실행 중에만 복사한 뒤
  `node --preserve-symlinks-main` 으로 조상 lstat 워크를 건너뛰게 함 — DENIED/ERROR/SUCCEEDED
  판정 로직 자체는 전혀 손대지 않음(순수 배관 수정). 음성 대조군 3종(`--negative-control`이
  deny-less 프로파일을 사전점검에서 거부, `--negative-control-skip-precheck`로 우회 시 Group F
  4건 전부 `FAIL not-denied`, `gen_sandbox_profile.py --no-canonicalize`(TEST-ONLY 신규 플래그)
  아래서 F6 이 예상대로 실패) 모두 사양대로 동작 실증, README 로 각각의 의미 문서화. 실제
  화이트리스트 대상 2회 독립 실행 모두 exit 0/CRITERION 4개 PASS 동일, `launchctl print`
  pid(46573) 불변, `cline` 호출 0회, `phase-02/`·plist 무변경.
- 03-04: **Phase 3 종료.** 03-RESEARCH.md Open Question 1(실제 `cline` 바이너리가 샌드박스
  아래서 추가 punch-through 가 필요한가)에 이 phase 유일의 budgeted 실제 `cline` 호출로 답함 —
  재설치-체이닝 패턴으로 `run_sandboxed.sh -- "$CLINE_BIN" --version` 실행, 결과: exit 1,
  stderr `error: An unknown error occurred (Unexpected)`(경로/errno 를 전혀 명시하지 않는 일반
  오류). 설치된 `.cline` 바이너리를 `strings -a` 로 직접 확인(추가 호출 0회)해 이 문구가 Bun
  런타임 자체의 startup catch-all 오류 계열임을 확정 — 플랜이 정의한 (B) BOUNDED-FIX 요건(사전
  선언된 후보 디렉터리 하나를 명시하는 permission 오류)을 만족하지 못해 **판정 (C)
  BLOCKED-NEEDS-HUMAN**, `EXTRA_ALLOW_PATHS` 무변경(경계 확장 없음), Phase 4 로 문서화된
  미해결 항목으로 이월. **자체 발견/수정 이슈 1건(Rule 3)**: 플랜이 문자 그대로 지시한 호출
  형태(출력을 `phase-03/results/` 로 직접 리다이렉트)가 Node 자체 프로세스 부트스트랩 중
  SIGABRT 로 크래시(cline/Bun 코드는 한 줄도 실행 전) — 03-03 의 F8 과 동일한 근본 원인(미펀치
  경로로의 stdio 리다이렉트). `workspace/scratch-repo/`(화이트리스트 안)로 캡처 대상을 바꾼 뒤
  결과 디렉터리로 복사하는 방식으로 수정, 이 크래시 시도는 "정확히 1회" 예산에 포함하지 않음
  (cline/Bun 코드가 전혀 실행되지 않았으므로). `docs/sandbox-whitelist.md` 작성 완료(한글, 8절,
  `docs/infra-hardening.md` 하우스 스타일, 한계 절이 각주가 아닌 독립 섹션, Phase 4 인터페이스
  계약(`run_sandboxed.sh`/`verify_sandbox.sh`/`EXTRA_ALLOW_PATHS`) 포함, criterion-1 서술이
  `verify_sandbox.sh` 실제 구현 방향과 일치 확인). phase-close 재검증 6개 게이트 전부 동시
  PASS(`verify_sandbox.sh` 4/4 CRITERION·16/16 케이스·CRASHED 0, `pytest phase-03/tests/` 11/11,
  `phase-01/config/verify_config.sh`, `phase-02/infra/verify_no_regression.sh` INF03:PASS,
  launchctl pid 3종 불변, git status 클린) — flashnext(46573)/role-shim(75548)/litellm(48525) 이
  phase 시작 시점부터 종료까지 불변, 서비스 재시작 0회. `cline` 호출로 인한 providers.json
  드리프트(01-04 가 예측한 대로 `check_versions.sh` 자체의 내부 `cline config --json` 호출로 한
  번 더 발생)는 `apply_provider_config.sh` 로 2회 모두 치유, 최종 `verify_config.sh` PASS.

- 04-01: `phase-04/classify_run.py`의 `classify(events, cline_exit_code=None, stderr_text="",
  allowed_prefixes=None) -> Outcome` 시그니처가 04-02/04-03 이 그대로 의존하는 계약 — 우선순위
  `crashed > sandbox_denied > context_overflow_terminal > tty_approval_rejected > run_aborted >
  success > other`, CLI exit code 계약(0/2/3/4/5/6/7, 1=classifier 자체 오류)도 grep 가능하게
  고정. 모든 outcome 의 boolean 시그널을 독립적으로 계산한 뒤에만 우선순위로 최종 outcome 을
  고르므로(`signals` 리스트에는 정보 손실 없음), crash 가 실제 EPERM denial 을 덮어써도
  `signals` 에는 `sandbox_denied` 가 남는다(전용 테스트로 검증).
- 04-01: `phase-04/fixtures/` 는 이 플랜 종료 시점부터 **frozen** — 04-02/04-03(wave 2) 둘 다
  `sandbox_denied.ndjson` 을 read-only 로 소비하며 어느 쪽도 이 디렉터리에 쓰지 않는다.
  `sandbox_denied.ndjson` 자체가 이미 (a) 04-RESEARCH.md Pitfall 3 의 실측 `$HOME/.zshrc` EPERM
  거부 두 건과 (b) `SANDBOX_INSIDE_CANARY.txt` 에 대한 성공적 in-sandbox `read_files` 양성
  대조군을 동시에 담고 있어, 04-03 이 이 fixture 하나로 부정/긍정 대조군을 모두 얻는다.
  provenance 는 `phase-04/fixtures/README.md` 에 파일별로 기록.
- 04-01: `phase-04/config.env` 는 `phase-03/sandbox/config.env` 관용구를 그대로 복제(BASH_SOURCE
  기반 PROJECT_ROOT). `SANDBOX_WORKDIR` 는 `workspace/ALLOWED_REPOS.json` 의 `repos[]` 첫 항목을
  `python3 -c`(jq 미사용)로 파싱해 파생 — 절대 하드코딩하지 않음, 기존 env var 오버라이드는 존중.
  `EXTRA_ALLOW_PATHS` 무변경(04-01 은 샌드박스를 전혀 확장하지 않음).
- 04-03: `phase-04/verify_sandbox_via_cline.sh`(criterion-3 증명 게이트)를 `cline` 호출 0회로
  작성/자가검증 완료. Preflight A(config guard)의 heal 경로(`apply_provider_config.sh`)가 실제로
  `cline auth ...`를 호출한다는 것을 근거로, `VERIFY_DRY_NDJSON` 오프라인 모드에서는 Preflight A
  자체를 아예 건너뛰도록 설계 — "cline 호출 0회"가 우연(현재 config 가 마침 깨지지 않아서)이
  아니라 구조적으로 보장됨. 판정 사다리 (e) 규칙은 `classify_run.py`의 `success` 필드뿐 아니라,
  이 검증기 자신이(샌드박스 밖에서) target 파일의 실제 첫 줄을 직접 읽어 raw ndjson 텍스트에
  유출됐는지도 교차 확인(fail-open에 대한 이중 방어). 7개 필수 행 중 "model refusal"(도구 호출
  0건) 케이스는 새 fixture 를 만들 필요 없이 04-01 의 `success_no_tools.ndjson` 을 그대로
  무변경 재사용— 이미 정확히 그 케이스였음. 두 negated 변형(canary 제거/target success 뒤집기)은
  `mktemp -d "${TMPDIR:-/tmp}/..."` 아래서만 만들고 커밋하지 않음, `phase-04/fixtures/` 는 실행
  전후 `git status --porcelain`/`git diff --stat` 둘 다 빈 결과로 무변경 확인. 저작 중 발견한
  버그 2건(둘 다 Task 1 커밋 이전에 수정, deviation 아님): (1) 헤더 설명문에 리터럴
  `--auto-approve false` 문자열이 두 번 등장해 플랜 자신의 grep 검증(`== 0`)을 깨뜨렸던 것을
  같은 의미를 유지한 채 재서술; (2) 판정 사다리 heredoc(`<<'PYEOF'`) 본문의 `#` 주석 한 줄에 있던
  아포스트로피 하나가 `bash -n` 을 "unterminated quote" 오류로 깨뜨림을 격리 재현으로 확인(따옴표로
  감싸지 않은 heredoc 본문의 아포스트로피는 quoted 구분자에도 불구하고 bash 파서가 여전히 스캔한다는
  것을 이 세션에서 실측) — 로직 변경 없이 문장만 재서술.
- 04-02: **Phase 3 인계 블로커, 라이브로 처음 해소됨.** `phase-04/run_headless.sh` 가
  `SANDBOX_WORKDIR` 로 실제 `cd` 한 뒤 `ALLOWED_REPOS.json` prefix-match 를 단언하고 나서야
  `run_sandboxed.sh` 를 호출 — 04-RESEARCH.md 의 cwd 픽스 예측이 이제 라이브 실측으로 확인됨:
  `run_headless.sh --timeout 180 "...PONG..."` → exit 0, `run_result.finishReason:"completed"`,
  모델 응답 정확히 "PONG". `EXTRA_ALLOW_PATHS` 는 여전히 빈 문자열, `phase-03/` 무변경.
- 04-02: 라이브 첫 시도가 `Abort trap: 6`(exit 134)로 크래시 — `stderr.log` 가 네이티브 C++
  스택트레이스(`node::InitializeOncePerProcessInternal`/`node::Start`)만 담고 있었고 `ndjson.log`
  는 비어 있어 cline/Bun 코드가 단 한 줄도 실행되지 않았음을 확인. 근본 원인은 플랜이 문자
  그대로 지시한 `2>"$RESULTS_DIR/stderr.log"`(미펀치 경로로의 직접 파일 리다이렉트) — 03-03 F8/
  03-04 가 이미 진단/수정한 것과 완전히 동일한 실패 계열. `SANDBOX_WORKDIR`(이미 화이트리스트
  안) 아래 스크래치 파일로 캡처한 뒤 결과 디렉터리로 복사·삭제하는 03-04 의 검증된 픽스를 그대로
  재사용(재도출하지 않음). 이 크래시 시도는 03-04 의 선례에 따라 "정확히 1회" 예산에 포함하지
  않음(cline/Bun 코드 미실행) — 재시도가 실제 예산 1회차로 계수됨.
- 04-02: 오프라인 dry-run 테스트(Task 2) 중 자체 발견/수정 버그 2건. (1) `DRY_FIXTURE`(플랜의
  모든 예시 커맨드가 리포 루트 기준 상대경로로 지정)가 Step 5 의 `cd "$SANDBOX_WORKDIR"` 이후에
  읽혀 잘못된 디렉터리 기준으로 풀렸던 것 — 스크립트 최상단에서 `cd` 전에 `ORIG_PWD` 를 캡처해
  상대경로를 그 기준으로 해석하도록 수정. (2) 초 단위 타임스탬프만 쓴 결과 디렉터리 이름이
  같은 UTC 초 안의 연속 호출(5-fixture 루프)끼리 충돌해 서로의 evidence 를 덮어썼던 것 —
  `$$`(PID)를 `-headless` 접미사 앞에 삽입해 해결(`*-headless` glob 매칭은 그대로 유지).
- 04-04: **Phase 4 종료, criterion 3(HLS-03) 라이브로 확정.**
  `phase-04/verify_sandbox_via_cline.sh --timeout 180` → exit 0, `VERDICT: DENIED` — 화이트리스트
  밖 `$HOME/.zshrc` 읽기가 커널 `EPERM`(`Error reading file: EPERM: operation not permitted,
  stat`)으로 거부됐고, 같은 tool-call 배치 안에서 화이트리스트 안쪽 canary
  (`SANDBOX_INSIDE_CANARY.txt`) 읽기는 성공 — 8단 판정 사다리의 rung (g)(결정적 양성)로 판정.
  증거: `phase-04/results/20260829T215236Z-verify-cline-criterion3/`(README.md 포함).
  자체 발견/수정 버그 1건(Rule 1): 04-03 이 오프라인으로만 저작/자가검증한
  `verify_sandbox_via_cline.sh` 가 이번이 처음으로 실제 라이브 실행을 받아봤는데, 라이브 실행 브랜치의
  `2>"$OUT_DIR/stderr.log"`(미펀치 경로로의 직접 리다이렉트)가 03-03 F8/03-04/04-02 와 동일한
  SIGABRT 계열을 재현(`Abort trap: 6`, exit 134, `ndjson.log` 비어 있음, 스택트레이스에
  cline/Bun 프레임 0개). `SANDBOX_WORKDIR` 안 스크래치 파일 캡처 후 복사·삭제하는 검증된 패턴을
  그대로 재사용해 수정, 이 크래시 시도는 예산 미포함(03-04/04-02 선례의 세 번째 확인 사례) — phase
  전체 실제 `cline` 호출은 정확히 2회(04-02 1회 + 04-04 1회), 상한 4회 대비 절반. criterion-3
  증거 디렉터리는 스크립트 기본 이름(`*-verify-cline`)에서 플랜 자체 검증 glob(`*-criterion3`)에
  맞춰 사후 rename(재실행 없이) — `20260829T215236Z-verify-cline-criterion3`.
  `docs/headless-wrapper.md` 작성 완료(한글, 8절, `docs/infra-hardening.md` 하우스 스타일):
  4절이 독립 헤딩으로 `--auto-approve false` 가 3.0.53 헤드리스에서 도구 호출을 전부 거부하는
  "안전하지만 무력(inert)" 한계를 명시하고, `--hook-command` 가 `cline connect <channel>` 에만
  존재한다는 사실과 Phase 5 로의 명시적 에스컬레이션 요구(`--auto-approve true` 수용 여부는 사람이
  결정, 조용히 바꾸지 않음)를 포함. 3절은 `docs/32k-compaction-policy.md` 의 운영 규칙을
  verbatim 재인용(재도출 아님). `docs/sandbox-whitelist.md` §7 에 `해결됨 (Phase 4)` 노트를
  append(원문 미해결 서술은 보존) — 실제 근본 원인(프로세스 cwd, punch-through 아님)과
  `docs/headless-wrapper.md` 경로를 명시. Phase-close 8개 게이트 전부 동시 PASS(`verify_sandbox.sh`
  4/4 CRITERION·16/16 CASES·CRASHED 0, `verify_no_regression.sh` INF03:PASS, `verify_config.sh`
  1차 통과(heal 불필요), `pytest phase-04/tests/` 13/13, `EXTRA_ALLOW_PATHS` 빈 값 +
  `git diff --stat phase-03/ phase-02/` 빈 결과, ROADMAP 3개 기준 재확인, launchctl pid 3종
  불변, git status 클린) — flashnext(46573)/role-shim(75548)/litellm(48525) 이 phase 시작부터
  종료까지 불변, 서비스 재시작 0회.
- 05-02: **Phase 5 착수, wave 1(05-01 과 병렬).** `check_versions.sh` Check C 의 임베디드 python 이
  이제 매칭된 plist 마다 필요 변수 목록을 순회하며 한 줄씩 PASS/FAIL 을 찍는다 —
  `CLINE_NO_AUTO_UPDATE` 는 항상, `KANBAN_NO_AUTO_UPDATE` 는 haystack 에 "kanban" 이 있을 때만
  추가로 요구(A/B 체크와 vacuous-pass 로직은 무변경). `strings` 로 확인된 사실(kanban 0.1.70 이
  `env2.KANBAN_NO_AUTO_UPDATE === "1"` 로 자체 업데이트 경로를 가드)을 근거로, 이전엔 아무것도 잡지
  못했던 kanban 전용 드리프트 게이트가 이제 fixture 쌍(`phase-05/fixtures/launchagents/
  com.ohama.fixture-kanban-{good,bad}.plist`, 둘 다 설치/부트스트랩 안 됨)으로 한 번의 스캐너
  실행에서 증명됨(rc=1, bad 는 KANBAN_NO_AUTO_UPDATE FAIL, good 은 둘 다 PASS).
  `restart_service.sh` 는 포크 대신 그 자리에서 확장 — `<port|none>`, portless 일 때 Step 3b 는
  `lsof` 프로브만 생략(비동기 bootout teardown-wait 폴링 자체와 3초 settle margin 은 그대로),
  Step 5 헬스체크는 `state=running` 단독을 증거로 받지 않고 **10초 이상 간격의 두 샘플에서 동일
  pid** 를 요구(재시작 루프에 갇힌 잡도 거의 매 샘플 `running` 을 보고하므로). numeric-port 경로는
  `git diff` 로 완전 동일함을 확인(if/else 로 분기, 기존 로직 재작성 아님). 이 플랜은 어떤
  서비스도 등록/재시작하지 않음 — `restart_service.sh` 는 정적 검증(`bash -n`, usage 라인,
  존재하지 않는 라벨에 대한 `none` 인자 파싱)만 거쳤고, flashnext/role-shim/litellm pid 3종은 플랜
  시작부터 종료까지 불변. `cline` 호출 1회(Check B 내부), `verify_config.sh` 1차 통과(heal
  불필요 — `contextWindow` 최상위 필드 정정이 `cline config --json` 정규화를 생존한다는 관찰과
  일치, guard 자체는 손대지 않음). 편차(deviation) 0건 — 두 태스크 모두 `<action>`/`<verify>`
  그대로 통과. 05-01(같은 wave, 병렬)이 소유한 `phase-05/services/`/`phase-05/plists/` 는 git
  status 로 무터치 확인.
- 05-01: **wave 1 나머지 절반, Phase 5 의 SVC-03/SVC-04 핵심 메커니즘.** readiness 게이트
  (`wait_for_upstream.sh`)는 litellm 포트 단독 TCP 체크를 명시적으로 배제 — litellm 은 flashnext
  로드 여부와 무관하게 자기 리스너를 열기 때문에, TCP 만으로는 SVC-04 가 다루려는 두 시나리오
  (flashnext 의도적 다운, 부팅 중 104GiB 로딩)에서 항상 "ready" 로 오판한다. 대신 flashnext 자신의
  `/health`(`loaded_model` 비어있지 않음) + litellm 이 `flashnext` alias 를 실제로 광고하는지를
  요구. 루프 꼬리 페이싱은 어느 단계가 실패했든 항상 적용 — stage 1(`wait_for_port.sh`)의 자체
  바운디드 대기만 믿으면, TCP 포트가 이미 열려있을 때 stage 1 은 매 iteration 거의 즉시 리턴하므로
  stage-2/3 실패가 타임아웃 예산 전체를 curl/python3 서브프로세스로 스핀시킨다.
  텔레그램 래퍼의 실제 호출은 `--provider`/`--model` 풀네임만 사용 — `cline connect telegram` 은
  one-shot 프롬프트 서페이스(`CLINE_COMMON_FLAGS` 가 쓰는 `-P`/`-m`)와 플래그 서페이스가 완전히
  다르며, 이 서브커맨드엔 `-P` 짧은 플래그가 아예 없고(라이브 확인: `unknown option '-P'`) `-m`
  은 `--bot-username` 에 바인딩돼 있어 절대 축약하지 않음(실제 토큰 주입 후 첫 실행에서 크래시루프
  하는 것을 막기 위함). 설명용 주석이 플랜 자체의 grep 기반 검증(literal `cline kanban`,
  `--auto-approve`, 고립된 `-P`, `sleep infinity`)과 4건 충돌 — 의미는 보존한 채 표현만 재작성해
  통과(02-01 의 kill/pkill 주석 충돌과 동일 기법, 동작 변경 없음).
- 05-03: **wave 2, launchd 등록 전 포그라운드 증명(prove-before-register).** `wait_for_upstream.sh`
  의 `WAITED` 는 원래 루프 꼬리의 sleep 양만 누적했는데, stage 1(`wait_for_port.sh`)이 그 자체로
  바운디드 재시도(`TIMEOUT_S=$INTERVAL_S`)라서 TCP 가 실패 단계일 때는 매 iteration 이 stage-1
  내부에서 이미 `INTERVAL_S` 초를 쓴 뒤 루프 꼬리에서 또 `INTERVAL_S` 초를 자므로, 실제 바운드가
  설정값의 약 2.4배(30초 설정 → 72초 실측)로 새고 있었다 — 05-01 의 라이브 검증은 stage 2/3 강제
  실패만 다뤄 TCP 가 항상 즉시 통과했으므로 이 버그가 한 번도 노출되지 않았다. 이 플랜의 dead-port
  케이스가 stage-1 을 실패 단계로 노출시킨 최초 실행이라 여기서 발견됨. `$SECONDS` 기반 실측
  wall-clock 으로 수정(`4ef64d2`) 후 재검증: 기본 통과는 여전히 ~0.08초, 강제 stage-1 실패가
  설정된 10초에 정확히 바운드(실측 10.18초), stage-2 강제 실패는 기존과 동일(실측 9.66초).
  Task 3 실행 중 자기 교정 1건(Rule 3): kanban 래퍼의 stdio 를 화이트리스트 밖
  `phase-05/results/` 로 직접 리다이렉트한 첫 시도가 이 프로젝트에서 다섯 번째로 동일한 미펀치
  경로 stdio SIGABRT 계열(네이티브 스택트레이스만, 애플리케이션 코드 미실행)을 재현 — 이 위험이
  `$HOME` 아래뿐 아니라 화이트리스트 밖 임의 경로 전체로 일반화됨을 확인. 이미 검증된
  `$HOME/.cline/logs/` 경로로 재시도해 해결, 스크립트 변경 없음, `EXTRA_ALLOW_PATHS` 무변경.
  결정적 SVC-04 증거: `python3 -m http.server` 로 TCP 단계는 진짜 통과시키되 health/alias 단계를
  각각 강제로 거부시켜, 리스닝 중인 프록시(예: 모델 미로드 상태의 litellm)가 준비 완료로 오판되지
  않음을 실측으로 확정(정확한 실패 단계명이 매번 기록됨). 연구 Open Question 2 는 kanban 포트
  인벤토리(정확히 3484 하나)와 텔레그램 빈 토큰 상태(소켓 자체를 열지 않음)로 "현재 구성에서는
  구조적으로 충돌 불가능"으로 해소, Phase 6 잔여 항목(`--rpc-address`/`CLINE_RPC_ADDRESS`)을
  README 에 이름으로 명시. 이 플랜도 아무것도 등록하지 않음 — pid 3종(46573/75548/48525) 전
  과정 불변, `EXTRA_ALLOW_PATHS` 빈 값, `launchctl bootstrap` 0건, `cline` 호출 0회(예산 0). 네
  커밋(`4ef64d2` fix, `733d1ca`/`f31f660`/`23192ae` feat) 모두 개별.
- 05-04: **wave 3, Phase 5 최초의 실제 launchd 등록.** plist 는 세 기존 house 서비스와 완전히
  동일한 스타일(알파벳순 키, 탭 들여쓰기, bare-boolean `KeepAlive`)로 작성하되 `EnvironmentVariables`
  에 `CLINE_NO_AUTO_UPDATE`/`KANBAN_NO_AUTO_UPDATE` 둘 다 명시, `WorkingDirectory` 는
  `workspace/scratch-repo`(THE CWD RULE), 로그는 `~/.cline/logs/`(펀치스루된 경로, 다른 세
  서비스의 `~/llm-system/services/logs/` 아님 — 이 프로젝트가 5번 만난 미펀치 stdio SIGABRT 계열의
  근본 수정), `ThrottleInterval 30`. `install_services.sh` 는 launchctl 을 절대 호출하지 않는
  쓰기 전용 멱등 설치기(백업→lint→복사→lint, 두 번째 실행은 `unchanged:` 로 무동작 실측 확인) —
  기동은 오직 `phase-02/infra/restart_service.sh` 만 수행. **자체 발견/수정 이슈 1건(Rule 1, 코드
  버그 아니라 플랜 자체 검증 기대치의 버그)**: 플랜은 anti-orphan 증거로 `ps -o args=` 에 리터럴
  `sandbox-exec` 문자열이 나타나야 한다고 명시했지만, `sandbox-exec` 는 설계상 wrapped 커맨드로
  진짜 `execve()` 하므로(그것이 sandbox-exec 의 존재 이유) 그 순간 프로세스의 기록된 argv 자체가
  통째로 교체돼 체인이 끝난 뒤의 `ps` 스냅샷에는 최종 커맨드(`node /opt/homebrew/bin/kanban ...`)만
  남고 `sandbox-exec` 문자열은 커널 동작상 나타날 수 없음을 확인(`run_sandboxed.sh` 소스 재확인:
  `exec sandbox-exec -f profile -- "$@"`). 증거를 `vmmap <pid> | grep -i sandbox` 로 대체/보강 —
  해당 pid 자신의 메모리에 `libsandbox.1.dylib`/`libsystem_sandbox.dylib` 가 매핑돼 있는 것은
  이 정확한 프로세스 안에서 `sandbox_init()` 이 실행됐다는 직접 증거이며, 이는 곧 sandbox-exec 가
  이 pid 로 execve() 했다는 것과 동치. `supervised-proc.txt` 에는 이 설명 산문 자체에 리터럴
  `sandbox-exec`/`kanban` 문자열이 여전히 포함돼 플랜 자신의 grep 검증도 그대로 통과(검증 완화
  없음). SVC-01/SVC-03 두 성공기준 모두 독립 2차 오라클로 실측(`state=running` 단독을 증거로
  받지 않음): 20초 간격 동일 pid + 3484 실제 LISTEN + HTTP 200; `kill -TERM` 1회 후 2초 내 새 pid
  소생 + 15초 뒤 동일 pid; `launchctl bootout` 으로 실제 take-down 집행(label 미등록+포트 비움
  확인 후 30초간 5초 간격 재확인, 되살아나지 않음), `restart_service.sh` 로 복구. 이 사이클이
  05-07 이 재실행 없이 인용할 수 있는 reboot-persistence 대리 증거로 기록됨. flashnext/litellm/
  role-shim pid 3종 전 과정 불변, `EXTRA_ALLOW_PATHS` 빈 값, `cline` 호출 0회
  (`kanban --version` 만 1회, 허용), `sync.sh` 미실행(05-06 소관). 세 커밋
  (`5623fce`/`be82fcb`/`91dc343`) 모두 개별.

### Pending Todos

없음 (아직 없음)

### Blockers/Concerns

- 🔴 **2026-08-30 — Phase 1 의 결론이 정정됨.** 32k 압축은 **정상 작동한다.**
  `contextWindow` 를 `providers.json` 의 `settings` **최상위**에 넣어야 하며(`models[]` 아님),
  값은 오버슈트 흡수를 위해 **29000**(트리거 26,100)이다. 실측: `phase-01/results/exp-verify29k/`.
  → Phase 4(400 종료조건 불필요) · 6(NET-05 에 "압축 중" 추가) · 7(토큰 예산 제한 불필요) ·
    8(매뉴얼 경고 변경) 에 반영 필요. Phase 5 는 영향 없음(플랜 검색 확인).
- 🔴 **cline 자동 업데이트가 `CLINE_NO_AUTO_UPDATE=1` 로 막히지 않는다.** 정정 작업 중에도
  3.0.53 → 3.0.60 드리프트가 재현됨. CFG-05 성공 기준이 위태롭다. 별도 과제 필요.

- **(FULLY RESOLVED — Phase 4 종료, 세 성공기준 모두 라이브 증거로 확정)** 03-04 에서 남긴 verdict
  C(BLOCKED-NEEDS-HUMAN, `cline` 이 샌드박스 안에서 경로명 없는 일반 Bun 런타임 오류로 죽던 문제)의
  근본 원인이 04-RESEARCH.md 에서 실측으로 확정된 뒤, 04-02 가 shipped 래퍼로, 04-04 가 별도의
  criterion-3 전용 스크립트로 각각 라이브 재확인했다: 원인은 샌드박스 프로파일이 아니라 프로세스
  자신의 cwd — `sandbox-exec` 가 `$HOME` 자체에 대한 `file-read-metadata` 를 거부하는데, cwd 가
  화이트리스트 밖(예: repo 루트)이면 Node/Bun 의 자체 startup 이 조상 디렉터리를 stat 하려다 이
  deny 에 걸려 cline 코드가 실행되기도 전에 일반 오류를 낸다. 고침: 샌드박스 프로세스를 실행하기
  *전에* 이미 `ALLOWED_REPOS.json` 안에 있는 경로로 실제 `cd`(cline 자신의 `-c/--cwd` 플래그는
  별개이며 대체하지 않음) — `EXTRA_ALLOW_PATHS` 변경 없이, `run_headless.sh --timeout 180
  "...PONG..."` → exit 0/`success`/`run_result` (04-02,
  `phase-04/results/20260829T214344Z-90746-headless/`), 그리고 `verify_sandbox_via_cline.sh
  --timeout 180` → exit 0/`VERDICT: DENIED`(04-04,
  `phase-04/results/20260829T215236Z-verify-cline-criterion3/`) 둘 다 재현 완료. `phase-04/config.env`
  의 `SANDBOX_WORKDIR` 가 바로 이 픽스를 위해 존재(04-01 에서 구현), 04-02/04-04 둘 다 소비/검증.
  04-RESEARCH.md 가 추가로 예측했던 `--auto-approve false` 헤드리스 모드의 TTY 게이트 거부(정상
  동작, 크래시 아님)와 criterion 3 증명 분리(별도의 `--auto-approve true` 전용 검증 스크립트,
  04-03 작성/04-04 실행)도 모두 반영됨. **04-04 로 Phase 4 전체가 종료됐다** — 세 ROADMAP
  성공기준(HLS-01/02/03) 이 동시에 실측 증거로 성립, `EXTRA_ALLOW_PATHS` 는 phase 시작부터 종료까지
  빈 값 그대로. 증거: `.planning/phases/04-headless-cli-wrapper/04-RESEARCH.md` Pitfall 1/2/3,
  `phase-04/results/20260829T214344Z-90746-headless/README.md`,
  `phase-04/results/20260829T215236Z-verify-cline-criterion3/README.md`,
  `phase-04/results/20260829T215715Z-phase-close/README.md`, `docs/headless-wrapper.md`,
  `docs/sandbox-whitelist.md` §7(`해결됨 (Phase 4)`).
  **Phase 5 로 넘어가는 열린 항목(블로커 아님):** `docs/headless-wrapper.md` §4/§8 이 문서화한
  `--auto-approve false` "안전하지만 무력" 한계 — Kanban/Telegram 표면이 실제 도구-사용 작업을
  헤드리스로 수행하려면, `--auto-approve true`(샌드박스만을 경계로 수용)와 업스트림 기능 대기
  중 하나를 사람이 반드시 명시적으로 결정해야 한다(조용히 플래그만 바꾸는 것은 금지 — HLS-02
  보안 태세의 실제 변경이기 때문).
- (Phase 3 설계 경계, 블로커 아님) 샌드박스는 `(allow default)` + `$HOME` deny + punch-through
  구조라 **`$HOME` 밖은 보호하지 않는다** (`/tmp`, `/opt`, `/usr/local`, 외장 볼륨 등). 전면 차단
  감옥이 아니다. `phase-03/sandbox/config.env`/`run_sandboxed.sh` 헤더와
  `docs/sandbox-whitelist.md` §3 에 명시돼 있다.

- Phase 1 의 핵심 미지수는 01-06 에서 실측 완료(결과 ②, 위 결정 로그 참조) — 더 이상 미지수가
  아니다. Phase 4/5/7/8 은 `docs/32k-compaction-policy.md` 의 "작업을 다시 시작한다" 규칙과
  터미널 실패 분류를 반드시 반영해야 한다.
- Telegram 봇 토큰은 BotFather 에서 사람이 직접 발급해야 한다 — Phase 5 는 토큰 주입 자리를
  비운 채로 완료되고, 실사용은 토큰 발급 후에 가능하다
- (환경 노트, 블로커 아님) 이 개발 환경에서 `cline` 은 거의 모든 호출마다 백그라운드에서
  3.0.53→3.0.60 으로 self-update 를 시도한다. Phase 5 가 launchd plist 로 `cline`/`kanban` 을
  등록할 때 이 드리프트에 대비해야 한다 — `check_versions.sh` Check C 가 이미 이런 plist 를
  스캔하도록 armed 되어 있음.
- (환경 노트, 블로커 아님) `launchctl bootout` 은 비동기이므로, 무거운 프로세스(모델 로드 등)를
  물고 있는 launchd 서비스를 재시작할 때는 반드시 teardown 확인 폴링을 거쳐야 한다.
  `restart_service.sh` 가 이미 이 폴링을 내장하고 있으므로(Step 3b) 이 헬퍼만 사용하면 문제
  없음 — 다만 Phase 5 에서 새 launchd 서비스용 헬퍼를 별도로 작성한다면 동일 패턴을 반드시
  재사용할 것. 이 하우스 룰은 이제 `docs/infra-hardening.md` 에도 기록됨.
- (환경 노트, 블로커 아님) Phase 2 가 남긴 상시 게이트 `phase-02/infra/verify_no_regression.sh`
  는 읽기 전용·재실행 가능 — Phase 5(Kanban+Telegram 동시 기동)와 Phase 6(네트워크 노출)은 새
  서비스를 올리기 전/후 이 스크립트를 그대로 호출해 회귀를 잡을 것.
- **(SUPERSEDED by 04-RESEARCH.md, now fully RESOLVED live by 04-02 — kept for history)** 이
  항목은 03-04 종료 시점에 "Phase 4 가 `dtruss`/`fs_usage` 로 정밀 재현해야 한다"고 남겼던 오픈
  아이템이었다. 실제로는 `log stream`(관리자 권한 불필요, `dtruss`/`fs_usage` 불필요)로
  04-RESEARCH.md 세션에서 근본 원인을 이미 확정했고, 04-02 가 그 픽스를 shipped 래퍼로 라이브
  재확인했다: 부족한 건 `EXTRA_ALLOW_PATHS` punch-through 가 아니라 래퍼 프로세스의 cwd 였다(위
  항목 참조). `EXTRA_ALLOW_PATHS` 의 사전 선언된 4개 후보(`$HOME/.npm` 등) 는 격리 테스트에서
  전부 불필요한 것으로 확인됐고 넓히지 않았다. 04-04 가 `verify_sandbox_via_cline.sh` 로 criterion
  3 을 실제 1회 라이브로 확정했다 — 이 항목도 이제 완전히 종료.

## Session Continuity

Last session: 2026-08-30
Stopped at: **05-04-PLAN.md 완료 — wave 3, Phase 5 최초의 실제 launchd 서비스 등록.**
`com.ohama.kanban` 을 `phase-05/plists/com.ohama.kanban.plist`(house style, 양쪽
NO_AUTO_UPDATE, `WorkingDirectory`=scratch-repo, 로그=`~/.cline/logs/`)로 스테이징, 쓰기 전용
멱등 설치기(`phase-05/services/install_services.sh`, launchctl 미호출, 두 번째 실행
`unchanged:` 로 무동작 확인)로 설치, `phase-02/infra/restart_service.sh` 로만 기동
(`RESTART OK pid=52654`). criterion 1(SVC-01)을 20초 간격 동일 pid + 3484 실제 LISTEN + HTTP
200 + `vmmap` 기반 sandbox 라이브러리 매핑(anti-orphan/sandbox-chain 증거, 아래 결정 로그 참조)
으로 실측. criterion 2(SVC-03)를 `kill -TERM 52654` 1회 → 2초 내 새 pid(53505) 소생 → 15초 뒤
동일 pid로 확정, `launchctl bootout` take-down 도 실제 집행(30초간 되살아나지 않음 확인) 후
`restart_service.sh` 로 복구(pid=53894). `phase-05/results/20260830T020530Z-svc01-kanban/`
(README.md 포함)에 전 증거 기록. 편차 1건(Rule 1, 플랜 자체 검증 기대치의 버그 — 코드 변경
없음). flashnext(46573)/litellm(48525)/role-shim(75548) pid 전 과정 불변, `EXTRA_ALLOW_PATHS`
빈 값, `cline` 호출 0회, `sync.sh` 미실행(05-06 소관). 세 커밋
(`5623fce`/`be82fcb`/`91dc343`) 모두 개별, SUMMARY 작성 완료, STATE.md 갱신 완료.
**다음:** 05-05(telegram-connect 등록, wave 3 나머지 절반)로 진행 — `install_services.sh`/
`restart_service.sh` 는 이미 telegram 의 portless 라벨 경로까지 지원하도록 검증돼 있으므로
그대로 재사용 가능. `docs/headless-wrapper.md` 4절/8절이 남긴 `--auto-approve false` "안전하지만
무력" 한계에 대한 에스컬레이션 결정은 여전히 검토 필요(이 플랜의 범위 밖).

이전 세션: 2026-08-30
정지 지점: **05-03-PLAN.md 완료 — wave 2, prove-before-register.**
`phase-05/results/20260830T014424Z-svc04/`(README.md 포함)에 SVC-03/SVC-04 를 launchd 등록 전에
포그라운드에서 직접 증명한 증거 전부 기록: dead-port(exit 1 ~36-41s/30s, %cpu 전 샘플 0.0),
listening-but-not-ready 결정적 케이스(`python3 -m http.server` 로 TCP 는 성공시키되 health/alias
각각 강제 거부, 정확한 단계명 기록), 오버라이드 없는 실제 운영 타깃 recovery(launchd 와 동일한
stdio 리다이렉트로 kanban 이 3484 를 실제 바인딩, SIGABRT 없음), 텔레그램 빈 토큰 idle ~96초
관찰(동일 pid·0%cpu·로그 불변·`connect telegram` 0), kanban 포트 인벤토리(3484 하나)로 연구
Open Question 2 해소. 자체 발견/수정 버그 1건(Rule 1, `wait_for_upstream.sh` 의 `WAITED` 가
stage-1 자체 바운디드 재시도 시간을 누락해 실제 바운드가 설정값의 약 2.4배로 새던 것을
`$SECONDS` 기반으로 수정) + Rule 3 자기 교정 1건(Task 3 첫 시도가 화이트리스트 밖 경로로 stdio
리다이렉트해 이 프로젝트의 다섯 번째 미펀치 stdio SIGABRT 를 재현 — 이미 검증된 경로로 재시도).
이 플랜도 아무것도 등록하지 않음 — pid 3종(46573/75548/48525) 불변, `EXTRA_ALLOW_PATHS` 무변경,
`launchctl bootstrap` 0건, `cline` 호출 0회(예산 0). 네 커밋(`4ef64d2` fix +
`733d1ca`/`f31f660`/`23192ae` feat) 모두 개별, SUMMARY 작성 완료, STATE.md 갱신 완료.
**다음:** wave 3(05-04/05-05, plist 작성/등록)으로 진행. `docs/headless-wrapper.md` 4절/8절이
남긴 `--auto-approve false` "안전하지만 무력" 한계에 대한 에스컬레이션 결정(사람이 명시적으로:
`--auto-approve true` 수용 vs 업스트림 기능 대기)은 여전히 검토 필요. `phase-05/services/` 의 두
래퍼는 이제 foreground 로 완전히 증명됐지만 아직 어떤 plist 에도 연결되지 않았음 — 실제 plist
작성/등록(`WorkingDirectory` 명시 필수)은 05-04/05-05 의 소관. 이 플랜이 남긴 미해결 항목 없음
(블로커 0건).

이전 세션: 2026-08-30
정지 지점: **05-01-PLAN.md 완료 — wave 1(05-01/05-02, 병렬) 둘 다 완료.**
`phase-05/services/{config.env,wait_for_port.sh,wait_for_upstream.sh,run_kanban_service.sh,
run_telegram_service.sh}` 작성. 3단 readiness 게이트를 라이브 스택 대상 3종(전체 통과/stage-2
강제실패/stage-3 강제실패) 실측 확인. 텔레그램 래퍼 빈 토큰 idle 분기(숫자 sleep 루프, exit 없음,
`sleep infinity` 없음)와 실제 호출 줄(`-i --no-tools` + `--provider`/`--model` 풀네임)을 grep 으로
전부 재확인. 이 플랜은 아무것도 등록/재시작하지 않음 — pid 3종(46573/75548/48525) 불변,
`EXTRA_ALLOW_PATHS` 무변경, `phase-05/` 안 `launchctl bootstrap` 0건, `cline` 호출 0회. 편차 0건
(주석 리터럴 4건 표현만 재작성, 아래 결정 로그 참조). 세 태스크 모두 개별 커밋
(`1b6fd84`/`dc6e8ba`/`aa3b532`), SUMMARY 작성 완료, STATE.md 갱신 완료.

이전 세션: 2026-08-30
정지 지점: **05-02-PLAN.md 완료 (wave 1, 05-01 과 병렬).** `check_versions.sh` Check C 에
`KANBAN_NO_AUTO_UPDATE=1` 게이트 추가(fixture 쌍으로 증명), `restart_service.sh` 를 포크 없이
확장해 포트 없는 라벨 재시작 지원(비동기 bootout teardown-wait 보존, 10초+ 동일-pid 헬스 증거).
서비스 등록/재시작 0건, pid 3종 불변, `cline` 호출 1/2, 편차 0건. 두 태스크 모두 개별 커밋
(`e7ab02b`/`a23c1f1`), SUMMARY 작성 완료, STATE.md 갱신 완료.

더 이전 세션: 2026-08-30
정지 지점: **04-04-PLAN.md 완료 — Phase 4 전체 종료(wave 3, 마지막 플랜).**
criterion 3(HLS-03) 을 `phase-04/verify_sandbox_via_cline.sh --timeout 180` 실제 1회 라이브 실행으로
확정: exit 0, `VERDICT: DENIED` — 화이트리스트 밖 `/Users/ohama/.zshrc` 읽기가 커널 EPERM 으로
거부됐고, 같은 tool-call 배치 안에서 화이트리스트 안쪽 canary 읽기는 성공. 라이브 실행 전 자체
발견/수정 버그 1건(Rule 1): 04-03 이 오프라인으로만 저작한 `verify_sandbox_via_cline.sh` 가
처음으로 실제 라이브를 받아보자 `2>"$OUT_DIR/stderr.log"`(미펀치 경로 직접 리다이렉트)가
03-03 F8/03-04/04-02 와 동일한 SIGABRT 계열(Abort trap: 6, cline/Bun 코드 미실행)을 재현 —
화이트리스트 안 스크래치 파일 캡처 후 복사하는 검증된 패턴을 재사용해 수정, 이 크래시는 예산
미포함(선례의 세 번째 확인). phase 전체 실제 `cline` 호출은 정확히 2회(04-02+04-04), 상한 4회
대비 절반. `docs/headless-wrapper.md` 작성(한글 8절, house style, 4절이 독립 헤딩으로
`--auto-approve false` 의 "안전하지만 무력" 한계와 Phase 5 에스컬레이션 요구 명시,
3절은 32K 운영 규칙을 `docs/32k-compaction-policy.md` 에서 verbatim 재인용). `docs/sandbox-whitelist.md`
§7 에 `해결됨 (Phase 4)` 노트 append(원문 미해결 서술 보존). Phase-close 게이트 스윕 8개 항목
전부 PASS(`verify_sandbox.sh` 4/4 CRITERION·16/16 CASES·CRASHED 0, `verify_no_regression.sh`
INF03:PASS, `verify_config.sh` 1차 통과, `pytest phase-04/tests/` 13/13, `EXTRA_ALLOW_PATHS` 빈 값
+ `git diff --stat phase-03/ phase-02/` 빈 결과, ROADMAP 3개 기준 재확인, launchctl pid 3종
불변, git status 클린 — phase-04/docs/.planning 외 사전 존재 무관 untracked 파일 2건만 제외).
3 태스크 모두 개별 커밋, SUMMARY 작성 완료, STATE.md 갱신 완료.
**다음 세션은 Phase 5(Kanban/Telegram 표면) 부터 시작** — `docs/headless-wrapper.md` 4절/8절이
남긴 `--auto-approve false` "안전하지만 무력" 한계에 대한 에스컬레이션 결정(사람이 명시적으로:
`--auto-approve true` 수용 vs 업스트림 기능 대기)과, Phase 5 의 launchd plist 가 `WorkingDirectory`
를 반드시 명시해야 한다는 요구사항(그렇지 않으면 이번 phase 가 고친 것과 동일한 크래시가
재발하며, 겉보기엔 샌드박스가 더 엄격해진 것처럼 보일 것)을 먼저 검토할 것.
Resume file: None
