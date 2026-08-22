#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
dtsdir = root / "target/linux/ath79/dts"
img = root / "target/linux/ath79/image/tiny-tp-link.mk"

base_dtsi = dtsdir / "ar9331_tplink_tl-wr703n_tl-mr10u.dtsi"
base_dts = dtsdir / "ar9331_tplink_tl-wr703n.dts"
custom_dtsi = dtsdir / "ar9331_tplink_tl-wr703n-16m64m.dtsi"
custom_dts = dtsdir / "ar9331_tplink_tl-wr703n-16m64m.dts"

for p in (base_dtsi, base_dts, img):
    if not p.exists():
        raise SystemExit(f"required OpenWrt source file not found: {p}")

s = base_dtsi.read_text()
expected = [
    "reg = <0x20000 0x3d0000>;",
    "partition@3f0000",
    "reg = <0x3f0000 0x10000>;",
]
for needle in expected:
    if needle not in s:
        raise SystemExit(f"upstream DTS layout changed; missing: {needle}")

s = s.replace("reg = <0x20000 0x3d0000>;", "reg = <0x20000 0xfd0000>;")
s = s.replace("partition@3f0000", "partition@ff0000")
s = s.replace("reg = <0x3f0000 0x10000>;", "reg = <0xff0000 0x10000>;")
custom_dtsi.write_text(s)

s = base_dts.read_text()
s = s.replace('#include "ar9331_tplink_tl-wr703n_tl-mr10u.dtsi"',
              '#include "ar9331_tplink_tl-wr703n-16m64m.dtsi"')
s = s.replace('model = "TP-Link TL-WR703N";',
              'model = "TP-Link TL-WR703N (16M Flash / 64M RAM mod)";')
s = s.replace('compatible = "tplink,tl-wr703n", "qca,ar9331";',
              'compatible = "tplink,tl-wr703n-16m64m", "qca,ar9331";')
custom_dts.write_text(s)

mk = img.read_text()
marker = "define Device/tplink_tl-wr703n-16m64m"
if marker not in mk:
    block = r'''

# Local appliance profile: TL-WR703N hardware modified to 16 MiB SPI NOR / 64 MiB RAM.
# The custom DTS keeps ART at the last 64 KiB of the 16 MiB flash.
define Device/tplink_tl-wr703n-16m64m
  $(Device/tplink-16mlzma)
  SOC := ar9331
  DEVICE_MODEL := TL-WR703N
  DEVICE_VARIANT := 16M64M WiFi2Eth
  DEVICE_DTS := ar9331_tplink_tl-wr703n-16m64m
  DEVICE_PACKAGES := kmod-usb-chipidea2
  TPLINK_HWID := 0x07030101
  SUPPORTED_DEVICES += tplink,tl-wr703n-16m64m
endef
TARGET_DEVICES += tplink_tl-wr703n-16m64m
'''
    mk += block
    img.write_text(mk)

# Validate the resulting source tree.
checks = {
    custom_dtsi: ["reg = <0x20000 0xfd0000>;", "partition@ff0000", "reg = <0xff0000 0x10000>;"],
    custom_dts: ['compatible = "tplink,tl-wr703n-16m64m", "qca,ar9331";'],
    img: ["define Device/tplink_tl-wr703n-16m64m", "$(Device/tplink-16mlzma)", "DEVICE_DTS := ar9331_tplink_tl-wr703n-16m64m"],
}
for p, needles in checks.items():
    text = p.read_text()
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"validation failed: {needle} not found in {p}")

print("Prepared custom device: tplink_tl-wr703n-16m64m")
print("  firmware: 0x020000 + 0xfd0000")
print("  ART:      0xff0000 + 0x010000")
