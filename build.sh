#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-}"

usage() {
  cat <<'EOF'
WR703N-16M64M WiFi2Eth 构建入口

用法:
  ./build.sh docker [build|quick|prepare|clean|shell|image]
  ./build.sh [build|quick|prepare|clean]

推荐（Docker，无需在宿主机装编译依赖）:
  ./build.sh docker build     首次全量编译（约 30~60 分钟）
  ./build.sh docker quick     增量编译（改 rootfs/脚本，约 5~15 分钟）

原生编译（宿主机需安装 OpenWrt 依赖，见 README）:
  ./build.sh build
  ./build.sh quick

环境变量:
  JOBS=N              并行任务数（默认 Docker 用 nproc，原生用 2）
  FEEDS=1             quick 模式下也更新 feeds
  CCACHE_DIR=路径     ccache 目录（Docker 默认 .ccache/）
EOF
}

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
