# ── Stage 1: Build ──────────────────────────────────────────────
FROM node:24-slim AS builder

# Enable pnpm via corepack
RUN corepack enable && corepack prepare pnpm@10.18.3 --activate

WORKDIR /app

# Copy workspace config files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml lerna.json tsconfig.base.json ./

# Copy only the packages needed for the server
COPY packages/shared/package.json packages/shared/tsconfig.json ./packages/shared/
COPY packages/task-service/package.json packages/task-service/tsconfig.json ./packages/task-service/
COPY packages/server/package.json packages/server/tsconfig.json packages/server/tsconfig.base.json packages/server/tsconfig.src.json ./packages/server/
COPY packages/eslint-config/package.json ./packages/eslint-config/

# Install dependencies (frozen lockfile for reproducibility)
RUN pnpm install --frozen-lockfile

# Copy source code for build
COPY packages/shared/src ./packages/shared/src
COPY packages/task-service/src ./packages/task-service/src
COPY packages/server/src ./packages/server/src
COPY packages/eslint-config/ ./packages/eslint-config/

# Build all packages (shared → task-service → server)
RUN pnpm build

# ── Stage 2: Production ────────────────────────────────────────
FROM node:24-slim AS production

RUN corepack enable && corepack prepare pnpm@10.18.3 --activate

WORKDIR /app

# Copy workspace config
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml lerna.json ./

# Copy package.json for each workspace package
COPY packages/shared/package.json ./packages/shared/
COPY packages/task-service/package.json ./packages/task-service/
COPY packages/server/package.json ./packages/server/
COPY packages/eslint-config/package.json ./packages/eslint-config/

# Install production dependencies only
RUN pnpm install --frozen-lockfile --prod

# Copy built output from builder
COPY --from=builder /app/packages/shared/dist ./packages/shared/dist
COPY --from=builder /app/packages/task-service/dist ./packages/task-service/dist
COPY --from=builder /app/packages/server/dist ./packages/server/dist

# Don't run as root
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser
USER appuser

EXPOSE 3210

# Default: start the API server
CMD ["node", "packages/server/dist/index.js"]
