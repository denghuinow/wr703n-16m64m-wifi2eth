# WR703N-16M64M WiFi → Ethernet

专用于以下硬件改机：

- SoC: Atheros AR9331
- RAM: 64 MiB
- SPI NOR: Winbond W25Q128 16 MiB
- Bootloader: Breed（目标机为 r1337）
- 以太网：WR703N 单 RJ45
- Wi-Fi：2.4 GHz ath9k

**旧的 4MB/32MB V3 不要再刷。** 本工程是完全独立的 16M64M 设备 profile。

## 基线

OpenWrt 25.12.5 / ath79/tiny。

构建脚本新增 `tplink_tl-wr703n-16m64m`，并从官方 WR703N DTS 复制出独立 DTS：

```text
0x000000 ┌──────────────────────┐
         │ bootloader / data    │ 128 KiB
0x020000 ├──────────────────────┤
         │                      │
         │ firmware             │ 0xfd0000 = 16192 KiB
         │ kernel + rootfs      │
         │                      │
0xff0000 ├──────────────────────┤
         │ ART                  │ 64 KiB
0x1000000└──────────────────────┘
```

内存大小**不在 DTS 中强行写死**。AR9331/Breed 已经正确初始化并报告 64MB 时，让内核沿用启动时的内存探测结果更安全。

## 刷机前必须确认 ART

本固件假定 ART 在 **0xff0000**。如果你的 16MB 改机仍把 ART 放在 0x3f0000，**绝对不能刷**，因为扩展 firmware 分区会覆盖那个位置。

当前系统能 SSH 时先运行：

```sh
sh tools/device-preflight.sh
```

（把脚本复制到当前 WR703N 后执行。）只有输出 `PASS` 才与本工程布局一致。

此外必须进入 Breed Web 界面备份：

1. 整片 16MB Flash（如果 Breed 提供整片备份）；
2. Bootloader/编程器固件；
3. ART/EEPROM/无线校准区。

ART 是本机无线校准数据，丢失后不能用别台机器的备份随便替代。

## 构建

### Docker 编译（推荐）

宿主机只需安装 Docker，不必手动装 OpenWrt 编译依赖。`.build/` 与 `.ccache/` 会保留在宿主机目录，**第二次起用 `quick` 会快很多**。

```sh
# 首次全量编译（约 30~60 分钟，视 CPU 而定）
JOBS=8 ./build.sh docker build

# 只改了 rootfs / wifi2eth / 网页 等，增量编译（约 5~15 分钟）
JOBS=8 ./build.sh docker quick

# 进入容器调试
./build.sh docker shell
```

等价写法：

```sh
docker compose run --rm builder                    # 默认 quick
docker compose run --rm builder ./scripts/openwrt-build.sh build
```

同步到远程编译（**不要** rsync `.build/`，各机器路径不同会污染缓存）：

```sh
./scripts/sync-remote.sh ubuntu@192.168.9.208
ssh ubuntu@192.168.9.208 'cd ~/wr703n/wr703n-16m64m-wifi2eth && JOBS=12 ./build.sh docker build'
```

产物仍在 `out/`。

### 原生编译

Ubuntu/Debian 需先安装 OpenWrt 常用依赖：

```sh
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync swig unzip zlib1g-dev file wget
```

```sh
./build.sh prepare    # 仅准备源码与 .config
./build.sh build      # 全量编译
./build.sh quick      # 增量编译（保留 .build/）
```

> **说明**：`build` 会重置 OpenWrt 源码树（`git clean -fdx`），每次都像首次编译一样慢；日常改 overlay 请用 `quick`。

产物位于 `out/`：

```text
openwrt-25.12.5-ath79-tiny-tplink_tl-wr703n-16m64m-squashfs-factory.bin
openwrt-25.12.5-ath79-tiny-tplink_tl-wr703n-16m64m-squashfs-sysupgrade.bin
SHA256SUMS
```

## Breed 首刷

前提：已经确认 ART@0xff0000，并已完成备份。

优先通过 Breed 的“固件更新”刷 `factory.bin`。**不要选择 Bootloader 更新，不要勾选擦除/覆盖 ART、EEPROM、校准区。**

第一次切换到这个自定义分区布局时，不保留旧 OpenWrt 配置。

后续本固件之间升级使用 `sysupgrade.bin`；由于这是自定义 compatible/profile，不要拿官方 4MB WR703N sysupgrade 镜像覆盖回来。

## 首次使用

首次启动：

```text
SSID: WR703N-Setup
管理地址: http://192.168.77.1/
```

手机连接热点后：

1. 点击“扫描附近 Wi-Fi”；
2. 点选 SSID；
3. 自动带出 WPA2/WPA3 类型，可手工修改；
4. 输入密码；
5. 选择 NAT 或 relay；
6. 保存并连接。

### NAT（默认）

```text
上级 Wi-Fi
    │
 WR703N
    │ NAT
    └── RJ45 → 192.168.77.x
```

兼容性和长期稳定性优先。

### relayd 伪桥

```text
上级 Wi-Fi DHCP
    │
 WR703N relayd
    │
    └── RJ45 → 上级路由器网段地址
```

这是 IPv4 pseudo-bridge，不是真正的 802.11 四地址二层桥。

OpenWrt 25.12.5 在 2026-07 有 relayd 长时间运行后停止转发的公开 bug 报告，因此本固件默认 NAT；只有确实要求有线设备与上级处于同一 IPv4 网段时才选 relay。

## Reset

```text
< 1 秒       重启
5～14 秒     重新进入 WR703N-Setup 配网模式
>= 15 秒     恢复出厂并重启
```

## SSH

默认账号（首次启动 / 恢复出厂后）：

```text
用户: root
密码: wr703n
```

登录后请立刻修改：

```sh
passwd
```

也可以用 SSH 直接配网：

```sh
wifi2eth setup 'SSID' 'password' nat psk2
wifi2eth setup 'SSID' 'password' relay psk2
wifi2eth setup 'SSID' 'password' nat sae
wifi2eth status
```

开放网络：

```sh
wifi2eth setup 'OpenSSID' - nat none
```

## 当前实现内容

- OpenWrt 25.12.5 / ath79/tiny
- 16MiB TP-Link LZMA image layout
- ART @ 0xff0000
- 64MB RAM 改机目标（不强制 DTS memory node）
- 首次/Reset 配网 AP
- 手机 Web 配网
- `iwinfo` 扫描附近 2.4GHz Wi-Fi
- WPA2 / WPA3-SAE / WPA2-WPA3 Mixed / Open
- NAT
- relayd IPv4 pseudo-bridge
- uhttpd
- SSH
- Captive Portal 常见探测 URL
