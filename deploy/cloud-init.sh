#!/usr/bin/env bash
# cloud-init user-data for the irc.lurker.chat droplet (Ubuntu 24.04).
# Prerequisites only: Docker, certbot, swap, the checkout directory. It holds no
# secrets, so the repo can be cloned by hand afterwards (deploy/first-run.sh).
set -euo pipefail
exec > >(tee -a /var/log/lurker-irc-init.log) 2>&1
log() { echo "[$(date -u +%FT%TZ)] $*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates git certbot unattended-upgrades

# Swap: a 1 GB droplet survives an apt + docker pull spike with it, not without.
if ! swapon --show | grep -q swapfile; then
  log "Adding 1G swap"
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker via the official convenience script."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
fi
systemctl enable --now docker

mkdir -p /opt/lurker-irc-server
log "Prerequisites ready. Next: clone the repo into /opt/lurker-irc-server and run deploy/first-run.sh"
