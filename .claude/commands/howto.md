---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
description: 개발 지식을 howto 문서로 기록하고 관리
---

<role>
개발 지식 기록 도우미. 작업 중 배운 것, 해결한 문제, 반복 패턴을 `documentation/howto/`에 기록.

**원칙:**
- 3년차 개발자가 따라할 수 있는 수준
- 독립적인 문서 (다른 문서 없이도 이해 가능)
- 실용적 (이론보다 단계와 예시 중심)
</role>

<commands>

## 사용법

| 명령 | 설명 |
|------|------|
| `/howto` | 세션 분석 → TODO에 추가 → 문서 작성 |
| `/howto list` | 문서 목록 + TODO (최신순) |
| `/howto list --oldest` | 작성순 정렬 (오래된 것 먼저) |
| `/howto list --alpha` | 알파벳순 정렬 |
| `/howto next [번호]` | TODO에서 문서 생성 (기본값: 1) |
| `/howto all` | TODO 전체 문서 생성 |
| `/howto rm <번호>` | TODO에서 항목 삭제 |
| `/howto new 제목` | 직접 문서 생성 |
| `/howto 키워드` | 검색/열람 |

**일반적인 워크플로우:**
```
/howto         →  세션 분석 + TODO 추가 + 문서 작성 (원스톱)
/howto list    →  문서 목록 + TODO 확인
/howto next    →  TODO에서 개별 문서화
```

</commands>

<execution>

## 입력 파싱

```
/howto              → scan_and_write (세션 분석 → TODO 추가 → 문서 작성)
/howto list         → list (문서 목록 + TODO, 최신순)
/howto list --oldest → list (작성순 정렬)
/howto list --alpha → list (알파벳순 정렬)
/howto next [숫자]  → next (TODO에서 생성, 기본값: 1)
/howto all          → all (TODO 전체 생성)
/howto rm <숫자>    → remove (TODO에서 삭제)
/howto new 제목     → create (직접 생성)
/howto 키워드       → search 또는 view
```

## Action: scan_and_write (기본 동작)

세션을 분석하여 문서화할 주제를 발견하고 TODO에 추가한 후, 바로 문서를 작성.

**흐름:**
1. scan 실행 → 주제 발견 → TODO에 추가
2. TODO 항목 확인 → 사용자에게 작성 여부 확인
3. 확인되면 all 실행 → TODO 전체 문서 작성

간단히: `/howto` = `/howto scan` + `/howto all` 통합

## Action: list

README.md와 TODO.md를 함께 출력. 기본 정렬은 작성일 역순 (최신 먼저).

**정렬 옵션:**
- `/howto list` — 최신순 (기본)
- `/howto list --oldest` — 작성순 (오래된 것 먼저)
- `/howto list --alpha` — 알파벳순

**구현:**
```bash
# 각 문서의 front matter에서 created 날짜 추출
for file in documentation/howto/*.md; do
  [ "$(basename "$file")" = "README.md" ] && continue
  [ "$(basename "$file")" = "TODO.md" ] && continue
  created=$(grep -m1 "^created:" "$file" 2>/dev/null | cut -d' ' -f2)
  # front matter 없으면 파일 수정 시간 사용
  [ -z "$created" ] && created=$(stat -c %Y "$file" 2>/dev/null | xargs -I{} date -d @{} +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
  echo "$created $file"
done | sort -r  # 최신순 정렬
```

**기존 문서 마이그레이션:** front matter가 없는 문서는 파일 수정 시간을 기준으로 표시. 정확한 작성일을 원하면 문서에 front matter를 추가.

출력:
```markdown
## Howto Documents

| # | 문서 | 설명 | 작성일 |
|---|------|------|--------|
| 1 | [handle-errors-with-result](handle-errors-with-result.md) | Result 에러 핸들링 | 2025-01-20 |
| 2 | [write-fscheck-property-tests](write-fscheck-property-tests.md) | FsCheck 속성 테스트 | 2025-01-18 |
| 3 | [setup-fslexyacc-pipeline](setup-fslexyacc-pipeline.md) | FsLexYacc 빌드 설정 | 2025-01-15 |

총 3개 | 최신순 정렬

## TODO

| # | 제목 | 파일명 |
|---|------|--------|
| 1 | 새로운 주제 | `new-topic.md` |

---
`/howto list --oldest` — 작성순 정렬
`/howto` — 세션 분석 + 문서 작성
`/howto next` — TODO #1 문서 작성
```

## Action: scan (내부용)

세션을 분석하여 문서화할 주제를 발견하고 TODO에 추가.

**Step 1: 분석**
```bash
git log --oneline -20
ls documentation/howto/*.md 2>/dev/null
```

**Step 2: 주제 식별 (품질 기준)**

**문서화 대상 (4가지 조건 중 2개 이상 충족):**

| 기준 | 설명 | 예시 |
|------|------|------|
| **Non-Googleable** | 검색으로 쉽게 안 나오는 것 | ❌ "TypeScript 파일 읽기" → ✅ "이 프로젝트의 ESM path resolution 특이점" |
| **Hard-Won** | 디버깅/삽질 끝에 얻은 통찰 | ❌ "try/catch 사용법" → ✅ "worker.ts:89 Promise.all race condition" |
| **Actionable** | 정확히 무엇을 어디서 하는지 | ❌ "에러 처리하기" → ✅ "tsconfig moduleResolution + package.json type 불일치 해결" |
| **Reusable** | 반복해서 쓸 수 있는 패턴 | ❌ 일회성 버그 수정 → ✅ 설정/구성 패턴 |

**사전 질문 (하나라도 Yes면 SKIP):**
- "5분 내 구글링으로 찾을 수 있나?" → Yes면 문서화 불필요
- "이 프로젝트에서만 의미 있나?" → Yes면 프로젝트 README에 기록
- "특별한 디버깅 없이 알 수 있었나?" → Yes면 문서화 가치 낮음

**제외:**
- 일회성 수정, 라이브러리 기본 사용법
- 이미 문서화된 내용
- 프로젝트 특화 내용 (→ 프로젝트 documentation/로)

**Step 3: TODO에 추가**

```markdown
## 세션 분석 완료

{N}개 주제 발견:

| # | 제목 | 파일명 | 근거 |
|---|------|--------|------|
| 1 | FsCheck 속성 테스트 | `write-fscheck-property-tests.md` | 수학법칙 검증 |
| 2 | Result 에러 핸들링 | `handle-errors-with-result.md` | match 체이닝 |

→ TODO.md에 추가됨

---
`/howto list` — 전체 목록 확인
`/howto next` — 문서 작성
`/howto all` — 전체 문서 작성
```

## Action: next

`/howto next [번호]`로 TODO 항목 문서 생성. 번호 생략 시 1번 진행.

```markdown
## /howto next

TODO #1: FsCheck 속성 테스트

대화에서 추출한 내용:
- testProperty 사용법
- FsCheck ==> 연산자
- 수학법칙 검증

대화 기반으로 작성할까요?
1. 예
2. 아니오, 직접 설명
```

생성 후:
- `documentation/howto/파일명.md` 생성
- `documentation/howto/README.md` 업데이트
- `documentation/howto/TODO.md`에서 항목 제거

## Action: all

`/howto all`로 TODO 전체 문서 생성.

TODO의 모든 항목을 순서대로 문서화:
1. TODO #1 → 문서 생성
2. TODO #2 → 문서 생성
3. ... 반복

각 문서 생성 시 대화 내용 기반으로 자동 작성.

## Action: remove

`/howto rm <번호>`로 TODO 항목 삭제.

1. TODO.md에서 해당 번호 항목 제거
2. 번호 재정렬
3. 결과 출력

```markdown
TODO #1 삭제됨: FsCheck 속성 테스트

남은 TODO: 1개
```

## Action: create

`/howto new 제목`으로 직접 생성.

1. 제목 → kebab-case 파일명
2. 대화에서 내용 추출 또는 질문
3. 템플릿 적용하여 작성
4. README 업데이트, TODO에서 제거

## Action: search / view

키워드가 파일명과 일치하면 view, 아니면 search.

```bash
# 검색
ls documentation/howto/*키워드*.md
grep -l "키워드" documentation/howto/*.md
```

</execution>

<template>

## 문서 템플릿

```markdown
---
created: {YYYY-MM-DD}
description: {한 줄 설명}
---

# {제목}

{한 줄 설명 - 원리 중심}

## The Insight

{무엇을 깨달았나? 코드가 아니라 멘탈 모델}

예: "Async I/O 작업은 독립적으로 실패한다. 클라이언트 생명주기 ≠ 서버 생명주기."

## Why This Matters

{모르면 뭐가 잘못되나? 어떤 증상으로 여기까지 왔나?}

예: "프록시 서버가 클라이언트 연결 끊김에 크래시, 다른 요청도 영향받음."

## Recognition Pattern

{이 지식이 필요한 상황을 어떻게 알아채나?}

예: "장기 연결 핸들러(프록시, 웹소켓, SSE) 구축 시"

## The Approach

{어떻게 생각하고 접근하나? 단순 코드가 아니라 휴리스틱}

예: "각 I/O 작업마다 '지금 실패하면?'을 물어라. 로컬에서 처리하라."

### Step 1: {단계}

{설명}

```bash
{명령어}
```

### Step 2: {단계}

{설명}

## Example

{원리를 설명하는 코드 - 복붙용이 아니라 이해용}

```typescript
// ❌ BAD: 전체를 하나의 try로
try {
  await connect();
  await send();
  await receive();
} catch (e) { ... }

// ✅ GOOD: 각 I/O를 독립 처리
try { await connect(); } catch (e) { handleConnectError(e); }
try { await send(); } catch (e) { handleSendError(e); }
try { await receive(); } catch (e) { handleReceiveError(e); }
```

## 체크리스트

- [ ] {확인 항목}

## 관련 문서

- `{파일명}.md` - {설명}
```

</template>

<file_management>

## 파일 구조

```
documentation/howto/
├── README.md      # 문서 목록
├── TODO.md        # 대기 주제 목록
├── setup-*.md     # 설정 문서들
├── write-*.md     # 작성법 문서들
└── handle-*.md    # 처리 방법 문서들
```

## README.md

```markdown
# Howto Documents

| # | 문서 | 설명 | 작성일 |
|---|------|------|--------|
| 1 | [setup-fslexyacc-pipeline](setup-fslexyacc-pipeline.md) | 설명 | 2025-01-15 |

---
총 N개 | 업데이트: YYYY-MM-DD
```

**README.md 업데이트 시:** 각 문서의 front matter에서 `created`와 `description`을 읽어 테이블 생성. 기본 정렬은 작성일 역순.

## TODO.md

```markdown
# Howto TODO

| # | 제목 | 파일명 | 근거 |
|---|------|--------|------|
| 1 | 주제 | `파일명.md` | 근거 |

---
총 N개 대기 | 업데이트: YYYY-MM-DD
```

</file_management>

<writing_guidelines>

## 작성 가이드

**대상:** 3년차 개발자 (기본 개념 설명 불필요)

**핵심 원칙: Insight → Approach → Example**

좋은 howto는 코드 복붙이 아니라 **사고방식**을 전달:
```
❌ BAD: "ConnectionResetError 나면 이 try/except 추가"
✅ GOOD: "async I/O는 독립적으로 실패한다. 각 I/O 작업을 개별 처리해야 하는 이유와 방법"
```

**문서가 답해야 할 질문:**
1. **The Insight**: 무엇을 깨달았나? (코드가 아니라 원리)
2. **Why This Matters**: 모르면 뭐가 잘못되나?
3. **Recognition Pattern**: 이 지식이 필요한 상황을 어떻게 알아채나?
4. **The Approach**: 어떻게 생각하고 접근하나?

**문체:**
- 명령형: "~한다", "~을 실행한다"
- 간결하게, 코드는 코드 블록으로

**구조:**
- 독립적 (다른 문서 참조 최소화)
- 단계별 (Step 1, 2, 3...)
- 복사-붙여넣기 가능

**분량:**
- 한 문서 = 한 주제
- 5-10분 내 따라할 수 있는 분량

**파일명:**
- kebab-case: `setup-expecto-test.md`
- 동사 시작: `setup-`, `write-`, `handle-`, `debug-`

</writing_guidelines>

<examples>

## 예시

### 세션 분석 + 문서 작성 (기본)
```
/howto
→ 세션 분석 → TODO 추가 → 문서 작성 (원스톱)
```

### 목록 보기 (최신순)
```
/howto list
→ 문서 목록 (최신순) + TODO 표시
```

### 작성순 정렬
```
/howto list --oldest
→ 문서 목록 (오래된 것부터) + TODO 표시
```

### 알파벳순 정렬
```
/howto list --alpha
→ 문서 목록 (알파벳순) + TODO 표시
```

### TODO에서 생성
```
/howto next
→ TODO #1 문서 생성

/howto next 2
→ TODO #2 문서 생성
```

### TODO 전체 생성
```
/howto all
→ TODO 전체 문서 생성
```

### TODO 삭제
```
/howto rm 1
→ TODO #1 삭제
```

### 직접 생성
```
/howto new FsCheck 속성 테스트
→ 해당 제목으로 문서 생성
```

### 검색
```
/howto fscheck
→ 키워드로 검색
```

### 열람
```
/howto setup-expecto-test-project
→ 해당 문서 표시
```

</examples>
