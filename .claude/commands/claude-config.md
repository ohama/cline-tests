# Claude Config Command

.claude/ submodule의 변경 사항을 commit, push하고 부모 저장소도 업데이트한다.

## 전제 조건

- `.claude/`가 git submodule로 설정되어 있어야 함
- 부모 저장소의 working directory가 clean해야 함 (다른 변경 사항이 섞이지 않도록)

## 인자 처리

| 명령 | 설명 |
|------|------|
| `/claude-config` | 상태만 확인 (commit 안 함) |
| `/claude-config push` | 변경 사항 확인 및 commit/push |
| `/claude-config push -m "메시지"` | 지정한 메시지로 commit |
| `/claude-config pull` | 원격에서 submodule 가져와서 부모 저장소 업데이트 |

## 워크플로우

### /claude-config (기본 = status)

```
┌─────────────────────────────────────────────────────────┐
│  /claude-config                                         │
├─────────────────────────────────────────────────────────┤
│  1. Submodule 상태 표시                                 │
│     └─ git -C .claude status --short                    │
│     └─ 변경 없음 → "Clean" 출력                         │
│     └─ 변경 있음 → 변경 파일 목록 출력                  │
│                                                         │
│  2. Submodule 원격 상태                                 │
│     └─ git -C .claude log origin/master..HEAD --oneline │
│     └─ 푸시 안 된 커밋 있으면 표시                      │
│                                                         │
│  3. 부모 저장소 submodule 참조 상태                     │
│     └─ git status .claude                               │
│     └─ 변경 있으면 "(new commits)" 표시                 │
└─────────────────────────────────────────────────────────┘
```

### /claude-config push

```
┌─────────────────────────────────────────────────────────┐
│  /claude-config push                                    │
├─────────────────────────────────────────────────────────┤
│  0. 전제 조건 확인                                      │
│     └─ .claude가 submodule인지 확인                     │
│     └─ 부모 저장소 clean 상태 확인                      │
│                                                         │
│  1. git -C .claude status --short                       │
│     └─ 변경 없음 → "Nothing to commit" 출력 후 종료     │
│     └─ 변경 있음 → 계속                                 │
│                                                         │
│  2. 변경 내용 표시                                      │
│     └─ git -C .claude diff --stat                       │
│                                                         │
│  3. 커밋 메시지 요청 (인자로 안 받았으면)               │
│                                                         │
│  4. Submodule commit                                    │
│     └─ git -C .claude add -A                            │
│     └─ git -C .claude commit -m "메시지                 │
│                                                         │
│        Co-Authored-By: Claude Opus 4.5 <noreply@...>"   │
│                                                         │
│  5. 사용자에게 push 확인                                │
│     └─ 거부 → 종료 (commit은 유지)                      │
│     └─ 승인 → 계속                                      │
│                                                         │
│  6. Submodule push                                      │
│     └─ git -C .claude push                              │
│     └─ 실패 시 → 에러 메시지 출력 후 종료               │
│                                                         │
│  7. 부모 저장소 업데이트                                │
│     └─ git add .claude                                  │
│     └─ git commit -m "chore: update .claude submodule   │
│                                                         │
│        Co-Authored-By: Claude Opus 4.5 <noreply@...>"   │
│     └─ git push                                         │
│                                                         │
│  8. 완료 메시지                                         │
└─────────────────────────────────────────────────────────┘
```

### /claude-config pull

```
┌─────────────────────────────────────────────────────────┐
│  /claude-config pull                                    │
├─────────────────────────────────────────────────────────┤
│  0. 전제 조건 확인                                      │
│     └─ .claude가 submodule인지 확인                     │
│     └─ 부모 저장소 clean 상태 확인                      │
│                                                         │
│  1. Submodule fetch & pull                              │
│     └─ git -C .claude fetch origin                      │
│     └─ git -C .claude pull origin master                │
│     └─ 변경 없음 → "Already up to date" 출력 후 종료   │
│     └─ 변경 있음 → 변경 내용 표시 후 계속              │
│                                                         │
│  2. 부모 저장소 상태 확인                               │
│     └─ git status .claude                               │
│     └─ 변경 없음 → 종료                                 │
│     └─ 변경 있음 → 계속                                 │
│                                                         │
│  3. 사용자에게 commit/push 확인                         │
│     └─ 거부 → 종료 (submodule은 이미 pull됨)           │
│     └─ 승인 → 계속                                      │
│                                                         │
│  4. 부모 저장소 업데이트                                │
│     └─ git add .claude                                  │
│     └─ git commit -m "chore: update .claude submodule   │
│                                                         │
│        Co-Authored-By: Claude Opus 4.5 <noreply@...>"   │
│     └─ git push                                         │
│                                                         │
│  5. 완료 메시지                                         │
└─────────────────────────────────────────────────────────┘
```

## 에러 처리

| 상황 | 대응 |
|------|------|
| .claude가 submodule이 아님 | "Error: .claude is not a submodule" 출력 후 종료 |
| 부모 저장소에 uncommitted 변경 있음 | "Error: Parent repo has uncommitted changes" 출력 후 종료 |
| push 실패 (네트워크/인증) | 에러 메시지 표시, commit은 유지됨을 안내 |
| pull 시 충돌 발생 | 충돌 파일 표시, 수동 해결 안내 |

## 확인용 명령어

```bash
# submodule 여부 확인
git config --file .gitmodules --get submodule..claude.path

# 부모 저장소 상태 확인
git status --porcelain | grep -v "^?? .claude"

# submodule 원격과 비교
git -C .claude log origin/master..HEAD --oneline
```
