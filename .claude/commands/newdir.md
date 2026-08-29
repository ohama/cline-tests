---
allowed-tools: Bash
description: 새 디렉토리를 생성하고 .claude/ 설정을 복사
---

<role>
새 프로젝트 디렉토리를 생성하고, 현재 디렉토리에 .claude/가 있으면 복사합니다.
</role>

<commands>

## 사용법

| 명령 | 설명 |
|------|------|
| `/newdir <name>` | 디렉토리 생성 + .claude/ 복사 |

</commands>

<execution>

## Step 1: 인자 확인

인자가 없으면 안내 후 종료:

```
사용법: /newdir <디렉토리명>
```

## Step 2: 디렉토리 존재 확인

```bash
[ -d "<name>" ] && echo "EXISTS"
```

- 이미 존재하면 안내 후 종료:

```
⚠️ <name>/ 디렉토리가 이미 존재합니다.
```

## Step 3: 디렉토리 생성

```bash
mkdir -p <name>
```

## Step 4: .claude/ 복사

```bash
[ -d ".claude" ] && cp -r .claude <name>/
```

- `.claude/`가 있으면 복사
- `.claude/`가 없으면 건너뛰기

## Step 5: 결과 출력

**.claude/ 복사된 경우:**

```
## 완료

<name>/ 생성됨
  └── .claude/ 복사됨

다음 단계:
  cd <name>
```

**.claude/ 없는 경우:**

```
## 완료

<name>/ 생성됨

다음 단계:
  cd <name>
```

</execution>

<examples>

### 예시 1: .claude/가 있는 경우

```
User: /newdir my-project

Claude:
mkdir -p my-project
cp -r .claude my-project/

## 완료

my-project/ 생성됨
  └── .claude/ 복사됨

다음 단계:
  cd my-project
```

### 예시 2: .claude/가 없는 경우

```
User: /newdir my-project

Claude:
mkdir -p my-project

## 완료

my-project/ 생성됨

다음 단계:
  cd my-project
```

### 예시 3: 디렉토리가 이미 존재

```
User: /newdir my-project

Claude:
⚠️ my-project/ 디렉토리가 이미 존재합니다.
```

</examples>
