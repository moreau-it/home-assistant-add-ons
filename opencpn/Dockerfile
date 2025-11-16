########################################
# Stage 1 — Build OpenCPN
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

RUN update-ca-certificates

# Clone OpenCPN source
RUN git clone --depth=1 https://github.com/OpenCPN/OpenCPN.git .

# Fix missing legacy TinyXML SONAME required by OpenCPN
RUN ln -s \
    /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/libtinyxml.so \
    /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/libtinyxml.so.2.6.2 \
    || true

# Build OpenCPN
RUN mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DOCPN_BUNDLE_TCDATA=ON \
      -DOCPN_FORCE_GTK3=ON \
      -DOCPN_ENABLE_GARMINHOST=ON \
      -DCMAKE_C_FLAGS="-fPIC -pthread" \
      -DCMAKE_CXX_FLAGS="-fPIC -pthread" && \
    make -j$(nproc) && make install

RUN rm -rf /src /build


########################################
# Stage 2 — Runtime environment
########################################
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x800
ENV KASMVNC_PORT=6080
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH="/usr/local/bin:/usr/local/sbin:${PATH}"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop
    xfce4 xfce4-goodies xfce4-terminal xfce4-session \
    dbus dbus-x11 policykit-1 x11-xserver-utils xauth gvfs gvfs-backends \
    # OpenCPN runtime deps
    libwxbase3.2-1 libwxgtk3.2-1 libwxgtk-gl3.2-1 \
    libgtk-3-0 libgl1 libglu1-mesa libglew2.2 \
    libarchive13 libudev1 libusb-1.0-0 libsqlite3-0 libcurl4 libssl3 \
    zlib1g libbz2-1.0 libexpat1 \
    # tooling
    perl libswitch-perl curl jq ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && ldconfig

RUN update-ca-certificates

# Fix TinyXML library for OpenCPN runtime
RUN ln -s \
    /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/libtinyxml.so \
    /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/libtinyxml.so.2.6.2 \
    || true

########################################
# Install latest KasmVNC
########################################
RUN set -eux; \
    . /etc/os-release; \
    ARCH="$(dpkg --print-architecture)"; \
    DISTRO="${VERSION_CODENAME:-bookworm}"; \
    URL="$(curl -s https://api.github.com/repos/kasmtech/KasmVNC/releases/latest \
        | jq -r --arg arch "$ARCH" --arg dist "$DISTRO" \
        '.assets[] | select(.name | test("^kasmvncserver_" + $dist + "_[0-9.]+_" + $arch + "\\.deb$")) \
        | .browser_download_url')"; \
    curl --fail --show-error --retry 3 -L -o /tmp/kasmvnc.deb "$URL"; \
    apt-get update && apt-get install -y /tmp/kasmvnc.deb; \
    rm -rf /var/lib/apt/lists/* /tmp/kasmvnc.deb


########################################
# Install OpenCPN from build stage
########################################
COPY --from=opencpn-builder /usr/local /usr/local


########################################
# Add startup script
########################################
COPY start.sh /start.sh
RUN chmod +x /start.sh


########################################
# Expose ports
########################################
EXPOSE 6080/tcp
EXPOSE 10110/tcp 10110/udp


########################################
# Start add-on
########################################
ENTRYPOINT ["/start.sh"]
