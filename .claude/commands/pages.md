---
allowed-tools: Read, Write, Edit, Bash, Glob, AskUserQuestion
description: mdBook 프로젝트 설정 및 GitHub Pages 배포 준비 (CI 자동 빌드)
---

<role>
mdBook 문서 사이트 설정 도우미. 지정 디렉토리를 mdBook 프로젝트로 구성하고 (book.toml, SUMMARY.md 추가), GitHub Actions 워크플로우를 생성하여 CI에서 자동 빌드한다.

핵심 원칙: **소스 디렉토리 = mdBook 프로젝트.** 별도 book/ 디렉토리를 만들지 않고, 사용자의 .md 파일이 있는 디렉토리에서 직접 작업한다. 파일 복사 없음.

**로컬 빌드/미리보기는 `/mdbook` 커맨드를 사용한다.**
</role>

<skills_reference>
이 커맨드는 `mdbook-utils` 스킬을 사용한다:
- mdbook 설치 확인
- book.toml 탐지
- SUMMARY.md 동기화
- README.md Documentation 섹션 업데이트
</skills_reference>

<commands>

## 사용법

| 명령 | 설명 |
|------|------|
| `/pages <dir>` | 단일 디렉토리를 mdBook으로 구성 + CI 설정 |
| `/pages <dir1> <dir2> ...` | 다중 디렉토리를 하나의 mdBook으로 통합 + CI 설정 |
| `/pages` | 대화형 설정 시작 (디렉토리 질문 포함) |
| `/pages init <dir>` | 기본값으로 빠른 초기화 (빈 템플릿) |

**빌드/미리보기는 `/mdbook` 커맨드 사용:**
- `/mdbook build [dir]` — 로컬 빌드
- `/mdbook serve [dir]` — 로컬 개발 서버
- `/mdbook sync [dir]` — SUMMARY.md 동기화

</commands>

<architecture>

## 단일 디렉토리 모드

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
```

### book.toml 핵심 설정

```toml
[book]
src = "."       # ← 별도 src/ 없이 디렉토리 자체를 소스로
```

---

## 다중 디렉토리 모드

`/pages tutorial youtube` 처럼 2개 이상의 디렉토리를 지정하면, **프로젝트 루트에 통합 mdBook**을 생성한다.

### 최초 설정 전 (사용자의 원본)

```
repo/
├─ tutorial/
│  ├─ 01-overview.md
│  └─ 02-settings.md
└─ youtube/
   ├─ ep01.md
   └─ ep02.md
```

### 최초 설정 후 (프로젝트 루트에 mdBook 파일 추가)

```
repo/
├─ book.toml              ← 프로젝트 루트에 추가 (src = ".")
├─ SUMMARY.md             ← 모든 디렉토리를 섹션으로 참조
├─ introduction.md        ← 랜딩 페이지
├─ tutorial/
│  ├─ 01-overview.md      ← 원본 그대로
│  └─ 02-settings.md
└─ youtube/
   ├─ ep01.md             ← 원본 그대로
   └─ ep02.md
```

### SUMMARY.md 구조 (다중 디렉토리)

각 디렉토리가 섹션(`#`)이 되고, 하위 .md 파일이 챕터(`-`)가 된다:

```markdown
# Summary

[소개](introduction.md)

# Tutorial

- [Overview](tutorial/01-overview.md)
- [Settings](tutorial/02-settings.md)

# YouTube

- [Episode 01](youtube/ep01.md)
- [Episode 02](youtube/ep02.md)
```

### book.toml 핵심 설정 (다중 디렉토리)

```toml
[book]
src = "."       # 프로젝트 루트 전체를 소스로

[build]
build-dir = "docs"   # 루트 기준이므로 상대경로 없음
```

---

## 공통 장점

- **파일 복사 없음** — 원본이 곧 mdBook 소스
- **수정 즉시 반영** — 파일 편집 → CI 빌드 → 끝
- **동기화 불필요** — 파일이 한 벌이므로 상태 추적 최소화

</architecture>

<execution>

## Step 1: mdbook 설치 확인

`mdbook-utils` 스킬의 "1. mdbook 설치 확인" 참조.

## Step 2: 모드 결정 (단일 vs 다중 디렉토리)

### 인자 파싱

```
/pages tutorial           → 단일 모드: DIRS = ["tutorial"]
/pages tutorial youtube   → 다중 모드: DIRS = ["tutorial", "youtube"]
/pages                    → 대화형: AskUserQuestion으로 디렉토리 질문
```

**다중 디렉토리 모드 조건:** 인자가 2개 이상이고, 모두 존재하는 디렉토리

### 디렉토리 존재 확인

```bash
for dir in {DIRS}; do
  [ -d "$dir" ] || echo "NOT_FOUND: $dir"
done
```

없는 디렉토리가 있으면 오류 출력 후 중단.

### 기존 설정 확인

`mdbook-utils` 스킬의 "2. book.toml 탐지" 참조.

**book.toml이 있는 경우 → 업데이트 모드 (Step 6으로 이동)**

**book.toml이 없는 경우 → 최초 설정 (Step 3부터 계속)**

## Step 3: 소스 파일 스캔

**단일 모드:**
```bash
ls {DIR}/*.md 2>/dev/null
```

**다중 모드:**
```bash
for dir in {DIRS}; do
  echo "=== $dir ==="
  ls "$dir"/*.md 2>/dev/null
done
```

- 각 디렉토리별 .md 파일 목록 표시
- .md 파일이 없는 디렉토리가 있으면 경고

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

### 단일 모드

`{DIR}/` 안에 3개 파일을 생성한다.

#### book.toml (단일 모드)

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

#### SUMMARY.md (단일 모드)

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

#### introduction.md (단일 모드)

```markdown
# {TITLE}

{DESCRIPTION}

## 시작하기

[Chapter 1]({FIRST_CHAPTER_FILE})부터 시작하세요.
```

---

### 다중 모드

**프로젝트 루트**에 3개 파일을 생성한다.

#### book.toml (다중 모드)

```toml
[book]
title = "{TITLE}"
authors = ["{AUTHOR}"]
language = "{LANG}"
description = "{DESCRIPTION}"
src = "."

[build]
build-dir = "docs"
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
edit-url-template = "{REPO_URL}/edit/master/{path}"
```

#### SUMMARY.md (다중 모드)

각 디렉토리가 섹션(`#`)이 되고, 하위 .md 파일이 챕터가 된다:

```markdown
# Summary

[소개](introduction.md)

# {DIR1_TITLE}

- [{CHAPTER1_TITLE}]({DIR1}/01-file.md)
- [{CHAPTER2_TITLE}]({DIR1}/02-file.md)

# {DIR2_TITLE}

- [{CHAPTER1_TITLE}]({DIR2}/ep01.md)
- [{CHAPTER2_TITLE}]({DIR2}/ep02.md)
```

**섹션 제목 결정:**
1. 디렉토리 내 첫 번째 .md 파일의 `#` 헤더에서 추출 시도
2. 없으면 디렉토리명을 Title Case로 변환 (예: `youtube` → `YouTube`)

**챕터 제목 결정:**
- 각 .md 파일의 첫 번째 `#` 헤더를 제목으로 추출
- 없으면 파일명 사용

#### introduction.md (다중 모드)

```markdown
# {TITLE}

{DESCRIPTION}

## 목차

- [{DIR1_TITLE}]({DIR1}/01-file.md)
- [{DIR2_TITLE}]({DIR2}/ep01.md)
```

## Step 6: SUMMARY.md 동기화 (업데이트 모드)

book.toml이 이미 있어서 Step 2에서 여기로 온 경우.

`mdbook-utils` 스킬의 "3. SUMMARY.md 동기화" 참조.

**단일 모드:**
```
SUMMARY.md 동기화:

  + 08-appendix.md    (새 파일 - SUMMARY에 없음)
  - old-chapter.md    (SUMMARY에 있지만 파일 없음)

SUMMARY.md를 업데이트할까요? [Y/N]
```

**다중 모드:**
```
SUMMARY.md 동기화:

tutorial/:
  + 08-appendix.md    (새 파일)

youtube/:
  + ep03.md           (새 파일)
  - old-ep.md         (파일 없음)

SUMMARY.md를 업데이트할까요? [Y/N]
```

Y 선택 시 SUMMARY.md 업데이트. N 선택 또는 차이 없으면 건너뛰기.

## Step 7: GitHub Actions 워크플로우 생성 (최초 설정 시만)

Step 2에서 book.toml이 없어 최초 설정으로 진행한 경우에만 실행.
업데이트 모드에서는 건너뛴다.

### GitHub Actions 워크플로우 (단일 모드)

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

      - name: Create .nojekyll
        run: touch docs/.nojekyll

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

### GitHub Actions 워크플로우 (다중 모드)

다중 모드에서는 모든 소스 디렉토리와 루트 mdBook 파일을 감시한다:

```yaml
# .github/workflows/mdbook.yml
name: Build mdBook

on:
  push:
    branches:
      - master
      - main
    paths:
      - 'book.toml'
      - 'SUMMARY.md'
      - 'introduction.md'
      - '{DIR1}/**'
      - '{DIR2}/**'
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
          mdbook clean .
          mdbook build .

      - name: Create .nojekyll
        run: touch docs/.nojekyll

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

## Step 8: README.md에 Book 링크 추가/업데이트

프로젝트 루트에 `README.md`가 있으면 GitHub Pages 링크를 추가하거나 업데이트한다.

```bash
[ -f "README.md" ] && echo "README_EXISTS"
```

**README.md가 있는 경우:**

1. GitHub repo URL에서 Pages URL을 유도한다:
   - `https://github.com/{user}/{repo}` → `https://{user}.github.io/{repo}/`

2. `## Documentation` 섹션이 있는지 확인한다:
   ```bash
   grep -q "^## Documentation" README.md
   ```

3. **섹션이 있는 경우 → 업데이트:**
   - `## Documentation` 다음 줄부터 다음 `##` 전까지의 내용을 새 링크로 교체
   ```markdown
   ## Documentation

   [{TITLE}]({PAGES_URL})
   ```

4. **섹션이 없는 경우 → 추가:**
   - README.md의 **첫 번째 `#` 헤딩(제목) 바로 다음**에 Documentation 섹션을 삽입
   - `#` 제목이 없으면 파일 맨 앞에 추가
   ```markdown
   # Project Title

   ## Documentation

   [{TITLE}]({PAGES_URL})

   ## Other Sections...
   ```

5. GitHub repo URL이 없는 경우 (Step 4에서 미입력):
   - 이 단계를 건너뛴다

**README.md가 없는 경우:** 건너뛴다.

## Step 9: 결과 출력

### 최초 설정

```markdown
## mdBook 설정 완료

### {DIR}/ 에 추가된 파일
- book.toml - mdBook 설정 (src = ".")
- SUMMARY.md - 목차
- introduction.md - 소개 페이지

### CI 설정
- .github/workflows/mdbook.yml - push 시 자동 빌드

### 다음 단계
1. `/mdbook serve {DIR}` 으로 로컬 미리보기
2. `git push` 후 CI가 docs/ 자동 생성
3. GitHub Settings > Pages > Branch: master, Folder: /docs
```

### 업데이트 (SUMMARY 동기화)

```markdown
## mdBook 업데이트 완료

### SUMMARY.md 변경
- + 08-appendix.md 추가됨
- - old-chapter.md 제거됨

git push 후 CI가 docs/ 재생성.
```

### 업데이트 (변경 없음)

```
SUMMARY.md와 파일 목록이 일치합니다.
변경사항 없음.
```

</execution>

<examples>

### 예시 1: 최초 설정

```
User: /pages tutorial

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
- .github/workflows/mdbook.yml 생성

다음 단계:
1. `/mdbook serve tutorial` 으로 로컬 미리보기
2. git push 후 CI가 docs/ 자동 생성
```

### 예시 2: 재실행 (새 파일 추가됨)

```
User: /pages tutorial

Claude: tutorial/book.toml 발견 — 업데이트 모드

SUMMARY.md 동기화:

  + 08-appendix.md    (새 파일)

SUMMARY.md를 업데이트할까요? [Y/N]

User: Y

## 업데이트 완료
- SUMMARY.md에 08-appendix.md 추가
git push 후 CI가 docs/ 재생성.
```

### 예시 3: 재실행 (변경 없음)

```
User: /pages tutorial

Claude: tutorial/book.toml 발견 — 업데이트 모드

SUMMARY.md와 파일 목록이 일치합니다.
변경사항 없음.
```

### 예시 4: 빈 템플릿

```
User: /pages init my-docs

Claude: my-docs/ 생성, 기본값으로 초기화
- 제목: my-docs
- 저자: ohama

## 완료
- my-docs/ (3 files)
- .github/workflows/mdbook.yml 생성
```

---

### 예시 5: 다중 디렉토리 최초 설정

```
User: /pages tutorial youtube

Claude: 다중 디렉토리 모드 감지

=== tutorial ===
- 01-overview.md
- 02-settings.md

=== youtube ===
- ep01.md
- ep02.md

[프로젝트 정보 질문 → 답변]

프로젝트 루트에 추가:
- book.toml (src = ".")
- SUMMARY.md (2 sections, 4 chapters)
- introduction.md

## 완료
- .github/workflows/mdbook.yml 생성

`/mdbook serve .` 으로 로컬 미리보기하세요.
```

### 예시 6: 다중 디렉토리 업데이트

```
User: /pages tutorial youtube

Claude: book.toml 발견 — 다중 디렉토리 업데이트 모드

SUMMARY.md 동기화:

tutorial/:
  (변경 없음)

youtube/:
  + ep03.md    (새 파일)

SUMMARY.md를 업데이트할까요? [Y/N]

User: Y

## 업데이트 완료
- SUMMARY.md에 youtube/ep03.md 추가
git push 후 CI가 docs/ 재생성.
```

</examples>
