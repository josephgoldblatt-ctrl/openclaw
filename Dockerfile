FROM ghcr.io/openclaw/openclaw:main
USER root

# ── Fix broken WhatsApp extension in :main image ──────────────────────
# The :main tag ships uncompiled TS extensions that reference /app/src/
# which doesn't exist. Replace with compiled 2026.3.13 versions at build time.
RUN npm pack openclaw@2026.3.13 --pack-destination /tmp && \
    cd /tmp && tar xzf openclaw-2026.3.13.tgz && \
    rm -rf /app/extensions && cp -r /tmp/package/extensions /app/extensions && \
    rm -rf /app/dist && cp -r /tmp/package/dist /app/dist && \
    cp /tmp/package/package.json /app/package.json && \
    cp /tmp/package/openclaw.mjs /app/openclaw.mjs && \
    rm -rf /tmp/package /tmp/openclaw-2026.3.13.tgz

# ── System dependencies ──────────────────────────────────────────────
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ffmpeg \
      xvfb && \
    PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── gog CLI (Google Workspace) ───────────────────────────────────────
RUN curl -sL "https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_linux_amd64.tar.gz" \
    -o /tmp/gog.tar.gz && \
    tar xzf /tmp/gog.tar.gz -C /usr/local/bin gog && \
    chmod +x /usr/local/bin/gog && \
    rm /tmp/gog.tar.gz

# ── Persistent volume symlinks ───────────────────────────────────────
RUN mkdir -p /root/.config && \
    ln -sf /data/.config/gogcli /root/.config/gogcli

ENV PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
