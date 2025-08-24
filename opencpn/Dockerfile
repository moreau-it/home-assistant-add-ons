# =========================
# Stage 1: Build OpenCPN
# =========================
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# ---- Install build dependencies ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        pkg-config \
        gettext \
        git \
        wget \
        curl \
        ca-certificates \
        unzip \
        tar \
        lsb-release \
        libwxgtk3.2-dev \
        libglu1-mesa-dev \
        libsqlite3-dev \
        libtinyxml2-dev \
        libtinyxml-dev \
        libcurl4-openssl-dev \
        libgtk-3-dev \
        libglew-dev \
        libarchive-dev \
        libudev-dev \
        libusb-1.0-0-dev \
        libpthread-stubs0-dev \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libexpat1-dev && \
    rm -rf /var/lib/apt/lists/*

# ---- Get OpenCPN source ----
WORKDIR /src
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git OpenCPN

WORKDIR /src/OpenCPN

# Patch GarminHost linking
RUN sed -i '/add_library(GARMINHOST/a target_link_libraries(GARMINHOST pthread rt m usb-1.0 udev)' CMakeLists.txt
RUN sed -i '/target_link_libraries(opencpn PRIVATE/ s/$/ pthread rt m usb-1.0 udev/' CMakeLists.txt

# ---- Build OpenCPN ----
RUN mkdir -p build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON \
      -DOCPN_ENABLE_GARMINHOST=ON \
      -DCMAKE_C_FLAGS="-fPIC -pthread" \
      -DCMAKE_CXX_FLAGS="-fPIC -pthread" && \
    make -j1 VERBOSE=1 && \
    make install

# =========================
# Stage 2: Runtime Image
# =========================
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# ---- Install runtime libraries ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libwxgtk3.2-1 \
        libglu1-mesa \
        libsqlite3-0 \
        libtinyxml2-9 \
        libcurl4 \
        libgtk-3-0 \
        libglew2.2 \
        libarchive13 \
        libudev1 \
        libusb-1.0-0 \
        libssl3 \
        zlib1g \
        libbz2-1.0 \
        libexpat1 \
        ca-certificates \
        tzdata \
        wget \
        curl && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy OpenCPN from builder ----
COPY --from=builder /usr/local/ /usr/local/

# ---- Expose OpenCPN default NMEA ports ----
EXPOSE 10110/udp
EXPOSE 10110/tcp

# ---- Set default working dir ----
WORKDIR /usr/local/bin

# ---- Start OpenCPN ----
ENTRYPOINT ["opencpn"]
