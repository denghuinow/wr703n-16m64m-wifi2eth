# Changelog

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
