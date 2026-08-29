---
name: mdbook-docs-images
description: mdBook 문서 작성 시 이미지·구조·렌더링 규칙을 강제하는 스킬
trigger: mdBook 기반 문서를 생성·편집할 때 자동 적용
consumers:
  - mdbook command
  - 문서 작성 작업
---

# mdBook 문서 · 그림 규칙

mdBook 기반 문서를 생성할 때 이 문서를 **절대 규칙(spec)** 으로 따른다.

## 목적

- mdBook에서 깨지지 않는 문서 구조 유지
- GitHub Pages 배포 시 동일한 렌더링 보장
- 장(chapter) 단위 문서 일관성 확보
- 그림, 링크, 코드 블록의 표준화

## 적용 범위

- mdBook 프로젝트의 모든 `.md` 파일
- `SUMMARY.md`
- 튜토리얼 / 강의 노트 / 기술 문서
- 아키텍처 및 알고리즘 설명 문서

## 1. mdBook 기본 구조 규칙

항상 다음 구조를 전제로 문서를 작성한다.

```
book/
 ├─ src/
 │   ├─ SUMMARY.md
 │   ├─ introduction.md
 │   ├─ chapter_01.md
 │   ├─ chapter_02.md
 │   └─ images/
 │       ├─ overview.png
 │       ├─ pipeline.svg
 │       └─ ast.png
 └─ book.toml
```

## 2. SUMMARY.md 작성 규칙

### 기본 원칙

- 모든 문서는 `SUMMARY.md`에 등록되어야 한다
- 파일 경로는 `src/` 기준 상대경로
- 제목은 짧고 명확하게 작성

### 예시

```md
# Summary

- [소개](introduction.md)
- [언어 개요](chapter_01.md)
  - [표현식](chapter_01.md#표현식)
  - [타입 시스템](chapter_01.md#타입-시스템)
- [컴파일 파이프라인](chapter_02.md)
```

## 3. mdBook 문서 작성 규칙

### 3.1 헤더 규칙

- 문서 제목은 `#` 하나만 사용
- 장 내부 섹션은 `##`, `###` 순서 유지
- 헤더 레벨 건너뛰기 금지

### 3.2 링크 규칙

- 내부 링크는 **상대경로**
- 확장자 `.md` 포함

```md
[타입 시스템](chapter_01.md#타입-시스템)
```

## 4. mdBook 전용 이미지 규칙

### 4.1 이미지 경로

- 모든 이미지는 `src/images/` 하위
- 문서에서는 `images/...` 상대경로 사용

```md
![컴파일 파이프라인](images/compiler-pipeline.png)
```

### 4.2 이미지 캡션 규칙

```md
![AST 구조](images/ast.png)

*그림 2. 추상 구문 트리 구조*
```

- 이미지 바로 아래 줄에 캡션
- 기울임꼴 사용

### 4.3 HTML 사용 제한

- `<img>` 태그 기본 금지
- mdBook 플러그인에 의존하는 문법 금지
- HTML 사용은 **명시적 요청 시만 허용**

## 5. 이미지 설계 주석 (mdBook 호환)

```md
![타입 추론 흐름](images/type-inference.png)

<!--
목적: mdBook 독자를 위한 타입 추론 개념 시각화
포함 요소:
- Expr AST
- Type Environment
- Unification
- Result Type
도형:
- 좌 → 우 흐름
-->
```

- HTML 주석은 mdBook에서 렌더링되지 않음
- 그림 설계 명세로 활용

## 6. 코드 블록 규칙

- 언어 명시 필수
- mdBook 하이라이트 호환 언어 사용

```md
```fsharp
let add x y = x + y
```
```

## 7. 경고 / 주의 박스 규칙

> mdBook 기본 Markdown만 사용한다
> 확장 문법(admonition)은 사용하지 않는다

## 8. 그림 삽입 기준

| 문서 위치 | 이미지 |
|---------|--------|
| 장 서두 | 필수 |
| 개념 설명 | 권장 |
| 코드 나열 | 선택 |
| API 설명 | 선택 |

## 9. 자체 검증 체크리스트

출력 전 반드시 확인한다.

- [ ] 모든 문서가 SUMMARY.md에 포함되어 있는가?
- [ ] 이미지 경로가 images/ 상대경로인가?
- [ ] HTML / 확장 Markdown을 사용하지 않았는가?
- [ ] mdBook 기본 렌더러에서 동작하는가?
