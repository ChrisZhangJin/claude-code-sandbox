FROM node:24-slim

# --- System tools + Python packages ---
# build-essential installed and purged in the same layer to avoid size bloat
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl vim net-tools ca-certificates \
        python3 python3-pip \
        ripgrep fd-find jq tree wget unzip less \
        fzf bat sqlite3 make \
        build-essential \
        gh tmux \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && pip install --break-system-packages fastmcp langsmith \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache/pip

# --- Claude Code ---
RUN GCS="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" \
    && VERSION=$(curl -fsSL "${GCS}/latest") \
    && curl -fsSL "${GCS}/${VERSION}/linux-x64/claude" -o /usr/local/bin/claude \
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

# --- Claude Code Skills ---
RUN git clone --depth=1 https://github.com/ComposioHQ/awesome-claude-skills /tmp/awesome-claude-skills \
    && mkdir -p /root/.claude/skills \
    && cp -r /tmp/awesome-claude-skills/changelog-generator     /root/.claude/skills/changelog-generator \
    && cp -r /tmp/awesome-claude-skills/skill-creator           /root/.claude/skills/skill-creator \
    && cp -r /tmp/awesome-claude-skills/content-research-writer /root/.claude/skills/content-research-writer \
    && cp -r /tmp/awesome-claude-skills/mcp-builder             /root/.claude/skills/mcp-builder \
    && cp -r /tmp/awesome-claude-skills/langsmith-fetch         /root/.claude/skills/langsmith-fetch \
    && cp -r /tmp/awesome-claude-skills/file-organizer          /root/.claude/skills/file-organizer \
    && cp -r /tmp/awesome-claude-skills/document-skills         /root/.claude/skills/document-skills \
    && rm -rf /tmp/awesome-claude-skills

# --- Project-level agent behavior baseline ---
COPY CLAUDE.md /root/CLAUDE.md

WORKDIR /root

CMD ["tail", "-f", "/dev/null"]
