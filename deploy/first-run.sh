#!/usr/bin/env bash
# One-time bring-up on the droplet, after cloud-init and after ergo.env is
# filled in. Idempotent enough to re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="irc.lurker.chat"
cd "$ROOT"

[ -f ergo.env ] || { echo "ergo.env missing: cp ergo.env.example ergo.env and fill it in" >&2; exit 1; }
mkdir -p data/tls

# 1. Certificate. Port 80 is free (nothing else listens), so standalone HTTP-01.
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  certbot certonly --standalone --non-interactive --agree-tos \
    --preferred-challenges http -d "$DOMAIN" -m abuse@lurker.chat
fi
install -m 0755 deploy/install-ergo-certificates /etc/letsencrypt/renewal-hooks/deploy/install-ergo-certificates
/etc/letsencrypt/renewal-hooks/deploy/install-ergo-certificates

# 2. Config, then the container.
scripts/render.sh
docker compose build --pull
docker compose up -d

# 3. Nightly backup of the datastore at 04:10 UTC.
install -m 0755 deploy/backup.sh /usr/local/bin/lurker-irc-backup
echo '10 4 * * * root /usr/local/bin/lurker-irc-backup >> /var/log/lurker-irc-backup.log 2>&1' > /etc/cron.d/lurker-irc-backup

sleep 3
docker compose ps
echo
echo "Now: scripts/status.sh  (expects a 001 over TLS), then /OPER from a client."
