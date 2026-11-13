#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# VPS Initial Setup Script
# Run this ONCE on a fresh Ubuntu 22.04/24.04 VPS
# Usage: ssh root@your-vps "bash -s" < deploy/setup-vps.sh
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

echo "══════════════════════════════════════════"
echo "  Practice App — VPS Setup"
echo "══════════════════════════════════════════"

# ── System updates ─────────────────────────────────────────────
echo "→ Updating system packages..."
apt update && apt upgrade -y

# ── Install Docker ─────────────────────────────────────────────
echo "→ Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "  ✓ Docker installed"
else
    echo "  ✓ Docker already installed"
fi

# ── Install Docker Compose plugin ──────────────────────────────
echo "→ Ensuring Docker Compose plugin..."
if ! docker compose version &> /dev/null; then
    apt install -y docker-compose-plugin
    echo "  ✓ Docker Compose plugin installed"
else
    echo "  ✓ Docker Compose already available"
fi

# ── Firewall ───────────────────────────────────────────────────
echo "→ Configuring firewall..."
ufw allow OpenSSH
# No inbound web ports needed when using Cloudflare Tunnels!
ufw --force enable
echo "  ✓ Firewall configured (SSH only)"

echo ""
echo "══════════════════════════════════════════"
echo "  ✅ VPS setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Clone your repo to ~/practice (git clone <repo-url> ~/practice)"
echo "  2. Copy deploy/.env.production.example → deploy/.env.production"
echo "  3. Fill in your secrets in deploy/.env.production"
echo "  4. Run: ./deploy/deploy.sh"
echo "══════════════════════════════════════════"
