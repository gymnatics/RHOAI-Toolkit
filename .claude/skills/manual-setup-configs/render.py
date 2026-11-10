#!/usr/bin/env python3
"""Render the standalone manual-setup guide from template.md.

Lines of the form  {{file:<repo-relative-path>}}  are replaced with the exact
contents of that file, so the guide's inline YAML always matches lib/manifests/.

Usage (from repo root):
  python3 .claude/skills/manual-setup-configs/render.py            # write guide
  python3 .claude/skills/manual-setup-configs/render.py --check    # exit 1 if guide is stale
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
TEMPLATE = pathlib.Path(__file__).with_name("template.md")
OUTPUT = ROOT / "docs/guides/rhoai-3.5/RHOAI-35-MANUAL-SETUP-CONFIGS.md"
MARKER = re.compile(r"^\{\{file:(?P<path>[^}]+)\}\}$")


def render() -> str:
    out = []
    for line in TEMPLATE.read_text().splitlines():
        m = MARKER.match(line.strip())
        if not m:
            out.append(line)
            continue
        src = ROOT / m.group("path")
        text = src.read_text().rstrip("\n")
        if re.search(r"^EOF$", text, re.M):
            sys.exit(f"{src}: contains a bare EOF line, which would break the heredoc")
        out.append(text)
    return "\n".join(out) + "\n"


def main() -> None:
    rendered = render()
    if "--check" in sys.argv:
        current = OUTPUT.read_text() if OUTPUT.exists() else ""
        if current != rendered:
            print(f"STALE: {OUTPUT.relative_to(ROOT)} differs from template + manifests; re-run render.py")
            sys.exit(1)
        print("OK: guide is in sync with manifests")
        return
    OUTPUT.write_text(rendered)
    print(f"wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
