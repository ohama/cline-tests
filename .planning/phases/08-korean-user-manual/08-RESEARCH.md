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
