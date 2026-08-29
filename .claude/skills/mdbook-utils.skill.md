---
name: mdbook-utils
description: mdBook 공통 유틸리티 (설치 확인, book.toml 탐지, SUMMARY 동기화)
---

## 사용 커맨드

- `/pages` — mdBook 설정 및 CI 구성
- `/mdbook` — 로컬 빌드/서브/클린/싱크

---

## 1. mdbook 설치 확인

```bash
which mdbook || echo "NOT_INSTALLED"
```

**설치 안 됨 → 안내:**
```
mdbook이 설치되어 있지 않습니다.

설치 방법:
  cargo install mdbook
  # 또는
  brew install mdbook  # macOS
  # 또는
  sudo apt install mdbook  # Ubuntu
```

---

## 2. book.toml 탐지

### 인자가 있는 경우

```bash
[ -f "{DIR}/book.toml" ] && echo "FOUND"
```

### 인자가 없는 경우

1. 프로젝트 루트 확인:
```bash
[ -f "book.toml" ] && echo "FOUND_ROOT"
```

2. 하위 디렉토리 탐색:
```bash
find . -maxdepth 2 -name "book.toml" -type f 2>/dev/null | head -1
```

### 다중 디렉토리 모드 판별

인자가 2개 이상이고 모두 디렉토리로 존재하면 다중 모드:
- 단일 모드: `{DIR}/book.toml`
- 다중 모드: 프로젝트 루트 `book.toml`

---

## 3. SUMMARY.md 동기화

### 파일 목록 비교

1. SUMMARY.md에서 링크된 .md 파일 추출:
```bash
grep -oE '\([^)]+\.md\)' SUMMARY.md | tr -d '()'
```

2. 디렉토리의 실제 .md 파일 목록과 비교

3. 비교 제외 대상:
   - SUMMARY.md
   - introduction.md
   - book.toml
   - README.md

### 차이 표시

```
SUMMARY.md 동기화:

  + new-chapter.md      (새 파일)
  - old-chapter.md      (파일 없음)
```

### 업데이트 로직

- 새 파일: 적절한 섹션에 추가 (파일의 첫 `#` 헤더를 제목으로)
- 삭제된 파일: SUMMARY.md에서 해당 항목 제거
- 기존 섹션 구조(`#` 헤더)는 유지

---

## 4. 빌드 명령

### 단일 모드

```bash
mdbook clean {DIR}
mdbook build {DIR}
```

### 다중 모드

```bash
mdbook clean .
mdbook build .
```

**참고:** `mdbook clean`은 삭제된 챕터의 잔여 HTML이 남지 않도록 한다.

---

## 5. .nojekyll 확인

GitHub Pages에서 Jekyll 처리를 건너뛰기 위해 필요:

```bash
[ -f "docs/.nojekyll" ] || touch docs/.nojekyll
```

---

## 6. README.md Documentation 섹션 업데이트

### 확인

```bash
[ -f "README.md" ] && echo "README_EXISTS"
grep -q "^## Documentation" README.md && echo "SECTION_EXISTS"
```

### 섹션이 있는 경우 → 업데이트

`## Documentation` 다음 줄부터 다음 `##` 전까지의 내용을 새 링크로 교체:

```markdown
## Documentation

[{TITLE}]({LINK})
```

**링크 형식:**
- `/pages`: `https://{user}.github.io/{repo}/` (GitHub Pages URL)
- `/mdbook`: `docs/index.html` (로컬 경로)

### 섹션이 없는 경우 → 추가

README.md의 **첫 번째 `#` 헤딩(제목) 바로 다음**에 삽입:

```markdown
# Project Title

## Documentation

[{TITLE}]({LINK})

## Other Sections...
```

- `#` 제목이 없으면 파일 맨 앞에 추가
