FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800

# Build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config gettext git wget curl ca-certificates unzip tar lsb-release \
    libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libtinyxml-dev \
    libcurl4-openssl-dev libgtk-3-dev libglew-dev libarchive-dev libudev-dev libusb-1.0-0-dev \
    libpthread-stubs0-dev libssl-dev zlib1g-dev libbz2-dev libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

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
# Runtime
# -------------------------
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800

# Install runtime deps + desktop + VNC + noVNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    libwxgtk3.2-1 libglu1-mesa libsqlite3-0 libtinyxml2-9 libcurl4 \
    libgtk-3-0 libglew2.2 libarchive13 libudev1 libusb-1.0-0 libssl3 \
    zlib1g libbz2-1.0 libexpat1 x11-xserver-utils jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local
COPY run.sh /run.sh

RUN chmod +x /run.sh

# Expose ports
# TigerVNC
EXPOSE 5901
# noVNC (web)
EXPOSE 6080
# NMEA TCP
EXPOSE 10110/tcp
# NMEA UDP
EXPOSE 10110/udp

CMD ["/run.sh"]
