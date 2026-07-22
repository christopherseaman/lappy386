#!/bin/bash
# setup-cli.sh — shared user-level CLI/dev layer for both hosts and the agent sandbox guests:
# shell dotfiles, the starship prompt, and on-demand toolchains (nvm, uv, golang, codex).
#
# Runs as the invoking user with NO sudo — system packages (apt/brew) and host-only config
# (git identity, SSH, DNS, nvim, claude) are the caller's responsibility. Idempotent.
# Self-locating: cd's to its own directory, so it can be run from anywhere.
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

## Global agent instructions
# Canonical source is a gist, not this repo — it governs every machine and project.
#   view: https://gist.github.com/christopherseaman/310a389a659acf37a6b13675a92a2438
#   edit: gh gist edit 310a389a659acf37a6b13675a92a2438 -f CLAUDE.md <file>
# One body, two readers, split per harness: Claude Code reads ~/.claude/CLAUDE.md and
# ignores AGENTS.md; codex reads ~/.codex/AGENTS.md. Fetch once, then emit a tailored copy
# for each (the ONLY:* strip below). Metadata stays in these shell comments — codex renders
# HTML comments in the body verbatim, so the strip also drops the markers it keys on.
#
# The third copy under ~/.local/share is for the sandbox guest: there ~/.codex is a
# bind mount that shadows whatever the image wrote, so the container start wrapper
# restores AGENTS.md from this (unmounted) path. Harmless on hosts.
INSTRUCTIONS_URL="https://gist.githubusercontent.com/christopherseaman/310a389a659acf37a6b13675a92a2438/raw/CLAUDE.md"
mkdir -p ~/.claude ~/.codex ~/.local/share/agent-instructions
instructions_tmp=$(mktemp)
if curl -fsSL "$INSTRUCTIONS_URL" -o "$instructions_tmp" && [ -s "$instructions_tmp" ]; then
  # The delegation guidance differs by reader: Claude Code delegates freely (subagents are
  # context-isolating), codex must not spawn (it forks the full context per child, metered).
  # Both paragraphs live in the gist wrapped in <!-- ONLY:claude --> / <!-- ONLY:codex -->
  # markers. strip_only keeps the matching block, drops the other and both markers, so each
  # file carries only its own line and no HTML comment reaches codex. A source with no
  # markers (older revision) passes through whole — same as the previous copy-both behaviour.
  strip_only() {  # $1 = harness to keep (claude|codex) -> stdout
    awk -v keep="$1" '
      /^<!-- ONLY:claude -->/ { blk=1; tag="claude"; next }
      /^<!-- ONLY:codex -->/  { blk=1; tag="codex";  next }
      /^<!-- \/ONLY:/         { blk=0; next }
      { if (!blk || tag==keep) print }
    ' "$instructions_tmp"
  }
  emit() {  # $1=harness  $2=dest — never overwrite a destination with an empty strip
    local out; out=$(mktemp)
    strip_only "$1" >"$out"
    if [ -s "$out" ]; then cp "$out" "$2"
    else echo "Agent instructions: strip($1) empty; left $2 untouched" >&2; fi
    rm -f "$out"
  }
  emit claude ~/.claude/CLAUDE.md
  emit codex  ~/.codex/AGENTS.md
  emit codex  ~/.local/share/agent-instructions/AGENTS.md
  echo "Agent instructions: split -> ~/.claude/CLAUDE.md (claude), ~/.codex/AGENTS.md (codex)"
else
  echo "Agent instructions: fetch failed; existing files left untouched" >&2
fi
rm -f "$instructions_tmp"
