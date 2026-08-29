---
allowed-tools: Read, Bash, AskUserQuestion
description: 간단한 git push (옵션으로 안전 모드, 태그, PR 지원)
---

<role>
Git 푸시를 실행합니다. 기본은 단순 푸시, 옵션으로 검증 추가.
</role>

## 사용법

| 명령 | 설명 |
|------|------|
| `/push` | 현재 브랜치를 바로 푸시 (확인 없음) |
| `/push --safe` | 푸시 전 상태 확인 및 검증 |
| `/push --tags` | 태그도 함께 푸시 |
| `/push --pr` | 푸시 후 PR 생성 |
| `/push --force` | Force push (확인 후) |
| `/push <remote>` | 지정된 remote로 푸시 |

옵션 조합 가능: `/push --safe --tags --pr`

---

## 기본 모드 (옵션 없음)

최소한의 검증만 하고 바로 푸시:

```bash
# 1. 브랜치 확인
BRANCH=$(git branch --show-current)

# 2. upstream 여부 확인
if ! git rev-parse --abbrev-ref @{u} &>/dev/null; then
  # 새 브랜치면 -u 추가
  git push -u origin "$BRANCH"
else
  git push origin "$BRANCH"
fi
```

**출력:**

```
Push 완료: <branch> → origin/<branch>
```

실패시 에러 메시지만 표시.

---

## --safe 모드

푸시 전 전체 검증:

### 1. 상태 확인

```bash
git branch --show-current
git status --porcelain
git log --oneline @{u}..HEAD 2>/dev/null || git log --oneline -5
```

### 2. 보호 브랜치 확인

main/master/develop 브랜치면 경고:

```
브랜치 'main'에 직접 푸시합니다. 계속? [Y/N]
```

### 3. 분기 감지

```bash
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u} 2>/dev/null)
BASE=$(git merge-base HEAD @{u} 2>/dev/null)

if [ -n "$REMOTE" ] && [ "$REMOTE" != "$BASE" ]; then
  echo "DIVERGED"
fi
```

분기시:

```
로컬과 원격이 분기됨. [P]ull / [F]orce / [X] 취소?
```

### 4. 푸시 실행

확인 후 푸시.

---

## --tags 모드

```bash
git push origin "$BRANCH" --tags
```

---

## --pr 모드

푸시 후 PR 생성:

```bash
git push origin "$BRANCH"
gh pr create --fill
```

---

## --force 모드

확인 후 force push:

```
Force push는 원격 히스토리를 덮어씁니다. 진행? [Y/N]
```

Y 선택시:

```bash
git push --force-with-lease origin "$BRANCH"
```

---

## 에러 처리

| 상황 | 처리 |
|------|------|
| 원격 없음 | `git remote add origin <url>` 안내 |
| 인증 실패 | SSH/토큰 확인 안내 |
| 푸시 거부 | pull 또는 force 제안 |
