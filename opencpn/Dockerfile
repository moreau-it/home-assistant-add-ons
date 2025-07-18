# ──────────────── Stage 1: Builder ────────────────
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
    pkg-config lsb-release libshp-dev \
    libjpeg-dev libtiff-dev libpng-dev \
 && apt-get clean

# Build and install libnmea
RUN git clone https://github.com/jacketizer/libnmea.git /tmp/libnmea && \
    cd /tmp/libnmea && mkdir build && cd build && \
    cmake .. && make && make install && \
    ldconfig && rm -rf /tmp/libnmea

# Clone and build latest OpenCPN
RUN mkdir -p /src/opencpn && cd /src/opencpn && \
    git clone https://github.com/OpenCPN/OpenCPN.git && \
    cd OpenCPN && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# ──────────────── Stage 2: Runtime ────────────────
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0

# Install runtime dependencies and VNC support
RUN apt-get update && apt-get install -y \
    x11vnc xvfb fluxbox novnc websockify \
    usbutils udev \
    libgtk-3-0 libglew2.1 \
    libjpeg62-turbo libtiff5 libpng16-16 \
    libbz2-1.0 libcurl4 libarchive13 libsqlite3-0 \
    libgdk-pixbuf-2.0-0 liblz4-1 liblzma5 libpango-1.0-0 \
 && apt-get clean

# Copy OpenCPN and libnmea from builder
COPY --from=build /usr/local/bin/opencpn /usr/local/bin/opencpn
COPY --from=build /usr/local/lib/libnmea* /usr/local/lib/
RUN ldconfig

# Add startup script
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 6080
CMD ["/run.sh"]
