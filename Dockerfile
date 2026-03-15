FROM ghcr.io/openclaw/openclaw:2026.3.13
USER root

# Install system dependencies missing from the base image
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ffmpeg \
      xvfb && \
    # Install Playwright Chromium + system deps
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
