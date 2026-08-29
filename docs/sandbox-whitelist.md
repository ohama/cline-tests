# Phase 3 샌드박스 + 저장소 화이트리스트 (SBX-01~04)

## 1. 무엇을 만들었나

`workspace/ALLOWED_REPOS.json` 하나가 이 phase 전체의 진실의 원천이다. 사람이 편집하는 파일은
이것 하나뿐이다.

```json
{
  "repos": ["/Users/ohama/projs/cline-tests/workspace/scratch-repo"]
}
```

`phase-03/sandbox/gen_sandbox_profile.py` 가 이 파일을 파싱해 `workspace/sandbox.sb` (macOS
Seatbelt SBPL 프로필)로 컴파일하고, `phase-03/sandbox/run_sandboxed.sh` 가 호출될 때마다 이
프로필을 무조건 새로 생성한 뒤 `sandbox-exec -f sandbox.sb -- <command>` 로 감싸서 실행한다.
캐시 경로는 어디에도 없다 — "저장소를 추가했는데 화이트리스트가 조용히 재생성되지 않았다"는
드리프트를 애초에 설계에서 제거하기 위해서다(03-RESEARCH.md 권고). `sandbox.sb` 는 **절대 손으로
고치지 않는다** — 매 호출마다 어차피 덮어써지고, `.gitignore` 에도 그렇게 등록되어 있다.

흐름을 한 줄로: `ALLOWED_REPOS.json` → (`gen_sandbox_profile.py`) → `sandbox.sb` →
(`run_sandboxed.sh` 가 `sandbox-exec` 로 감쌈) → 실제 실행.

## 2. 왜 Cline 자체 기능을 쓰지 않았나

`03-RESEARCH.md` 가 실제 설치된 `cline` 바이너리를 `strings` 로 직접 뒤져 확인한 사실 두 가지:

- `CLINE_COMMAND_PERMISSIONS` 와 `.clineignore` 는 이 빌드에 아예 존재하지 않는다. 유일한
  매치는 완전히 무관한 Discord.js 상수였다.
- `CLINE_SANDBOX` / `CLINE_SANDBOX_DATA_DIR` 라는 환경변수는 존재하지만, 이름과 달리
  파일시스템 샌드박스가 아니다 — 설정/데이터를 저장하는 위치만 옮길 뿐, 접근을 막는 기능은
  전혀 없다.

즉 Cline 자체에는 기댈 수 있는 보안 경계가 없다. 커널이 강제하는 `sandbox-exec` (macOS
Seatbelt) 를 프로세스 전체에 씌우는 것이 유일하게 실제로 작동하는 수단이다.

## 3. ⚠️ 이 샌드박스의 한계 (명시된 범위 경계)

**이 문서에서 가장 눈에 띄어야 하는 절이다.**

생성되는 프로필의 베이스는 `(deny default)` 가 아니라 **`(allow default)` + `$HOME` 통째 deny +
화이트리스트 punch-through** 다:

```
(allow default)
(deny file-read* (subpath "$HOME"))
(deny file-write* (subpath "$HOME"))
(allow file-read* (subpath "<ALLOWED_REPOS.json 의 각 항목>"))
(allow file-write* (subpath "<ALLOWED_REPOS.json 의 각 항목>"))
```

그러므로:

- **보호되는 것**: `$HOME` 아래, 화이트리스트 밖의 모든 경로.
- **보호되지 않는 것**: `$HOME` 밖 — `/tmp`, `/opt`, `/usr/local`, 그리고 외장 볼륨이나 네트워크
  공유가 마운트될 경우 그 내용. 샌드박스 안의 프로세스는 이런 곳을 여전히 읽고 쓸 수 있다.

이것은 실수가 아니라 **의도적으로 받아들인 범위 경계**다. 조사 시점(2026-08-30)에 이 기계에는
보호가 필요한 다른 마운트 지점이 없었고, 기계의 저장소 구성이 바뀌면(외장 디스크 상시 마운트
등) 재검토해야 한다. 이 문구는 `phase-03/sandbox/config.env`와 `run_sandboxed.sh` 헤더에도
verbatim 으로 이미 적혀 있다 — 이 문서는 그것을 그대로 옮긴 것이지 새로 지어낸 것이 아니다.

**`(deny default)` 를 쓰지 않은 이유.** 실측에서 `(deny default)` 베이스는 dyld 가 런타임
의존성(공유 라이브러리 등)을 읽지 못하는 순간 실제 바이너리를 진단 메시지 하나 없이 `SIGABRT`
로 죽였다. "종료 코드가 0 이 아니면 차단된 것"이라는 순진한 테스트는 이 크래시를 성공한 차단으로
오보한다. 이 phase 의 모든 차단 테스트(`assert_denied.sh`)가 exit 코드만이 아니라 stderr 의 실제
`Operation not permitted` 문구까지 확인하는 이유가 바로 이것이다 — 크래시와 거부(denial)를
구분하지 못하면 fail-open 프로필도 통과된 것처럼 보일 수 있다.

## 4. 저장소를 추가하려면

`workspace/ALLOWED_REPOS.json` 의 `repos` 배열에 절대 경로 한 줄을 추가하고
`phase-03/sandbox/verify_sandbox.sh` 를 돌려 4개 CRITERION 이 전부 PASS 인지 확인한다. 그게
전부다 — 프로필은 다음 `run_sandboxed.sh` 호출 때 자동으로 재생성된다.

**금지 사항 두 가지:**

- **저장소 루트 `/Users/ohama/projs/cline-tests` 를 통째로 넣지 말 것.** `bench/` 가 그 아래에
  있어, 루트를 넣으면 `bench/` 도 함께 punch-through 되어 SBX-04(criterion 4)가 깨진다.
  `ALLOWED_REPOS.json` 자체의 `_comment` 필드에도 이 금지가 적혀 있다.
- **`sandbox.sb` 를 손으로 고치지 말 것.** 매 호출마다 덮어써지므로 손댄 내용은 사라지고, 그
  사이 잘못된 프로필로 실행될 위험만 남는다.

심볼릭 링크로 적힌 경로도 안전하다 — 생성기가 모든 경로를 `os.path.realpath()` 로 정규화한 뒤에
프로필에 쓰기 때문이다. 이 정규화 단계를 제거하면 실제 우회가 생긴다는 것은 연구에서 재현된
사실이다(`/tmp` vs `/private/tmp` 같은 심볼릭 링크 스푸핑). `gen_sandbox_profile.py` 는
`--no-canonicalize` 라는 TEST-ONLY 디버그 플래그를 갖고 있는데, 이 회귀를 검증기 스스로
재현하기 위한 것일 뿐 어떤 정상 호출 경로에서도 쓰이지 않는다(`run_sandboxed.sh` 는 이 플래그를
절대 넘기지 않는다).

## 5. Phase 4 를 위한 인터페이스 계약

Phase 4 가 이 phase 의 내부 구현을 역설계하지 않아도 되도록, 계약은 다음과 같다:

- **호출 형태**: `phase-03/sandbox/run_sandboxed.sh -- <command> [args...]`
  (예: `phase-03/sandbox/run_sandboxed.sh -- cline --auto-approve true ...`)
- **종료 코드와 stderr**: 감싼 명령(`<command>`)의 것이 그대로 전달된다. `run_sandboxed.sh`
  자신의 종료 코드는 프로필 생성 자체가 실패했을 때(fail closed)만 관여한다.
- **화이트리스트 밖 경로를 건드리는 명령**은 `Operation not permitted` 로 거부된다 — Phase 4
  성공기준 3 이 기대하는 신호가 정확히 이것이다.
- **기본 작업 디렉터리**로 쓸 수 있는, 화이트리스트 안에 이미 들어 있는 경로:
  `workspace/scratch-repo`.
- **상시 게이트**: `phase-03/sandbox/verify_sandbox.sh`
  (`[--out-dir <dir>]`, 인자 없이 실행하면 `phase-03/results/` 아래 새 타임스탬프 디렉터리에
  결과를 남긴다). 종료 코드 계약: `0`=전부 통과, `1`=하나 이상 FAIL, `2`=크래시/판정 불가
  (성공으로 취급하면 안 됨). Phase 4·5·6·7 은 `run_sandboxed.sh` 를 신뢰하기 전에 이 게이트를
  먼저 돌려야 한다 — Phase 2 의 `phase-02/infra/verify_no_regression.sh` 와 같은 성격의 상시
  게이트다(읽기 전용, 재실행 가능, 무변경).
- **넓히기가 필요할 때의 유일한 지점**: `phase-03/sandbox/config.env` 의 `EXTRA_ALLOW_PATHS`
  (콜론 구분 경로 목록, 기본값 빈 문자열). 사전 선언된 후보 목록
  (`$HOME/.npm`, `$HOME/.cache`, `$HOME/.config/cline`, `$HOME/Library/Caches/cline`) 밖으로
  넓히는 것은 사람의 결정이며, 이 문서를 읽는 어떤 자동화 코드도 스스로 그 결정을 내려서는
  안 된다.

## 6. 검증 증거

plan 03-03 이 남긴 결과 디렉터리: 실제 화이트리스트 대상 독립 2회 실행
(`phase-03/results/20260829T202043Z-sbx/`, `phase-03/results/20260829T202048Z-sbx/`, 둘 다 exit
0/16 케이스/CRASHED 0/동일한 4개 CRITERION PASS), 그리고 음성 대조군 3종
(`phase-03/results/20260829T201927Z-negative-control/`).

ROADMAP 성공 기준과 `verify_sandbox.sh` 케이스 ID 의 대응:

| 기준 | 무엇을 증명 | 증명하는 케이스 |
|---|---|---|
| 1 (SBX-01) | `ALLOWED_REPOS.json` 이 유일한 진실의 원천 | criterion-1 체크 (아래 서술) |
| 2 (SBX-02) | 화이트리스트 밖 읽기/쓰기가 실제로 실패 | F2, F3, F8 |
| 3 (SBX-03) | 화이트리스트 밖 `execute_command` 가 `sandbox-exec` 로 차단 | F4, F8 |
| 4 (SBX-04) | `bench/` 결과 디렉터리가 샌드박스 안에서 읽을 수 없음 | P3, P4 |

**criterion-1 체크가 실제로 무엇을 보는지.** `ALLOWED_REPOS.json` 이 존재하고 정상 파싱되며
모든 항목이 실재하는 디렉터리로 resolve 되는지 확인한 뒤, **어떤 항목도 `realpath(BENCH_DIR)`
와 같거나 그 조상이 아님**을 검사한다. 방향이 중요하다 — 막으려는 오설정은 "저장소 루트를
화이트리스트에 넣어서 `bench/` 가 punch-through 를 물려받는" 실수이지, 그 반대(저장소가 실수로
`bench/` 안쪽에 놓이는 경우)가 아니다. 이 서술은 `phase-03/sandbox/verify_sandbox.sh` 의 실제
구현(criterion-1 섹션 주석: "NO entry equals or is an ancestor of realpath(BENCH_DIR)")과 정확히
일치한다.

세 음성 대조군이 무엇을 증명하는지: (1) `--negative-control` 는 사전점검(profile sanity
pre-check)이 deny 규칙이 없는 fail-open 프로필 자체를 거부한다는 것을 보여주고, (2)
`--negative-control-skip-precheck` 로 그 사전점검을 우회하면 Group F 의 거부 케이스 4건 전부가
`FAIL not-denied` 로 정직하게 실패한다는 것을 보여주며(검증기가 통과를 흉내내지 않음), (3)
`gen_sandbox_profile.py --no-canonicalize` 아래서는 F6(심볼릭 링크로 적힌 화이트리스트 항목
케이스)이 예상대로 실패해, 정규화 단계 자체가 없어지는 회귀를 검증기가 실제로 잡아낸다는 것을
보여준다. 세 가지 모두 "검증기가 통과만 아는 게 아니라 실패도 정직하게 낼 수 있다"는 것을
실증한다 — 그렇지 않으면 fail-open 샌드박스가 조용히 PASS 로 보고될 위험이 있다
(03-RESEARCH.md Pitfall 5).

## 7. `cline` 스모크 테스트 결과

이 phase 는 실제 `cline` 바이너리를 정확히 **한 번만** 샌드박스 아래에서 호출했다(plan 03-04,
`phase-03/results/20260829T202633Z-cline-smoke/`). 결과는 **(C) BLOCKED-NEEDS-HUMAN** 이다:

```
phase-03/sandbox/run_sandboxed.sh -- "$CLINE_BIN" --version
```

종료 코드 1, stdout 없음, stderr:

```
resolved allow list: ['/Users/ohama/projs/cline-tests/workspace/scratch-repo', '/Users/ohama/.cline']
error: An unknown error occurred (Unexpected)
```

`strings -a` 로 설치된 `.cline` 바이너리를 직접 확인한 결과, 이 메시지는 Bun 런타임 자체의
일반적인 startup catch-all 오류 문구("error: An unknown error occurred, possibly due to low max
file descriptors (Unexpected)"의 짧은 변형)이며, 특정 경로나 errno 를 알려주지 않는다.
`~/.cline/` 아래 어떤 파일도 이 실행으로 갱신되지 않아, 실패가 Bun 런타임이 자기 데이터 디렉터리에
손대기도 전에 일어났음을 시사한다. 어떤 파일 경로가 거부됐는지는 이 증거만으로 특정할 수 없다.

이 결과는 **Phase 4 를 위한 미해결 항목**이다 — 경계를 넓히는 것은 사람의 결정이라 이 phase 는
일부러 그 결정을 내리지 않았다: `EXTRA_ALLOW_PATHS` 는 이 phase 종료 시점에도 빈 값 그대로다.
Phase 4 는 실제 `cline` 을 이 샌드박스 아래에서 그대로 돌리면 이 일반적인 Bun 오류를 만난다는
것을 전제하고, `dtruss`/`fs_usage`(관리자 권한 필요, 이 phase 에서는 시도하지 않음) 같은 더
정밀한 도구로 재현한 뒤에 `EXTRA_ALLOW_PATHS` 를 사전 선언된 후보 목록 안에서 좁게 넓힐지 판단할
시간을 예산에 넣어야 한다.

ROADMAP Phase 3 의 네 성공 기준 중 어느 것도 실제 `cline` 이 샌드박스 아래서 도는 것을 요구하지
않는다 — 기준 2/3 은 위 6절 표대로 `/bin/cat`/`/bin/sh`/`node` 로 커널 수준까지 이미 증명됐고,
실제 헤드리스 `cline` 래퍼는 Phase 4 의 소유다. 이 결과는 숨겨진 실패가 아니라 기록된 미해결
항목이다.

전체 재현 과정, 첫 시도가 왜 세지 않는지(Node 자체 부트스트랩 SIGABRT, cline/Bun 코드는 한 줄도
실행되지 않음), config guard 힐 사이클 전체 로그는
`phase-03/results/20260829T202633Z-cline-smoke/README.md` 와 `verdict.txt` 에 있다.

## 8. 미룬 것

`.planning/research/ARCHITECTURE.md` 가 제안한, Kanban 이 여러 저장소를 다루기 위한
`workspace/<repo-name>` 심볼릭 링크 트리는 이 phase 의 네 성공 기준(SBX-01~04) 어디에도
필요하지 않다. Phase 5 로 미룬다.
