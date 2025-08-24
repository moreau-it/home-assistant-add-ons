# ==============================================================
# Stage 1: Build OpenCPN from source
# ==============================================================

FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    # wxWidgets + OpenGL dev
    libwxgtk3.2-dev \
    libglu1-mesa-dev \
    # Core deps
    libsqlite3-dev \
    libtinyxml2-dev \
    libtinyxml-dev \
    libcurl4-openssl-dev \
    libgtk-3-dev \
    libglew-dev \
    libarchive-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    libpthread-stubs0-dev \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenCPN source
WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Create build folder
WORKDIR /src/build

# Configure with Garmin + GTK3
RUN cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DOCPN_BUNDLE_TCDATA=ON \
    -DOCPN_FORCE_GTK3=ON \
    -DOCPN_ENABLE_GARMINHOST=ON \
    -DCMAKE_C_FLAGS="-fPIC -pthread" \
    -DCMAKE_CXX_FLAGS="-fPIC -pthread"

# Build OpenCPN with 2 threads to avoid memory starvation on small systems
RUN make -j2 && make install

# ==============================================================
# Stage 2: Runtime image
# ==============================================================

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenCPN runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # wxWidgets GTK3 + GL + HTML + Core + XML + Net + AUI + RichText
    libwxgtk3.2-1 \
    libwxgtk3.2-dev \
    libglu1-mesa \
    libsqlite3-0 \
    libtinyxml2-9 \
    libcurl4 \
    libgtk-3-0 \
    libglew2.2 \
    libarchive13 \
    libudev1 \
    libusb-1.0-0 \
    libssl3 \
    zlib1g \
    libbz2-1.0 \
    libexpat1 \
    # Backwards compatibility for TinyXML 2.6.2
    libtinyxml2.6.2v5 \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenCPN from builder
COPY --from=builder /usr/local /usr/local

# Set library search path so wxWidgets GL + TinyXML are always found
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH

# Expose default OpenCPN NMEA ports
EXPOSE 10110/udp
EXPOSE 10110/tcp

# Default working dir
WORKDIR /usr/local/bin

# Start OpenCPN
ENTRYPOINT ["opencpn"]
