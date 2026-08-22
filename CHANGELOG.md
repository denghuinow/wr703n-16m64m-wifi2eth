# Changelog

## [1.1.1] - 2026-08-23

### Bug Fixes
- Setup 模式：`network restart` 后重新加载无线，使 AP 重新加入 `br-lan`，修复连 `WR703N-Setup` 拿不到 IP（有线正常）的问题。
- 首次 `board.json` 生成：`tplink,tl-wr703n-16m64m` 与 WR703N 一样仅使用 `eth0` 作 LAN。
- 扫描列表：`iwinfo` 的 `WPA PSK (CCMP)` 误判为「仅 WPA1」导致灰显不可点选；现按 CCMP/AES 识别为可连接的 WPA2。

### Changed
- 新增 Docker 容器编译（`./build.sh docker build|quick`）与 `quick` 增量编译，避免每次全量重编 OpenWrt。

## [1.1.0] - 2026-08-22

### Security
- SSH 默认设置 root 密码 `wr703n`（不再允许空密码登录）。

### Bug Fixes
- Setup 热点 LAN 使用 br-lan，并强制 dnsmasq DHCP，避免有线口检测到上游 DHCP 后 Wi-Fi 拿不到地址。
- 修复配网页点选扫描 SSID 无反应（文本节点点击崩溃）。

## [1.0.0] - 2026-08-20

- 废弃旧 4MB/32MB LEDE 17.01.7 V3 架构。
- 基线切换到 OpenWrt 25.12.5 ath79/tiny。
- 新增独立 `tplink_tl-wr703n-16m64m` 设备 profile。
- 使用 `tplink-16mlzma`，firmware 区 0x20000 + 0xfd0000。
- ART 调整到 0xff0000 + 0x10000。
- 不强制写死内存节点，依赖 Breed 正确初始化 64MB。
- 保留 Web 配网和 Wi-Fi 扫描。
- 扫描列表增加 WPA3-SAE / WPA2-WPA3 Mixed 识别。
- 默认模式改为 NAT；保留 relayd 伪桥。
- 增加刷机前 ART 布局只读检查脚本。
