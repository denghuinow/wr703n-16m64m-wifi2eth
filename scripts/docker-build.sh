#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-wifi2eth-builder:latest}"
MODE="${1:-quick}"
DEVICE="${DEVICE:-wr703n-16m64m}"
shift || true

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少命令: $1" >&2; exit 1; }; }
need docker

if [ "$MODE" = "shell" ]; then
  docker build -t "$IMAGE" -f "$HERE/Dockerfile" "$HERE"
  exec docker run --rm -it \
    --user "$(id -u):$(id -g)" \
    -v "$HERE:/work" \
    -w /work \
    -e DEVICE="$DEVICE" \
    -e JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}" \
    -e FORCE_UNSAFE_CONFIGURE=1 \
    -e CCACHE_DIR="${CCACHE_DIR:-/work/.ccache}" \
    "$IMAGE" \
    bash
fi

if [ "$MODE" = "image" ]; then
  docker build -t "$IMAGE" -f "$HERE/Dockerfile" "$HERE"
  echo "镜像已构建：$IMAGE"
  exit 0
fi

docker build -t "$IMAGE" -f "$HERE/Dockerfile" "$HERE"

TTY=()
if [ -t 0 ]; then
  TTY=( -it )
fi

mkdir -p "${CCACHE_DIR:-$HERE/.ccache}"
DOCKER_USER=( --user "$(id -u):$(id -g)" )

docker run --rm "${TTY[@]}" \
  "${DOCKER_USER[@]}" \
  -v "$HERE:/work" \
  -v "${CCACHE_DIR:-$HERE/.ccache}:/work/.ccache" \
  -w /work \
  -e DEVICE="$DEVICE" \
  -e JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}" \
  -e FORCE_UNSAFE_CONFIGURE=1 \
  -e CCACHE_DIR=/work/.ccache \
  -e CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-10G}" \
  "$IMAGE" \
  ./scripts/openwrt-build.sh "$MODE" "$@"
