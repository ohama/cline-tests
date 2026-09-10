# Requirements: v1.1 Plan/Act ↔ reasoning_effort

**Defined:** 2026-09-01
**Core Value (v1.1):** Plan 모드에서만 사고가 켜지고, 그것이 **실제로 도달했음이 증명**된다

설계·계획 근거: `docs/plan-act-reasoning-design.md` · `-implementation.md` · `-diagrams.md`

## v1.1 Requirements

### PRB — 사전 확인 (게이트, 스택 무변경)

- [x] **PRB-01**: `reasoning_effort: medium` 이 `:8011` 직결에서 실제로 응답에 `reasoning` 필드를
  만드는지 확인되고 결과가 기록된다
  <br>🔶 **2026-09-01 게이트에서 강등.** 별칭이 `enable_thinking: true` 를 함께 주입하도록
  바뀌었으므로(CFG-11), effort 단독으로 사고가 켜지지 않아도 마일스톤은 계속된다 — 조합이
  그 역할을 한다. 이 측정은 여전히 가치 있다: **"effort 하나로 충분한가"** 에 답하고,
  충분하다면 별칭을 단순화할 근거가 된다. 부정적이어도 **종료 사유가 아니다.**
  <br>🔴 남은 진짜 킬 컨디션은 **PRB-04** 하나다
- [x] **PRB-02**: `enable_thinking: false` 가 litellm 을 통과하는지 확인된다 →
  `flashnext-act` 별칭 생성 여부가 이 결과로 결정된다
- [x] **PRB-03**: effort 별 `prompt_tokens` 차이(미지정 23 / medium 21 / low 51 / xhigh 63)가
  재확인되어 도달 증명 오라클로 쓸 수 있음이 확립된다
- [x] **PRB-04**: 사고 트레이스가 다음 턴 컨텍스트로 되돌아오는지 실측된다
  <br>🔴 **게이트.** 누적되면 v1 의 "실제 부하에서 압축이 프루닝하지 않는다"와 겹쳐
  치명적이므로 마일스톤을 폐기한다

**✅ 2026-09-01 Phase 9 결과** — `phase-09/GATE-VERDICT.md`, 검증 32/32

| | 측정 | 판정 |
|---|---|---|
| PRB-01 | `medium` 단독 → `reasoning` **179자**; 미지정 대조군 → **0자** | 양성 (진단) |
| PRB-02 | `false` 는 거부 안 됨(200). `true` 대조군이 **실제 적용** 입증 | → CFG-12 근거 |
| PRB-03 | 6갈래 스윕 A/B 완전 일치. 델타는 선행 두 데이터셋과 정확히 일치 | 오라클 확립 |
| PRB-04 | 통제 리플레이 **16/16 이 `delta=0`**, `prompt_tokens=46` 고정 | **양성 — 킬 컨디션 미발동** |

**PRB-03 의 위 수치(23/21/51/63)는 낡았다.** 실측 절대값은 **13/11/41/53** 으로 이동했고,
델타(medium −2, low +28, xhigh +40)는 비트 단위로 보존됐다. 원인 미규명. **오라클은 절대값이
아니라 델타로만 쓸 것** — `PRB-03-ORACLE.md` §5.

**PRB-04 의 강도:** 실제 트레이스 2,497자를 넣어도 필드를 통째로 뺀 것과 토큰이 같다(46).
두 엔드포인트 · 두 필드명 전부. **길이 임계 효과 없음.**

**CFG-11 설계 전제가 반증됐다.** "effort 만으로는 사고가 켜진다는 보장이 없다"가 근거였으나,
PRB-01 은 `medium` 단독으로 켜짐을 보였고 PRB-03 은 `et-medium`=`medium`(11), `et-true`=`xhigh`(53)
로 **`reasoning_effort` 가 명시되면 `enable_thinking` 은 측정 가능한 변화를 만들지 않음**을 보였다.
주입은 무해하고 VALIDATED §4 권장과 일치하므로 **유지하되**, 근거는 "필요"가 아니라 "이중 안전장치"다.
CFG-16 의 질문도 이에 따라 좁아졌다 — `GATE-VERDICT.md` §3.2.

### CFG — 별칭과 주입

- [x] **CFG-11**: `flashnext-plan` 별칭이 **`enable_thinking: true` 와 `reasoning_effort: medium` 을 함께**
  주입한다 (~~Cline 은 `--thinking` 을 쓰지 않는다~~)
  <br>🔴 **2026-09-02 정정 — 괄호 안 전제가 지금은 거짓이다.** 3.0.53 에서는 참이었으나
  설치된 **3.0.60 에는 `--thinking <level>` 플래그가 실재한다**(`none|low|medium|high|xhigh`,
  `cline --help` 로 직접 확인). 클라이언트가 보낸 `reasoning_effort` 는 litellm 의 kwarg 병합
  순서상 **별칭이 주입한 값을 덮어쓴다.** 즉 사용자가 `--thinking` 을 쓰면 별칭 설계가
  우회된다. **Phase 11 의 래퍼는 `--thinking` 통과를 능동적으로 막아야 한다** — 플래그가
  없어서 안전하다는 가정은 더 이상 성립하지 않는다. 이는 CFG-05(자동 업데이트 미차단)의
  3차 피해다.
  <br>※ **2026-09-01 변경.** 원래는 `reasoning_effort` 만 주입할 계획이었다. `VALIDATED.md` §4 의
  권장이 *"중간 → `enable_thinking: true` + `reasoning_effort: medium`"* 으로 **두 파라미터를 함께**
  쓰라고 명시하고, `enable_thinking` 의 기본값이 `false` 이므로 effort 만으로 사고가 켜진다는 보장이
  없다. 실제로 `medium`(21) < 미지정(23) 이라는 시스템 프롬프트 길이 이상 징후가 그 의심의 근거다.
  두 개를 함께 넣으면 이 불확실성 자체가 사라진다
- [x] **CFG-12**: PRB-02 가 통과를 확인한 경우에만 `flashnext-act` 별칭이 만들어진다.
  통과하지 못하면 만들지 않고 그 사실이 기록된다
- [x] **CFG-13**: 기존 `flashnext` 별칭은 변경되지 않는다 (회귀 판정 기준선)
- [x] **CFG-14**: `drop_params: true` 를 쓰지 않는다 — 파라미터를 조용히 버려 200 을 만드는
  실패 모드이며, 이 프로젝트가 두 번 당한 것과 같은 종류다
- [x] **CFG-15**: 변경이 `~/local-llm-settings` 에 반영되고 `sync.sh` 결과에 나타난다
- [x] **CFG-16**: 별칭이 주입하는 **두 파라미터 조합**(`enable_thinking: true` + `reasoning_effort: medium`)이
  실제로 `reasoning` 필드를 만드는 것이 `:8011` 과 `:4000` 양쪽에서 확인된다
  <br>※ **2026-09-01 신설.** 이 조합은 이 스택에서 측정된 적이 없다. VALIDATED.md 의 권장은
  `:8000` 직결 시절 기록이다. 조합이 안 되면 별칭 정의를 고쳐야 하므로 Phase 10 안에서 답이 나야 한다

- [x] **CFG-17**: deprecated `qwen-*` 별칭 6개(`qwen-local`, `qwen-35b`, `qwen-122b`,
  `qwen-122b-claude`, `qwen-35b-claude`, `qwen-122b-codex`)가 라이브 설정에서 제거된다.
  `flashnext` 와 `flashnext-codex` 는 보존한다
  <br>※ **2026-09-01 사용자 지시.** 설정 파일 주석이 스스로 정한 삭제 조건("한동안 로그를 보고
  쓰이지 않으면 지운다")을 로그로 확인함 — **현 litellm 인스턴스 기동 이후 `qwen-*` 요청 0건,
  `flashnext` 163건.** 과거 기록의 요청은 전부 마지막 재기동 이전이며 대부분 404·
  `No deployments available` 로 실패한 것(별칭이 Flash-Next 로 재지정되기 전 흔적).
  <br>※ **Phase 10 유지보수 창에 합류.** 삭제도 재기동이 있어야 반영되므로 별도 실행하면
  Kanban·Telegram 이 두 번 끊긴다. 같은 백업·같은 롤백·같은 검증 사다리를 쓴다.
  <br>※ 삭제 범위는 라이브 설정 **34–50행**(빈 줄 + 주석 4줄 + 별칭 12줄). 남는 1–33행은
  `flashnext`(22행)와 `flashnext-codex`(29–33행)이며 **바이트 단위로 보존**된다(CFG-13).

### VRF — 도달 증명

- [x] **VRF-01**: 동일 사용자 메시지를 `flashnext` 와 `flashnext-plan` 으로 각각 보냈을 때
  서버 로그의 `prompt_tokens` 가 **다르다** — 주입이 실제로 도달했다는 증거
- [x] **VRF-02**: 판정 근거가 서버 측 증거이지 HTTP 200 응답이 아니다
- [x] **VRF-04**: **실제 `cline` CLI 실행**의 `--json` 스트림에 `reasoning` 이 나타나는지가
  `flashnext-plan` 과 대조군 양쪽에서 관측·기록된다
  <br>※ **2026-09-01 신설.** curl 은 *게이트웨이가 파라미터를 전달한다*만 증명한다.
  *Cline 이 그 경로로 실제 사고를 한다*는 별개이며, 리서치도 이를 "deferred, not done"으로
  명시했다(신뢰도 MEDIUM). v1 에서 설정은 기록됐는데 CLI 가 안 읽어 이틀을 쓴 전례가 있다.
  <br>※ 관측 결과가 부정적이어도 이 요구사항은 충족된다 — 관측이 요구사항이다
- [x] **VRF-03**: 재실행 가능한 검증 스크립트로 남는다 (일회성 확인이 아님)

### USE — 사용 표면과 문서

- [x] **USE-01**: `cline-plan` / `cline-act` 래퍼가 모드와 별칭의 짝을 강제한다
- [x] **USE-02**: `verify_config.sh` 가 짝 불일치와 `--thinking high` 사용을 잡아낸다
- [x] **USE-03**: `medium` vs 기본 A/B 결과가 기록된다. 개선이 없으면 래퍼 기본값을
  `flashnext` 로 되돌리고 그 판단을 남긴다
- [x] **USE-04**: `docs/manual/01-cli.md` 에 사용법이, `docs/cline-config-pins.md` 에 별칭과
  파라미터가 고정값으로 기록된다. **`--thinking` 이 현재 400 이라는 사실**도 명시된다
  <br>🔶 **2026-09-10 정정 — 위 "현재 400" 은 다섯 개 살아있는 별칭 중 정확히 하나에만
  맞는다.** 실측: `flashnext`(`openai/` 접두사)만 litellm 자신의 `UnsupportedParamsError` →
  **HTTP 400**. `flashnext-plan`/`flashnext-act`/`flashnext-reach-xhigh`(`hosted_vllm/`
  접두사)는 litellm 검증을 통과하고 **모델 서버가 500** 을 낸다. 래퍼를 거치지 않은 원시
  `cline --thinking high` 는 그 500 을 Cline 자신의 오류 이벤트로 표면화하며 **exit 1** 로
  끝난다 — 이 경로에서는 400 을 전혀 볼 수 없다. **요구사항 문장 자체는 고치지 않는다** —
  실측에 맞춰 조용히 재서술하면 반증 불가능해진다. 정확한 형태는
  `docs/cline-config-pins.md` §7.4 에 접두사별로 기록됐다. 근거:
  `phase-11/OPEN-ITEMS.md` Open Item 1, `phase-12/PHASE-12-FINDINGS.md` §2·§3.
- [x] **USE-05**: `docs/plan-act-reasoning-design.md` / `-implementation.md` 가 실측 결과로 갱신된다
  <br>✅ **2026-09-10 완료.** 상태 배지가 "제안/계획"에서 채택됨/구현됨으로 바뀌었고, 두 게이트
  판정(① 재첨부는 실재하나 토큰 비용 0, ② 개선 없음·`keep`은 사람의 override)이 이유와 함께
  기록됐다. `docs/plan-act-reasoning-diagrams.md` 도 같은 정정을 받았다(요구사항이 이름을
  붙이진 않았으나 같은 3층 설계 문서군). 근거: `phase-12/PHASE-12-FINDINGS.md` §1·§2.

## Future Requirements (v1.2+)

- **`--compaction basic` 검증** — 근인 행렬이 지목한 유일한 유망 미테스트 지렛대
- **CFG-05** — `CLINE_NO_AUTO_UPDATE=1` 이 듣지 않는 문제의 실질적 해결
- **Kanban·Telegram 표면 적용** — 커넥터의 `mode: act|plan` 옵션 활용
- **Phase 1 VERIFICATION.md 보강** — v1 의 유일한 미검증 페이즈
- **`flashnext-reach-xhigh` 제거** — 2026-09-10, `phase-12/SCOPE-DECISIONS.md` 3번 항목에서
  결정. 검증 전용 별칭이라 사용 표면이 아니지만, 제거하려면 litellm 재기동이 한 번 더
  필요하고 그 재기동은 Kanban/Telegram 서비스의 또 한 번의 중단을 의미한다 — **남겨 두는
  데는 비용이 없다.** v1.2+ 유지보수 창에서 함께 처리할 후보로 남긴다.

## Out of Scope

| Feature | Reason |
|---------|--------|
| `allowed_openai_params` 로 `--thinking` 통과시키기 | 별칭 주입이 더 단순하고 Cline 무수정. 400 을 만나지 않는다 |
| `drop_params: true` | 파라미터를 조용히 버린다. 200 이 나오지만 아무 일도 안 일어난다 |
| role_shim 에서 프롬프트로 모드 추론 | Cline 내부 시스템 프롬프트 문자열에 결합. 자동 업데이트(CFG-05 미해결)로 조용히 깨진다 |
| Cline 포크 | 별칭으로 충분하다. v1 에서 contextWindow 때 검토했다가 설정으로 해결된 전례 |
| `thinking_budget` 으로 사고 길이 제한 | drafter 부착 상태에서 500. 이 구성에서 불가능 |
| `reasoning_effort: high` | 모델이 500 으로 거부 (`:8011` 직결 실측) |
| Kanban·Telegram 표면 | 사용자 결정 2026-09-01. CLI 만 |
| `--compaction basic`, CFG-05 | 사용자 결정 2026-09-01. v1.2+ 로 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PRB-01 | Phase 9 | Complete |
| PRB-02 | Phase 9 | Complete |
| PRB-03 | Phase 9 | Complete |
| PRB-04 | Phase 9 | Complete |
| CFG-11 | Phase 10 | Complete |
| CFG-12 | Phase 10 | Complete |
| CFG-13 | Phase 10 | Complete |
| CFG-14 | Phase 10 | Complete |
| CFG-15 | Phase 10 | Complete |
| CFG-16 | Phase 10 | Complete |
| CFG-17 | Phase 10 | Complete |
| VRF-01 | Phase 10 | Complete |
| VRF-02 | Phase 10 | Complete |
| VRF-03 | Phase 10 | Complete |
| VRF-04 | Phase 10 | Complete |
| USE-01 | Phase 11 | Complete |
| USE-02 | Phase 11 | Complete |
| USE-03 | Phase 11 | Complete |
| USE-04 | Phase 12 | Complete |
| USE-05 | Phase 12 | Complete |

**Coverage:**
- v1.1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-01*
