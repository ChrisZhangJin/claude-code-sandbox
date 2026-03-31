# Claude Sandbox

A Docker-based environment for running [Claude Code](https://claude.ai/code) as a persistent, self-contained AI coding agent. The container ships with a curated set of MCP servers, pre-built sub-agents, and Claude skills ready to use out of the box.

## What's inside

| Component | Details |
|-----------|---------|
| **Claude Code** | Latest binary, installed at build time from official GCS release channel |
| **Runtimes** | Node.js 24, Python 3, Go 1.24 |
| **CLI tools** | `git`, `gh`, `ripgrep`, `fd`, `jq`, `fzf`, `bat`, `sqlite3`, `tmux`, `vim` |
| **MCP servers** | `filesystem`, `fetch`, `memory`, `github`, `brave-search`, `sqlite` |
| **Sub-agents** | `api-designer`, `code-reviewer`, `debugger`, `devops`, `doc-writer`, `git-assistant`, `security-auditor`, `test-writer` |
| **Skills** | Pulled from [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) at build time |
| **Python libs** | `fastmcp`, `langsmith` |

## Prerequisites

- Docker with Compose
- An [Anthropic API key](https://console.anthropic.com/)
- Optional: GitHub personal access token, Brave Search API key

## Setup

**1. Copy and fill in environment variables**

```bash
cp env.example .env
```

Edit `.env`:

```
GITHUB_TOKEN=ghp_...
BRAVE_API_KEY=BSA...
```

**2. Copy and edit the Compose file**

```bash
cp docker-compose.yaml.example docker-compose.yaml
```

Edit `docker-compose.yaml`:
- Set `ANTHROPIC_AUTH_TOKEN` to your Anthropic API key
- Set the workspace volume mount to your local project path:
  ```yaml
  volumes:
    - /path/to/your/workspace:/root/workspace
  ```

**3. Build the image**

```bash
./run_build.sh 2.0
```

Or build manually:

```bash
docker build -t claude_sandbox:2.0 .
```

**4. Start the container**

```bash
docker compose up -d
```

**5. Open a shell and start Claude**

```bash
docker exec -it claude-sandbox bash
claude
```

## Directory structure

```
.
├── Dockerfile                  # Image definition
├── docker-compose.yaml.example # Compose template (copy to docker-compose.yaml)
├── env.example                 # Environment variable template (copy to .env)
├── run_build.sh                # Build helper script
├── CLAUDE.md                   # Agent behavior baseline (mounted into container)
├── claude-user-config/
│   ├── settings.json           # Claude Code settings: MCP servers, hooks, env
│   └── CLAUDE.md               # User-level runtime context for the agent
└── agents/                     # Pre-built Claude sub-agent definitions
```

## MCP servers

Configured in `claude-user-config/settings.json` and available to Claude automatically:

| Server | Purpose | Requires |
|--------|---------|---------|
| `filesystem` | Read/write files under `/root` | — |
| `fetch` | HTTP fetch tool | — |
| `memory` | Persistent key-value memory | — |
| `github` | GitHub API access | `GITHUB_TOKEN` in `.env` |
| `brave-search` | Web search | `BRAVE_API_KEY` in `.env` |
| `sqlite` | SQLite at `/root/data.db` | — |

## Sub-agents

Sub-agents live in `agents/` and are loaded automatically by Claude Code. Invoke them by name during a session, e.g. `use the code-reviewer agent on this PR`.

| Agent | Role |
|-------|------|
| `api-designer` | Design and review API contracts |
| `code-reviewer` | Structured code review (critical / warnings / suggestions) |
| `debugger` | Root-cause analysis and fix suggestions |
| `devops` | Docker, CI/CD, infrastructure tasks |
| `doc-writer` | Generate and improve documentation |
| `git-assistant` | Commit messages, branch strategy, history cleanup |
| `security-auditor` | OWASP-style security review |
| `test-writer` | Write and improve test coverage |

## Skills

Skills are downloaded from [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) at image build time (no local copy needed). The following skills are installed:

`changelog-generator` · `skill-creator` · `content-research-writer` · `mcp-builder` · `langsmith-fetch` · `file-organizer` · `document-skills`

## Configuration

### Agent behavior baseline

`CLAUDE.md` (repo root) is copied into the container at `/root/CLAUDE.md` and loaded as a project-level instruction file for every session. It enforces conventions around code style, git workflow, shell tool preferences, and response style.

### Claude Code settings

`claude-user-config/settings.json` controls:
- MCP server registration
- Environment variables injected into every Claude session (`FORCE_COLOR`, `PYTHONDONTWRITEBYTECODE`, etc.)
- Experimental features (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)
- Hooks (e.g. logging session end times to `/tmp/claude-session.log`)
- Teammate mode (`tmux`)

## Security notes

- Never commit `.env` or `docker-compose.yaml` — both are in `.gitignore`.
- `ANTHROPIC_AUTH_TOKEN` goes in `docker-compose.yaml` (not `.env`) so it is never accidentally pushed.
- The container runs as `root` inside an isolated Docker network (`network_mode: host` is used for MCP server connectivity — adjust if your threat model requires stricter isolation).
