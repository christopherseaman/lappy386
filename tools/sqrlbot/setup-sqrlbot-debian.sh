#!/bin/bash

## SANDBOX USER (sqrlbot): own home, no sudo, no docker, group rwx to ~/projects.
## `dan` runs Claude as this user so --dangerously-skip-permissions stays inside a jail.
SANDBOX_USER="sqrlbot"
SANDBOX_GROUP="sqrlbot"
PROJECTS_DIR="$HOME/projects"
if ! id -u "$SANDBOX_USER" &>/dev/null; then
  echo "Creating sandbox user $SANDBOX_USER..."
  sudo useradd -m -s /bin/bash "$SANDBOX_USER"
  sudo passwd -l "$SANDBOX_USER" >/dev/null # lock password: reachable only via your sudo
fi
# dedicated shared group; you + sqrlbot are members
getent group "$SANDBOX_GROUP" >/dev/null || sudo groupadd "$SANDBOX_GROUP"
sudo usermod -aG "$SANDBOX_GROUP" "$(whoami)"
sudo usermod -aG "$SANDBOX_GROUP" "$SANDBOX_USER"
# enforce no privilege escalation (useradd never adds these, but be explicit)
sudo gpasswd -d "$SANDBOX_USER" sudo &>/dev/null || true
sudo gpasswd -d "$SANDBOX_USER" docker &>/dev/null || true
# group rwx to ~/projects, with setgid + default ACLs so new files inherit access both ways.
# An explicit u:<you> ACL keeps YOUR access immediate (group membership only loads at next
# login, but a user ACL applies right away and to files sqrlbot creates).
# The recursive pass only fixes pre-existing files; setgid + default ACLs cover files created
# later, so it runs once and re-runs skip the (potentially large) tree walk.
mkdir -p "$PROJECTS_DIR"
if ! getfacl -p "$PROJECTS_DIR" 2>/dev/null | grep -q "group:$SANDBOX_GROUP:"; then
  echo "Granting $SANDBOX_GROUP group access to $PROJECTS_DIR..."
  sudo chgrp -R "$SANDBOX_GROUP" "$PROJECTS_DIR"
  sudo chmod -R g+rwX "$PROJECTS_DIR"
  sudo find "$PROJECTS_DIR" -type d -exec chmod g+s {} +
  sudo setfacl -R -m "u:$(whoami):rwX,g:$SANDBOX_GROUP:rwX" "$PROJECTS_DIR"
  sudo setfacl -R -d -m "u:$(whoami):rwX,g:$SANDBOX_GROUP:rwX" "$PROJECTS_DIR"
fi
# traverse-only into home so sqrlbot can reach ~/projects without listing the rest of home
sudo setfacl -m u:"$SANDBOX_USER":--x "$HOME"

## PROVISION CLAUDE FOR THE SANDBOX USER
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/setup-sqrlbot-common.sh"
