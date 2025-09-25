#!/usr/bin/env python3
"""
Generate sitemap.xml from markdown files.

Defaults:
  - markdown dir: /Users/rishibanerjee/Personal/website/markdowns
  - output sitemap: /Users/rishibanerjee/Personal/website/sitemap.xml

Behavior:
  - For each .md file in the markdown dir (non recursive) use the filename (without .md)
    to produce a slug for the URL.
  - If the file has YAML frontmatter with a created field use that for lastmod.
    Otherwise fallback to the file modification time.
  - Slugification: normalize to ascii, lowercase, replace non alnum with hyphen,
    collapse multiple hyphens and trim.
  - Sort entries newest first by lastmod.
  - Backup existing sitemap to sitemap.xml.bak.TIMESTAMP before overwriting.
"""
from __future__ import annotations

import datetime
import os
import re
import shutil
import sys
import unicodedata
from pathlib import Path
from typing import List, Optional, Tuple

# CONFIG - change these if you like
MARKDOWN_DIR = Path("/Users/rishibanerjee/Personal/website/markdowns")
SITEMAP_OUT = Path("/Users/rishibanerjee/Personal/website/sitemap.xml")
SITE_PREFIX = "https://banerjeerishi.com/text"


def slugify(text: str) -> str:
    # normalize to ascii
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    # replace non alnum with hyphen
    text = re.sub(r"[^a-z0-9]+", "-", text)
    # collapse hyphens and strip
    text = re.sub(r"-{2,}", "-", text).strip("-")
    if not text:
        return "untitled"
    return text


ISO_DATE_RE = re.compile(r"^\s*created\s*:\s*(.+)$", flags=re.I)


def parse_frontmatter_created(text: str) -> Optional[datetime.datetime]:
    """
    Extract 'created' value from YAML frontmatter if present.
    Accepts ISO like 2024-07-07T08:00:00.000Z or simple YYYY-MM-DD.
    Returns an aware datetime in UTC when possible, or None.
    """
    lines = text.splitlines()
    if not lines:
        return None
    # find frontmatter block between first two lines that are exactly '---'
    if len(lines) < 3 or lines[0].strip() != "---":
        return None
    # scan until next '---'
    created_value = None
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        m = ISO_DATE_RE.match(ln)
        if m:
            created_value = m.group(1).strip().strip('"').strip("'")
            break
    if not created_value:
        return None

    # normalize Z to +00:00 for fromisoformat
    if created_value.endswith("Z"):
        created_value = created_value[:-1] + "+00:00"
    # remove trailing fractional timezone if weird
    try:
        dt = datetime.datetime.fromisoformat(created_value)
    except Exception:
        # try parsing just date
        try:
            dt = datetime.datetime.strptime(created_value[:10], "%Y-%m-%d")
        except Exception:
            return None

    # if naive assume UTC
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    else:
        # convert to UTC
        dt = dt.astimezone(datetime.timezone.utc)
    return dt


def file_lastmod(path: Path) -> datetime.datetime:
    """
    Return file modification time as UTC aware datetime
    """
    mtime = path.stat().st_mtime
    return datetime.datetime.fromtimestamp(mtime, tz=datetime.timezone.utc)


def read_frontmatter(path: Path) -> Optional[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return None
    # Only attempt frontmatter parse if file starts with ---
    if not text.startswith("---"):
        return None
    # limit to first 4kB to avoid huge files
    return text[:4096]


def build_entries(markdown_dir: Path) -> List[Tuple[datetime.datetime, str]]:
    """
    Returns list of (lastmod_datetime, slug) for every .md file in markdown_dir
    """
    entries: List[Tuple[datetime.datetime, str]] = []
    for p in sorted(markdown_dir.iterdir()):
        if not p.is_file() or p.suffix.lower() != ".md":
            continue
        title = p.stem  # keep original title for slugification
        url_slug = slugify(title)
        created_dt = None

        fm = read_frontmatter(p)
        if fm:
            created_dt = parse_frontmatter_created(fm)

        if created_dt is None:
            created_dt = file_lastmod(p)

        entries.append((created_dt, url_slug))
    return entries


def format_date_iso(dt: datetime.datetime) -> str:
    # produce YYYY-MM-DD (UTC)
    dt_utc = dt.astimezone(datetime.timezone.utc)
    return dt_utc.strftime("%Y-%m-%d")


def write_sitemap(entries: List[Tuple[datetime.datetime, str]], out_path: Path) -> None:
    # backup existing
    if out_path.exists():
        bak = out_path.with_suffix(out_path.suffix + f".bak.{datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}")
        shutil.copy2(out_path, bak)
        print(f"Backed up existing sitemap to {bak}")

    # sort entries newest first
    entries_sorted = sorted(entries, key=lambda e: e[0], reverse=True)

    lines: List[str] = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    # homepage
    lines.append("  <url>")
    lines.append(f"    <loc>https://banerjeerishi.com/</loc>")
    lines.append(f"    <lastmod>{datetime.datetime.utcnow().strftime('%Y-%m-%d')}</lastmod>")
    lines.append("    <priority>1.00</priority>")
    lines.append("  </url>")

    for dt, slug in entries_sorted:
        lastmod = format_date_iso(dt)
        lines.append("  <url>")
        lines.append(f"    <loc>{SITE_PREFIX}/{slug}.html</loc>")
        lines.append(f"    <lastmod>{lastmod}</lastmod>")
        lines.append("    <priority>0.80</priority>")
        lines.append("  </url>")

    lines.append("</urlset>")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote sitemap to {out_path}")


def main(argv: Optional[List[str]] = None) -> int:
    argv = argv or sys.argv[1:]
    md_dir = Path(argv[0]) if len(argv) >= 1 else MARKDOWN_DIR
    sitemap_out = Path(argv[1]) if len(argv) >= 2 else SITEMAP_OUT

    if not md_dir.exists() or not md_dir.is_dir():
        print(f"Error markdown dir not found: {md_dir}", file=sys.stderr)
        return 2

    entries = build_entries(md_dir)
    if not entries:
        print("No markdown files found, writing sitemap with only homepage.")
    write_sitemap(entries, sitemap_out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
