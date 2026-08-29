# GSD 설정

## 설정 파일

GSD 설정은 두 곳에 저장됩니다:

1. **`.claude/settings.json`** - Claude Code 통합 설정
2. **`.planning/config.json`** - 프로젝트별 GSD 설정

---

## `.claude/settings.json`

Claude Code와의 통합을 설정합니다:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/hooks/gsd-check-update.js"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "node .claude/hooks/gsd-statusline.js"
  }
}
```

### hooks

**SessionStart**: 세션 시작 시 실행되는 훅
- `gsd-check-update.js`: 새 버전 확인

### statusLine

상태 표시줄에 GSD 정보 표시:
- 현재 페이즈
- 진행률
- 프로젝트 상태

---

## `.planning/config.json`

프로젝트별 GSD 워크플로우 설정:

```json
{
  "mode": "interactive",
  "model_profile": "balanced",
  "gates": {
    "researcher": true,
    "plan_checker": true,
    "verifier": true
  },
  "planning": {
    "commit_docs": true,
    "search_gitignored": false
  }
}
```

---

## 설정 옵션

### mode

워크플로우 모드를 설정합니다.

| 값 | 설명 |
|----|------|
| `interactive` | 주요 결정마다 확인 (기본값) |
| `yolo` | 대부분 자동 진행 |

**Interactive 모드:**
- 체크포인트에서 일시 정지
- 계획 승인 요청
- 더 많은 안내

**YOLO 모드:**
- 자동 승인
- 중요 체크포인트에서만 정지
- 빠른 진행

---

### model_profile

에이전트가 사용할 모델을 결정합니다.

| 프로파일 | 설명 | 사용 시점 |
|----------|------|----------|
| `quality` | 모든 곳에 Opus | 쿼터 여유, 중요 작업 |
| `balanced` | 계획에 Opus, 실행에 Sonnet | 일반 개발 (기본값) |
| `budget` | 작성에 Sonnet, 리서치에 Haiku | 쿼터 절약, 대량 작업 |

**프로파일별 모델 할당:**

| 에이전트 | quality | balanced | budget |
|----------|---------|----------|--------|
| gsd-planner | opus | opus | sonnet |
| gsd-roadmapper | opus | sonnet | sonnet |
| gsd-executor | opus | sonnet | sonnet |
| gsd-phase-researcher | opus | sonnet | haiku |
| gsd-project-researcher | opus | sonnet | haiku |
| gsd-research-synthesizer | sonnet | sonnet | haiku |
| gsd-debugger | opus | sonnet | sonnet |
| gsd-codebase-mapper | sonnet | haiku | haiku |
| gsd-verifier | sonnet | sonnet | haiku |
| gsd-plan-checker | sonnet | sonnet | haiku |
| gsd-integration-checker | sonnet | sonnet | haiku |

**변경 방법:**

```
/gsd:set-profile budget
```

또는 config.json 직접 편집:

```json
{
  "model_profile": "budget"
}
```

---

### gates

선택적 에이전트 활성화/비활성화:

```json
{
  "gates": {
    "researcher": true,
    "plan_checker": true,
    "verifier": true
  }
}
```

| 게이트 | 에이전트 | 비활성화 시점 |
|--------|----------|--------------|
| `researcher` | gsd-phase-researcher | 도메인이 익숙할 때 |
| `plan_checker` | gsd-plan-checker | 단순한 페이즈 |
| `verifier` | gsd-verifier | 빠른 반복 시 |

**변경 방법:**

```
/gsd:settings
```

---

### planning

계획 문서 관리 설정:

```json
{
  "planning": {
    "commit_docs": true,
    "search_gitignored": false
  }
}
```

#### commit_docs

| 값 | 동작 |
|----|------|
| `true` | 계획 문서를 Git에 커밋 (기본값) |
| `false` | 계획 문서를 로컬에만 유지 |

**`false` 사용 시:**
- `.gitignore`에 `.planning/` 추가 필요
- OSS 기여, 클라이언트 프로젝트에 유용
- 계획 비공개 유지

#### search_gitignored

| 값 | 동작 |
|----|------|
| `false` | 기본 ripgrep 동작 (기본값) |
| `true` | gitignored 파일도 검색 |

`.planning/`이 gitignored일 때만 `true` 필요.

---

## 설정 변경 방법

### 대화형 설정

```
/gsd:settings
```

토글 및 프로파일을 대화형으로 변경합니다.

### 빠른 프로파일 변경

```
/gsd:set-profile <profile>
```

### 직접 편집

`.planning/config.json`을 직접 수정:

```bash
# 편집기로 열기
code .planning/config.json
```

---

## 프로젝트 초기화 시 설정

`/gsd:new-project` 실행 시:

1. 모드 선택 (Interactive/YOLO)
2. 리서치 여부 선택
3. config.json 자동 생성

---

## 환경별 권장 설정

### 새 프로젝트 (학습 중)

```json
{
  "mode": "interactive",
  "model_profile": "balanced",
  "gates": {
    "researcher": true,
    "plan_checker": true,
    "verifier": true
  }
}
```

### 숙련된 개발자

```json
{
  "mode": "yolo",
  "model_profile": "balanced",
  "gates": {
    "researcher": false,
    "plan_checker": false,
    "verifier": true
  }
}
```

### 쿼터 절약

```json
{
  "mode": "yolo",
  "model_profile": "budget",
  "gates": {
    "researcher": false,
    "plan_checker": false,
    "verifier": false
  }
}
```

### OSS 기여

```json
{
  "mode": "interactive",
  "model_profile": "balanced",
  "planning": {
    "commit_docs": false,
    "search_gitignored": true
  }
}
```

---

## 훅 스크립트

### gsd-check-update.js

세션 시작 시 새 버전을 확인합니다.

**위치:** `.claude/hooks/gsd-check-update.js`

**동작:**
1. npm에서 최신 버전 확인
2. 현재 버전과 비교
3. 업데이트 필요 시 알림

### gsd-statusline.js

상태 표시줄 정보를 제공합니다.

**위치:** `.claude/hooks/gsd-statusline.js`

**표시 정보:**
- 현재 페이즈
- 진행률
- 프로젝트 이름

---

## 문제 해결

### 설정이 적용되지 않음

1. config.json 경로 확인: `.planning/config.json`
2. JSON 문법 확인
3. `/gsd:progress`로 상태 확인

### 에이전트가 잘못된 모델 사용

1. `model_profile` 값 확인
2. `/gsd:set-profile`로 재설정

### 훅이 실행되지 않음

1. `.claude/settings.json` 확인
2. Node.js 설치 확인
3. 훅 스크립트 권한 확인
