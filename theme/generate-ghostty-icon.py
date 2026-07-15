#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Resize theme/ghostty-chromeos.png into XDG icon sizes for the ChromeOS launcher.

Outputs to theme/icons/hicolor/<size>x<size>/apps/com.mitchellh.ghostty.png
mirroring the XDG hicolor structure so the install step is a direct `cp`.

Start with 256x256 per the reddit recipe; add more sizes if the launcher needs them.
"""
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "theme" / "ghostty-chromeos.png"
OUT_BASE = REPO / "theme" / "icons" / "hicolor"
APP_ID = "com.mitchellh.ghostty"

# Garcon's icon_finder.cc fallback preference list: {256, 128, 96, 64, 48, 32}.
# Start with just 256 (highest preference); expand if needed.
SIZES = [256]


def main() -> None:
    src = Image.open(SRC)
    print(f"source: {SRC} ({src.size[0]}x{src.size[1]} {src.mode})")
    for size in SIZES:
        out_dir = OUT_BASE / f"{size}x{size}" / "apps"
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{APP_ID}.png"
        resized = src.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG", optimize=True)
        print(f"  wrote: {out_path.relative_to(REPO)} ({size}x{size}, {out_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
