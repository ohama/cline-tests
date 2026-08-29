#!/usr/bin/env python3
"""
gen_filler.py - deterministic, properly line-wrapped filler file generator.

Directly implements RESEARCH.md Pitfall 3: Cline's tool-output limiter truncates
pathologically long single lines and reports "[line truncated]", which silently
collapses a file's token contribution from ~2,300 tokens down to ~650. Every file
this script writes is wrapped at ~100 characters via textwrap.fill(width=100), so
no line can ever approach that limiter.

Stdlib only: random, textwrap, pathlib, argparse.

Usage:
    python3 phase-01/filler/gen_filler.py [--count 12] [--outdir phase-01/filler] [--seed 20260829]

Same --seed + --count always produces byte-identical files (VER-01 requires the
regression test to be RE-runnable, not merely re-executable).
"""
import argparse
import random
import textwrap
from pathlib import Path

# Seeded pseudo-technical/prose word pool. Deliberately plausible-looking rather
# than lorem-ipsum, so a human skimming ndjson.log transcripts recognizes it as
# intentional filler rather than mistaking it for real task content.
_WORDS = [
    "context", "window", "token", "budget", "compaction", "trigger", "threshold",
    "provider", "endpoint", "latency", "prefill", "generation", "queue", "server",
    "config", "override", "baseline", "regression", "harness", "runner", "fixture",
    "classifier", "verdict", "evidence", "oracle", "log", "slice", "offset", "byte",
    "line", "wrap", "truncate", "limiter", "tool", "call", "loop", "iteration",
    "assistant", "message", "conversation", "history", "buffer", "growth", "measure",
    "observed", "predicted", "derive", "formula", "ratio", "effective", "maximum",
    "input", "output", "usage", "notice", "status", "auto", "manual", "pipeline",
    "artifact", "snapshot", "durable", "drift", "version", "pin", "invocation",
    "environment", "variable", "flag", "argument", "default", "explicit", "implicit",
    "gateway", "reject", "accept", "response", "request", "payload", "header",
    "socket", "stream", "chunk", "batch", "worker", "thread", "process", "daemon",
    "service", "cluster", "node", "shard", "replica", "cache", "memory", "disk",
    "network", "bandwidth", "throughput", "concurrency", "parallel", "sequential",
    "deterministic", "random", "seed", "sample", "distribution", "variance", "mean",
    "median", "percentile", "outlier", "anomaly", "signal", "noise", "filter",
    "transform", "encode", "decode", "serialize", "deserialize", "schema", "field",
    "attribute", "property", "value", "type", "class", "instance", "object", "array",
    "index", "key", "map", "set", "list", "tuple", "record", "entry", "row", "column",
    "table", "database", "query", "transaction", "commit", "rollback", "isolation",
    "consistency", "availability", "partition", "resilience", "fallback", "retry",
    "backoff", "circuit", "breaker", "timeout", "deadline", "budgetary", "capacity",
    "utilization", "saturation", "pressure", "backpressure", "flow", "control",
]

_HEADER_TEMPLATE = "FILLER FILE {num:02d} - seed {seed}"
_WRAP_WIDTH = 100
_TARGET_MIN_BYTES = 8500
_TARGET_MAX_BYTES = 9200
_LINE_HARD_LIMIT = 120


def _render(rng, num, seed, n_words):
    """Render one filler file's full text for a given word count."""
    header = _HEADER_TEMPLATE.format(num=num, seed=seed)
    body_words = [rng.choice(_WORDS) for _ in range(n_words)]
    body_text = " ".join(body_words)
    wrapped = textwrap.fill(body_text, width=_WRAP_WIDTH)
    return header + "\n" + wrapped + "\n"


def generate_file_text(num, seed):
    """Deterministically generate one filler file's text within the byte target.

    Grows the word count until the wrapped text lands inside
    [_TARGET_MIN_BYTES, _TARGET_MAX_BYTES], using a fresh Random seeded from
    (seed, num) so output is byte-identical across regenerations and
    independent across files.
    """
    rng = random.Random(f"{seed}-{num}")
    n_words = 1400  # initial guess, close to the ~8.8KB target at this word pool
    text = _render(rng, num, seed, n_words)

    # Grow/shrink word count until byte length lands in range. Each step
    # re-seeds the same Random state deterministically by rebuilding rng.
    guard = 0
    while len(text.encode("utf-8")) < _TARGET_MIN_BYTES and guard < 200:
        n_words += 20
        rng = random.Random(f"{seed}-{num}")
        text = _render(rng, num, seed, n_words)
        guard += 1

    while len(text.encode("utf-8")) > _TARGET_MAX_BYTES and guard < 400:
        n_words -= 5
        rng = random.Random(f"{seed}-{num}")
        text = _render(rng, num, seed, n_words)
        guard += 1

    return text


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=12)
    parser.add_argument("--outdir", default="phase-01/filler")
    parser.add_argument("--seed", default="20260829")
    args = parser.parse_args(argv)

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    rows = []
    for i in range(1, args.count + 1):
        text = generate_file_text(i, args.seed)
        path = outdir / f"wrapped_{i:02d}.txt"
        path.write_text(text)

        raw_bytes = text.encode("utf-8")
        lines = text.splitlines()
        max_line_len = max((len(l) for l in lines), default=0)
        est_tokens = len(raw_bytes) / 3.8
        rows.append((path.name, len(raw_bytes), len(lines), max_line_len, est_tokens))

    print(f"{'file':<16}{'bytes':>8}{'lines':>8}{'max_len':>9}{'est_tokens(~)':>15}")
    for name, nbytes, nlines, max_len, est_tokens in rows:
        print(f"{name:<16}{nbytes:>8}{nlines:>8}{max_len:>9}{est_tokens:>15.0f}")

    over_limit = [r for r in rows if r[3] > _LINE_HARD_LIMIT]
    if over_limit:
        raise SystemExit(
            f"BUG: {len(over_limit)} file(s) exceeded the {_LINE_HARD_LIMIT}-char "
            f"hard line limit: {[r[0] for r in over_limit]}"
        )


if __name__ == "__main__":
    main()
