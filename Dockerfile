ARG OPENCLAW_EXTENSIONS=""
ARG OPENCLAW_VARIANT=default
ARG OPENCLAW_NODE_BOOKWORM_IMAGE="node:24-bookworm@sha256:3a09aa6354567619221ef6c45a5051b671f953f0a1924d1f819ffb236e520e6b"
ARG OPENCLAW_NODE_BOOKWORM_DIGEST="sha256:3a09aa6354567619221ef6c45a5051b671f953f0a1924d1f819ffb236e520e6b"

# ── Stage 1: Extension deps ────────────────────────────────────
FROM ${OPENCLAW_NODE_BOOKWORM_IMAGE} AS ext-deps
ARG OPENCLAW_EXTENSIONS
COPY extensions /tmp/extensions
RUN mkdir -p /out && \
    for ext in $OPENCLAW_EXTENSIONS; do \
      if [ -f "/tmp/extensions/$ext/package.json" ]; then \
        mkdir -p "/out/$ext" && \
        cp "/tmp/extensions/$ext/package.json" "/out/$ext/package.json"; \
      fi; \
    done

# ── Stage 2: Build ──────────────────────────────────────────────
FROM ${OPENCLAW_NODE_BOOKWORM_IMAGE} AS build

RUN set -eux; \
    for attempt in 1 2 3 4 5; do \
      if curl --retry 5 --retry-all-errors --retry-delay 2 -fsSL https://bun.sh/install | bash; then \
        break; \
      fi; \
      if [ "$attempt" -eq 5 ]; then \
        exit 1; \
      fi; \
      sleep $((attempt * 2)); \
    done
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches

COPY --from=ext-deps /out/ ./extensions/

# Railway: no BuildKit cache mounts
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

COPY . .

RUN for dir in /app/extensions /app/.agent /app/.agents; do \
      if [ -d "$dir" ]; then \
        find "$dir" -type d -exec chmod 755 {} +; \
        find "$dir" -type f -exec chmod 644 {} +; \
      fi; \
    done

RUN pnpm canvas:a2ui:bundle || \
    (echo "A2UI bundle: creating stub (non-fatal)" && \
     mkdir -p src/canvas-host/a2ui && \
     echo "/* A2UI bundle unavailable in this build */" > src/canvas-host/a2ui/a2ui.bundle.js && \
     echo "stub" > src/canvas-host/a2ui/.bundle.hash && \
     rm -rf vendor/a2ui apps/shared/OpenClawKit/Tools/CanvasA2UI)
RUN pnpm build:docker
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Prune dev dependencies
FROM build AS runtime-assets
RUN CI=true pnpm prune --prod && \
    find dist -type f \( -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' -o -name '*.map' \) -delete

# ── Stage 3: Runtime ────────────────────────────────────────────
FROM ${OPENCLAW_NODE_BOOKWORM_IMAGE}
ARG OPENCLAW_NODE_BOOKWORM_DIGEST
LABEL org.opencontainers.image.source="https://github.com/openclaw/openclaw" \
  org.opencontainers.image.title="OpenClaw" \
  org.opencontainers.image.description="OpenClaw gateway — Railway build"

WORKDIR /app

# Railway: no BuildKit cache mounts
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      procps hostname curl git lsof openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=runtime-assets /app/dist ./dist
COPY --from=runtime-assets /app/node_modules ./node_modules
COPY --from=runtime-assets /app/package.json .
COPY --from=runtime-assets /app/openclaw.mjs .
COPY --from=runtime-assets /app/extensions ./extensions
COPY --from=runtime-assets /app/skills ./skills
COPY --from=runtime-assets /app/docs ./docs

ENV COREPACK_HOME=/usr/local/share/corepack
RUN install -d -m 0755 "$COREPACK_HOME" && \
    corepack enable && \
    for attempt in 1 2 3 4 5; do \
      if corepack prepare "$(node -p "require('./package.json').packageManager")" --activate; then \
        break; \
      fi; \
      if [ "$attempt" -eq 5 ]; then \
        exit 1; \
      fi; \
      sleep $((attempt * 2)); \
    done && \
    chmod -R a+rX "$COREPACK_HOME"

# Install Chromium for browser automation
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
    mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -sf /app/openclaw.mjs /usr/local/bin/openclaw \
 && chmod 755 /app/openclaw.mjs

ENV NODE_ENV=production

HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
