# GSD 구조 개요

## 디렉토리 구조

```
.claude/
├── settings.json           # Claude Code 설정 (hooks, statusLine)
├── agents/                 # GSD 특수 에이전트 정의 (11개)
├── commands/               # 슬래시 명령어
│   ├── gsd/                # GSD 명령어 (27개)
│   ├── howto.md            # 개발 지식 기록 명령어
│   └── mdbook.md           # mdBook 문서 사이트 설정
├── skills/                 # 방법론 및 패턴
│   ├── gsd/                # GSD 스킬 (11개)
│   ├── mdbook-docs-images.skill.md      # mdBook 문서·이미지 규칙
│   └── markdown-image-insertion.skill.md # Markdown 이미지 삽입 규칙
├── get-shit-done/          # GSD 코어 시스템
│   ├── VERSION             # 현재 버전
│   ├── config/             # 스키마 및 설정 정의
│   ├── templates/          # 문서 템플릿
│   ├── references/         # 참조 문서
│   └── workflows/          # 워크플로우 정의
├── hooks/                  # 훅 스크립트
└── docs/                   # 문서
```

## 상세 구조

### 1. `settings.json`

Claude Code 통합 설정:

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

- **SessionStart hook**: 세션 시작 시 업데이트 확인
- **statusLine**: 상태 표시줄에 GSD 정보 표시

### 2. `agents/` (11개 에이전트)

| 에이전트 | 역할 | spawned_by |
|----------|------|------------|
| `gsd-planner` | 페이즈 계획 수립 | /gsd:plan-phase |
| `gsd-executor` | 계획 실행 | execute-phase workflow |
| `gsd-debugger` | 체계적 디버깅 | /gsd:debug |
| `gsd-verifier` | 목표 달성 검증 | verify-phase workflow |
| `gsd-phase-researcher` | 페이즈별 기술 리서치 | /gsd:plan-phase |
| `gsd-project-researcher` | 프로젝트 도메인 리서치 | /gsd:new-project |
| `gsd-roadmapper` | 로드맵 생성 | /gsd:new-project |
| `gsd-codebase-mapper` | 기존 코드베이스 분석 | /gsd:map-codebase |
| `gsd-plan-checker` | 계획 품질 검증 | /gsd:plan-phase |
| `gsd-integration-checker` | 페이즈 간 통합 검사 | /gsd:audit-milestone |
| `gsd-research-synthesizer` | 리서치 결과 종합 | /gsd:new-project |

### 3. `commands/`

#### GSD 명령어 (`commands/gsd/`, 28개)

**프로젝트 초기화**
- `new-project.md` - 새 프로젝트 시작
- `map-codebase.md` - 기존 코드베이스 분석

**페이즈 관리**
- `plan-phase.md`, `execute-phase.md`, `research-phase.md`
- `discuss-phase.md`, `add-phase.md`, `insert-phase.md`, `remove-phase.md`

**마일스톤 관리**
- `new-milestone.md`, `complete-milestone.md`, `audit-milestone.md`

**작업 관리**
- `progress.md`, `resume-work.md`, `pause-work.md`
- `quick.md`, `verify-work.md`, `debug.md`

**할 일 관리**
- `add-todo.md`, `check-todos.md`

**설정 및 유틸리티**
- `settings.md`, `set-profile.md`, `help.md`, `update.md`, `join-discord.md`
- `health.md` - GSD 프로젝트 상태 진단

#### 범용 명령어 (`commands/`)

- `commit.md` - Git 초기화, .gitignore 관리, 스마트 커밋
- `current.md` - 프로젝트 현황 요약 (current phase/plan 상세)
- `howto.md` - 개발 지식 기록 및 관리
- `mdbook.md` - mdBook 문서 사이트 설정 및 GitHub Pages 배포
- `push.md` - Git 푸시 (안전 모드, 태그, PR 지원)
- `release.md` - 버전 업그레이드, CHANGELOG 작성, 릴리스 커밋
- `submodule.md` - Git submodule 최신화
- `claude-config.md` - .claude/ submodule 관리

### 4. `skills/` (12개 GSD 스킬 + 2개 프로젝트 스킬)

에이전트가 참조하는 방법론 및 패턴:

**프로젝트 전용 스킬 (`skills/`)**

| 스킬 | 용도 |
|------|------|
| `mdbook-docs-images` | mdBook 문서·이미지·구조 규칙 |
| `markdown-image-insertion` | Markdown 이미지 삽입 규칙 |

**GSD 스킬 (`skills/gsd/`)**

| 스킬 | 용도 |
|------|------|
| `research-methodology` | 리서치 철학/전략/검증 (researcher 에이전트 공통) |
| `resolve-model-profile` | 모델 프로파일 결정 |
| `verify-goal-backward` | 목표 역추적 검증 |
| `checkpoint-and-state-save` | 체크포인트 프로토콜 |
| `atomic-git-workflow` | 태스크별 원자적 커밋 |
| `deviation-classifier` | 실행 이탈 분류 |
| `wave-executor` | 병렬 웨이브 실행 |
| `state-reconstruction` | STATE.md 복구 |
| `codebase-mapper-orchestrator` | 코드베이스 분석 |
| `todo-manager` | Todo 관리 |
| `verification-report-generator` | 검증 보고서 생성 |
| `context-discussion-guide` | 컨텍스트 수집 |

### 5. `get-shit-done/config/`

스키마 및 설정 정의:

| 파일 | 내용 |
|------|------|
| `agent-schema.json` | 에이전트 YAML frontmatter 스키마 |
| `model-profiles.json` | 모델 프로파일 정의 (단일 소스) |
| `planning-config-schema.json` | config.json 스키마 |

### 6. `get-shit-done/references/`

참조 문서:

| 파일 | 내용 |
|------|------|
| `model-profiles.md` | 모델 프로파일 설명 |
| `checkpoints.md` | 체크포인트 처리 |
| `hooks-vs-agents.md` | 훅과 에이전트 구분 |
| `skills-integration.md` | 스킬 통합 가이드 |
| `formatting-conventions.md` | 포맷팅 규칙 |
| `tdd.md` | 테스트 주도 개발 |
| `verification-patterns.md` | 검증 패턴 |
| `git-integration.md` | Git 통합 |
| `questioning.md` | 질문 가이드라인 |
| `continuation-format.md` | 연속 실행 포맷 |
| `planning-config.md` | 계획 설정 |
| `ui-brand.md` | UI 브랜딩 |

### 7. `hooks/`

| 파일 | 역할 |
|------|------|
| `gsd-check-update.js` | 세션 시작 시 업데이트 확인 |
| `gsd-statusline.js` | 상태 표시줄 정보 제공 |
| `gsd-config.js` | 설정 파싱 유틸리티 |

**중요:** Hook은 Node.js 스크립트이고, Agent는 AI 서브프로세스입니다. 혼동하지 마세요.

## 런타임 생성 파일 (`.planning/`)

GSD 사용 시 생성되는 프로젝트 파일:

```
.planning/
├── PROJECT.md              # 프로젝트 비전 및 요구사항
├── ROADMAP.md              # 페이즈 로드맵
├── REQUIREMENTS.md         # 상세 요구사항 (REQ-ID)
├── STATE.md                # 현재 상태 및 컨텍스트
├── config.json             # 워크플로우 설정
├── research/               # 도메인 리서치 결과
├── codebase/               # 코드베이스 분석 결과
├── todos/                  # 할 일 관리
├── debug/                  # 디버그 세션
├── quick/                  # 빠른 작업
└── phases/                 # 페이즈별 계획 및 결과
    ├── 01-foundation/
    │   ├── 01-01-PLAN.md
    │   ├── 01-01-SUMMARY.md
    │   └── 01-VERIFICATION.md
    └── 02-features/
        └── ...
```

## Howto 문서 (`documentation/howto/`)

개발 지식 기록:

```
documentation/howto/
├── README.md               # 문서 목록 (단일 소스)
├── create-skill.md         # 스킬 생성 방법
├── check-consistency.md    # 시스템 일관성 검사
└── ...
```
