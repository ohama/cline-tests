---
name: Show elapsed time during execution
description: User wants elapsed time checks during long-running execute-phase to track progress
type: feedback
---

execute-phase가 너무 오래 걸린다. 실행 중간중간에 경과 시간을 표시해 달라.

**Why:** 긴 실행 중에 진행 상황을 파악하기 어려움. 시간 감각을 유지하고 싶음.
**How to apply:** executor agent 프롬프트에 "각 iteration/fix 후 경과 시간을 표시하라" 지시를 추가. 예: `date +%H:%M:%S` 를 주요 단계마다 실행.
