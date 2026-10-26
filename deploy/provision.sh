#!/usr/bin/env bash
# Create the irc.lurker.chat droplet in the hosted fleet's VPC with doctl.
# Mirrors lurker-control-plane/deploy/provision-cell.sh conventions.
#
# Needs (env or exported from the CP's cp.secrets.env): DO_REGION, DO_PROJECT_ID,
# SSH_KEY_FINGERPRINTS, ADMIN_IP. Optional: VPC_NAME (lurker), IRC_SIZE
# (s-1vcpu-1gb), IRC_IMAGE (ubuntu-24-04-x64), DROPLET_NAME (irc.lurker.chat).
set -euo pipefail
say() { printf '\n==> %s\n' "$*"; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${DO_REGION:?set DO_REGION (same region as the cells)}"
: "${DO_PROJECT_ID:?set DO_PROJECT_ID}"
: "${SSH_KEY_FINGERPRINTS:?set SSH_KEY_FINGERPRINTS}"
: "${ADMIN_IP:?set ADMIN_IP (SSH is allowed from this address only)}"
VPC_NAME="${VPC_NAME:-lurker}"
IRC_SIZE="${IRC_SIZE:-s-1vcpu-1gb}"
IRC_IMAGE="${IRC_IMAGE:-ubuntu-24-04-x64}"
DROPLET_NAME="${DROPLET_NAME:-irc.lurker.chat}"
TAG="lurker-irc"

VPC_ID="$(doctl vpcs list --format Name,ID --no-header | awk -v n="$VPC_NAME" '$1==n{print $2}')"
[ -n "$VPC_ID" ] || { echo "VPC '${VPC_NAME}' not found."; exit 1; }
VPC_CIDR="$(doctl vpcs get "$VPC_ID" --format IPRange --no-header)"
say "VPC ${VPC_NAME} (${VPC_ID}) ${VPC_CIDR}"

doctl compute tag get "$TAG" >/dev/null 2>&1 || { say "Creating tag ${TAG}"; doctl compute tag create "$TAG" >/dev/null; }

# Firewall: IRC + WebSocket from anywhere, 80 for certbot's HTTP-01 renewals,
# SSH from the admin address. Nothing else listens.
OUTBOUND="protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0"
INBOUND="protocol:tcp,ports:6697,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:443,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:80,address:0.0.0.0/0,address:::/0 protocol:tcp,ports:22,address:${ADMIN_IP}"
FW_ID="$(doctl compute firewall list --format Name,ID --no-header | awk -v n="$TAG" '$1==n{print $2}')"
if [ -n "$FW_ID" ]; then say "Reusing firewall ${TAG} (${FW_ID})"; else
  say "Creating firewall ${TAG}"
  doctl compute firewall create --name "$TAG" --tag-names "$TAG" --inbound-rules "$INBOUND" --outbound-rules "$OUTBOUND" >/dev/null
fi

if doctl compute droplet list --format Name --no-header | grep -qx "$DROPLET_NAME"; then
  say "Droplet ${DROPLET_NAME} already exists; leaving it alone."; exit 0
fi

say "Creating ${DROPLET_NAME} (${IRC_SIZE}) in ${DO_REGION}, VPC ${VPC_NAME}"
doctl compute droplet create "$DROPLET_NAME" \
  --region "$DO_REGION" --size "$IRC_SIZE" --image "$IRC_IMAGE" \
  --vpc-uuid "$VPC_ID" --tag-names "$TAG" --project-id "$DO_PROJECT_ID" \
  --ssh-keys "$SSH_KEY_FINGERPRINTS" \
  --user-data-file "${SCRIPT_DIR}/cloud-init.sh" --wait

PUB="$(doctl compute droplet get "$DROPLET_NAME" --format PublicIPv4 --no-header)"
PRIV="$(doctl compute droplet get "$DROPLET_NAME" --format PrivateIPv4 --no-header)"
cat <<DONE

${DROPLET_NAME} is up.  public=${PUB}  vpc=${PRIV}

  1. DNS:  irc.lurker.chat  A → ${PUB}   (and AAAA if you enable IPv6)
           Wait for it to resolve before step 3: certbot needs it.
  2. ssh root@${PUB}
       git clone <this repo> /opt/lurker-irc-server
       cd /opt/lurker-irc-server && cp ergo.env.example ergo.env
       # fill ergo.env; VPC_CIDR=${VPC_CIDR}; hashes from scripts/genpasswd.sh
  3. deploy/first-run.sh     (cert, deploy hook, render, up, backups)

Cells reach it privately at ${PRIV}: that is the extra_hosts value for
cell-cloud-init.sh (phase 3 in IRC_SERVER_PLAN.md).
DONE
