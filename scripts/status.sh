#!/usr/bin/env bash
# Is it up, and does a TLS client get a 001? Run anywhere.
set -euo pipefail
HOST="${1:-irc.lurker.chat}"
# coreutils timeout is absent on macOS; run unbounded there.
if command -v timeout >/dev/null 2>&1; then T="timeout 15"; else T=""; fi
docker compose -f "$(dirname "${BASH_SOURCE[0]}")/../docker-compose.yml" ps 2>/dev/null || true
# Keep stdin open long enough for the 001 to arrive; a closed pipe makes
# s_client exit before the server has answered.
# Capture first, grep after: with pipefail, grep -m1 closing the pipe early
# would mark a successful probe as failed.
reply="$( (printf 'NICK statusprobe\r\nUSER s 0 * :s\r\n'; sleep 3; printf 'QUIT\r\n'; sleep 1) \
  | $T openssl s_client -quiet -connect "$HOST:6697" -servername "$HOST" 2>/dev/null || true)"
grep -m1 ' 001 ' <<<"$reply" || { echo "no 001 from $HOST:6697" >&2; exit 1; }
echo | $T openssl s_client -connect "$HOST:6697" -servername "$HOST" 2>/dev/null \
  | openssl x509 -noout -enddate
