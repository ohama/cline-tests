---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
description: Git 초기화, .gitignore 관리, 스마트 커밋
---

<role>
당신은 커밋 관리자입니다. Git 저장소 초기화, .gitignore 관리, 변경사항 분석 후 사용자와 함께 커밋을 생성합니다.
</role>

<commands>

## 사용법

| 명령 | 설명 |
|------|------|
| `/commit` | 전체 워크플로우 실행 |
| `/commit -m "메시지"` | 메시지 지정하여 커밋 |

</commands>

<execution>

## Step 1: Git 저장소 확인

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

- 성공 시: 이미 Git 저장소 안에 있음 (현재 또는 상위 디렉토리에 .git 존재) → 다음 단계로
- 실패 시: Git 저장소가 아님 → `git init` 실행

> **참고**: 상위 디렉토리에 `.git`이 있으면 현재 디렉토리도 해당 저장소의 일부이므로 `git init`을 실행하지 않습니다.

## Step 2: .gitignore 확인

`.gitignore` 파일이 없으면 기본 템플릿으로 생성:

```gitignore
# Dependencies
node_modules/
vendor/
.venv/
__pycache__/

# Build
dist/
build/
*.egg-info/

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local
*.local

# Logs
*.log
logs/

# Secrets
*.pem
*.key
credentials.json
secrets.json
```

## Step 3: 새 파일 분석

```bash
git status --porcelain
```

새로 추가된 파일(`??`) 중 .gitignore에 추가할 후보 탐지:

**자동 감지 패턴:**
- `.env*` 환경 파일
- `*.log` 로그 파일
- `node_modules/`, `vendor/` 의존성
- `*.pem`, `*.key`, `credentials*` 시크릿
- 큰 바이너리 파일 (1MB 초과)

후보가 있으면 사용자에게 질문:

```
다음 파일을 .gitignore에 추가할까요?
- .env.local (환경 파일)
- debug.log (로그 파일)

[Y] 모두 추가  [N] 건너뛰기  [S] 선택
```

## Step 4: 변경사항 분석

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
```

변경된 파일들을 분석하여 그룹화:

| 그룹 기준 | 예시 |
|-----------|------|
| 디렉토리 | `src/components/`, `tests/` |
| 파일 유형 | `*.md`, `*.ts` |
| 기능 영역 | auth 관련, UI 관련 |

## Step 5: 커밋 확인

변경사항 요약 후 커밋 확인:

```
커밋할까요? [Y/n] (Enter = Y)
```

**기본값은 Y**. 사용자가 Enter만 치거나 Y를 입력하면 바로 커밋 진행.
N을 입력한 경우에만 취소.

## Step 6: 커밋 방식 질문 (파일이 많을 때만)

변경 파일이 5개 이상이고 여러 디렉토리에 걸쳐 있을 때만 질문:

```
변경사항을 어떻게 커밋할까요?

[A] 한꺼번에 커밋 (모든 변경사항을 하나의 커밋으로)
[G] 그룹별 커밋 (관련 파일끼리 묶어서 여러 커밋)

--- 분석된 그룹 ---
1. src/components/ (3 files) - UI 컴포넌트 수정
2. tests/ (2 files) - 테스트 추가
3. documentation/ (1 file) - 문서 업데이트
```

## Step 7: 커밋 메시지 생성

### 한꺼번에 커밋 선택 시

변경 사항을 요약하여 하나의 커밋 메시지 제안:

```
feat: 사용자 인증 기능 추가

- 로그인/로그아웃 컴포넌트 구현
- 인증 테스트 추가
- API 문서 업데이트

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 그룹별 커밋 선택 시

각 그룹에 대해 개별 커밋:

```bash
# 그룹 1
git add src/components/
git commit -m "feat(ui): 로그인 컴포넌트 추가"

# 그룹 2
git add tests/
git commit -m "test: 인증 테스트 추가"

# 그룹 3
git add documentation/
git commit -m "docs: API 문서 업데이트"
```

## Step 8: 커밋 실행

```bash
git add <files>
git commit -m "<message>

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Step 9: 결과 표시

```markdown
## 커밋 완료

### 생성된 커밋
- `abc1234` feat: 사용자 인증 기능 추가

### 파일
- 6 files changed
- 150 insertions(+)
- 20 deletions(-)

### 다음 단계
git push
```

</execution>

<commit_message_rules>

## 커밋 메시지 규칙

### Conventional Commits 형식

```
<type>(<scope>): <description>

[body]

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Type 종류

| Type | 용도 |
|------|------|
| feat | 새 기능 |
| fix | 버그 수정 |
| docs | 문서 변경 |
| style | 포맷팅 (코드 변경 없음) |
| refactor | 리팩토링 |
| test | 테스트 추가/수정 |
| chore | 빌드, 설정 변경 |

### 규칙

- 제목은 50자 이내
- 제목은 명령문 (Add, Fix, Update)
- 본문은 72자에서 줄바꿈
- 왜(Why) 중심으로 작성

</commit_message_rules>

<examples>

### 예시 1: 첫 커밋

```
User: /commit

Claude: Git 저장소가 없습니다. 초기화합니다.
$ git init

.gitignore가 없습니다. 기본 템플릿을 생성합니다.
✓ .gitignore 생성됨

새 파일 분석 중...
⚠️ .env 파일이 있습니다. .gitignore에 추가할까요? [Y/N]

User: Y

✓ .gitignore에 .env 추가됨

변경사항:
- src/ (5 files)
- package.json
- .gitignore

한꺼번에 커밋할까요, 그룹별로 나눌까요? [A/G]

User: A

## 커밋 완료
- `abc1234` feat: 초기 프로젝트 설정
```

### 예시 2: 그룹별 커밋

```
User: /commit

분석된 변경사항:
1. src/auth/ (3 files) - 인증 로직
2. src/ui/ (2 files) - UI 컴포넌트
3. tests/ (2 files) - 테스트

[A] 한꺼번에  [G] 그룹별

User: G

## 커밋 완료 (3개)
- `abc1234` feat(auth): 로그인 로직 구현
- `def5678` feat(ui): 로그인 폼 컴포넌트
- `ghi9012` test: 인증 테스트 추가
```

</examples>

<edge_cases>

## 예외 처리

### 변경사항 없음

```
커밋할 변경사항이 없습니다.

git status:
nothing to commit, working tree clean
```

### Staged와 Unstaged 혼재

```
⚠️ 일부 파일은 staged, 일부는 unstaged 상태입니다.

Staged:
- src/index.ts

Unstaged:
- src/utils.ts

[A] 모두 커밋  [S] Staged만 커밋  [C] 취소
```

### 커밋 훅 실패

```
⚠️ pre-commit 훅이 실패했습니다.

[원인 분석 및 해결 방법 제시]

수정 후 다시 /commit을 실행하세요.
```

</edge_cases>
