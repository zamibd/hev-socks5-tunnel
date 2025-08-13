# Stage 1: Build the binary
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --update --no-cache \
    make \
    git \
    gcc \
    linux-headers \
    musl-dev \
    lwip-dev # ✅ Add lwIP headers (if available in Alpine)

# Set working directory
WORKDIR /src

# Copy source code
COPY . /src

# Optional: Ensure submodules are initialized if lwIP is embedded
RUN [ -d .git ] && git submodule update --init --recursive || echo "No .git directory found"

# Build the binary
RUN make

# Stage 2: Runtime image
FROM alpine:latest

# Install runtime dependencies
RUN apk add --update --no-cache \
    iproute2

# Environment variables (non-sensitive)
ENV TUN=tun0 \
    MTU=8500 \
    IPV4=198.18.0.1 \
    IPV6='' \
    TABLE=20 \
    MARK=438 \
    SOCKS5_ADDR=172.17.0.1 \
    SOCKS5_PORT=99 \
    SOCKS5_USERNAME='' \ 
    SOCKS5_UDP_MODE=udp \
    CONFIG_ROUTES=1 \
    IPV4_INCLUDED_ROUTES=0.0.0.0/0 \
    IPV4_EXCLUDED_ROUTES='' \
    LOG_LEVEL=warn

# Use ARG for secrets to avoid baking them into layers
ARG SOCKS5_PASSWORD
ENV SOCKS5_PASSWORD=$SOCKS5_PASSWORD

# Healthcheck
HEALTHCHECK --start-period=5s --interval=5s --timeout=2s --retries=3 \
    CMD ["test", "-f", "/success"]

# Copy entrypoint and binary
COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh
COPY --from=builder /src/bin/hev-socks5-tunnel /usr/bin/hev-socks5-tunnel

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
