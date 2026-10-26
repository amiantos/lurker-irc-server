#!/usr/bin/env bash
# Print a bcrypt hash for an oper password (paste into ergo.env).
# Reads the password from the terminal, never from argv (it would land in
# shell history and `ps`).
set -euo pipefail
IMAGE="$(grep -oE 'ghcr.io/ergochat/ergo:[^ ]+' "$(dirname "${BASH_SOURCE[0]}")/../Dockerfile" | head -1)"
read -r -s -p "password: " pw; echo >&2
printf '%s\n' "$pw" | docker run --rm -i --entrypoint /ircd-bin/ergo "$IMAGE" genpasswd
