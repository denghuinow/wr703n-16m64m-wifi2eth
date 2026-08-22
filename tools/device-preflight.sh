#!/bin/sh
# Run this on the CURRENT firmware before flashing the custom 16M image.
# It is intentionally read-only.
EXPECTED_ART_DEC=16711680   # 0xff0000
EXPECTED_ART_SIZE=65536     # 0x10000

echo '=== board ==='
uname -a 2>/dev/null || true
cat /etc/openwrt_release 2>/dev/null || true

echo
echo '=== /proc/mtd ==='
cat /proc/mtd 2>/dev/null || true

echo
echo '=== MTD sysfs ==='
PASS=0
FOUND_ART=0
for d in /sys/class/mtd/mtd[0-9]*; do
  [ -d "$d" ] || continue
  name="$(cat "$d/name" 2>/dev/null)"
  size="$(cat "$d/size" 2>/dev/null)"
  offset="$(cat "$d/offset" 2>/dev/null)"
  printf '%-6s name=%-16s offset=%-12s size=%s\n' "${d##*/}" "$name" "${offset:-?}" "${size:-?}"
  case "$name" in art|ART)
    FOUND_ART=1
    if [ "$offset" = "$EXPECTED_ART_DEC" ] && [ "$size" = "$EXPECTED_ART_SIZE" ]; then PASS=1; fi
    ;;
  esac
done

echo
echo '=== SPI / partition messages ==='
dmesg 2>/dev/null | grep -Ei 'spi-nor|m25p|w25q|Creating .* MTD|0x[0-9a-f]+-0x[0-9a-f]+.*art|art"' || true

echo
if [ "$PASS" -eq 1 ]; then
  echo 'PASS: ART 位于 0xff0000，大小 64 KiB；与 WR703N-16M64M 固件布局一致。'
  exit 0
fi
if [ "$FOUND_ART" -eq 1 ]; then
  echo 'FAIL: 找到了 ART，但位置/大小不是 0xff0000 + 0x10000。不要刷本固件。'
else
  echo 'UNKNOWN: 当前内核没有暴露可确认的 ART offset。不要仅凭此脚本刷写；请在 Breed 备份/确认 Flash 布局。'
fi
exit 1
