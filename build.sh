#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${DEVICE:-wr703n-16m64m}"
MODE="${1:-}"

usage() {
  cat <<'EOF'
WiFi2Eth 多设备构建入口

支持设备（DEVICE=...）:
  wr703n-16m64m   TP-Link WR703N 16M Flash / 64M RAM（默认）
  k2              斐讯 Phicomm K2（OpenWrt v22.5 布局）

各机型共用 Setup 热点 WiFi2Eth-Setup、密码 wifi2eth、同一套配网 UI。

用法:
  DEVICE=wr703n-16m64m ./build.sh docker [build|quick|prepare|clean|shell|image]
  DEVICE=k2            ./build.sh docker [build|quick|prepare|clean|shell|image]

  DEVICE=<设备> ./build.sh [build|quick|prepare|clean]

推荐（Docker，无需在宿主机装编译依赖）:
  DEVICE=k2 ./build.sh docker build
  DEVICE=k2 ./build.sh docker quick

环境变量:
  DEVICE=设备         目标设备，默认 wr703n-16m64m
  JOBS=N              并行任务数（默认 Docker 用 nproc，原生用 2）
  FEEDS=1             quick 模式下也更新 feeds
  CCACHE_DIR=路径     ccache 目录（Docker 默认 .ccache/）
EOF
}

case "$DEVICE" in
  wr703n-16m64m|k2) ;;
  *) echo "未知设备: $DEVICE" >&2; usage >&2; exit 1 ;;
esac

export DEVICE

case "$MODE" in
  docker)
    shift
    exec "$HERE/scripts/docker-build.sh" "${1:-quick}" "${@:2}"
    ;;
  build|quick|prepare|clean)
    exec "$HERE/scripts/openwrt-build.sh" "$MODE" "${@:2}"
    ;;
  -h|--help|help|"")
    usage
    [ -n "$MODE" ] || exit 0
    exit 0
    ;;
  *)
    echo "未知命令: $MODE" >&2
    usage >&2
    exit 1
    ;;
esac
