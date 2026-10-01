# lappy386
Automated setup scripts for new laptops and development environments.

## Quick Start

Run the main setup script to automatically detect your OS and configure your development environment:

```bash
./setup.sh
```

This will:
- Install essential development tools and packages
- Configure dotfiles (bashrc, tmux, nvim, etc.)
- Set up Git configuration
- Install modern CLI tools (starship, fastfetch, helix, etc.)

After setup completes, remember to run `gh auth login` to authenticate with GitHub.

## Manual Setup

You can also run platform-specific scripts directly:

These read `artifacts/` by relative path, so run them from `tools/`:

- **Debian/Ubuntu**: `cd tools && ./setup-debian.sh`
- **macOS**: `cd tools && ./setup-macos.sh`
- **Common configuration**: `cd tools && ./setup-common.sh` (git, SSH, nvim, agent settings, Ponytail plugin for Claude + Codex)
- **Shared CLI layer**: `cd tools && ./setup-cli.sh` (dotfiles, starship, nvm, uv, golang, codex)
- **Claude MCP setup**: `cd tools && ./setup-claude-mcp.sh`
- **Codex setup**: `cd tools && ./setup-codex.sh` (MCP servers; Ponytail is also installed by setup-common.sh)
- **Agent sandbox**: `./tools/sandbox/setup-sandbox-linux.sh` (podman) or `setup-sandbox-mac.sh` (Tart VM).
  The Linux sandbox runs codex plus an opencode web UI on host loopback, published for a tunnel to front.

Neovim config deployment preserves live-only files and `lazy-lock.json`. Changed
repo-managed files replace their live counterparts, keeping one previous version
per file in `${XDG_STATE_HOME:-$HOME/.local/state}/nvim-config-backup`. Identical reruns
leave files and backups untouched; files removed from the repo are not pruned live.
Common host setup also installs the Codex ACP adapter in `~/.local/bin`, using an
existing Node/npm installation or installing Node LTS through nvm when needed.
Codex remains a commented Avante provider alternative; authenticate with
`codex login` to use ChatGPT subscription access before enabling it.

## Host-Specific Configurations

The `hosts/` directory contains configuration files and setup scripts for specific machines.

# Raspberry Pi 5

 - [`input-remapper`](https://github.com/sezanzeb/input-remapper): bluetooth remote config
 - DRM: widevine ARM64 only provided by Raspberry Pi OS at `/opt/WidevineCdm` 
 - `xrdp`: apt version okay, change `thinclient_drives` to `.thinclient_drives` in `/etc/xrdp/sesman.ini`
```
[Chansrv]
FuseMountName=.thinclient_drives
```


# MacMini6,2

## Auto reboot on power failure

https://www.mythic-beasts.com/support/servers/colo/macmini

/etc/rc.local
`setpci -s 0:1f.0 0xa4.b=0`

## Mute startup chime
https://wiki.archlinux.org/title/Mac#Mute_startup_chime
