# lurker-irc-server

The config and runbook for **irc.lurker.chat**, the Lurker community's IRC network: one
[Ergo](https://ergo.chat) with every IRCv3 feature switched on. Why it exists and what was
decided is in [DECISIONS.md](DECISIONS.md); this file is the how.

- `ergo/ircd.yaml.tmpl` is the whole configuration. Every departure from Ergo's default is
  commented with a why. `scripts/render.sh` fills the `__PLACEHOLDERS__` from `ergo.env`
  (gitignored) and writes `data/ircd.yaml`. Edit the template, never the rendered file.
- `docker-compose.yml` runs the image `Dockerfile` builds: stock Ergo at a pinned tag plus
  the ergo-dnsbl plugin. `data/` holds the rendered config, the DNSBL policy, the datastore
  (`ircd.db`: accounts and channel registrations) and `tls/`.
- No message history, no always-on (bouncer) mode, no coupling to lurker.chat accounts.
  Those are decisions, not omissions.

## Bring-up

1. `deploy/provision.sh` from a workstation with `doctl` and the hosted fleet's secrets
   (`DO_REGION`, `DO_PROJECT_ID`, `SSH_KEY_FINGERPRINTS`, `ADMIN_IP`) exported. It creates the `lurker-irc` tag and firewall and a 1 GB droplet in the `lurker`
   VPC, IPv6 enabled, with `deploy/cloud-init.sh` as user-data (Docker, certbot, swap). It
   prints the public IPv4 and IPv6, the VPC IP, and the VPC CIDR for `ergo.env`.
2. DNS: `irc.lurker.chat A <ipv4>` and `AAAA <ipv6>`. Wait for both to resolve.
3. On the droplet: clone this repo to `/opt/lurker-irc-server`, `cp ergo.env.example ergo.env`,
   fill it in. Oper hashes come from `scripts/genpasswd.sh`; the Resend key is a separate,
   sending-only key for this server; `VPC_CIDR` from step 1.
4. `deploy/first-run.sh`: Let's Encrypt cert via standalone HTTP-01, the renewal deploy hook
   (copies the cert into `data/tls` and rehashes, no disconnect), render, `compose up`, and
   the nightly backup cron.
5. `scripts/status.sh` should print a `001` and the cert expiry. Then `/OPER brad <password>`.

## Day to day

| Want to | Run | Disconnects anyone? |
|---|---|---|
| Change config or the MOTD | edit, commit, `scripts/rehash.sh` | No |
| Renew the cert | nothing; certbot's timer + the deploy hook | No |
| Upgrade Ergo or the DNSBL plugin | bump the tag or commit in `Dockerfile`, commit, `scripts/update.sh` | **Yes, everyone.** Announce it, off-peak. |
| Change the DNSBL policy | edit `ergo/dnsbl.yaml`, commit, `scripts/rehash.sh` | No. The plugin reads its file on every check. |
| Add an oper | add a block to the template + a hash to `ergo.env`, `scripts/rehash.sh` | No |
| Check it from outside | `scripts/status.sh` | No |

Ergo logs which settings a rehash could not apply; those need `update.sh`.

## Oper notes

- **Ban `ident@host`, never `*@host`.** Cloaks are derived from the IP, so every user on
  one hosted lurker.chat cell shares a host. Their idents differ (`lu12`, `lu40`: the cells
  answer identd and this server asks). `*!lu12@*` is one person; `*!*@thatcloak` is the whole
  cell, and a DLINE is worse. `+R` for drive-by spam.
- Nick enforcement is strict and a nick equals its account: a registered nick is its
  owner's, an unauthenticated holder is renamed to `Guest-*`, and anyone logged in is
  renamed to their account name and cannot `/nick` away from it. So a name in `+b`, `+I`
  or a ChanServ `AMODE` is one specific account.
- Vhosts: `/msg HostServ HELP`. There is no self-service; an oper sets them.
- **Every connecting IP is checked against DroneBL, the EFnet RBL and the Tor exit list**
  (`ergo/dnsbl.yaml`). Listed drones and proxies are refused with a message naming the list;
  Tor exits may connect only with SASL. Hosted cells arrive over the VPC and are never
  listed. Someone wrongly refused writes to abuse@; the lists have their own removal pages.
  Check a specific address from the droplet:
  `echo '{"ip":"1.2.3.4"}' | docker exec -i ergo /ircd-bin/ergo-dnsbl /ircd/dnsbl.yaml`
- `/REHASH` from a client is the same as `scripts/rehash.sh` minus the re-render, so only
  use it after someone has already rendered.

## Backups and the restore drill

`deploy/backup.sh` copies `data/ircd.db` nightly to `/var/backups/lurker-irc` (30 days) and
to `RCLONE_REMOTE` if set in `ergo.env`. It copies the live file, and Ergo's datastore is an
append-only log, so **before launch, prove a copy loads**: on a scratch machine, render a
config, put a backup in place as `data/ircd.db`, start the container, and `/msg NickServ INFO`
a known account. Repeat after any Ergo upgrade that touches the schema.

## Not in this repo

- The hosted cells resolving `irc.lurker.chat` to the VPC IP (`extra_hosts`, written by the
  hosted service's cell provisioning, which is not public).
- The picker entry and first-party pin in [lurker](https://github.com/amiantos/lurker)
  (`builtinNetworks.json` / `.ts`).
- The bridge: one `networks` entry and one `lurker` room member in
  [snitch](https://github.com/amiantos/snitch).

## License

[MPL-2.0](LICENSE), like Lurker. The config template started from Ergo's `default.yaml` (MIT).
