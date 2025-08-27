########################################
# Stage 1 — Build KasmVNC
########################################
FROM debian:bookworm-slim AS kasmvnc-builder

ENV DEBIAN_FRONTEND=noninteractive

# Install all required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git pkg-config \
    libjpeg-dev libpng-dev libssl-dev \
    libx11-dev libxext-dev libxrender-dev libxrandr-dev libxtst-dev libxi-dev \
    xauth x11-xserver-utils \
    ca-certificates curl \
    libfreetype6-dev libgnutls28-dev libpam0g-dev \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
    libcpuid-dev libtbb-dev libxcursor-dev \
    libwebp-dev libturbojpeg0-dev zlib1g-dev \
    libx264-164 libx265-199 libxvidcore4 libtwolame0 \
    libvorbis0a libvorbisenc2 libvorbisfile3 libvpx7 \
    libtheora0 libtiff6 libxml2 libxmu6 libxmuu1 libxpm4 \
    libxt6 libxaw7 libxmu-dev libxrandr-dev libxrender-dev libxxf86vm1 \
    linux-libc-dev make nettle-dev ocl-icd-libopencl1 openssl patch perl \
    perl-modules-5.36 pkg-config pkgconf pkgconf-bin procps rpcsvc-proto \
    shared-mime-info x11-common x11-xserver-utils x11proto-dev xorg-sgml-doctools \
    xtrans-dev xz-utils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth=1 https://github.com/kasmtech/KasmVNC.git .

# Build KasmVNC with dependency logging
RUN mkdir build && cd build && \
    echo "=== Starting CMake configuration with verbose logs ===" && \
    cmake .. --trace-expand --debug-output -DCMAKE_VERBOSE_MAKEFILE=ON || true && \
    echo "=== Missing dependencies from CMakeError.log ===" && \
    cat CMakeFiles/CMakeError.log || true && \
    make -j$(nproc) && make install

# Clean up build artifacts
RUN rm -rf /src /build

########################################
# Stage 2 — Build OpenCPN
########################################
FROM debian:bookworm-slim AS opencpn-builder

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /src

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config gettext git wget curl ca-certificates unzip tar lsb-release \
    libwxgtk3.2-dev libglu1-mesa-dev libsqlite3-dev libtinyxml2-dev libtinyxml-dev \
    libcurl4-openssl-dev libgtk-3-dev libglew-dev libarchive-dev libudev-dev libusb-1.0-0-dev \
    libpthread-stubs0-dev libssl-dev zlib1g-dev libbz2-dev libexpat1-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON \
      -DOCPN_ENABLE_GARMINHOST=ON \
      -DCMAKE_C_FLAGS="-fPIC -pthread" \
      -DCMAKE_CXX_FLAGS="-fPIC -pthread" && \
    make -j$(nproc) && make install

# Clean up build artifacts
RUN rm -rf /src /build


########################################
# Stage 3 — Runtime
########################################
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800
ENV NOVNC_PORT=6080
ENV VNC_PORT=5901
ENV LD_LIBRARY_PATH=/usr/local/lib
# Add /usr/local/bin and /usr/local/sbin to PATH
ENV PATH="/usr/local/bin:/usr/local/sbin:${PATH}"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-terminal xfce4-session \
    dbus-x11 gvfs gvfs-backends policykit-1 libpam-systemd \
    x11-xserver-utils xauth jq \
    libwxgtk3.2-1 libglu1-mesa libsqlite3-0 libtinyxml2-9 libtinyxml2.6.2v5 libcurl4 \
    libgtk-3-0 libglew2.2 libarchive13 libudev1 libusb-1.0-0 libssl3 \
    zlib1g libbz2-1.0 libexpat1 \
    novnc websockify \
    perl libswitch-perl \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

# Copy in KasmVNC and OpenCPN from build stages
COPY --from=kasmvnc-builder /usr/local /usr/local
COPY --from=opencpn-builder /usr/local /usr/local

# Expose ports
EXPOSE 5901 6080 10110/udp 10110/tcp

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
