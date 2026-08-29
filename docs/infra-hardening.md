# Phase 2 인프라 보정 기록 (INF-01/02/03)

## 1. 무엇을 바꿨나

두 라이브 launchd plist 를 실제로 편집하고 재시작했다. 둘 다 `phase-02/infra/config.env` 가
값을 정의하는 유일한 지점이며, 값을 바꾸려면 `config.env` 를 고치고 각 `apply_*.sh` 를 재실행한
뒤(idempotent, 몇 번을 돌려도 플래그 쌍이 하나만 남는다) `restart_service.sh` 로 재시작하면
된다.

### `com.ohama.flashnext` — `--max-num-seqs`

Before (`ProgramArguments`, 관련 부분만):

```
--max-kv-size
32768
--log-level
INFO
```

After:

```
--max-kv-size
32768
--log-level
INFO
--max-num-seqs
1
```

`MAX_NUM_SEQS` 는 `phase-02/infra/config.env` 가 정의한다(기본값 `1`).

### `com.ohama.litellm` — `--host`

Before:

```
/Users/ohama/agent-stack/venv/bin/litellm
--config
/Users/ohama/agent-stack/litellm/config.yaml
--port
4000
```

After:

```
/Users/ohama/agent-stack/venv/bin/litellm
--config
/Users/ohama/agent-stack/litellm/config.yaml
--port
4000
--host
127.0.0.1
```

`LITELLM_BIND_HOST` 는 같은 `phase-02/infra/config.env` 가 정의한다(기본값 `127.0.0.1`).
`config.yaml` 과 `master_key` 는 이 phase 내내 손대지 않았다.

## 2. 왜 이렇게 골랐나

**`--max-num-seqs`** 는 mlx-vlm `0.6.17` 이 이미 갖고 있는 네이티브 플래그이며, 그 자체 docstring
이 정확히 이 백프레셔(backpressure)를 설명한다 — 새 코드를 얹지 않고 서버가 스스로 큐잉하게
만드는 가장 얇은 개입이다. 값으로 `1`(완전 직렬화)을 고른 이유는 두 가지다: 로드맵 Phase 2
성공 기준 1 이 문자 그대로 "하나가 즉시 처리되고 다른 하나는 큐잉/지연"을 요구하고, 이 스택의
32K 헤드룸이 4.39GB 뿐이라 동시 2개를 허용하는 `MAX_NUM_SEQS=2` 보다 `1` 이 명백히 더 안전하다.

**`--host 127.0.0.1`** 은 `master_key` 도입 대신 고른 것이다. 이 머신의 `:4000` 소비처 4곳
(Cline `providers.json`, `~/.hermes/config.yaml`, `~/.openjarvis/config.toml`,
`~/.claude/proxy.env`) 이 전부 이미 `localhost` 를 가리키고 placeholder 키 `dummy` 를 쓰고
있었다 — 루프백 바인딩은 이 넷을 하나도 건드리지 않고 LAN 노출만 닫지만, `master_key` 를
추가했다면 넷 다 401 로 깨졌을 것이다.

## 3. 한계

**`--max-num-seqs` 는 동시(concurrent) 시퀀스 수만 제한한다.** 32,768 KV 상한 근처에서 발생하는
단일 요청 Metal OOM 자체를 고치지 않는다 — 이미 문서화된 실측 사례가 `flashnext.err` 에 있다
(`2026-08-29 19:05:22` 근방, `prompt_tokens=30505`, `in_flight=1`). 이 실패 모드는 계속
`docs/32k-compaction-policy.md` 의 "작업을 다시 시작한다" 규칙이 관할한다. 나중에 이 문서를 읽는
사람이 Phase 2 를 OOM 수정으로 오해하지 않도록 명시해 둔다.

## 4. 증거

| 항목 | 경로 |
|---|---|
| 언캡트(before) 큐잉 베이스라인 — `max_overlap=2`, `queued_count=0` | `phase-02/results/20260829T183540Z/` |
| INF-01 캡트(after) 큐잉 통과 — `max_overlap=1`, `queued_count=1` | `phase-02/results/20260829T185628Z-inf01/` |
| INF-01 실패했던 재시작 2회(비동기 bootout 버그 재현) | `phase-02/results/20260829T184656Z-inf01/` |
| INF-02 LAN 차단 판정(`INF02: PASS`) | `phase-02/results/20260829T190346Z-inf02/` |
| INF-03 전체 체인 통과(`INF03: PASS`, 127.0.0.1/localhost 양쪽) | `phase-02/results/20260829T191031Z-inf03/` |
| 미러 sync 실행 로그 | `phase-02/results/20260829T191031Z-inf03/sync.txt` |

재실행 가능한 세 스크립트:

```
bash phase-02/infra/verify_queueing.sh --label after-final
bash phase-02/infra/verify_lan_bind.sh
bash phase-02/infra/verify_no_regression.sh
```

`verify_no_regression.sh` 는 이 phase 의 표준 상시 헬스 게이트다 — Phase 5(Kanban + Telegram
동시 기동)와 Phase 6(네트워크 노출) 은 새 서비스를 올리기 전/후 이 스크립트를 그대로 호출하면
된다. 무변경, 읽기 전용, 항상 재실행 가능.

## 5. 롤백

두 롤백 모두 `phase-02/infra/restart_service.sh` 가 실패 시 자동으로 출력하는 블록과 동일하며,
여기 그대로 복사해 둔다. `<UID>` 는 `id -u`.

### flashnext 롤백 (plan 02-02)

가장 최근 백업: `phase-02/infra/backups/com.ohama.flashnext.plist.20260829T185616Z`

```
cp -p phase-02/infra/backups/com.ohama.flashnext.plist.20260829T185616Z \
  ~/Library/LaunchAgents/com.ohama.flashnext.plist
plutil -lint ~/Library/LaunchAgents/com.ohama.flashnext.plist          # must print OK
launchctl bootout   gui/<UID>/com.ohama.flashnext   # ignore "No such process"
launchctl bootstrap gui/<UID> ~/Library/LaunchAgents/com.ohama.flashnext.plist
```

### litellm 롤백 (plan 02-03)

가장 최근 백업: `phase-02/infra/backups/com.ohama.litellm.plist.20260829T190346Z`

```
cp -p phase-02/infra/backups/com.ohama.litellm.plist.20260829T190346Z \
  ~/Library/LaunchAgents/com.ohama.litellm.plist
plutil -lint ~/Library/LaunchAgents/com.ohama.litellm.plist          # must print OK
launchctl bootout   gui/<UID>/com.ohama.litellm   # ignore "No such process"
launchctl bootstrap gui/<UID> ~/Library/LaunchAgents/com.ohama.litellm.plist
```

**둘 다: 롤백 후 반드시 `~/local-llm-settings/sync.sh` 를 다시 돌려라.** 그러지 않으면 미러가
이미 되돌린 변경을 계속 광고하게 된다.

또한 어느 쪽이든 실제로는 `phase-02/infra/restart_service.sh <label> <port>` 를 통해서만
재시작할 것 — 위 명령을 손으로 직접 치지 말 것. 이 헬퍼가 아래 하우스 룰(bootout 의 비동기성)을
이미 내장하고 있다.

## 6. 하우스 룰

- **절대 `kill`/`pkill` 로 서비스를 내리지 않는다.** `launchctl load`/`unload` 도 쓰지 않는다
  (KeepAlive/ThrottleInterval 과 충돌한다). plist 편집 후 `launchctl kickstart` 로 "다시 읽지
  않고 재시작"도 쓰지 않는다 — 편집한 파일이 반영되지 않는다.
- **항상 `bootout` → 편집 → `bootstrap` → `launchctl print` 확인** 순서를 지킨다.
- **`launchctl bootout` 은 비동기다.** unload를 "요청"한 시점에 리턴하며, 프로세스가 실제로
  사라지는 시점을 보장하지 않는다. 무거운 프로세스(모델 로드 등)를 물고 있는 서비스는 teardown
  에 수 초가 걸리는데, 그 사이 곧바로 `bootstrap` 을 호출하면 `Bootstrap failed: 5: Input/output
  error` 로 실패한다 — 이 프로젝트 첫 라이브 재시작(flashnext, 104GiB 모델)에서 정확히 이 순서로
  두 번 재현되었다(`phase-02/results/20260829T184656Z-inf01/`). `restart_service.sh` 의 Step 3b
  가 이미 이 폴링(라벨이 더 이상 조회되지 않고 + 포트에 리스너가 없을 때까지, +3초 여유)을
  내장하고 있으므로, 이 헬퍼만 쓰면 이 함정을 다시 만날 일이 없다. **Phase 5 가 Kanban/Telegram
  용으로 새 launchd 서비스를 등록하고 그 서비스만의 재시작 로직을 새로 짠다면, 이 순서
  (bootout → teardown 확인 폴링 → bootstrap → healthy 폴링) 를 반드시 그대로 재사용해야 한다.**
- **`~/local-llm-settings/` 미러는 절대 손으로 편집하지 않는다.** 이 디렉터리는 "살아 있는
  기준점"의 스냅샷이며, 갱신 방향은 항상 live → mirror 다(`sync.sh`, 인자 없이). `sync.sh` 는
  이 phase 에서 `02-04` 플랜 한 번만 실행했다 — 다른 어떤 플랜도 mirror 를 건드리지 않았다.
