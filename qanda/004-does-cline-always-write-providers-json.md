# (Q) `cline` 이 plan/act 모드에서 `providers.json` 을 반드시 변경하는가? — 소스 재확인

> **질문 (2026-09-10):** cline 소스를 보고, `cline` 이 plan, act mode 에서
> `providers.json` 을 반드시 변경하는지 재확인!
>
> **후속:** 3.0.61 소스를 받아서 확인해 줘. 3.0.53 source 는 지우고.

## 짧은 답

**네, 반드시 씁니다.** 소스에서 확인했습니다 — `apps/cli/src/main.ts` 의
`saveProviderSettings({ ..., model: config.modelId, ... })`, **조건문 없이** 기동 경로에
있습니다. `try/catch` 는 실패를 로그만 하고 넘어갑니다.

**세 가지가 함께 확정됐습니다:**

1. **plan/act 와 무관합니다.** `-p` 가 아니라 `-m` 이 원인입니다.
2. **버전 변화가 아닙니다.** 3.0.53 에도 **똑같은 코드가 있었습니다.**
3. **그래도 막을 수 있습니다.** `CLINE_PROVIDER_SETTINGS_PATH` 로 쓰기 대상을 돌리면
   실제 파일은 바이트 단위로 보존됩니다 (실측 확인).

---

## 🔴 이 문서의 이전 판이 틀렸습니다 (2026-09-10 정정)

첫 판에서 이렇게 썼습니다:

> *"3.0.53 의 그 코드는 3.0.61 바이너리에 없다 — `strings` 로 `selectedProviderSettings?.model`
> 을 찾으면 0건이다. 코드가 바뀌었다."*

**틀렸습니다.** 3.0.61 소스를 받아 보니 그 코드는 `session-runtime.ts:110-111` 에
**그대로 있습니다.** `strings` 가 0건을 낸 것은 코드가 없어서가 아니라 **Bun 번들이 변수명을
뭉갰기** 때문입니다.

**교훈:** 난독화된 번들에서 소스 문자열이 안 나오는 것은 **부재의 증거가 아닙니다.**
없는 것과 안 보이는 것을 구별하지 못했습니다.

---

## 1. 실제 쓰기 지점

`apps/cli/src/main.ts` (3.0.61 기준 1122행, 3.0.53 기준 1119행):

```ts
providerSettingsManager.saveProviderSettings({
    ...(selectedProviderSettings ?? {}),
    provider,
    model: config.modelId,        // ← -m 이 여기로 영속화된다
    ...persistApiKey,
});
```

`config.modelId` 의 정의 (`main.ts:1056`):

```ts
modelId:
    args.model ??                      // -m 이 최우선
    selectedProviderSettings?.model ??
    knownModelIds[0] ??
    "anthropic/claude-sonnet-4.6",
```

**`-m` 값이 그대로 파일에 기록됩니다.** 이 호출은 `if` 안에 있지 않습니다 — 기동 경로에
무조건 있고, 헤드리스 실행도 이 지점을 지납니다.

### 우리가 전에 읽은 곳은 다른 모듈이었습니다

Phase 9 는 `session-runtime.ts:109-113` 을 읽고 *"`-m` 은 영속화하지 않는다"* 고 결론지었습니다:

```ts
model:
    input.options.model?.trim() ||        // 쓰기 없음 — 읽기 전용 해석
    selectedProviderSettings?.model || ...
```

그 판독 자체는 맞습니다. **다만 그건 커넥터(Slack·Telegram 등)의 *읽기* 경로**이고,
CLI 자신의 *쓰기* 경로인 `main.ts` 는 보지 않았습니다.

🔴 **버그가 아니라 조사 범위의 문제였습니다.** 한 모듈에서 쓰기가 없다는 것을
"어디에도 쓰기가 없다"로 일반화했습니다.

---

## 2. 버전 간 비교 — 동작은 변한 적이 없다

```
$ git diff cli-v3.0.53 cli-v3.0.61 -- apps/cli/src/main.ts
 apps/cli/src/main.ts | 5 ++++-
 1 file changed, 4 insertions(+), 1 deletion(-)
```

유일한 변경은 `knownModelIds` 에 `filterChatModels()` 를 씌운 것입니다.
**`saveProviderSettings` 블록은 두 태그에서 바이트 단위로 동일합니다.**

**따라서 이 쓰기는 처음부터 있었습니다.** CFG-05 드리프트 탓이 아닙니다.

### 그러면 Phase 10 은 왜 못 봤나 — 미해결

Phase 10 의 VRF-04(3.0.60)는 `updatedAt` 만 바뀌고 **`model` 은 `flashnext` 그대로**였다고
기록했습니다. 그런데 소스는 세 태그에서 동일하고, Phase 11 은 **31/31** 로 `model` 변경을
관측했습니다.

**이 불일치는 설명하지 못했습니다.** 지어내지 않고 미해결로 남깁니다.
증거의 무게는 명백히 한쪽입니다 — 동일한 소스 + 31/31 관측 대 단발 관측 1건.
**Phase 10 의 관측이 이상치입니다.**

---

## 3. 관측 — `-p` 가 아니라 `-m`

| 실행 | `-p` | `-m` | 결과 |
|---|---|---|---|
| `cline-act "2+2"` | ❌ | `flashnext-act` | `model` → **`flashnext-act`** |
| `cline-plan "3+4"` | ✅ | `flashnext-plan` | `model` → **`flashnext-plan`** |

소스가 이유를 설명합니다 — 쓰이는 값은 `config.modelId` 이고 거기에 `-p` 는 관여하지 않습니다.

---

## 4. 막는 법 — 검증됨

`sdk/packages/shared/src/storage/paths.ts:424-430` (3.0.61 기준. 3.0.53 에서는 `:347-353`):

```ts
export function resolveProviderSettingsPath(): string {
    const explicitPath = process.env.CLINE_PROVIDER_SETTINGS_PATH?.trim();
    if (explicitPath) {
        return explicitPath;          // ← 조건 없이 우선. 샌드박스 전용 아님
    }
    return join(resolveClineDataDir(), "settings", "providers.json");
}
```

### 실측 (2026-09-10)

```bash
cp ~/.cline/data/settings/providers.json /tmp/scratch.json
CLINE_PROVIDER_SETTINGS_PATH=/tmp/scratch.json CLINE_NO_AUTO_UPDATE=1 \
  cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 600 "5+5는? 숫자만."
```

```
답                     10                                  ✅ 정상
실제 파일 sha          588bd7cc5e15977a → 588bd7cc5e15977a  ✅ 불변
실제 파일 model        flashnext                            ✅ 보존
스크래치 model         flashnext-plan       ← 쓰기가 여기로
스크래치 contextWindow 29000                                ✅ 설정 온전
서버 로그              prompt_tokens=5205                   ✅ 모델 도달
```

**격리가 완전합니다.**

---

## 5. 결정에 미치는 영향

Phase 11 의 되돌림 근거는 둘이었습니다:

| 근거 | 상태 |
|---|---|
| 정확도 개선 없음 (25/30 대 25/30, p=0.563) | **그대로** |
| 부작용 100% 확실 | **회피 가능으로 바뀜** |

래퍼가 호출마다 스크래치 사본을 가리키면 **탐지 → 예방**이 됩니다. `exit 4` 경고도
사후 복구도 필요 없어집니다.

🔴 **아직 제안이지 구현이 아닙니다.** 맨손 `cline` 으로만 확인했고, 래퍼에 넣어
13케이스 argv 테스트와 뮤턴트 검증을 통과시키는 일은 안 했습니다.

---

## 6. 남은 미지수

- **Phase 10 이 왜 `model` 변경을 못 봤는지** — 위 §2. 미해결.
- **`-m` 없이도 쓰는지 안 봤습니다.** 소스상 `config.modelId` 는 항상 값을 가지므로
  **쓸 것으로 보이지만**, 관측하지 않았습니다. 추론입니다.
- **`CLINE_PROVIDER_SETTINGS_PATH` 의 수명 보장은 없습니다.** CFG-05 는 미해결이고,
  바이너리는 이 세션 중에도 한 번 통째로 사라졌다가 재설치됐습니다.

---

## 7. `cline-src` 상태 변경

요청대로 **`cli-v3.0.53` → `cli-v3.0.61` 로 전환**했습니다(`git checkout`).
`rm -rf` 대신 태그 전환을 쓴 이유는 **git 이력이 남아 기존 인용이 계속 유효**하기 때문입니다:

```bash
git show cli-v3.0.53:apps/cli/src/main.ts    # 여전히 조회 가능
```

`phase-09/PRB-04-FINDINGS.md` 의 `ai-sdk.ts:284-289` 등 3.0.53 기준 인용은 **작업 트리에는
더 이상 없지만 태그로 접근 가능**합니다. 그 문서들에 태그가 명시돼 있어 추적됩니다.

---

## 근거

| 주장 | 확인 방법 |
|---|---|
| 무조건 쓰기 | `main.ts:1122` (3.0.61) / `:1119` (3.0.53), `if` 없음 |
| `-m` → 파일 | `main.ts:1056` `modelId: args.model ?? …` |
| 동작 불변 | `git diff cli-v3.0.53 cli-v3.0.61 -- apps/cli/src/main.ts` → `filterChatModels` 한 줄뿐 |
| Phase 9 판독 범위 오류 | `session-runtime.ts:109-113` 은 커넥터 읽기 경로 |
| env 우선 | `paths.ts:424-430` (3.0.61). 3.0.53 에서는 `:347-353` — 코드 동일, 위치만 이동 |
| 격리 실측 | 이 문서 작성 중 실행, sha `588bd7cc5e15977a` 전후 동일 |
| 100% 발생률 | `phase-11/AB-RESULTS.md`, `providers-drift.tsv` (31/31) |
