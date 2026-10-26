#!/usr/bin/env bash
# Pull the pinned image (bump it in docker-compose.yml first) and restart.
# ⚠ One box is the network: this DISCONNECTS EVERYONE. Announce it, do it
# off-peak. Lurker users reconnect on their own; other clients see a blip.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
git pull --ff-only
"$ROOT/scripts/render.sh"
"$ROOT/deploy/backup.sh"
docker compose pull
docker compose up -d
docker compose ps
