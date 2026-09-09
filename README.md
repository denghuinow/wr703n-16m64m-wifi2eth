# WiFi2Eth — Wi-Fi → Ethernet

把路由器变成「上级 Wi-Fi → 有线网口」的客户端网关。各机型共用同一套配网 UI、Setup 热点与默认密码；按硬件选择对应固件刷写。

## 统一身份

| 项目 | 值 |
|------|-----|
| Setup 热点 SSID | `WiFi2Eth-Setup`（开放网络） |
| 管理地址 | http://192.168.77.1/ |
| SSH | `root` / `wifi2eth` |
| 主机名 | `wifi2eth` |

登录后请立刻执行 `passwd` 修改密码。

## 支持的硬件

| 设备 | `DEVICE=` | 平台 | Wi-Fi | 有线 | 刷机注意 |
|------|-----------|------|-------|------|----------|
| TP-Link TL-WR703N（16M Flash / 64M RAM 改机） | `wr703n-16m64m` | ath79/tiny · AR9331 | 仅 2.4 GHz | 单 RJ45 | 必须 ART@`0xff0000`；旧 4MB/32MB 机型**不要**刷 |
| 斐讯 Phicomm K2（原厂布局 v22.5 或更新） | `k2` | ramips/mt7620 · MT7620A + MT7612 | 2.4 + 5 GHz | 交换机多口 | 使用 OpenWrt `phicomm_k2-v22.5` 镜像；**勿与 v22.4 布局混刷** |

产物目录：`out/<DEVICE>/`。请务必刷对本机型的镜像。

## 基线

OpenWrt **25.12.5**。

- WR703N：自定义 `tplink_tl-wr703n-16m64m` profile（见下方分区说明）
- K2：使用官方 `phicomm_k2-v22.5` profile，复用本仓库的 WiFi2Eth overlay

---

## WR703N-16M64M 分区与刷机前检查

仅适用于 `DEVICE=wr703n-16m64m`。

```text
0x000000 ┌──────────────────────┐
         │ bootloader / data    │ 128 KiB
0x020000 ├──────────────────────┤
         │ firmware             │ 0xfd0000 = 16192 KiB
         │ kernel + rootfs      │
0xff0000 ├──────────────────────┤
         │ ART                  │ 64 KiB
0x1000000└──────────────────────┘
```

内存大小不在 DTS 中强行写死；由 Breed/启动探测报告 64MB。

本固件假定 ART 在 **0xff0000**。若改机仍把 ART 放在 `0x3f0000`，**绝对不能刷**。

```sh
sh tools/device-preflight.sh
```

只有输出 `PASS` 才与本工程布局一致。进入 Breed 前请备份：整片 Flash、Bootloader、ART/校准区。

### Breed 首刷（WR703N）

刷 `factory.bin`（固件更新）。**不要**更新 Bootloader，**不要**擦除 ART/EEPROM。首次切到本布局时不保留旧配置。后续本固件之间用 `sysupgrade.bin`；不要拿官方 4MB WR703N 镜像覆盖回来。

### K2 刷机

按机身/原厂固件确认是 **v22.5 布局**后，刷 `out/k2/` 中对应的 `sysupgrade`/`factory`（以 OpenWrt 产物名为准）。布局不符会变砖风险高。

---

## 构建

### Docker（推荐）

```sh
# 指定设备；默认 wr703n-16m64m
JOBS=8 DEVICE=wr703n-16m64m ./build.sh docker build
JOBS=8 DEVICE=k2            ./build.sh docker build

# 只改了 rootfs / 网页等 → 增量
JOBS=8 DEVICE=k2 ./build.sh docker quick

./build.sh docker shell
```

远程同步（**不要** rsync `.build/`）：

```sh
./scripts/sync-remote.sh ubuntu@192.168.9.208
ssh ubuntu@192.168.9.208 'cd ~/wr703n/wr703n-16m64m-wifi2eth && JOBS=12 DEVICE=k2 ./build.sh docker build'
```

产物：`out/<DEVICE>/`。

### 原生编译

```sh
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib gettext git \
  libncurses-dev libssl-dev python3 python3-setuptools rsync swig unzip zlib1g-dev file wget

DEVICE=k2 ./build.sh prepare
DEVICE=k2 ./build.sh build    # 全量（会 git clean 源码树）
DEVICE=k2 ./build.sh quick    # 增量
```

---

## 首次使用

1. 连接热点 `WiFi2Eth-Setup`
2. 打开 http://192.168.77.1/
3. 扫描并点选上级 SSID（双频机可看到 2.4 / 5 GHz）
4. 输入密码，选择 NAT 或 relay
5. 保存并连接

### NAT（默认）

```text
上级 Wi-Fi
    │
 WiFi2Eth 设备
    │ NAT
    └── 网口 → 192.168.77.x
```

### relayd 伪桥

```text
上级 Wi-Fi DHCP
    │
 WiFi2Eth relayd
    │
    └── 网口 → 上级网段地址
```

仅为 IPv4 伪桥。OpenWrt 25.12.5 有 relayd 长时间停转的报告，默认请用 NAT。

## Reset

```text
< 1 秒       重启
5～14 秒     重新进入 WiFi2Eth-Setup 配网
>= 15 秒     恢复出厂并重启
```

## SSH 配网

```sh
wifi2eth setup 'SSID' 'password' nat psk2
wifi2eth setup 'SSID' 'password' relay psk2
wifi2eth setup 'SSID' 'password' nat sae 5g    # 双频机可选 2g|5g
wifi2eth setup 'OpenSSID' - nat none
wifi2eth status
```

## 功能概览

- 共用 Web 配网 UI / Captive Portal 探测跳转
- `iwinfo` 扫描（多 radio 时含 5 GHz）
- WPA2 / WPA3-SAE / Mixed / Open
- NAT 与 relayd
- uhttpd + SSH（默认密码见上表）
