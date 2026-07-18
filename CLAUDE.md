# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Does

lappy386 is a machine provisioning toolkit. `./setup.sh` detects the OS (Debian/Ubuntu, Arch, macOS) and runs the appropriate platform script, which then calls `setup-common.sh` for cross-platform config (dotfiles, git, SSH keys, nvim, nvm/node, CLI tools like Claude Code and Copilot).

**Idempotency is a core design goal.** Re-running `setup.sh` on an already-provisioned machine should update to latest settings without breaking anything. Most scripts use `command -v` / `dpkg -l` guards to skip already-installed software. When adding new setup steps, follow this pattern.

## Architecture

```
setup.sh                    # Entry point: OS detection, dispatches to tools/
tools/
  setup-debian.sh           # Debian/Ubuntu: apt packages, neovim, fonts, VM tools, RDP, Firefox
  setup-arch.sh             # Arch: pacman packages
  setup-macos.sh            # macOS: Homebrew, Ghostty config, Dock prefs
  setup-common.sh           # Cross-platform: dotfiles, git, SSH, nvim config, nvm, Claude/Codex/Happier CLIs
  setup-firefox.sh          # Mozilla apt repo Firefox (replaces snap)
  setup-claude-mcp.sh       # Interactive: configures Notion/Atlassian MCP servers for Claude
  artifacts/                # Source-of-truth config files copied to target machine
    dot-bashrc, dot-aliases, dot-tmux.conf, dot-zshrc, dot-ssh-config
    dot-config-nvim/        # Full LazyVim config (copied to ~/.config/nvim)
    claude-settings.json    # Claude Code global settings
    public_keys/            # All host SSH pubkeys -> aggregated into authorized_keys
    brew.lst, cask.lst      # macOS Homebrew package lists
  rdp/                      # GNOME headless RDP setup (GDM autologin, TLS, display fix service)
  sandbox/                  # Opt-in disposable agent sandboxes (run manually, not from setup.sh):
                            #   setup-sandbox-linux.sh (rootless Podman + Containerfile),
                            #   setup-sandbox-mac.sh (Tart macOS+Xcode VM). Run Codex via Happier.
  remove-sqrlbot.sh         # Opt-in teardown: remove the retired sqrlbot user/group/home (manual)
hosts/                      # Per-machine configs and setup scripts
  tarski/                   # Local QEMU/UTM VM (cloud-init via SMBIOS nocloud datasource)
  strongbad/                # ChromeOS Crostini container (LXC + cloud-config)
  carnac/                   # Server: Pi-hole, cloudflared tunnel (ingress), code-server, firewall
  gamepost/                 # Samba file server config
  hivemind/                 # NFS/fstab mounts
  schmaspberry/             # Cellular gateway setup
  shtheeev/                 # Backup script
theme/                      # Terminal theme files (Kitty, Ghostty, macOS Terminal, Blink)
```

## Key Patterns

- **Artifacts are canonical.** Files in `tools/artifacts/` are the source of truth. They get copied wholesale to the target machine (e.g., `cat artifacts/dot-bashrc > ~/.bashrc`). Edit the artifact, not the deployed file.
- **SSH key management.** Each host generates an ed25519 key named `client_key`. Its pubkey is committed to `artifacts/public_keys/<hostname>.pub`. All pubkeys are aggregated into `~/.ssh/authorized_keys` on every run.
- **Cloud-init bootstrapping.** `hosts/tarski/` uses QEMU SMBIOS to point nocloud at the raw GitHub URL for `user-data`/`meta-data`. The cloud-init `runcmd` clones this repo and runs `setup-debian.sh`. The SMBIOS arg (`qemu_arg.txt`) can be passed to QEMU/UTM to auto-provision VMs.
- **Host-specific scripts** live under `hosts/<hostname>/` and are run manually or via cloud-init, not from the main `setup.sh` flow.
- **Two ways agents run.** `dan` (in `artifacts/dot-aliases`) runs Codex locally in
  bypass mode, as you — supervised, no jail. For unattended/remote runs, `tools/sandbox/`
  provides a disposable VM/container fronted by Happier.

## Common Operations

```bash
# Full setup on a new machine
./setup.sh

# Re-run just common config (dotfiles, git, SSH, nvim, node)
cd tools && ./setup-common.sh

# Re-run just Debian packages + common
cd tools && ./setup-debian.sh

# Set up a UTM VM (run on macOS host)
cd hosts/tarski && ./setup-utm-vm.sh

# Configure Claude MCP servers (interactive)
./tools/setup-claude-mcp.sh

# Set up headless RDP on a GNOME machine
sudo ./tools/rdp/setup-headless-rdp.sh [--auto] [username] [password]
```

## Conventions

- Shell scripts use `#!/bin/bash` and should work on both x86_64 and aarch64/arm64.
- `setup-debian.sh` detects architecture via `uname -m` and maps to download URLs accordingly.
- Package lists for macOS live in `artifacts/brew.lst` and `artifacts/cask.lst` (one package per line, `#` comments).
- The `RDP_PASSWORD` env var is threaded through from `setup-debian.sh` to `setup-headless-rdp.sh` and displayed in the final banner by `setup-common.sh`.
