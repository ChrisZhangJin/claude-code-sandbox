# Runtime Environment

This Claude Code instance is running inside a Docker container hosted in China.

**Container facts:**
- Working directory root: `/root`
- Workspace is mounted at `/root/workspace`
- Go, Node.js, Python3 are all available
- Shell is `/bin/bash`

**Network environment:**
- Direct access to Google, GitHub, npm (official), PyPI (official), and most foreign services is blocked by GFW.
- A SOCKS5 proxy is configured and working: `socks5h://192.168.32.101:18387`
- `http_proxy` and `https_proxy` env vars are already set — most CLI tools (`curl`, `wget`, `git`, `gh`) will use it automatically.
- **Always use `socks5h://` not `socks5://`** — the `h` suffix makes the proxy resolve DNS, bypassing GFW DNS poisoning. Using `socks5://` will appear to connect but time out due to poisoned local DNS.

**Mirror configuration (no proxy needed):**
- apt: Tsinghua mirror (`mirrors.tuna.tsinghua.edu.cn`)
- pip: Tsinghua mirror
- npm: npmmirror (`registry.npmmirror.com`)
- Go modules: `https://goproxy.cn`

**When a network request fails:**
1. Check if `http_proxy`/`https_proxy` are set (`echo $http_proxy`).
2. If the tool ignores env vars, pass the proxy explicitly (e.g. `curl --proxy socks5h://192.168.32.101:18387 ...`).
3. For `git` over HTTPS: `git config --global http.proxy socks5h://192.168.32.101:18387`
4. For `npm` if mirror is insufficient: `npm config set proxy socks5h://192.168.32.101:18387`
