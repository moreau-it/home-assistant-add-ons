# ----------------------------
# Stage 0: Builder
# ----------------------------
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config gettext git wget curl ca-certificates unzip tar lsb-release \
    libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libtinyxml-dev \
    libcurl4-openssl-dev libgtk-3-dev libglew-dev libarchive-dev libudev-dev libusb-1.0-0-dev \
    libpthread-stubs0-dev libssl-dev zlib1g-dev libbz2-dev libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Clone OpenCPN
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Build OpenCPN
RUN mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DOCPN_BUNDLE_TCDATA=ON \
             -DOCPN_FORCE_GTK3=ON \
             -DOCPN_ENABLE_GARMINHOST=ON \
             -DCMAKE_C_FLAGS="-fPIC -pthread" \
             -DCMAKE_CXX_FLAGS="-fPIC -pthread" && \
    make -j$(nproc) && make install

# ----------------------------
# Stage 1: Runtime
# ----------------------------
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-terminal xfce4-session \
    tigervnc-standalone-server tigervnc-common tigervnc-tools \
    novnc websockify dbus-x11 gvfs gvfs-backends policykit-1 libpam-systemd \
    x11-xserver-utils xauth jq \
    libwxgtk3.2-dev libglu1-mesa libsqlite3-0 libtinyxml2-9 libcurl4 \
    libgtk-3-0 libglew2.2 libarchive13 libudev1 libusb-1.0-0 libssl3 \
    zlib1g libbz2-1.0 libexpat1 && ldconfig && rm -rf /var/lib/apt/lists/*

# Copy OpenCPN from builder
COPY --from=builder /usr/local /usr/local

# Create VNC directory
RUN mkdir -p /root/.vnc

# Copy xstartup (custom script to start XFCE)
COPY xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose VNC and noVNC ports
EXPOSE 5901 6080

# Set default command
CMD ["/start.sh"]
