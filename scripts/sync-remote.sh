#!/usr/bin/env bash
# Sync project sources to remote; never copy .build/ or out/ (machine-local).
set -euo pipefail

REMOTE="${1:-ubuntu@192.168.9.208}"
DEST="${2:-~/wr703n/wr703n-16m64m-wifi2eth/}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

rsync -az --delete \
  --exclude '.git/' \
  --exclude '.build/' \
  --exclude '.ccache/' \
  --exclude 'out/' \
  --exclude 'build.log' \
  "$HERE/" "$REMOTE:$DEST"

echo "已同步到 $REMOTE:$DEST（不含 .build/ / out/）"
