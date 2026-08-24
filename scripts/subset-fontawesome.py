#!/usr/bin/env python3
"""Subset the theme's Font Awesome web fonts down to the glyphs this site uses.

Why this exists
---------------
hugo-coder ships the full Font Awesome 6 Free web fonts and preloads all three
faces on every page: fa-solid-900.woff2 (157 KB), fa-brands-400.woff2 (118 KB)
and fa-regular-400.woff2 (25 KB). That is ~300 KB fetched at the browser's
highest priority, competing with the LCP image, to draw about ten icons.

This script rewrites two of those files containing only the glyphs the site can
actually render, and drops the regular face entirely — nothing on the site uses
a regular-weight icon. Output goes to site/static/fonts/, which shadows the
theme's copies of the same filenames in Hugo's static file union, so the URLs
in the stylesheet and the preload tags are unchanged; they just get small.

This is NOT part of the build. Run it by hand when the icon set changes:

    python3 -m venv .venv && .venv/bin/pip install fonttools brotli
    .venv/bin/python scripts/subset-fontawesome.py

then commit the regenerated .woff2 files. Keeping it out of CI means the deploy
pipeline needs no Python toolchain and the committed fonts are exactly what
ships.

Where the glyph list comes from
-------------------------------
There is no list in this file, on purpose. Two SCSS maps are the single source
of truth, because they are also what emits the CSS classes:

    site/assets/scss/font-awesome/_icons.scss   $site-fa-icons        (solid)
    site/assets/scss/font-awesome/brands.scss   $site-fa-brand-icons  (brands)

Each entry names a $fa-var-* variable, which this script resolves against the
theme's own _variables.scss. So a glyph can never be in the font but missing
from the CSS, or the reverse, and bumping the theme's Font Awesome version
keeps the codepoints correct automatically.

As a backstop it also scans the theme's SCSS for `fa-content($fa-var-x)` calls
and refuses to run if one of those glyphs is not in the solid map. That is how
external-link is caught: _content.scss draws it on an :after pseudo-element for
every outbound link in every post, so it appears nowhere in the HTML and no
amount of grepping the markup for `fa-` will find it.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEME_SCSS = REPO / "site" / "themes" / "hugo-coder" / "assets" / "scss"
FA_SCSS = THEME_SCSS / "font-awesome"
SITE_FA_SCSS = REPO / "site" / "assets" / "scss" / "font-awesome"
SRC = REPO / "site" / "themes" / "hugo-coder" / "static" / "fonts"
DST = REPO / "site" / "static" / "fonts"

# (output filename, overriding SCSS file, Sass map name)
FACES = (
    ("fa-solid-900.woff2", SITE_FA_SCSS / "_icons.scss", "site-fa-icons"),
    ("fa-brands-400.woff2", SITE_FA_SCSS / "brands.scss", "site-fa-brand-icons"),
)

DROPPED = "fa-regular-400.woff2"  # no fa-regular / .far icon exists on the site


def die(msg: str) -> None:
    sys.exit(f"subset-fontawesome: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        die(f"missing {path.relative_to(REPO)} — is the theme submodule checked out?")
    return path.read_text(encoding="utf-8")


def fa_variables() -> dict[str, str]:
    """Map every $fa-var-<name> to its codepoint, from the theme's variables."""
    text = read(FA_SCSS / "_variables.scss")
    return {
        m.group(1): m.group(2).upper()
        for m in re.finditer(r"^\$fa-var-([a-z0-9-]+):\s*\\([0-9a-fA-F]+);", text, re.M)
    }


def map_entries(path: Path, map_name: str) -> list[str]:
    """Pull the $fa-var-* names out of a Sass map literal."""
    text = read(path)
    m = re.search(rf"\${re.escape(map_name)}:\s*\((.*?)\n\);", text, re.S)
    if not m:
        die(f"could not find ${map_name} in {path.relative_to(REPO)}")
    names = re.findall(r"\$fa-var-([a-z0-9-]+)", m.group(1))
    if not names:
        die(f"${map_name} in {path.relative_to(REPO)} lists no $fa-var-* icons")
    return names


def css_injected_icons() -> set[str]:
    """Glyphs the theme draws from CSS, which never appear as a class in HTML."""
    found: set[str] = set()
    for scss in THEME_SCSS.glob("*.scss"):
        found |= set(re.findall(r"fa-content\(\$fa-var-([a-z0-9-]+)\)", scss.read_text(encoding="utf-8")))
    return found


def subset(filename: str, codepoints: dict[str, str]) -> tuple[int, int]:
    src, dst = SRC / filename, DST / filename
    if not src.is_file():
        die(f"missing source font {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    unicodes = ",".join(f"U+{cp}" for cp in sorted(codepoints.values()))
    subprocess.run(
        [
            sys.executable, "-m", "fontTools.subset", str(src),
            f"--unicodes={unicodes}",
            f"--output-file={dst}",
            "--flavor=woff2",
            "--no-hinting",       # icon fonts render from outlines; hints are dead weight
            "--desubroutinize",
            "--drop-tables+=DSIG",
            "--name-IDs=*",       # keep the SIL OFL notice in the name table
        ],
        check=True,
    )
    return src.stat().st_size, dst.stat().st_size


def main() -> None:
    variables = fa_variables()
    plan: list[tuple[str, dict[str, str]]] = []
    solid_names: set[str] = set()

    for filename, scss_path, map_name in FACES:
        names = map_entries(scss_path, map_name)
        unknown = [n for n in names if n not in variables]
        if unknown:
            die(f"${map_name} names icons with no $fa-var-* definition: {', '.join(unknown)}")
        plan.append((filename, {n: variables[n] for n in names}))
        if map_name == "site-fa-icons":
            solid_names = set(names)

    # Backstop: glyphs the theme's CSS injects must be in the solid map.
    missing = sorted(css_injected_icons() - solid_names)
    if missing:
        die(
            "the theme draws these with fa-content() but they are absent from "
            f"$site-fa-icons, so they would render as blank boxes: {', '.join(missing)}"
        )

    before = after = 0
    for filename, codepoints in plan:
        was, now = subset(filename, codepoints)
        before, after = before + was, after + now
        print(f"{filename:<22} {was:>8,} B -> {now:>7,} B  ({len(codepoints)} glyphs)")

    dropped = (SRC / DROPPED).stat().st_size
    before += dropped
    print(f"{DROPPED:<22} {dropped:>8,} B -> {'dropped':>7}  (0 glyphs used)")
    print(f"{'TOTAL':<22} {before:>8,} B -> {after:>7,} B  "
          f"({100 - after * 100 // before}% smaller)")


if __name__ == "__main__":
    main()
