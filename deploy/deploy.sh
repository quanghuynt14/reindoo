#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Deploy Script — Run on VPS from the project root
# Usage: ./deploy/deploy.sh
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "══════════════════════════════════════════"
echo "  Practice App — Deploy"
echo "══════════════════════════════════════════"

# ── Pre-flight checks ─────────────────────────────────────────
if [ ! -f deploy/.env.production ]; then
    echo "❌ deploy/.env.production not found!"
    echo "   Copy deploy/.env.production.example → deploy/.env.production"
    echo "   and fill in your secrets."
    exit 1
fi

# Load REDIS_PASSWORD for docker-compose
set -a
source deploy/.env.production
set +a

# ── Pull latest code ──────────────────────────────────────────
echo "→ Pulling latest code..."
git pull origin main

# ── Build and start containers ─────────────────────────────────
echo "→ Building Docker images..."
docker compose build

echo "→ Starting services..."
docker compose up -d

# ── Health check ──────────────────────────────────────────────
echo ""
echo "→ Waiting for API to start..."
sleep 5

if curl -sf http://localhost:3210/health > /dev/null 2>&1; then
    echo "  ✓ API is healthy!"
else
    echo "  ⚠️  API not responding yet. Check logs:"
    echo "     docker compose logs api"
fi

echo ""
echo "══════════════════════════════════════════"
echo "  ✅ Deployment complete!"
echo ""
echo "  Useful commands:"
echo "    docker compose logs -f api       # API logs"
echo "    docker compose logs -f worker    # Worker logs"
echo "    docker compose ps                # Service status"
echo "    docker compose restart api       # Restart API"
echo "    ./deploy/deploy.sh               # Redeploy"
echo "══════════════════════════════════════════"
