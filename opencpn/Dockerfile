FROM debian:bullseye AS build

ENV DEBIAN_FRONTEND=noninteractive

# Install full set of build dependencies
RUN apt-get update && apt-get install -y \
  git build-essential cmake gettext \
  libwxgtk3.0-gtk3-dev wx-common \
  libglu1-mesa-dev freeglut3-dev mesa-common-dev \
  libcurl4-gnutls-dev libtinyxml-dev zlib1g-dev libbz2-dev \
  libarchive-dev libdrm-dev libelf-dev libexif-dev \
  libgdk-pixbuf2.0-dev liblz4-dev liblzma-dev libpango1.0-dev \
  libsqlite3-dev libunarr-dev libwxsvg-dev portaudio19-dev \
  pkg-config usbutils udev

# Build and install libnmea
RUN git clone https://github.com/jacketizer/libnmea.git /tmp/libnmea && \
    cd /tmp/libnmea && mkdir build && cd build && \
    cmake .. && make && make install && ldconfig && \
    rm -rf /tmp/libnmea

# Download and build OpenCPN v5.12.0
RUN mkdir -p /opencpn && cd /opencpn && \
    wget https://github.com/OpenCPN/OpenCPN/archive/refs/tags/v5.12.0.tar.gz && \
    tar xf v5.12.0.tar.gz && \
    cd OpenCPN-5.12.0 && mkdir build && cd build && \
    cmake .. && make -j$(nproc) && make install

# Final runtime stage
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0

# Install runtime dependencies required by OpenCPN
RUN apt-get update && apt-get install -y \
  bzip2 libarchive13 libbz2-1.0 libcurl3-gnutls libelf1 \
  liblz4-1 liblzma5 libportaudio2 libsqlite3-0 \
  libtinyxml2.6.2v5 libunarr1 \
  libwxbase3.0-0v5 libwxgtk3.0-gtk3-0v5 libwxsvg3 \
  libx11-6 \
  x11vnc xvfb fluxbox novnc websockify usbutils udev \  
  libgtk-3-0 libglew-dev && rm -rf /var/lib/apt/lists/*

# Copy built binaries/libraries
COPY --from=build /usr/local/bin/opencpn /usr/local/bin/
COPY --from=build /usr/local/lib/libnmea* /usr/local/lib/
RUN ldconfig

# Add your run script & expose port
COPY run.sh /run.sh
RUN chmod +x /run.sh
EXPOSE 6080
CMD ["/run.sh"]
