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

- **Debian/Ubuntu**: `./tools/setup-debian.sh`
- **macOS**: `./tools/setup-macos.sh`
- **Common configuration**: `./tools/setup-common.sh` (git, SSH, nvim, agent settings)
- **Shared CLI layer**: `./tools/setup-cli.sh` (dotfiles, starship, nvm, uv, golang, codex)
- **Claude MCP setup**: `./tools/setup-claude-mcp.sh`
- **Agent sandbox**: `./tools/sandbox/setup-sandbox-linux.sh` (podman) or `setup-sandbox-mac.sh` (Tart VM)

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
