FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0

RUN apt-get update && apt-get install -y \
    git build-essential cmake gettext \
    libwxgtk3.0-gtk3-dev wx-common \
    libglu1-mesa-dev freeglut3-dev mesa-common-dev \
    libcurl4-openssl-dev \
    libtinyxml-dev zlib1g-dev \
    x11vnc xvfb fluxbox wget \
    libgtk2.0-0 \
    libnmea-dev \
    supervisor \
    novnc websockify \
    && apt-get clean

# Build OpenCPN 5.11.3-beta3
RUN mkdir -p /opencpn && \
    cd /opencpn && \
    wget https://github.com/OpenCPN/OpenCPN/archive/refs/tags/v5.11.3-beta3.tar.gz && \
    tar -xzf v5.11.3-beta3.tar.gz && \
    cd OpenCPN-5.11.3-beta3 && \
    mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install

# Copy run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 6080
CMD [ "/run.sh" ]
