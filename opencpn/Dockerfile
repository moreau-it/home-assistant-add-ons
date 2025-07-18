# ──────────────────────────────── Stage 1: Build OpenCPN + libnmea
FROM debian:bullseye AS build

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git build-essential cmake gettext wget \
    libwxgtk3.0-gtk3-dev wx-common \
    libglu1-mesa-dev freeglut3-dev mesa-common-dev \
    libcurl4-gnutls-dev \
    libtinyxml-dev zlib1g-dev libbz2-dev \
    libarchive-dev libdrm-dev libelf-dev libexif-dev \
    libgdk-pixbuf2.0-dev liblz4-dev liblzma-dev libpango1.0-dev \
    libsqlite3-dev libunarr-dev libwxsvg-dev portaudio19-dev \
    libglew-dev \
    libgtk2.0-0 libgtk-3-dev \
    pkg-config \
    lsb-release \
 && apt-get clean

# Build libnmea from source
RUN git clone https://github.com/jacketizer/libnmea.git /tmp/libnmea && \
    cd /tmp/libnmea && mkdir build && cd build && \
    cmake .. && make && make install && \
    ldconfig && rm -rf /tmp/libnmea

# Clone and build latest OpenCPN from master
RUN mkdir -p /src/opencpn && cd /src/opencpn && \
    git clone https://github.com/OpenCPN/OpenCPN.git && \
    cd OpenCPN && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# ──────────────────────────────── Stage 2: Runtime
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    x11vnc xvfb fluxbox novnc websockify \
    usbutils udev \
    libgtk-3-0 libglew2.1 \
 && apt-get clean

# Copy OpenCPN binary and libnmea from build stage
COPY --from=build /usr/local/bin/opencpn /usr/local/bin/opencpn
COPY --from=build /usr/local/lib/libnmea* /usr/local/lib/
RUN ldconfig

# Copy launcher script
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 6080
CMD ["/run.sh"]
