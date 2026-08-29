"""
Test-first (RED phase) suite for phase-03/sandbox/gen_sandbox_profile.py —
the ALLOWED_REPOS.json -> sandbox.sb SBPL compiler.

Written before the implementation exists per the plan's TDD instruction.
render_profile() is a pure function of its arguments, and load_allowed_repos()
is a pure function of a JSON path plus the real filesystem — both are directly
testable without invoking sandbox-exec itself (that's covered by the plan's
live end-to-end verify step, not by this file).

The module under test lives in a sibling directory with a hyphenated parent
(phase-03/sandbox/), so it is imported by file path via importlib rather than
a normal package import.
"""
import importlib.util
import json
import sys
import unittest
from pathlib import Path

GEN_SCRIPT = Path(__file__).parent.parent / "sandbox" / "gen_sandbox_profile.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("gen_sandbox_profile", GEN_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestRenderProfile(unittest.TestCase):
    """Case 1: exact profile text and rule ordering."""

    def test_exact_text_and_ordering(self):
        gsp = _load_module()
        text = gsp.render_profile(
            "/Users/ohama", ["/Users/ohama/.cline", "/p/repo-a"]
        )
        expected = (
            "(version 1)\n"
            "(allow default)\n"
            '(deny file-read* (subpath "/Users/ohama"))\n'
            '(deny file-write* (subpath "/Users/ohama"))\n'
            '(allow file-read* (subpath "/Users/ohama/.cline"))\n'
            '(allow file-write* (subpath "/Users/ohama/.cline"))\n'
            '(allow file-read* (subpath "/p/repo-a"))\n'
            '(allow file-write* (subpath "/p/repo-a"))\n'
        )
        self.assertEqual(text, expected)

    def test_allow_punchthroughs_come_after_deny_root(self):
        gsp = _load_module()
        text = gsp.render_profile(
            "/Users/ohama", ["/Users/ohama/.cline", "/p/repo-a"]
        )
        lines = text.splitlines()
        deny_read_idx = lines.index('(deny file-read* (subpath "/Users/ohama"))')
        deny_write_idx = lines.index('(deny file-write* (subpath "/Users/ohama"))')
        first_allow_read_idx = next(
            i for i, l in enumerate(lines) if l.startswith("(allow file-read*")
        )
        self.assertGreater(first_allow_read_idx, deny_read_idx)
        self.assertGreater(first_allow_read_idx, deny_write_idx)


class TestWildcardFormsOnly(unittest.TestCase):
    """Case 2: only file-read*/file-write* wildcards, never the narrow forms."""

    def test_no_narrow_rule_forms(self):
        gsp = _load_module()
        text = gsp.render_profile("/Users/ohama", ["/p/repo-a"])
        self.assertNotIn("file-write-data", text)
        self.assertNotIn("file-write-create", text)
        self.assertNotIn("file-read-data", text)


class TestCanonicalization(unittest.TestCase):
    """Case 3: the reproduced symlink-vs-canonical bypass from 03-RESEARCH.md
    Pitfall 2. A whitelist entry spelled through a symlink must resolve to,
    and be rendered as, its realpath'd canonical form."""

    def test_symlink_repo_entry_resolves_to_realpath(self, tmp_path=None):
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            real_dir = tmp_path / "real"
            real_dir.mkdir()
            link_dir = tmp_path / "link"
            link_dir.symlink_to(real_dir)

            allowed_json = tmp_path / "ALLOWED_REPOS.json"
            allowed_json.write_text(json.dumps({"repos": [str(link_dir)]}))

            gsp = _load_module()
            resolved = gsp.load_allowed_repos(str(allowed_json))

            self.assertEqual(len(resolved), 1)
            self.assertEqual(resolved[0], str(real_dir.resolve()))
            self.assertNotIn(str(link_dir), resolved)

            text = gsp.render_profile("/Users/ohama", resolved)
            self.assertIn(str(real_dir.resolve()), text)
            self.assertNotIn(str(link_dir), text)

    def test_protected_root_symlink_resolves_to_realpath(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            real_home = tmp_path / "real_home"
            real_home.mkdir()
            link_home = tmp_path / "link_home"
            link_home.symlink_to(real_home)

            gsp = _load_module()
            import os

            protected_realpath = os.path.realpath(str(link_home))
            text = gsp.render_profile(protected_realpath, [])
            self.assertIn(str(real_home.resolve()), text)
            self.assertNotIn(str(link_home) + '"', text)


class TestValidation(unittest.TestCase):
    """Case 4: load_allowed_repos exits non-zero, naming the offending entry,
    on nonexistent entries, file (not dir) entries, and nested entries."""

    def test_nonexistent_entry_exits(self):
        import tempfile

        gsp = _load_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            missing = Path(tmpdir) / "does-not-exist"
            allowed_json = Path(tmpdir) / "ALLOWED_REPOS.json"
            allowed_json.write_text(json.dumps({"repos": [str(missing)]}))
            with self.assertRaises(SystemExit) as ctx:
                gsp.load_allowed_repos(str(allowed_json))
            self.assertIn(str(missing), str(ctx.exception))

    def test_file_not_directory_entry_exits(self):
        import tempfile

        gsp = _load_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            a_file = Path(tmpdir) / "not-a-dir.txt"
            a_file.write_text("x")
            allowed_json = Path(tmpdir) / "ALLOWED_REPOS.json"
            allowed_json.write_text(json.dumps({"repos": [str(a_file)]}))
            with self.assertRaises(SystemExit) as ctx:
                gsp.load_allowed_repos(str(allowed_json))
            self.assertIn(str(a_file), str(ctx.exception))

    def test_nested_entries_exit(self):
        import tempfile

        gsp = _load_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            outer = Path(tmpdir) / "a"
            inner = outer / "b"
            inner.mkdir(parents=True)
            allowed_json = Path(tmpdir) / "ALLOWED_REPOS.json"
            allowed_json.write_text(
                json.dumps({"repos": [str(outer), str(inner)]})
            )
            with self.assertRaises(SystemExit) as ctx:
                gsp.load_allowed_repos(str(allowed_json))
            msg = str(ctx.exception)
            self.assertTrue(str(inner) in msg or str(outer) in msg)

    def test_underscore_keys_ignored(self):
        import tempfile

        gsp = _load_module()
        with tempfile.TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir) / "repo"
            repo.mkdir()
            allowed_json = Path(tmpdir) / "ALLOWED_REPOS.json"
            allowed_json.write_text(
                json.dumps({"_comment": "not a repo", "repos": [str(repo)]})
            )
            resolved = gsp.load_allowed_repos(str(allowed_json))
            self.assertEqual(resolved, [str(repo.resolve())])


class TestPrefixBoundary(unittest.TestCase):
    """Case 5: the generator emits one exact subpath per entry and invents
    nothing wider — /a/allowed_extra must not appear just because
    /a/allowed is an entry."""

    def test_no_invented_wider_rule(self):
        gsp = _load_module()
        text = gsp.render_profile("/Users/ohama", ["/a/allowed"])
        self.assertNotIn('"/a/allowed_extra"', text)
        self.assertIn('"/a/allowed"', text)


class TestEmptyReposList(unittest.TestCase):
    """Case 6: an empty repos list must still emit a valid, deny-having
    profile -- never an empty or deny-less (fail-open) profile."""

    def test_empty_allow_list_still_denies_root(self):
        gsp = _load_module()
        text = gsp.render_profile("/Users/ohama", [])
        self.assertIn("(version 1)", text)
        self.assertIn("(allow default)", text)
        self.assertIn('(deny file-read* (subpath "/Users/ohama"))', text)
        self.assertIn('(deny file-write* (subpath "/Users/ohama"))', text)


if __name__ == "__main__":
    unittest.main()
