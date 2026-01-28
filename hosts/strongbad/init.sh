#!/bin/bash
set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/christopherseaman/lappy386/refs/heads/master/hosts/strongbad"
CONTAINER_NAME="penguin"
IMAGE="ubuntu-minimal-daily:resolute"

# Add remote if needed, squash error if already set up
lxc remote add --protocol simplestreams ubuntu-minimal-daily https://cloud-images.ubuntu.com/minimal/daily/ 2>/dev/null || true

# Set up yank() as convenience function in vmc termina in case anything goes wrong
yank() {
  local content
  if [[ -f "$1" ]]; then
    content=$(cat "$1")
  else
    content=$(cat)
  fi

  if [[ "$OSTYPE" == "darwin"* ]] && [[ -z "$TMUX" ]]; then
    printf "%s" "$content" | pbcopy
  else
    local b64=$(printf "%s" "$content" | base64 | tr -d '\n')
    echo -en "\033Ptmux;\033\033]52;c;${b64}\007\033\\"
  fi
}

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

echo "==> Waiting for cloud-init to complete..."
lxc exec "$CONTAINER_NAME" -- cloud-init status --wait

echo "==> Verifying setup..."
lxc exec "$CONTAINER_NAME" -- id christopher
lxc exec "$CONTAINER_NAME" -- hostname

echo ""
echo "Done! Restart container to enable GUI integration."
