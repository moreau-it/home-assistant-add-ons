# ===== Stage 1: Build OpenCPN from source =====
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for OpenCPN build
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        curl \
        ca-certificates \
        libwxgtk3.2-dev \
        libglu1-mesa-dev \
        libsqlite3-dev \
        libtinyxml2-dev \
        libcurl4-openssl-dev \
        gettext \
        git \
        pkg-config \
        g++ \
        unzip \
        tar \
        cmake && \
    rm -rf /var/lib/apt/lists/*

# Clone OpenCPN source
WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .
RUN mkdir -p build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON && \
    make -j$(nproc) && \
    make install

# ===== Stage 2: Final HA Add-on Image =====
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies only (keep image small)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libwxgtk3.2-1 \
        libglu1-mesa \
        libsqlite3-0 \
        libtinyxml2-9 \
        libcurl4 \
        ca-certificates \
        gettext \
        tzdata \
        wget \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Copy OpenCPN from builder stage
COPY --from=builder /usr/local/ /usr/local/

# Expose OpenCPN ports (if required)
EXPOSE 10110/udp
EXPOSE 10110/tcp

# Set up entrypoint
WORKDIR /usr/local/bin
ENTRYPOINT ["opencpn"]
