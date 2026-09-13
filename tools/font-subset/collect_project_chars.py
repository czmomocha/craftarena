#!/usr/bin/env python3
"""Collect every character the shipped project can render, as a subset supplement.

The 3500-char common table (see README.md) is a national standard, not a
description of this repo. Hard-coded Chinese in `.gd`, button text in `.tscn`,
the locale CSV and the official course JSON all ship to players, and any of them
may hold a character outside that table. This scanner turns "whatever the repo
actually typesets" into a file, so the subset can be regenerated after copy
changes instead of silently losing glyphs.

Scanning is deliberately dumb: every non-ASCII char in the scanned files goes in,
comments included. Hand-picking the player-visible strings would be smaller, but
a missed one produces no error at all — the engine fallback just draws a
lookalike glyph. Comments cost a few dozen KB and remove that failure mode. See
README.md section 2.2.

Usage:
    python3 tools/font-subset/collect_project_chars.py [--check]

`--check` exits non-zero when the checked-in supplement is stale.

**This script does not run in CI** (Python + fontTools are not installed there;
adding them is a human gate under constitution article 18). So "changing a
string can never silently lose a glyph" is *not* an enforced property: the GUT
suite asserts the font covers the checked-in supplement, and nothing asserts the
supplement is current. Re-running this after a copy change is a manual step,
listed in README.md section 4.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# The supplement lives next to the font it feeds, not next to the tool: it is
# part of the packaged content ("what does this subset cover"), and it has to be
# readable as `res://` so the GUT coverage test can assert against it.
OUTPUT = REPO_ROOT / "game" / "content" / "ui" / "fonts" / "charsets" / "project_supplement.txt"

SCAN_DIRS = (
    "game/src",
    "game/content/locale",
    "game/content/official",
)

SCAN_SUFFIXES = (".gd", ".tscn", ".tres", ".csv", ".json")

SKIP_DIR_NAMES = {".godot", "addons", "_source_refs", "export"}


def collect() -> list[str]:
    seen: set[str] = set()
    order: list[str] = []
    for rel in SCAN_DIRS:
        base = REPO_ROOT / rel
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in SCAN_SUFFIXES:
                continue
            if any(part in SKIP_DIR_NAMES for part in path.relative_to(REPO_ROOT).parts):
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            for ch in text:
                if ord(ch) < 128:
                    continue
                if ch in seen:
                    continue
                seen.add(ch)
                order.append(ch)
    return order


def render(chars: list[str]) -> str:
    return "".join(f"{ch}\n" for ch in sorted(chars))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail when the checked-in supplement differs from a fresh scan",
    )
    args = parser.parse_args()

    fresh = render(collect())
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != fresh:
            print(
                f"stale: {OUTPUT.relative_to(REPO_ROOT)}\n"
                "  run: python3 tools/font-subset/collect_project_chars.py",
                file=sys.stderr,
            )
            return 1
        print(f"ok: {len(fresh.splitlines())} chars, supplement up to date")
        return 0

    OUTPUT.write_text(fresh, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)}: {len(fresh.splitlines())} chars")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
