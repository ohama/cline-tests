# Phase 8: 한글 사용 매뉴얼 - Research

**Researched:** 2026-08-31
**Domain:** (A) macOS Seatbelt 샌드박스 + Kanban(simple-git 기반) 프로젝트 등록 블로커의 근본원인 진단, (B) 사용자 매뉴얼 구조/콘텐츠 리서치
**Confidence:** HIGH (A — 실측+소스코드 대조), MEDIUM-HIGH (B — 문서 인벤토리 기반, 매뉴얼 자체는 아직 안 씀)

## Summary

**PRIMARY 작업(블로커 진단) 결과부터: 이 블로커는 하나가 아니라 세 개다, 그리고 그중 등록을
막는 두 개는 샌드박스를 전혀 넓히지 않고 고칠 수 있다.**

1. `~/.gitconfig` 거부는 실재하며, 정확히 문서화된 것과 같은 파일이다 — `git` 프로세스 자신의
   커널 로그 줄은 이번 세션에서 잡히지 않았지만(원인 불명, 아래 §A2 참고), `cat`/`stat`/`test`
   세 가지 표준 도구로 **동일 프로파일, 동일 경로**를 찔러 커널이 실제로
   `deny(1) file-read-data /Users/ohama/.gitconfig` / `deny(1) file-read-metadata
   /Users/ohama/.gitconfig` 를 기록하는 것을 확인했다. git 자신의 에러 문구("unable to access
   '/Users/ohama/.gitconfig': Operation not permitted")와 정확히 같은 경로 · 같은 errno다.
2. **새 발견 — gitconfig 를 고쳐도 등록은 여전히 실패한다.** `workspace/scratch-repo` 는
   자체 git 저장소가 아니라(06-05 가 이미 "not its own git repo"라고 남긴 것과 일치),
   프로젝트 루트 `/Users/ohama/projs/cline-tests` 의 git 트리 안에 들어있는 gitignore 된
   서브디렉터리일 뿐이다. Kanban 이 내부적으로 쓰는 `simple-git` 계열 헬퍼(`detectGitRoot` =
   `git rev-parse --show-toplevel`)는 프로젝트 경로를 **git 최상위로 치환**한다 — 그
   최상위는 `ALLOWED_REPOS.json` 자신의 주석이 "절대 추가 금지"라고 못박은 바로 그 저장소
   루트다(`bench/` 가 그 밑에 있어서). 즉 지금 구조로는 gitconfig 문제가 없어도 등록이
   구조적으로 불가능하다.
3. **또 다른 새 발견 — `git worktree add` 는 이 샌드박스 설계 아래서 새 디렉터리를 만들 수
   없다**, 이미 허용된 서브패스 **안**이라도 마찬가지다. `mkdir -p` 와 `git worktree add`
   둘 다 리프 디렉터리를 만들기 전에 조상 디렉터리를 순서대로 `stat()`하는데, 그 조상 걷기가
   `/Users/ohama`(허용되지 않은 조상) 를 건드리는 순간 거부당한다 — 04-RESEARCH.md 가 이미
   기록한 "조상 디렉터리는 subpath 규칙이 덮지 못한다"는 것과 **완전히 같은 종류의 문제**지만,
   이번엔 kanban 의 핵심 기능인 태스크별 worktree 생성 자체를 겨눈다. 이건 Phase 8
   DOC-02("worktree")에 직접 영향을 준다 — 등록과는 독립적인, 별도로 escalate 해야 할 문제다.
4. **가장 값진 결과: no-widening 수정이 실제로 존재하고 실측으로 증명됐다.** Kanban 의 컴파일된
   소스(`/opt/homebrew/lib/node_modules/kanban/dist/cli.js`)를 직접 읽었다 — 모든 내부 git
   호출은 `createGitProcessEnv()`(=`process.env` 를 그대로 통과시키되 `GIT_DIR` 류 7개 키만
   제거)를 거친다. `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`/`GIT_CONFIG_NOSYSTEM` 은 전혀
   거르지 않는다. 실제 생성된(unmodified) 샌드박스 프로파일 아래, 격리된 임시 저장소에
   `GIT_CONFIG_GLOBAL=/dev/null` 하나만 주고 `git rev-parse --is-inside-work-tree` /
   `--show-toplevel` / `symbolic-ref` / `status` / `diff` / `log` 를 실행했더니 **전부 exit
   0**로 성공했다(§A5). `EXTRA_ALLOW_PATHS`/`sandbox.sb`/plist 는 손대지 않았다.

**PRIMARY 권고:** widening 을 먼저 검토하지 말 것. (1) `run_kanban_service.sh` 에
`export GIT_CONFIG_GLOBAL=...`(값은 `/dev/null` 또는 `~/.cline` 안의 새 파일 — 이미 펀치된
경로)를 추가하고, (2) `workspace/scratch-repo` 를 독립 git 저장소로 만드는(`git init`, Phase 6
이 이미 한 번 했다가 되돌린 바로 그 조치) 두 가지를 **함께** 하면 등록이 no-widening 으로
풀린다. `git worktree add` 문제는 **별개로 사람에게 escalate**해야 한다 — 이건 "widen 이냐
아니냐"의 문제가 아니라 "조상 read-metadata 를 얼마나 더 넓혀야 kanban 의 핵심 기능이
동작하느냐"의 문제이고, 지금 확보한 실측만으로는 최소 범위를 단정할 수 없다(§A7).

**SECONDARY(Phase 8) 결과:** 기존 8개 `docs/*.md` 는 전부 엔지니어링 기록(무엇을 만들었고
어떻게 검증했는가)이지 사용자 매뉴얼이 아니다. 매뉴얼은 `docs/manual/` 아래 4개 문서(하나는
공통 "시작하기")로 새로 만들고, 각 문서 서두에 대응하는 엔지니어링 문서로의 링크만 걸어
중복을 피하는 구조를 제안한다(§B1). 기존 문서가 명시적으로 "Phase 8 은 이렇게 쓰면 안 된다"고
못박은 문장들을 전부 인벤토리했다(§B2) — 특히 cline-bench 관련 5개 금지 문장과 gitconfig
블로커 자체가 매뉴얼에 어떻게 반영돼야 하는지(§A 의 결과를 그대로).

## PART A — Kanban 프로젝트 등록 블로커: 근본원인 진단

### A0. 재현/추론 구분표 (정직성 원장)

| # | 주장 | 상태 | 증거 |
|---|------|------|------|
| 1 | `git rev-parse --is-inside-work-tree`(비독립 scratch-repo 위)가 실제 sandbox-exec 프로파일 아래서 "unable to access '/Users/ohama/.gitconfig': Operation not permitted", exit 128 로 실패한다 | **재현함** (이번 세션에 3회 이상 독립 실행) | 아래 §A2 커맨드 로그 |
| 2 | 그 실패가 커널 Seatbelt 의 `~/.gitconfig` 파일-읽기 거부다 | **재현함(삼각측량)** — git 프로세스 자신의 커널 로그 줄은 못 잡았지만 `cat`/`stat`/`test` 로 동일 경로·동일 프로파일에서 동일 클래스의 `deny(1)` 을 커널 로그로 직접 확인 | §A2 |
| 3 | `~/.gitconfig` 를 우회해도(`GIT_CONFIG_GLOBAL=/dev/null`) 실제 `workspace/scratch-repo` 는 여전히 실패한다(다른 경로, "workspace" 조상 stat 거부) | **재현함** | §A3 |
| 4 | 그 실패의 원인은 scratch-repo 가 독립 저장소가 아니라서 git 이 조상 디렉터리를 걸어 올라간다 | **재현함**(unsandboxed `git rev-parse --show-toplevel` → `/Users/ohama/projs/cline-tests`, `ls -la workspace/scratch-repo`에 `.git` 없음, `.gitignore:9`에 `workspace/scratch-repo/` 항목 존재) | §A3 |
| 5 | Kanban 이 내부적으로 `git`을 직접 spawn하며 그 경로가 gitconfig/git-root 문제와 정확히 일치한다 | **재현함(정적 소스 대조)** — `dist/cli.js`를 직접 읽어 `runGitCapture`/`hasGitRepository`/`resolveWorkspacePath`/`createGitProcessEnv` 함수 본문 확보 | §A4 |
| 6 | `GIT_CONFIG_GLOBAL=/dev/null` + 독립 저장소 조합이면 등록에 필요한 모든 git 호출이 샌드박스 안에서 성공한다 | **재현함** — 격리된 임시 저장소(실제 ALLOWED_REPOS.json/sandbox.sb 는 건드리지 않고 `--extra-allow`로 스크래치 프로파일만 생성)에서 `rev-parse --is-inside-work-tree`/`--show-toplevel`/`symbolic-ref`/`status`/`diff`/`log` 전부 exit 0 | §A5 |
| 7 | `git worktree add` 는 이미 허용된 서브패스 안에서도 새 디렉터리를 못 만든다 | **재현함**(단일 레벨·중첩 레벨·사전 생성된 빈 디렉터리 세 가지 변형 모두 동일하게 실패, `mkdir -p` 로 독립 재현) | §A6 |
| 8 | kanban 의 checkpoint 커밋 기능은 `~/.gitconfig` 의 `user.name`/`user.email` 에 의존하지 않는다 | **재현함(정적 소스 대조)** — `createWorkingTreeCheckpointCommit` 이 `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`/`GIT_COMMITTER_*` 를 직접 env 로 주입 | §A4 |
| 9 | 라이브 kanban 서버(pid 53894)에 실제로 `GIT_CONFIG_GLOBAL` 을 적용하면 등록이 성공한다 | **적용 안 함 — 추론만** | 서비스 재시작이 금지된 진단 세션이라 라이브 프로세스에는 적용/검증하지 않았다. §A5 의 격리 재현이 대리 증거다. |

모든 명령은 `phase-03/sandbox/run_sandboxed.sh` 가 매 호출마다 재생성하는 **실제 미수정
프로파일**(또는 그 프로파일에 `--extra-allow` 로 스크래치 디렉터리 하나만 더한 변형)로
실행했다. `workspace/ALLOWED_REPOS.json`, `workspace/sandbox.sb`, `phase-03/sandbox/config.env`,
`phase-05/services/*`, 어떤 plist 도 수정하지 않았다. 여섯 개 라이브 pid(46573/75548/48525/
53894/99162/19669)는 진단 시작과 끝에서 동일함을 확인했다. 실 저장소에 만든 임시 디렉터리
(`workspace/.tmp-git-selftest-diag`)와 스크래치 프로파일은 전부 삭제했고
`git status --porcelain`/`git diff --stat` 로 0 변경을 확인했다.

### A2. `~/.gitconfig` 거부 — 신호 재현

```
$ phase-03/sandbox/run_sandboxed.sh -- git -C workspace/scratch-repo rev-parse --is-inside-work-tree
resolved allow list: ['.../workspace/scratch-repo', '/Users/ohama/.cline']
fatal: unable to access '/Users/ohama/.gitconfig': Operation not permitted
exit=128
```

`log stream`/`log show` 로 `git` 프로세스 자신의 커널 로그 줄을 잡으려 했으나(정확히
04-RESEARCH.md 가 문서화한 레시피 `log stream --style compact --predicate 'eventMessage
CONTAINS "deny"'`, 그리고 사후 조회 `log show --predicate 'subsystem ==
"com.apple.sandbox.reporting"'` 둘 다) **3회의 독립적인 `git` 호출 전부에서 한 줄도 잡히지
않았다** — 60분 범위 전체를 훑어도 `git(...)` 프로세스명의 로그가 전혀 없다. 이는
04-RESEARCH.md 가 남긴 "동일 (프로세스, 오퍼레이션, 경로) 튜플은 중복 억제된다"는 캐비어트만으로는
설명이 안 된다(억제는 *반복*에만 적용되지 최초 1회는 항상 찍혀야 한다 — 이 세션의 최초 시도도
안 찍혔다). 원인은 불명으로 남긴다(가설: git 이 트리거하는 syscall 클래스가 커널의 리포팅
서브시스템이 다루지 않는 경로를 타거나, 이전 세션(Phase 6, "moments ago")에서 이미 동일 튜플이
소비돼 이 boot session 전체에 걸쳐 억제 중일 가능성).

**로그로 직접 확인한 대체 증거(같은 프로파일, 같은 경로, 3개의 표준 유틸리티):**
```
$ sandbox-exec -f <동일 프로파일> -- /bin/cat /Users/ohama/.gitconfig
cat: /Users/ohama/.gitconfig: Operation not permitted
→ log show: kernel: (Sandbox) ... deny(1) file-read-data /Users/ohama/.gitconfig

$ sandbox-exec -f <동일 프로파일> -- /usr/bin/stat /Users/ohama/.gitconfig
stat: /Users/ohama/.gitconfig: stat: Operation not permitted
→ log show: kernel: (Sandbox) ... deny(1) file-read-metadata /Users/ohama/.gitconfig

$ sandbox-exec -f <동일 프로파일> -- /bin/test -r /Users/ohama/.gitconfig
(exit 1)
→ log show: kernel: (Sandbox) ... deny(1) file-read-metadata /Users/ohama/.gitconfig
```
git 자신의 에러 텍스트("unable to access '/Users/ohama/.gitconfig': Operation not permitted")가
이 세 가지 대리 프로브의 커널-확인된 거부와 경로·errno 클래스가 정확히 일치한다. **결론:
`~/.gitconfig` 거부는 실재하며 유일한 원인이다 — git 프로세스 자신의 커널 로그 줄이 이번
세션에서 안 잡힌 것은 진단의 신뢰도를 낮추지 않는다(삼각측량으로 충분히 확증됨), 다만 향후
같은 기법을 쓸 사람을 위해 이 caveat 를 남긴다.**

### A3. 두 번째 층 — scratch-repo 는 독립 저장소가 아니다

```
$ ls -la workspace/scratch-repo/          # .git 없음, README.md/SANDBOX_INSIDE_CANARY.txt 뿐
$ git -C workspace/scratch-repo rev-parse --show-toplevel   # (unsandboxed) → /Users/ohama/projs/cline-tests
$ git check-ignore -v workspace/scratch-repo   # .gitignore:9:workspace/scratch-repo/
```

`workspace/scratch-repo` 는 프로젝트 루트 저장소의 gitignore 된 서브디렉터리일 뿐, 자체
`.git` 이 없다. `ALLOWED_REPOS.json` 의 코멘트 자신이 "저장소 루트
`/Users/ohama/projs/cline-tests` 는 절대 추가하면 안 된다 — `bench/` 가 그 아래 있고 SBX-04
가 그걸 도달 불가능하게 요구하기 때문"이라고 명시한다.

`GIT_CONFIG_GLOBAL=/dev/null` 로 gitconfig 문제를 우회해도:
```
$ env GIT_CONFIG_GLOBAL=/dev/null sandbox-exec -f <동일 프로파일> -- \
    git -C workspace/scratch-repo rev-parse --is-inside-work-tree
fatal: failed to stat '    .../workspace': Operation not permitted
exit=128
```
git 의 저장소 판별 로직이 `.git` 을 찾아 조상으로 걸어 올라가다가 `workspace/`(scratch-repo
바로 위, 허용되지 않은 경로)를 stat 하는 순간 거부당한다. **이 경로를 계속 따라가면 결국
`/Users/ohama/projs/cline-tests/.git` 에 도달해야 하는데, 그 경로는 설계상 영원히 허용되지
않는다.** 즉 gitconfig 만 고치면 반쯤만 고친 것이고, 실제로는 두 번째로 독립적인 실패 지점이
있다.

### A4. Kanban 소스 대조 — 이 진단이 실제 코드와 일치함을 확인

`kanban@0.1.70`(readlink: `/opt/homebrew/lib/node_modules/kanban/dist/cli.js`)의 컴파일된
번들을 직접 읽었다:

```js
// 모든 내부 git 호출의 공통 경로
async function runGit(cwd, args, options = {}) {
  const fullArgs = ["-c", "core.quotepath=false", ...args];
  const { stdout, stderr } = await execFileAsync5("git", fullArgs, {
    cwd, encoding: "utf8", maxBuffer: GIT_MAX_BUFFER_BYTES,
    env: options.env || createGitProcessEnv()   // ← 여기
  });
  ...
}

function createGitProcessEnv(overrides = {}) {
  const sanitized = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (GIT_REPOSITORY_ENV_KEYS.has(key)) continue;   // GIT_DIR/GIT_WORK_TREE/GIT_COMMON_DIR/
    sanitized[key] = value;                            // GIT_INDEX_FILE/GIT_OBJECT_DIRECTORY/
  }                                                     // GIT_ALTERNATE_OBJECT_DIRECTORIES/GIT_PREFIX
  return { ...sanitized, ...overrides };
}
```

`GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`/`GIT_CONFIG_NOSYSTEM` 은 이 7개 차단 목록에 없다 —
`process.env` 를 그대로 통과시킨다. `grep`으로 확인한 결과 `dist/cli.js` 안 어디에도
`GIT_CONFIG_*` 리터럴이 없다(kanban 이 자체적으로 이 변수들을 설정/제거하지 않는다는 뜻이므로,
서비스 wrapper 가 export 하면 그대로 전달된다).

**등록 경로의 실제 함수:**
```js
function detectGitRoot(cwd) { return runGitCapture(cwd, ["rev-parse", "--show-toplevel"]); }

async function resolveWorkspacePath(cwd) {
  const canonicalCwd = await realpath(resolve7(cwd)).catch(() => resolve7(cwd));
  const gitRoot = detectGitRoot(canonicalCwd);
  if (!gitRoot) throw new Error(`No git repository detected at ${canonicalCwd}`);
  const resolvedGitRoot = resolve7(gitRoot);
  return await realpath(resolvedGitRoot).catch(() => resolvedGitRoot);
}
```
`resolveWorkspacePath` 는 전달받은 경로가 아니라 **git 최상위**를 등록 대상(`repoPath`)으로
쓴다 — CLI 의 `--project-path` 를 명시적으로 줘도(`resolveRuntimeWorkspace` 확인) 동일하게
`loadWorkspaceContext(resolvedPath, ...)` → `resolveWorkspacePath` 로 흘러가므로 우회되지
않는다. 이게 §A3 의 실측과 정확히 일치한다 — kanban 은 항상 "이 경로가 속한 git 저장소 전체"를
프로젝트로 삼는다.

**checkpoint 커밋은 gitconfig 에 의존하지 않는다:**
```js
async function createWorkingTreeCheckpointCommit(repoRoot, turn, taskId) {
  const gitEnv = {
    ...createGitProcessEnv(),
    GIT_INDEX_FILE: tempIndexPath,
    GIT_AUTHOR_NAME: CHECKPOINT_AUTHOR_NAME, GIT_AUTHOR_EMAIL: CHECKPOINT_AUTHOR_EMAIL,
    GIT_COMMITTER_NAME: CHECKPOINT_AUTHOR_NAME, GIT_COMMITTER_EMAIL: CHECKPOINT_AUTHOR_EMAIL
  };
  ...
}
```
author/committer 이름·이메일을 직접 주입하므로 `GIT_CONFIG_GLOBAL=/dev/null` 로 `user.name`/
`user.email` 이 사라져도 checkpoint 커밋 자체는 깨지지 않는다(정적 검토 기준 — 코드베이스
전체에서 `credential.helper`/`push`/`fetch`/`clone` 호출은 발견되지 않았다; 완전한 런타임
커버리지는 아니다).

**실제 라이브 에러의 클라이언트/서버 분리:** `kanban task list` 는 CLI(비샌드박스, 사람이 직접
실행)가 로컬에서 `resolveRuntimeWorkspace(...).repoPath` 를 계산한 뒤 그 문자열을 서버에
tRPC 로 보내고, 서버는 `autoCreateIfMissing:false` 로 인덱스에서 그 경로를 찾다가 없으면
`Project ${repoPath} is not added to Kanban yet.` 을 던진다(`listTasks` 함수 확인) — 이건
서버측 git 호출 없이도 재현되는 에러이고, 오늘 프롬프트의 라이브 재현(`cwd =
/Users/ohama/projs/cline-tests`)과 정확히 일치한다(그 cwd 에서 로컬 unsandboxed git 이
`--show-toplevel` 을 실행하면 프로젝트 루트 자신이 나오므로 즉시 그 경로가 "not added"로
보고된다). **실제 등록 시도**(`ensureRuntimeWorkspace` → 서버의 `projects.add` mutation,
`autoCreateIfMissing:true` 분기)에서 비로소 **서버측**(샌드박스 안) git 호출이 일어나고,
거기서 §A2/§A3 의 두 실패가 발생한다.

### A5. No-widening 수정 — 실측 성공

격리된 임시 저장소(`workspace/` 안, 실제 `ALLOWED_REPOS.json`/`sandbox.sb` 는 건드리지
않고 `gen_sandbox_profile.py --extra-allow <임시 디렉터리>` 로 스크래치 프로파일만 생성)에
독립 `.git` 을 만들고, 동일한 미수정 생성 로직으로 만든 프로파일 아래서:

```
$ env GIT_CONFIG_GLOBAL=/dev/null sandbox-exec -f <스크래치 프로파일> -- \
    git -C <임시 독립 저장소> rev-parse --is-inside-work-tree     → true    (exit 0)
$ ... git -C <임시 독립 저장소> rev-parse --show-toplevel          → <임시 저장소 경로 자신>  (exit 0)
$ ... git -C <임시 독립 저장소> symbolic-ref --quiet --short HEAD  → main   (exit 0)
$ ... git -C <임시 독립 저장소> status --porcelain                 → 정상 (~/.config/git/ignore
                                                                         에 대한 warning 만, fatal 아님)
$ ... git -C <임시 독립 저장소> diff / log --oneline                → 정상 (exit 0)
```

**결론:** Kanban 의 `runGitCapture`/`hasGitRepository`(둘 다 `rev-parse
--is-inside-work-tree`/`--show-toplevel` 정확히 이 명령들을 씀 — §A4)가 필요로 하는 모든
git 호출은, (1) `GIT_CONFIG_GLOBAL=/dev/null`(또는 이미 펀치된 경로 안의 파일)과 (2) 등록
대상 디렉터리가 그 자체로 git 최상위인 것, 이 둘만 있으면 **샌드박스를 전혀 넓히지 않고**
성공한다.

**권고하는 구현(이번 진단에서는 적용하지 않음 — 다음 규정):**
1. `phase-05/services/run_kanban_service.sh` 의 `exec` 줄 **앞**에
   `export GIT_CONFIG_GLOBAL=<경로>` 를 추가한다. `/dev/null` 이 가장 단순하고 이미 검증됐다.
   원한다면 `$HOME/.cline/git/gitconfig` 처럼 이미 펀치된 `~/.cline` 아래 새 파일을 만들어
   `init.defaultbranch=main` 같은 안전한 최소 설정만 담는 대안도 가능(두 경로 다
   `sandbox.sb`/`EXTRA_ALLOW_PATHS` 변경 없이 동작함 — `~/.cline` 은 이미 펀치돼 있다).
2. `workspace/scratch-repo` 에 `git init` 한다(Phase 6 가 이미 한 번 하고 되돌린 바로 그
   조치 — 이번엔 되돌리지 않고 유지). `ALLOWED_REPOS.json`/`sandbox.sb` 는 변경 불필요 — 이미
   허용된 경로 안에 `.git` 이 생기는 것뿐이다.
3. 사용자는 `kanban` CLI 를 **`workspace/scratch-repo` 안에서**(또는 `--project-path`로
   그 경로를 명시해서) 실행해야 한다 — §A4 에서 확인했듯 `resolveWorkspacePath` 는 git
   최상위로 치환하므로, 프로젝트 루트에서 실행하면 여전히 금지된 저장소 루트를 등록하려
   시도한다.
4. 서비스 재시작이 필요하다(env 는 프로세스 시작 시점에만 적용됨) — 이번 진단 세션에서는
   금지돼 있어 라이브 확인은 못 했다; §A0 표의 항목 9 참고.

### A6. 세 번째, 독립적인 문제 — `git worktree add` 는 샌드박스 안에서 새 디렉터리를 못 만든다

이건 등록과 무관하게 발견됐고, Kanban 의 핵심 기능(태스크별 worktree)에 직접 영향을 준다.

```
$ mkdir <허용된 서브패스>/single-level-dir            → 성공 (exit 0, 단일 mkdir syscall)
$ mkdir -p <허용된 서브패스>/single-level-dir2         → mkdir: /Users/ohama: Operation not permitted
$ git worktree add <허용된 서브패스 안의 새 경로> -b x  → fatal: could not create leading
                                                            directories of '.../.git':
                                                            Operation not permitted
   (단일 레벨, 중첩 레벨, 사전에 빈 디렉터리를 만들어둔 경우 세 변형 모두 동일하게 실패)
```

원인은 04-RESEARCH.md 가 이미 다른 맥락(Node/Bun 부트스트랩)에서 문서화한 것과 **완전히
같은 클래스**다: BSD `mkdir -p`(그리고 git 의 "leading directories" 생성 로직)는 목표
경로의 조상들을 루트부터 순서대로 `stat()` 하는데, `/Users/ohama` 자신이
`(deny file-read* (subpath "/Users/ohama"))` 에 그대로 걸린다 — 더 안쪽의 allow 규칙은
`/Users/ohama` **자신**을 커버하지 않고 그 서브패스만 커버하기 때문이다(SBPL `subpath` 규칙의
근본적 성질: 대상과 그 후손만 덮고 조상은 덮지 않는다). 대상 디렉터리가 **이미 존재해도**
git 은 여전히 조상 체인을 걷는다(사전 생성 테스트로 확인).

**이건 gitconfig/git-root 문제와 별개의 원인이고, GIT_CONFIG_GLOBAL 로도 독립 저장소로도
고쳐지지 않는다.** worktree 생성이 실제로 필요해지는 시점(Phase 8 DOC-02 "worktree" 사용,
또는 임의의 실제 태스크 실행)에 다시 나타난다.

**이 진단에서는 이 문제의 최소 해법을 확정하지 않는다** — 후보는 (a) `/Users/ohama` 자신에
대한 `file-read-metadata` 만 별도로 허용(쓰기/데이터읽기는 여전히 거부 — SBPL 에서
오퍼레이션별로 분리 가능한지는 검증 필요), (b) worktree 대상 디렉터리를 kanban 실행 **전에**
미리 전부 만들어 두는 방식으로 회피(하지만 태스크마다 새 worktree 를 만드는 kanban 의 설계와
충돌), (c) 이 조상-stat 패턴 자체를 감내할 수 있을 만큼 `PROTECTED_ROOT` 설계를 재검토. 세
후보 모두 Phase 3 소유의 보안 경계 변경이거나 kanban 의 동작 방식에 대한 가정이 필요해 **사람
에스컬레이션이 필요하다** — 이번 진단의 범위를 넘는다. Phase 8 은 이걸 매뉴얼의 gap 으로
정직하게 적어야 한다("등록이 된 뒤에도 worktree 생성은 별도로 확인되지 않았다").

### A7. 권고 요약

| 항목 | 권고 | widening 필요? | 확신도 |
|---|---|---|---|
| `~/.gitconfig` 읽기 거부 | `run_kanban_service.sh` 에 `GIT_CONFIG_GLOBAL=/dev/null`(또는 `~/.cline` 안 파일) export | **아니오** | HIGH(실측) |
| git 최상위가 금지된 저장소 루트로 치환됨 | `workspace/scratch-repo` 를 `git init` 으로 독립 저장소화 + 사용자가 그 경로 안에서/`--project-path`로 kanban 을 호출 | **아니오** | HIGH(실측+소스대조) |
| `git worktree add` 가 새 디렉터리를 못 만듦 | **미해결 — 사람 에스컬레이션 필요**, widening 이 필요할 가능성이 높으나 최소 범위 미확정 | 아마도 필요(범위 미확정) | MEDIUM(현상은 재현, 해법은 미검증) |
| 만약 위 두 가지를 사람이 거부하고 widening 을 원한다면 | `EXTRA_ALLOW_PATHS` 에 `~/.gitconfig` **파일** 하나만(디렉터리 아님 — `gen_sandbox_profile.py` 는 지금 디렉터리만 받는 `--extra-allow`/`os.path.isdir` 검증을 하므로 스크립트 수정이 같이 필요함) 추가 — 그래도 A3/A6 문제는 안 풀린다는 점을 반드시 명시 | 예(비권장) | — |

**결론 문장(매뉴얼/STATE.md 인계용):** "Kanban 프로젝트 등록은 gitconfig 하나가 아니라
최소 두 개의 독립적 원인이 겹쳐 있었다 — 각각 no-widening 수정이 실측으로 검증됐다. 등록이
풀린 뒤의 worktree 생성은 세 번째, 아직 해법이 없는 별도 문제로 새로 발견됐다."

---

## PART B — Phase 8 (한글 사용 매뉴얼) 리서치

### B1. 매뉴얼 형태·파일 배치 제안

**제안: `docs/manual/` 하위에 5개 파일.** 기존 `docs/*.md` 8개(엔지니어링 기록)와 폴더로
분리해서 "이건 어떻게 만들었나"와 "이건 어떻게 쓰나"를 물리적으로 나눈다 — `docs/` 최상위에
평평하게 9번째 파일로 섞으면 두 성격이 뒤섞인다.

```
docs/
├── manual/
│   ├── 00-시작하기.md          # 공통 진입점: 이 시스템이 뭔지, 다섯 서비스, 오늘 뭘 켜야 하나
│   ├── 01-cli-사용법.md         # DOC-01: 기동, 태스크 실행, Plan/Act, 체크포인트
│   ├── 02-kanban-사용법.md      # DOC-02: 카드, worktree, diff 리뷰, 의존 체인
│   ├── 03-모바일-사용법.md      # DOC-03: iPad/iPhone, Tailscale, Telegram, 승인/거부
│   └── 04-32k-운용주의.md       # DOC-04: 64초 대기, 압축 지연, contextWindow 위치, ⌘+클릭
├── 32k-compaction-policy.md    # (기존, 엔지니어링 기록 — 04 가 링크만)
├── cline-config-pins.md        # (기존 — 01 이 링크만)
├── ...
```

각 매뉴얼 문서 서두에 "이 문서는 사용법이다. 왜/어떻게 검증됐는지는
`docs/<대응파일>.md` 참고" 한 줄을 박아 이중 유지보수를 피한다. 예: `01-cli-사용법.md` →
`docs/cline-config-pins.md` + `docs/headless-wrapper.md`, `02-kanban-사용법.md` →
`docs/services.md` §5/§6 + 이 문서 §A(등록 블로커 상태), `03-모바일-사용법.md` →
`docs/network-exposure.md` §4a/4b + `phase-06/IPAD-CHECKLIST.md`(그대로 참조, 중복 재작성
금지 — 이미 "직접 열어서 따라 할 수 있게" 만들어진 문서), `04-32k-운용주의.md` →
`docs/32k-compaction-policy.md` §5.

**`00-시작하기.md` 를 따로 두는 이유:** 네 요구사항 문서(DOC-01~04) 모두 "이 여섯 개 서비스가
이미 떠 있다"를 전제로 시작하는데, 정작 "오늘 처음 켤 때 뭘 확인하나"/"떠 있는지 어떻게
아나"/"64초 대기와 멈춤을 어떻게 구분하나" 는 넷 중 어디에도 딱 맞는 자리가 없다(§B3). 이걸
독립 진입점으로 빼면 나머지 네 문서가 "이미 켜져 있다고 가정하고" 순수하게 사용법에만
집중할 수 있다.

**요구사항과 파일의 대응 — 1:1 이 아니라 필요하면 쪼갠다:** DOC-01(CLI)과 DOC-04(32K
주의)는 사실 CLI 사용 중에 계속 겹친다(체크포인트도, 압축 지연도 CLI 세션 중에 일어난다) —
`01-cli-사용법.md` 안에 "긴 세션에서 무슨 일이 생기나" 한 절을 넣고 `04-32k-운용주의.md` 를
"모든 표면 공통"으로 독립시키는 지금 구조를 유지하되, 01 은 04 를 앞쪽에서 명시적으로
가리키게 한다(순서: 사용자가 CLI 를 먼저 켜므로).

### B2. 기존 문서가 이미 못박은 "이렇게 쓰면 안 된다" 인벤토리

각 `docs/*.md` 의 "Phase 7·8 인계"/"Phase 8 인계"/"한계" 절을 그대로 확인한 결과:

| 출처 | 매뉴얼이 절대 쓰면 안 되는 것 | 대신 써야 하는 것 |
|---|---|---|
| `docs/32k-compaction-policy.md` §1,§9 | "32K 벽에서 작업이 죽는다"(1차 결론) — 오설정 상태의 측정이었다, §9 부록에만 보존 | "압축이 정상 작동한다, `contextWindow` 위치가 핵심" |
| `docs/32k-compaction-policy.md` §5 | "작업 예산/태스크 쪼개기가 필요하다" | 불필요해졌다(phase_8_context 의 2026-08-30 정정과 일치) |
| `docs/cline-bench.md` §9 | "cline-bench 가 통과했다/실행됐다→통과로 승격/공식 스위트가 검증됐다/온와이어 프롬프트가 캡처됐다/BCH-01 이 충족됐다/이 스택이 과제를 완료할 수 있다" — 6개 금지 문장, 전부 명시적 | "요청이 flashnext/litellm 체인에 실제로 도달한다"(O), "32K 컨텍스트 예산 안에서 완료하지 못했다"(O, 관측된 3개 과제 전부) |
| `docs/network-exposure.md` §9 | NET-01 iPad 절반/NET-05 Telegram 절반을 "확인됨"으로 격상 | 둘 다 gap 으로 그대로 옮겨 쓴다, iPad 진입 주소는 반드시 tailnet 주소 |
| `docs/network-exposure.md` §9 | (이 문서 §A 가 새로 갱신) gitconfig 문제를 "Phase 3 소유, 미해결"로만 적기 | §A 의 결론(두 개는 no-widening 으로 풀린다, 세 번째는 별도 미해결)으로 갱신 |
| `docs/headless-wrapper.md` §4,§8 | `--auto-approve true`/도구-허용 전환이 이미 결정된 것처럼 쓰기 | "읽기·대화 전용, 원격 에이전트는 파일을 못 고친다" 를 사실로, 전환은 사람의 결정 사항으로 |
| `docs/services.md` §4 | "재부팅 후에도 동작 확인됨" | 프록시 증거일 뿐, 실제 재부팅은 관측 안 됨 + `iogpu.wired_limit_mb` 재적용 필요 |
| `.planning/STATE.md` Blockers | "cline 3.0.53 고정" 을 검증 없이 사실로 | 드리프트됨(3.0.60), 매뉴얼은 실제 버전을 다시 확인하라고 독자에게 지시 |
| `phase-06/IPAD-CHECKLIST.md` | Telegram 타이핑 표시기의 결과를 예단 | "아직 아무도 확인하지 않았다"를 그대로 유지 |

### B3. 기존 문서가 다루지 않는, 매뉴얼이 새로 채워야 할 것

- **일상 기동/상태 확인** — 여섯 서비스가 떠 있는지 확인하는 법(`verify_services.sh`,
  `verify_network.sh`)은 엔지니어링 관점(게이트 통과/실패)으로만 문서화돼 있다. 매뉴얼은
  "오늘 아침 이걸 켜고 싶다"는 사용자 관점 절차가 필요하다 — 서비스는 이미 `RunAtLoad: true`
  로 등록돼 있으므로 보통은 "아무것도 안 해도 된다"가 정답이지만, 그 사실 자체와 "확인하고
  싶으면 이 명령"을 매뉴얼이 명시적으로 알려줘야 한다.
- **64초 대기 중 멈춤과 정상 지연을 구분하는 법** — `docs/32k-compaction-policy.md` §5.3 이
  "압축 자체가 지연을 만든다"는 사실은 남겼지만, 사용자가 화면에서 뭘 보고 "이건 정상, 이건
  이상"을 판단하는 절차는 없다. Kanban 카드가 In Progress 에 머무는 것, Telegram 에 아무
  변화가 없는 것(§A2 의 04-RESEARCH 발견과 연결: typing indicator 는 재발화가 없다)이 정상
  범위임을 매뉴얼이 명시적으로 가르쳐야 한다 — 이게 DOC-04 의 핵심 요구사항이기도 하다.
- **Kanban 등록 자체** — 지금은 등록된 프로젝트가 하나도 없다(§A 전체). 매뉴얼의 DOC-02 를
  쓰려면 최소한 §A5 의 두 가지 수정(GIT_CONFIG_GLOBAL + 독립 저장소화)이 실제로 적용된
  뒤여야 "카드/worktree/diff 리뷰"를 실제로 시연할 수 있다 — Phase 8 플래너는 이 순서
  의존성(먼저 등록 블로커를 고친다 → 그 다음 DOC-02 스크린샷/절차를 쓴다)을 계획에 반영해야
  한다. 못 고치면 DOC-02 는 "등록이 아직 안 된다"는 정직한 gap 으로 남겨야 한다(overclaim
  금지, §B2 표와 같은 원칙).
- **Plan/Act 모드, `--id`(세션 재개), cline 자체의 체크포인트 개념** — `docs/
  cline-config-pins.md` §2 는 `--help` 플래그 표면만 확인했을 뿐, Plan/Act 전환이나 세션
  재개가 이 프로젝트에서 실제로 실행/검증된 적이 없다(전부 헤드리스 1회성 프롬프트만
  검증됨). DOC-01 이 요구하는 "Plan/Act, 체크포인트"가 (a) cline CLI 자체의 기능인지 (b)
  kanban 의 git 체크포인트 커밋(§A4)을 가리키는지 phase 착수 전에 확인이 필요하다 — 이 리서치
  범위 밖의 open question 으로 남긴다(§B4).
- **문제 발생 시 무엇을 보고 어디로 가나(트러블슈팅 인덱스)** — 매뉴얼 다섯 문서 각각이 "이게
  안 되면 어느 엔지니어링 문서의 몇 절을 보라"는 식으로 흩어져 있으면 사용자가 못 찾는다.
  `00-시작하기.md` 끝에 "증상 → 어느 문서" 한 표를 두는 걸 제안한다(예: "카드가 안 보인다 →
  `02-kanban-사용법.md` §등록", "64초 넘게 아무 반응 없다 → `04-32k-운용주의.md` §정상/이상
  구분").

### B4. Open Questions

1. **Plan/Act 모드가 이 cline 버전(3.0.53/드리프트된 3.0.60)의 CLI 에 실제로 존재하는가,
   존재한다면 헤드리스(`--auto-approve false`, TTY 없음)에서 의미가 있는가?**
   - 아는 것: `--help` 표면(§ `docs/cline-config-pins.md` §2)에 Plan/Act 전용 플래그가
     안 보인다. 이 프로젝트의 모든 실측은 1회성 헤드리스 프롬프트뿐이다.
   - 모르는 것: Plan/Act 가 대화형(TTY) 전용 개념인지, 헤드리스에도 대응 개념이 있는지.
   - 권고: Phase 8 착수 전 `cline --help`/`cline <prompt> --help` 재확인 한 번으로 해소
     가능한 저비용 질문 — 플래너가 Task 0 격으로 넣을 것.
2. **DOC-01 의 "체크포인트"가 cline 자체 기능인가 kanban 의 git 체크포인트 커밋(§A4)인가?**
   - 아는 것: kanban 쪽은 `createWorkingTreeCheckpointCommit` 로 실제 구현이 확인된다.
     cline CLI 자체의 체크포인트 개념은 이 프로젝트 문서 어디에도 실측되지 않았다.
   - 권고: 두 가지 다 있다면 매뉴얼에서 구분해서 설명(하나는 CLI 세션 재개(`--id`) 관점,
     하나는 kanban 웹에서 보이는 git 커밋 히스토리 관점).
3. **§A6(`git worktree add` 조상-stat 실패)의 최소 해법이 확정되지 않았다.** Phase 8 은
   등록이 고쳐진 뒤에도 "worktree 생성"을 실제로 시연하지 못할 수 있다 — 매뉴얼 집필 전에
   사람이 §A7 표의 세 후보 중 하나를 결정해야 한다. 결정이 안 나면 DOC-02 는 정직하게
   "worktree 생성은 미검증"으로 적어야 한다.
4. **`GIT_CONFIG_GLOBAL` 적용을 실제 라이브 kanban 서비스(pid 53894)에 언제 반영할 것인가?**
   이 진단은 격리된 재현으로만 검증했다(서비스 재시작 금지 제약) — Phase 8(또는 그 전에
   별도 소소한 phase)이 실제로 `run_kanban_service.sh` 를 고치고
   `phase-02/infra/restart_service.sh com.ohama.kanban 3484` 로 재기동해 라이브로 재확인해야
   한다.

## Sources

### Primary (HIGH confidence — 이번 세션 실측)
- `phase-03/sandbox/run_sandboxed.sh`, `phase-03/sandbox/config.env`,
  `phase-03/sandbox/gen_sandbox_profile.py`, `workspace/sandbox.sb`,
  `workspace/ALLOWED_REPOS.json` — 직접 읽음, 미수정 확인
- `phase-05/services/run_kanban_service.sh`, `phase-05/services/config.env` — 직접 읽음
- `sandbox-exec`/`log show`/`mkdir`/`git` 라이브 실행 트랜스크립트(이 세션, §A2/§A3/§A5/§A6)
- `/opt/homebrew/lib/node_modules/kanban/dist/cli.js`(kanban 0.1.70 컴파일된 번들) — 직접 읽음,
  `runGit`/`runGitCapture`/`createGitProcessEnv`/`GIT_REPOSITORY_ENV_KEYS`/`detectGitRoot`/
  `resolveWorkspacePath`/`resolveRuntimeWorkspace`/`hasGitRepository`/`listTasks`/
  `createWorkingTreeCheckpointCommit`/`ensureRuntimeWorkspace` 함수 본문 확보
- `phase-06/results/20260830T071532Z-net05/kanban-registration-blocker.txt`,
  `.planning/phases/06-network-exposure/06-05-SUMMARY.md` — Phase 6 의 선행 진단(이번 진단이
  이어받고 확장함)
- `.planning/phases/03-sandbox-repo-whitelist/03-04-SUMMARY.md`,
  `.planning/phases/04-headless-cli-wrapper/04-RESEARCH.md` — `log stream`/`log show` 기법의
  출처와 조상-stat 문제의 선행 사례(§A6 이 재사용)

### Secondary (MEDIUM confidence)
- `docs/32k-compaction-policy.md`, `docs/cline-config-pins.md`, `docs/headless-wrapper.md`,
  `docs/sandbox-whitelist.md`, `docs/services.md`, `docs/network-exposure.md`,
  `docs/cline-bench.md` — 각 §"한계"/§"Phase 8 인계" 절 전문 확인
- `.planning/STATE.md` Blockers/Concerns 절 전문 확인
- `phase-06/IPAD-CHECKLIST.md` 전문 확인

## Metadata

**Confidence breakdown:**
- 블로커 진단(§A) — HIGH: 실측 재현 + 소스코드 직접 대조, 라이브 서비스 자체에는 미적용(§A0
  항목 9)이라는 단 하나의 명시적 gap
- 매뉴얼 구조 제안(§B1) — MEDIUM-HIGH: 기존 문서 인벤토리에 근거한 합리적 제안이지 검증된
  사실은 아님(플래너/사용자 재량)
- 한계 인벤토리(§B2) — HIGH: 각 문서의 명시적 문장을 그대로 인용
- Open Questions(§B4) — 명시적으로 미해결로 남김

**Research date:** 2026-08-31
**Valid until:** 라이브 kanban 서비스에 `GIT_CONFIG_GLOBAL` 이 실제 적용되거나 `EXTRA_ALLOW_PATHS`
가 바뀌는 즉시 §A 재검증 필요. 나머지는 Phase 8 착수 시점까지 유효.

---

## A6b. worktree 생성 차단 — 정밀 진단

**결론부터 (재현 vs 추론 구분은 아래 §A6b-0 표를 볼 것):**

1. **No-widening 수정은 존재하지 않는다 — 이건 재현으로 확인됐다, 추정이 아니다.** call-shape
   을 바꾼 세 가지 시도(상대경로 타깃, 이미 존재하는 서브디렉터리 안의 상대경로 타깃, 사전
   생성된 빈 디렉터리) 전부 **완전히 동일한** 치명적 실패로 끝났다 — `git worktree add` 는
   내부적으로 관련 절대경로를 realpath 류 방식으로 정규화하면서 `/Users/ohama` 자체를 항상
   통과해야 하고, 이 프로젝트의 전체 작업 트리가 `$HOME` 아래에 있는 한 이건 우회할 방법이
   없다.
2. **최소 widening 후보를 실측으로 확정했다: `(allow file-read-metadata (subpath $HOME))`
   만으로 충분하다 — `file-read-data`/`file-write*` 는 여전히 거부된 채로.** 단일 레벨·중첩
   레벨·사전 생성된 디렉터리 세 변형 모두 실제로 worktree 를 만드는 데 성공했다(디스크에서
   직접 확인).
3. **하지만 이 widening 은 "config.env 값 하나 바꾸기"가 아니라 `gen_sandbox_profile.py` 의
   코드 변경을 요구한다** — 이번 진단에서 새로 발견한 macOS Seatbelt 의 성질 때문이다:
   연산(operation) 키워드가 더 구체적인 규칙(`file-read-data`)은, 나중에 나오고 경로가 더
   좁더라도, 더 넓은 연산 키워드의 규칙(`file-read*`)에 의해 **덮어써지지 않는다** — 이
   프로젝트의 `gen_sandbox_profile.py` 자신의 주석("SBPL is last-match-wins")이 전제하는
   것과 다르다(같은 연산 키워드끼리는 여전히 last-match-wins 가 맞다 — 이건 §A6b-3 에서
   직접 대조 실험으로 증명했다). 즉 `PROTECTED_ROOT` 의 거부를 `file-read-data` 로 좁히면,
   지금 존재하는 모든 `ALLOWED_REPOS.json` 엔트리 · `~/.cline` 의 file-read-data 접근도
   함께 끊어진다 — `render_profile()` 이 각 허용 경로마다 `file-read-data` 를 명시적으로
   다시 허용하는 줄을 추가로 방출하도록 고쳐야 망가지지 않는다(§A6b-5 에 정확한 diff).
4. **비용은 정확히 이렇다:** `$HOME` 아래 어디든(허용된 서브패스 밖 포함) 이미 경로를 아는
   개별 파일/디렉터리의 **stat 급 메타데이터**(존재 여부, 크기, 권한, 소유자, 세 가지
   타임스탬프, inode)는 읽을 수 있게 된다. **내용은 여전히 읽을 수 없다**(`cat` 계속 거부),
   **디렉터리 나열도 여전히 안 된다**(`ls` 는 디렉터리에 대한 `file-read-data` 라서 여전히
   거부 — 즉 `$HOME` 밑을 통째로 훑어 뭐가 있는지 찾아낼 수는 없다, 경로를 이미 알아야
   stat 할 수 있다), **쓰기는 전혀 안 된다**(`file-write*` 는 손대지 않음). 이건 §A6 이 후보
   (b)로 이미 예상했던 정확히 그 절충이고, 이번 진단이 그걸 실측으로 확정했다.
5. **DOC-02("worktree") 는 이 widening 이 실제로 적용된 뒤에만 시연 가능하다.** 사람이
   Phase 3 의 `PROTECTED_ROOT` 정책과 §A6b-5 의 generator 코드 변경을 승인하지 않는 한
   worktree 생성은 여전히 안 된다 — 매뉴얼은 이걸 gap 으로 정직하게 적어야 한다.
6. **부수 발견 — 지난 세션 §A2 의 "git 자체 커널 로그가 안 잡히는 원인 불명" 미스터리가
   풀렸다.** 이 쉘(zsh)에는 `log` 라는 **빌트인 명령**이 있어서(`/System` 의 `log(1)` 과
   무관), `log stream ...` 을 그냥 쓰면 조용히 `(eval):log:N: too many arguments` 로 실패하고
   `> logfile` 로 리다이렉트된 그 에러 문구만 파일에 남는다 — 실제 커널 로그는 단 한 줄도
   캡처되지 않은 채 "로그가 비었다"로 오인하기 쉽다. `/usr/bin/log` 처럼 **전체 경로로
   호출해야** 진짜 `log(1)` 이 실행된다. 이번 세션 §A6b-2 의 재현은 전부 `/usr/bin/log stream`
   으로 다시 하고 나서야 git 자신의 커널 로그 줄을 직접 잡을 수 있었다.

### A6b-0. 재현/추론 구분표

| # | 주장 | 상태 | 증거 |
|---|------|------|------|
| 1 | zsh 의 `log` 빌트인이 `/usr/bin/log` 를 가려서 `log stream` 이 조용히 실패한다 | **재현함** | §A6b-1 |
| 2 | `GIT_CONFIG_GLOBAL=/dev/null` + 독립 저장소로 gitconfig/git-root 두 문제를 우회해도, `git worktree add` 는 이미 허용된 서브패스 안의 새 경로에서도 실패한다(단일/중첩/사전생성 세 변형) | **재현함**(3변형 모두, 커널 로그로 확인) | §A6b-2 |
| 3 | 그 실패의 실제 커널 신호는 `file-read-data`·`file-read-metadata` 둘 다 여러 조상 경로(`/Users/ohama`, `/Users/ohama/projs/cline-tests`)에서 발생하지만, 최종 fatal 은 metadata 쪽 거부다 | **재현함**(커널 로그 원문 확보) | §A6b-2 |
| 4 | 상대경로 타깃/이미 존재하는 하위 디렉터리 안 타깃/사전 생성된 빈 디렉터리 — call-shape 을 바꿔도 전부 동일하게 실패한다(no-widening 후보 소진) | **재현함**(세 가지 모두 직접 실행) | §A6b-2, §A6 원본(사전생성 변형은 원 진단에서도 이미 확인됨) |
| 5 | `(allow file-read-metadata (subpath $HOME))` 만으로(file-read-data/file-write* 는 계속 거부) `git worktree add` 세 변형이 전부 성공한다 | **재현함**(디스크에 실제 worktree 생성 확인, `.git` gitdir 포인터·파일 내용까지 검증) | §A6b-4 |
| 6 | SBPL 은 "나중에 쓴 규칙이 이긴다"가 아니라, 연산 키워드가 더 구체적인 규칙이 더 넓은 wildcard 규칙을 순서와 무관하게 이긴다(같은 구체성끼리는 순서가 이긴다) | **재현함**(4가지 순서 조합 통제 실험으로 직접 대조) | §A6b-3 |
| 7 | metadata-only widening 아래서도 `$HOME` 의 내용 읽기(`cat`)와 디렉터리 나열(`ls`)은 허용된 서브패스 밖에서 여전히 거부된다 — 즉 이 widening 이 실제로 "메타데이터만" 좁혀졌다 | **재현함** | §A6b-4 |
| 8 | cline 바이너리에 `--mode <act|plan>` CLI 플래그(디폴트 `"act"`)가 실재한다 | **재현함(정적 문자열 대조)** — 컴파일된 바이너리를 `strings` 로 직접 읽어 `.option("--mode <act|plan>","Agent mode","act")` 리터럴 확인. cline 실행은 안 함 | §A6b-6 |
| 9 | 이 프로젝트가 실제로 쓰는 순수 헤드리스 1회성 프롬프트 커맨드(=Phase 1 이 `--help` 전문을 캡처한 그 커맨드)도 `--mode` 를 지원하는가 | **미확인 — 정적 분석의 한계로 남김** | §A6b-6 |
| 10 | cline 자신도(kanban 과 별개로) 자체 체크포인트 기능(파일 체크포인팅, git ref 기반)을 갖고 있다 | **재현함(정적 문자열 대조)** — `createCheckpoint`/`restoreCheckpoint`/`cline-checkpoint-`/`CLAUDE_CODE_*_FILE_CHECKPOINTING` 리터럴 확인. 런타임 동작(언제 자동 생성되는지, 헤드리스에서도 켜지는지)은 미검증 | §A6b-7 |

모든 명령은 실제 생성 로직(`phase-03/sandbox/run_sandboxed.sh --profile-out <스크래치 경로>` 및
동일 코드 경로를 쓰는 `gen_sandbox_profile.py --extra-allow`)으로 만든 프로파일, 또는 이번
진단의 가설을 검증하기 위해 손으로 쓴 스크래치 SBPL 파일로 실행했다 — 전부 스크래치 디렉터리
(`/private/tmp/.../scratchpad/`, 그리고 실제 저장소 안의 `workspace/.tmp-wt-diag/`, 진단 종료
시 삭제)를 대상으로 했다. `workspace/ALLOWED_REPOS.json`, `workspace/sandbox.sb`,
`phase-03/sandbox/gen_sandbox_profile.py`, `phase-05/services/*`, 어떤 plist 도 수정하지
않았다(`git diff --stat` 로 0 변경 확인). 여섯 개 라이브 pid 는 진단 시작·끝에서 동일함을
확인했다.

### A6b-1. 방법론 버그: zsh 의 `log` 빌트인이 `log stream` 을 가린다

```
$ log stream --style compact --predicate 'eventMessage CONTAINS "deny"' > logfile &
$ cat logfile
(eval):log:8: too many arguments
```
`log` 이 실제 `/usr/bin/log` 가 아니라 zsh 빌트인으로 해석돼서 즉시 실패하고, 그 에러 한 줄만
로그 파일에 남는다 — "커널 로그에 아무것도 안 잡혔다"처럼 보이지만 사실은 캡처 프로세스 자체가
시작도 못 했다. `/usr/bin/log stream ...` 처럼 절대경로로 불러야 한다:
```
$ /usr/bin/log stream --style compact --predicate 'eventMessage CONTAINS "deny"' > logfile &
```
이걸로 바꾸자 이번 세션의 모든 이후 캡처에서 git 자신의 커널 로그 줄이 직접 잡혔다(§A6b-2).
이건 04-RESEARCH.md Pitfall 7 이 확립한 레시피 자체는 옳았다는 뜻이고, 08-RESEARCH.md §A2 가
"git 프로세스 자신의 커널 로그 줄이 이번 세션에서 안 잡힌" 이유로 남겼던 "원인 불명"은 이제
설명된다: 그 세션에서도 같은 쉐도잉이 원인이었을 가능성이 매우 높다(사후 확인은 불가능하지만,
이번 세션에서 100% 재현되는 동일 증상이었다). 향후 이 프로젝트에서 `log stream`/`log show`
를 쓰는 모든 스크립트·연구는 반드시 `/usr/bin/log` 절대경로를 써야 한다.

### A6b-2. 정밀 재현 — 어떤 연산이, 어떤 경로에서 거부되는가

실제 generator 로직으로 만든(수정 없음) 프로파일에 스크래치 디렉터리 하나만
`--extra-allow` 로 추가해 격리 재현했다:
```
$ EXTRA_ALLOW_PATHS=.../workspace/.tmp-wt-diag \
    phase-03/sandbox/run_sandboxed.sh --dry-run --profile-out <scratch>.sb -- true
resolved allow list: ['.../workspace/scratch-repo', '/Users/ohama/.cline',
                       '.../workspace/.tmp-wt-diag']
```
`.tmp-wt-diag/main-repo` 를 독립 `.git` 저장소로 만들고, `GIT_CONFIG_GLOBAL=/dev/null` 로
gitconfig 문제를 우회한 뒤, `/usr/bin/log stream` 을 트리거 **이전에** 먼저 띄워두고
`git worktree add ../wt-varA -b wt-varA-branch` 를 실행했다:
```
$ env GIT_CONFIG_GLOBAL=/dev/null /usr/bin/sandbox-exec -f <scratch>.sb -- \
    git -C workspace/.tmp-wt-diag/main-repo worktree add ../wt-varA -b wt-varA-branch
Preparing worktree (new branch 'wt-varA-branch')
fatal: Invalid path '/Users/ohama': Operation not permitted
exit=128
```
동시에 캡처된 커널 로그 원문(발췌, 실제 pid 다름 — 같은 실행 안에서 git 이 최소 3개의
서브프로세스를 스폰함):
```
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-data /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-metadata /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) Sandbox: git(23987) deny(1) file-read-metadata /Users/ohama
kernel[...] (Sandbox) Sandbox: git(23987) deny(1) file-read-metadata /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-metadata /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) 1 duplicate report for Sandbox: git(23986) deny(1) file-read-metadata ...
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-metadata /Users/ohama
kernel[...] (Sandbox) Sandbox: git(23986) deny(1) file-read-metadata /Users/ohama/projs/cline-tests
kernel[...] (Sandbox) 4 duplicate reports for Sandbox: git(23986) deny(1) file-read-metadata ...
kernel[...] (Sandbox) Sandbox: git(23988) deny(1) file-read-metadata /Users/ohama
```
**정리:** `git(23986)` 한 번은 `/Users/ohama/projs/cline-tests`(프로젝트 루트, 조상)에 대해
`file-read-data` 로도 거부됐다 — 즉 조상 경로에 대한 거부는 metadata 하나가 아니다,
data(읽기/나열류) 거부도 실재한다. 그러나 이건 이 특정 호출에서 fatal 하지 않았다(§A6b-4 가
metadata 만 허용해도 성공함을 보여준다 — 즉 이 file-read-data 거부는 git 이 관대하게 넘어가는
비필수 프로브였던 것으로 보인다). 나머지는 전부 `file-read-metadata` — `/Users/ohama` 자신과
`/Users/ohama/projs/cline-tests` 양쪽에 반복적으로.

**no-widening 후보 소진 — call-shape 을 바꿔도 안 된다(이번 세션에서 직접 실행):**
```
# (1) 절대경로 대신 순수 상대경로, 심지어 이미 존재하는 저장소 자신의 서브디렉터리 밑
$ cd workspace/.tmp-wt-diag/main-repo && mkdir sub
$ env GIT_CONFIG_GLOBAL=/dev/null /usr/bin/sandbox-exec -f <원본 미수정 shape 프로파일> -- \
    git worktree add sub/wt-rel -b wt-relbranch
fatal: Invalid path '/Users/ohama': Operation not permitted     # 동일하게 실패

# (2) 타깃 디렉터리를 미리 만들어 둔 경우 (원 진단 §A6 이 이미 확인, 이번 세션도 재확인)
# (3) 중첩 레벨 (nested/deep/...)
```
셋 다 완전히 동일한 실패다. **결론: git 이 관련 경로를 절대·정규화(realpath 류)하면서
`/Users/ohama` 자체를 항상 stat 해야 하고, 이 프로젝트 전체가 `$HOME` 아래 있는 한 어떤
호출 형태·env var·git 플래그로도 이 조상 stat 자체를 피할 수 없다 — no-widening 수정은
존재하지 않는다.**

### A6b-3. SBPL 발견 — "나중에 쓴 규칙이 이긴다"는 절반만 맞다

문제 (2)의 후보 (b)를 검증하려고 손으로 쓴 최소 프로파일(`(deny file-read-data (subpath
$HOME))` + `(allow file-read-metadata (subpath $HOME))` + 기존과 동일한 `(allow file-read*
(subpath <repo>))` 식 punch-through)을 만들었더니, **허용된 서브패스 안에서도** `ls`/`git
status` 가 깨졌다:
```
$ cd .../main-repo && /usr/bin/sandbox-exec -f <metadata-only-v1>.sb -- /bin/ls -la .
ls: .: Operation not permitted
→ kernel log: Sandbox: ls(24462) deny(1) file-read-data /Users/ohama/projs/cline-tests/workspace/.tmp-wt-diag/main-repo
```
이 디렉터리는 punch-through 목록에 있는데도 거부됐다. 네 가지 순서 조합으로 통제 실험했다
(전부 이번 세션에 직접 실행, `$HOME` 에 좁은 deny, `<repo>` 서브패스에 넓은/좁은 allow):

| 실험 | 규칙 순서(요약) | `ls .`(repo 안) |
|---|---|---|
| order-test-1 | `deny file-read-data(HOME)` → `allow file-read*(repo)` | **거부** |
| order-test-2 | `allow file-read*(repo)` → `deny file-read-data(HOME)`(반대 순서) | **거부** |
| order-test-3 | `deny file-read-data(HOME)` → `allow file-read-data(repo)`(같은 연산 키워드끼리) | **허용** |
| order-test-4 | order-test-1 규칙 + 추가로 `allow file-read-data(repo)` 명시 | **허용** |

order-test-1/2 가 **순서와 무관하게** 둘 다 거부라는 게 핵심이다 — 순서를 바꿔도 결과가
똑같으므로 이건 "line order" 문제가 아니라 "연산 키워드 구체성" 문제다: `file-read-data`
라는 **구체적** 연산에 대해 명시적 규칙이 존재하면, `file-read*` 라는 **넓은 wildcard**
규칙은(설령 경로가 더 좁고 텍스트상 더 나중에 나와도) 그 구체적 연산을 커버하지 못한다.
order-test-3(같은 키워드끼리)과 order-test-4(넓은 규칙 + 명시적으로 같은 키워드 규칙 추가)가
둘 다 성공한 게 이걸 증명한다. **이 프로젝트의 `gen_sandbox_profile.py` 자체 주석("SBPL is
last-match-wins")은 지금까지 이 generator 가 실제로 방출해 온 규칙 모양(모든 rule 이 항상
`file-read*`/`file-write*` 같은 넓은 키워드로만 통일돼 있음)에서는 참이지만, 서로 다른
구체성의 연산 키워드를 섞으면 깨진다 — 이건 이 프로젝트가 지금까지 실제로 시도해 본 적 없는
규칙 모양이라 이번에 처음 드러났다.**

### A6b-4. 최소 widening 실측 성공 — metadata-only, 세 변형 전부

order-test-4 의 교훈(넓은 wildcard punch-through 를 유지하면서 같은 키워드로 명시적
`file-read-data` allow 를 추가)을 반영한 v2 프로파일로 재시도:
```sbpl
(allow default)
(deny file-read-data (subpath "/Users/ohama"))
(allow file-read-metadata (subpath "/Users/ohama"))
(deny file-write* (subpath "/Users/ohama"))
(allow file-read* (subpath "<repo>"))
(allow file-read-data (subpath "<repo>"))   ; ← 없으면 §A6b-3 처럼 repo 안도 깨진다
(allow file-write* (subpath "<repo>"))
```
세 변형 전부 exit 0, 실제로 디스크에 worktree 생성됨:
```
$ env GIT_CONFIG_GLOBAL=/dev/null /usr/bin/sandbox-exec -f <v2>.sb -- git worktree add ../wt-v2test -b wt-v2test-branch
Preparing worktree (new branch 'wt-v2test-branch')
warning: unable to access '/Users/ohama/.config/git/ignore': Operation not permitted   # §A5 에 이미 기록된 것과 같은 비치명적 warning
HEAD is now at ec7b1d4 init
exit=0

$ git worktree add ../nested/deep/wt-nested -b wt-nested-branch     → exit=0 (중첩 레벨)
$ mkdir -p ../wt-precreated && git worktree add ../wt-precreated -b wt-precreated-branch   → exit=0 (사전 생성)

$ git worktree list
.../main-repo             ec7b1d4 [main]
.../nested/deep/wt-nested ec7b1d4 [wt-nested-branch]
.../wt-precreated         ec7b1d4 [wt-precreated-branch]
.../wt-v2test             ec7b1d4 [wt-v2test-branch]
```
디스크에서 직접 확인(샌드박스 밖):
```
$ cat workspace/.tmp-wt-diag/wt-v2test/.git
gitdir: /Users/ohama/projs/cline-tests/workspace/.tmp-wt-diag/main-repo/.git/worktrees/wt-v2test
$ cat workspace/.tmp-wt-diag/wt-v2test/f.txt
hi
```
**보호 경계가 실제로 metadata 로만 좁혀졌는지 검증(같은 v2 프로파일 아래):**
```
$ /usr/bin/sandbox-exec -f <v2>.sb -- /bin/cat /Users/ohama/.gitconfig          → 거부 (내용은 여전히 안 읽힘)
$ /usr/bin/sandbox-exec -f <v2>.sb -- /usr/bin/stat /Users/ohama/.gitconfig     → 성공, 실제 크기/권한/타임스탬프 반환
$ /usr/bin/sandbox-exec -f <v2>.sb -- /bin/ls -la /Users/ohama                  → 거부 ($HOME 나열도 여전히 안 됨)
$ /usr/bin/sandbox-exec -f <v2>.sb -- /bin/cat .../cline-tests/cline-analysis.md → 거부 (다른 무관 프로젝트 파일 내용도 안 읽힘)
```
**결론: 후보 (b)가 정확히 의도한 대로 동작한다** — `$HOME` 아래 어디든 stat 급 메타데이터
(존재/크기/권한/소유자/타임스탬프)는 노출되지만, 내용(`file-read-data`)과 디렉터리 나열은
punch-through 되지 않은 곳에서는 여전히 완전히 막혀 있다.

### A6b-5. 정확한 최소 코드 변경 (적용하지 않음 — 사람 결정 사항)

`phase-03/sandbox/gen_sandbox_profile.py` 의 `render_profile()`(현재 "정확히 2 + 2 +
2*len(allow_paths) 줄을 방출한다"고 스스로 문서화한 그 함수)을 이렇게 바꿔야 한다:

```python
# 현재:
lines.append(f'(deny file-read* (subpath "{protected_root}"))')
lines.append(f'(deny file-write* (subpath "{protected_root}"))')
for p in allow_paths:
    lines.append(f'(allow file-read* (subpath "{p}"))')
    lines.append(f'(allow file-write* (subpath "{p}"))')

# 제안(최소 widening, §A6b-4 로 실측 검증됨 — 적용 안 함):
lines.append(f'(deny file-read-data (subpath "{protected_root}"))')
lines.append(f'(allow file-read-metadata (subpath "{protected_root}"))')
lines.append(f'(deny file-write* (subpath "{protected_root}"))')
for p in allow_paths:
    lines.append(f'(allow file-read* (subpath "{p}"))')
    lines.append(f'(allow file-read-data (subpath "{p}"))')   # 신규 — 없으면 §A6b-3 처럼 이미 허용된 repo 도 깨진다
    lines.append(f'(allow file-write* (subpath "{p}"))')
```
줄 수 문서화(`Emits exactly 2 + 2 + 2*len(allow_paths) lines`)도 같이 갱신해야 한다. 이건
`EXTRA_ALLOW_PATHS`에 값 하나 넣는 것과 **차원이 다른** 변경이다 — `PROTECTED_ROOT` 자체가
보호하는 연산의 범위를 바꾸는 것이고, `config.env` 헤더가 "SBX-01/02/03 override point" 라고
부르는 그 지점보다 한 단계 더 깊은, generator 코드 자체의 변경이다. **이번 진단에서는
`gen_sandbox_profile.py` 를 건드리지 않았다 — 전부 스크래치 사본에서 검증했다.**

### A6b-6. Open Question 1 해소 (저비용) — Plan/Act 모드는 실재한다

`docs/cline-config-pins.md` §2 가 캡처한 `cline --help` 전문(11개 플래그)에는 `--mode` 가
없다 — 이게 원래 open question 의 근거였다. cline 을 직접 실행하지 않고, 이미 설치된 바이너리
(`/opt/homebrew/lib/node_modules/cline/bin/.cline`, Phase 1 이 CFG-04 재정의 때 쓴 것과 같은
`strings` 정적 스캔 기법)를 다시 읽어 확인했다:

```
$ strings .cline | grep -F '.option("--mode'
.option("--mode <act|plan>","Agent mode","act")
```
그리고 내부 5-모드 도구-허용 테이블(리터럴로 확인):
```js
Ja = {
  act:     {enableReadFiles:true, enableSearch:true, enableBash:true, enableWebFetch:true,
            enableApplyPatch:false, enableEditor:true,  enableSkills:true, ...},
  plan:    {enableReadFiles:true, enableSearch:true, enableBash:true, enableWebFetch:true,
            enableApplyPatch:false, enableEditor:false, enableSkills:true, ...},   // ← editor 만 다름
  search:  {..., enableBash:false, enableWebFetch:false, ...},
  minimal: {enableReadFiles:false, enableSearch:false, enableBash:true, ...},
  ...
}
```
그리고 `CLAUDE_CODE_PLAN_MODE_REQUIRED`, `CLAUDE_CODE_ACT_DONT_REDERIVE` 라는 이름의 env
var 도 존재한다(`CLAUDE_CODE_*` 접두사 — Claude Agent SDK 자체의 명명 규칙과 동일, cline 이
그 SDK 의 plan/act 기능을 그대로 물려받았다는 정황).

**결론:** Plan/Act 는 실재하는 개념이고, 최소 한 커맨드(`discord` 커넥터의 `createCommand()`)
에서 `--mode <act|plan>`(디폴트 `"act"`) CLI 플래그로 노출된다 — CLI 플래그이므로 원천적으로
TTY 와 무관하게(헤드리스에서도) 동작하도록 설계됐다. **미확인으로 남는 것:** 이 프로젝트가
실제로 쓰는 순수 헤드리스 1회성 프롬프트 커맨드(Phase 1 이 `--help` 전문을 캡처한 바로 그
커맨드)도 `--mode` 를 지원하는지는 이 정적 문자열 대조만으로는 단정할 수 없다(컴파일된
바이너리의 제어 흐름 분석이 필요한데, 이건 이번 진단 범위를 넘고 cline 실행 없이는 확정하기
어렵다). **DOC-01 권고 문장:** "Plan/Act 는 실재하는 기능이고 최소 하나의 커넥터 커맨드는
`--mode` 플래그로 지원한다(디폴트 act). 이 프로젝트의 기본 헤드리스 호출은 `--mode` 를 명시한
적이 없으므로 지금까지 전부 디폴트인 act 모드로만 실행돼 왔다 — Plan 모드는 이 프로젝트에서
한 번도 실제로 실행된 적이 없다는 뜻이고, 매뉴얼은 이걸 정직한 gap 으로 적어야 한다."

### A6b-7. Open Question 2 해소 (저비용) — "체크포인트"는 둘 다 있고, 서로 다르다

kanban 쪽은 §A4 에서 이미 확인됨(`createWorkingTreeCheckpointCommit`, 태스크 단위,
`GIT_AUTHOR_NAME` 등 직접 주입). cline 자신도 별도의, 훨씬 방대한 자체 체크포인트 기계장치를
갖고 있다는 게 이번에 `strings` 스캔으로 확인됐다(cline 실행 없이):

```
createCheckpoint, restoreCheckpoint, getCheckpointData, fileCheckpointingEnabled,
enableFileCheckpointing, readSessionCheckpointHistory, compareCheckpointToWorkspace,
buildCheckpointWorkspaceDiff, deleteCheckpointRefs, restoredCheckpointMetadata
cline-checkpoint-                                    ← git ref 접두사로 보이는 리터럴
CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING            ← env var
CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING               ← env var
```
`CLAUDE_CODE_*` 접두사 명명 규칙이 Plan/Act(§A6b-6)와 동일하다 — cline 이 Claude Agent SDK
자체의 파일 체크포인팅 기능을 그대로 물려받았다는 합리적 추론이지만, 이건 정적 문자열
증거일 뿐 런타임 동작(언제 자동 생성되는지, 헤드리스 `--auto-approve true` 에서도 기본으로
켜지는지, `--id` 세션 재개와 어떻게 연결되는지)은 검증하지 않았다.

**결론: 둘 다 있고, 서로 다른 것이다.** cline 자체 체크포인트는 **세션(에이전트 실행) 단위**
파일 상태 스냅샷/복원(`cline-checkpoint-*` 이름의 git ref 로 추정, `--id` 세션 재개와 같은
레이어), kanban 체크포인트는 **태스크 단위** 로 남기는 명시적 작업 커밋(kanban 웹 UI 의 diff
리뷰에서 보임, §A4). **DOC-01 은 전자, DOC-02 는 후자를 문서화해야 하고, 매뉴얼이 둘을 같은
개념으로 뭉뚱그리면 안 된다** — 이게 정확히 원래 open question 이 우려했던 지점이다.

### A6b-8. 종합 권고 (§A7 표의 worktree 행을 이 표로 갱신)

| 항목 | 권고 | widening 필요? | 확신도 |
|---|---|---|---|
| `git worktree add` 가 새 디렉터리를 못 만듦 | no-widening 수정 없음(재현으로 확인). 최소 widening: `PROTECTED_ROOT` 를 `file-read-data` deny + `file-read-metadata` allow 로 분리하고, `gen_sandbox_profile.py` 의 `render_profile()` 이 각 punch-through 경로마다 `file-read-data` 를 명시적으로 재허용하도록 수정(§A6b-5, 코드 변경, config 값 아님) | **예 — 정확히 이 범위로 확정** | HIGH(3변형 실측 성공 + 보호 경계 유지 확인) |
| Plan/Act 모드가 헤드리스에 적용되는가 | 실재함, 최소 한 커맨드는 `--mode` 로 지원(디폴트 act). 이 프로젝트의 기본 헤드리스 호출은 항상 디폴트(act)로만 동작해왔다 | 해당 없음(순수 조사 질문) | MEDIUM(정적 문자열 증거, 런타임 미검증) |
| DOC-01 "체크포인트"가 무엇을 가리키는가 | cline 자체 세션 체크포인트(파일 스냅샷)와 kanban 태스크 체크포인트 커밋 **둘 다 실재하며 다르다** — DOC-01 은 전자, DOC-02 는 후자 | 해당 없음(순수 조사 질문) | MEDIUM(cline 쪽은 정적 증거만, kanban 쪽은 §A4 소스 대조로 HIGH) |

**DOC-02(worktree) 가능 여부, 명확히:** 사람이 §A6b-5 의 `gen_sandbox_profile.py` 코드 변경과
그에 따른 정확한 비용(§A6b-4: `$HOME` 전체의 stat 급 메타데이터 노출, 내용·나열·쓰기는 계속
막힘)을 승인하기 전까지는 **불가능하다**. 승인하면 이 진단이 검증한 그대로 동작한다. 승인하지
않으면 매뉴얼은 "worktree 생성은 이 배포에서 지원되지 않는다"를 정직한 gap 으로 적어야 한다.

### A6b Sources

- 이번 세션 라이브 실행 트랜스크립트(§A6b-1~7의 모든 명령·커널 로그) — 스크래치 프로파일은
  `/private/tmp/.../scratchpad/`, 스크래치 저장소는 `workspace/.tmp-wt-diag/`(진단 종료 후
  삭제, `git status --porcelain` 로 0 변경 확인)
- `phase-03/sandbox/config.env`, `run_sandboxed.sh`, `gen_sandbox_profile.py` — 직접 읽음,
  미수정 확인(§A6b-5 는 제안일 뿐 미적용)
- `/opt/homebrew/lib/node_modules/cline/bin/.cline`(설치된 컴파일 바이너리) — `strings` 정적
  스캔으로 `--mode`/`Ja` 모드 테이블/`checkpoint*` 리터럴 확보. cline 프로세스는 이번 진단에서
  단 한 번도 실행하지 않았다(제약 준수)
- `docs/cline-config-pins.md` §2(`cline --help` 전문 캡처), `docs/headless-wrapper.md`
  §"검증된 CLI 플래그 표면" — Open Question 1 의 기존 근거로 재확인
- `.planning/phases/04-headless-cli-wrapper/04-RESEARCH.md` Pitfall 7 — `log stream` 선(先)기동
  레시피의 출처, §A6b-1 이 그 레시피 자체는 옳았음을 재확인
