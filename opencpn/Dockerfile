# ===== Stage 1: Build OpenCPN from source =====
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies for OpenCPN
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        pkg-config \
        gettext \
        git \
        wget \
        curl \
        ca-certificates \
        unzip \
        tar \
        libwxgtk3.2-dev \
        libglu1-mesa-dev \
        libsqlite3-dev \
        libtinyxml2-dev \
        libcurl4-openssl-dev \
        libgtk-3-dev \
        libglew-dev \
        zlib1g-dev \
        libbz2-dev \
        libexpat1-dev && \
    rm -rf /var/lib/apt/lists/*

# Run dependency checker inline
RUN echo '#!/bin/bash\n' \
    'set -e\n' \
    'echo "🔍 Checking OpenCPN build dependencies..."\n' \
    'MISSING=false\n' \
    'DEPS="build-essential cmake pkg-config gettext libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libcurl4-openssl-dev libgtk-3-dev libglew-dev zlib1g-dev libbz2-dev libexpat1-dev"\n' \
    'for pkg in $DEPS; do\n' \
    '  if ! dpkg -s $pkg >/dev/null 2>&1; then\n' \
    '    echo "❌ Missing: $pkg"\n' \
    '    MISSING=true\n' \
    '  else\n' \
    '    echo "✅ $pkg"\n' \
    '  fi\n' \
    'done\n' \
    'if [ "$MISSING" = true ]; then\n' \
    '  echo "⚠️ Missing dependencies detected. Aborting build."\n' \
    '  exit 1\n' \
    'else\n' \
    '  echo "🎉 All build dependencies are installed!"\n' \
    'fi\n' \
    > /check_opencpn_deps.sh && chmod +x /check_opencpn_deps.sh && /check_opencpn_deps.sh

# Clone OpenCPN source
WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Build OpenCPN
RUN mkdir -p build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON && \
    make -j$(nproc) && \
    make install

# ===== Stage 2: Runtime Image =====
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime libraries only
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libwxgtk3.2-1 \
        libglu1-mesa \
        libsqlite3-0 \
        libtinyxml2-9 \
        libcurl4 \
        libgtk-3-0 \
        libglew2.2 \
        zlib1g \
        libbz2-1.0 \
        libexpat1 \
        ca-certificates \
        tzdata \
        wget \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Copy built OpenCPN from builder
COPY --from=builder /usr/local/ /usr/local/

# Expose OpenCPN ports
EXPOSE 10110/udp
EXPOSE 10110/tcp

WORKDIR /usr/local/bin
ENTRYPOINT ["opencpn"]
