# Why irc.lurker.chat exists, and what was decided

Decided 2026-10-26, live since the same day. The config in `ergo/ircd.yaml.tmpl` comments
each setting with its reason; this is the layer above that.

## Why

1. **No public network runs the IRCv3 feature set Lurker supports.** Reactions, replies,
   multiline, metadata and avatars, typing, read markers: Lurker users only ever saw them
   work against each other on networks that happen to pass the tags through. A first-party
   server turns everything on.
2. **Lurker regulars wanted somewhere that isn't Libera.** `#lurker` lives here, bridged to
   Libera and MansionNET by [snitch](https://github.com/amiantos/snitch) so nobody is cut off.
3. **First run on hosted Lurker was bad.** A new lurker.chat user was pointed at Libera, which
   refuses unauthenticated connections from datacenter IPs. First contact was a disconnect and
   a SASL lecture. With irc.lurker.chat first in the picker, first contact is a channel with
   people in it.

## The four decisions

### 1. Ergo, run as a plain ircd

- **No linking, no netsplits.** Ergo scales up, not out. One box is the whole network, so a
  version upgrade disconnects everyone. Lurker users reconnect on their own; third-party
  clients see a blip. Upgrades are announced and done off-peak.
- **Not a bouncer.** `always-on` is disabled. Lurker already is the always-connected client;
  Ergo's bouncer mode would duplicate it and add held nicks and storage to babysit.
  `multiclient` is enabled only because Ergo requires it for `force-nick-equals-account`, and
  it is per-user opt-in.
- **Everything on.** metadata, relaymsg, multiline, setname, chghost, SCRAM, channel-rename,
  message-redaction, bot-mode, standard-replies. Several of these Lurker does not handle yet.
  That is the point: a bug that only shows against a fully-featured server should show here.
- **No message history.** Lurker keeps its own and never consumed upstream CHATHISTORY, so
  Ergo's would serve only third-party clients, and the cost is holding other people's messages.
  Off also removes retention questions wholesale.
- Alternatives (Solanum, UnrealIRCd, InspIRCd, ngIRCd) lose on IRCv3 coverage or need
  external services.

### 2. It is the community home, not a QA box

That means two human opers, each with their own block and nothing shared; a `chat-moderator`
class for trusted regulars; an `abuse@lurker.chat` that a human reads; nightly backups of the
datastore, because registered nicks and channels are people's identities now; and rehash for
config and cert changes so nobody is dropped for those.

### 3. Independent accounts, plain NickServ

Any IRC client works normally. No coupling to lurker.chat accounts: Ergo's `auth-script`,
`jwt-auth` and `oauth2` could make a lurker.chat login an IRC account, but that ties the server
to the hosted service and gives self-hosters and third-party clients nothing. Hosted users get
nothing special.

| Setting | Why |
|---|---|
| Registration open, email verification on | A community home cannot have closed registration. Verification is the single biggest spam lever, and gives password reset. |
| Registration throttle 10 per 10 min, bcrypt cost 10 | Ergo's defaults (30, and cost 4, the library minimum) are for bigger networks. |
| Nick reservation `strict`, nick equals account | A registered nick is its owner's. An unauthenticated holder becomes `Guest-*`. A logged-in user is their account name, so a name in `+b`, `+I`, `+e` or a ChanServ `AMODE` is one specific account. Cost: a Lurker user whose nick differs from their account is renamed on connect, and grouped alternates are unusable. |
| `check-ident: true`, no coercion | See cloaks below. Ergo's default throws the ident away. |
| `require-sasl: false` | A wall at the door is hostile to first contact. Channel `+R` if spam arrives. |
| DNSBL on every connecting IP | DroneBL and the EFnet RBL refuse known drones and proxies; Tor exits may connect with SASL. Added after someone pointed out the certificate transparency log had already announced the host. |
| Vhosts on | Opers can grant them. Ergo has no self-service. |

### 4. Its own box, TLS only

- One small droplet in the hosted fleet's private network, same region as the hosted Lurker
  cells. Not a cell, not co-located with anything else.
- **TLS only on 6697**, plus a native WebSocket listener for browser clients. No plaintext
  port, so no STS either: there is nothing to upgrade from, and a sticky policy is a trap if a
  cert ever goes bad.
- **Hosted cells reach it over the private network.** A cell is one public IP carrying many
  users, and Ergo allows 16 concurrent connections per IP by default. The private range is
  exempt from that cap, and each cell resolves `irc.lurker.chat` to the private address.

### Cloaks: a cell is one host, idents tell users apart

Ergo derives the cloak from the IP, so every user on one hosted cell shares a cloaked host.
What separates them is the ident: cells answer identd with a per-user `lu<id>`, so two hosted
users are `lu12@cloak` and `lu40@cloak`. Hence **ops ban `ident@host`, never `*@host`**, which
is why `check-ident` is on and why that rule is in the runbook's oper notes.

WEBIRC from the cells would give each hosted user their own cloak. Not needed while idents do
the job, and it would be the first hosted-only privilege.

## Not now, maybe later

- **RELAYMSG for the bridge.** Ergo lets a chanop bot present bridged users as distinct
  `nick/libera` nicks instead of an envelope. snitch does not speak it yet.
- **`draft/account-registration`.** Lurker implementing it would let first run register the
  nick inline on any network that offers the cap. A Lurker feature, not a server one.
- **Lurker gaps this server exposes:** channel renames, message redaction, standard-replies,
  setname, bot-mode. Filed against Lurker as regulars hit them.
