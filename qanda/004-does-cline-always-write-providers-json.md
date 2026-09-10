# (Q) `cline` 이 plan/act 모드에서 `providers.json` 을 반드시 변경하는가? — 소스 재확인

> **질문 (2026-09-10):** cline 소스를 보고, `cline` 이 plan, act mode 에서
> `providers.json` 을 반드시 변경하는지 재확인!

## 짧은 답

**쓰는 것은 맞습니다. 그러나 "그 파일에" 쓰는 것은 아닙니다.**

`cline` 은 **`CLINE_PROVIDER_SETTINGS_PATH` 가 가리키는 파일**에 씁니다. 환경변수를 스크래치
사본으로 돌리면 **실제 `providers.json` 은 바이트 단위로 그대로**입니다. 오늘 실제로 확인했습니다.

**그리고 plan/act 모드와는 무관합니다.** `-p` 유무가 아니라 `-m` 이 원인입니다 —
`cline-act`(`-p` 없음)도 똑같이 씁니다.

---

## 1. 소스는 뭐라고 하나 — 그리고 왜 소스만으로는 부족한가

로컬 체크아웃은 **`cli-v3.0.53`**, 설치된 바이너리는 **`3.0.61`** 입니다. 8개 버전 차이입니다.

3.0.53 의 `session-runtime.ts:109-113` 은 `-m` 을 **읽기 전용 오버라이드**로 다룹니다:

```ts
model:
    input.options.model?.trim() ||        // -m 이 최우선
    selectedProviderSettings?.model ||    // 없으면 저장된 값
    input.defaultModel ||
    "anthropic/claude-sonnet-4.6",
```

**쓰기가 없습니다.** Phase 9 가 "`-m` 은 영속화하지 않는다"고 읽은 근거가 이것이고,
그 판독은 **3.0.53 에 대해서는 옳았습니다.**

🔴 **그런데 그 코드는 3.0.61 바이너리에 없습니다.** 89MB Bun 바이너리에서
`selectedProviderSettings?.model` 문자열을 찾으면 **0건**입니다. 코드가 바뀌었습니다.

**결론: 우리가 가진 소스로는 3.0.61 의 동작을 판정할 수 없습니다.** 관측이 유일한 근거입니다.
(CFG-05 — 자동 업데이트를 막지 못해 소스와 바이너리가 계속 어긋납니다.)

---

## 2. 관측 — `-p` 가 아니라 `-m` 이 원인

| 실행 | `-p` | `-m` | 결과 |
|---|---|---|---|
| `cline-act "2+2"` | ❌ | `flashnext-act` | `model` → **`flashnext-act`** |
| `cline-plan "3+4"` | ✅ | `flashnext-plan` | `model` → **`flashnext-plan`** |

**Plan 모드 여부와 무관합니다.** `-p` 없는 `cline-act` 도 똑같이 씁니다.
A/B 에서는 **31회 호출 중 31회, 100%** 였습니다.

---

## 3. 결정적 발견 — 쓰기 대상은 바꿀 수 있다

바이너리에서 `CLINE_PROVIDER_SETTINGS_PATH` 를 찾았고, 소스에도 그 해석기가 있습니다
(`sdk/packages/shared/src/storage/paths.ts:347-353`):

```ts
export function resolveProviderSettingsPath(): string {
    const explicitPath = process.env.CLINE_PROVIDER_SETTINGS_PATH?.trim();
    if (explicitPath) {
        return explicitPath;          // ← 무조건 우선
    }
    return join(resolveClineDataDir(), "settings", "providers.json");
}
```

**샌드박스 모드 전용이 아닙니다.** 조건 없이 우선합니다.

### 실측 (2026-09-10)

```bash
cp ~/.cline/data/settings/providers.json /tmp/scratch.json

CLINE_PROVIDER_SETTINGS_PATH=/tmp/scratch.json CLINE_NO_AUTO_UPDATE=1 \
  cline -P openai-compatible -p -m flashnext-plan --compaction agentic -t 600 "5+5는? 숫자만."
```

결과:

```
답                        10                     ✅ 정상 동작
실제 파일 sha             588bd7cc5e15977a  →  588bd7cc5e15977a   ✅ 불변
실제 파일 model           flashnext                               ✅ 보존
스크래치 model            flashnext-plan          ← 쓰기가 여기로 갔다
스크래치 contextWindow    29000                   ✅ 설정 온전
서버 로그                 prompt_tokens=5205      ✅ 모델까지 도달
```

**격리가 완전합니다.** 실제 파일은 손도 안 탔고, 실행은 정상이며, 설정도 온전합니다.

---

## 4. 그래서 무엇이 바뀌나

이 발견 전까지 래퍼의 상황은 이랬습니다:

> 쓸 때마다 Kanban·Telegram 의 공유 설정이 오염된다. 래퍼는 **탐지만 하고 예방은 못 한다.**
> A/B 가 완주한 유일한 이유는 하네스 안에만 있던 수리 루프였다.

**이제 예방이 가능합니다.** 래퍼가 호출마다 스크래치 사본을 만들고 그쪽을 가리키면 됩니다:

```bash
SCRATCH=$(mktemp)
cp "$REAL_PROVIDERS" "$SCRATCH"
CLINE_PROVIDER_SETTINGS_PATH="$SCRATCH" cline ...
rm -f "$SCRATCH"
```

**탐지 → 예방**으로 성격이 바뀝니다. `exit 4` 경고도, 사후 복구도 필요 없어집니다.

🔴 **다만 이건 아직 제안이지 구현이 아닙니다.** 위 실측은 `cline` 을 맨손으로 부른 것이고,
래퍼에 넣어 13케이스 argv 테스트와 뮤턴트 검증을 통과시키는 일은 아직 안 했습니다.
**Phase 11 의 유지/되돌림 결정에 이 사실이 들어가야 합니다** — 결정의 근거였던
"부작용 100%" 가 **회피 가능한** 부작용으로 바뀌었기 때문입니다.

(정확도 차이가 없다는 사실은 그대로입니다. 그건 별개 근거입니다.)

---

## 5. 남은 미지수

- **왜 쓰는지는 모릅니다.** 3.0.61 의 쓰기 지점을 특정하지 못했습니다. 바이너리가 난독화된
  Bun 번들이라 함수 이름이 `O`, `M`, `C` 로 뭉개져 있습니다. **"쓴다"는 관측 사실이고
  "왜"는 미규명입니다.**
- **`-m` 없이도 쓰는지 안 봤습니다.** 우리 경로는 항상 `-m` 을 씁니다.
- **다음 버전에서 또 바뀔 수 있습니다.** 3.0.53→3.0.61 사이에 이미 바뀌었고 CFG-05 는
  미해결입니다. `CLINE_PROVIDER_SETTINGS_PATH` 도 언제까지 유효할지 보장이 없습니다.

---

## 근거

| 주장 | 확인 방법 |
|---|---|
| 3.0.53 은 읽기 전용 | `cline-src` `session-runtime.ts:109-113`, 태그 `cli-v3.0.53` |
| 그 코드가 3.0.61 에 없음 | `strings bin/.cline \| grep -F 'selectedProviderSettings?.model'` → 0건 |
| env 가 무조건 우선 | `sdk/packages/shared/src/storage/paths.ts:347-353` |
| 격리 실측 | 이 문서 작성 중 실행, sha `588bd7cc5e15977a` 전후 동일 |
| `-p` 무관 | `cline-act`(`-p` 없음)도 오염 — `qanda/001` |
| 100% 발생률 | `phase-11/AB-RESULTS.md`, `providers-drift.tsv` (31/31) |
