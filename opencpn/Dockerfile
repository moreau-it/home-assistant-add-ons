FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0

# Install core system dependencies
RUN apt-get update && apt-get install -y \
    build-essential cmake git wget curl pkg-config \
    gettext libgtk-3-dev libgtk2.0-0 libwxgtk3.0-gtk3-dev wx-common \
    libglu1-mesa-dev freeglut3-dev mesa-common-dev \
    libcurl4-openssl-dev libtinyxml-dev zlib1g-dev \
    libbz2-dev libarchive-dev libdrm-dev libelf-dev \
    libexif-dev libgdk-pixbuf2.0-dev liblz4-dev liblzma-dev \
    libpango1.0-dev libsqlite3-dev libunarr-dev libwxsvg-dev \
    portaudio19-dev libglew-dev usbutils udev \
    x11vnc xvfb fluxbox supervisor novnc websockify \
    && apt-get clean

# Upgrade CMake to >= 3.20 for compatibility with cmake_path
RUN apt-get remove -y cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.27.9/cmake-3.27.9-linux-aarch64.tar.gz && \
    tar -xzf cmake-3.27.9-linux-aarch64.tar.gz -C /opt && \
    ln -s /opt/cmake-3.27.9-linux-aarch64/bin/cmake /usr/local/bin/cmake

# Build and install libnmea from source
RUN git clone https://github.com/jacketizer/libnmea.git /tmp/libnmea && \
    cd /tmp/libnmea && mkdir build && cd build && \
    cmake .. && make && make install && \
    ldconfig && rm -rf /tmp/libnmea

# Clone and build latest OpenCPN from source
RUN mkdir -p /src/opencpn && cd /src/opencpn && \
    git clone https://github.com/OpenCPN/OpenCPN.git && \
    cd OpenCPN && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# Copy the startup script
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 6080
CMD ["/run.sh"]
