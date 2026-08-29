# Claude Config - Shared Configuration

이 저장소는 여러 프로젝트에서 공유하는 Claude Code 설정입니다.

## 새 프로젝트에 설치

```bash
# 1. 프로젝트 생성 및 git 초기화
mkdir my-project && cd my-project
git init

# 2. .claude submodule 추가
git submodule add git@github-ohama:ohama/Claude-Config.git .claude

# 3. 초기 커밋
git add .gitmodules .claude
git commit -m "chore: add .claude as submodule"
```

## 기존 프로젝트에 추가

이미 git이 초기화된 프로젝트에 Claude-Config를 submodule로 추가하는 방법.

### Case 1: .claude 디렉토리가 없는 경우

```bash
cd existing-project

# submodule 추가
git submodule add git@github-ohama:ohama/Claude-Config.git .claude

# 커밋
git add .gitmodules .claude
git commit -m "chore: add .claude as submodule"
```

### Case 2: .claude 디렉토리가 이미 있는 경우

기존 `.claude/` 디렉토리를 백업하고 submodule로 교체.

```bash
cd existing-project

# 1. 기존 .claude 백업
mv .claude .claude.backup

# 2. git에서 .claude 제거 (tracked인 경우)
git rm -r --cached .claude 2>/dev/null || true

# 3. submodule 추가
git submodule add git@github-ohama:ohama/Claude-Config.git .claude

# 4. 백업에서 필요한 설정 복사 (선택)
cp .claude.backup/settings.local.json .claude/ 2>/dev/null || true

# 5. 커밋
git add .gitmodules .claude
git commit -m "chore: add .claude as submodule"

# 6. 백업 정리 (확인 후)
rm -rf .claude.backup
```

### Case 3: .claude가 이미 submodule인데 다른 원격을 가리키는 경우

```bash
cd existing-project

# 1. 기존 submodule 제거
git submodule deinit -f .claude
git rm -f .claude
rm -rf .git/modules/.claude

# 2. 새 submodule 추가
git submodule add git@github-ohama:ohama/Claude-Config.git .claude

# 3. 커밋
git add .gitmodules .claude
git commit -m "chore: replace .claude submodule"
```

### 확인

```bash
# submodule 상태 확인
git submodule status

# 원격 URL 확인
git config --file .gitmodules --get submodule..claude.url
```

## 기존 프로젝트 클론

```bash
# submodule 포함하여 클론
git clone --recurse-submodules <repo-url>

# 또는 클론 후 submodule 초기화
git clone <repo-url>
cd <repo>
git submodule update --init
```

## 설정 변경 후 Push (Project A)

`.claude/` 내용을 수정한 후:

```bash
/claude-config push
```

또는 커밋 메시지 지정:

```bash
/claude-config push -m "feat: add new skill"
```

### 수동으로 하려면

```bash
# 1. Submodule 커밋
cd .claude
git add -A
git commit -m "변경 내용"
git push

# 2. 부모 저장소 업데이트
cd ..
git add .claude
git commit -m "chore: update .claude submodule"
git push
```

## 다른 프로젝트에서 Pull (Project B)

Project A가 변경한 내용을 가져오려면:

```bash
/claude-config pull
```

### 상태 확인

```bash
/claude-config
```

### 수동으로 하려면

```bash
# 1. Submodule 최신으로 업데이트
cd .claude
git fetch origin
git pull origin master

# 2. 변경 확인
cd ..
git status .claude  # "(new commits)" 표시되면 업데이트됨

# 3. 부모 저장소에 반영
git add .claude
git commit -m "chore: update .claude submodule"
git push
```

## 명령어 요약

| 명령 | 설명 |
|------|------|
| `/claude-config` | 상태 확인 |
| `/claude-config push` | 변경 사항 commit/push |
| `/claude-config push -m "메시지"` | 지정 메시지로 commit |
| `/claude-config pull` | 원격 변경 가져오기 |

## 구조

```
.claude/
├── agents/          # 에이전트 설정
├── commands/        # 슬래시 명령어
├── docs/            # 문서
├── hooks/           # 훅 스크립트
├── skills/          # 스킬 정의
├── settings.json    # 공유 설정
└── settings.local.json  # 로컬 설정 (gitignore)
```

## 주의사항

- `settings.local.json`은 `.gitignore`에 포함되어 있어 공유되지 않음
- Submodule 변경 시 부모 저장소도 함께 커밋해야 다른 프로젝트에서 참조 가능
