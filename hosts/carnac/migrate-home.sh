#!/bin/bash
# carnac-migrate-home.sh — move christopher's home onto the big ext4 disk (sdb),
# which today holds only the ~/projects data. End-state: sdb mounted at
# /home/christopher, containing all home files + a projects/ subdir (the existing
# 25G). Home PATH stays /home/christopher (no config breakage).
#
# RUN AS ROOT FROM A ROOT SSH SESSION (root SSH is the confirmed recovery lifeline).
# Do NOT run via `sudo` from christopher's session — this kills christopher's whole
# session (code-server, headless GNOME, rootless Docker), so it must not run inside it.
# No reboot: Pi-hole/Caddy are system services outside /home and keep running.
#
# SAFETY MODEL:
#   - The home copy goes into a STAGING SUBDIR on sdb first, so the original 25G
#     projects data is untouched until a fast, same-fs "commit" phase. Any failure
#     BEFORE commit rolls back cleanly (drop the staged copy, remount sdb at ~/projects).
#   - The old root-disk home is preserved as /home/christopher.old (rollback + the
#     space you reclaim later). This script deletes nothing.
#   - Aborts before the point of no return if the copied home dir or .ssh would be
#     rejected by sshd StrictModes (world/group-writable) — the real lockout cause.
#   - An ERR trap auto-rolls-back on any unexpected failure and restarts services.
#
# USAGE:
#   sudo bash carnac-migrate-home.sh --dry-run     # print every action, change nothing
#   sudo bash carnac-migrate-home.sh --go          # do it (prompts once)
#   sudo bash carnac-migrate-home.sh --go --yes    # do it, skip the prompt
set -Eeuo pipefail

TARGET_USER="christopher"
HOME_DIR="/home/christopher"
OLD_DIR="/home/christopher.old"
DEV_UUID="a87ace88-78fe-4c84-937f-766aadc6e5c8"
CUR_MOUNT="/home/christopher/projects"       # where sdb is mounted today
NEUTRAL="/mnt/carnac-home"                    # temp staging mountpoint
STAGE_SUBDIR=".newhome-staging"               # temp subdir on sdb holding the home copy
FSTAB="/etc/fstab"
FSTAB_BAK="/etc/fstab.pre-home-migrate"
LIFELINE="/root/.ssh/authorized_keys"         # confirmed recovery path: root SSH
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"

GO=0; DRY_RUN=0; ASSUME_YES=0
for a in "$@"; do case "$a" in
  --go) GO=1 ;; --dry-run|-n) DRY_RUN=1 ;; --yes|-y) ASSUME_YES=1 ;;
  *) echo "unknown arg: $a" >&2; exit 2 ;;
esac; done
[ "$GO" -eq 1 ] || [ "$DRY_RUN" -eq 1 ] || { echo "pass --dry-run or --go" >&2; exit 2; }

say(){ echo ">> $*"; }
run(){ if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry-run] $*"; else echo "   + $*"; "$@"; fi; }
die(){ echo "ABORT: $*" >&2; exit 1; }
STAGE=start; DEV=""

restore_services(){
  [ "$DRY_RUN" -eq 1 ] && return 0
  systemctl unmask "code-server@$TARGET_USER.service" 2>/dev/null || true
  loginctl enable-linger "$TARGET_USER" 2>/dev/null || true
  systemctl start "user@$TARGET_UID.service" 2>/dev/null || true
  systemctl start "code-server@$TARGET_USER.service" 2>/dev/null || true
}
rollback(){
  trap - ERR
  echo "!! rolling back (stage=$STAGE)" >&2
  case "$STAGE" in
    cutover|fstab)
      mountpoint -q "$HOME_DIR" && umount "$HOME_DIR" 2>/dev/null || true
      [ -f "$FSTAB_BAK" ] && cp -a "$FSTAB_BAK" "$FSTAB" 2>/dev/null || true
      if [ -d "$OLD_DIR" ]; then
        [ -d "$HOME_DIR" ] && [ -z "$(ls -A "$HOME_DIR" 2>/dev/null)" ] && rmdir "$HOME_DIR" 2>/dev/null || true
        [ ! -e "$HOME_DIR" ] && mv "$OLD_DIR" "$HOME_DIR" 2>/dev/null || true
      fi
      mountpoint -q "$CUR_MOUNT" || mount "UUID=$DEV_UUID" "$CUR_MOUNT" 2>/dev/null || true
      echo "!! sdb holds the MIGRATED layout (home + projects/). Data intact under $CUR_MOUNT/projects/." >&2
      echo "!! This is a best-effort restore of a post-commit failure — review manually." >&2 ;;
    committing)
      mountpoint -q "$NEUTRAL" && umount "$NEUTRAL" 2>/dev/null || true
      mountpoint -q "$CUR_MOUNT" || mount "UUID=$DEV_UUID" "$CUR_MOUNT" 2>/dev/null || true
      echo "!! PARTIAL reorganization — sdb layout may be half-nested. ALL data is present under" >&2
      echo "!! $CUR_MOUNT (some entries under projects/, some at root, some in $STAGE_SUBDIR)." >&2
      echo "!! Do NOT retry blindly — inspect $CUR_MOUNT by hand first." >&2 ;;
    committed)
      mountpoint -q "$NEUTRAL" && umount "$NEUTRAL" 2>/dev/null || true
      mountpoint -q "$CUR_MOUNT" || mount "UUID=$DEV_UUID" "$CUR_MOUNT" 2>/dev/null || true
      echo "!! sdb holds the fully-migrated layout (home + projects/), now at $CUR_MOUNT. Data intact; review manually." >&2 ;;
    copied|neutral)
      [ -n "$NEUTRAL" ] && [ -d "$NEUTRAL/$STAGE_SUBDIR" ] && rm -rf "${NEUTRAL:?}/$STAGE_SUBDIR" 2>/dev/null || true
      mountpoint -q "$NEUTRAL" && umount "$NEUTRAL" 2>/dev/null || true
      mount "UUID=$DEV_UUID" "$CUR_MOUNT" 2>/dev/null || true
      echo "!! clean rollback: original ~/projects restored, staged copy discarded." >&2 ;;
    unmounted)
      mount "UUID=$DEV_UUID" "$CUR_MOUNT" 2>/dev/null || true
      echo "!! clean rollback: ~/projects remounted." >&2 ;;
    *) : ;;
  esac
  restore_services
  echo "!! rollback done. Recover via root SSH; investigate before retrying." >&2
}
fail(){ rollback; die "$*"; }

# --------------------------------------------------------------------- preflight
say "Preflight"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -n "$TARGET_UID" ] || die "cannot resolve uid for $TARGET_USER"
inv="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
[ -n "$inv" ] || die "cannot determine invoking user — run from an interactive root SSH login"
[ "$inv" != "$TARGET_USER" ] || die "invoked from $TARGET_USER's session — log in over root SSH and run it there"
case "$PWD" in "$HOME_DIR"|"$HOME_DIR"/*) die "cwd is under $HOME_DIR — cd to / first";; esac
for c in rsync findmnt setfacl fuser mountpoint blkid; do command -v "$c" >/dev/null || die "missing tool: $c"; done
getent passwd "$TARGET_USER" >/dev/null || die "no user $TARGET_USER"
[ ! -e "$OLD_DIR" ] || die "$OLD_DIR exists (previous run?) — resolve first"
[ -s "$LIFELINE" ] || die "recovery lifeline $LIFELINE missing/empty — confirm root SSH works first"
mountpoint -q "$NEUTRAL" && die "$NEUTRAL is already a mountpoint"
DEV="$(findmnt -no SOURCE "$CUR_MOUNT" 2>/dev/null || true)"
[ -n "$DEV" ] || die "$CUR_MOUNT is not a mountpoint"
byuuid="$(blkid -U "$DEV_UUID" 2>/dev/null || true)"
[ "$DEV" = "$byuuid" ] || die "$CUR_MOUNT is $DEV but UUID $DEV_UUID is '$byuuid' — mismatch"
grep -qE "^[[:space:]]*UUID=$DEV_UUID[[:space:]]+$CUR_MOUNT[[:space:]]" "$FSTAB" || die "no fstab line mounting UUID=$DEV_UUID at $CUR_MOUNT"
for reserved in projects "$STAGE_SUBDIR"; do
  [ -e "$CUR_MOUNT/$reserved" ] && die "reserved name '$reserved' already exists at $CUR_MOUNT — resolve first (would collide with the reorg)"
done
home_kb="$(du -sxk "$HOME_DIR" | awk '{print $1}')"
free_kb="$(df -Pk "$CUR_MOUNT" | awk 'NR==2{print $4}')"
say "home ~$((home_kb/1024/1024))G, sdb free ~$((free_kb/1024/1024))G, device=$DEV, invoked-by=$inv"
[ "$free_kb" -gt "$((home_kb + 1048576))" ] || die "insufficient free space on sdb"
say "Preflight OK"

if [ "$GO" -eq 1 ] && [ "$ASSUME_YES" -ne 1 ]; then
  echo; echo "This logs out $TARGET_USER (code-server, GNOME, rootless docker), copies home"
  echo "onto sdb, and remounts sdb at $HOME_DIR. Pi-hole/Caddy keep running. $OLD_DIR is kept."
  printf "Type 'migrate' to proceed: "
  if ! read -r r || [ "$r" != "migrate" ]; then echo "Aborted."; exit 1; fi
fi

# arm auto-rollback for all destructive steps below
trap 'rc=$?; echo "!! unexpected failure (rc=$rc)" >&2; rollback; exit 1' ERR

# --------------------------------------------------------------------- quiesce
say "Quiescing $TARGET_USER"
STAGE=quiesced
run systemctl mask --now "code-server@$TARGET_USER.service" || true
run loginctl disable-linger "$TARGET_USER" || true
run loginctl terminate-user "$TARGET_USER" || true
run systemctl stop "user@$TARGET_UID.service" || true
if [ "$DRY_RUN" -eq 0 ]; then
  sleep 2
  systemctl is-active --quiet "code-server@$TARGET_USER.service" && fail "code-server still active after mask/stop"
  systemctl is-active --quiet "user@$TARGET_UID.service" && fail "user@$TARGET_UID slice still active"
  pkill -KILL -u "$TARGET_USER" 2>/dev/null || true; sleep 1
  if pgrep -u "$TARGET_USER" >/dev/null; then pkill -KILL -u "$TARGET_USER" 2>/dev/null || true; sleep 1; fi
  pgrep -u "$TARGET_USER" >/dev/null && fail "$TARGET_USER still has live processes — unsafe to unmount"
  # UID-agnostic backstop for rootless-docker (mapped subuid) procs holding home open
  refs="$(ls -l /proc/[0-9]*/cwd /proc/[0-9]*/root 2>/dev/null | grep -cF "$HOME_DIR/" || true)"
  [ "${refs:-0}" -eq 0 ] || { echo "!! warning: $refs proc refs under $HOME_DIR after quiesce; pausing" >&2; sleep 3; }
fi

# --------------------------------------------------------------------- unmount
say "Unmounting nested mounts under $HOME_DIR, then sdb"
nested="$(findmnt -rno TARGET 2>/dev/null | awk -v h="$HOME_DIR/" -v p="$CUR_MOUNT" 'index($0,h)==1 && $0!=p {print length, $0}' | sort -rn | cut -d' ' -f2- || true)"
if [ -n "$nested" ]; then
  printf '%s\n' "$nested" | while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry-run] umount $m"; else
      echo "   + umount $m"; umount "$m" 2>/dev/null || { fuser -km "$m" 2>/dev/null || true; sleep 1; umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true; }
    fi
  done
fi
if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry-run] umount $CUR_MOUNT"
else umount "$CUR_MOUNT" 2>/dev/null || { fuser -km "$CUR_MOUNT" 2>/dev/null || true; sleep 2; umount "$CUR_MOUNT"; } || fail "could not unmount $CUR_MOUNT"; fi
STAGE=unmounted

# --------------------------------------------------------------------- stage copy
say "Mounting sdb at $NEUTRAL and copying home into staging (original projects untouched)"
run mkdir -p "$NEUTRAL"
run mount "UUID=$DEV_UUID" "$NEUTRAL"
STAGE=neutral
if [ "$DRY_RUN" -eq 0 ]; then
  mountpoint -q "$NEUTRAL" || fail "neutral mount failed"
  [ ! -e "$NEUTRAL/.ssh/authorized_keys" ] || fail "$NEUTRAL already looks like a home dir — refusing (idempotency guard)"
  mkdir -p "$NEUTRAL/$STAGE_SUBDIR"
fi
run rsync -aHAXS --numeric-ids --exclude='/projects' "$HOME_DIR/" "$NEUTRAL/$STAGE_SUBDIR/"
STAGE=copied

say "Verifying + hardening the staged home (sshd StrictModes lockout guard)"
if [ "$DRY_RUN" -eq 0 ]; then
  st="$NEUTRAL/$STAGE_SUBDIR"
  [ -s "$st/.ssh/authorized_keys" ] || fail "authorized_keys missing/empty in copy — NOT cutting over"
  setfacl -Rb "$st/.ssh" 2>/dev/null || true
  chown -R "$TARGET_UID:$TARGET_UID" "$st/.ssh"
  chmod 700 "$st/.ssh"; chmod 600 "$st/.ssh/authorized_keys"
  # home dir itself must not be group/world-writable or sshd rejects pubkey auth
  setfacl -b "$st" 2>/dev/null || true
  chown "$TARGET_UID:$TARGET_UID" "$st"; chmod 0750 "$st"
fi

# --------------------------------------------------------------------- COMMIT (fast, same-fs)
say "Commit: nesting project data under projects/ and placing home files"
STAGE=committing
if [ "$DRY_RUN" -eq 1 ]; then
  echo "   [dry-run] mkdir $NEUTRAL/projects; move project entries into it; move staged home to root; rmdir staging"
else
  mkdir -p "$NEUTRAL/projects"
  find "$NEUTRAL" -maxdepth 1 -mindepth 1 ! -name projects ! -name 'lost+found' ! -name "$STAGE_SUBDIR" -exec mv -t "$NEUTRAL/projects/" {} +
  find "$NEUTRAL/$STAGE_SUBDIR" -maxdepth 1 -mindepth 1 -exec mv -t "$NEUTRAL/" {} +
  rmdir "$NEUTRAL/$STAGE_SUBDIR"
  [ -s "$NEUTRAL/.ssh/authorized_keys" ] || fail "authorized_keys not at home root after commit"
  [ -d "$NEUTRAL/projects" ] || fail "projects/ missing after commit"
  setfacl -b "$NEUTRAL" 2>/dev/null || true   # strip any inherited ACL on the home root (sshd hygiene)
  chown "$TARGET_UID:$TARGET_UID" "$NEUTRAL"; chmod 0750 "$NEUTRAL"
  STAGE=committed
  say "new home: $(find "$NEUTRAL" -maxdepth 1 -mindepth 1 | wc -l) top-level entries incl projects/"
fi
run umount "$NEUTRAL"

# --------------------------------------------------------------------- fstab + cutover
say "Repointing fstab: $CUR_MOUNT -> $HOME_DIR (backup at $FSTAB_BAK)"
STAGE=fstab
run cp -a "$FSTAB" "$FSTAB_BAK"
if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry-run] sed fstab mountpoint for UUID=$DEV_UUID"
else
  sed -i -E "s|^([[:space:]]*UUID=$DEV_UUID[[:space:]]+)$CUR_MOUNT([[:space:]])|\1$HOME_DIR\2|" "$FSTAB"
  n="$(grep -cE "^[[:space:]]*UUID=$DEV_UUID[[:space:]]+$HOME_DIR[[:space:]]" "$FSTAB" || true)"
  [ "$n" = "1" ] || fail "fstab edit produced $n matching lines (want 1)"
fi

say "Cutover: set old home aside, mount sdb at $HOME_DIR"
STAGE=cutover
if [ "$DRY_RUN" -eq 1 ]; then echo "   [dry-run] mv $HOME_DIR $OLD_DIR; mkdir $HOME_DIR; mount UUID=$DEV_UUID $HOME_DIR"
else
  mv "$HOME_DIR" "$OLD_DIR"
  mkdir "$HOME_DIR"; chown "$TARGET_UID:$TARGET_UID" "$HOME_DIR"; chmod 0750 "$HOME_DIR"
  mount "UUID=$DEV_UUID" "$HOME_DIR" || fail "mount at $HOME_DIR failed"
  now="$(findmnt -no SOURCE "$HOME_DIR" || true)"
  [ "$now" = "$DEV" ] || fail "$HOME_DIR mounted '$now', expected $DEV"
  [ -s "$HOME_DIR/.ssh/authorized_keys" ] || fail "authorized_keys not readable after mount"
fi

# --------------------------------------------------------------------- done
trap - ERR
say "Restoring services"
run systemctl unmask "code-server@$TARGET_USER.service" || true
run loginctl enable-linger "$TARGET_USER" || true
run systemctl start "user@$TARGET_UID.service" || true
run systemctl start "code-server@$TARGET_USER.service" || true

echo
if [ "$DRY_RUN" -eq 1 ]; then say "DRY-RUN complete — nothing changed."
else
  say "DONE. sdb is now mounted at $HOME_DIR (home + projects/)."
  echo "   fstab backup: $FSTAB_BAK    rollback net: $OLD_DIR (old root-disk home, untouched)"
  echo "   VERIFY (new terminal): ssh $TARGET_USER@carnac ; ls ~ ; check ~/projects, git, code-server."
  echo "   Reclaim root space once satisfied:  sudo rm -rf $OLD_DIR"
  echo "   Manual rollback before that: sudo umount $HOME_DIR && sudo rmdir $HOME_DIR && sudo mv $OLD_DIR $HOME_DIR && sudo cp -a $FSTAB_BAK $FSTAB && sudo mount UUID=$DEV_UUID $CUR_MOUNT"
fi
