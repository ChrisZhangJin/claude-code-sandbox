#!/bin/bash
# Install tools that are NOT in the base image but may be useful on demand.
# Source: Tsinghua / npmmirror + GitHub proxy for releases.
# This script is at /root/install-optional-tools.sh inside the container.

set -euo pipefail

echo "Installing optional tools (skipping those already present)..."

# hadolint — Dockerfile linter (~65 MB)
if ! command -v hadolint >/dev/null 2>&1; then
  echo "  → hadolint"
  curl -sSL --proxy "${http_proxy:-}" \
    -o /usr/local/bin/hadolint \
    https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
  chmod +x /usr/local/bin/hadolint
else
  echo "  = hadolint (already installed)"
fi

# shellcheck — bash script linter (~35 MB, pulls perl dependencies)
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "  → shellcheck"
  apt-get update && apt-get install -y --no-install-recommends shellcheck
  rm -rf /var/lib/apt/lists/*
else
  echo "  = shellcheck (already installed)"
fi

# prettier — code formatter (~10 MB)
if ! command -v prettier >/dev/null 2>&1; then
  echo "  → prettier"
  npm install -g prettier
else
  echo "  = prettier (already installed)"
fi

# markdownlint-cli2 — markdown linter (~11 MB)
if ! command -v markdownlint-cli2 >/dev/null 2>&1; then
  echo "  → markdownlint-cli2"
  npm install -g markdownlint-cli2
else
  echo "  = markdownlint-cli2 (already installed)"
fi

# fastmcp + langsmith — Python libs for building MCP servers / debugging
# LangChain agents (~120 MB with deps). Only needed for AI/LLM tooling work.
if ! python3 -c "import fastmcp" >/dev/null 2>&1; then
  echo "  → fastmcp + langsmith"
  pip install --break-system-packages fastmcp langsmith
else
  echo "  = fastmcp + langsmith (already installed)"
fi

echo ""
echo "Done. Restart Claude Code if hooks depend on any of these tools."