FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata wget gzip

# Default to linux-amd64 build. You can override via --build-arg MIHOMO_URLS="url1 url2 ..."
ARG MIHOMO_URLS="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.10/mihomo-linux-amd64-v3-v1.19.10.gz https://mirror.ghproxy.com/https://github.com/MetaCubeX/mihomo/releases/download/v1.19.10/mihomo-linux-amd64-v3-v1.19.10.gz https://ghproxy.net/https://github.com/MetaCubeX/mihomo/releases/download/v1.19.10/mihomo-linux-amd64-v3-v1.19.10.gz"

RUN set -eux; \
  ok=""; \
  for u in $MIHOMO_URLS; do \
    echo "Trying: $u"; \
    if wget -O /tmp/mihomo.gz "$u" && gzip -t /tmp/mihomo.gz 2>/dev/null; then \
      ok="yes"; \
      break; \
    fi; \
  done; \
  test -n "$ok"; \
  gzip -dc /tmp/mihomo.gz > /usr/local/bin/mihomo; \
  chmod +x /usr/local/bin/mihomo; \
  /usr/local/bin/mihomo -v >/dev/null

ENTRYPOINT ["/usr/local/bin/mihomo", "-f", "/config/config.yaml"]
