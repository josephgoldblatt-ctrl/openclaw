# Stage 1: grab just the whatsapp extension from 2026.3.13
FROM node:22-slim AS patcher
RUN npm pack openclaw@2026.3.13 --pack-destination /tmp && \
    cd /tmp && tar xzf openclaw-2026.3.13.tgz && rm openclaw-2026.3.13.tgz

# Stage 2: base image — only replace the broken whatsapp extension
FROM ghcr.io/openclaw/openclaw:main
USER root

# Replace ONLY the broken WhatsApp extension with 2026.3.13's version.
# The 2026.3.13 extension uses compiled plugin-sdk imports instead of
# raw ../../../src/ paths that don't exist in the Docker image.
# Keep everything else (dist, node_modules, package.json) at :main version.
COPY --from=patcher /tmp/package/extensions/whatsapp /app/extensions/whatsapp

# System dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ffmpeg \
      xvfb && \
    PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# gog CLI (Google Workspace)
RUN curl -sL "https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_linux_amd64.tar.gz" \
    -o /tmp/gog.tar.gz && \
    tar xzf /tmp/gog.tar.gz -C /usr/local/bin gog && \
    chmod +x /usr/local/bin/gog && \
    rm /tmp/gog.tar.gz

# Persistent volume symlinks
RUN mkdir -p /root/.config && \
    ln -sf /data/.config/gogcli /root/.config/gogcli

ENV PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
