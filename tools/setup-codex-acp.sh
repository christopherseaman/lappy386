#!/bin/bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    export NVM_DIR="$HOME/.config/nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        echo "Codex ACP: Node/npm unavailable; run setup-cli.sh to install nvm first." >&2
        exit 1
    fi
    set +u
    source "$NVM_DIR/nvm.sh" --no-use
    nvm install --lts
    nvm alias default 'lts/*'
    set -u
fi

node --version
npm --version

CODEX_ACP_BIN="$HOME/.local/bin/codex-acp"
if [ -e "$CODEX_ACP_BIN" ] || [ -L "$CODEX_ACP_BIN" ]; then
    if [ -x "$CODEX_ACP_BIN" ] && VERSION="$("$CODEX_ACP_BIN" --version)"; then
        case "$VERSION" in
            '@agentclientprotocol/codex-acp '*)
                echo "Codex ACP: $VERSION (already installed)"
                exit 0
                ;;
        esac
    fi
    echo "Codex ACP: refusing to overwrite conflicting or unhealthy $CODEX_ACP_BIN." >&2
    exit 1
fi

npm install --global --prefix "$HOME/.local" @agentclientprotocol/codex-acp@latest
"$CODEX_ACP_BIN" --version
