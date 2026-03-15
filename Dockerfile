FROM ghcr.io/openclaw/openclaw:2026.3.13
USER root

# Install gog (Google Workspace CLI) for Gmail/Calendar/Drive/Sheets
RUN curl -sL "https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_linux_amd64.tar.gz" \
    -o /tmp/gog.tar.gz && \
    tar xzf /tmp/gog.tar.gz -C /usr/local/bin gog && \
    chmod +x /usr/local/bin/gog && \
    rm /tmp/gog.tar.gz

# Symlink gog config from persistent volume
RUN mkdir -p /root/.config && \
    ln -sf /data/.config/gogcli /root/.config/gogcli
