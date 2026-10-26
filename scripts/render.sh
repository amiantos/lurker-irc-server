#!/usr/bin/env bash
# Render ergo/ircd.yaml.tmpl + ergo.env → data/ircd.yaml.
# Bash literal replacement, no sed/envsubst: bcrypt hashes and API keys carry
# $ / & and must land verbatim. Fails loudly on a missing or placeholder value.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ERGO_ENV:-$ROOT/ergo.env}"
OUT="${1:-$ROOT/data/ircd.yaml}"

[ -f "$ENV_FILE" ] || { echo "render: $ENV_FILE missing (copy ergo.env.example)" >&2; exit 1; }
set -a; . "$ENV_FILE"; set +a

VARS=(VPC_CIDR OPER_BRAD_HASH OPER_JAWSH_HASH RESEND_API_KEY)
for v in "${VARS[@]}"; do
  val="${!v:-}"
  case "$val" in
    ""|*replace*me*|*replace-me*) echo "render: $v is unset or still a placeholder in $ENV_FILE" >&2; exit 1;;
  esac
done

# bash ≥5.2 expands `&` in an unquoted replacement to the matched text (which
# would corrupt a secret containing &), and bash 3.2 (macOS) keeps the inner
# quotes of a quoted replacement literally. Turn the 5.2 behaviour off and
# substitute unquoted: identical, literal results on both.
shopt -u patsub_replacement 2>/dev/null || true
content="$(cat "$ROOT/ergo/ircd.yaml.tmpl")"
for v in "${VARS[@]}"; do
  rep="${!v}"
  content="${content//__${v}__/$rep}"
done
if grep -q '__[A-Z_]*__' <<<"$content"; then
  echo "render: unreplaced placeholder(s):" >&2
  grep -o '__[A-Z_]*__' <<<"$content" | sort -u >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
umask 077
printf '%s\n' "$content" > "$OUT"
# The MOTD rides along so a rehash picks up edits (see docker-compose.yml).
cp "$ROOT/ergo/ircd.motd" "$(dirname "$OUT")/ircd.motd"
echo "rendered $OUT (+ ircd.motd)"
