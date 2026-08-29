---
allowed-tools: Read, Bash, Grep, Glob
description: 프로젝트 현황 요약 (current phase/plan 상세)
---

<role>
프로젝트 현황을 빠르게 파악하는 명령. Project, Milestone, Phase, Plan을 한눈에 보여주되, current phase와 current plan만 상세히 표시한다.

특수문자(이모지 등)를 사용하지 않는다.

## 서브커맨드

| 명령 | 설명 |
|------|------|
| `/current` | 압축 요약 (기본) |
| `/current detail` | 전체 현황 (phase/plan 상세 포함) |

</role>

<execution>

## Step 1: .planning/ 존재 확인

```bash
test -d .planning && echo "exists" || echo "missing"
```

없으면:
```
프로젝트가 설정되지 않았습니다.
/gsd:new-project 로 시작하세요.
```
종료.

## Step 2: 핵심 파일 읽기

다음 파일을 병렬로 읽는다:

- `.planning/PROJECT.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`

ROADMAP.md가 없으면:
```
마일스톤이 완료되어 아카이브된 상태입니다.
/gsd:new-milestone 로 다음 마일스톤을 시작하세요.
```
종료.

## Step 3: 전체 Phase 목록 수집

ROADMAP.md에서 Phase 목록을 파싱한다.
`.planning/phases/` 디렉토리에서 각 phase의 PLAN, SUMMARY 파일을 카운트한다.

```bash
# 각 phase 디렉토리의 plan/summary 수
for dir in .planning/phases/*/; do
  phase=$(basename "$dir")
  plans=$(ls "$dir"*-PLAN.md 2>/dev/null | wc -l)
  summaries=$(ls "$dir"*-SUMMARY.md 2>/dev/null | wc -l)
  echo "$phase plans=$plans done=$summaries"
done
```

## Step 4: Current Phase/Plan 결정

STATE.md에서 현재 위치를 파싱한다:
- `Phase:` 행에서 현재 phase 번호와 이름
- `Plan:` 행에서 현재 plan 번호
- `Status:` 행에서 상태

## Step 5: 인자 분기

- 인자 없음 (`/current`) → **요약 모드** (이 파일 하단의 "요약 모드" 참조)
- 인자 `detail` (`/current detail`) → **상세 모드** (아래 계속)

## Step 5-detail: 상세 출력

아래 형식으로 출력한다. 특수문자 없이 텍스트만 사용.

---

### 출력 형식

```
# {프로젝트 이름}

{프로젝트 설명 한 줄}

## Milestone

진행: {완료 phase}/{전체 phase} phases
상태: {milestone 상태}

## Phases

  {N}. {Phase 이름} .................. {plans done}/{plans total} plans  {상태}
  {N}. {Phase 이름} .................. {plans done}/{plans total} plans  {상태}
> {N}. {Phase 이름} .................. {plans done}/{plans total} plans  진행중
  {N}. {Phase 이름} .................. {plans done}/{plans total} plans  {상태}

( > 표시는 current phase )

## Current Phase: Phase {N} - {Phase 이름}

Goal: {ROADMAP.md에서 가져온 phase goal}
Status: {상태}
Progress: {완료 plan}/{전체 plan} plans

Success Criteria:
  1. {criteria 1}
  2. {criteria 2}

### Plans

  {N}-01: {plan 설명} ................ 완료
  {N}-02: {plan 설명} ................ 완료
> {N}-03: {plan 설명} ................ 진행중
  {N}-04: {plan 설명} ................ 대기

## Current Plan: {N}-{MM} {plan 이름}

{PLAN.md의 objective 섹션 내용}

Tasks:
  [ ] {task 1}
  [ ] {task 2}
  [x] {task 3}  (SUMMARY.md가 있으면 완료 표시)

Verification:
  [ ] {verification 1}
  [ ] {verification 2}

## Next

{다음 행동 안내}
```

---

### 상태 표시 규칙

| 조건 | 표시 |
|------|------|
| PLAN 없음 | 미계획 |
| PLAN 있음, SUMMARY 없음, current 아님 | 대기 |
| PLAN 있음, SUMMARY 없음, current임 | 진행중 |
| SUMMARY 있음 | 완료 |
| 모든 plan SUMMARY 있음 | phase 완료 |

### Current Plan 결정 규칙

Current phase 내에서 첫 번째로 SUMMARY.md가 없는 PLAN.md를 current plan으로 간주한다.

### Plan이 없는 Phase

current phase에 PLAN.md가 없으면:

```
## Current Phase: Phase {N} - {Phase 이름}

Goal: {goal}
Status: 미계획

이 phase는 아직 계획되지 않았습니다.

## Next

/gsd:plan-phase {N} 으로 계획을 생성하세요.
```

### 모든 Phase 완료

```
## Next

모든 phase가 완료되었습니다.
/gsd:complete-milestone 로 마일스톤을 완료하세요.
```

---

## Step 5-summary: 요약 출력 (기본 모드)

인자 없음 (`/current`)일 때 Step 1~4는 동일하게 실행하되, 아래 압축 형식으로 출력한다.

### 출력 형식

```
{프로젝트 이름} | {완료 phase}/{전체 phase} phases | Phase {N}: {Phase 이름} ({done}/{total} plans) | {상태}
```

한 줄 예시:

```
MyProject | 2/5 phases | Phase 3: Auth Frontend (1/3 plans) | 진행중
```

Phase 목록도 한 줄씩 압축:

```
{프로젝트 이름} | {완료}/{전체} phases

  1. Foundation        3/3  완료
  2. Auth Backend      2/2  완료
> 3. Auth Frontend     1/3  진행중
  4. Testing           0/0  미계획
  5. Deploy            0/0  미계획

Current: Phase 3, Plan 03-02 (세션 관리) - 진행중
Next: /gsd:execute-phase 3
```

- Current Phase의 goal, success criteria, plan 상세는 생략
- Current Plan의 tasks, verification은 생략
- Phase 목록 + 현재 위치 + 다음 행동만 표시

</execution>
