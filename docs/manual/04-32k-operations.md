# 04. 32K 운용 주의

근거 문서: docs/32k-compaction-policy.md §5·§7, docs/cline-max-tokens-findings.md,
docs/headless-wrapper.md §3, docs/cline-bench.md §4·§9.

이 문서는 **사용법**이다 — 왜/어떻게 검증됐는지는 위 근거 문서들을 볼 것, 여기서는 반복하지 않는다.

CLI·Kanban·Telegram 어디로 작업을 넣든, flashnext(29K 설정) 위에서는 공통으로 이 네 가지를
겪는다: 64초 근처의 조용한 대기, 자동으로 도는 압축과 그 지연, `contextWindow` 를 넣는 위치,
그리고 터치 기기에서 ⌘+클릭이 안 되는 것. 이 문서를 언제 열어보나: 세션이 길어질 때, 카드가
오래 멈춰 있을 때, 서버 오류가 뜰 때, 그리고 iPad/iPhone에서 뭔가 클릭이 안 될 때.

## 1. ~64초 프리필 대기 — 멈춤이 아니라 정상

32K 근처까지 채워진 요청은 모델이 답을 만들기 전 입력을 처리하는 프리필(prefill) 자체가
오래 걸린다. 실측상 이 대기는 ~64초까지 조용할 수 있다 — 화면에 아무 것도 새로 뜨지 않는다.

이걸 "멈췄다"와 구분하는 법:

- **Kanban**: 카드가 계속 In Progress 에 머문다. 에러 상태로 넘어가지 않는다.
- **Telegram**: 아무 새 메시지도 뜨지 않는다 — 타이핑 표시기는 메시지 하나당 딱 한 번만
  발화하고, Telegram 자체가 그 표시를 약 5초 뒤에 소멸시키며, 재발화 루프가 전혀 없다. 그래서
  Telegram 화면도 프리필이 끝날 때까지 조용하다.
- 실제 응답 스트리밍은 **프리필이 끝난 다음에만** 시작된다 — 스트리밍이 안 보인다고 죽은 게
  아니라, 아직 프리필 중이라는 뜻이다.

판단 기준: ~64초 안의 침묵은 정상 범위다. **그보다 훨씬 길게(수 분 이상) 넘어가면**, 아무것도
끄거나 재시작하기 전에 먼저 상시 게이트부터 돌려본다:

```
bash phase-05/services/verify_services.sh
bash phase-06/net/verify_network.sh --baseline phase-06/results/20260830T051403Z-baseline
```

두 게이트가 전부 PASS 면 문제는 이 대기 자체가 아니라 다른 곳에 있다는 뜻이니, §5(서버 400)와
§8(어디를 보나) 로 넘어간다.

## 2. 압축은 자동으로 돈다

컨텍스트가 트리거를 넘으면 Cline 이 대화를 스스로 요약해 압축한다 — 사용자가 따로 시킬 필요가
없다. 이 스택의 설정은 `settings.contextWindow = 29000` → 트리거 `26100`(× 0.9, 한 번만이다 —
× 0.81 두 단계 폴백이 아니다. 그 폴백은 `maxInputTokens` 가 없을 때만 쓰이는데, 이 구성에서는
`contextWindow` 가 그대로 `maxInputTokens` 로 넘어가므로 해당하지 않는다).

압축이 도는 턴은 그 자체로 짧은 요약 호출(실측 ~458 토큰)을 하나 더 만든다 — 즉 **압축 자체가
추가 지연을 낳는다.** 이게 사용자가 인식해야 할 두 번째 종류의 정상 멈춤이다: §1의 프리필
대기와는 별개로, "지금 압축이 돌고 있어서" 잠깐 더 걸리는 순간이 있을 수 있다.

※ 2026-08-31 정정(범위 좁힘) — 위 설명은 압축이 **발동한다**는 사실만 보증한다. 실제
cline-bench 워크로드에서 캡처된 압축 완료 이벤트 2건은 **메시지를 하나도 지우지 않았고
(요약만 얹혔다) 토큰이 오히려 늘었다** — 그 결과 이 스택은 모델에 도달한 cline-bench 과제
3개 전부에서 32K 천장에 부딪혀 죽었다(§7). "압축이 돈다"를 "압축이 벽 충돌을 막아준다"로
읽지 말 것. 증거: `phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md`,
`phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md`.

## 3. ⚠️ [GAP-COMPACTION-CONFIG] contextWindow는 반드시 이 칸에

`contextWindow` 는 `providers.json` 의 **`settings` 최상위**에 있어야 한다.

```jsonc
// 맞음
"settings": { "provider": "openai-compatible", "model": "flashnext", "contextWindow": 29000 }

// 틀림 — CLI가 안 읽는다
"settings": { "models": [ { "id": "flashnext", "contextWindow": 32768 } ] }
```

`models[]` 는 VS Code 용 per-model override 경로이지, CLI 가 읽는 경로가 아니다. 값을 저기 넣는
것이 정확히, 이 프로젝트가 한때 냈던 "32K 에서 작업이 죽는다"는 (지금은 철회된) 결론을 만든
오설정이었다.

`29000` 인 이유는 `32768` 이 아니라서다 — 압축은 트리거를 넘는 즉시 발동하지 않고 한 턴 늦게
반응해 실측 ~3,100 토큰의 오버슈트가 생긴다. `contextWindow` 를 올리고 싶다면
`trigger + 3,100 + max_tokens < MAX_KV_SIZE` 를 다시 만족시켜야 한다.

이 설정이 맞는 칸에 있는지 상시로 확인하는 한 줄:

```
bash phase-01/config/verify_config.sh
```

## 4. "작업 예산 / 태스크 쪼개기" 조언은 폐기됐다

이전에는 대화를 대략 26k 토큰 이하로 유지하고, 큰 작업은 작은 작업으로 쪼개라는 조언이
있었다. **이 조언은 2026-08-30 정정으로 폐기됐다** — 압축이 정상 작동해 대역을 유지하므로 더
이상 필요 없다. 필러 18개, 누적 30,000 토큰을 넘는 시나리오에서 긴 세션이 실제로 완주함이
실측으로 확인됐다(§2, 근거 문서 §5).

이 문서는 이 폐기된 조언을 어디에서도 다시 지침으로 내지 않는다 — "그냥 혹시 몰라서" 포함해서.
지금 규칙은 단순하다: 세션을 미리 자르지 말고, §1·§2 의 정상 지연을 인식하고, §5 의 터미널
실패가 뜨면 그때만 새로 시작한다.

※ 2026-08-31 추가 — Phase 7 gap-closure(07-11~07-16)가 실제 워크로드에서 압축이 프루닝하지
않는 결함(§2 정정, §7)을 찾았다. 이 발견은 위 폐기 결정을 되돌리지 않는다 — 사용자는 이
결과를 보고도 `doc-only`(설정·조언 변경 없음)를 선택했다. 근거:
`phase-07/results/20260831T011037Z-remediation/DECISION.md`.

## 5. 서버 400은 회복 불가 — 재시도하지 말고 다시 시작

설정이 잘못된 칸(§3)으로 되돌아가면, 서버가 `MAX_KV_SIZE`(32768) 초과로 HTTP 400 을 다시
거부하기 시작한다. Cline 자신의 오류 분류기는 이 서버가 실제로 보내는 오류 문구를 인식하지
못한다(하드코딩된 정규식 8개 전부 불일치) — 그래서 **자가 복구가 없다.**

**터미널 실패다. 재시도하지 말고, 기다리지 말고, 작업을 다시 시작한다.**

헤드리스 래퍼(`phase-04/run_headless.sh`)를 통해 이게 어떻게 보이는지: outcome
`context_overflow_terminal`, exit code `5` (docs/headless-wrapper.md §3). Kanban/Telegram
어느 표면에서 보든 결론은 같다 — 죽은 작업을 되살리려 하지 말고 새로 시작한다.

## 6. ⌘+클릭이 터치에서는 안 된다

iPad/iPhone 의 Safari 에는 모디파이어(⌘) 클릭이 없다. CLI/Kanban 사용법 중 "⌘+클릭으로 새 탭에서
연다" 같은 절차를 만나면, 터치에서는 **롱프레스 → "새 탭에서 열기"** 로 바꾸거나, 그 조작만은
Mac 에서 한다. 모바일 화면의 나머지 사용법은 모바일 사용법 문서(`03-mobile.md`)를 참고한다.

## 7. ⚠️ [GAP-BENCH] cline-bench 는 이 스택을 아직 통과하지 못했다

정확히 이 세 문장만 사실로 쓸 수 있다(근거: docs/cline-bench.md §9):

1. cline-bench 공식 과제의 요청이 이 스택의 flashnext/litellm 체인에 실제로 도달한다.
2. 파이프라인(설치 → 실행 → 검증)이 서로 다른 4개 과제에 대해 반복적으로 동작했다.
3. 이 스택은 관측된 3개 과제 어디에서도 32K 컨텍스트 예산 안에서 과제를 완료하지 못했다 —
   **통과 0개**다.

※ 2026-08-31 추가(gap-closure 2, 07-11~07-16; 판정 변경 없음) — 이 3개 과제는 하나의
원인이 아니라 최소 두 가지 서로 다른 메커니즘으로 죽었다: `telegram-plugin-refactor` 는
압축이 정시에 발동했지만 프루닝 없이 요약만 얹었고, 곧바로 이어진 단일 tool 호출(줄범위
제한 없는 `read_files`)이 그 자체로 ~11,764 토큰을 더해 벽을 5,435 토큰 넘겼다.
`v-edit-workspace-tests` 는 압축이 한 번 발동한 뒤 4턴 연속으로 건너뛰며 서서히 벽까지
기어올라 123 토큰 차이로 넘었다. `discord-trivia-approval-keyerror` 는 459 토큰 차이로
넘었으나 어느 메커니즘인지는 측정되지 않았다(indeterminate). 이 3개 과제의 판정
(`fail-context`) 을 매기던 분류기는 원래 `\b400\b` 단순 매치였고 위양성·위음성이 모두
있는 불건전한 분류기였음이 감사로 드러났으나, 수리된 분류기로 저장된 5개 실행 인스턴스를
전부 재분류한 결과 **판정은 0건도 바뀌지 않았다** — 위 세 판정은 정확했다. 근거:
`phase-07/results/20260831T003728Z-context-forensics/CONTEXT-FORENSICS.md`,
`phase-07/results/20260831T004024Z-classifier-audit/CLASSIFIER-AUDIT.md`,
`phase-07/results/20260831T010013Z-reclassify/RECLASSIFICATION.md`.

다음 문장들은 절대 쓰지 않는다: cline-bench 가 통과했다, 공식 스위트가 검증됐다, 온와이어
프롬프트가 캡처됐다, BCH-01 이 충족됐다, 이 스택이 cline-bench 과제를 완료할 수 있다. 이
문서를 고치는 사람은 새 문장을 추가하기 전에 `docs/cline-bench.md` §9 를 다시 읽을 것.

## 8. 이럴 때는 어디를 보나

| 증상 | 문서/명령 |
|---|---|
| ~64초 넘게 조용함, 카드가 그래도 In Progress | 이 문서 §1 — `phase-05/services/verify_services.sh`, `phase-06/net/verify_network.sh` |
| 서버 400, 또는 작업이 갑자기 끝나버림(`context_overflow_terminal`) | 이 문서 §5, docs/headless-wrapper.md §3 |
| `contextWindow` 관련 이상 동작, 압축이 전혀 안 뜸 | 이 문서 §3 — `phase-01/config/verify_config.sh` |
| iPad/iPhone 에서 ⌘+클릭이 안 먹힘 | 이 문서 §6, `03-mobile.md` |
| cline-bench 관련 주장을 확인하고 싶을 때 | 이 문서 §7, docs/cline-bench.md §9 |
| 압축/프리필과 무관한 다른 이상 | `01-cli.md`, `02-kanban.md` |
