# OpenWrt 25.12.5 builder for WR703N-16M64M WiFi2Eth
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    FORCE_UNSAFE_CONFIGURE=1 \
    PATH="/usr/lib/ccache:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ccache \
    clang \
    flex \
    bison \
    g++ \
    gawk \
    gcc-multilib \
    gettext \
    git \
    libncurses-dev \
    libssl-dev \
    python3 \
    python3-setuptools \
    rsync \
    swig \
    unzip \
    zlib1g-dev \
    file \
    wget \
    ca-certificates \
    time \
    xsltproc \
    libelf-dev \
    && rm -rf /var/lib/apt/lists/*

RUN ccache --max-size=10G || true

WORKDIR /work

# Default to incremental builds; override with: docker ... ./scripts/openwrt-build.sh build
CMD ["./scripts/openwrt-build.sh", "quick"]
