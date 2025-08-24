########################################
# Stage 1 — Build OpenCPN
########################################
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config gettext git wget curl ca-certificates unzip tar lsb-release \
    libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libtinyxml-dev \
    libcurl4-openssl-dev libgtk-3-dev libglew-dev libarchive-dev libudev-dev libusb-1.0-0-dev \
    libpthread-stubs0-dev libssl-dev zlib1g-dev libbz2-dev libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

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

########################################
# Stage 2 — Runtime with VNC + noVNC
########################################
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800
ENV NOVNC_PORT=6080
ENV VNC_PORT=5901
ENV LD_LIBRARY_PATH=/usr/local/lib

# Install runtime dependencies + fixes for XFCE + DBus
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-terminal xfce4-session \
    tigervnc-standalone-server tigervnc-common novnc websockify \
    dbus-x11 gvfs gvfs-backends policykit-1 libpam-systemd \
    x11-xserver-utils xauth jq \
    libwxgtk3.2-1 libglu1-mesa libsqlite3-0 libtinyxml2-9 libtinyxml2.6.2v5 libcurl4 \
    libgtk-3-0 libglew2.2 libarchive13 libudev1 libusb-1.0-0 libssl3 \
    zlib1g libbz2-1.0 libexpat1 \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenCPN binaries
COPY --from=builder /usr/local /usr/local

# Configure VNC + XFCE startup
RUN mkdir -p /root/.vnc && \
    echo '#!/bin/sh' > /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'export XAUTHORITY=/root/.Xauthority' >> /root/.vnc/xstartup && \
    echo 'dbus-launch --exit-with-session startxfce4 &' >> /root/.vnc/xstartup && \
    echo 'sleep 2' >> /root/.vnc/xstartup && \
    echo 'opencpn &' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

EXPOSE 5901
EXPOSE 6080
EXPOSE 10110/udp
EXPOSE 10110/tcp

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
