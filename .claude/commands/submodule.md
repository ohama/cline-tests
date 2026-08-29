---
allowed-tools: Bash
description: Git submodule을 최신 버전으로 업데이트
---

<role>
Git submodule을 최신 상태로 업데이트합니다.
</role>

<commands>

## 사용법

| 명령 | 설명 |
|------|------|
| `/submodule <name>` | 지정한 submodule을 최신화 |
| `/submodule` | 모든 submodule 최신화 |

</commands>

<execution>

## Step 1: Submodule 확인

```bash
git submodule status
```

- submodule이 없으면 안내 후 종료
- 인자가 주어졌으면 해당 submodule 존재 여부 확인

## Step 2: Submodule 업데이트

### 특정 submodule (인자가 있을 때)

```bash
cd <submodule_path>
git fetch origin
git checkout origin/HEAD
cd -
```

### 모든 submodule (인자가 없을 때)

```bash
git submodule update --remote --merge
```

## Step 3: 결과 확인

```bash
git submodule status
git diff --submodule
```

## Step 4: 변경사항 안내

변경이 있으면:

```
## Submodule 업데이트 완료

- <submodule_name>: <old_commit> → <new_commit>

커밋하려면 `/commit` 실행
```

변경이 없으면:

```
이미 최신 상태입니다.
```

</execution>

<examples>

### 예시 1: 특정 submodule 업데이트

```
User: /submodule .claude

Claude: Submodule 업데이트 중...

## Submodule 업데이트 완료

- .claude: 87c2948 → a1b2c3d

커밋하려면 `/commit` 실행
```

### 예시 2: 모든 submodule 업데이트

```
User: /submodule

Claude: 모든 submodule 업데이트 중...

## Submodule 업데이트 완료

- .claude: 87c2948 → a1b2c3d
- lib/utils: 1234567 → 89abcde

커밋하려면 `/commit` 실행
```

### 예시 3: 이미 최신

```
User: /submodule .claude

Claude: 이미 최신 상태입니다.
```

</examples>
