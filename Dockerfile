# ============================================================================
# Docker CLI 抽取阶段 —— tarball 大 (86MB)，隔离在 throwaway stage，
# 只把 42MB docker 二进制 COPY 进 final image。
# ============================================================================
FROM node:24-slim AS docker-extract
COPY docker-29.4.0.tgz /tmp/docker.tgz
RUN tar xzf /tmp/docker.tgz --strip-components=1 -C /usr/local/bin docker/docker \
    && chmod +x /usr/local/bin/docker

# ============================================================================
# Final image —— 单段构建，npm globals + GSD 直接装到最终镜像里，
# 避免"builder 装了但 final 漏拷"的隐患。
# ============================================================================
FROM node:24-slim

ARG INSTALL_PROXY
ARG INSTALL_GO=0
ARG INSTALL_RUST=0

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
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl vim ca-certificates jq \
    python3 python3-pip \
    ripgrep fd-find tree unzip less \
    fzf bat sqlite3 make \
    openssh-client \
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
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache/pip

# --- 清华 npm 镜像 ---
RUN npm config set registry https://registry.npmmirror.com

# --- npm globals: Claude Code + TypeScript LSP + CodeGraph + ctx7 ---
# 直接装在 final image 层里 —— 无 builder 阶段，无"漏拷贝"风险
RUN npm install -g \
        @anthropic-ai/claude-code@latest \
        typescript-language-server typescript \
        @colbymchenry/codegraph \
        ctx7@latest \
    && codegraph telemetry off \
    && ln -sf ../lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe  /usr/local/bin/claude \
    && ln -sf ../lib/node_modules/@colbymchenry/codegraph/npm-shim.js     /usr/local/bin/codegraph \
    && ln -sf ../lib/node_modules/typescript/bin/tsc                      /usr/local/bin/tsc \
    && ln -sf ../lib/node_modules/typescript-language-server/lib/cli.mjs  /usr/local/bin/typescript-language-server \
    && ln -sf ../lib/node_modules/ctx7/dist/index.js                      /usr/local/bin/ctx7 \
    && rm -rf /root/.npm

# --- GSD: Get Shit Done workflow system ---
# 官方 installer 直接装到 /root/.claude；同层清理 npx cache
# GSD 输出的 settings.json 先存为临时文件，稍后与自定义配置合并
RUN npx --yes get-shit-done-cc@latest \
    && mv /root/.claude/settings.json /tmp/gsd-settings.json \
    && rm -rf /root/.npm/_npx /root/.npm/_cacache /root/.npm/_logs

# --- Docker CLI 二进制 ---
COPY --from=docker-extract /usr/local/bin/docker /usr/local/bin/docker

# --- docker compose (CLI plugin; not bundled in docker.tgz, not in trixie repo) ---
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -sSL --proxy "${INSTALL_PROXY}" -o /usr/local/lib/docker/cli-plugins/docker-compose \
        https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64 \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# --- Go runtime (可选：--build-arg INSTALL_GO=1) ---
# 从清华镜像拉 tarball，同层解压并清理，只留 /usr/local/go
ENV GOROOT=/usr/local/go
ENV PATH=$PATH:/usr/local/go/bin
RUN if [ "$INSTALL_GO" = "1" ]; then \
        curl -fsSL --proxy "${INSTALL_PROXY}" \
            -o /tmp/go.tgz \
            https://mirrors.aliyun.com/golang/go1.25.9.linux-amd64.tar.gz \
        && tar -C /usr/local -xzf /tmp/go.tgz \
        && rm /tmp/go.tgz ; \
    fi

# --- Rust toolchain (可选：--build-arg INSTALL_RUST=1) ---
# musl-tools/musl-dev/gcc/libc6-dev/pkg-config 只在装 Rust 时才需要
# rustup-init 走 USTC 镜像，toolchain + crates 走 SOCKS5 proxy
# 同层清理 cargo/rustup 缓存与文档
ENV PATH="/root/.cargo/bin:${PATH}"
RUN if [ "$INSTALL_RUST" = "1" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            musl-tools musl-dev \
            gcc libc6-dev pkg-config \
        && rm -rf /var/lib/apt/lists/* \
        && curl -sSf -o /tmp/rustup-init \
            https://mirrors.ustc.edu.cn/rust-static/rustup/dist/x86_64-unknown-linux-gnu/rustup-init \
        && chmod +x /tmp/rustup-init \
        && http_proxy="${INSTALL_PROXY}" https_proxy="${INSTALL_PROXY}" \
           /tmp/rustup-init -y --default-toolchain stable --no-modify-path \
        && rm /tmp/rustup-init \
        && . /root/.cargo/env \
        && http_proxy="${INSTALL_PROXY}" https_proxy="${INSTALL_PROXY}" \
           rustup target add x86_64-unknown-linux-musl \
        && http_proxy="${INSTALL_PROXY}" https_proxy="${INSTALL_PROXY}" \
           cargo install cargo-edit cargo-watch \
        && rm -rf /root/.cargo/registry/cache \
                  /root/.cargo/registry/src \
                  /root/.cargo/git \
                  /root/.rustup/toolchains/*/share/doc \
        && mkdir -p /root/.cargo \
        && printf '%s\n' \
            '[source.crates-io]' \
            "replace-with = 'rsproxy-sparse'" \
            '' \
            '[source.rsproxy-sparse]' \
            'registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"' \
            '' \
            '[net]' \
            'git-fetch-with-cli = true' \
            > /root/.cargo/config.toml ; \
    fi

# --- Git config ---
RUN git config --global user.email "dev@container" && \
    git config --global user.name "Dev"

# --- settings.json 合并：GSD installer 输出 + 自定义配置（覆盖叠加）---
COPY claude-user-config/settings.json /tmp/custom-settings.json
RUN jq -s '.[0] * .[1]' /tmp/gsd-settings.json /tmp/custom-settings.json \
        > /root/.claude/settings.json \
    && rm /tmp/gsd-settings.json /tmp/custom-settings.json

# --- User-level CLAUDE.md ---
COPY claude-user-config/CLAUDE.md /root/.claude/CLAUDE.md

# --- mattpocock/skills (stable only: engineering, productivity, misc) ---
RUN git -c http.proxy="${INSTALL_PROXY}" clone --depth 1 \
        https://github.com/mattpocock/skills.git /tmp/mattpocock-skills \
    && for dir in /tmp/mattpocock-skills/skills/engineering/* \
                  /tmp/mattpocock-skills/skills/productivity/* \
                  /tmp/mattpocock-skills/skills/misc/*; do \
           [ -d "$dir" ] && cp -r "$dir" /root/.claude/skills/; \
       done \
    && find /root/.claude/skills -name SKILL.md \
        -exec sed -i '/^disable-model-invocation: true$/d' {} + \
    && rm -rf /tmp/mattpocock-skills

WORKDIR /root

CMD ["tail", "-f", "/dev/null"]
