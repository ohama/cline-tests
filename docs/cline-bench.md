# Phase 7 cline-bench 동작 검증 기록 (BCH-01~03)

## 1. 결론 (한 줄)

`harbor run --env docker` 로 이 스택 위에서 실제로 실행된 공식 cline-bench 과제는 두 런
디렉터리(수정 전 `bench/runs/20260830T093657Z-phase07/`, 수정 후
`bench/runs/20260830T122809Z-phase07-fix/`)를 통틀어 **고유 4개**
(`discord-trivia-approval-keyerror`/`telegram-plugin-refactor`/`filmarchiver`/
`v-edit-workspace-tests`; 실행 인스턴스로는 5회 — `discord-trivia-approval-keyerror` 는 수정
전/후 두 번 시도된 동일 과제 1개이지 두 개의 다른 과제가 아니다), 이 중 **3개가 이 스택의
모델 서버(flashnext)에 실제로 도달**했고, 통과는 여전히 **0개**다. 이전 버전의 이 문서는
"cline-bench 가 이 스택을 검증하지 못했다"고 적었다 — 그 문장의 절반은 더 이상 사실이 아니다:
파이프라인은 이제 flashnext 에 실제로 도달함이 실측으로 증명됐다(§4). 나머지 절반은 그대로다:
아직 통과한 과제가 하나도 없고, 공식 12개 과제 풀 중 4개(33.3%)만 시도됐다. 모델에 도달한 3개
전부 이 스택의 32K 컨텍스트 천장(`MAX_KV_SIZE=32768`)에서 거부됐다 — 아래 4절이 그 전말이다.

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
| 실제 실행된 과제(두 런 디렉터리 통틀어) | 고유 **4개** — `discord-trivia-approval-keyerror`(easy, 2회 시도)/`telegram-plugin-refactor`(easy)/`filmarchiver`(medium)/`v-edit-workspace-tests`(hard); 실행 인스턴스로는 5회 |
| 모델 스펙 | `openai-compatible:flashnext` |
| 왜 README 의 `openai:` 가 아닌가 | `openai-compatible` 은 cline 빌트인 프로바이더 테이블에 실제로 등록된 id 이자 이 프로젝트가 이미 검증한 id(`phase-01/config/cline-invocation.env`)다. 순수 `openai` id 는 cline 빌트인 테이블에서 발견되지 않았다(07-RESEARCH.md Pitfall 3) |
| `BASE_URL` | `http://host.docker.internal:4000/v1` — colima 가 이 이름을 호스트 loopback 으로 프록시하므로 litellm 의 `127.0.0.1` 전용 바인딩을 바꾸지 않고도 컨테이너에서 도달 가능함을 실측(07-01) |
| `--agent-kwarg cline-version=3.0.53` | 지정됨. **실제로 준수됨** — 컨테이너 내부 설치 로그(`agent/setup/install-agent-runtime.log`)가 `3.0.53` 설치와 스모크 테스트 통과를 확인한다. 이 컨테이너 설치는 아래 호스트 드리프트와 무관하다 |
| contextWindow/baseUrl 주입 메커니즘(수정 후, 07-07 적용) | `cline-cw-providers.json` 에 최상위 `"version": 1` 과 provider 별 `"updatedAt"`(ISO8601)을 추가 — cline 3.0.53 의 영속 설정 스키마가 요구하는 두 필수 필드였다. 이전 값(경로/주석 조정만)은 이 두 필드가 없어 침묵 거부됐다(07-06 진단, 아래 §4) |
| 호스트 `cline` 바이너리 드리프트 | 호스트(다윈) `cline` 이 어느 시점엔가 **3.0.60** 으로 드리프트됨(사전 존재하는 상태, 이 phase 가 만든 것이 아니며 이 phase 는 수정하지 않는다) — 07-02 의 원래 `INJECTABLE` 판정이 바로 이 드리프트된 바이너리를 정적 분석해 나온 것이었음이 07-06 에서 드러났다. 컨테이너의 핀 고정 3.0.53 설치는 이 드리프트의 영향을 받지 않는다 |

07-02 의 원래 `VERDICT: INJECTABLE` 은 호스트의 `cline` 바이너리를 정적 분석해 도출됐는데, 그
바이너리는 이미 3.0.60 으로 드리프트돼 있었다(컨테이너가 실제로 설치하는 핀 버전은 3.0.53).
이 버전 불일치(H1 가설)는 07-06 에서 실측으로 **기각**됐다: 컨테이너와 동일 플랫폼
(linux-arm64)의 3.0.53/3.0.60 바이너리를 나란히 스캔한 결과, 주입 프리미티브
(`CLINE_PROVIDER_SETTINGS_PATH` 리졸버, `getProviderConfig()`, 영속 설정 스키마와 그 침묵
폴백 `read()`)는 두 버전에서 구조적으로 동일했다 — 두 버전 사이에서 발견된 유일한 차이는 이
주입과 무관한 기능("modes") 하나뿐이었다. **진짜 원인은 버전이 아니라 스키마였다**:
`cline-cw-providers.json` 이 필수 필드(`version`/`updatedAt`)를 빠뜨려 cline 의
`ProviderSettingsManager.read()` 가 검증 실패 시 경고 없이 빈 provider 레지스트리로 조용히
폴백하고 있었다(07-06 `DIAGNOSIS.md`, `ROOT_CAUSE: schema-rejected`). 07-07 이 그 두 필드를
추가하는 것으로 문제를 고쳤다 — 아래 4절이 그 실측 증거다. **버전 스큐 가설은 닫힌 질문이며
다시 열어서는 안 된다.**

## 3. 어떻게 재현하나

네 스크립트가 전부다. 모두 `phase-07/bench/config.env` 를 단일 출처로 삼는다.

```bash
bash phase-07/bench/install_bench.sh                    # harbor + cline-bench 설치(멱등)
bash phase-07/bench/run_task.sh <task-suffix>            # 과제 1개 실행, --dry-run 으로 명령만 확인 가능
bash phase-07/bench/make_summary.sh                       # BCH-03 표 재생성
bash phase-07/bench/injection_probe.sh --results-dir <dir> [--with-model-call]  # 주입 메커니즘 자체를 모델 비용 없이(R1-R3), 또는 --with-model-call 로 실제 1회 검증(R4)
```

재실행 가능한 상시 게이트 — **두 런 디렉터리 모두**:

```bash
bash phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T093657Z-phase07      # 수정 전(pre-fix) 시대
bash phase-07/bench/verify_bench.sh --run-dir bench/runs/20260830T122809Z-phase07-fix  # 수정 후(post-fix) 시대
```

Phase 8 이 이 phase 의 산출물을 다시 검증하고 싶을 때 재실행해야 할 명령이 정확히 이것이다.

## 4. ⚠️ 한계

**이 절이 이 문서에서 가장 눈에 띄어야 한다.**

- **과제 풀은 12개이지, ~89개가 아니다.** 두 런 디렉터리를 통틀어 실행한 고유 4개는 라이브 풀
  12개의 **33.3%**다(수정 전 문서는 8.3%라고 적었다 — 그때는 1개뿐이었다) — 공식 전체 스위트의
  일부에 불과하며, 부분 실행이라는 사실 자체는 바뀌지 않았다.
- **5~8개 실행이 계획이었지만, 실제로는 고유 4개만 실행됐다(실행 인스턴스로는 5회).** 07-03 의
  1차 비용 결정 체크포인트에서 사용자가 `stop-at-one` 을 선택했다. 사용자의 이유를 그대로
  옮긴다: *"the invocation shape is identical for every task, so more runs would very likely
  reproduce the same structural fail-infra — buying repeated evidence of one known limitation
  rather than more passes."* 07-06/07-07 이 그 구조적 `fail-infra` 의 원인을 고치고 주입
  메커니즘이 실제로 동작함을 증명한 뒤, 07-08 의 2차 체크포인트에서 사용자의 응답("Continue",
  다섯 옵션 중 어느 것도 verbatim 으로 명명하지 않음)이 오케스트레이터에 의해 `plus-three` 로
  **해석**됐다(`decision2.md` 가 이를 07-03 의 verbatim 인용과는 다른, 더 낮은 증거 기준의
  해석으로 명시적으로 구분해 기록한다). 07-09 가 세 과제를 추가 실행했다. 그 결과 고유 과제
  수는 **1(discord-trivia) + 3(plus-three) = 4** 이지 5 가 아니다 —
  `discord-trivia-approval-keyerror` 는 수정 전/후 두 번 시도된 동일 과제 1개이지 두 개의 다른
  과제가 아니기 때문이다(07-08 이 계획 자신의 "총 5개 도달" 문구가 런 인스턴스 카운트였음을
  자체 발견해 정정한 산술, 07-10 도 반복하지 않는다). 4는 여전히 5~8 범위의 하한에 1개 못
  미친다 — **ROADMAP criterion 1 은 `phase-07/results/<UTC>-phase-close-2/criteria2.md` 에서
  명시적으로 `not_met` 으로 기록된다.** 이 4개를 5~8 범위를 만족하는 것으로 승격하지 않는다.
- **수정 전(`bench/runs/20260830T093657Z-phase07/`) 시대: 이 런의 유일한 과제는 이 스택의
  모델 서버에 끝내 도달하지 못했다.** flashnext 서버 로그의 byte-offset 슬라이스가
  **0바이트**였다 — 이 232초 실행 동안 flashnext 로 들어간 요청이 단 하나도 없었다는 뜻이다.
  대신 컨테이너의 cline 은 실제 OpenAI 기본 엔드포인트를 호출했고, OpenAI SDK 자신의 에러
  문구(`"Incorrect API key provided... platform.openai.com/account/api-keys"`)로 실패했다.
  07-06 이 이 실패를 실측(container-side, 모델 비용 0)으로 진단했다: `cline-cw-providers.json`
  이 cline 3.0.53 의 영속 설정 스키마가 요구하는 최상위 `version` 과 provider 별 `updatedAt`
  을 빠뜨렸고, `ProviderSettingsManager.read()` 가 검증 실패 시 경고 없이 빈 provider
  레지스트리로 조용히 폴백하고 있었다(`ROOT_CAUSE: schema-rejected`). 이 진단 과정에서 07-02
  의 원래 `INJECTABLE` 판정이 이미 3.0.60 으로 드리프트된 호스트 바이너리를 분석해 나온
  것이었다는 사실도 드러났다(§2) — 그러나 같은 플랫폼(linux-arm64)의 3.0.53/3.0.60 대조
  스캔으로 버전 자체는 원인이 아님이 확인됐다(`H1_VERDICT: ruled-out`, 07-06). 하네스 버그가
  아니라 cline 레벨의 스키마 거부였다.
- **수정 후(`bench/runs/20260830T122809Z-phase07-fix/`) 시대: 이제 증명된 것은 cline-bench
  과제의 요청이 실제로 이 스택의 flashnext 에 도달한다는 것이다.** 07-07 이 두 누락 필드를
  추가하는 최소 수정을 적용하고 `discord-trivia-approval-keyerror` 를 다시 실행해
  `SLICE_BYTES=145133`(수정 전 0바이트) / `MODEL_TURNS=38`(수정 전 0) 을 실측했다
  (`phase-07/results/20260830T122700Z-injection-fix/PROOF.md`). 07-09 가 서로 다른 두 과제
  (`telegram-plugin-refactor`, `v-edit-workspace-tests`)에서 동일한 도달을 재현했다 — 이제
  난이도 easy/easy/hard 를 아우르는 3개 과제에서 관측된 사실이지, 한 과제의 우연이 아니다.
  **아직 증명되지 않은 것: 이 스택 위에서 cline-bench 과제가 실제로 완료(통과) 가능한지** —
  그것만이 `pass` 판정으로 보여줄 수 있는데, P 는 여전히 0이다(아래 불릿). 네 번째 과제
  (`filmarchiver`)는 모델에 아예 도달하지 못했다 — 그러나 이유는 주입 메커니즘과 무관하다:
  컨테이너의 `bun install` 이 `CPU lacks AVX support` 로 세그폴트했다(colima 가상화 환경에서
  x86_64 Bun 바이너리가 AVX 를 못 찾음), cline 이 호출되기도 전에 죽은 별개의 인프라 결함이다
  (재시도 안 함 — 재시도해도 동일 결과가 동일 비용으로 반복될 뿐, 새 정보를 사지 않는다).
- **모델에 도달한 과제 3개 전부, 예외 없이, 이 스택의 32K 컨텍스트 천장에서 거부됐다.**
  `discord-trivia-approval-keyerror`(38턴, `max_prompt_tokens=30463`),
  `telegram-plugin-refactor`(6턴, `max_prompt_tokens=21036`),
  `v-edit-workspace-tests`(12턴, `max_prompt_tokens=30696`) — litellm 이 다음 요청을
  `Error code: 400`(`"...but MAX_KV_SIZE is 32768"`)으로 거부하며 셋 다 `fail-context` 로
  끝났다. 07-08 체크포인트 시점에는 이것이 n=1 에서 관측된, 한 과제 특유의 현상일 수도 있다는
  점이 명시적으로 미확정이었다(`cost.md` §5의 "unknown at n=1" 문구). 지금은 n=3 에서
  관측됐다. **이것은 아마 이 phase 가 배운 가장 유용한 사실이다: (적어도 이 3개) cline-bench
  과제는 이 스택의 컨텍스트 예산을 초과한다.** `docs/32k-compaction-policy.md` 가 이미 문서화한
  호스트 측 32K 벽과 같은 종류의 제약이 harbor 컨테이너 내부에서도 그대로 재현된다.
- **"벤치가 돌았다"는 "벤치가 통과했다"가 아니다.** `fail-infra` 행 하나는 스택이 실제로 동작함을
  보여주는 증거가 될 수 없다 — 이 구분을 이 문서 전체에서 유지한다.
- `docs/32k-compaction-policy.md` 는 **호스트** 설정(최상위 `contextWindow: 29000`, 정상 작동
  실측 완료)에 관한 문서다. harbor 컨테이너 내부에는 별도로 적용된다 — 주입이 성공한 지금,
  컨테이너의 cline 은 이 phase 가 자체 작성한 `providers.json`(동일 스키마, 동일 값)을 실제로
  읽는다. 호스트 파일을 직접 읽는 것은 아니다. 이 문서를 읽는 사람이 "압축이 컨테이너 안에서
  깨졌다"거나 "컨테이너가 호스트 설정 파일을 공유한다"고 오해하지 않도록 명시적으로 적어둔다.
- **온와이어 시스템 프롬프트는 여전히 캡처되지 않았다.** 수정 전 실행은 첫 요청에서 실패해
  애초에 캡처될 기회가 없었다. 수정 후 실행은 38/6/12턴을 성공적으로 돌았음에도
  `system-prompt-probe.txt` 는 세 과제 모두 여전히 `SYSTEM_PROMPT_IN_TRANSCRIPT: no` 다 —
  cline 자신의 트랜스크립트 포맷이 system 롤 줄을 남기지 않기 때문이며, 첫 요청 실패와는
  무관한 별개의 사실임이 이번에 드러났다. 남은 대안(litellm/role-shim 의 request-body 로깅)은
  여전히 라이브 서비스 재시작이 필요해서 이 phase 범위 밖으로 두고 의도적으로 켜지 않는다.
- **`pass` 행 하나든 `fail-context` 행 셋이든, 시도되지 않은 나머지 과제에 대해서는 아무것도
  말해주지 않는다.** 이번에 관측된 3개의 `fail-context` 는 이 스택의 32K 천장이 구조적임을
  강하게 시사하지만, 나머지 8개 미시도 과제(위 표의 `not-run` 행들)가 전부 같은 운명일
  것이라고 추론할 근거로 쓰지 않는다.

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
`--max-num-seqs 1` 서버 큐에 함께 줄을 서기 때문이다. 수정 전 실행(`model_turns=0`)에서는 이
경합이 원리상으로만 예상됐을 뿐, 모델에 도달하지 못했으므로 실제로는 발생하지 않았다. 수정
후에는 다르다: 세 과제가 실제로 56턴(38+6+12)의 모델 생성을 이 스택에서 소비했고, 대응하는
`harbor run` 들이 각각 약 27.7분(`discord-trivia-approval-keyerror`, 재실행)/6.2분
(`telegram-plugin-refactor`)/9.8분(`v-edit-workspace-tests`)의 벽시계 시간을 썼다
(`PROOF.md`, `phase-07/results/20260830T170042Z-gap-batch/ledger.tsv`) — 이 시간 동안
Kanban/Telegram 큐잉 경합이 실제로 발생했을 것이다. 다만 그 경합 자체(응답 지연의 폭 등)를
별도로 계측하지는 않았다 — 예상된 동작이며 회귀가 아니라는 결론은 그대로다.

## 7. 제거 방법

이 phase 가 설치한 모든 것을 지우는 문자 그대로의 명령:

```bash
uv tool uninstall harbor
rm -rf bench/cline-bench
rm -rf phase-07/results/*/scratch-cline-*/   # 07-06 이 H1 진단용으로 언팩한 ~400MB cline 3.0.53/3.0.60 바이너리 트리(gitignored, 텍스트 증거만 추적됨)
docker rmi injection-probe-cline353:latest   # 07-06 이 R3 프로브용으로 빌드한 ~2.4GB 이미지
docker builder prune        # 벤치 과제 Dockerfile 들의 빌드 캐시 회수
```

`docker image prune` 이 아니라 `docker builder prune` 인 이유: harbor 는 각 트라이얼 종료 후
그 트라이얼이 만든 태그된 이미지 자체를 이미 삭제한다(07-09 실측: 갭 배치 전/후
`docker images` 출력이 바이트 단위로 동일 — 남아 있는 벤치 이미지가 하나도 없다). 회수할 수
있는 것은 이미지가 아니라 Docker 의 빌드 캐시다(07-09 실측 6.858GB reclaimable).

**`bench/runs/` 는 이 recipe 로 지우지 않는다** — 그 디렉터리는 이 phase 의 증거(카나리아
포함)이지 설치 산출물이 아니다. 지우고 싶다면 그건 별도의, 명시적인 결정이어야 한다.

## 8. 증거 인덱스

| 무엇 | 경로 |
|---|---|
| 수정 전 실행 결과 디렉터리(프롬프트/결과/서버로그 슬라이스/메타) | `bench/runs/20260830T093657Z-phase07/` |
| 수정 전 BCH-03 표 | `bench/runs/20260830T093657Z-phase07/summary.md` |
| BCH-02 프롬프트+결과 인덱스(수정 전) | `bench/runs/20260830T093657Z-phase07/prompts/INDEX.md` |
| 실행 설정 기록(수정 전) | `bench/runs/20260830T093657Z-phase07/config.json` |
| 설치 + 상시 게이트 프리플라이트 + 과제 인벤토리 | `phase-07/results/20260830T084629Z-preflight/`, `phase-07/results/20260830T085155Z-install/`, `phase-07/results/20260830T085301Z-inventory/` |
| contextWindow 주입 가능성 조사(원 판정, 이후 07-06 이 원인 재진단) | `phase-07/results/20260830T091118Z-ctxwindow/FINDING.md` |
| 스모크 실행 + 7문항 분석 + 1차 비용 결정(`stop-at-one`) | `phase-07/results/20260830T093515Z-smoke/ANALYSIS.md`, `.../decision.md` |
| 배치(빈 `SELECTED_TASKS`) + 사후 게이트 스윕 | `phase-07/results/20260830T101803Z-batch/README.md` |
| 1차 phase-close 게이트 스윕 + `criteria.md`(갭 클로저 이전, 이제 시대에 뒤처짐 — `criteria2.md` 참고) | `phase-07/results/20260830T103307Z-phase-close/` |
| 주입 실패 진단(H1~H5 판정, `ROOT_CAUSE: schema-rejected`) | `phase-07/results/20260830T113923Z-injection-diag/DIAGNOSIS.md` |
| 수정 적용 + 실측 증명(`SLICE_BYTES`/`MODEL_TURNS`, 32K 거부 로그 원문) | `phase-07/results/20260830T122700Z-injection-fix/PROOF.md` |
| 수정 후 실행 결과 디렉터리(고유 4개 과제, 5 인스턴스) | `bench/runs/20260830T122809Z-phase07-fix/` |
| 수정 후 BCH-03 표(모델 도달 카운트 포함) | `bench/runs/20260830T122809Z-phase07-fix/summary.md` |
| 2차 실측 비용 체크포인트 + 결정 기록 | `phase-07/results/20260830T141218Z-cost-checkpoint/cost.md`, `.../decision2.md` |
| 갭 클로저 배치(`plus-three` 3개 과제) + 사후 게이트 스윕 | `phase-07/results/20260830T170042Z-gap-batch/` |
| 2차(최종) phase-close 게이트 스윕 + `criteria2.md` + 과대주장 감사 | `phase-07/results/<UTC>-phase-close-2/` |

## 9. Phase 8 인계

Phase 8 의 매뉴얼 작성자가 **절대 쓰지 말아야 할 문장들**:

- "cline-bench 가 실행됐다"를 "cline-bench 가 통과했다"로 승격하는 어떤 문장도 안 된다 — 두 런
  디렉터리를 통틀어 통과 **0개**다.
- 공식 스위트 전체(또는 그 상당 부분)가 검증됐다고 서술하는 어떤 문장도 안 된다 — 12개 중
  고유 4개, 33.3%다.
- 온와이어 시스템 프롬프트가 캡처됐다고 서술하는 문장은 안 된다 — 모델에 도달한 과제에서도
  여전히 캡처되지 않았다(4절).
- BCH-01(공식 과제 5~8개 실행)이 충족됐다고 서술하는 문장은 안 된다 — 고유 과제 수는 4로,
  여전히 하한에 1개 못 미친다. `criteria2.md` 가 이를 `not_met` 으로 기록한다.
- **가장 중요한 한 줄(수정됨 — 이전 판은 이 문장이 반대 방향이었다): cline-bench 가 이
  스택(flashnext)을 "통과"했다거나, 공식 스위트가 "검증"됐다거나, 이 스택이 cline-bench
  과제를 "완료할 수 있다"고 서술하는 문장은 절대 안 된다.** 모델에 도달한 3개 과제 전부 이
  스택의 32K 컨텍스트 천장에서 거부됐다(4절) — 이는 이 스택이 아직 어떤 cline-bench 과제도
  완료하지 못했다는 뜻이다.

Phase 8 이 정확한 근거를 갖고 쓸 수 있는 문장(이번 gap-closure 로 새로 허용됨):

- "cline-bench 공식 과제의 요청이 이 스택의 flashnext/litellm 체인에 실제로 도달한다" —
  `PROOF.md` 의 `SLICE_BYTES=145133`/`MODEL_TURNS=38`, 그리고 07-09 의 두 독립 재현 사례로
  뒷받침된다.
- "이 스택은 (적어도 관측된 3개 과제에서는) cline-bench 과제를 이 스택의 32K 컨텍스트 예산
  안에서 완료하지 못했다" — 32K 천장이 모델에 도달한 모든 과제에서 관측된 유일한 실패 양상
  이라는 사실과 함께 써야 한다.
- "파이프라인(설치 → 컨테이너 빌드 → 주입 → 호출 → 검증 → 증거 번들)이 서로 다른 4개 과제에
  대해 반복적으로 동작했다."

Phase 8 이 이 phase 의 산출물을 다시 검증하려면 `phase-07/bench/verify_bench.sh` 를 **두 런
디렉터리 모두**에 대해 재실행하면 된다(3절의 두 명령 그대로) — 커밋된 실행 디렉터리 위에서
다시 돌 수 있는 상시 게이트로 남겨둔다.

---
*Phase: 07-cline-bench-verification*
*Completed: 2026-08-30*
