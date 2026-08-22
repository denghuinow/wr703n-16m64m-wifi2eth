#!/usr/bin/env bash
# Core OpenWrt build logic. Runs natively or inside the Docker builder image.
set -euo pipefail

OPENWRT_VERSION="25.12.5"
TAG="v${OPENWRT_VERSION}"
DEVICE="tplink_tl-wr703n-16m64m"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${HERE}/.build"
SRC="${WORK}/openwrt-${OPENWRT_VERSION}"
OUT="${HERE}/out"
JOBS="${JOBS:-2}"
MODE="${1:-build}"

export FORCE_UNSAFE_CONFIGURE=1

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少构建命令: $1" >&2; exit 1; }; }
for c in git make gcc g++ python3 rsync awk sed sha256sum; do need "$c"; done

sync_overlay() {
  rm -rf "$SRC/files"
  mkdir -p "$SRC/files"
  rsync -a "${HERE}/rootfs/" "$SRC/files/"
  cp "${HERE}/config.seed" "$SRC/.config"
  make -C "$SRC" defconfig
}

verify_target() {
  if ! grep -q '^CONFIG_TARGET_ath79_tiny_DEVICE_tplink_tl-wr703n-16m64m=y$' "$SRC/.config"; then
    echo "自定义 target 未进入 .config，停止构建。" >&2
    exit 2
  fi
}

collect_images() {
  mkdir -p "$OUT"
  rm -f "$OUT"/*
  shopt -s nullglob
  local images=( "$SRC"/bin/targets/ath79/tiny/*wr703n-16m64m*squashfs*.bin )
  if [ ${#images[@]} -eq 0 ]; then
    echo "没有找到 WR703N-16M64M 输出镜像。" >&2
    exit 3
  fi
  cp -av "${images[@]}" "$OUT/"

  local max=$((0xfd0000))
  local f
  for f in "$OUT"/*.bin; do
    local sz
    sz=$(stat -c %s "$f")
    if [ "$sz" -gt "$max" ]; then
      echo "镜像超过 0xfd0000 firmware 分区：$f ($sz bytes)" >&2
      exit 4
    fi
  done

  (
    cd "$OUT"
    sha256sum *.bin > SHA256SUMS
  )

  echo
  echo "构建完成："
  ls -lh "$OUT"
  echo
  echo "Breed 首刷优先使用 *factory.bin；OpenWrt 后续升级使用 *sysupgrade.bin。"
  echo "刷写前必须确认 ART 位于 0xff0000，详见 README.md。"
}

run_make() {
  make -C "$SRC" download -j"$JOBS"
  if ! make -C "$SRC" -j"$JOBS"; then
    echo "并行构建失败，改用单线程输出详细日志。" >&2
    make -C "$SRC" -j1 V=s
  fi
}

prepare_tree() {
  local full="${1:-0}"
  mkdir -p "$WORK"

  if [ ! -d "$SRC/.git" ]; then
    git clone --depth 1 --branch "$TAG" https://github.com/openwrt/openwrt.git "$SRC"
  elif [ "$full" = "1" ]; then
    git -C "$SRC" fetch --depth 1 origin "refs/tags/${TAG}:refs/tags/${TAG}" || true
    git -C "$SRC" checkout -f "$TAG"
    git -C "$SRC" reset --hard "$TAG"
    git -C "$SRC" clean -fdx
  fi

  "${HERE}/scripts/prepare-openwrt.py" "$SRC"

  if [ "$full" = "1" ] || [ ! -d "$SRC/feeds" ] || [ "${FEEDS:-0}" = "1" ]; then
    "$SRC/scripts/feeds" update -a
    "$SRC/scripts/feeds" install -a
  fi
}

case "$MODE" in
  clean)
    rm -rf "$WORK" "$OUT"
    echo "已清理构建目录。"
    ;;

  prepare)
    prepare_tree 1
    sync_overlay
    verify_target
    echo
    echo "准备完成：$SRC"
    echo "可检查配置后执行：./build.sh quick 或 ./build.sh build"
    ;;

  build)
    prepare_tree 1
    sync_overlay
    verify_target
    run_make
    collect_images
    ;;

  quick)
    [ -d "$SRC/.git" ] || { echo "尚未初始化源码树，请先执行 ./build.sh build 或 ./build.sh prepare" >&2; exit 1; }
    prepare_tree 0
    sync_overlay
    verify_target
    run_make
    collect_images
    ;;

  *)
    echo "用法: $0 {build|quick|prepare|clean}" >&2
    echo "  build   全量重编（重置 OpenWrt 源码树，首次或换版本时用）" >&2
    echo "  quick   增量编译（保留 .build 缓存，改 rootfs/脚本时用）" >&2
    echo "  prepare 只准备源码与 .config，不编译" >&2
    echo "  clean   删除 .build/ 与 out/" >&2
    exit 1
    ;;
esac
