# -------------------------
# Stage 1: Build OpenCPN
# -------------------------
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV VNC_RESOLUTION=1280x800
ENV DISPLAY=:1

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config gettext git wget curl ca-certificates unzip tar lsb-release \
    libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libtinyxml-dev \
    libcurl4-openssl-dev libgtk-3-dev libglew-dev libarchive-dev libudev-dev libusb-1.0-0-dev \
    libpthread-stubs0-dev libssl-dev zlib1g-dev libbz2-dev libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenCPN source
WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Build OpenCPN
RUN mkdir -p build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DOCPN_BUNDLE_TCDATA=ON \
        -DOCPN_FORCE_GTK3=ON \
        -DOCPN_ENABLE_GARMINHOST=ON \
        -DCMAKE_C_FLAGS="-fPIC -pthread" \
        -DCMAKE_CXX_FLAGS="-fPIC -pthread" && \
    make -j$(nproc) && \
    make install

# -------------------------
# Stage 2: Final runtime image
# -------------------------
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV NOVNC_HOME=/usr/share/novnc
ENV NOVNC_PORT=6080

# Install runtime dependencies + TigerVNC + noVNC + websockify
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    libwxgtk3.2-1 libglu1-mesa libsqlite3-0 libtinyxml2-9 libcurl4 \
    libgtk-3-0 libglew2.2 libarchive13 libudev1 libusb-1.0-0 libssl3 \
    zlib1g libbz2-1.0 libexpat1 x11-xserver-utils jq \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenCPN binaries from builder
COPY --from=builder /usr/local /usr/local

# Create VNC startup script (Xfce + OpenCPN)
RUN mkdir -p ~/.vnc && \
    echo '#!/bin/sh\n' \
         'unset SESSION_MANAGER\n' \
         'unset DBUS_SESSION_BUS_ADDRESS\n' \
         'startxfce4 &\n' \
         'sleep 2\n' \
         'opencpn &' \
    > ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

# -------------------------
# Add startup script
# -------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

# -------------------------
# Expose ports
# -------------------------
EXPOSE 10110/udp       # NMEA UDP
EXPOSE 10110/tcp       # NMEA TCP
EXPOSE 5901            # Direct VNC
EXPOSE 6080            # noVNC web interface

# Default working directory
WORKDIR /usr/local/bin

# Start script
ENTRYPOINT ["/start.sh"]
