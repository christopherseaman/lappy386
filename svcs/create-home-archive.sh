#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp /tmp/home-backup.XXXXXX.tgz)"
trap 'rm -f "$tmp"' EXIT
dest="$HOME/bkp-$(hostname -s)-${USER}-$(date +%Y%m%d-%H%M%S).tgz"

tar -C "$HOME" -czf "$tmp" \
  --exclude='./.cache' \
  --exclude='./.local' \
  --exclude='*/.venv' \
  --exclude='*/venv' \
  --exclude='*/virtualenv' \
  --exclude='*/.virtualenv' \
  --exclude='*/node_modules' \
  --exclude='*/.tox' \
  --exclude='*/.nox' \
  .

mv "$tmp" "$dest"
trap - EXIT
echo "Backup complete: $dest"
