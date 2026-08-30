# Phase 7 cline-bench 동작 검증 기록 (BCH-01~03)

## 1. 결론 (한 줄)

`harbor run --env docker` 로 이 스택 위에서 실제로 실행된 공식 cline-bench 과제는 **1개**
(`discord-trivia-approval-keyerror`), 통과는 **0개**다. 프롬프트·결과·소요시간은 파일로 남아
있다. 이 1회 실행이 증명하는 것은 파이프라인(설치 → 컨테이너 빌드 → 에이전트 기동 → 호출 →
검증 → 증거 번들)이 끝까지 동작한다는 것뿐이며, 이 스택 위에서 cline-bench 과제가 실제로
완료 가능한지는 증명하지 못한다 — 아래 4절이 그 이유다.

## 2. 무엇을 실행했나

harbor 는 `harbor-framework/harbor`(Apache-2.0, Terminal-Bench 의 후속 프로젝트)다.
**CNCF 컨테이너 레지스트리 프로젝트(Harbor)와 이름만 같은 별개의 소프트웨어**임을 여기서
명시한다 — 둘을 혼동하지 말 것. cline-bench 는 과제 데이터(프롬프트 + 검증 스크립트)만
제공하고, 실제 실행 엔진은 harbor 다.

| 항목 | 값 |
| --- | --- |
| harbor 버전 | `0.22.0` |
| cline-bench 커밋 | `d1085569fb0ae3f9613957e6fc2706c6e2f7da9b` |
| 실측 라이브 과제 풀 크기 | **12개** (`bench/cline-bench/tasks/`, 이 phase 가 직접 클론해 실측 — 07-RESEARCH.md 가 적었던 14개도, 그 이전의 ~89개 추정치도 아니다. 연구 시점 클론과 이 phase 의 클론 사이 같은 날 안에 과제 디렉터리 2개가 줄었다) |
| 실제 실행된 과제 | `discord-trivia-approval-keyerror` (easy, `memory_mb=2048`) 1개뿐 |
| 모델 스펙 | `openai-compatible:flashnext` |
| 왜 README 의 `openai:` 가 아닌가 | `openai-compatible` 은 cline 빌트인 프로바이더 테이블에 실제로 등록된 id 이자 이 프로젝트가 이미 검증한 id(`phase-01/config/cline-invocation.env`)다. 순수 `openai` id 는 cline 빌트인 테이블에서 발견되지 않았다(07-RESEARCH.md Pitfall 3) |
| `BASE_URL` | `http://host.docker.internal:4000/v1` — colima 가 이 이름을 호스트 loopback 으로 프록시하므로 litellm 의 `127.0.0.1` 전용 바인딩을 바꾸지 않고도 컨테이너에서 도달 가능함을 실측(07-01) |
| `--agent-kwarg cline-version=3.0.53` | 지정됨. **실제로 준수됨** — 컨테이너 내부 설치 로그(`agent/setup/install-agent-runtime.log`)가 `3.0.53` 설치와 스모크 테스트 통과를 확인한다 |

## 3. 어떻게 재현하나

세 스크립트가 전부다. 모두 `phase-07/bench/config.env` 를 단일 출처로 삼는다.

```bash
bash phase-07/bench/install_bench.sh                    # harbor + cline-bench 설치(멱등)
bash phase-07/bench/run_task.sh <task-suffix>            # 과제 1개 실행, --dry-run 으로 명령만 확인 가능
bash phase-07/bench/make_summary.sh                       # BCH-03 표 재생성
```

재실행 가능한 상시 게이트:

```bash
bash phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07
```

Phase 8 이 이 phase 의 산출물을 다시 검증하고 싶을 때 재실행해야 할 명령이 정확히 이것이다.

## 4. ⚠️ 한계

**이 절이 이 문서에서 가장 눈에 띄어야 한다.**

- **과제 풀은 12개이지, ~89개가 아니다.** 이번에 실행한 1개는 라이브 풀 12개의 8.3%다 — 공식
  전체 스위트의 극히 일부이며, 부분 실행이라는 사실 자체가 바뀌지 않는다.
- **5~8개 실행이 계획이었지만, 실제로는 1개만 실행됐다.** 07-03 의 비용 결정 체크포인트에서
  사용자가 `stop-at-one` 을 선택했다. 사용자의 이유를 그대로 옮긴다: *"the invocation shape is
  identical for every task, so more runs would very likely reproduce the same structural
  fail-infra — buying repeated evidence of one known limitation rather than more passes."*
  이 1개를 5~8개 범위를 만족하는 것으로 승격하지 않는다 — ROADMAP criterion 1 은 6절/`criteria.md`
  에서 명시적으로 `not_met` 으로 기록된다.
- **이 1개 과제는 이 스택의 모델 서버에 끝내 도달하지 못했다.** flashnext 서버 로그의
  byte-offset 슬라이스가 **0바이트**다 — 이 232초 실행 동안 flashnext 로 들어간 요청이 단 하나도
  없었다는 뜻이다. 대신 컨테이너의 cline 은 실제 OpenAI 기본 엔드포인트를 호출했고, OpenAI SDK
  자신의 에러 문구(`"Incorrect API key provided... platform.openai.com/account/api-keys"`)로
  실패했다. 즉 07-02 의 `CLINE_PROVIDER_SETTINGS_PATH` 주입 메커니즘(판정 `INJECTABLE` — 설치된
  harbor 0.22.0 어댑터와 설치된 cline 3.0.53 바이너리의 소스만으로 도출됐고, 이 실행 전까지 한
  번도 라이브로 검증된 적이 없었다)은 **harbor 의 실제 호출 형태에서는 작동하지 않는다.**
  이 판정을 받아들이기 전, 추가 예산 없이 두 하위 레이어를 독립적으로 재검증했다 —
  docker-compose 머지가 해당 환경변수를 보존한다는 것과, `docker exec` 가 컨테이너 자신의
  환경을 그대로 물려받는다는 것 둘 다 각각 격리된 실측으로 확인됐다. 따라서 이건 하네스
  버그가 아니라, **cline 레벨에서 "실제로는 적용되지 않는다"는 확정 소견**이다.
- **증명된 것: 파이프라인 전체가 끝까지 동작한다는 것.** 설치 → 컨테이너 빌드 → 에이전트 기동
  → 호출 → 검증 → 증거 번들 수집까지, 실패한 과제 1개로도 전 과정이 끊기지 않고 완주했다.
  측정된 232초의 내역: `environment_setup` 141.5초, `agent_setup` 57.3초, `agent_execution`
  5.3초, `verifier` 12.4초 — 즉 약 86%가 과제당 반복되는 셋업 비용이고, 모델을 호출하려던
  시도 자체는 5.3초 만에 (실패로) 끝났다.
- **증명되지 않은 것: cline-bench 가 이 스택을 실제로 검증했다는 것.** 이 phase가 실행한 유일한
  과제는 flashnext 를 단 한 번도 건드리지 못했다. **Phase 8 의 매뉴얼은 cline-bench 가 이 스택을
  검증했다고 서술해서는 안 된다** — 9절에 이 사실을 다시 못박는다.
- **"벤치가 돌았다"는 "벤치가 통과했다"가 아니다.** `fail-infra` 행 하나는 스택이 실제로 동작함을
  보여주는 증거가 될 수 없다 — 이 구분을 이 문서 전체에서 유지한다.
- `docs/32k-compaction-policy.md` 는 **호스트** 설정(최상위 `contextWindow: 29000`, 정상 작동
  실측 완료)에 관한 문서다. harbor 컨테이너 내부에는 적용되지 않는다 — 컨테이너의 cline 은
  주입이 성공했더라면 별도의, 이 phase 가 자체 작성한 `providers.json`(동일 스키마, 동일 값)을
  읽었을 것이지, 호스트 파일을 읽지 않는다. 이 문서를 읽는 사람이 "압축이 컨테이너 안에서
  깨졌다"고 오해하지 않도록 명시적으로 적어둔다.
- **온와이어 시스템 프롬프트는 캡처되지 않았다.** 이 실행은 첫 요청에서 실패했으므로 cline 이
  시스템 프롬프트를 만들어내거나 전사할 기회 자체가 없었다(`system-prompt-probe.txt` →
  `SYSTEM_PROMPT_IN_TRANSCRIPT: no`). 남은 대안(litellm/role-shim 의 request-body 로깅)은
  라이브 서비스 재시작이 필요해서 이 phase 범위 밖으로 두고 의도적으로 켜지 않았다.
- **`pass` 행 하나는 실행되지 않은 나머지 과제에 대해 아무 것도 말해주지 않는다.** 이번 실행의
  `fail-infra` 행조차 실행되지 않은 11개 과제의 결과를 추론할 근거가 되지 않는다.

## 5. 보안·태세: 이 phase 가 건드리지 않은 것

- harbor 의 `cline-cli` 에이전트는 **harbor 자신의 일회용 Docker 컨테이너 안에서만** 완전
  자동승인으로 돈다 — 그 컨테이너가 harbor 자신의 샌드박스 경계이지, 이 프로젝트의
  `sandbox-exec` 경계가 아니다. `harbor run` 은 그래서 의도적으로
  `phase-03/sandbox/run_sandboxed.sh` 를 거치지 않는다 — 호스트의 `cline` 바이너리를 아예
  호출하지 않는다.
- 따라서 Phase 4·5·6 이 각각 눈에 띄게 남겨온 host-posture 이스케이프 질문 — 즉 헤드리스
  래퍼가 강제하는 `--auto-approve` 플래그를 뒤집을지 여부 — 는 **이 phase 에는 적용되지 않는다**.
  결정된 것이 아니라, "적용 대상 아님"으로 기록한다. 이 질문은 여전히 열려 있고, 호스트 표면을
  바꾸는 다음 사람의 몫이다.
- 저장소 화이트리스트 변수는 이 phase 내내 빈 값 그대로였다. 정확히 말하면: 그 환경변수 값은
  phase 시작부터 끝까지 빈 문자열이었다 — `bench/` 는 `workspace/ALLOWED_REPOS.json` 밖에
  남았고, SBX-04 의 카나리아 파일은 벤치가 결과를 쓴 뒤에도 다시 확인됐으며 여전히 샌드박스
  안에서 읽을 수 없다.
- 네트워크 노출 표면은 하나도 움직이지 않았다. Tailscale 관련해서 이 phase 가 실행한 명령은
  **없다** — mutating 커맨드는 물론, 상태를 바꾸는 어떤 명령도 호출되지 않았다. 공용으로 여는
  서브커맨드(`funnel`)도 이 phase 어디에서도 호출되지 않았다. 포트 3000 은 계속 미바인딩
  상태였고, litellm 은 계속 `127.0.0.1` 단독 바인딩을 유지했다. 컨테이너가 그래도 litellm 에
  도달할 수 있었던 것은 colima 가 `host.docker.internal` 을 호스트 loopback 으로 프록시하기
  때문이지, Phase 2 가 만든 네트워크 태세를 이 phase 가 바꿔서가 아니다.
- **Phase 6 이 넘겨준 kanban `~/.gitconfig` 샌드박스 블로커는 이 phase 에서 재발하지 않았다 —
  이 phase 가 kanban 에 아무 것도 등록하지 않고, kanban 을 한 번도 호출하지 않았기 때문이다.**
  그 항목은 여전히 열려 있고, 바뀐 것 없이, Phase 3/8 의 몫으로 그대로 남아 있다 — 이 인계가
  조용히 사라진 게 아님을 여기서 분명히 적는다.

## 6. 운영 부작용

벤치 배치가 도는 동안 Kanban 과 Telegram 은 느려진다 — 모든 모델 턴이 같은
`--max-num-seqs 1` 서버 큐에 함께 줄을 서기 때문이다. 이번 실행은 `model_turns=0`(모델에
도달하지 못했으므로)이라 실제로는 이 경합이 관측되지 않았지만, 원리상 예상된 동작이지
회귀가 아니다.

## 7. 제거 방법

이 phase 가 설치한 모든 것을 지우는 문자 그대로의 명령:

```bash
uv tool uninstall harbor
rm -rf bench/cline-bench
docker image prune          # 과제 Dockerfile 이 받은 이미지 회수 (harbor 가 자동으로 하지 않음)
```

**`bench/runs/` 는 이 recipe 로 지우지 않는다** — 그 디렉터리는 이 phase 의 증거(카나리아
포함)이지 설치 산출물이 아니다. 지우고 싶다면 그건 별도의, 명시적인 결정이어야 한다.

## 8. 증거 인덱스

| 무엇 | 경로 |
|---|---|
| 실행 결과 디렉터리(프롬프트/결과/서버로그 슬라이스/메타) | `bench/runs/20260830T093657Z-phase07/` |
| BCH-03 표 | `bench/runs/20260830T093657Z-phase07/summary.md` |
| BCH-02 프롬프트+결과 인덱스 | `bench/runs/20260830T093657Z-phase07/prompts/INDEX.md` |
| 실행 설정 기록 | `bench/runs/20260830T093657Z-phase07/config.json` |
| 설치 + 상시 게이트 프리플라이트 + 과제 인벤토리 | `phase-07/results/20260830T084629Z-preflight/`, `phase-07/results/20260830T085155Z-install/`, `phase-07/results/20260830T085301Z-inventory/` |
| contextWindow 주입 가능성 조사 | `phase-07/results/20260830T091118Z-ctxwindow/FINDING.md` |
| 스모크 실행 + 7문항 분석 + 비용 결정 | `phase-07/results/20260830T093515Z-smoke/ANALYSIS.md`, `.../decision.md` |
| 배치(빈 `SELECTED_TASKS`) + 사후 게이트 스윕 | `phase-07/results/20260830T101803Z-batch/README.md` |
| Phase-close 게이트 스윕 + `criteria.md` | `phase-07/results/<UTC>-phase-close/` |

## 9. Phase 8 인계

Phase 8 의 매뉴얼 작성자가 **절대 쓰지 말아야 할 문장들**:

- "cline-bench 가 실행됐다"를 "cline-bench 가 통과했다"로 승격하는 어떤 문장도 안 된다 — 통과
  0개다.
- 공식 스위트 전체(또는 그 상당 부분)가 검증됐다고 서술하는 어떤 문장도 안 된다 — 12개 중
  1개, 8.3%다.
- 온와이어 시스템 프롬프트가 캡처됐다고 서술하는 문장은 안 된다 — 캡처되지 않았다(4절).
- **가장 중요한 한 줄: cline-bench 가 이 스택(flashnext)을 검증했다고 서술하는 문장은 절대
  안 된다.** 이 phase 가 실행한 유일한 과제는 flashnext 에 단 한 번도 도달하지 못했다. 매뉴얼이
  서술할 수 있는 것은 파이프라인 메커니즘(harbor 호출, 증거 캡처, 판정 분류)이 증명됐다는
  것까지이며, 실제 cline-bench 과제가 이 스택의 flashnext/litellm 체인을 상대로 관측됐다는
  것은 아니다.

Phase 8 이 이 phase 의 산출물을 다시 검증하려면 `phase-07/bench/verify_bench.sh` 를 이 문서
3절의 인자로 그대로 재실행하면 된다 — 커밋된 실행 디렉터리 위에서 다시 돌 수 있는 상시
게이트로 남겨둔다.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
