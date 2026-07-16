#!/bin/bash
# hosts/carnac/setup-user-home.sh
# Fresh-install provisioning for carnac: create the `christopher` user with $HOME on
# the PERSISTENT data volume, mount it at /home/christopher, and add an fstab entry so
# it auto-mounts at boot. This does NOT run the normal setup.sh.
#
# THIS SCRIPT NEVER FORMATS OR WRITES A FILESYSTEM. The data volume is persistent and
# already contains christopher's home + projects. It only MOUNTS the existing volume
# (identified by the UUID in this directory's etc-fstab). Mounting by UUID IS the
# presence check: if that volume is not attached, the mount fails and the script aborts
# before creating the user or editing fstab. It never creates or erases a filesystem.
#
# Run as ROOT on a fresh box: ssh in as `ubuntu`, `sudo -i`, clone this repo, run this.
#
# USAGE:
#   sudo bash setup-user-home.sh [--dry-run]
set -euo pipefail

TARGET_USER="christopher"
TARGET_UID="1002"
TARGET_GID="1002"
FULL_NAME="Christopher Seaman"
SHELL_BIN="/bin/bash"
KEY_SOURCE="/home/ubuntu/.ssh/authorized_keys"   # the key you just SSH'd in with
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FSTAB_SNIPPET="$SCRIPT_DIR/etc-fstab"
FSTAB="/etc/fstab"

DRY_RUN=0
while [ $# -gt 0 ]; do case "$1" in
  --dry-run|-n) DRY_RUN=1 ;;
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) echo "unknown arg: $1" >&2; exit 2 ;;
esac; shift; done

say(){ echo ">> $*"; }
run(){ if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry-run] $*"; else echo "   + $*"; "$@"; fi; }
die(){ echo "ABORT: $*" >&2; exit 1; }

# canonical fstab snippet (single source of truth for UUID + mountpoint)
[ -f "$FSTAB_SNIPPET" ] || die "missing $FSTAB_SNIPPET — run from the cloned repo"
FSTAB_LINE="$(grep -E '^[[:space:]]*UUID=' "$FSTAB_SNIPPET" | head -1 || true)"
[ -n "$FSTAB_LINE" ] || die "no UUID line in $FSTAB_SNIPPET"
EXPECTED_UUID="$(echo "$FSTAB_LINE" | awk '{print $1}' | sed 's/^UUID=//')"
MOUNTPOINT="$(echo "$FSTAB_LINE" | awk '{print $2}')"
[ -n "$EXPECTED_UUID" ] && [ -n "$MOUNTPOINT" ] || die "could not parse UUID/mountpoint from $FSTAB_SNIPPET"

# preflight
say "Preflight (user=$TARGET_USER, uuid=$EXPECTED_UUID, mountpoint=$MOUNTPOINT)"
[ "$(id -u)" -eq 0 ] || die "must run as root"
for c in findmnt useradd groupadd usermod install; do command -v "$c" >/dev/null || die "missing tool: $c"; done
[ "$MOUNTPOINT" = "/home/$TARGET_USER" ] || die "snippet mountpoint '$MOUNTPOINT' != /home/$TARGET_USER"
u_at_uid="$(getent passwd "$TARGET_UID" | cut -d: -f1 || true)"
[ -z "$u_at_uid" ] || [ "$u_at_uid" = "$TARGET_USER" ] || die "uid $TARGET_UID already used by '$u_at_uid'"
g_at_gid="$(getent group "$TARGET_GID" | cut -d: -f1 || true)"
[ -z "$g_at_gid" ] || [ "$g_at_gid" = "$TARGET_USER" ] || die "gid $TARGET_GID already used by group '$g_at_gid'"
if id -u "$TARGET_USER" >/dev/null 2>&1; then
  cur_uid="$(id -u "$TARGET_USER")"; [ "$cur_uid" = "$TARGET_UID" ] || die "user $TARGET_USER already exists with uid $cur_uid (expected $TARGET_UID)"
fi

# mount the persistent volume by UUID — this IS the presence check (fails if not attached; never formats)
say "Mounting the persistent data volume at $MOUNTPOINT"
run mkdir -p "$MOUNTPOINT"
if findmnt -rno SOURCE "$MOUNTPOINT" >/dev/null 2>&1; then
  say "already mounted"
else
  run mount "UUID=$EXPECTED_UUID" "$MOUNTPOINT" || die "could not mount UUID=$EXPECTED_UUID — attach the persistent data volume and re-run (this script never formats)"
fi
if [ "$DRY_RUN" -eq 0 ]; then
  mounted_uuid="$(findmnt -no UUID "$MOUNTPOINT" 2>/dev/null || true)"
  [ "$mounted_uuid" = "$EXPECTED_UUID" ] || die "$MOUNTPOINT has the wrong volume mounted (uuid '$mounted_uuid', expected $EXPECTED_UUID)"
fi

# group + user + sudo (only after the right volume is confirmed mounted)
say "Ensuring group/user $TARGET_USER ($TARGET_UID:$TARGET_GID) + sudo"
getent group "$TARGET_GID" >/dev/null || run groupadd -g "$TARGET_GID" "$TARGET_USER"
if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
  run useradd -u "$TARGET_UID" -g "$TARGET_GID" -M -d "$MOUNTPOINT" -s "$SHELL_BIN" -c "$FULL_NAME" "$TARGET_USER"
fi
run usermod -aG sudo "$TARGET_USER"

# fstab entry for auto-mount at boot (idempotent, UUID-based)
say "Ensuring fstab entry for boot"
if grep -qE "^[[:space:]]*UUID=$EXPECTED_UUID[[:space:]]" "$FSTAB"; then
  cur="$(grep -E "^[[:space:]]*UUID=$EXPECTED_UUID[[:space:]]" "$FSTAB" | head -1 || true)"
  if printf '%s' "$cur" | grep -qE "[[:space:]]$MOUNTPOINT[[:space:]]"; then
    say "fstab already mounts UUID $EXPECTED_UUID at $MOUNTPOINT"
  else
    die "fstab already has UUID $EXPECTED_UUID at a different mountpoint — resolve manually: $cur"
  fi
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "   [dry-run] append to $FSTAB: $FSTAB_LINE"
else
  printf '%s\n' "## Mount persistent data volume as christopher's \$HOME" "$FSTAB_LINE" >> "$FSTAB"
fi

# home contents (seed skel ONLY if the volume is genuinely empty), SSH keys, perms — never destroys data
say "Home contents, SSH keys, permissions"
if [ "$DRY_RUN" -eq 0 ]; then
  if [ -z "$(ls -A "$MOUNTPOINT" 2>/dev/null | grep -vx 'lost+found' || true)" ]; then
    say "volume is empty — seeding dotfiles from /etc/skel"
    cp -aT /etc/skel "$MOUNTPOINT" || die "failed to seed /etc/skel into $MOUNTPOINT"
    chown -R "$TARGET_USER:$TARGET_USER" "$MOUNTPOINT"
  else
    say "volume already has data — preserving existing home/projects (no changes to contents)"
  fi
  install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$MOUNTPOINT/.ssh"
  if [ ! -s "$MOUNTPOINT/.ssh/authorized_keys" ]; then
    if [ -s "$KEY_SOURCE" ]; then
      install -m 600 -o "$TARGET_USER" -g "$TARGET_USER" "$KEY_SOURCE" "$MOUNTPOINT/.ssh/authorized_keys"
      say "seeded authorized_keys from $KEY_SOURCE"
    else
      echo "!! warning: $KEY_SOURCE not found — christopher has NO SSH keys yet; add them before relying on SSH." >&2
    fi
  fi
  chown "$TARGET_USER:$TARGET_USER" "$MOUNTPOINT"; chmod 0750 "$MOUNTPOINT"
  chown -R "$TARGET_USER:$TARGET_USER" "$MOUNTPOINT/.ssh"
  chmod 700 "$MOUNTPOINT/.ssh"
  [ -f "$MOUNTPOINT/.ssh/authorized_keys" ] && chmod 600 "$MOUNTPOINT/.ssh/authorized_keys"
fi

# verify
say "Verify"
if [ "$DRY_RUN" -eq 0 ]; then
  getent passwd "$TARGET_USER" >/dev/null || die "user not created"
  id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx sudo || echo "!! warning: $TARGET_USER not in sudo group"
  findmnt "$MOUNTPOINT" >/dev/null || die "$MOUNTPOINT not mounted"
  [ -s "$MOUNTPOINT/.ssh/authorized_keys" ] || echo "!! warning: no authorized_keys — christopher not yet SSH-reachable"
fi
echo
if [ "$DRY_RUN" -eq 1 ]; then
  say "DRY-RUN complete — nothing changed."
else
  say "DONE. $TARGET_USER created; \$HOME on the data volume at $MOUNTPOINT (auto-mounts at boot)."
  echo "   Next: ssh $TARGET_USER@carnac  →  clone lappy386 and run the normal setup as christopher."
fi
