FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata wget gzip

# Default to linux-amd64 build. Override with --build-arg MIHOMO_URL=... if needed.
ARG MIHOMO_URL="https://ghproxy.com/https://github.com/MetaCubeX/mihomo/releases/download/v1.19.10/mihomo-linux-amd64-v3-v1.19.10.gz"

RUN wget -O /tmp/mihomo.gz "$MIHOMO_URL" \
 && gunzip /tmp/mihomo.gz \
 && mv /tmp/mihomo /usr/local/bin/mihomo \
 && chmod +x /usr/local/bin/mihomo

ENTRYPOINT ["/usr/local/bin/mihomo", "-f", "/config/config.yaml"]
