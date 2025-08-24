# ===== Stage 1: Build OpenCPN from source =====
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies for OpenCPN (builder)
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
        lsb-release \
        libwxgtk3.2-dev \
        libglu1-mesa-dev \
        libsqlite3-dev \
        libtinyxml2-dev \
        libtinyxml-dev \
        libcurl4-openssl-dev \
        libgtk-3-dev \
        libglew-dev \
        libarchive-dev \
        libudev-dev \
        libusb-1.0-0-dev \
        zlib1g-dev \
        libbz2-dev \
        libexpat1-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Build OpenCPN with generic USB, Garmin disabled
RUN mkdir -p build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON \
      -DOCPN_ENABLE_GARMINHOST=OFF && \
    make -j2 && \
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
        libarchive13 \
        libudev1 \
        zlib1g \
        libbz2-1.0 \
        libexpat1 \
        ca-certificates \
        tzdata \
        wget \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Copy built OpenCPN
COPY --from=builder /usr/local/ /usr/local/

# Expose OpenCPN ports
EXPOSE 10110/udp
EXPOSE 10110/tcp

WORKDIR /usr/local/bin
ENTRYPOINT ["opencpn"]
