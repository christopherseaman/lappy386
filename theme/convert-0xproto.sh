#!/usr/bin/env bash
# Generate base64-encoded CSS for 0xProto Nerd Font (for blink.sh on iOS)
# Usage: ./generate-0xproto-css.sh [output_dir]
set -euo pipefail
OUTPUT_DIR="${1:-.}"
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT
NF_URL=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip
FONT_FAMILY="0xProto Nerd Font"
CSS_FILE="$OUTPUT_DIR/0xProto Nerd Font.css"
echo "Downloading 0xProto Nerd Font v3.4.0…"
curl -sL "$NF_URL" -o "$WORK_DIR/0xProto.zip"
unzip -qo "$WORK_DIR/0xProto.zip" -d "$WORK_DIR/fonts"
echo "Found fonts:"
find "$WORK_DIR/fonts" -name "*.ttf" -print0 | xargs -0 -n1 basename | sort
encode_font() {
local file=$1
local match
match=$(find "$WORK_DIR/fonts" -name "$file" -type f | head -1)
if [ -z "$match" ]; then
echo "SKIP: $file not found" >&2
return 1
fi
echo "  Encoding: $(basename "$match")" >&2
base64 -w0 < "$match"
}
write_face() {
local style=$1
local weight=$2
local b64=$3
printf '@font-face {\n' >> "$CSS_FILE"
printf '    font-family: "%s";\n' "$FONT_FAMILY" >> "$CSS_FILE"
printf '    font-style: %s;\n' "$style" >> "$CSS_FILE"
printf '    font-weight: %s;\n' "$weight" >> "$CSS_FILE"
printf '    src: url(data:font/ttf;charset-utf-8;base64,%s);\n' "$b64" >> "$CSS_FILE"
printf '}\n' >> "$CSS_FILE"
}
echo ""
echo "Generating CSS…"
mkdir -p "$OUTPUT_DIR"
: > "$CSS_FILE"
if b64=$(encode_font 0xProtoNerdFont-Regular.ttf); then
write_face normal 400 "$b64"
fi
if b64=$(encode_font 0xProtoNerdFont-Bold.ttf); then
write_face normal 700 "$b64"
fi
if b64=$(encode_font 0xProtoNerdFont-Italic.ttf); then
write_face italic 400 "$b64"
fi
echo ""
echo "Done! CSS written to: $CSS_FILE"
echo "Size: $(du -h "$CSS_FILE" | cut -f1)"
echo ""
echo "Copy the CSS file content into blink.sh custom font config."
