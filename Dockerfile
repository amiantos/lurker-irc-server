# irc.lurker.chat image: stock Ergo plus the ergo-dnsbl IP-check plugin, which
# Ergo calls for every connecting IP (server.ip-check-script in the config).
# The plugin is pinned to a commit; bump deliberately, like the Ergo tag.
FROM docker.io/golang:1.23-alpine AS dnsbl
RUN apk add --no-cache git
ARG ERGO_DNSBL_COMMIT=3e66d083e859c5ac36d826db3b381ab509d461b7
RUN git clone https://github.com/ergochat/ergo-dnsbl.git /src \
 && cd /src && git checkout "${ERGO_DNSBL_COMMIT}" \
 && CGO_ENABLED=0 go build -mod=vendor -o /ergo-dnsbl .

# Keep this tag in step with the comment in docker-compose.yml.
FROM ghcr.io/ergochat/ergo:v2.19.1
COPY --from=dnsbl /ergo-dnsbl /ircd-bin/ergo-dnsbl
