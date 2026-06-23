# Runtime Environment

This Claude Code instance runs inside a Docker container as an automated agent.

**Container facts:**
- Working directory root: `/root`
- Workspace is mounted at `/root/workspace`
- Node.js and Python3 are available; Go is optional (check `go version`)
- Shell is `/bin/bash`

---

## Network self-configuration

On first run, detect whether the network is restricted (GFW / corporate proxy)
and configure mirrors accordingly. Run these checks in order:

```
1. curl -sf --max-time 5 https://registry.npmjs.org/-/ping   → npm reachable?
2. curl -sf --max-time 5 https://pypi.org/simple/             → PyPI reachable?
3. curl -sf --max-time 5 https://storage.googleapis.com       → Google APIs reachable?
```

If **all fail**, apply the China mirror table below.
If **some fail**, apply only the relevant entries.
If **all pass**, no action needed.

---

## China mirror reference

Use this table only when the network check above indicates restricted access.

### apt (Debian)

Replace `/etc/apt/sources.list.d/debian.sources` with:

```
Types: deb deb-src
URIs: http://mirrors.tuna.tsinghua.edu.cn/debian
Suites: trixie trixie-updates trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://mirrors.tuna.tsinghua.edu.cn/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

### npm

```
npm config set registry https://registry.npmmirror.com
```

### pip

```
pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
```

### Go modules (if Go is installed)

```
go env -w GOPROXY=https://goproxy.cn
```

### Docker Hub mirror

Set `registry-mirrors` in `/etc/docker/daemon.json` (host-level, not in container):

```json
{ "registry-mirrors": ["https://docker.m.daocloud.io"] }
```

---

## Proxy fallback

If mirrors are insufficient (some upstreams are not mirrored), set environment
variables so CLI tools route through a SOCKS5 proxy:

```bash
export http_proxy=socks5h://<PROXY_HOST>:<PORT>
export https_proxy=socks5h://<PROXY_HOST>:<PORT>
```

**Always use `socks5h://`** (with `h`) so DNS is resolved by the proxy,
bypassing local DNS poisoning. Plain `socks5://` will appear to connect
but time out on GFW-poisoned domains.
