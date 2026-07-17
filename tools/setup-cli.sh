#!/bin/bash
# setup-cli.sh — shared user-level CLI/dev layer for both hosts and the agent sandbox guests:
# shell dotfiles, the starship prompt, and on-demand toolchains (nvm, uv, golang, codex).
#
# Runs as the invoking user with NO sudo — system packages (apt/brew) and host-only config
# (git identity, SSH, DNS, nvim, claude) are the caller's responsibility. Idempotent.
# Must be run from the tools/ directory (it reads ./artifacts/).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/.local/bin ~/.config

## Shell dotfiles (installed, not copied — same content the host deploys)
cat artifacts/dot-bashrc  >~/.bashrc
cat artifacts/dot-aliases >~/.aliases
cat artifacts/dot-tmux.conf >~/.tmux.conf
cat artifacts/dot-zshrc   >~/.zshrc
cp artifacts/tmux-zen.sh ~/.local/bin/tmux-zen.sh && chmod +x ~/.local/bin/tmux-zen.sh
cp artifacts/starship.toml ~/.config/starship.toml

## Starship prompt (user-level install, no sudo)
if ! command -v starship >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null
fi
echo "Starship: $(starship --version 2>/dev/null | head -1 || true)"

## uv (Python toolchain manager — provides/manages Python via `uv python install`)
if command -v uv >/dev/null 2>&1; then
  uv self update >/dev/null 2>&1 || true
else
  curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --quiet
fi
echo "uv: $("$HOME/.local/bin/uv" --version 2>/dev/null | head -1 || uv --version 2>/dev/null | head -1 || true)"

## nvm (Node version manager — install manager only; node pulled on demand with `nvm install`)
export NVM_DIR="$HOME/.config/nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  mkdir -p "$NVM_DIR"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash >/dev/null
fi
echo "nvm: $( [ -s "$NVM_DIR/nvm.sh" ] && echo "installed ($NVM_DIR)" || echo "MISSING" )"

## golang (user-level tarball to ~/.local/go, arch-aware; toolchain for on-demand builds)
GO_OS="linux"; [[ "${OSTYPE:-}" == darwin* ]] && GO_OS="darwin"
case "$(uname -m)" in
  x86_64|amd64) GO_ARCH="amd64" ;;
  aarch64|arm64) GO_ARCH="arm64" ;;
  *) GO_ARCH="" ;;
esac
if [ -n "$GO_ARCH" ]; then
  GO_VER="$(curl -fsSL 'https://go.dev/VERSION?m=text' 2>/dev/null | head -1 || true)"
  if [ -n "$GO_VER" ] && [ "$("$HOME/.local/go/bin/go" version 2>/dev/null | awk '{print $3}')" != "$GO_VER" ]; then
    if curl -fsSL "https://go.dev/dl/${GO_VER}.${GO_OS}-${GO_ARCH}.tar.gz" -o /tmp/go.tgz 2>/dev/null; then
      rm -rf "$HOME/.local/go"
      tar -C "$HOME/.local" -xzf /tmp/go.tgz || echo "Go: extract failed" >&2
      rm -f /tmp/go.tgz
    else
      echo "Go: download failed, skipping" >&2
    fi
  fi
  if [ -x "$HOME/.local/go/bin/go" ]; then
    ln -sf "$HOME/.local/go/bin/go" ~/.local/bin/go
    ln -sf "$HOME/.local/go/bin/gofmt" ~/.local/bin/gofmt
  fi
  echo "Go: $(go version 2>/dev/null | awk '{print $3}' || echo 'not installed')"
fi

## Codex CLI
if command -v codex >/dev/null 2>&1; then
  codex --version >/dev/null 2>&1 || true
else
  curl -fsSL https://chatgpt.com/codex/install.sh | sh >/dev/null 2>&1 || true
fi
echo "Codex: $(codex --version 2>/dev/null | head -1 || true)"
