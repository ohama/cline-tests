#!/bin/bash
# phase-07/bench/classify_lib.sh -- single source of truth for cline-bench's verdict
# classification rule. Sourced by both run_task.sh (live runs) and reclassify_runs.sh
# (offline re-classification of stored evidence), so the two paths cannot diverge --
# see the `key_links` entry in 07-13-PLAN.md's frontmatter.
#
# WHY THIS FILE EXISTS (07-13 gap closure, following 07-12's CLASSIFIER-AUDIT.md):
# the previous verdict rule set `http_400_seen=1` on a bare `grep -qE '\b400\b'` match
# against the server-log slice and the agent transcript. 07-12 demonstrated this is
# unsound in both directions at once:
#   - false-negative: the server's own rejection line never contains a bare "400"
#     (confirmed against all 3 tasks that hit it in the audited dataset)
#   - false-positive: decode telemetry (`generated_tokens=400`), log-timestamp
#     millisecond coincidences, and the benchmark task's OWN repository source code
#     echoed into agent/cline.txt by ordinary file-read tool calls (`case 400:`,
#     `new ApiError(..., 400, ...)`) all satisfy `\b400\b` with zero relationship to
#     any context rejection
# None of the 4 audited fail-context labels were actually flipped by these defects
# (every one also carried an independent true-signal match), but 07-12 judged the
# instrument unsound anyway because nothing downstream could tell a trustworthy match
# from a coincidental one. This file replaces the bare-400 test with a match on the
# authoritative rejection phrase itself, which both the raw flashnext server log and
# litellm's relayed BadRequestError text contain verbatim (verified byte-for-byte
# against 3 stored tasks in 07-11/07-12):
#
#   Request needs <T> context tokens (<P> prompt + <G> max generation), but MAX_KV_SIZE is <K>
#
# It also adds a distinct memory-exhaustion signal (GPU/host OOM), since one stored
# task (discord-trivia-approval-keyerror) shows both a context rejection and 6
# recovered OOM events, and 07-12/07-13's must-haves require the two to be
# distinguishable in the recorded verdict rather than silently collapsing into one
# label.
#
# Every function below degrades to its zero value for a missing/empty/unreadable
# input file rather than erroring -- callers pass paths that may legitimately not
# exist (e.g. no agent/cline.txt when environment_setup crashed before the agent).

CLASSIFY_LIB_MAXKV_PATTERN='Request needs [0-9]+ context tokens \([0-9]+ prompt \+ [0-9]+ max generation\), but MAX_KV_SIZE is [0-9]+'
CLASSIFY_LIB_OOM_PATTERN='Request failed:.*(kIOGPUCommandBufferCallbackErrorOutOfMemory|Insufficient Memory)'

# count_maxkv_rejections <file> -- number of lines matching the authoritative
# rejection phrase. Works identically against a raw server-log slice or an
# agent/cline.txt transcript (litellm relays the phrase verbatim inside its
# BadRequestError message). Prints 0 for a missing/unreadable/empty file or path.
count_maxkv_rejections() {
  local f="${1:-}" n
  if [ -z "$f" ] || [ ! -f "$f" ]; then printf '0\n'; return 0; fi
  n="$(grep -cE "$CLASSIFY_LIB_MAXKV_PATTERN" "$f" 2>/dev/null)"
  printf '%s\n' "${n:-0}"
}

# count_oom_failures <file> -- number of *events* (not raw string occurrences). Each
# real GPU/host OOM event logs its trigger string on up to 4 separate lines (two
# RuntimeError traceback lines, one WARNING "Request failed:" line, one ERROR "Chat
# completion stream generation failed:" line -- see 07-12's failure-composition.tsv,
# which found a naive `grep -c` on the bare OOM string over-counts 4x). Anchoring on
# the single "Request failed:"-prefixed line avoids that over-count.
count_oom_failures() {
  local f="${1:-}" n
  if [ -z "$f" ] || [ ! -f "$f" ]; then printf '0\n'; return 0; fi
  n="$(grep -cE "$CLASSIFY_LIB_OOM_PATTERN" "$f" 2>/dev/null)"
  printf '%s\n' "${n:-0}"
}

# max_prompt_tokens_accepted <file> -- peak prompt_tokens=N over every request the
# server actually queued (Generation queued: / Request completed: / Prefill ...:
# lines). Unchanged in computation from the pre-07-13 rule -- 07-11's
# CONTEXT-FORENSICS.md independently confirmed this figure is correct for what it
# measures; it is a LOWER BOUND on the true fatal request, not the true fatal
# request itself (a rejected request is never queued, so it never appears here --
# see max_rejected_prompt_tokens / max_prompt_tokens_attempted below).
max_prompt_tokens_accepted() {
  local f="${1:-}" n
  if [ -z "$f" ] || [ ! -f "$f" ]; then printf '0\n'; return 0; fi
  n="$(grep -oE 'prompt_tokens=[0-9]+' "$f" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
  printf '%s\n' "${n:-0}"
}

# max_rejected_prompt_tokens <file> -- peak <P> captured from the authoritative
# rejection phrase's "prompt" count: the request the server rejected BEFORE ever
# queueing it, which is structurally invisible to max_prompt_tokens_accepted
# (07-12 CLASSIFIER-AUDIT.md defect 4).
max_rejected_prompt_tokens() {
  local f="${1:-}" n
  if [ -z "$f" ] || [ ! -f "$f" ]; then printf '0\n'; return 0; fi
  n="$(grep -oE "$CLASSIFY_LIB_MAXKV_PATTERN" "$f" 2>/dev/null \
       | grep -oE '\([0-9]+ prompt' | grep -oE '[0-9]+' | sort -n | tail -1)"
  printf '%s\n' "${n:-0}"
}

# max_prompt_tokens_attempted <serverlog-file> <transcript-file-or-empty> -- max
# over the accepted peak and both files' rejected-request peaks. This is the true
# peak prompt size the task actually attempted, including the fatal request the
# server refused to queue.
max_prompt_tokens_attempted() {
  local accepted rej_a rej_b
  accepted="$(max_prompt_tokens_accepted "${1:-}")"
  rej_a="$(max_rejected_prompt_tokens "${1:-}")"
  rej_b="$(max_rejected_prompt_tokens "${2:-}")"
  printf '%s\n%s\n%s\n' "$accepted" "$rej_a" "$rej_b" | sort -n | tail -1
}

# count_model_turns <serverlog-file> -- number of `Request completed:` lines. Same
# computation the pre-07-13 rule already used; factored here so run_task.sh and
# reclassify_runs.sh share one implementation.
count_model_turns() {
  local f="${1:-}" n
  if [ -z "$f" ] || [ ! -f "$f" ]; then printf '0\n'; return 0; fi
  n="$(grep -c 'Request completed:' "$f" 2>/dev/null)"
  printf '%s\n' "${n:-0}"
}

# read_reward <trial-dir-or-empty> -- verbatim contents of verifier/reward.txt
# (whitespace-stripped), or the string "null" if the trial dir/file does not exist.
# No side effects (does not write CAPTURE-GAPS.txt) -- callers that need that side
# effect (run_task.sh, which records the gap for BCH-02 auditability) keep their own
# copy of that bookkeeping around this same read.
read_reward() {
  local trial_dir="${1:-}"
  if [ -n "$trial_dir" ] && [ -f "$trial_dir/verifier/reward.txt" ]; then
    tr -d '[:space:]' < "$trial_dir/verifier/reward.txt"
  else
    printf 'null\n'
  fi
}

# classify_verdict <maxkv_serverlog_count> <maxkv_transcript_count> <oom_count>
#   <reward|null> <model_turn_count>
# Prints exactly one verdict token: pass | fail-task | fail-context | fail-oom |
# fail-infra. This is the ENTIRE verdict rule -- both run_task.sh and
# reclassify_runs.sh call this one function so a future fix cannot land in one path
# and silently miss the other.
classify_verdict() {
  local maxkv_s="${1:-0}" maxkv_t="${2:-0}" oom="${3:-0}" reward="${4:-null}" turns="${5:-0}"
  if [ "$maxkv_s" -gt 0 ] 2>/dev/null || [ "$maxkv_t" -gt 0 ] 2>/dev/null; then
    # Highest precedence, even over a nonzero oom count. Chosen because 07-12's
    # CLASSIFIER-AUDIT.md section 4 confirmed the MAX_KV_SIZE rejection is the
    # TERMINAL event in the one stored task that shows both signals
    # (discord-trivia-approval-keyerror: 6 recovered OOM events, each followed by a
    # successful retry, then 1 terminal MAXKV rejection that ends the run for good).
    # oom_failures is still recorded in the emitted meta record precisely so a
    # fail-context verdict with a nonzero oom count is never a SILENT pure-context
    # report -- the reader can see the memory-pressure noise without it changing
    # the label.
    printf 'fail-context\n'
  elif [ "$reward" = "1" ]; then
    printf 'pass\n'
  elif [ "$reward" = "0" ] && [ "$turns" -gt 0 ] 2>/dev/null; then
    printf 'fail-task\n'
  elif [ "$turns" -gt 0 ] 2>/dev/null; then
    # Model was reached and produced turns, but reward is missing/unparseable --
    # still not an infra failure; treat conservatively as fail-task rather than
    # silently mislabeling it fail-infra (same reasoning the pre-07-13 rule used).
    printf 'fail-task\n'
  elif [ "$oom" -gt 0 ] 2>/dev/null; then
    # New in 07-13: no context rejection ever occurred AND zero model turns ever
    # completed AND a memory/GPU exhaustion event is present in the server-log
    # slice. Distinguishes "died of memory exhaustion before completing any turn"
    # from the zero-evidence fail-infra catch-all below (image build failure,
    # harness timeout, environment_setup crash with no server-log activity at all).
    printf 'fail-oom\n'
  else
    printf 'fail-infra\n'
  fi
}
