#!/bin/bash
## Remove the sqrlbot sandbox user, group, and home directory.
## Opt-in, operator-run teardown for the sqrlbot -> Codex migration.
## Leaves ~/projects untouched by design (its group/setgid/ACLs are not reverted here).
## Cross-platform: Debian/Ubuntu (userdel/groupdel) and macOS (sysadminctl/dseditgroup).
## Run as your normal user (it uses sudo as needed), NOT via sudo/root.
set -euo pipefail

SANDBOX_USER="sqrlbot"
SANDBOX_GROUP="sqrlbot"
ASSUME_YES=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: remove-sqrlbot.sh [--yes] [--dry-run]
  Removes the sqrlbot user (+home), the sqrlbot group, and the sqrlbot
  traverse ACL on \$HOME. Leaves ~/projects untouched.
    --yes, -y      skip the confirmation prompt
    --dry-run, -n  print the actions without executing them
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) ASSUME_YES=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user (it uses sudo as needed), not as root —" >&2
  echo "otherwise \$HOME resolves to root's home and the ACL step targets the wrong dir." >&2
  exit 1
fi

# echo + run; under --dry-run, only echo
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    echo "  + $*"
    "$@"
  fi
}

OS="$(uname -s)"

user_exists=0
group_exists=0
if id -u "$SANDBOX_USER" >/dev/null 2>&1; then user_exists=1; fi
if [ "$OS" = "Darwin" ]; then
  dseditgroup -o read "$SANDBOX_GROUP" >/dev/null 2>&1 && group_exists=1 || true
else
  getent group "$SANDBOX_GROUP" >/dev/null 2>&1 && group_exists=1 || true
fi

if [ "$user_exists" -eq 0 ] && [ "$group_exists" -eq 0 ]; then
  echo "sqrlbot user and group are not present on this host — nothing to do."
  exit 0
fi

echo "About to remove on $(hostname) ($OS):"
[ "$user_exists" -eq 1 ] && echo "  - user  $SANDBOX_USER (and its home directory)"
[ "$group_exists" -eq 1 ] && echo "  - group $SANDBOX_GROUP"
echo "  - the '$SANDBOX_USER' traverse ACL on \$HOME ($HOME), if present"
echo "  (~/projects is left untouched.)"

if [ "$ASSUME_YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  printf "Type 'remove' to proceed: "
  if ! read -r reply || [ "$reply" != "remove" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# --- remove the sqrlbot traverse ACL from $HOME (do this before deleting the user) ---
if [ "$OS" = "Darwin" ]; then
  if ls -lde "$HOME" 2>/dev/null | grep -q "user:$SANDBOX_USER "; then
    run sudo chmod -a "user:$SANDBOX_USER allow execute" "$HOME"
  fi
else
  if getfacl -p "$HOME" 2>/dev/null | grep -q "^user:$SANDBOX_USER:"; then
    run sudo setfacl -x "u:$SANDBOX_USER" "$HOME"
  fi
fi

# --- delete the user (and its home directory) ---
if [ "$user_exists" -eq 1 ]; then
  if [ "$OS" = "Darwin" ]; then
    run sudo sysadminctl -deleteUser "$SANDBOX_USER"
  else
    run sudo pkill -TERM -u "$SANDBOX_USER" 2>/dev/null || true
    [ "$DRY_RUN" -eq 1 ] || sleep 1
    run sudo pkill -KILL -u "$SANDBOX_USER" 2>/dev/null || true
    run sudo userdel -r "$SANDBOX_USER"
  fi
fi

# --- delete the group ---
if [ "$group_exists" -eq 1 ]; then
  if [ "$OS" = "Darwin" ]; then
    run sudo dseditgroup -o delete "$SANDBOX_GROUP"
  else
    run sudo groupdel "$SANDBOX_GROUP"
  fi
fi

echo "Done. sqrlbot removed."
echo "Note: ~/projects still carries group '$SANDBOX_GROUP'/setgid (left untouched by design);"
echo "reset it by hand later if you want (e.g. chgrp -R \"\$(id -gn)\" ~/projects && find ~/projects -type d -exec chmod g-s {} +)."
