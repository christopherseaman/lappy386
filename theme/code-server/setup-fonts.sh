#!/bin/bash
# Install 0xProto Nerd Font Mono into code-server
# Patches workbench.html to load @font-face CSS and copies TTF files
# Re-run after code-server updates (package replaces workbench.html)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CS_BASE="/usr/lib/code-server/lib/vscode/out"
CS_FONTS="$CS_BASE/fonts"
CS_WORKBENCH="$CS_BASE/vs/code/browser/workbench/workbench.html"
CS_SETTINGS="$HOME/.local/share/code-server/User/settings.json"

NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip"
FONT_CSS="$SCRIPT_DIR/0xproto-nerd-codeserver.css"
LINK_TAG='<link rel="stylesheet" href="{{WORKBENCH_WEB_BASE_URL}}/out/fonts/0xproto-nerd-codeserver.css">'

# Check code-server is installed
if [ ! -f "$CS_WORKBENCH" ]; then
    echo "code-server not found at $CS_BASE"
    exit 1
fi

# Download fonts if not cached locally
FONT_DIR="$HOME/font"
if [ ! -f "$FONT_DIR/0xProtoNerdFontMono-Regular.ttf" ]; then
    echo "Downloading 0xProto Nerd Font..."
    mkdir -p "$FONT_DIR"
    WORK_DIR=$(mktemp -d)
    trap "rm -rf $WORK_DIR" EXIT
    curl -sL "$NF_URL" -o "$WORK_DIR/0xProto.zip"
    unzip -qo "$WORK_DIR/0xProto.zip" -d "$FONT_DIR"
    echo "Fonts downloaded to $FONT_DIR"
else
    echo "Fonts already present in $FONT_DIR"
fi

# Copy TTFs and CSS to code-server static dir
echo "Installing fonts to code-server..."
sudo mkdir -p "$CS_FONTS"
sudo cp "$FONT_DIR"/0xProtoNerdFontMono-{Regular,Bold,Italic}.ttf "$CS_FONTS/"
sudo cp "$FONT_CSS" "$CS_FONTS/"

# Backup and patch workbench.html (idempotent)
if ! grep -q "0xproto-nerd-codeserver.css" "$CS_WORKBENCH"; then
    echo "Patching workbench.html..."
    sudo cp "$CS_WORKBENCH" "$CS_WORKBENCH.bak"
    sudo sed -i "s|</head>|\t\t${LINK_TAG}\n\t</head>|" "$CS_WORKBENCH"
else
    echo "workbench.html already patched"
fi

# Set editor font in settings.json
if [ -f "$CS_SETTINGS" ]; then
    if grep -q "editor.fontFamily" "$CS_SETTINGS"; then
        echo "editor.fontFamily already set in $CS_SETTINGS — verify it includes '0xProto Nerd Font Mono'"
    else
        # Insert before the last closing brace
        sed -i 's/}$/,\n    "editor.fontFamily": "0xProto Nerd Font Mono, monospace"\n}/' "$CS_SETTINGS"
        echo "Added editor.fontFamily to settings.json"
    fi
else
    mkdir -p "$(dirname "$CS_SETTINGS")"
    cat > "$CS_SETTINGS" <<'EOF'
{
    "editor.fontFamily": "0xProto Nerd Font Mono, monospace"
}
EOF
    echo "Created settings.json with font family"
fi

# Restart code-server
echo "Restarting code-server..."
sudo systemctl restart "code-server@$(whoami)"

echo "Done! Hard-refresh the browser to load the font."
