# Run Outcome: crashed

**Generated:** 2026-08-29T21:51:33.624932+00:00

## Meaning (한글 요약)

스트림이 불완전하거나(run_result 없음) 프로세스가 시그널로 죽었다(exit>128) - 미확정이며, 절대 '차단 성공'으로 보고하면 안 된다

## Verdict

- **outcome:** `crashed`
- **reason:** Stream has no run_result event, or the wrapped process died by signal (exit code > 128). This result is INCONCLUSIVE about the sandbox and must never be reported as a successful block -- same discriminator phase-03/sandbox/assert_denied.sh uses.
- **finish_reason:** `None`
- **cline_exit_code:** 134
- **malformed_lines:** 0
- **signals:** crashed

## Tool Attempts

(no tool call attempts in this stream)

## Denied Targets

(none)

