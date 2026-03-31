#!/bin/bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 2.1"
  exit 1
fi

if [[ -z "${PROXY_URL:-}" ]]; then
  echo "Error: PROXY_URL is not set. Export it or add it to .env before running."
  exit 1
fi

version=$1

echo "Building claude_sandbox:${version} (proxy: ${PROXY_URL}) ..."
docker build \
  --build-arg INSTALL_PROXY="${PROXY_URL}" \
  -t claude_sandbox:${version} \
  .
echo "DONE!"
