---
allowed-tools: Read, Write, Edit, Bash, Glob, AskUserQuestion
description: mdBook 프로젝트 설정 및 GitHub Pages 배포 준비
---

<role>
mdBook 문서 사이트 설정 도우미. 지정 디렉토리를 mdBook 프로젝트로 구성하고 (book.toml, SUMMARY.md 추가), docs/에 빌드하며, GitHub Actions 워크플로우를 생성합니다.

핵심 원칙: **소스 디렉토리 = mdBook 프로젝트.** 별도 book/ 디렉토리를 만들지 않고, 사용자의 .md 파일이 있는 디렉토리에서 직접 작업한다. 파일 복사 없음.
</role>

<commands>

## 사용법

| 명령 | 설명 |
|------|------|
| `/mdbook <dir>` | 지정 디렉토리를 mdBook으로 구성 (최초 설정 또는 SUMMARY 업데이트) |
| `/mdbook` | 대화형 설정 시작 (디렉토리 질문 포함) |
| `/mdbook init <dir>` | 기본값으로 빠른 초기화 (빈 템플릿) |
| `/mdbook build <dir>` | 빌드만 실행 |
| `/mdbook clean <dir>` | 빌드 출력 정리 (docs/ 삭제) |
| `/mdbook serve <dir>` | 로컬 개발 서버 |

</commands>

<architecture>

## 디렉토리 구조

**별도 book/ 디렉토리를 만들지 않는다.** `<dir>` 자체가 mdBook 프로젝트가 된다.

### 최초 설정 전 (사용자의 원본)

```
tutorial/
    01-overview.md
    02-settings.md
    03-commands.md
    images/
```

### 최초 설정 후 (book.toml + SUMMARY.md + introduction.md 추가)

```
tutorial/                  ← mdBook 프로젝트 루트
    book.toml              ← 추가됨 (설정, src = ".")
    SUMMARY.md             ← 추가됨 (목차)
    introduction.md        ← 추가됨 (소개 페이지)
    01-overview.md         ← 원본 그대로
    02-settings.md         ← 원본 그대로
    03-commands.md         ← 원본 그대로
    images/                ← 원본 그대로

docs/                      ← 빌드 출력 (프로젝트 루트)
```

### book.toml 핵심 설정

```toml
[book]
src = "."       # ← 별도 src/ 없이 디렉토리 자체를 소스로
```

### 장점

- **파일 복사 없음** — 원본이 곧 mdBook 소스
- **수정 즉시 반영** — 파일 편집 → `mdbook build` → 끝
- **동기화 불필요** — 파일이 한 벌이므로 상태 추적 최소화
- **추가되는 파일 3개만** — book.toml, SUMMARY.md, introduction.md

</architecture>

<execution>

## Step 1: mdbook 설치 확인

```bash
which mdbook || echo "NOT_INSTALLED"
```

설치 안 됨 → 설치 안내:
```
mdbook이 설치되어 있지 않습니다.

설치 방법:
  cargo install mdbook
  # 또는
  brew install mdbook  # macOS
  # 또는
  sudo apt install mdbook  # Ubuntu
```

## Step 2: 디렉토리 결정 및 기존 설정 확인

### 디렉토리 결정

**인자로 디렉토리가 주어진 경우** (`/mdbook <dir>`):
- `{DIR}` = 주어진 디렉토리
- 디렉토리 존재 확인: `[ -d "{DIR}" ]`
- 없으면 오류 출력 후 중단

**인자 없이 실행된 경우** (`/mdbook`):
- AskUserQuestion으로 디렉토리 질문
- 옵션: 기존 폴더 경로 입력 / 새 폴더 생성

### 기존 설정 확인

```bash
[ -f "{DIR}/book.toml" ] && echo "ALREADY_CONFIGURED"
```

**book.toml이 있는 경우 → 업데이트 모드 (Step 7로 이동):**

이미 mdBook 프로젝트가 구성되어 있으므로:
1. 현재 SUMMARY.md와 디렉토리의 .md 파일 목록을 비교
2. 새 파일이 추가되었거나 삭제된 파일이 있으면 SUMMARY.md 업데이트 제안
3. 빌드 실행

**book.toml이 없는 경우 → 최초 설정 (Step 3부터 계속):**

## Step 3: 소스 파일 스캔

```bash
ls {DIR}/*.md 2>/dev/null
```

- .md 파일 목록 표시
- .md 파일이 없으면 경고 (빈 템플릿으로 진행할지 질문)

## Step 4: 프로젝트 정보 수집

AskUserQuestion으로 수집:

**질문 1: 프로젝트 정보**
- 책 제목 (예: "My Project Documentation")
- 저자 이름
- 언어 (ko/en, 기본: ko)
- 설명 (한 줄)

**질문 2: GitHub 정보** (선택)
- Repository URL (예: https://github.com/user/repo)
- 없으면 edit URL 기능 비활성화

## Step 5: mdBook 파일 생성

`{DIR}/` 안에 3개 파일을 생성한다.

### book.toml

```toml
[book]
title = "{TITLE}"
authors = ["{AUTHOR}"]
language = "{LANG}"
description = "{DESCRIPTION}"
src = "."

[build]
build-dir = "../docs"
create-missing = false

[output.html]
default-theme = "light"
preferred-dark-theme = "navy"
{GIT_REPO_CONFIG}

[output.html.search]
enable = true
limit-results = 30
boost-title = 2
boost-hierarchy = 1
```

**GIT_REPO_CONFIG** (repo URL 있을 때만):
```toml
git-repository-url = "{REPO_URL}"
edit-url-template = "{REPO_URL}/edit/master/{DIR}/{path}"
```

**build-dir 계산:**
- `{DIR}`이 프로젝트 루트 기준 1단계 하위 (`tutorial/`) → `"../docs"`
- `{DIR}`이 2단계 하위 (`src/docs/`) → `"../../docs"`
- `{DIR}`이 프로젝트 루트 자체 (`.`) → `"docs"` (하위로)

### SUMMARY.md

기존 .md 파일을 스캔하여 목차를 생성한다:
- 각 .md 파일의 첫 번째 `#` 헤더를 제목으로 추출
- 파일명 순서대로 챕터 목록 구성
- 사용자에게 목차 구조 확인

```markdown
# Summary

[소개](introduction.md)

# 본문

- [.claude/ 디렉토리 개요](01-overview.md)
- [Settings 설정](02-settings.md)
- [Commands (슬래시 명령어)](03-commands.md)
```

기존 .md 파일이 없으면 (빈 템플릿):
```markdown
# Summary

[소개](introduction.md)

# 시작하기

- [Chapter 1](chapter-01.md)
```

### introduction.md

```markdown
# {TITLE}

{DESCRIPTION}

## 시작하기

[Chapter 1]({FIRST_CHAPTER_FILE})부터 시작하세요.
```

## Step 6: docs/ 충돌 처리

```bash
[ -d "docs" ] && echo "DOCS_EXISTS"
```

`docs/`가 존재하면 질문:
```
docs/ 폴더가 이미 존재합니다.

[B] 백업 후 진행 (docs/ → docs.backup/)
[O] 덮어쓰기
[X] 취소
```

## Step 7: 빌드

```bash
mdbook clean {DIR}
mdbook build {DIR}
```

**참고:** `mdbook clean`은 이전 빌드 출력을 삭제하여 삭제된 챕터의 잔여 HTML 파일이 남지 않도록 한다.

## Step 8: SUMMARY.md 동기화 확인 (업데이트 모드)

book.toml이 이미 있어서 Step 2에서 여기로 온 경우:

1. 현재 SUMMARY.md를 파싱하여 등록된 .md 파일 목록 추출
2. 디렉토리의 실제 .md 파일 목록과 비교
3. 차이가 있으면 표시:

```
SUMMARY.md 동기화:

  + 08-appendix.md    (새 파일 - SUMMARY에 없음)
  - old-chapter.md    (SUMMARY에 있지만 파일 없음)

SUMMARY.md를 업데이트할까요? [Y/N]
```

**비교 제외 대상:** SUMMARY.md, introduction.md, book.toml (mdBook 자체 파일)

4. Y 선택 시:
   - 새 파일: SUMMARY.md의 적절한 섹션에 추가 (파일의 첫 # 헤더를 제목으로)
   - 삭제된 파일: SUMMARY.md에서 해당 항목 제거
   - 기존 섹션 구조(# 헤더)는 유지

5. N 선택 시 또는 차이 없으면: 빌드만 실행

```bash
mdbook clean {DIR}
mdbook build {DIR}
```

## Step 9: GitHub Pages 설정 (최초 설정 시만)

Step 2에서 book.toml이 없어 최초 설정으로 진행한 경우에만 실행.
업데이트 모드에서는 건너뛴다.

### .nojekyll 생성
```bash
touch docs/.nojekyll
```

### GitHub Actions 워크플로우

```yaml
# .github/workflows/mdbook.yml
name: Build mdBook

on:
  push:
    branches:
      - master
      - main
    paths:
      - '{DIR}/**'
  workflow_dispatch:

concurrency:
  group: mdbook-build
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: false

      - name: Setup mdBook
        uses: peaceiris/actions-mdbook@v2
        with:
          mdbook-version: 'latest'

      - name: Build mdBook
        run: |
          mdbook clean {DIR}
          mdbook build {DIR}

      - name: Check for changes
        id: check
        run: |
          git add docs/
          git diff --cached --quiet || echo "changes=true" >> $GITHUB_OUTPUT

      - name: Commit and push
        if: steps.check.outputs.changes == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit -m "docs: rebuild mdBook site"
          git push
```

## Step 10: README.md에 Book 링크 추가 (최초 설정 시만)

프로젝트 루트에 `README.md`가 있으면 GitHub Pages 링크를 추가한다.

```bash
[ -f "README.md" ] && echo "README_EXISTS"
```

**README.md가 있는 경우:**

1. GitHub repo URL에서 Pages URL을 유도한다:
   - `https://github.com/{user}/{repo}` → `https://{user}.github.io/{repo}/`

2. README.md에 이미 동일한 링크가 있는지 확인한다:
   ```bash
   grep -q "github.io/{REPO_NAME}" README.md
   ```
   - 이미 있으면 건너뛰기

3. 링크가 없으면 README.md의 **첫 번째 `##` 헤딩 바로 앞**에 Documentation 섹션을 삽입한다:

   ```markdown
   ## Documentation

   [{TITLE}]({PAGES_URL})

   ```

   - 첫 번째 `##`을 찾아 그 직전 줄에 삽입
   - `##`이 없으면 파일 끝에 추가

4. GitHub repo URL이 없는 경우 (Step 4에서 미입력):
   - 이 단계를 건너뛴다

**README.md가 없는 경우:** 건너뛴다.

## Step 11: 결과 출력

### 최초 설정

```markdown
## mdBook 설정 완료

### {DIR}/ 에 추가된 파일
- book.toml - mdBook 설정 (src = ".")
- SUMMARY.md - 목차
- introduction.md - 소개 페이지

### 빌드 출력
- docs/ ({N} HTML files)

### 기타
- .github/workflows/mdbook.yml - 자동 빌드
- README.md - Book 링크 추가 (해당 시)

### 다음 단계
1. `mdbook serve {DIR}`으로 로컬 미리보기
2. 새 .md 파일 추가 후 `/mdbook {DIR}`로 SUMMARY.md 자동 업데이트
3. git push 후 GitHub Settings > Pages > Branch: master, Folder: /docs
```

### 업데이트 (SUMMARY 동기화)

```markdown
## mdBook 업데이트 완료

### SUMMARY.md 변경
- + 08-appendix.md 추가됨
- - old-chapter.md 제거됨

### 빌드
- docs/ 재생성 완료
```

### 업데이트 (변경 없음)

```
SUMMARY.md와 파일 목록이 일치합니다.
mdbook build {DIR} 완료.
```

</execution>

<subcommands>

## /mdbook init <dir>

기본값으로 빠른 초기화:
- 제목: 디렉토리명 (없으면 현재 폴더명)
- 저자: git config user.name
- 언어: ko
- 빈 SUMMARY.md 템플릿 생성

```bash
mdbook build {DIR}
```

## /mdbook build <dir>

빌드만 실행:
```bash
mdbook clean {DIR}
mdbook build {DIR}
```

`{DIR}` 생략 시:
- 현재 디렉토리에 book.toml이 있으면 `.`으로 빌드
- 없으면 book.toml을 가진 하위 디렉토리를 자동 탐지

## /mdbook clean <dir>

빌드 출력 정리 (stale 파일 제거):
```bash
mdbook clean {DIR}
```

- book.toml의 `build-dir`에 해당하는 디렉토리를 삭제
- 챕터 삭제 후 남은 잔여 HTML 파일 정리에 유용
- `{DIR}` 생략 시: `/mdbook build`와 동일한 자동 탐지 규칙 적용

## /mdbook serve <dir>

로컬 개발 서버:
```bash
mdbook serve {DIR} --open
```

</subcommands>

<examples>

### 예시 1: 최초 설정

```
User: /mdbook tutorial

Claude: tutorial/ 스캔 결과:
- 01-overview.md
- 02-settings.md
- 03-commands.md
- 04-skills.md

[프로젝트 정보 질문 → 답변]

tutorial/ 에 추가:
- book.toml (src = ".")
- SUMMARY.md (4 chapters)
- introduction.md

## 완료
- tutorial/ (3 files 추가, 기존 4 files 유지)
- docs/ (10 HTML files)

`mdbook serve tutorial`으로 미리보기하세요.
```

### 예시 2: 재실행 (새 파일 추가됨)

```
User: /mdbook tutorial

Claude: tutorial/book.toml 발견 — 업데이트 모드

SUMMARY.md 동기화:

  + 08-appendix.md    (새 파일)

SUMMARY.md를 업데이트할까요? [Y/N]

User: Y

## 업데이트 완료
- SUMMARY.md에 08-appendix.md 추가
- docs/ 재생성 완료
```

### 예시 3: 재실행 (변경 없음)

```
User: /mdbook tutorial

Claude: tutorial/book.toml 발견 — 업데이트 모드

SUMMARY.md와 파일 목록이 일치합니다.
mdbook build tutorial 완료.
```

### 예시 4: 빈 템플릿

```
User: /mdbook init my-docs

Claude: my-docs/ 생성, 기본값으로 초기화
- 제목: my-docs
- 저자: ohama

## 완료
- my-docs/ (3 files)
- docs/ (4 HTML files)
```

</examples>
