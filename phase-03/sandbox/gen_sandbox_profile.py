#!/usr/bin/env python3
"""
gen_sandbox_profile.py — compiles workspace/ALLOWED_REPOS.json into a
kernel-enforced macOS Seatbelt (sandbox-exec) profile.

DO NOT EDIT the generated sandbox.sb by hand; it is regenerated fresh on
every phase-03/sandbox/run_sandboxed.sh invocation from ALLOWED_REPOS.json.

Profile shape (verified live against /bin/cat, /bin/sh, and node in
03-RESEARCH.md): `(allow default)` base, an explicit
`(deny file-read*/file-write* (subpath <protected-root>))` pair, then an
`(allow file-read*/file-write* (subpath <path>))` pair per punched-through
path (each ALLOWED_REPOS.json entry, Cline's own data dir, and any
--extra-allow paths). Rule ORDER is load-bearing: SBPL is last-match-wins,
so every allow punch-through must be written after the deny-root lines.

Every path written into the profile is os.path.realpath()'d first --
03-RESEARCH.md Pitfall 2 reproduced a real bypass where a deny rule written
in non-canonical (e.g. symlinked /tmp/...) form did not block access via the
canonical (/private/tmp/...) path. Skipping realpath() here re-opens that
exact hole.
"""
import argparse
import datetime
import json
import os
import sys


def load_allowed_repos(path):
    """Parse ALLOWED_REPOS.json, realpath() every repo entry, and validate
    that each resolves to an existing directory and that no entry is nested
    under another. Ignores any top-level key starting with '_' (e.g.
    "_comment"). Exits non-zero (SystemExit) naming the offending entry on
    any validation failure."""
    with open(path) as f:
        data = json.load(f)

    raw_entries = [v for k, v in data.items() if not k.startswith("_")]
    # "repos" is expected to be the (only) non-underscore key, but be
    # tolerant of the shape rather than hardcoding key access twice.
    if "repos" in data:
        raw_repos = data["repos"]
    else:
        sys.exit(f"ALLOWED_REPOS.json at {path!r} has no 'repos' key")

    resolved = []
    for raw in raw_repos:
        real = os.path.realpath(raw)
        if not os.path.isdir(real):
            sys.exit(
                f"ALLOWED_REPOS entry does not resolve to an existing "
                f"directory: {raw!r} -> {real!r}"
            )
        resolved.append(real)

    for a in resolved:
        for b in resolved:
            if a != b and (a + os.sep).startswith(b + os.sep):
                sys.exit(
                    f"{a!r} is nested under {b!r} - list only the "
                    f"outermost path"
                )

    return resolved


def render_profile(protected_root, allow_paths):
    """Pure function: given a (realpath'd) protected root and an ordered
    list of (realpath'd) paths to punch through, return the exact SBPL
    profile text. No file I/O, no timestamp -- deterministic for testing.

    Emits exactly 2 + 2 + 2*len(allow_paths) lines, newline-terminated.
    Only the file-read*/file-write* wildcard forms are used (never the
    narrow file-write-data/file-write-create/file-read-data forms, which
    would leave gaps -- see 03-RESEARCH.md Anti-Patterns)."""
    lines = ["(version 1)", "(allow default)"]
    lines.append(f'(deny file-read* (subpath "{protected_root}"))')
    lines.append(f'(deny file-write* (subpath "{protected_root}"))')
    for p in allow_paths:
        lines.append(f'(allow file-read* (subpath "{p}"))')
        lines.append(f'(allow file-write* (subpath "{p}"))')
    return "\n".join(lines) + "\n"


def _validate_extra_allow(raw):
    real = os.path.realpath(raw)
    if not os.path.isdir(real):
        sys.exit(
            f"--extra-allow entry does not resolve to an existing "
            f"directory: {raw!r} -> {real!r}"
        )
    return real


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Compile ALLOWED_REPOS.json into a Seatbelt sandbox.sb profile"
    )
    parser.add_argument("--allowed-repos", required=True, help="Path to ALLOWED_REPOS.json")
    parser.add_argument("--protected-root", required=True, help="Root to deny-then-punch-through (e.g. $HOME)")
    parser.add_argument("--extra-allow", action="append", default=[], help="Additional path to punch through (repeatable)")
    parser.add_argument("--out", help="Output path for the generated profile")
    parser.add_argument("--print-only", action="store_true", help="Write profile to stdout instead of --out")
    args = parser.parse_args(argv)

    if not args.print_only and not args.out:
        parser.error("--out is required unless --print-only is given")

    repo_paths = load_allowed_repos(args.allowed_repos)
    protected_root = os.path.realpath(args.protected_root)

    # The Cline data dir is always punched through, even with no --extra-allow
    # given at all: it lives under $HOME and would otherwise be caught by the
    # protected-root deny. Callers (e.g. run_sandboxed.sh) may additionally
    # pass it explicitly via --extra-allow (e.g. when CLINE_DATA_DIR has been
    # overridden away from the default in config.env) -- deduplicated below.
    default_cline_dir = _validate_extra_allow(os.path.expanduser("~/.cline"))
    extra_allow = [_validate_extra_allow(p) for p in args.extra_allow]

    allow_paths = []
    for p in repo_paths + [default_cline_dir] + extra_allow:
        if p not in allow_paths:
            allow_paths.append(p)

    body = render_profile(protected_root, allow_paths)

    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    # SBPL requires (version 1) to be the very first form, so the header
    # comment lines go immediately AFTER it -- and are kept OUT of
    # render_profile() so its unit tests can assert exact text without a
    # moving timestamp.
    body_lines = body.split("\n", 1)
    header_comment = (
        f";; DO NOT EDIT — generated from {args.allowed_repos}\n"
        f";; Generated: {timestamp}\n"
    )
    full_text = body_lines[0] + "\n" + header_comment + body_lines[1]

    if args.print_only:
        sys.stdout.write(full_text)
    else:
        with open(args.out, "w") as f:
            f.write(full_text)

    print(f"resolved allow list: {allow_paths}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
