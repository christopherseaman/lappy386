#!/bin/bash
set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/christopherseaman/lappy386/refs/heads/master/hosts/strongbad"
CONTAINER_NAME="penguin"
IMAGE="ubuntu-daily:26.04"
CLOUD_INIT_TIMEOUT=900  # 15 minutes

echo "==> Downloading cloud-config..."
curl -fsSL "${REPO_BASE}/cloud-config.yaml" -o /tmp/cloud-config.yaml

echo "==> Checking for existing container..."
if lxc info "$CONTAINER_NAME" &>/dev/null; then
    echo "==> Deleting existing container '$CONTAINER_NAME'..."
    lxc delete "$CONTAINER_NAME" --force
fi

echo "==> Creating container from $IMAGE..."
lxc init "$IMAGE" "$CONTAINER_NAME" < /dev/null

echo "==> Applying cloud-config..."
lxc config set "$CONTAINER_NAME" user.user-data "$(cat /tmp/cloud-config.yaml)"

echo "==> Starting container..."
lxc start "$CONTAINER_NAME" < /dev/null

echo "==> Waiting for cloud-init to complete (timeout: ${CLOUD_INIT_TIMEOUT}s)..."
if ! timeout "$CLOUD_INIT_TIMEOUT" lxc exec "$CONTAINER_NAME" -- cloud-init status --wait; then
    echo "==> Cloud-init timed out or failed. Checking status..."
    lxc exec "$CONTAINER_NAME" -- cloud-init status --long || true
    lxc exec "$CONTAINER_NAME" -- tail -50 /var/log/cloud-init-output.log || true
    echo ""
    echo "Container is running but cloud-init did not complete."
    echo "You can retry packages manually with: lxc exec penguin -- apt-get install -y <packages>"
    exit 1
fi

echo "==> Verifying setup..."
lxc exec "$CONTAINER_NAME" -- id christopher
lxc exec "$CONTAINER_NAME" -- hostname

echo ""
echo "Done! Restart container to enable GUI integration."
