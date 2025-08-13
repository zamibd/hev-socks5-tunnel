# -------------------------------
# Stage 1: Build the binary
# -------------------------------
    FROM alpine:latest AS builder

    # Install build dependencies
    RUN apk add --update --no-cache \
        make \
        git \
        gcc \
        linux-headers \
        musl-dev
    
    # Set working directory
    WORKDIR /src
    
    # Clone lwIP from official repo
    RUN git clone --depth=1 https://git.savannah.nongnu.org/git/lwip.git /lwip
    
    # Copy your source code into build context
    COPY . /src
    
    # Export lwIP headers for compilation
    ENV CFLAGS="-I/lwip/src/include -I/lwip/src/include/ipv4"
    
    # Optional: Initialize submodules if your project uses them
    RUN [ -d .git ] && git submodule update --init --recursive || echo "No submodules to init"
    
    # Build your binary (assumes Makefile honors CFLAGS)
    RUN make
    
    # -------------------------------
    # Stage 2: Runtime image
    # -------------------------------
    FROM alpine:latest
    
    # Install runtime dependencies
    RUN apk add --update --no-cache iproute2
    
    # Healthcheck to verify container readiness
    HEALTHCHECK --start-period=5s --interval=5s --timeout=2s --retries=3 \
        CMD ["test", "-f", "/success"]
    
    # Copy entrypoint and built binary from builder stage
    COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh
    COPY --from=builder /src/bin/hev-socks5-tunnel /usr/bin/hev-socks5-tunnel
    
    # Entrypoint script
    ENTRYPOINT ["/entrypoint.sh"]
    