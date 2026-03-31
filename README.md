# Claude Sandbox

基于 Docker 的持久化 AI 编程代理运行环境，用于运行 [Claude Code](https://claude.ai/code)。容器内置精选 MCP 服务器、预构建子代理和 Claude 技能，开箱即用。

## 内置组件

| 组件 | 说明 |
|------|------|
| **Claude Code** | 构建时从官方 GCS 发布渠道安装最新二进制 |
| **运行时** | Node.js 24、Python 3、Go 1.24 |
| **CLI 工具** | `git`、`gh`、`ripgrep`、`fd`、`jq`、`fzf`、`bat`、`sqlite3`、`tmux`、`vim` |
| **MCP 服务器** | `filesystem`、`fetch`、`memory`、`github`、`brave-search`、`sqlite` |
| **子代理** | `api-designer`、`code-reviewer`、`debugger`、`devops`、`doc-writer`、`git-assistant`、`security-auditor`、`test-writer` |
| **技能** | 构建时从 [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) 拉取 |
| **Python 库** | `fastmcp`、`langsmith` |

## 前置条件

- Docker 及 Compose
- [Anthropic API 密钥](https://console.anthropic.com/)
- 可选：GitHub Personal Access Token、Brave Search API 密钥

## 快速开始

**1. 配置环境变量**

```bash
cp env.example .env
```

编辑 `.env`：

```
GITHUB_TOKEN=ghp_...
BRAVE_API_KEY=BSA...
```

**2. 配置 Compose 文件**

```bash
cp docker-compose.yaml.example docker-compose.yaml
```

编辑 `docker-compose.yaml`：
- 将 `ANTHROPIC_AUTH_TOKEN` 设置为你的 Anthropic API 密钥
- 将工作区卷挂载路径改为本地项目目录：
  ```yaml
  volumes:
    - /path/to/your/workspace:/root/workspace
  ```

**3. 构建镜像**

```bash
./run_build.sh 2.0
```

或手动构建：

```bash
docker build -t claude_sandbox:2.0 .
```

**4. 启动容器**

```bash
docker compose up -d
```

**5. 进入容器并启动 Claude**

```bash
docker exec -it claude-sandbox bash
claude
```

## 目录结构

```
.
├── Dockerfile                  # 镜像定义
├── docker-compose.yaml.example # Compose 模板（复制为 docker-compose.yaml）
├── env.example                 # 环境变量模板（复制为 .env）
├── run_build.sh                # 构建辅助脚本
├── CLAUDE.md                   # 代理行为基线（挂载至容器内）
├── claude-user-config/
│   ├── settings.json           # Claude Code 配置：MCP 服务器、钩子、环境变量
│   └── CLAUDE.md               # 用户级运行时上下文
└── agents/                     # 预构建 Claude 子代理定义
```

## MCP 服务器

在 `claude-user-config/settings.json` 中配置，Claude 自动加载：

| 服务器 | 用途 | 依赖 |
|--------|------|------|
| `filesystem` | 读写 `/root` 下的文件 | — |
| `fetch` | HTTP 请求工具 | — |
| `memory` | 持久化键值存储 | — |
| `github` | GitHub API 访问 | `.env` 中的 `GITHUB_TOKEN` |
| `brave-search` | 网页搜索 | `.env` 中的 `BRAVE_API_KEY` |
| `sqlite` | SQLite 数据库（`/root/data.db`） | — |

## 子代理

子代理定义位于 `agents/`，由 Claude Code 自动加载。在会话中按名称调用，例如：`使用 code-reviewer 代理审查这个 PR`。

| 代理 | 职责 |
|------|------|
| `api-designer` | API 契约设计与审查 |
| `code-reviewer` | 结构化代码审查（严重问题 / 警告 / 建议） |
| `debugger` | 根因分析与修复建议 |
| `devops` | Docker、CI/CD 及基础设施任务 |
| `doc-writer` | 文档生成与改进 |
| `git-assistant` | 提交信息、分支策略、历史清理 |
| `security-auditor` | OWASP 风格安全审查 |
| `test-writer` | 编写与改善测试覆盖率 |

## 技能

技能在镜像构建时从 [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) 下载，无需本地副本。已安装以下技能：

`changelog-generator` · `skill-creator` · `content-research-writer` · `mcp-builder` · `langsmith-fetch` · `file-organizer` · `document-skills`

## 配置说明

### 代理行为基线

`CLAUDE.md`（仓库根目录）被复制到容器内的 `/root/CLAUDE.md`，作为每次会话的项目级指令文件，约束代码风格、Git 工作流、Shell 工具偏好和响应风格。

### Claude Code 配置

`claude-user-config/settings.json` 控制：
- MCP 服务器注册
- 注入每次 Claude 会话的环境变量（`FORCE_COLOR`、`PYTHONDONTWRITEBYTECODE` 等）
- 实验性功能（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`）
- 钩子（如将会话结束时间记录到 `/tmp/claude-session.log`）
- 团队协作模式（`tmux`）

## 安全说明

- 不要提交 `.env` 或 `docker-compose.yaml`，两者均已加入 `.gitignore`。
- `ANTHROPIC_AUTH_TOKEN` 放在 `docker-compose.yaml` 中（而非 `.env`），以防意外推送到代码仓库。
- 容器以 `root` 用户运行，使用 `network_mode: host`（用于 MCP 服务器连通性）。如有更严格的安全要求，请调整网络模式。
