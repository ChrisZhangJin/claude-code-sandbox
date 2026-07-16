FROM node:24-slim AS npm-builder

ARG INSTALL_PROXY

# --- 清华 npm 镜像 ---
RUN npm config set registry https://registry.npmmirror.com

# --- npm globals: Claude Code + TypeScript LSP + CodeGraph ---
# 版本固定：避免每月 @latest 漂移撑大层并击穿 build cache（手动 bump）
# 不在 builder 里清 cache：让 final stage COPY --from=builder 后整体清理
RUN npm install -g \
        @anthropic-ai/claude-code@2.1.211 \
        typescript-language-server@5.3.0 typescript@7.0.2 \
        @colbymchenry/codegraph@1.4.1 \
    && codegraph telemetry off

# --- GSD: Get Shit Done workflow system ---
# 装到 /root/.claude；final stage 只 COPY 需要的子目录
RUN npx --yes get-shit-done-cc@1.42.3

# --- Cleanup builder stage artefacts (npx cache, npm cache) ---
RUN rm -rf /root/.npm/_npx /root/.npm/_cacache /root/.npm/_logs

# ============================================================================
# Docker CLI extraction — throwaway stage keeps the 86MB tarball out of the
# final image; only the ~42MB docker binary is copied across.
FROM node:24-slim AS docker-extract
COPY docker-29.4.0.tgz /tmp/docker.tgz
RUN tar xzf /tmp/docker.tgz --strip-components=1 -C /usr/local/bin docker/docker \
    && chmod +x /usr/local/bin/docker

# ============================================================================

FROM node:24-slim

ARG INSTALL_PROXY

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
    && pip install --break-system-packages uv \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache/pip
# fastmcp / langsmith 移到 install-optional-tools.sh（~120MB，非核心工作负载）

# --- Copy npm globals from builder — node_modules only ---
# 只 COPY node_modules，避免重复带入 base 已有的 ~116MB node 二进制；
# 手动重建 4 个 global bin symlink（node/npm/npx/corepack/yarn 由 base 提供）。
COPY --from=npm-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe  /usr/local/bin/claude \
    && ln -sf ../lib/node_modules/@colbymchenry/codegraph/npm-shim.js     /usr/local/bin/codegraph \
    && ln -sf ../lib/node_modules/typescript/bin/tsc                      /usr/local/bin/tsc \
    && ln -sf ../lib/node_modules/typescript-language-server/lib/cli.mjs  /usr/local/bin/typescript-language-server

COPY --from=npm-builder /root/.claude/skills /root/.claude/skills
COPY --from=npm-builder /root/.claude/agents /root/.claude/agents
COPY --from=npm-builder /root/.claude/hooks /root/.claude/hooks
COPY --from=npm-builder /root/.claude/package.json /root/.claude/package.json
COPY --from=npm-builder /root/.claude/gsd-file-manifest.json /root/.claude/gsd-file-manifest.json

# --- Docker CLI（从 docker-extract stage 取二进制，tarball 不进入镜像）---
COPY --from=docker-extract /usr/local/bin/docker /usr/local/bin/docker

# --- docker compose (CLI plugin; not bundled in docker.tgz, not in trixie repo) ---
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -sSL --proxy "${INSTALL_PROXY}" -o /usr/local/lib/docker/cli-plugins/docker-compose \
        https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64 \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

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

# --- Optional tools installer (NOT auto-installed; run on demand) ---
COPY install-optional-tools.sh /root/install-optional-tools.sh
RUN chmod +x /root/install-optional-tools.sh

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
    && mkdir -p /root/.claude/plugins/cache/claude-plugins-official/security-guidance/2.0.6 \
    && cp -r /root/.claude/plugins/marketplaces/claude-plugins-official/plugins/security-guidance/. \
              /root/.claude/plugins/cache/claude-plugins-official/security-guidance/2.0.6/ \
    && mkdir -p /root/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0 \
    && cp -r /root/.claude/plugins/marketplaces/claude-plugins-official/plugins/typescript-lsp/. \
              /root/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/ \
    && mkdir -p /root/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.11.0 \
    && cp -r /root/.claude/plugins/marketplaces/ui-ux-pro-max-skill/. \
              /root/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max/2.11.0/

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

# --- Project-level agent behavior baseline ---
COPY CLAUDE.md /root/CLAUDE.md

WORKDIR /root

CMD ["tail", "-f", "/dev/null"]