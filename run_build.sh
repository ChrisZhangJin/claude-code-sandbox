#!/bin/bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 2.1"
  exit 1
fi

version=$1

echo "Building claude_sandbox:${version} ..."
docker build \
  -t claude_sandbox:${version} \
  .
echo "DONE!"
