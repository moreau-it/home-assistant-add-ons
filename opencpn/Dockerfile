# syntax=docker/dockerfile:1

FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV DISPLAY=:0

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    x11vnc \
    xvfb \
    fluxbox \
    novnc \
    websockify \
    libwxgtk3.0-gtk3-dev \
    libgtk-3-dev \
    libglu1-mesa-dev \
    libgtk2.0-0 \
    libgtk2.0-dev \
    libglu1-mesa-dev \
    libglew-dev \
    libbz2-dev \
    libarchive-dev \
    libdrm-dev \
    libelf-dev \
    libexif-dev \
    libgdk-pixbuf2.0-dev \
    liblz4-dev \
    liblzma-dev \
    libpango1.0-dev \
    libsqlite3-dev \
    libunarr-dev \
    libwxsvg-dev \
    libportaudio2 \
    portaudio19-dev \
    pkg-config \
    zlib1g-dev \
    libcurl4-openssl-dev \
    libtinyxml2-dev \
    libexpat1-dev \
    libssl-dev \
    libcurlpp-dev \
    ca-certificates \
    libx11-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libjpeg-dev \
    libtiff5-dev \
    libgeos-dev \
    libproj-dev \
    unzip \
    xdg-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Replace outdated cmake with newer version
RUN apt-get remove -y cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.27.9/cmake-3.27.9-linux-aarch64.tar.gz && \
    tar -xzf cmake-3.27.9-linux-aarch64.tar.gz && \
    cp -r cmake-3.27.9-linux-aarch64/* /usr/local/ && \
    rm -rf cmake-3.27.9-linux-aarch64* && \
    cmake --version

# Clone and build libnmea
RUN git clone https://github.com/jacketizer/libnmea.git /tmp/libnmea && \
    cd /tmp/libnmea && mkdir build && cd build && \
    cmake .. && make && make install && \
    ldconfig && rm -rf /tmp/libnmea

# Clone and build OpenCPN
RUN mkdir -p /src/opencpn && cd /src/opencpn && \
    git clone https://github.com/OpenCPN/OpenCPN.git && \
    cd OpenCPN && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# Copy runtime script
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
