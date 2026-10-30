#!/usr/bin/env bash
# Copy Ergo's datastore (accounts + channel registrations; it is small) to
# /var/backups/lurker-irc, keep 30 days, and push to an rclone remote if
# RCLONE_REMOTE is set in ergo.env (e.g. r2:lurker-irc-backups).
#
# ⚠ This copies the LIVE file. Ergo's datastore is an append-only log; a copy
# taken mid-write can be truncated at the tail. The restore drill (RUNBOOK.md) must
# prove a copy LOADS before anyone relies on this. ircd.yaml is not backed up:
# it is rendered from git + ergo.env, and ergo.env is in the password manager.
set -euo pipefail
ROOT="${ROOT:-/opt/lurker-irc-server}"
DEST="/var/backups/lurker-irc"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DEST"
cp "$ROOT/data/ircd.db" "$DEST/ircd-$STAMP.db"
gzip -f "$DEST/ircd-$STAMP.db"
find "$DEST" -name 'ircd-*.db.gz' -mtime +30 -delete
if [ -f "$ROOT/ergo.env" ]; then set -a; . "$ROOT/ergo.env"; set +a; fi
if [ -n "${RCLONE_REMOTE:-}" ] && command -v rclone >/dev/null 2>&1; then
  rclone copy "$DEST/ircd-$STAMP.db.gz" "$RCLONE_REMOTE/" --quiet
fi
echo "backup ok: $DEST/ircd-$STAMP.db.gz"
