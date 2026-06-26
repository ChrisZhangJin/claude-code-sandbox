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
    git curl vim ca-certificates \
    python3 python3-pip \
    ripgrep fd-find jq tree unzip less \
    fzf bat sqlite3 make \
    build-essential openssh-client \
    gh tmux \
    git-lfs patch diffutils \
    file xxd \
    procps lsof strace \
    dnsutils \
    parallel entr \
    zip tar \
    && ln -s $(which batcat) /usr/local/bin/bat \
    && ln -s $(which fdfind) /usr/local/bin/fd \
    && pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple \
    && pip install --break-system-packages fastmcp langsmith \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache/pip

# --- npm 镜像 ---
RUN npm config set registry https://registry.npmmirror.com

# --- Claude Code（通过 npmmirror 安装，无需代理）---
RUN npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force

# --- TypeScript LSP + CodeGraph CLI ---
RUN npm install -g typescript-language-server typescript @colbymchenry/codegraph \
    && npm cache clean --force \
    && codegraph telemetry off

# --- Docker CLI（本地静态二进制）---
COPY docker-29.4.0.tgz /tmp/docker.tgz
RUN tar xzf /tmp/docker.tgz --strip-components=1 -C /usr/local/bin docker/docker \
    && chmod +x /usr/local/bin/docker \
    && rm /tmp/docker.tgz

# --- Go runtime ---
COPY --from=golang:1.25.9-alpine /usr/local/go /usr/local/go
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
RUN npx --yes get-shit-done-cc@latest  \
    && rm -rf /root/.npm/_npx

# --- Claude Code Skills (copied from local, GitHub inaccessible in China) ---
RUN mkdir -p /root/.claude/skills

# awesome-claude-skills (original set)
COPY awesome-claude-skills/changelog-generator     /root/.claude/skills/changelog-generator
COPY awesome-claude-skills/skill-creator           /root/.claude/skills/skill-creator
COPY awesome-claude-skills/content-research-writer /root/.claude/skills/content-research-writer
COPY awesome-claude-skills/mcp-builder             /root/.claude/skills/mcp-builder
COPY awesome-claude-skills/langsmith-fetch         /root/.claude/skills/langsmith-fetch
COPY awesome-claude-skills/file-organizer          /root/.claude/skills/file-organizer
COPY awesome-claude-skills/document-skills         /root/.claude/skills/document-skills

# mattpocock/skills — cloned from GitHub via proxy (includes in-progress & personal skills)
ARG INSTALL_PROXY
RUN git -c http.proxy="${INSTALL_PROXY}" clone --depth 1 \
        https://github.com/mattpocock/skills.git /tmp/mattpocock-skills \
    && for dir in /tmp/mattpocock-skills/skills/*/*; do \
           [ -d "$dir" ] && cp -r "$dir" /root/.claude/skills/; \
       done \
    && rm -rf /tmp/mattpocock-skills

# Unlock mattpocock skills that ship with `disable-model-invocation: true`
RUN sed -i '/^disable-model-invocation: true$/d' \
        /root/.claude/skills/setup-matt-pocock-skills/SKILL.md \
        /root/.claude/skills/ubiquitous-language/SKILL.md

# --- Claude Code plugin marketplaces (cloned via proxy, populated into cache) ---
RUN mkdir -p /root/.claude/plugins/marketplaces /root/.claude/plugins/cache \
    && git -c http.proxy="${INSTALL_PROXY}" clone --depth 1 \
        https://github.com/anthropics/claude-plugins-official.git \
        /root/.claude/plugins/marketplaces/claude-plugins-official \
    && git -c http.proxy="${INSTALL_PROXY}" clone --depth 1 \
        https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git \
        /root/.claude/plugins/marketplaces/ui-ux-pro-max-skill \
    && rm -rf /root/.claude/plugins/marketplaces/*/.git \
    && mkdir -p /root/.claude/plugins/cache/claude-plugins-official/context7/latest \
    && cp -r /root/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/context7/. \
              /root/.claude/plugins/cache/claude-plugins-official/context7/latest/ \
    && mkdir -p /root/.claude/plugins/cache/claude-plugins-official/security-guidance/2.0.4 \
    && cp -r /root/.claude/plugins/marketplaces/claude-plugins-official/plugins/security-guidance/. \
              /root/.claude/plugins/cache/claude-plugins-official/security-guidance/2.0.4/ \
    && mkdir -p /root/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0 \
    && cp -r /root/.claude/plugins/marketplaces/claude-plugins-official/plugins/typescript-lsp/. \
              /root/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/ \
    && mkdir -p /root/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.6.2 \
    && cp -r /root/.claude/plugins/marketplaces/ui-ux-pro-max-skill/. \
              /root/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.6.2/

# addyosmani/agent-skills — spec→ship lifecycle + engineering discipline
COPY awesome-claude-skills/using-agent-skills               /root/.claude/skills/using-agent-skills
COPY awesome-claude-skills/idea-refine                      /root/.claude/skills/idea-refine
COPY awesome-claude-skills/spec-driven-development          /root/.claude/skills/spec-driven-development
COPY awesome-claude-skills/planning-and-task-breakdown      /root/.claude/skills/planning-and-task-breakdown
COPY awesome-claude-skills/incremental-implementation       /root/.claude/skills/incremental-implementation
COPY awesome-claude-skills/test-driven-development          /root/.claude/skills/test-driven-development
COPY awesome-claude-skills/context-engineering              /root/.claude/skills/context-engineering
COPY awesome-claude-skills/source-driven-development        /root/.claude/skills/source-driven-development
COPY awesome-claude-skills/doubt-driven-development         /root/.claude/skills/doubt-driven-development
COPY awesome-claude-skills/frontend-ui-engineering          /root/.claude/skills/frontend-ui-engineering
COPY awesome-claude-skills/api-and-interface-design         /root/.claude/skills/api-and-interface-design
COPY awesome-claude-skills/browser-testing-with-devtools    /root/.claude/skills/browser-testing-with-devtools
COPY awesome-claude-skills/debugging-and-error-recovery     /root/.claude/skills/debugging-and-error-recovery
COPY awesome-claude-skills/code-review-and-quality          /root/.claude/skills/code-review-and-quality
COPY awesome-claude-skills/code-simplification              /root/.claude/skills/code-simplification
COPY awesome-claude-skills/security-and-hardening           /root/.claude/skills/security-and-hardening
COPY awesome-claude-skills/performance-optimization         /root/.claude/skills/performance-optimization
COPY awesome-claude-skills/git-workflow-and-versioning      /root/.claude/skills/git-workflow-and-versioning
COPY awesome-claude-skills/ci-cd-and-automation             /root/.claude/skills/ci-cd-and-automation
COPY awesome-claude-skills/deprecation-and-migration        /root/.claude/skills/deprecation-and-migration
COPY awesome-claude-skills/documentation-and-adrs           /root/.claude/skills/documentation-and-adrs
COPY awesome-claude-skills/shipping-and-launch              /root/.claude/skills/shipping-and-launch
COPY awesome-claude-skills/agent-skills-hooks               /root/.claude/skills/agent-skills-hooks
COPY awesome-claude-skills/agent-skills-references          /root/.claude/skills/agent-skills-references

# --- Project-level agent behavior baseline ---
COPY CLAUDE.md /root/CLAUDE.md

WORKDIR /root

CMD ["tail", "-f", "/dev/null"]
