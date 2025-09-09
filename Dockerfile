# Use the official Elixir Alpine image for M4 Mac compatibility
FROM hexpm/elixir:1.15.7-erlang-26.2.5.2-alpine-3.18.6

# Install build dependencies and runtime dependencies including Python for ChromaDB
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    python3 \
    py3-pip \
    sqlite \
    poppler-utils \
    ca-certificates \
    openssl \
    supervisor \
    && rm -rf /var/cache/apk/*

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000
ENV PHX_SERVER=true
ENV CHROMA_HOST=localhost
ENV CHROMA_PORT=8000

# Create app directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install ChromaDB
RUN pip3 install --no-cache-dir chromadb==0.4.24

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy assets
COPY assets assets
COPY priv priv

# Copy source code
COPY lib lib
COPY config config

# Install assets dependencies and build assets
RUN cd assets && npm ci --only=production
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Create directories for data and logs
RUN mkdir -p /app/data /app/chroma_data /var/log/supervisor && \
    chmod 755 /app/data /app/chroma_data

# Copy configuration files
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /app/docker-entrypoint.sh

# Expose only Phoenix port (ChromaDB runs internally)
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Set entrypoint
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]