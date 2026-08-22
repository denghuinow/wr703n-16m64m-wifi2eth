#!/usr/bin/env bash
set -euo pipefail

OPENWRT_VERSION="25.12.5"
TAG="v${OPENWRT_VERSION}"
DEVICE="tplink_tl-wr703n-16m64m"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${HERE}/.build"
SRC="${WORK}/openwrt-${OPENWRT_VERSION}"
OUT="${HERE}/out"
# Default to 2 jobs on small hosts; override with JOBS=N.
JOBS="${JOBS:-2}"
MODE="${1:-build}"

# GNU tar/coreutils configure refuse to run as root unless this is set.
export FORCE_UNSAFE_CONFIGURE=1

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少构建命令: $1" >&2; exit 1; }; }
for c in git make gcc g++ python3 rsync awk sed sha256sum; do need "$c"; done

case "$MODE" in
  clean)
    rm -rf "$WORK" "$OUT"
    echo "已清理构建目录。"
    exit 0
    ;;
  prepare|build) ;;
  *) echo "用法: $0 [prepare|build|clean]" >&2; exit 1 ;;
esac

mkdir -p "$WORK"
if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch "$TAG" https://github.com/openwrt/openwrt.git "$SRC"
else
  git -C "$SRC" fetch --depth 1 origin "refs/tags/${TAG}:refs/tags/${TAG}" || true
  git -C "$SRC" checkout -f "$TAG"
  git -C "$SRC" reset --hard "$TAG"
  git -C "$SRC" clean -fdx
fi

cd "$SRC"
"${HERE}/scripts/prepare-openwrt.py" "$SRC"

./scripts/feeds update -a
./scripts/feeds install -a

rm -rf "$SRC/files"
mkdir -p "$SRC/files"
rsync -a "${HERE}/rootfs/" "$SRC/files/"

cp "${HERE}/config.seed" .config
make defconfig

if ! grep -q '^CONFIG_TARGET_ath79_tiny_DEVICE_tplink_tl-wr703n-16m64m=y$' .config; then
  echo "自定义 target 未进入 .config，停止构建。" >&2
  exit 2
fi

if [ "$MODE" = "prepare" ]; then
  echo
  echo "准备完成：$SRC"
  echo "可检查配置后执行：$0 build"
  exit 0
fi

make download -j"$JOBS"
if ! make -j"$JOBS"; then
  echo "并行构建失败，改用单线程输出详细日志。" >&2
  make -j1 V=s
fi

mkdir -p "$OUT"
rm -f "$OUT"/*
shopt -s nullglob
images=(bin/targets/ath79/tiny/*wr703n-16m64m*squashfs*.bin)
if [ ${#images[@]} -eq 0 ]; then
  echo "没有找到 WR703N-16M64M 输出镜像。" >&2
  exit 3
fi
cp -av "${images[@]}" "$OUT/"

# Firmware partition is exactly 0xfd0000 bytes (16192 KiB).
MAX=$((0xfd0000))
for f in "$OUT"/*.bin; do
  sz=$(stat -c %s "$f")
  if [ "$sz" -gt "$MAX" ]; then
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
