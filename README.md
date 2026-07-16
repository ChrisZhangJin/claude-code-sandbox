# Claude Sandbox

基于 Docker 的持久化 AI 编程代理运行环境，用于运行 [Claude Code](https://claude.ai/code)。容器内置精选 MCP 服务器、预构建子代理和 Claude 技能，开箱即用。

## 内置组件

| 组件 | 说明 |
|------|------|
| **Claude Code** | 构建时从官方 GCS 发布渠道安装最新二进制 |
| **运行时** | Node.js 24、Python 3、Go 1.24 |
| **CLI 工具** | `git`、`gh`、`ripgrep`、`fd`、`jq`、`fzf`、`bat`、`sqlite3`、`tmux`、`vim` |
| **MCP 服务器** | `filesystem`、`fetch`、`memory`、`github`、`brave-search`、`sqlite` |
| **子代理** | `architect`、`database-agent`、`data-engineer`、`incident-runner`、`product-manager`、`ux-writer` |
| **技能** | 构建时从多个来源拉取（见下方技能章节） |
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

## Agent 镜像（自动化智能体）

除交互式镜像外，本仓库还提供一个专为自动化代理设计的轻量镜像。移除了所有人工交互组件，适用于 CI/CD、监控、日志分析、数据库查询等无人值守场景。

### 与交互式镜像的区别

| | 交互式 (`Dockerfile`) | Agent (`Dockerfile.agent`) |
|---|---|---|
| **基础镜像** | `node:24-slim` | `node:24-slim` |
| **GSD 工作流** | 完整安装 + 钩子 | 已移除 |
| **交互工具** | tmux、vim、fzf、bat | 已移除 |
| **Go 运行时** | 固定安装 (~300MB) | 可选 (`--build-arg INSTALL_GO=true`) |
| **Docker CLI** | 固定安装 (~70MB) | 可选 (`--build-arg INSTALL_DOCKER=true`) |
| **MCP 服务器** | 7 个 | 1 个 (github) |
| **技能** | 30+ 个 | 5 个自动化相关 |
| **中国镜像** | 硬编码在 Dockerfile | 运行时知识库，agent 自动检测并配置 |
| **预估大小** | ~900MB | ~250MB (最小) |

### 构建 Agent 镜像

```bash
# 最小镜像 (~250MB)
./run_build_agent.sh 1.0

# 使用中国镜像源构建
./run_build_agent.sh 1.0 --china

# 包含 Go + Docker CLI
./run_build_agent.sh 1.0 --go --docker
```

手动构建：

```bash
docker build -f Dockerfile.agent \
  --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn \
  --build-arg NPM_REGISTRY=https://registry.npmmirror.com \
  --build-arg INSTALL_GO=false \
  -t claude_agent:1.0 .
```

### 构建参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `INSTALL_GO` | `false` | 安装 Go 运行时 (+300MB) |
| `INSTALL_DOCKER` | `false` | 安装 Docker CLI (+70MB) |
| `DOCKER_VERSION` | `29.4.0` | Docker CLI 版本 |
| `APT_MIRROR` | `""` (官方源) | apt 镜像地址 |
| `NPM_REGISTRY` | `https://registry.npmjs.org` | npm 注册表 |
| `PIP_INDEX_URL` | `https://pypi.org/simple` | PyPI 索引 |
| `GO_MODULE_PROXY` | `https://proxy.golang.org` | Go 模块代理 |

### 中国部署说明

Agent 镜像默认使用国际源构建。部署到中国网络环境时，agent 会在首次运行时自动检测网络状况并配置镜像（参见容器内 `/root/.claude/CLAUDE.md`）。也可以在构建时直接使用中国镜像：

```bash
./run_build_agent.sh 1.0 --china
```

## 目录结构

```
.
├── Dockerfile                  # 交互式镜像定义
├── Dockerfile.agent            # Agent 镜像定义（自动化智能体）
├── docker-compose.yaml.example # Compose 模板（复制为 docker-compose.yaml）
├── env.example                 # 环境变量模板（复制为 .env）
├── run_build.sh                # 交互式镜像构建脚本
├── run_build_agent.sh          # Agent 镜像构建脚本
├── CLAUDE.md                   # 代理行为基线（挂载至容器内）
├── claude-user-config/
│   ├── settings.json           # 交互式配置：MCP 服务器、钩子、环境变量
│   ├── settings.agent.json     # Agent 配置：最小化钩子、精简 MCP
│   └── CLAUDE.md               # 运行时上下文 + 中国镜像知识库
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

子代理定义位于 `agents/`，由 Claude Code 自动加载。已移除与技能重叠的代理，仅保留无技能覆盖的领域专家。在会话中按名称调用，例如：`使用 architect 代理设计系统架构`。

| 代理 | 职责 |
|------|------|
| `architect` | 系统架构设计、技术选型、可扩展性评估 |
| `database-agent` | 数据库 schema 设计、迁移、查询优化 |
| `data-engineer` | 数据管道、ETL/ELT、分析 schema |
| `incident-runner` | Runbook 编写、故障诊断、事后复盘 |
| `product-manager` | 用户故事、验收标准、需求拆解 |
| `ux-writer` | UI 文案、错误提示、微文案、本地化 |

## 技能

技能在镜像构建时从本地 `awesome-claude-skills/` 目录复制到容器内。来源如下：

### [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills)

`changelog-generator` · `skill-creator` · `content-research-writer` · `mcp-builder` · `langsmith-fetch` · `file-organizer` · `document-skills`

### [mattpocock/skills](https://github.com/mattpocock/skills)

日常工程技能 — 调试、TDD、PRD 编写、issue 拆分、token 压缩等。

| 技能 | 用途 |
|------|------|
| `diagnose` | 调试循环：复现 → 最小化 → 假设 → 插桩 → 修复 → 回归测试 |
| `tdd` | 测试驱动开发（红-绿-重构） |
| `to-prd` | 对话上下文 → PRD GitHub Issue |
| `to-issues` | 拆分为独立可领取的 GitHub Issue |
| `triage` | Issue 分诊状态机 |
| `grill-with-docs` | 术语打磨，更新 CONTEXT.md 和 ADR |
| `grill-me` | 追问式访谈，穷尽决策分支 |
| `caveman` | 极简沟通模式，约省 75% token |
| `handoff` | 压缩对话，供其他 agent 继续 |
| `prototype` | 一次性原型构建 |
| `zoom-out` | 为不熟悉的代码提供系统级上下文 |
| `improve-codebase-architecture` | 识别架构深化机会 |
| `write-a-skill` | 创建新技能 |
| `setup-matt-pocock-skills` | 初始化每仓库配置（首次使用前运行） |
| `git-guardrails-claude-code` | 通过钩子拦截危险 git 命令 |
| `scaffold-exercises` | 创建练习目录结构 |
| `setup-pre-commit` | 配置 Husky + lint-staged |

### [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)

生产级工程纪律 — 从 spec 到 ship 的完整生命周期，含安全、性能、前端、API 设计专项。

| 技能 | 用途 |
|------|------|
| `using-agent-skills` | 元技能：将工作映射到正确的技能流程 |
| `idea-refine` | 发散/收敛思维，模糊想法 → 具体提案 |
| `spec-driven-development` | 先写 PRD，再写代码 |
| `planning-and-task-breakdown` | 拆分为带验收标准的小任务 |
| `incremental-implementation` | 薄纵向切片，特性开关，安全回滚 |
| `test-driven-development` | TDD，测试金字塔，Beyonce 规则 |
| `context-engineering` | 在正确的时间提供正确的上下文 |
| `source-driven-development` | 基于官方文档做框架决策 |
| `doubt-driven-development` | 对抗式审查每个非平凡决策 |
| `frontend-ui-engineering` | 组件架构、设计系统、WCAG 2.1 AA |
| `api-and-interface-design` | 契约优先、Hyrum 定律、错误语义 |
| `browser-testing-with-devtools` | Chrome DevTools MCP 实时运行时数据 |
| `debugging-and-error-recovery` | 五步分诊：复现 → 定位 → 精简 → 修复 → 防护 |
| `code-review-and-quality` | 五维审查，变更分级 |
| `code-simplification` | Chesterton 栅栏、Rule of 500 |
| `security-and-hardening` | OWASP Top 10、认证模式、密钥管理 |
| `performance-optimization` | 先度量，Core Web Vitals 目标 |
| `git-workflow-and-versioning` | 主干开发、原子提交 |
| `ci-cd-and-automation` | 左移、特性开关、质量门 |
| `deprecation-and-migration` | 代码即负债、迁移模式、僵尸代码清理 |
| `documentation-and-adrs` | ADR、API 文档、内联文档标准 |
| `shipping-and-launch` | 发布清单、分阶段发布、回滚流程 |

此外还附带 `agent-skills-hooks`（会话生命周期钩子）和 `agent-skills-references`（测试、安全、性能、无障碍速查表）。

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
