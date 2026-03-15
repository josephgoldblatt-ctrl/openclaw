# Stage 1: grab the working 2026.3.13 package
FROM node:22-slim AS patcher
RUN npm pack openclaw@2026.3.13 --pack-destination /tmp && \
    cd /tmp && tar xzf openclaw-2026.3.13.tgz && rm openclaw-2026.3.13.tgz

# Stage 2: base image with fixes applied via COPY
FROM ghcr.io/openclaw/openclaw:main
USER root

# Replace broken extensions + matching dist from 2026.3.13
# This fixes the WhatsApp plugin which ships uncompiled TS in :main
COPY --from=patcher /tmp/package/extensions /app/extensions
COPY --from=patcher /tmp/package/dist /app/dist
COPY --from=patcher /tmp/package/openclaw.mjs /app/openclaw.mjs
COPY --from=patcher /tmp/package/package.json /app/package.json

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
