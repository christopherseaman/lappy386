#!/bin/bash
set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/christopherseaman/lappy386/refs/heads/master/hosts/strongbad"
CONTAINER_NAME="penguin"
IMAGE="ubuntu-daily:26.04"

echo "==> Downloading cloud-config..."
curl -fsSL "${REPO_BASE}/cloud-config.yaml" -o /tmp/cloud-config.yaml

echo "==> Checking for existing container..."
if lxc info "$CONTAINER_NAME" &>/dev/null; then
    echo "==> Deleting existing container '$CONTAINER_NAME'..."
    lxc delete "$CONTAINER_NAME" --force
fi

echo "==> Launching $IMAGE as $CONTAINER_NAME..."
lxc launch "$IMAGE" "$CONTAINER_NAME" \
    --config=user.user-data="$(cat /tmp/cloud-config.yaml)"

echo "==> Waiting for cloud-init to complete..."
# Poll for completion (timeout after 5 min)
for i in {1..60}; do
    if lxc exec "$CONTAINER_NAME" -- test -f /home/christopher/.cloud-init-done 2>/dev/null; then
        echo "==> Cloud-init finished!"
        break
    fi
    echo "    waiting... ($i/60)"
    sleep 5
done

echo "==> Verifying setup..."
lxc exec "$CONTAINER_NAME" -- id christopher
lxc exec "$CONTAINER_NAME" -- hostname

echo ""
echo "Done! You may need to restart the container for Crostini integration:"
echo "  lxc restart $CONTAINER_NAME"
echo ""
echo "Or restart Linux from ChromeOS Settings > Advanced > Developers"
