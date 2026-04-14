#!/bin/bash
# Replace code-server favicon with custom icon
# Uses favicon-source.png from this directory
# Re-run after code-server updates (package replaces media files)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CS_MEDIA="/usr/lib/code-server/src/browser/media"
CS_SERVER="/usr/lib/code-server/lib/vscode/resources/server"
SOURCE_PNG="$SCRIPT_DIR/favicon-source.png"

if [ ! -d "$CS_MEDIA" ]; then
    echo "code-server media dir not found at $CS_MEDIA"
    exit 1
fi

if [ ! -f "$SOURCE_PNG" ]; then
    echo "favicon-source.png not found in $SCRIPT_DIR"
    exit 1
fi

# Back up originals (once)
if [ ! -f "$CS_MEDIA/favicon.ico.orig" ]; then
    echo "Backing up original favicons..."
    for f in favicon.ico favicon.svg favicon-dark-support.svg \
             pwa-icon-192.png pwa-icon-512.png \
             pwa-icon-maskable-192.png pwa-icon-maskable-512.png; do
        [ -f "$CS_MEDIA/$f" ] && sudo cp "$CS_MEDIA/$f" "$CS_MEDIA/$f.orig"
    done
    for f in code-192.png code-512.png; do
        [ -f "$CS_SERVER/$f" ] && sudo cp "$CS_SERVER/$f" "$CS_SERVER/$f.orig"
    done
fi

# Generate all favicon sizes from source PNG using Pillow
echo "Generating favicon files from source..."
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

python3 - "$SOURCE_PNG" "$WORK_DIR" <<'PYEOF'
import sys, base64, io
from PIL import Image

src_path, out_dir = sys.argv[1], sys.argv[2]
img = Image.open(src_path).convert("RGBA")

# favicon.ico — multi-size ICO (16, 32, 48)
img.save(f"{out_dir}/favicon.ico", format="ICO", sizes=[(16, 16), (32, 32), (48, 48)])

# PWA icons
for size in [192, 512]:
    resized = img.resize((size, size), Image.LANCZOS)
    resized.save(f"{out_dir}/pwa-icon-{size}.png")
    resized.save(f"{out_dir}/pwa-icon-maskable-{size}.png")
    resized.save(f"{out_dir}/code-{size}.png")

# favicon.svg — embed a 48px PNG as a data URI SVG
buf = io.BytesIO()
img.resize((48, 48), Image.LANCZOS).save(buf, format="PNG")
b64 = base64.b64encode(buf.getvalue()).decode()
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48">
  <image href="data:image/png;base64,{b64}" width="48" height="48"/>
</svg>'''
for name in ["favicon.svg", "favicon-dark-support.svg"]:
    with open(f"{out_dir}/{name}", "w") as f:
        f.write(svg)

print("Generated favicon files")
PYEOF

# Copy generated files to code-server
sudo cp "$WORK_DIR"/favicon.ico "$WORK_DIR"/favicon*.svg \
    "$WORK_DIR"/pwa-icon-*.png "$CS_MEDIA/"
sudo cp "$WORK_DIR"/code-192.png "$WORK_DIR"/code-512.png "$CS_SERVER/"
sudo chmod 644 "$CS_MEDIA"/favicon.ico "$CS_MEDIA"/favicon*.svg \
    "$CS_MEDIA"/pwa-icon-*.png "$CS_SERVER"/code-{192,512}.png

# Restart code-server
echo "Restarting code-server..."
sudo systemctl restart "code-server@$(whoami)"

echo "Done! Hard-refresh the browser to see the new favicon."
