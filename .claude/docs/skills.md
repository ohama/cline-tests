# GSD 스킬

스킬은 에이전트가 반복적으로 사용하는 **방법론(methodology)**을 정의합니다.

## 스킬 vs 명령어 vs 에이전트

| 구분 | 위치 | 호출 방식 | 용도 |
|------|------|-----------|------|
| Command | `.claude/commands/` | `/명령어` | 사용자가 직접 실행 |
| Agent | `.claude/agents/` | Task tool spawn | 독립적 AI 작업 |
| Skill | `.claude/skills/` | 에이전트가 참조 | 방법론/패턴 정의 |

## 스킬 네임스페이스

| 네임스페이스 | 위치 | 용도 |
|--------------|------|------|
| `gsd:*` | `.claude/skills/gsd/` | GSD 내부 방법론 |
| `superpowers:*` | `.claude/skills/superpowers/` | 외부 통합 스킬 |
| (루트) | `.claude/skills/` | 프로젝트 전용 스킬 |

---

## 프로젝트 전용 스킬 (2개)

#### `mdbook-docs-images`

mdBook 문서 작성 시 이미지·구조·렌더링 규칙을 강제하는 스킬.

**트리거:** mdBook 기반 문서를 생성·편집할 때 자동 적용

**규칙:**
- mdBook 기본 구조 (`book/src/`, `SUMMARY.md`)
- 이미지는 `src/images/` 하위, 상대경로만 사용
- HTML 사용 금지 (명시적 요청 시만 허용)
- 이미지 설계 주석을 HTML 주석으로 삽입

---

#### `markdown-image-insertion`

Markdown 문서 내 이미지 삽입 규칙 (경로, 캡션, HTML 제한 등)을 강제하는 스킬.

**트리거:** Markdown 문서를 생성·편집할 때 자동 적용

**규칙:**
- Markdown 표준 문법만 사용 (`![alt](images/file.png)`)
- 상대경로만 허용, URL/절대경로 금지
- 캡션은 이미지 아래 기울임꼴
- 실제 이미지 파일은 생성하지 않고, 설계 주석으로 명세 제공

---

## GSD 스킬 목록 (11개)

### P0 (핵심)

#### `gsd:resolve-model-profile`

모델 프로파일 결정 패턴.

**사용 에이전트:** 모든 에이전트

**패턴:**
1. config.json에서 profile 읽기
2. model-profiles.json에서 에이전트별 모델 조회
3. 폴백: sonnet

---

#### `gsd:verify-goal-backward`

목표 역추적 검증 방법론.

**사용 에이전트:** gsd-verifier, gsd-plan-checker

**패턴:**
1. 목표 상태 정의 (사용자 관점)
2. 현재 상태 확인
3. 갭 식별
4. 검증 보고서 생성

---

#### `gsd:checkpoint-and-state-save`

체크포인트 프로토콜.

**사용 에이전트:** gsd-executor

**체크포인트 유형:**
- `human-verify`: 수동 테스트 필요
- `decision`: 중요 결정 필요
- `human-action`: 사용자 조치 필요

---

#### `gsd:atomic-git-workflow`

태스크별 원자적 커밋 패턴.

**사용 에이전트:** gsd-executor

**패턴:**
1. 태스크 시작
2. 변경 수행
3. 검증
4. 커밋 (태스크별 1개)

---

### P1 (중요)

#### `gsd:deviation-classifier`

실행 중 이탈 상황 분류.

**사용 에이전트:** gsd-executor

**4가지 규칙:**
1. Blocker Detection - 불가능 상황 감지
2. Enhancement Deferral - 범위 확장은 TODO로
3. Technical Adaptation - 기술적 조정은 즉시
4. User Escalation - 중요 결정은 사용자에게

---

#### `gsd:wave-executor`

병렬 웨이브 실행 패턴.

**사용 에이전트:** execute-phase workflow

**패턴:**
1. 의존성 분석
2. 웨이브 그룹화
3. 웨이브별 순차 실행 (웨이브 내 병렬)

---

#### `gsd:state-reconstruction`

STATE.md 복구 방법론.

**사용 시점:** STATE.md 손상/누락 시

**패턴:**
1. git log에서 최근 작업 추출
2. ROADMAP.md에서 현재 위치 파악
3. STATE.md 재구성

---

#### `gsd:codebase-mapper-orchestrator`

코드베이스 병렬 분석 패턴.

**사용 에이전트:** gsd-codebase-mapper

**패턴:**
1. 4개 매퍼 병렬 spawn (tech, arch, quality, concerns)
2. 각 매퍼가 문서 직접 작성
3. 결과 통합

---

### P2 (편의)

#### `gsd:todo-manager`

Todo 생명주기 관리.

**사용 에이전트:** /gsd:add-todo, /gsd:check-todos

**위치:**
- 대기: `.planning/todos/pending/`
- 완료: `.planning/todos/done/`

---

#### `gsd:verification-report-generator`

VERIFICATION.md 생성 패턴.

**사용 에이전트:** gsd-verifier

**구조:**
- Phase Goal
- Must-Haves (검증 항목)
- Verification Results
- Status (passed/human_needed/gaps_found)

---

#### `gsd:context-discussion-guide`

페이즈 컨텍스트 수집 가이드.

**사용 에이전트:** /gsd:discuss-phase

**패턴:**
1. 페이즈 목표 확인
2. 적응적 질문
3. CONTEXT.md 생성

---

## 스킬 참조 방법

에이전트 frontmatter에서:

```yaml
---
name: gsd-executor
skills_integration:
  - gsd:deviation-classifier
  - gsd:checkpoint-and-state-save
  - gsd:atomic-git-workflow
---
```

에이전트 본문에서:

```markdown
<skills_reference>
이 에이전트는 다음 스킬을 사용합니다:
- `gsd:deviation-classifier` - 이탈 상황 분류
- `gsd:checkpoint-and-state-save` - 체크포인트 처리
</skills_reference>
```

---

## 스킬 생성

새 스킬 생성 시:

1. `.claude/skills/gsd/스킬명.md` 파일 생성
2. YAML frontmatter: name, description
3. When to Use 섹션
4. The Pattern 섹션 (단계별)
5. Examples 섹션
6. 관련 에이전트에 skills_integration 추가

**참고:** `documentation/howto/create-skill.md` (생성 예정)
