#!/bin/bash

## SANDBOX USER (sqrlbot): own home, no admin, group rwx to ~/projects.
## `dan` runs Claude as this user so --dangerously-skip-permissions stays inside a jail.
SANDBOX_USER="sqrlbot"
SANDBOX_GROUP="sqrlbot"
PROJECTS_DIR="$HOME/projects"
if ! id -u "$SANDBOX_USER" &>/dev/null; then
  echo "Creating sandbox user $SANDBOX_USER..."
  # no -admin => not in admin group / not a sudoer; reachable only via your sudo
  sudo sysadminctl -addUser "$SANDBOX_USER" -fullName "sqrlbot" -shell /bin/bash
  sudo dscl . -create /Users/"$SANDBOX_USER" IsHidden 1     # keep off the login window
  sudo dscl . -create /Users/"$SANDBOX_USER" Password '*'   # disable password login
fi
# dedicated shared group; you + sqrlbot are members
# (no docker group on macOS; Docker Desktop is a per-user GUI app — nothing to restrict)
# guard create on existence: `-o create` on an existing group prompts "overwrite? y/n" and hangs
dseditgroup -o read "$SANDBOX_GROUP" &>/dev/null || sudo dseditgroup -o create "$SANDBOX_GROUP"
sudo dseditgroup -o edit -a "$(whoami)" -t user "$SANDBOX_GROUP"
sudo dseditgroup -o edit -a "$SANDBOX_USER" -t user "$SANDBOX_GROUP"
# group rwx to ~/projects, with setgid + inherited ACLs so new files inherit access both ways.
# An explicit user ACL keeps YOUR access immediate and covers files sqrlbot creates.
# The recursive pass only fixes pre-existing files; inherited ACLs cover files created later,
# so it runs once and re-runs skip the (potentially large) tree walk.
mkdir -p "$PROJECTS_DIR"
if ! ls -lde "$PROJECTS_DIR" 2>/dev/null | grep -q "group:$SANDBOX_GROUP allow"; then
  echo "Granting $SANDBOX_GROUP group access to $PROJECTS_DIR..."
  ACL_PERMS="read,write,execute,delete,add_file,add_subdirectory,file_inherit,directory_inherit"
  sudo chgrp -R "$SANDBOX_GROUP" "$PROJECTS_DIR"
  sudo chmod -R g+rwX "$PROJECTS_DIR"
  sudo find "$PROJECTS_DIR" -type d -exec chmod g+s {} +
  sudo chmod -R +a "group:$SANDBOX_GROUP allow $ACL_PERMS" "$PROJECTS_DIR"
  sudo chmod -R +a "user:$(whoami) allow $ACL_PERMS" "$PROJECTS_DIR"
fi
# traverse into home so sqrlbot can reach ~/projects
sudo chmod +a "user:$SANDBOX_USER allow execute" "$HOME"

## PROVISION CLAUDE FOR THE SANDBOX USER
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/setup-sqrlbot-common.sh"
