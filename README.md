# irc.lurker.chat

The Lurker community's IRC network: one [Ergo](https://ergo.chat) server with every IRCv3
feature switched on, run by the people who make [Lurker](https://lurker.chat). This repo is
its configuration.

## Connecting

| | |
|---|---|
| Server | `irc.lurker.chat`, port 6697, TLS only |
| WebSocket | `wss://irc.lurker.chat` for browser clients |
| Channels | `#lobby` to hang out. `#lurker` is for Lurker itself: support and the project, bridged to Libera |
| Register | `/msg NickServ REGISTER <password> <email>`, then verify the email |
| Rules | The [Lurker code of conduct](https://github.com/amiantos/lurker/blob/main/CODE_OF_CONDUCT.md) applies. No spam, no bots without asking an oper |
| Abuse | abuse@lurker.chat |

In Lurker it is the first entry in the network picker. Any IRC client works.

What you get: metadata and avatars, reactions, replies, multiline, typing, read markers,
channel rename, message redaction. What you don't: message history, a plaintext port,
or a bouncer. A registered nick is its owner's, and once logged in your nick is your account
name. [DECISIONS.md](DECISIONS.md) says why.

## This repo

- `ergo/ircd.yaml.tmpl` is the whole configuration. Every departure from Ergo's default is
  commented with a why. `scripts/render.sh` fills the `__PLACEHOLDERS__` from `ergo.env`
  (gitignored) and writes `data/ircd.yaml`.
- `ergo/dnsbl.yaml` is the DNSBL policy: known drones and proxies are refused, Tor exits
  need SASL. `ergo/ircd.motd` is the MOTD.
- `Dockerfile` and `docker-compose.yml` build and run stock Ergo at a pinned tag plus the
  [ergo-dnsbl](https://github.com/ergochat/ergo-dnsbl) plugin.
- `deploy/` and `scripts/` are the operator's tools. [RUNBOOK.md](RUNBOOK.md) is how to use
  them.

## License

[MPL-2.0](LICENSE), like Lurker. The config template started from Ergo's `default.yaml` (MIT).
