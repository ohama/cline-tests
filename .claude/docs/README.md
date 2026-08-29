# GSD (Get Shit Done) Documentation

GSD는 Claude Code를 위한 체계적인 프로젝트 관리 워크플로우 시스템입니다.

**Version:** 1.9.13

## 문서 목차

| 문서 | 설명 |
|------|------|
| [구조 개요](./structure.md) | 디렉토리 구조 및 파일 역할 |
| [빠른 시작](./quickstart.md) | 5분 안에 GSD 시작하기 |
| [명령어 레퍼런스](./commands.md) | 전체 슬래시 명령어 목록 |
| [에이전트](./agents.md) | 특수 에이전트 역할 및 동작 |
| [스킬](./skills.md) | 에이전트 방법론 및 패턴 |
| [워크플로우](./workflows.md) | 단계별 작업 흐름 가이드 |
| [설정](./configuration.md) | 설정 옵션 및 모델 프로파일 |

## GSD란?

GSD는 "Get Shit Done"의 약자로, 솔로 개발자가 Claude Code와 함께 프로젝트를 체계적으로 진행할 수 있도록 설계된 워크플로우 시스템입니다.

### 핵심 개념

```
프로젝트 → 마일스톤 → 페이즈 → 플랜 → 태스크
```

- **프로젝트(Project)**: 전체 제품/서비스
- **마일스톤(Milestone)**: 릴리스 단위 (v1.0, v2.0 등)
- **페이즈(Phase)**: 마일스톤 내 주요 기능 단위
- **플랜(Plan)**: 페이즈 내 구체적 실행 계획
- **태스크(Task)**: 플랜 내 개별 작업 항목

### 핵심 워크플로우

```
/gsd:new-project → /gsd:plan-phase → /gsd:execute-phase → 반복
```

## 시스템 구성

```
.claude/
├── agents/          # AI 에이전트 (11개)
├── commands/        # 슬래시 명령어
│   ├── gsd/         # GSD 명령어 (27개)
│   ├── commit.md    # Git 초기화 및 스마트 커밋
│   ├── howto.md     # 개발 지식 기록
│   └── release.md   # 릴리스 관리
├── skills/          # 방법론 및 패턴
│   └── gsd/         # GSD 스킬 (11개)
├── hooks/           # Node.js 훅 스크립트
├── get-shit-done/   # GSD 코어
└── docs/            # 문서
```

## 빠른 시작

```bash
# 1. 새 프로젝트 시작
/gsd:new-project

# 2. 첫 번째 페이즈 계획
/gsd:plan-phase 1

# 3. 페이즈 실행
/gsd:execute-phase 1

# 4. 진행 상황 확인
/gsd:progress
```

## 개발 지식 기록

```bash
# 세션 분석 + 문서 작성 (원스톱)
/howto

# 문서 목록 보기
/howto list

# 새 문서 생성
/howto new "제목"
```

## 업데이트

```bash
npx get-shit-done-cc@latest
```

또는:

```
/gsd:update
```

## 도움말

- `/gsd:help` - 명령어 레퍼런스 표시
- `/gsd:progress` - 현재 상태 및 다음 단계 안내
- [Discord 커뮤니티](https://discord.gg/gsd) - `/gsd:join-discord`
