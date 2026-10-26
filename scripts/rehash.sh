#!/usr/bin/env bash
# Config-only change: re-render and SIGHUP Ergo. Reloads config, the MOTD and
# TLS certificates WITHOUT disconnecting anyone. Listener changes and a few
# others need a restart (scripts/update.sh); Ergo logs which.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/render.sh"
docker kill -s HUP ergo
sleep 1
docker logs --since 10s ergo 2>&1 | tail -n 5
