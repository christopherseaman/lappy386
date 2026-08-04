#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$OSTYPE" == "darwin"* ]]; then
  exec "$SCRIPT_DIR/setup-sandbox-mac.sh" "$@"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  exec "$SCRIPT_DIR/setup-sandbox-linux.sh" "$@"
else
  echo "Unsupported OS: $OSTYPE" >&2
  exit 1
fi

