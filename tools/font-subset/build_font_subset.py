#!/usr/bin/env python3
"""Build the shipped UI font: a subset of Noto Sans SC, renamed for OFL.

Why a subset: the full Noto Sans SC is ~8 MB per weight. Shipping it would put
every byte of a CJK font into a desktop installer and a Web package that
[CD-62](../../Confirmed-docs/60-plan/62-risk-register.md) already flags for size.
The human-pinned scope is "common 3500 chars" (see README.md), which lands at
well under 1 MB.

Why the rename: SIL OFL 1.1 has a Reserved Font Name clause. "Noto Sans SC" is
reserved, and a *modified* derivative (a subset is a modification) may not carry
it. So the output is renamed to the project's own family before it is written.
The test suite asserts the reserved name is gone — the rename is a licence
obligation, not cosmetics.

Source pinning: the upstream file is fetched by URL and checked against a
recorded SHA-256. Upstream moving the file fails the build loudly instead of
silently producing a different font.

Usage:
    python3 tools/font-subset/build_font_subset.py            # build
    python3 tools/font-subset/build_font_subset.py --check    # verify output only
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = REPO_ROOT / "tools" / "font-subset"
# Charsets ship with the font (see collect_project_chars.py) so the packaged
# subset carries its own spec and `res://` tests can read it.
CHARSET_DIR = REPO_ROOT / "game" / "content" / "ui" / "fonts" / "charsets"

SOURCE_URL = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/main/"
    "Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
)
SOURCE_SHA256 = "faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9"

OUTPUT_FONT = REPO_ROOT / "game" / "content" / "ui" / "fonts" / "craftarena_sans_sc_regular.otf"
OUTPUT_LICENSE = REPO_ROOT / "game" / "content" / "ui" / "fonts" / "OFL-1.1.txt"
LICENSE_SOURCE = TOOL_DIR / "licenses" / "OFL-1.1.txt"

CACHE = TOOL_DIR / ".cache" / "NotoSansSC-Regular.otf"

# Reserved Font Name ("Noto Sans SC") must not survive into the output.
FAMILY = "CraftArena Sans SC"
SUBFAMILY = "Regular"
FULL_NAME = f"{FAMILY} {SUBFAMILY}"
PS_NAME = "CraftArenaSansSC-Regular"
UNIQUE_ID = f"{FULL_NAME} : 2026 : Craft Arena"
VERSION = "Version 1.000"

# name-table IDs: 1 family, 2 subfamily, 3 unique id, 4 full name,
# 6 PostScript name, 16/17 typographic family/subfamily.
NAME_IDS = (1, 2, 3, 4, 6, 16, 17)

# 7 = trademark. Not a copyright notice, so it goes; see rename().
TRADEMARK_NAME_ID = 7

# Reserved Font Names on this upstream file: "Noto Sans SC" (Google) and
# "Source" (Adobe, the Source Han Sans lineage). A subset may not carry either.
# They are still allowed in ID 0 (copyright) and 13/14 (licence text) — OFL
# *requires* those to survive, so the check is scoped to naming IDs only.
RESERVED_NAMES = ("Noto", "Source")
NAMING_IDS = (1, 2, 3, 4, 6, 16, 17)

# Printable ASCII is the floor. The common table stores one char per line, so a
# space is literally unrepresentable there, and English copy ("Solo play",
# "Offline play, scores are not uploaded") is full of them. Requesting the whole
# range costs a few hundred bytes and removes a whole class of "why is there a
# box in the middle of a sentence" bugs.
ASCII_PRINTABLE = "".join(chr(code) for code in range(0x20, 0x7F))

# Symbols the UI reaches for on its own, on top of the two charset files.
EXTRA_CHARS = ASCII_PRINTABLE + "×÷°′″§¶·•…—–‘’“”〈〉《》「」『』【】〔〕℃℉№"

# Deliberately tighter than the 2 MB single-file budget that the GUT suite
# asserts (CD-11 section 8.1, mirrored in test_font_packaging.gd). The GUT number
# is the contract — "this must not ship oversized"; this one is a tripwire — "the
# subset just grew by 80%, go look at why". Neither is a new budget: nobody here
# is allowed to invent font size numbers.
MAX_OUTPUT_BYTES = 1_500_000


def load_charsets() -> list[str]:
    chars: list[str] = []
    for name in ("common_3500.txt", "project_supplement.txt"):
        path = CHARSET_DIR / name
        if not path.exists():
            print(f"missing charset: {path}", file=sys.stderr)
            raise SystemExit(1)
        for line in path.read_text(encoding="utf-8").splitlines():
            for ch in line:
                chars.append(ch)
    chars.extend(EXTRA_CHARS)
    deduped: list[str] = []
    seen: set[str] = set()
    for ch in chars:
        if ch in seen:
            continue
        seen.add(ch)
        deduped.append(ch)
    return deduped


def fetch_source() -> Path:
    if CACHE.exists():
        digest = hashlib.sha256(CACHE.read_bytes()).hexdigest()
        if digest == SOURCE_SHA256:
            return CACHE
        print("cache sha256 mismatch, re-fetching", file=sys.stderr)
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    print(f"fetching {SOURCE_URL}")
    with urllib.request.urlopen(SOURCE_URL, timeout=180) as response:  # noqa: S310
        data = response.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCE_SHA256:
        print(
            "source sha256 changed:\n"
            f"  expected {SOURCE_SHA256}\n"
            f"  actual   {digest}\n"
            "Update SOURCE_SHA256 only after a human confirms the new upstream file.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    CACHE.write_bytes(data)
    return CACHE


def subset(source: Path, chars: list[str], out: Path) -> None:
    from fontTools import subset  # noqa: PLC0415 - dev-time only

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.drop_tables += ["DSIG"]
    options.desubroutinize = True
    options.hinting = False

    font = subset.load_font(str(source), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="".join(chars))
    subsetter.subset(font)
    out.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(out), options)


def rename(out: Path) -> None:
    from fontTools.ttLib import TTFont  # noqa: PLC0415 - dev-time only

    font = TTFont(out)
    if "name" not in font:
        print("subset has no name table", file=sys.stderr)
        raise SystemExit(1)
    table = font["name"]
    values = {
        1: FAMILY,
        2: SUBFAMILY,
        3: UNIQUE_ID,
        4: FULL_NAME,
        6: PS_NAME,
        16: FAMILY,
        17: SUBFAMILY,
    }
    # The trademark notice is not a copyright notice: OFL requires the latter to
    # survive, and requires the Reserved Font Name not to. Dropping ID 7 keeps
    # both obligations true at once.
    for name_id in set(NAME_IDS) | {TRADEMARK_NAME_ID}:
        table.removeNames(nameID=name_id)
    # Rebuild from scratch rather than overwriting: the upstream file carries
    # each name in several platform/encoding/language combinations, and any
    # combination missed here would keep the reserved name alive.
    for name_id in NAME_IDS:
        table.setName(values[name_id], name_id, 3, 1, 0x409)
        table.setName(values[name_id], name_id, 1, 0, 0)
    if "CFF " in font:
        cff = font["CFF "]
        cff.cff.fontNames = [PS_NAME]
        cff.cff.topDictIndex[0].FullName = FULL_NAME
        cff.cff.topDictIndex[0].FamilyName = FAMILY
    font.save(out)


def report(out: Path, chars: list[str]) -> None:
    from fontTools.ttLib import TTFont  # noqa: PLC0415 - dev-time only

    font = TTFont(out)
    cmap: set[int] = set()
    for table in font["cmap"].tables:
        cmap |= set(table.cmap.keys())
    missing = sorted({ch for ch in chars if ord(ch) not in cmap})
    size = out.stat().st_size
    print(f"output      {out.relative_to(REPO_ROOT)}")
    print(f"requested   {len(chars)} chars")
    print(f"in cmap     {len(cmap)} codepoints")
    print(f"size        {size} bytes")
    if missing:
        preview = "".join(missing[:40])
        print(
            f"WARN {len(missing)} requested chars have no glyph upstream: {preview}",
            file=sys.stderr,
        )
    if size > MAX_OUTPUT_BYTES:
        print(
            f"over budget: {size} > {MAX_OUTPUT_BYTES} bytes",
            file=sys.stderr,
        )
        raise SystemExit(1)


def check() -> int:
    if not OUTPUT_FONT.exists():
        print(f"missing {OUTPUT_FONT}", file=sys.stderr)
        return 1
    from fontTools.ttLib import TTFont  # noqa: PLC0415 - dev-time only

    font = TTFont(OUTPUT_FONT)
    for rec in font["name"].names:
        if rec.nameID not in NAMING_IDS:
            continue
        text = rec.toUnicode()
        for reserved in RESERVED_NAMES:
            if reserved in text:
                print(
                    f"reserved font name {reserved!r} leaked into nameID {rec.nameID}: {text!r}",
                    file=sys.stderr,
                )
                return 1
    size = OUTPUT_FONT.stat().st_size
    if size > MAX_OUTPUT_BYTES:
        print(f"over budget: {size} > {MAX_OUTPUT_BYTES}", file=sys.stderr)
        return 1
    if not OUTPUT_LICENSE.exists():
        print(f"missing {OUTPUT_LICENSE}", file=sys.stderr)
        return 1
    print(f"ok: {OUTPUT_FONT.name}, {size} bytes, licence file present")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify the shipped font only")
    args = parser.parse_args()

    if args.check:
        return check()

    chars = load_charsets()
    source = fetch_source()
    subset(source, chars, OUTPUT_FONT)
    rename(OUTPUT_FONT)
    shutil.copyfile(LICENSE_SOURCE, OUTPUT_LICENSE)
    report(OUTPUT_FONT, chars)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
