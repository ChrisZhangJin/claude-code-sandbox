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

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Optional tools (NOT installed in base image)

The base image is intentionally lean. These tools are available via `bash /root/install-optional-tools.sh` if a task needs them:

- **hadolint** — Dockerfile linter (~65 MB)
- **shellcheck** — bash script linter (~35 MB, pulls perl)
- **prettier** — code formatter (~10 MB; usually installed per-project)
- **markdownlint-cli2** — markdown linter (~11 MB; usually per-project)
- **fastmcp + langsmith** — Python libs for building MCP servers / debugging LangChain agents (~120 MB with deps; only for AI/LLM tooling work)

These Claude Code plugins load on-demand from marketplaces (no manual install needed; first use will auto-download):
- `feature-dev`, `pr-review-toolkit`, `commit-commands`
