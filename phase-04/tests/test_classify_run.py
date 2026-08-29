"""
pytest coverage for phase-04/classify_run.py's discriminators.

Run as `python3 -m pytest phase-04/tests/ -q`, matching how `phase-03/tests/`
is run. `classify_run.py` lives directly under `phase-04/` (a hyphen-safe
leaf module name), so it is imported via a sys.path insertion of the
`phase-04/` directory itself -- the same effect as
`phase-03/tests/test_gen_sandbox_profile.py`'s importlib-by-path approach,
just via the simpler route since `classify_run.py` is not nested under a
further hyphenated subdirectory.

Every test loads its fixture straight from `phase-04/fixtures/` on disk and
asserts against `classify()` (pure, no file I/O) -- no test ever writes to
`phase-04/fixtures/`, keeping that directory frozen per its own README.
"""
import sys
from pathlib import Path

PHASE_04_DIR = Path(__file__).parent.parent
FIXTURES_DIR = PHASE_04_DIR / "fixtures"
sys.path.insert(0, str(PHASE_04_DIR))

import classify_run  # noqa: E402


def _load_fixture(name):
    lines = (FIXTURES_DIR / name).read_text().splitlines()
    return classify_run.parse_ndjson(lines)


# ---------------------------------------------------------------------------
# 1. One test per fixture, asserting the primary outcome.
# ---------------------------------------------------------------------------

def test_success_no_tools_fixture_classifies_success():
    events = _load_fixture("success_no_tools.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "success"
    assert outcome.finish_reason == "completed"


def test_sandbox_denied_fixture_classifies_sandbox_denied():
    events = _load_fixture("sandbox_denied.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "sandbox_denied"
    assert outcome.denied_targets  # non-empty


def test_tty_approval_rejected_fixture_classifies_tty_approval_rejected():
    events = _load_fixture("tty_approval_rejected.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "tty_approval_rejected"


def test_context_overflow_32k_fixture_classifies_context_overflow_terminal():
    events = _load_fixture("context_overflow_32k.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "context_overflow_terminal"
    assert "restart the task" in outcome.reason.lower() or "재시작" in outcome.reason


def test_crashed_truncated_fixture_classifies_crashed():
    events = _load_fixture("crashed_truncated.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "crashed"


# ---------------------------------------------------------------------------
# 2. Nested vs flat error shape -- both yield context_overflow_terminal.
# ---------------------------------------------------------------------------

def test_nested_and_flat_max_kv_size_both_classify_context_overflow():
    msg = (
        "litellm.BadRequestError: OpenAIException - Error code: 400 - "
        "{'detail': 'Request needs 33998 context tokens (31950 prompt + "
        "2048 max generation), but MAX_KV_SIZE is 32768.'}"
    )
    nested_events = [
        {"type": "agent_event", "event": {"type": "error", "error": {"name": "Error", "message": msg}}},
        {"type": "run_result", "finishReason": "error"},
    ]
    flat_events = [
        {"type": "agent_event", "event": {"type": "error", "message": msg}},
        {"type": "run_result", "finishReason": "error"},
    ]
    nested_outcome = classify_run.classify(nested_events)
    flat_outcome = classify_run.classify(flat_events)
    assert nested_outcome.outcome == "context_overflow_terminal"
    assert flat_outcome.outcome == "context_overflow_terminal"


# ---------------------------------------------------------------------------
# 3. Crash is never a denial.
# ---------------------------------------------------------------------------

def test_crash_outranks_denial_but_denial_signal_survives():
    events = _load_fixture("sandbox_denied.ndjson")
    outcome = classify_run.classify(events, cline_exit_code=134)
    assert outcome.outcome == "crashed"
    assert "sandbox_denied" in outcome.signals
    assert outcome.outcome != "sandbox_denied"


# ---------------------------------------------------------------------------
# 4. Denial is not a TTY rejection.
# ---------------------------------------------------------------------------

def test_denial_and_tty_rejection_are_distinct_and_dont_cross_contaminate():
    denial_outcome = classify_run.classify(_load_fixture("sandbox_denied.ndjson"))
    tty_outcome = classify_run.classify(_load_fixture("tty_approval_rejected.ndjson"))
    assert denial_outcome.outcome != tty_outcome.outcome
    assert "tty_approval_rejected" not in denial_outcome.signals
    assert "sandbox_denied" not in tty_outcome.signals


# ---------------------------------------------------------------------------
# 5. Model refusal is not a denial.
# ---------------------------------------------------------------------------

def test_zero_tool_attempts_success_stream_is_never_sandbox_denied():
    events = _load_fixture("success_no_tools.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "success"
    assert outcome.tool_attempts == []
    assert outcome.outcome != "sandbox_denied"


# ---------------------------------------------------------------------------
# 6. Mixed stream: the denial fixture's own successful in-sandbox tool call
#    does not suppress the denial.
# ---------------------------------------------------------------------------

def test_mixed_stream_denial_not_suppressed_by_successful_canary_call():
    events = _load_fixture("sandbox_denied.ndjson")
    outcome = classify_run.classify(events)
    assert outcome.outcome == "sandbox_denied"
    assert "sandbox_denied" in outcome.signals
    assert "success" in outcome.signals  # finishReason is "completed" in this fixture
    # the successful canary attempt is enumerated too, not dropped
    canary_attempts = [
        a for a in outcome.tool_attempts
        if a.get("query") and "SANDBOX_INSIDE_CANARY.txt" in str(a.get("query"))
    ]
    assert canary_attempts
    assert canary_attempts[0]["success"] is True


# ---------------------------------------------------------------------------
# 7. allowed_prefixes: denial inside the allow list adds a signal.
# ---------------------------------------------------------------------------

def test_denial_inside_allowlist_adds_signal():
    events = _load_fixture("sandbox_denied.ndjson")
    outcome = classify_run.classify(events, allowed_prefixes=["/Users/ohama/.zshrc"])
    assert "denied_inside_allowlist" in outcome.signals
    outcome_no_prefix = classify_run.classify(events)
    assert "denied_inside_allowlist" not in outcome_no_prefix.signals


# ---------------------------------------------------------------------------
# 8. run_result absence alone (exit code None) yields crashed.
# ---------------------------------------------------------------------------

def test_missing_run_result_alone_yields_crashed():
    events = [
        {"type": "hook_event", "hookEventName": "agent_start"},
        {"type": "agent_event", "event": {"type": "usage", "inputTokens": 100, "outputTokens": 10}},
    ]
    outcome = classify_run.classify(events, cline_exit_code=None)
    assert outcome.outcome == "crashed"


# ---------------------------------------------------------------------------
# Fixture immutability check: no test above may have mutated a fixture file.
# ---------------------------------------------------------------------------

def test_fixtures_directory_is_untouched_by_this_test_run():
    for name in (
        "success_no_tools.ndjson",
        "sandbox_denied.ndjson",
        "tty_approval_rejected.ndjson",
        "context_overflow_32k.ndjson",
        "crashed_truncated.ndjson",
    ):
        assert (FIXTURES_DIR / name).exists()
