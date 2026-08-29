# GSD 빠른 시작 가이드

## 설치

GSD가 이미 `.claude/` 디렉토리에 설치되어 있습니다.

업데이트가 필요한 경우:

```bash
npx get-shit-done-cc@latest
```

## 새 프로젝트 시작하기

### 1단계: 프로젝트 초기화

```
/gsd:new-project
```

이 명령은 다음 과정을 진행합니다:

1. **심층 질문**: 무엇을 만들려는지 이해
2. **도메인 리서치** (선택): 4개의 병렬 리서처 에이전트 실행
3. **요구사항 정의**: v1/v2/범위 외 구분
4. **로드맵 생성**: 페이즈 분할 및 성공 기준 정의

생성되는 파일:
```
.planning/
├── PROJECT.md       # 프로젝트 비전
├── REQUIREMENTS.md  # 요구사항
├── ROADMAP.md       # 로드맵
├── STATE.md         # 상태 추적
└── config.json      # 설정
```

### 2단계: 첫 번째 페이즈 계획

```
/gsd:plan-phase 1
```

페이즈 1에 대한 상세 실행 계획을 생성합니다.

생성되는 파일:
```
.planning/phases/01-foundation/
└── 01-01-PLAN.md
```

### 3단계: 페이즈 실행

```
/gsd:execute-phase 1
```

계획된 태스크를 실행합니다:
- 웨이브 기반 병렬 실행
- 각 태스크별 원자적 커밋
- 자동 검증

### 4단계: 진행 상황 확인

```
/gsd:progress
```

현재 위치와 다음 단계를 확인합니다.

### 5단계: 다음 페이즈 진행

```
/clear
/gsd:plan-phase 2
/gsd:execute-phase 2
```

> **팁**: 각 페이즈 사이에 `/clear`를 사용하여 컨텍스트를 정리하세요.

## 기존 프로젝트에 GSD 적용

### 1단계: 코드베이스 분석

```
/gsd:map-codebase
```

기존 코드베이스를 분석하여 `.planning/codebase/`에 문서화합니다.

### 2단계: 새 마일스톤 시작

```
/gsd:new-project
```

또는 이미 PROJECT.md가 있다면:

```
/gsd:new-milestone "v2.0 Features"
```

## 작업 재개하기

이전 세션에서 작업을 이어가려면:

```
/gsd:resume-work
```

또는:

```
/gsd:progress
```

## 빠른 작업 (Quick Mode)

계획 없이 작은 작업을 빠르게 처리:

```
/gsd:quick
```

- 리서치, 검증 에이전트 생략
- `.planning/quick/`에 저장
- STATE.md만 업데이트

## 디버깅

문제 발생 시:

```
/gsd:debug "버튼 클릭이 작동하지 않음"
```

세션 간 상태가 유지됩니다. 다시 시작하려면:

```
/gsd:debug
```

## 워크플로우 모드

### Interactive 모드 (기본값)
- 주요 결정마다 확인
- 체크포인트에서 일시 정지
- 더 많은 안내 제공

### YOLO 모드
- 대부분의 결정 자동 승인
- 확인 없이 계획 실행
- 중요 체크포인트에서만 정지

설정에서 변경:

```
/gsd:settings
```

또는 `.planning/config.json` 직접 편집

## 다음 단계

- [명령어 레퍼런스](./commands.md) - 전체 명령어 목록
- [워크플로우](./workflows.md) - 상세 워크플로우 가이드
- [설정](./configuration.md) - 모델 프로파일 및 옵션
