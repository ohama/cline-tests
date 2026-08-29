---
name: markdown-image-insertion
description: Markdown 문서 내 이미지 삽입 규칙 (경로, 캡션, HTML 제한 등)을 강제하는 스킬
trigger: Markdown 문서를 생성·편집할 때 자동 적용
consumers:
  - 문서 작성 작업
  - mdbook-docs-images skill
---

# Markdown + Image Insertion Rules

Markdown 문서를 생성할 때 이 문서를 **절대 규칙(spec)** 으로 사용한다.

## 목적

- Markdown 문서 내 이미지 삽입을 일관되게 유지
- GitHub / GitHub Pages / mdBook 호환성 보장
- 사람이 나중에 이미지를 추가·교체해도 문서 구조 유지
- 임의 판단(HTML 남용, 절대경로 사용 등) 방지

## 적용 범위

다음 작업에 **항상 적용**된다.

- 문서 작성
- 튜토리얼, 설계 문서
- 아키텍처 설명
- 알고리즘 해설
- 강의 노트

## 1. 기본 원칙 (Must Rules)

1. 이미지 삽입은 **Markdown 표준 문법만 사용**
2. 이미지 경로는 **상대경로만 사용**
3. 모든 이미지는 `images/` 디렉토리 하위에 위치한다고 가정
4. 실제 이미지 파일은 생성하지 않음
5. 모든 이미지에는 **의미 있는 alt text** 포함
6. mdBook / GitHub Pages / GitHub Markdown 에서 동일하게 렌더링되어야 함

## 2. 허용되는 이미지 문법

### 2.1 기본 이미지 문법

```md
![대체 텍스트](images/파일명.png)
```

예시:

```md
![컴파일 파이프라인 전체 흐름](images/compiler-pipeline.png)
```

### 2.2 캡션 포함 이미지

```md
![타입 추론 흐름](images/type-inference.png)

*그림 3. Algorithm W 기반 타입 추론 흐름*
```

- 캡션은 이미지 바로 아래 줄
- 기울임꼴 사용

## 3. 디렉토리 구조 규약

항상 다음 구조를 전제로 문서를 작성한다.

```
docs/
 ├─ chapter1.md
 ├─ chapter2.md
 └─ images/
     ├─ overview.png
     ├─ pipeline.svg
     └─ type-system.png
```

### 경로 허용 / 금지

| 구분 | 허용 | 금지 |
|----|----|----|
| 상대경로 | images/a.png | /images/a.png |
| 로컬경로 | - | C:\img\a.png |
| URL | - | https://example.com/a.png |

## 4. HTML 사용 규칙

### 기본 방침

- HTML 사용 **금지**
- **자발적으로 HTML을 사용하지 않는다**

### 예외 (사람이 명시적으로 요청한 경우만 허용)

- 이미지 크기 조절
- 중앙 정렬

허용 예:

```html
<p align="center">
  <img src="images/architecture.png" width="600"/>
</p>
```

## 5. 이미지 설계 주석 규칙 (Image Spec Comment)

실제 이미지를 생성하지 않는 대신, 이미지 설계 정보를 **HTML 주석으로 남긴다.**

```md
![클로저 환경 캡처 구조](images/closure-env.png)

<!--
목적: 클로저 환경 캡처 구조 설명
포함 요소:
- Function pointer
- Environment record
- Free variables
도형:
- 박스 + 화살표
추천 도구:
- draw.io
- Excalidraw
-->
```

주석은 렌더링되지 않으며, 사람이 그림을 그릴 때 명세로 사용된다.

## 6. 파일명 규칙

- 소문자 사용
- 공백 대신 하이픈(`-`)
- 의미 중심 이름

| 주제 | 파일명 |
|----|----|
| 컴파일 파이프라인 | compiler-pipeline.png |
| 타입 시스템 | type-system-overview.svg |
| AST 구조 | ast-structure.png |

## 7. 섹션별 이미지 삽입 기준

| 섹션 유형 | 이미지 |
|----|----|
| 개요 / 아키텍처 | 필수 |
| 알고리즘 설명 | 권장 |
| 코드 예제 | 선택 |
| API 레퍼런스 | 선택 |

## 8. 자체 검증 체크리스트

출력 전 다음을 검증한다.

- [ ] 모든 이미지가 images/ 상대경로인가?
- [ ] alt text 가 의미를 설명하는가?
- [ ] HTML 남용이 없는가?
- [ ] 실제 이미지 데이터를 생성하지 않았는가?
- [ ] mdBook / GitHub Pages 호환성을 유지하는가?
