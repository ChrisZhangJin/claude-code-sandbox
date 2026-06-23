#!/bin/bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <version> [--go] [--docker] [--china]"
  echo ""
  echo "Options:"
  echo "  --go       Include Go runtime (adds ~300MB)"
  echo "  --docker   Include Docker CLI (adds ~70MB)"
  echo "  --china    Use China mirrors for apt/npm/pip"
  echo ""
  echo "Examples:"
  echo "  $0 1.0                  # minimal image, international mirrors"
  echo "  $0 1.0 --china          # minimal image, China mirrors baked in"
  echo "  $0 1.0 --go --docker    # full dev toolkit"
  exit 1
fi

version=$1
shift

install_go=false
install_docker=false
apt_mir=""
npm_reg="https://registry.npmjs.org"
pip_idx="https://pypi.org/simple"
go_proxy="https://proxy.golang.org"

for arg in "$@"; do
  case "$arg" in
    --go)       install_go=true ;;
    --docker)   install_docker=true ;;
    --china)
      apt_mir="mirrors.tuna.tsinghua.edu.cn"
      npm_reg="https://registry.npmmirror.com"
      pip_idx="https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"
      go_proxy="https://goproxy.cn"
      ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

echo "Building claude_agent:${version}"
echo "  Go: ${install_go} | Docker: ${install_docker}"
[[ -n "$apt_mir" ]] && echo "  Mirrors: China (Tsinghua/npmmirror)"

docker build \
  -f Dockerfile.agent \
  --build-arg INSTALL_GO="${install_go}" \
  --build-arg INSTALL_DOCKER="${install_docker}" \
  --build-arg APT_MIRROR="${apt_mir}" \
  --build-arg NPM_REGISTRY="${npm_reg}" \
  --build-arg PIP_INDEX_URL="${pip_idx}" \
  --build-arg GO_MODULE_PROXY="${go_proxy}" \
  -t "claude_agent:${version}" \
  .
echo "DONE!"
