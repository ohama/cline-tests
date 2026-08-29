"""
Fixture-driven test suite for phase-01/parse_result.py — the three-way
compaction verdict classifier (VER-02 / VER-03).

Written test-first (RED phase): at the point this file is created,
phase-01/parse_result.py does not exist, so every test below must fail
(import error or assertion failure). No implementation is written in
this task.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"
PARSE_RESULT_PY = Path(__file__).parent.parent / "parse_result.py"

# Make phase-01/ importable so `import parse_result` works regardless of cwd.
sys.path.insert(0, str(PARSE_RESULT_PY.parent))


def load_ndjson(name):
    """Read a fixture NDJSON file as a list of raw text lines (not yet parsed)."""
    path = FIXTURES / name
    with open(path, "r") as f:
        return f.read().splitlines()


def load_log(name):
    path = FIXTURES / name
    with open(path, "r") as f:
        return f.read().splitlines()


class TestParseNdjsonAndClassify(unittest.TestCase):
    """Behavior cases 1-3 from the plan: the three verdicts."""

    def test_outcome1_compaction_fired(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome1_compacted.ndjson"))
        verdict = parse_result.classify(events, [])
        self.assertEqual(verdict.outcome, "compaction_fired")
        self.assertEqual(
            verdict.compaction_events[0]["metadata"]["triggerTokens"], 26542
        )

    def test_outcome1_surfaces_before_after_fields(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome1_compacted.ndjson"))
        verdict = parse_result.classify(events, [])
        # the auto-compacted event (second compaction event) carries these
        compacted = [
            e
            for e in verdict.compaction_events
            if e.get("message") == "auto-compacted"
        ]
        self.assertTrue(compacted, "expected an auto-compacted event to be present")
        meta = compacted[0]["metadata"]
        for key in ("tokensBefore", "tokensAfter", "messagesBefore", "messagesAfter"):
            self.assertIn(key, meta)

    def test_outcome2_server_400_no_compaction(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome2_server400.ndjson"))
        verdict = parse_result.classify(events, [])
        self.assertEqual(verdict.outcome, "server_400_no_compaction")

    def test_outcome2_reason_states_no_self_heal(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome2_server400.ndjson"))
        verdict = parse_result.classify(events, [])
        self.assertIn("self-heal", verdict.reason.lower())

    def test_outcome2_server_error_captured(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome2_server400.ndjson"))
        verdict = parse_result.classify(events, [])
        self.assertIsNotNone(verdict.server_error)
        self.assertIn("MAX_KV_SIZE", verdict.server_error)

    def test_outcome3_below_trigger_is_other(self):
        import parse_result

        events = parse_result.parse_ndjson(
            load_ndjson("outcome3_below_trigger.ndjson")
        )
        verdict = parse_result.classify(events, [])
        self.assertEqual(verdict.outcome, "other")
        self.assertIn("never reached", verdict.reason)

    def test_outcome3_below_trigger_recommends_more_filler(self):
        import parse_result

        events = parse_result.parse_ndjson(
            load_ndjson("outcome3_below_trigger.ndjson")
        )
        verdict = parse_result.classify(events, [])
        self.assertIn("filler", verdict.reason.lower())

    def test_outcome3_timeout_is_unexpected(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome3_timeout.ndjson"))
        verdict = parse_result.classify(events, [])
        self.assertEqual(verdict.outcome, "other")
        self.assertIn("unexpected", verdict.reason)


class TestFlashnextLogParsing(unittest.TestCase):
    """Behavior case 4: oracle independence (VER-02)."""

    def test_peak_prompt_tokens(self):
        import parse_result

        sample = load_log("flashnext_window_sample.log")
        result = parse_result.parse_flashnext_log(sample)
        self.assertEqual(result.peak_prompt_tokens, 26800)

    def test_no_progress_bar_source_in_module(self):
        """The verdict must never be derived from the TUI progress bar (VER-02)."""
        source = PARSE_RESULT_PY.read_text().lower()
        forbidden = ["progress_bar", "progressbar", "progress bar", "% complete"]
        for term in forbidden:
            self.assertNotIn(
                term, source, f"parse_result.py must not reference {term!r}"
            )


class TestPeaksReportedSideBySide(unittest.TestCase):
    def test_verdict_carries_both_peaks(self):
        import parse_result

        events = parse_result.parse_ndjson(load_ndjson("outcome1_compacted.ndjson"))
        log_lines = load_log("flashnext_window_sample.log")
        verdict = parse_result.classify(events, log_lines)
        self.assertEqual(verdict.peak_input_tokens, 26800)
        self.assertEqual(verdict.peak_prompt_tokens, 26800)
        self.assertEqual(verdict.evidence_source, "both")


class TestOracleDisagreement(unittest.TestCase):
    """Behavior case 5: >15% disagreement between peaks must be flagged, not
    silently resolved in favor of either oracle."""

    def test_disagreement_warning_present(self):
        import parse_result

        # Craft events/log with peaks differing by more than 15%.
        events = [
            {"type": "agent_event", "event": {"type": "usage", "inputTokens": 10000}},
            {"type": "run_result", "finishReason": "completed"},
        ]
        log_lines = [
            "2026-08-29 16:15:03,135 - INFO - Request completed: endpoint=/chat/completions "
            "prompt_tokens=20000 generated_tokens=5 finish_reason=stop"
        ]
        verdict = parse_result.classify(events, log_lines)
        self.assertEqual(verdict.evidence_source, "both")
        self.assertIn("WARNING: oracle disagreement", verdict.reason)


class TestCliBehavior(unittest.TestCase):
    """Behavior case 6: CLI exit codes and verdict.md rendering."""

    def _run_cli(self, ndjson_fixture, extra_args=None):
        with tempfile.TemporaryDirectory() as tmpdir:
            args = [
                sys.executable,
                str(PARSE_RESULT_PY),
                "--ndjson",
                str(FIXTURES / ndjson_fixture),
                "--server-log",
                str(FIXTURES / "flashnext_window_sample.log"),
                "--out",
                tmpdir,
            ]
            if extra_args:
                args.extend(extra_args)
            result = subprocess.run(args, capture_output=True, text=True)
            verdict_path = Path(tmpdir) / "verdict.md"
            verdict_text = verdict_path.read_text() if verdict_path.exists() else ""
            return result.returncode, verdict_text

    def test_exit_code_0_for_compaction_fired(self):
        code, _ = self._run_cli("outcome1_compacted.ndjson")
        self.assertEqual(code, 0)

    def test_exit_code_2_for_server_400(self):
        code, _ = self._run_cli("outcome2_server400.ndjson")
        self.assertEqual(code, 2)

    def test_exit_code_3_for_other(self):
        code, _ = self._run_cli("outcome3_below_trigger.ndjson")
        self.assertEqual(code, 3)

    def test_verdict_md_is_readable(self):
        code, text = self._run_cli("outcome1_compacted.ndjson")
        self.assertIn("compaction_fired", text)
        self.assertIn("26800", text)  # peak_input_tokens / peak_prompt_tokens
        self.assertIn("26542", text)  # predicted_trigger default used

    def test_cli_predicted_trigger_flag_reaches_classify(self):
        """The --predicted-trigger flag must actually change classify()'s
        verdict, not just be accepted and ignored (which would silently fall
        back to the module-level PREDICTED_TRIGGER_TOKENS default)."""
        # outcome3_below_trigger's peak inputTokens is 18400. Lowering the
        # trigger below that must flip the sub-reason away from below_trigger.
        code, text = self._run_cli(
            "outcome3_below_trigger.ndjson", extra_args=["--predicted-trigger", "15000"]
        )
        self.assertIn("15000", text)
        self.assertNotIn("never reached", text)

    def test_cli_handles_empty_ndjson_without_crash(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            empty_ndjson = Path(tmpdir) / "empty.ndjson"
            empty_ndjson.write_text("")
            args = [
                sys.executable,
                str(PARSE_RESULT_PY),
                "--ndjson",
                str(empty_ndjson),
                "--out",
                tmpdir,
            ]
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 3)
            self.assertEqual(result.stderr, "")


class TestRobustness(unittest.TestCase):
    """Task 3: how a real captured stream differs from a clean fixture."""

    def test_truncated_trailing_line_is_counted_not_raised(self):
        import parse_result

        # Must not raise even though the file ends mid-JSON-object.
        events = parse_result.parse_ndjson(load_ndjson("outcome3_timeout.ndjson"))
        verdict = parse_result.classify(events, [])
        self.assertEqual(verdict.malformed_lines, 1)

    def test_empty_ndjson_is_other_unexpected_not_a_crash(self):
        import parse_result

        verdict = parse_result.classify([], [])
        self.assertEqual(verdict.outcome, "other")
        self.assertIn("unexpected", verdict.reason)

    def test_missing_server_log_notes_missing_cross_check(self):
        import parse_result

        events = parse_result.parse_ndjson(
            load_ndjson("outcome3_below_trigger.ndjson")
        )
        verdict = parse_result.classify(events, [])
        self.assertEqual(verdict.evidence_source, "ndjson_usage")
        self.assertIn("cross-check", verdict.reason.lower())

    def test_no_disagreement_warning_when_within_threshold(self):
        import parse_result

        # 10000 vs 11000 is a 9% difference - must NOT trigger the warning.
        events = [
            {"type": "agent_event", "event": {"type": "usage", "inputTokens": 10000}},
            {"type": "run_result", "finishReason": "completed"},
        ]
        log_lines = [
            "2026-08-29 16:15:03,135 - INFO - Request completed: endpoint=/chat/completions "
            "prompt_tokens=11000 generated_tokens=5 finish_reason=stop"
        ]
        verdict = parse_result.classify(events, log_lines)
        self.assertNotIn("WARNING: oracle disagreement", verdict.reason)

    def test_trigger_is_genuinely_parameterized_not_shadowed(self):
        """LOAD-BEARING: proves --predicted-trigger cannot be silently
        shadowed by the module-level PREDICTED_TRIGGER_TOKENS=26542 default.

        outcome3_below_trigger's peak inputTokens is 18400 (below the 26542
        default, hence "below_trigger" with the default). If classify()
        genuinely honors a caller-supplied predicted_trigger, lowering it to
        15000 (below the fixture's peak) must flip the sub-reason away from
        below_trigger - proving the comparison used the parameter, not the
        shadowed constant.
        """
        import parse_result

        events = parse_result.parse_ndjson(
            load_ndjson("outcome3_below_trigger.ndjson")
        )

        default_verdict = parse_result.classify(events, [])
        self.assertIn("never reached", default_verdict.reason)

        lowered_verdict = parse_result.classify(events, [], predicted_trigger=15000)
        self.assertNotIn("never reached", lowered_verdict.reason)


if __name__ == "__main__":
    unittest.main()
