#!/usr/bin/env bash
# Core OpenWrt build logic. Runs natively or inside the Docker builder image.
set -euo pipefail

OPENWRT_VERSION="25.12.5"
TAG="v${OPENWRT_VERSION}"
DEVICE="${DEVICE:-wr703n-16m64m}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${HERE}/.build/${DEVICE}"
SRC="${WORK}/openwrt-${OPENWRT_VERSION}"
OUT="${HERE}/out/${DEVICE}"
JOBS="${JOBS:-2}"
MODE="${1:-build}"

case "$DEVICE" in
  wr703n-16m64m)
    CONFIG_SEED="${HERE}/configs/wr703n-16m64m.seed"
    TARGET_CONFIG='CONFIG_TARGET_ath79_tiny_DEVICE_tplink_tl-wr703n-16m64m=y'
    TARGET_DIR='ath79/tiny'
    IMAGE_GLOB='*wr703n-16m64m*squashfs*.bin'
    ;;
  k2)
    CONFIG_SEED="${HERE}/configs/k2.seed"
    TARGET_CONFIG='CONFIG_TARGET_ramips_mt7620_DEVICE_phicomm_k2-v22.5=y'
    TARGET_DIR='ramips/mt7620'
    IMAGE_GLOB='*phicomm_k2-v22.5*squashfs*.bin'
    ;;
  *) echo "未知设备: $DEVICE" >&2; exit 1 ;;
esac

export FORCE_UNSAFE_CONFIGURE=1

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少构建命令: $1" >&2; exit 1; }; }
for c in git make gcc g++ python3 rsync awk sed sha256sum; do need "$c"; done

sync_overlay() {
  rm -rf "$SRC/files"
  mkdir -p "$SRC/files"
  rsync -a "${HERE}/rootfs/" "$SRC/files/"
  cp "$CONFIG_SEED" "$SRC/.config"
  make -C "$SRC" defconfig
}

verify_target() {
  if ! grep -Fqx "$TARGET_CONFIG" "$SRC/.config"; then
    echo "目标 $DEVICE 未进入 .config，停止构建。" >&2
    exit 2
  fi
}

collect_images() {
  mkdir -p "$OUT"
  rm -f "$OUT"/*
  shopt -s nullglob
  local images=( "$SRC"/bin/targets/$TARGET_DIR/$IMAGE_GLOB )
  if [ ${#images[@]} -eq 0 ]; then
    echo "没有找到 $DEVICE 输出镜像。" >&2
    exit 3
  fi
  cp -av "${images[@]}" "$OUT/"

  if [ "$DEVICE" = "wr703n-16m64m" ]; then
    local max=$((0xfd0000)) f sz
    for f in "$OUT"/*.bin; do
      sz=$(stat -c %s "$f")
      if [ "$sz" -gt "$max" ]; then
        echo "镜像超过 WR703N 0xfd0000 firmware 分区：$f ($sz bytes)" >&2
        exit 4
      fi
    done
  fi

  ( cd "$OUT" && sha256sum *.bin > SHA256SUMS )
  echo
  echo "构建完成：$DEVICE"
  ls -lh "$OUT"
  if [ "$DEVICE" = "wr703n-16m64m" ]; then
    echo "Breed 首刷优先使用 *factory.bin；OpenWrt 后续升级使用 *sysupgrade.bin。"
    echo "刷写前必须确认 ART 位于 0xff0000，详见 README.md。"
  else
    echo "K2 请确认机身/原厂为 v22.5 布局后再刷；产物在 out/k2/。"
  fi
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

  # Only the modified WR703N needs a local DTS/device profile patch.
  if [ "$DEVICE" = "wr703n-16m64m" ]; then
    "${HERE}/scripts/prepare-openwrt.py" "$SRC"
  fi

  if [ "$full" = "1" ] || [ ! -d "$SRC/feeds" ] || [ "${FEEDS:-0}" = "1" ]; then
    "$SRC/scripts/feeds" update -a
    "$SRC/scripts/feeds" install -a
  fi
}

case "$MODE" in
  clean)
    rm -rf "$WORK" "$OUT"
    echo "已清理 $DEVICE 构建目录。"
    ;;
  prepare)
    prepare_tree 1; sync_overlay; verify_target
    echo "准备完成：$SRC"
    ;;
  build)
    prepare_tree 1; sync_overlay; verify_target; run_make; collect_images
    ;;
  quick)
    [ -d "$SRC/.git" ] || { echo "尚未初始化 $DEVICE 源码树，请先执行 DEVICE=$DEVICE ./build.sh build 或 prepare" >&2; exit 1; }
    prepare_tree 0; sync_overlay; verify_target; run_make; collect_images
    ;;
  *)
    echo "用法: DEVICE=<设备> $0 {build|quick|prepare|clean}" >&2
    exit 1
    ;;
esac
