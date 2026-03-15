FROM ghcr.io/openclaw/openclaw:main
USER root

# Install system dependencies missing from the base image
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ffmpeg \
      xvfb && \
    PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install gog (Google Workspace CLI) for Gmail/Calendar/Drive/Sheets
RUN curl -sL "https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_linux_amd64.tar.gz" \
    -o /tmp/gog.tar.gz && \
    tar xzf /tmp/gog.tar.gz -C /usr/local/bin gog && \
    chmod +x /usr/local/bin/gog && \
    rm /tmp/gog.tar.gz

# Symlink configs from persistent volume
RUN mkdir -p /root/.config && \
    ln -sf /data/.config/gogcli /root/.config/gogcli

# Set Playwright browser path
ENV PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright

# Wrap openclaw binary to apply patches from /data volume before starting.
RUN mv /usr/local/bin/openclaw /usr/local/bin/openclaw-real && \
    printf '#!/bin/bash\nPATCH_DIR="/data/openclaw-patch/patch-files"\nMARKER="/tmp/.openclaw-patched"\nif [ ! -f "$MARKER" ] && [ -d "$PATCH_DIR/dist" ]; then\n  echo "[patch] Applying OpenClaw patch from /data volume..."\n  cp -f "$PATCH_DIR/openclaw.mjs" /app/openclaw.mjs 2>/dev/null\n  cp -f "$PATCH_DIR/package.json" /app/package.json 2>/dev/null\n  rm -rf /app/dist && cp -r "$PATCH_DIR/dist" /app/dist\n  rm -rf /app/extensions && cp -r "$PATCH_DIR/extensions" /app/extensions\n  touch "$MARKER"\n  echo "[patch] Done."\nfi\nexec /usr/local/bin/openclaw-real "$@"\n' > /usr/local/bin/openclaw && \
    chmod +x /usr/local/bin/openclaw

# Force Docker to use our wrapper as PID 1 (base image ENTRYPOINT gets cached)
ENTRYPOINT ["/usr/local/bin/openclaw"]
