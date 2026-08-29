# GSD 에이전트

GSD는 특수화된 에이전트들을 사용하여 복잡한 작업을 자율적으로 처리합니다.

## 에이전트 vs Hook

| 구분 | 위치 | 실행 방식 | 용도 |
|------|------|-----------|------|
| Agent | `.claude/agents/` | Task tool spawn | 독립적 AI 작업 |
| Hook | `.claude/hooks/` | Claude Code 이벤트 | Node.js 자동화 스크립트 |

**중요:** Hook은 Node.js 스크립트이고, Agent는 AI 서브프로세스입니다.

---

## 에이전트 개요

| 에이전트 | 역할 | spawned_by |
|----------|------|------------|
| `gsd-planner` | 계획 수립 | /gsd:plan-phase |
| `gsd-executor` | 계획 실행 | execute-phase workflow |
| `gsd-debugger` | 디버깅 | /gsd:debug |
| `gsd-verifier` | 목표 검증 | verify-phase workflow |
| `gsd-phase-researcher` | 페이즈 리서치 | /gsd:plan-phase |
| `gsd-project-researcher` | 프로젝트 리서치 | /gsd:new-project |
| `gsd-research-synthesizer` | 리서치 종합 | /gsd:new-project |
| `gsd-roadmapper` | 로드맵 생성 | /gsd:new-project |
| `gsd-codebase-mapper` | 코드베이스 분석 | /gsd:map-codebase |
| `gsd-plan-checker` | 계획 검증 | /gsd:plan-phase |
| `gsd-integration-checker` | 통합 검사 | /gsd:audit-milestone |

---

## 상세 설명

### gsd-planner

**역할:** 페이즈에 대한 상세 실행 계획(PLAN.md) 생성

**spawned_by:** `/gsd:plan-phase`

**입력:**
- 페이즈 목표 (ROADMAP.md)
- 프로젝트 컨텍스트 (STATE.md)
- 리서치 결과 (RESEARCH.md, 있는 경우)

**출력:**
- `XX-YY-PLAN.md` 파일
- 태스크 목록, 의존성, 웨이브 할당

**특징:**
- 목표 역방향 분석
- 의존성 기반 웨이브 그룹화
- 검증 가능한 성공 기준 정의

---

### gsd-executor

**역할:** PLAN.md의 태스크를 실제로 실행

**spawned_by:** execute-phase workflow, execute-plan command

**skills_integration:**
- `gsd:deviation-classifier`
- `gsd:checkpoint-and-state-save`
- `gsd:atomic-git-workflow`

**입력:**
- PLAN.md 파일
- 프로젝트 상태 (STATE.md)

**출력:**
- 코드 변경 (원자적 커밋)
- SUMMARY.md (실행 결과)
- STATE.md 업데이트

**특징:**
- 태스크별 원자적 커밋
- 체크포인트 지원
- 이탈 시 STATE.md 기록

---

### gsd-debugger

**역할:** 체계적인 버그 조사 및 해결

**spawned_by:** `/gsd:debug`

**입력:**
- 버그 설명
- 증상 정보

**출력:**
- DEBUG.md (조사 세션)
- 수정 코드 (해결 시)

**특징:**
- 과학적 방법 (증거 → 가설 → 테스트)
- 세션 상태 유지 (`/clear` 후에도)
- 해결된 이슈 아카이브

---

### gsd-verifier

**역할:** 페이즈가 목표를 달성했는지 검증

**spawned_by:** verify-phase workflow

**skills_integration:**
- `gsd:verify-goal-backward`

**입력:**
- 페이즈 목표 (ROADMAP.md)
- 실행 결과 (SUMMARY.md)
- 실제 코드베이스

**출력:**
- VERIFICATION.md (검증 보고서)

**상태 값:**
- `passed` - 모든 검증 통과
- `human_needed` - 수동 테스트 필요
- `gaps_found` - 갭 발견

**특징:**
- 목표 역방향 분석
- 실제 코드 확인 (태스크 완료 여부가 아님)
- must_have 항목 검증

---

### gsd-phase-researcher

**역할:** 페이즈 구현을 위한 기술 리서치

**spawned_by:** `/gsd:plan-phase`

**입력:**
- 페이즈 목표
- 기술 스택

**출력:**
- RESEARCH.md (리서치 결과)

**특징:**
- 표준 스택 발견
- 아키텍처 패턴
- 함정 및 모범 사례

---

### gsd-project-researcher

**역할:** 프로젝트 도메인 전체 리서치

**spawned_by:** `/gsd:new-project`, `/gsd:new-milestone`

**입력:**
- 프로젝트 설명
- 도메인 정보

**출력:**
- `.planning/research/` 디렉토리
  - SUMMARY.md
  - STACK.md
  - ARCHITECTURE.md
  - FEATURES.md
  - PITFALLS.md

**특징:**
- 4개 병렬 실행
- 도메인 생태계 탐색
- 전문가 지식 수집

---

### gsd-research-synthesizer

**역할:** 여러 리서처의 결과를 종합

**spawned_by:** `/gsd:new-project` (4개 리서처 완료 후)

**입력:**
- 4개 리서처의 출력

**출력:**
- SUMMARY.md (종합 보고서)

---

### gsd-roadmapper

**역할:** 프로젝트 로드맵 생성

**spawned_by:** `/gsd:new-project` (리서치 종합 후), `/gsd:new-milestone`

**입력:**
- PROJECT.md
- REQUIREMENTS.md

**출력:**
- ROADMAP.md

**특징:**
- 페이즈 분할
- 요구사항 매핑
- 성공 기준 도출
- 커버리지 검증

---

### gsd-codebase-mapper

**역할:** 기존 코드베이스 분석

**spawned_by:** `/gsd:map-codebase`

**skills_integration:**
- `gsd:codebase-mapper-orchestrator`

**입력:**
- 코드베이스 경로

**출력:**
- `.planning/codebase/` 디렉토리
  - 7개 분석 문서

**특징:**
- 병렬 Explore 에이전트
- 읽기 전용 분석
- 구조화된 출력

---

### gsd-plan-checker

**역할:** 계획이 페이즈 목표를 달성할 수 있는지 검증

**spawned_by:** `/gsd:plan-phase`

**skills_integration:**
- `gsd:verify-goal-backward`

**입력:**
- PLAN.md
- 페이즈 목표

**출력:**
- 검증 결과 (통과/피드백)

**특징:**
- 목표 역방향 분석
- 누락 항목 발견
- 실행 전 품질 게이트

---

### gsd-integration-checker

**역할:** 페이즈 간 통합 및 E2E 흐름 검증

**spawned_by:** `/gsd:audit-milestone`

**입력:**
- 여러 페이즈의 VERIFICATION.md

**출력:**
- 통합 검사 결과

**특징:**
- 페이즈 간 연결 확인
- 사용자 워크플로우 완성도 검사

---

## 모델 프로파일

각 에이전트가 사용하는 모델은 프로파일에 따라 다릅니다:

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

**프로파일 변경:**

```
/gsd:set-profile balanced
```

또는 `.planning/config.json`:

```json
{
  "model_profile": "balanced"
}
```

---

## 에이전트 토글

일부 에이전트는 비활성화할 수 있습니다:

```
/gsd:settings
```

**토글 가능:**
- 리서처 (gsd-phase-researcher)
- 플랜 체커 (gsd-plan-checker)
- 베리파이어 (gsd-verifier)

---

## 에이전트 파일 구조

각 에이전트 파일의 YAML frontmatter:

```yaml
---
name: gsd-에이전트명
description: 간단한 설명 (10-200자)
tools: Read, Write, Edit, Bash, Grep, Glob
color: green
spawned_by:
  - /gsd:명령어
skills_integration:
  - gsd:스킬명
---
```

**참고:** [skills.md](./skills.md)에서 스킬 상세 정보 확인
