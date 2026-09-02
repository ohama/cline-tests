#!/usr/bin/env python3
"""grade_ab.py -- turn a raw `cline --json` NDJSON stream into exactly one of four verdicts.

usage: grade_ab.py --ndjson <stream.log> --expected <task.expected> [--json]

Verdicts (never more, never fewer):
  correct     -- an ANSWER: line was found in the model's visible output and matches the key.
  incorrect   -- an ANSWER: line was found in the model's visible output and does not match.
  no-answer   -- visible output exists but carries no ANSWER: line. If an ANSWER: line was
                 found only inside reasoning-marked content, the qualifier
                 answer-seen-in-reasoning-only is attached -- the verdict itself never changes
                 to correct or incorrect on the strength of a reasoning-only match.
  no-output   -- no visible text at all was produced (the empty-content / finish_reason:length
                 shape phase-09/PRB-03-ORACLE.md Section 3 measured for a starved thinking arm).
  unparseable -- the file is missing, empty, or contains no valid JSON line at all.

Extraction is deliberately shape-tolerant (phase-10/VRF-04-OBSERVATION.md Section 2 found the
3.0.53-documented NDJSON shape must not be trusted as the only path at 3.0.60): every JSON line is
walked recursively; any dict is treated as "reasoning" for its own text/content keys and for every
dict nested inside it if the dict itself carries a contentType/type/kind/block_type field whose
value is (case-insensitively) "reasoning", mirroring the real shape phase-10 captured:
    {"event": {"type": "content_start", "contentType": "reasoning", "text": "..."}}
A raw whole-file substring scan for "ANSWER:" is kept as a separate, reported-only fallback net --
it is never allowed to overturn a verdict path 1/3 already decided (see module docstring above and
the no-answer rule).

Never prints a verdict its own row does not also justify with its counts.
"""
import argparse
import json
import os
import re
import sys

TEXT_KEYS = ("text", "content")
REASONING_FIELD_KEYS = ("reasoning", "reasoning_content")
MARKER_KEYS = ("contentType", "content_type", "type", "block_type", "kind")

ANSWER_RE = re.compile(r"ANSWER:\s*([^\n\r]*)")


def is_reasoning_marker(d):
    for k in MARKER_KEYS:
        v = d.get(k)
        if isinstance(v, str) and v.strip().lower() == "reasoning":
            return True
    return False


def walk(obj, in_reasoning, visible_chunks, reasoning_chunks):
    if isinstance(obj, dict):
        local_reasoning = in_reasoning or is_reasoning_marker(obj)
        for k, v in obj.items():
            if k in REASONING_FIELD_KEYS and isinstance(v, str):
                reasoning_chunks.append(v)
            elif k in TEXT_KEYS and isinstance(v, str):
                (reasoning_chunks if local_reasoning else visible_chunks).append(v)
            else:
                walk(v, local_reasoning, visible_chunks, reasoning_chunks)
    elif isinstance(obj, list):
        for item in obj:
            walk(item, in_reasoning, visible_chunks, reasoning_chunks)
    # bare strings/numbers/etc. outside a recognised text/content/reasoning key are ignored --
    # only explicit keys are trusted as model output, to avoid vacuuming up ids/timestamps/etc.


def load_ndjson(path):
    """Returns (parsed_objects, raw_text, total_nonblank_lines, bad_line_count, missing: bool)."""
    if not os.path.isfile(path):
        return [], "", 0, 0, True
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
    lines = [l for l in raw.split("\n") if l.strip() != ""]
    objs = []
    bad = 0
    for line in lines:
        try:
            objs.append(json.loads(line))
        except json.JSONDecodeError:
            bad += 1
    return objs, raw, len(lines), bad, False


def extract_answer_value(text):
    matches = ANSWER_RE.findall(text)
    if not matches:
        return None
    val = matches[-1].strip()
    return val if val != "" else None


def normalize_exact(s):
    s = s.strip().lower()
    if s.endswith("."):
        s = s[:-1]
    s = s.replace(",", "")  # thousands separators
    s = re.sub(r"\s+", "", s)  # remaining whitespace, including internal
    return s


def match_exact_normalized(answer, expected):
    return normalize_exact(answer) == normalize_exact(expected)


def match_numeric(answer, expected, tolerance):
    try:
        a = float(answer.strip().replace(",", ""))
        e = float(expected.strip().replace(",", ""))
    except ValueError:
        return False
    return abs(a - e) <= tolerance


def match_regex(answer, expected_pattern):
    try:
        return re.fullmatch(expected_pattern, answer.strip()) is not None
    except re.error:
        return False


def parse_expected_file(path):
    data = {}
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            hash_idx = line.find("#")
            if hash_idx != -1:
                line = line[:hash_idx]
            if ":" not in line:
                continue
            key, _, val = line.partition(":")
            data[key.strip()] = val.strip()
    return data


def grade(ndjson_path, expected_path):
    expected_data = parse_expected_file(expected_path)
    match_mode = expected_data.get("match", "exact_normalized")
    expected_value = expected_data.get("expected", "")
    tolerance = float(expected_data.get("tolerance", "0") or "0")
    task_id = expected_data.get("task_id", "")

    objs, raw, total_lines, bad_lines, missing = load_ndjson(ndjson_path)

    row = {
        "task_id": task_id,
        "verdict": "",
        "qualifier": "",
        "extracted_answer": "",
        "expected": expected_value,
        "match_mode": match_mode,
        "visible_chars": 0,
        "reasoning_chars": 0,
        "ndjson_lines": total_lines,
        "primary_hit": False,
        "fallback_hit": False,
        "reasoning_hit": False,
    }

    if missing or total_lines == 0 or len(objs) == 0:
        row["verdict"] = "unparseable"
        if bad_lines:
            print(
                f"warning: {bad_lines} malformed NDJSON line(s) skipped in {ndjson_path}",
                file=sys.stderr,
            )
        return row

    if bad_lines:
        print(
            f"warning: {bad_lines} malformed NDJSON line(s) skipped in {ndjson_path}",
            file=sys.stderr,
        )

    visible_chunks = []
    reasoning_chunks = []
    for obj in objs:
        walk(obj, False, visible_chunks, reasoning_chunks)
    visible_text = "".join(visible_chunks)
    reasoning_text = "".join(reasoning_chunks)

    row["visible_chars"] = len(visible_text)
    row["reasoning_chars"] = len(reasoning_text)
    row["fallback_hit"] = "ANSWER:" in raw

    primary_answer = extract_answer_value(visible_text)
    reasoning_answer = extract_answer_value(reasoning_text)
    row["reasoning_hit"] = reasoning_answer is not None

    if primary_answer is not None:
        row["primary_hit"] = True
        row["extracted_answer"] = primary_answer
        if match_mode == "numeric":
            ok = match_numeric(primary_answer, expected_value, tolerance)
        elif match_mode == "regex":
            ok = match_regex(primary_answer, expected_value)
        else:
            ok = match_exact_normalized(primary_answer, expected_value)
        row["verdict"] = "correct" if ok else "incorrect"
        return row

    # No ANSWER: found in visible output.
    if visible_text.strip() == "":
        row["verdict"] = "no-output"
        return row

    row["verdict"] = "no-answer"
    if reasoning_answer is not None:
        row["qualifier"] = "answer-seen-in-reasoning-only"
    return row


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ndjson", required=True)
    ap.add_argument("--expected", required=True)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    row = grade(args.ndjson, args.expected)

    if args.json:
        print(json.dumps(row, sort_keys=True))
    else:
        cols = [
            "task_id",
            "verdict",
            "qualifier",
            "extracted_answer",
            "expected",
            "match_mode",
            "visible_chars",
            "reasoning_chars",
            "ndjson_lines",
            "primary_hit",
            "fallback_hit",
            "reasoning_hit",
        ]
        print("\t".join(str(row[c]) for c in cols))

    return 0  # always exit 0 -- a wrong verdict is not a program failure


if __name__ == "__main__":
    sys.exit(main())
