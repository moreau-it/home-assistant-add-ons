########################################
# Stage 1 — Build OpenCPN
########################################
FROM debian:bookworm-slim AS opencpn-builder

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /src

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config gettext git wget curl ca-certificates unzip tar lsb-release \
    libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libtinyxml-dev \
    libcurl4-openssl-dev libgtk-3-dev libglew-dev libarchive-dev libudev-dev libusb-1.0-0-dev \
    libpthread-stubs0-dev libssl-dev zlib1g-dev libbz2-dev libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenCPN source
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Build OpenCPN
RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON \
      -DOCPN_ENABLE_GARMINHOST=ON \
      -DCMAKE_C_FLAGS="-fPIC -pthread" \
      -DCMAKE_CXX_FLAGS="-fPIC -pthread" && \
    make -j$(nproc) && make install

# Clean up build artifacts
RUN rm -rf /src /build

########################################
# Stage 2 — Runtime
########################################
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800
ENV VNC_PORT=5901
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH="/usr/local/bin:/usr/local/sbin:${PATH}"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-terminal xfce4-session \
    dbus-x11 gvfs gvfs-backends policykit-1 libpam-systemd \
    x11-xserver-utils xauth jq \
    libwxgtk3.2-1 libglu1-mesa libsqlite3-0 libtinyxml2-9 libtinyxml2.6.2v5 libcurl4 \
    libgtk-3-0 libglew2.2 libarchive13 libudev1 libusb-1.0-0 libssl3 \
    zlib1g libbz2-1.0 libexpat1 \
    perl libswitch-perl curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

RUN update-ca-certificates

# Install KasmVNC from .deb (multi-arch)
RUN ARCH=$(dpkg --print-architecture) && \
    curl --fail --show-error --retry 3 --retry-delay 2 -L \
      -o /tmp/kasmvnc.deb \
      "https://github.com/kasmtech/KasmVNC/releases/latest/download/kasmvnc-${ARCH}.deb" && \
    apt-get update && apt-get install -y /tmp/kasmvnc.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/kasmvnc.deb

# Copy OpenCPN from build stage
COPY --from=opencpn-builder /usr/local /usr/local

# Expose VNC port
EXPOSE 5901
EXPOSE 10110/udp 10110/tcp

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
