FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    unzip \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ttyd from GitHub releases (not in debian slim repos)
RUN TTYD_VERSION=1.7.7 && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
      -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Non-root user
RUN useradd -m -s /bin/bash sandbox

# Bake Claude Code settings pointing at the provider-proxy sidecar on localhost:3129.
# ANTHROPIC_AUTH_TOKEN carries the placeholder — the provider-proxy rewrites it with
# the real key before forwarding to the upstream LLM service.
RUN mkdir -p /home/sandbox/.claude && \
    cat > /home/sandbox/.claude/settings.json <<'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "placeholder:haiproxy",
    "ANTHROPIC_BASE_URL": "http://localhost:3129/anthropic/",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-latest",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-latest",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-latest",
    "ANTHROPIC_MODEL": "claude-sonnet-latest",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1"
  },
  "permissions": {
    "allow": ["Bash(*)", "Read(**)", "Write(**)", "Edit(**)", "WebFetch(*)", "WebSearch"]
  }
}
EOF
RUN chown -R sandbox:sandbox /home/sandbox/.claude

USER sandbox
WORKDIR /home/sandbox

EXPOSE 7681
CMD ["ttyd", "-p", "7681", "-W", "bash"]
