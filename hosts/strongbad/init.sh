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

echo "==> Creating container from $IMAGE..."
lxc init "$IMAGE" "$CONTAINER_NAME"

echo "==> Applying cloud-config..."
lxc config set "$CONTAINER_NAME" user.user-data - < /tmp/cloud-config.yaml

echo "==> Starting container..."
lxc start "$CONTAINER_NAME"

echo "==> Waiting for cloud-init to complete..."
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
