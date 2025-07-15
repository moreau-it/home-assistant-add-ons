# ──────────────────────────────── Stage 1: Builder
FROM opencpn/opencpn-builder:latest AS build

# Install libnmea dependencies
RUN apt-get update && apt-get install -y \
    git cmake build-essential \
 && rm -rf /var/lib/apt/lists/*

# Build libnmea from source
RUN git clone https://github.com/jacketizer/libnmea.git /tmp/libnmea \
 && cd /tmp/libnmea && mkdir build && cd build \
 && cmake .. && make && make install \
 && ldconfig && rm -rf /tmp/libnmea

# Build OpenCPN v5.12.0
RUN mkdir -p /src/opencpn && cd /src/opencpn \
 && wget https://github.com/OpenCPN/OpenCPN/archive/refs/tags/v5.12.0.tar.gz \
 && tar xf v5.12.0.tar.gz \
 && cd OpenCPN-5.12.0 && mkdir build && cd build \
 && cmake .. && make -j$(nproc) && make install

# ──────────────────────────────── Stage 2: Runtime
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0

# Runtime dependencies
RUN apt-get update && apt-get install -y \
   x11vnc xvfb fluxbox novnc websockify \
   usbutils udev libgtk-3-0 libglew2.1 \
 && rm -rf /var/lib/apt/lists/*

# Copy OpenCPN & libnmea
COPY --from=build /usr/local/bin/opencpn /usr/local/bin/opencpn
COPY --from=build /usr/local/lib/libnmea* /usr/local/lib/
RUN ldconfig

# Add run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 6080
CMD ["/run.sh"]
