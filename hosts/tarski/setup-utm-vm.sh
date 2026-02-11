#!/bin/bash
# Build cloud-init seed ISO and prep disk for UTM
# Run this on your Mac host

# https://cdimage.debian.org/images/cloud/
# https://docs.getutm.app/guest-support/linux/


set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CIDATA_DIR="$SCRIPT_DIR/cidata"
OUTPUT_DIR="$SCRIPT_DIR"

echo "=== Building cloud-init seed ISO ==="
mkdir -p "$CIDATA_DIR"
rm $OUTPUT_DIR/cidata.iso 2>/dev/null || true
hdiutil makehybrid \
  -o "$OUTPUT_DIR/cidata.iso" \
  "$CIDATA_DIR" \
  -joliet -iso
echo "Created: $OUTPUT_DIR/cidata.iso"

echo ""
echo "=== Resizing qcow2 disk ==="
# Adjust the path/filename to match your download
QCOW2=$(ls "$OUTPUT_DIR"/debian-*-genericcloud-arm64*.qcow2 2>/dev/null | head -1)
if [ -z "$QCOW2" ]; then
  echo "No genericcloud qcow2 found in $OUTPUT_DIR"
  echo "Download from: https://cloud.debian.org/images/cloud/trixie/daily/latest/"
  echo "Then run: qemu-img resize <file>.qcow2 32G"
else
  qemu-img resize "$QCOW2" 16G
  echo "Resized: $QCOW2 → 16G"
fi

echo ""
echo "=== UTM Setup Steps ==="
echo "1. New VM → Virtualize (Mac) or Emulate (iPad)"
echo "2. OS: Linux, skip ISO boot"
echo "3. Import Drive → select the .qcow2 file"
echo "4. Add Removable Drive (CD/DVD) → select cidata.iso"
echo "5. Boot — cloud-init runs automatically on first boot"
echo "6. SSH in: ssh christopher@<vm-ip>"
echo "7. After first boot succeeds, remove the cidata CD drive"
