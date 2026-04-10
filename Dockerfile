FROM node:24-slim

# --- 清华 apt 镜像 ---
RUN mv /etc/apt/sources.list.d/debian.sources /etc/apt/debian.sources.bak \
    && echo \
'Types: deb deb-src\n\
URIs: http://mirrors.tuna.tsinghua.edu.cn/debian\n\
Suites: trixie trixie-updates trixie-backports\n\
Components: main contrib non-free non-free-firmware\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\
\n\
Types: deb deb-src\n\
URIs: http://mirrors.tuna.tsinghua.edu.cn/debian-security\n\
Suites: trixie-security\n\
Components: main contrib non-free non-free-firmware\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' \
    > /etc/apt/sources.list.d/debian.sources

# --- 系统工具 + Python 包 ---
# build-essential 在同一层安装并清理，避免镜像体积膨胀
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl vim net-tools ca-certificates \
        python3 python3-pip \
        ripgrep fd-find jq tree wget unzip less \
        fzf bat sqlite3 make \
        build-essential \
        gh tmux \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple \
    && pip install --break-system-packages fastmcp langsmith \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache/pip

# --- npm 镜像 ---
RUN npm config set registry https://registry.npmmirror.com

# --- Claude Code（通过代理下载，绕过 storage.googleapis.com 封锁）---
ARG INSTALL_PROXY
RUN GCS="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" \
    && VERSION=$(curl -fsSL --proxy ${INSTALL_PROXY} "${GCS}/latest") \
    && curl -fsSL --proxy ${INSTALL_PROXY} "${GCS}/${VERSION}/linux-x64/claude" -o /usr/local/bin/claude \
    && chmod +x /usr/local/bin/claude

# --- Go runtime ---
COPY --from=golang:1.24-alpine /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go
ENV PATH=$PATH:/usr/local/go/bin

# --- Git config ---
RUN git config --global user.email "dev@container" && \
    git config --global user.name "Dev"

# --- Claude Code settings.json ---
RUN mkdir -p /root/.claude
COPY claude-user-config/settings.json /root/.claude/settings.json

# --- User-level CLAUDE.md (environment awareness, loaded for every project) ---
COPY claude-user-config/CLAUDE.md /root/.claude/CLAUDE.md

# --- Pre-built agents ---
COPY agents/ /root/.claude/agents/

# --- GSD: Get Shit Done workflow system ---
# Installs hooks, skills, and merges settings.json; harmless if already present
RUN npx --yes get-shit-done-cc@latest || true

# --- Claude Code Skills (copied from local, GitHub inaccessible in China) ---
RUN mkdir -p /root/.claude/skills
COPY awesome-claude-skills/changelog-generator     /root/.claude/skills/changelog-generator
COPY awesome-claude-skills/skill-creator           /root/.claude/skills/skill-creator
COPY awesome-claude-skills/content-research-writer /root/.claude/skills/content-research-writer
COPY awesome-claude-skills/mcp-builder             /root/.claude/skills/mcp-builder
COPY awesome-claude-skills/langsmith-fetch         /root/.claude/skills/langsmith-fetch
COPY awesome-claude-skills/file-organizer          /root/.claude/skills/file-organizer
COPY awesome-claude-skills/document-skills         /root/.claude/skills/document-skills

# --- Project-level agent behavior baseline ---
COPY CLAUDE.md /root/CLAUDE.md

WORKDIR /root

CMD ["tail", "-f", "/dev/null"]
