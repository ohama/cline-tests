# 02. 웹 Kanban 사용법

근거 문서: docs/services.md §2·§5·§5a, docs/network-exposure.md §2,
.planning/phases/08-korean-user-manual/08-RESEARCH.md §A.

이 문서는 **사용법**이다 — 왜/어떻게 검증됐는지는 위 근거 문서들을 볼 것, 여기서는 반복하지
않는다. 여기 적힌 모든 명령은 이 phase 가 라이브 서버를 상대로 직접 실행해 기록한
전사(transcript)에서 그대로 옮긴 것이다(`phase-08/results/20260830T194933Z-doc02/`) —
소스 코드를 읽고 짐작한 절차가 아니다.

**이 문서는 부분적으로만 충족(partially met)된 상태다.** 카드/등록/diff 리뷰/의존 체인은
실측으로 동작이 확인됐지만, Kanban 의 핵심 기능인 **작업(task)별 worktree 는 이 배포에서
지원되지 않는다** — 6절 참고. 이 사실을 완화하거나 승격해 적지 않는다.

## 1. 접속

로컬:
```
http://127.0.0.1:3484/
```

iPad/iPhone 에서: `docs/manual/03-mobile.md` 를 볼 것 — tailnet 접속 절차는 여기서
되풀이하지 않는다.

## 2. 프로젝트 등록 — 반드시 `workspace/scratch-repo` 안에서 실행한다

**왜 위치가 중요한가.** `kanban` CLI 는 실행된 디렉터리를 그대로 등록 대상으로 쓰지 않는다 —
항상 그 경로가 속한 git **최상위(top-level)** 를 계산해서 그걸 등록 대상으로 삼는다
(`resolveWorkspacePath`, `--project-path` 를 명시적으로 줘도 우회되지 않는다). 그래서
저장소 루트(`/Users/ohama/projs/cline-tests`)에서 CLI 를 실행하면, kanban 은 바로 그
루트를 등록하려고 시도한다 — 그런데 그 경로는 `workspace/ALLOWED_REPOS.json` 이 **영구적으로
금지**하는 딱 하나의 경로다(`bench/` 가 그 아래에 있고, SBX-04 는 `bench/` 가 샌드박스
안에서 아예 닿지 않아야 한다고 요구하기 때문이다). 그래서 `workspace/scratch-repo` 는 자기
자신의 git 저장소가 되도록 `git init` 돼 있고(그 자체가 최상위이므로), 서비스는
`GIT_CONFIG_GLOBAL=/dev/null` 을 export 해서 샌드박스가 거부하는 `~/.gitconfig` 를 git 이
아예 읽으려 하지 않게 만든다 — 이 두 조치의 정확한 이유와 롤백 절차는 `docs/services.md`
§5a 에 있다, 여기서 재설명하지 않는다.

실제 작동하는 호출(이번 실측 그대로):
```
cd workspace/scratch-repo
export KANBAN_NO_AUTO_UPDATE=1
kanban task list
```
`workspace/scratch-repo` **바깥**에서 실행하면 등록되지 않은 경로를 조회/등록하려다 실패한다.

이 프로젝트는 현재 등록돼 있다(2026-08-31 실측, `phase-08/results/20260830T191320Z-kanban-fix/
registration/VERDICT.txt`):
```
REGISTERED: kanban task create succeeded (task id=9bf8f, ...), kanban task list confirms
the task with no 'is not added to Kanban yet' error, HTTP 200, no post-restart gitconfig
denial in logs.
```

## 3. 카드

CLI 가 실제로 제공하는 하위 명령은 정확히 여덟 개다(`kanban task --help`): `list`, `create`,
`update`, `trash|done`, `delete`, `link`, `unlink`, `start`. 모두 `workspace/scratch-repo`
안에서 실행해야 한다.

**목록 보기:**
```
kanban task list
kanban task list --column backlog   # backlog | in_progress | review | done | trash
```

**만들기(backlog 에 생성):**
```
kanban task create --title "제목" --prompt "프롬프트"
```
실측 예(`phase-08/results/20260830T194933Z-doc02/card-lifecycle.txt`):
```
$ kanban task create --title "DOC-02 throwaway probe" --prompt "08-05 live evidence probe, safe to delete"
{"ok":true,"task":{"id":"c44a4","column":"backlog", ...}}
```

**옮기기 — CLI 에는 임의 컬럼 이동 명령이 없다.** CLI 로 확인되는 컬럼 전이는 딱 두 가지뿐이다:
`kanban task start --task-id <id>` (backlog → in_progress, 작업 세션 시작), `kanban task
trash --task-id <id>` (임의 컬럼 → done). `in_progress`/`review` 사이의 이동이나 임의
컬럼으로의 자유 이동은 CLI 표면에 없다 — 존재한다면 웹 UI 뿐이며, 이 문서는 웹 UI 를 직접
조작해 확인하지 않았다.

**지우기:**
```
kanban task delete --task-id <id>
```
실측 예(같은 전사): 카드를 만들고, `kanban task list` 로 보드에서 확인하고, `kanban task
delete --task-id c44a4` 로 지운 뒤 다시 `kanban task list` 로 사라졌음을 확인했다. 삭제
응답에는 `worktreeCleanup: [{"taskId":"c44a4","removed":false}]` 가 함께 왔다 — 애초에
worktree 가 생성된 적이 없었다는 뜻이며, 이는 6절의 사실과 정확히 일치한다.

## 4. diff 리뷰

`kanban task --help` 의 전체 하위 명령 목록(3절)에는 `diff` 나 `review` 이름의 명령이
없다 — CLI 에서 태스크의 변경사항을 직접 보여주는 표면은 확인되지 않았다
(`phase-08/results/20260830T194933Z-doc02/subcommands.txt`, 전체 `--help` 스캔). diff
리뷰는 웹 UI 의 몫으로 보이나, 이 문서는 웹 UI 를 직접 열어 확인하지는 않았다.

`git -C workspace/scratch-repo log --oneline` 로 실제 커밋 이력을 봐도, 08-01 이 등록
당시 남긴 최초 커밋(`3d8ef27`, "init scratch repo" — 등록 스크립트가 자동 생성) 하나뿐이다 —
5절의 태스크 단위
체크포인트 커밋이 한 번도 생긴 적이 없다는 뜻이며, 이 역시 6절의 worktree 불가와 맞물려
있다(작업 세션이 실제로 시작된 적이 없으므로 커밋할 것도 없었다).

## 5. ⚠️ [GAP-CHECKPOINT-KANBAN] 태스크 체크포인트 — cline 의 세션 체크포인트와 다르다

Kanban 은 **작업(task) 단위**로 working-tree 커밋을 만드는 자체 체크포인트를 갖고 있다
(`createWorkingTreeCheckpointCommit`). 이 함수는 `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`/
`GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL` 을 직접 env 로 주입하기 때문에,
`GIT_CONFIG_GLOBAL=/dev/null` 로 `user.name`/`user.email` 이 사라진 뒤에도 계속 동작한다
(2절 참고).

이건 cline 자신의 **세션(에이전트 실행) 단위** 파일 체크포인팅(`createCheckpoint`/
`restoreCheckpoint`, `cline-checkpoint-` git-ref 접두사)과는 **다른 것**이다 — 그건
`docs/manual/01-cli.md` 7절의 몫이다. 이 두 개념을 섞지 말 것.

## 6. ⚠️ [GAP-WORKTREE] worktree 생성은 이 배포에서 지원되지 않는다

**Kanban 은 원래 작업(task)마다 별도의 `git worktree add` 로 독립 작업 디렉터리를 만든다.
이 배포에서는 그게 지원되지 않는다** — "아직 확인되지 않았다"가 아니라, 세 가지 서로 다른
call-shape(순수 상대경로, 여러 단계 중첩 경로, 사전에 만들어 둔 빈 타깃 디렉터리)를 전부
직접 실행해 **재현으로 확인된** 사실이다. 전부 동일하게 실패한다:
```
fatal: Invalid path '/Users/ohama': Operation not permitted   (exit 128)
```

**원인.** `git worktree add` 는 대상 경로의 조상을 루트부터 순서대로 stat 하는데, 이
프로젝트 전체가 `$HOME`(`/Users/ohama`) 아래에 있고 샌드박스는 `$HOME` 자신에 대한
`file-read-metadata` 를 거부한다. 이 조상-stat 자체를 피하는 env var·git 플래그·call-shape
은 존재하지 않는다 — **no-widening 수정은 없다.**

**존재하는 유일한 해법은 샌드박스 경계를 넓히는 것이고, 사용자가 2026-08-31 에 이를
거절했다(DECLINED).** 정확한 변경 내용(`gen_sandbox_profile.py` 의 `render_profile()` 이
`$HOME` deny 를 `file-read-data` 전용으로 좁히고 `file-read-metadata` 는 별도로 허용하는
것)과 정확한 비용(`$HOME` 아래 이미 아는 경로의 stat 급 메타데이터 — 존재/크기/권한/소유자/
타임스탬프 — 가 읽히게 됨; 파일 내용과 디렉터리 나열, 쓰기는 계속 막힘)은 전부 실측·기록돼
있다 — `docs/sandbox-whitelist.md` §9, 실행 기록은
`phase-08/results/20260830T193634Z-widening/DECISION.md`. 이 승인 없이는 worktree 생성이
동작하지 않는다.

## 7. 의존 체인

`kanban task link --task-id <A> --linked-task-id <B>` 로 두 태스크를 연결한다. 둘 다
backlog 에 있으면 순서가 그대로 보존된다 — `--task-id` 가 `--linked-task-id` 를 기다리는
쪽이 되고, 보드의 화살표는 `--linked-task-id` 를 가리킨다. 연결을 없애려면
`kanban task unlink --dependency-id <id>` 를 쓴다.

실측 예(`phase-08/results/20260830T194933Z-doc02/dependency-chain.txt`): 임시 태스크
`b2b86`("A")와 `fbc51`("B")를 만들고 `kanban task link --task-id b2b86 --linked-task-id
fbc51` 을 실행하자, `kanban task list` 응답의 `dependencies[]` 배열에
`{"backlogTaskId":"b2b86","linkedTaskId":"fbc51", ...}` 가 실제로 나타났다. 이후
`kanban task unlink --dependency-id <그 dependency 의 id>` 로 연결을 지우고,
`kanban task delete` 로 두 임시 태스크를 모두 정리해 보드를 원상태로 되돌렸다(9bf8f 하나만
남음).

한쪽 선행 태스크가 review 를 끝내고 done 으로 이동하면, 기다리던 backlog 태스크가 시작
가능(ready) 상태가 된다 — 이건 CLI `--help` 텍스트에 명시된 동작이며, 이 문서는 실제로
review→done 전이를 겪어 ready 상태 전환을 라이브로 관찰하지는 않았다(3절의 컬럼 이동 제약과
같은 이유 — CLI 만으로는 review 컬럼에 태스크를 진입시킬 방법이 없었다).

## 8. ⚠️ [GAP-READONLY] Kanban 은 보드를 보여줄 뿐, 원격 쓰기 API 가 아니다

Kanban 웹 UI/CLI 는 보드 상태를 보여주고 태스크를 만들지만, 이 프로젝트가 실제로 노출하는
에이전트 실행 표면은 `--no-tools`(telegram)와 `--auto-approve false`(헤드리스) 두 가지뿐이다
— **원격에서 트리거된 에이전트는 파일을 수정할 수 없다.** 이 태세를 뒤집는 것은 사람이
명시적으로 내려야 하는 보안 결정이다(`docs/headless-wrapper.md` §4·§8) — 이 매뉴얼은
누구에게도 플래그를 뒤집으라고 말하지 않는다. 자세한 내용은 `docs/manual/01-cli.md` 5절.

## 9. 재시작과 문제 해결

접속 체인은 다음 세 단계다(원격 접속은 3절 참고):
```
tailscale serve :8444 -> com.ohama.kanban-proxy, 127.0.0.1:18484 -> com.ohama.kanban, 127.0.0.1:3484
```

**유일하게 정식으로 허용되는 재시작:**
```
bash phase-02/infra/restart_service.sh com.ohama.kanban 3484
```

**내리기(take-down):**
```
launchctl bootout gui/$(id -u)/com.ohama.kanban
```

`kill`/`pkill`, `launchctl load|unload|kickstart` 는 절대 쓰지 않는다.

**로그:** `~/.cline/logs/kanban.log` / `.err` — 자동으로 회전(rotate)되지 않으므로, 필요하면
`: > ~/.cline/logs/kanban.log` 로 직접 비운다.

**상시 확인:**
```
bash phase-05/services/verify_services.sh
```
read-only, 재실행 가능. 모든 `CHECK` 줄이 `PASS`, 마지막 `CASES N/N` 이 전부 통과여야 정상.

---
*근거: docs/services.md, docs/network-exposure.md, .planning/phases/08-korean-user-manual/08-RESEARCH.md, docs/sandbox-whitelist.md §9*
