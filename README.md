# H3C Magic NX30 Pro · 112M 大分区 ImmortalWrt 固件（GitHub Actions 自动编译）

用 GitHub Actions 云端编译 **H3C 新华三 NX30 Pro** 的 ImmortalWrt 固件：

| 项目 | 内容 |
| --- | --- |
| 源码 | [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) 分支 `25.12`（内核 6.12） |
| 配置 | 源码自带的 **`defconfig/mt7981-ax3000.config`** 为基准，只把设备列表裁到我们这一个 |
| 分区 | **112M 大分区**布局（`ubi` 从 64M 扩到 112M，吃掉 `pdt_data`/`pdt_data_1`/`exp`/`plugin`） |
| WiFi | MTK 闭源 **`mt_wifi`**（mtk-openwrt-feeds），不是开源 mt76 |
| 主题 | [rchen14b/luci-theme-glass](https://github.com/rchen14b/luci-theme-glass)（毛玻璃风格，已设为默认主题） |
| 代理 | [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki)（mihomo 透明代理，含 `mihomo-meta` 内核） |
| 刷写 | 通过 [Yuzhii0718/bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd) 的 U-Boot Web UI 刷入 |

---

## 一、快速开始

1. 在 GitHub 新建一个仓库（Public 或 Private 都可以）。
2. 把本目录下**所有文件**（包括隐藏目录 `.github/`）推上去：

   ```bash
   cd nx30pro-112m-build
   git init
   git add -A
   git commit -m "init: NX30 Pro 112M build"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```

3. 打开仓库 → **Actions** 标签 → 左侧 `Build ImmortalWrt (NX30 Pro 112M)` → **Run workflow**。
4. 约 2~4 小时后（`mihomo-meta` 要从源码编译，比较慢），在本次运行页面的 **Artifacts** 下载 `immortalwrt-h3c_magic-nx30-pro-112m`。
   也可以打 tag 触发，会自动创建 Release：`git tag v1.0 && git push origin v1.0`。

> 失败时下载 `build-log` 工件，里面是完整的编译输出。

---

## 二、目录结构

```
.
├── .github/workflows/build.yml          # 编译流水线
├── .github/workflows/config-check.yml   # 只生成 .config 做校验，不编译（约 2 分钟）
├── configs/nx30pro-112m.config          # 增量配置（只写模板里没有的项）
├── device/h3c_magic-nx30-pro-112m.mk    # 设备定义，追加到 filogic.mk
├── dts/mt7981b-h3c-magic-nx30-pro-112m.dts   # 112M 分区设备树
├── files/etc/uci-defaults/99-nx30pro-112m    # 首启设置默认主题/中文
├── scripts/apply-nx30pro-112m.sh        # 注入 DTS/设备定义/files，含 MAC 降级补丁
└── scripts/configure.sh                 # 模板 → 裁设备 → 叠加增量 → defconfig → 硬校验
```

流水线只做四件"必须做的事"，其余一概不动：

1. **取模板**：`cp defconfig/mt7981-ax3000.config .config`
2. **裁设备**：删掉模板里其它 91 个设备，只留 `h3c_magic-nx30-pro-112m`
3. **注入 112M**：新 DTS、设备定义、`02_network` 的 MAC 降级、首启配置
4. **加两个 feed 级依赖**：nikki feed + Glass 主题

软件包 / 工具链 / `CONFIG_DEVEL` / 闭源 WiFi 开关全部沿用模板，不覆盖。

> 想先验证配置、不花 2 小时编译，就跑 `Config Check (no build)` 这个工作流，
> 它会在 2 分钟内生成 `.config` 并做硬校验（设备唯一性、主题、nikki、mt_wifi 等）。

---

## 三、分区布局（关键）

```
偏移        大小      名称
0x0000000   1M        BL2            (U-Boot 引导链，不动)
0x0100000   0.5M      u-boot-env     (U-Boot 环境变量)
0x0180000   2M        Factory        (无线校准数据，不动)
0x0380000   2M        FIP            (U-Boot 本体)
0x0580000   112M      ubi            ← 原厂 64M，这里扩到 112M
```

原厂的 `pdt_data` / `pdt_data_1` / `exp` / `plugin` 四个分区被合并进 `ubi`，这就是多出来的 48M 空间（主要给 overlay / Docker / nikki 规则等）。

⚠️ **两个副作用，必须知道：**

1. **原机 MAC 会丢**。原厂固件把以太网 MAC 以文本形式存在 `pdt_data_1` 分区里，大分区布局不再有这个分区。
   构建脚本给 `board.d/02_network` 打了降级补丁（`pdt_data_1` → `Factory` → U-Boot 环境变量），
   但**刷机前请先记下原 MAC**，刷完后在 LuCI「网络 → 接口 → 设备」里核对，必要时手动填：
   ```sh
   # 在原厂/旧固件上执行
   mtd_get_mac_ascii pdt_data_1 ethaddr
   ```
2. **原厂插件与出厂信息不可恢复**（除非你有整片 flash 备份）。刷机第一步永远是备份。

> DTS 里的 `compatible` 故意保持 `h3c,magic-nx30-pro` 不变，只改 `model`。
> 因为 `board.d/02_network` 是按 `board_name` 匹配来分配 LAN/WAN 口的，改了会导致没网。

---

## 四、刷机步骤

### 4.0 前置条件

固件走的是 **OpenWrt U-Boot 布局**（`KERNEL_IN_UBI=1`，内核+rootfs 打包成 FIT 放进 UBI 卷 `fit`，
内核用 `root=/dev/fit0` 挂根），所以 U-Boot 必须能**从 UBI 的 `fit` 卷启动 FIT**。

实测这台机器的情况（`/sysinfo`、`/env/list` 读出来的）：

```
U-Boot 2025.07.1-Mediatek  384fdd8  build_variant=default   ← NMBM 开启
mtdids   = nmbm0=nmbm0
mtdparts = nmbm0:1024k(bl2),512k(u-boot-env),2048k(Factory),2048k(fip),112M(ubi)
nmbm0 bad     → 空（0 坏块）
nmbm0 mapping → 空（逻辑块 == 物理块）
```

结论：**`default` 变体也能用，不需要换成 `ubootmod`**。原因有两条：

1. 这个 u-boot 虽然叫 default，但已经支持从 UBI 卷 `fit` 启动 FIT（刷入时日志里是
   `Updating volume 'fit' ... OK`），并且内置了 `immortalwrt-112m` 布局；
2. 我们的内核**没有 NMBM 驱动**，但该闪存 0 坏块、NMBM 映射恒等，所以内核按裸 NAND 读到的
   数据与 u-boot 通过 `nmbm0` 写入的完全一致——已实机验证可正常启动。

> 唯一需要留意的长期风险：如果这块闪存将来出现坏块，u-boot 的 NMBM 会把坏块重映射到别处，
> 而内核按裸地址读就会错位。真遇到这种情况，再换 `ubootmod` 变体（关 NMBM）即可，
> 那一步要动 BL2、有变砖风险，需备好 TTL + [mtk_uartboot](https://github.com/981213/mtk_uartboot)。

### 4.1 备份（务必）

网线接 LAN 口，按住 reset 上电进入 failsafe Web UI（`http://192.168.1.1` 或 `http://failsafe.lan`），
用 **Backup** 功能下载整片 flash 备份，另存好。

### 4.2 确认 ubi 分区是 112M

在 Web UI 首页确认 `MTD layout` 显示为 `immortalwrt-112m`，`ubi` 分区为 **112M / 114688k**。
本机出厂即是这个值，一般无需改动：

```
mtdparts=nmbm0:1024k(bl2),512k(u-boot-env),2048k(Factory),2048k(fip),112M(ubi)
```

如果显示的是原厂 64M 布局，在 **环境变量 / Environment** 页面改成上面这行（`nmbm0` 前缀要与
`mtdids` 一致，不要写成 `spi-nand0`），保存并重启后再确认。

> 必须写死 `112M`（或 `114688k`），不要用 `-(ubi)`。`-` 表示“到 flash 末尾”（约 122.5M），
> 与内核 DTS 里的 112M 不一致，会导致 UBI 挂载失败。

### 4.3 刷入固件

1. Web UI → **Flash editor** → 选中 `ubi` → **Erase**（NAND 设备必须擦除，否则旧的 UBI 元数据会干扰）。
2. Web UI → **固件升级 / Firmware upgrade** → 上传 `*-sysupgrade.itb`。
3. 等待写入完成，设备自动重启（首次启动要格式化 overlay，约 1~2 分钟）。
4. 浏览器打开 `http://192.168.1.1`，无密码直接登录。

### 4.4 救砖 / 验证

- `*-recovery.itb` 是 initramfs 镜像，可以在 Web UI 的 **Initramfs** 里直接内存启动，用来验证固件是否正常，不写 flash。
- 真砖了：TTL 接串口 → `mtk_uartboot` 推一个 RAM 版 BL2 → 进 Web UI 重刷 BL2/FIP。

---

## 五、开机后

- **主题**：已经是 Glass（`/luci-static/glass`），可在「系统 → 系统 → 语言和界面」里换回。
- **nikki**：菜单「服务 → Nikki」，导入订阅后开启即可；内核是 `mihomo`（本固件里由 `mihomo-meta` 提供）。
- **overlay 空间**：`df -h` 应能看到 ~110M 左右的可用空间。

---

## 六、自定义

| 想改什么 | 改哪里 |
| --- | --- |
| 加软件包 | `configs/nx30pro-112m.config` 里加 `CONFIG_PACKAGE_xxx=y` |
| 改分区大小 | 同时改三处：DTS 的 `reg`、`device/*.mk` 的 `IMAGE_SIZE`、刷机时的 `mtdparts` |
| 换/加主题 | `.github/workflows/build.yml` 里 clone 主题那一步 + `files/etc/uci-defaults/` |
| 换源码分支 | workflow 里的 `REPO_BRANCH`（注意其它分支不一定是 6.12 内核，DTS 目录结构可能不同） |
| 默认语言/主机名 | `files/etc/uci-defaults/99-nx30pro-112m` |

---

## 七、已知限制

- **只编译一个设备**，没有开 `CONFIG_ALL`，所以镜像里只有固件必需的包；想加包请写进 config 种子。
- 大分区布局**不能**用官方 OpenWrt 的 `sysupgrade` 从原厂固件直升，只能走 U-Boot Web UI。
- 如果你把 `IMAGE_SIZE` 改小于实际 rootfs，编译最后一步会报 `Image too big`，按提示加大即可。
- 本仓库不包含 U-Boot 的编译（用上游 bl-mt798x-dhcpd 的 Actions 即可），也不对你的设备安全负责——刷机前请备份。

---

## 八、编译加速（重要）

### 为什么不能直接用现成的 .ipk

很多人想「软件包直接从源里下编好的 ipk」。这对 **kmod-\\* 完全行不通**：

- kmod 的 ABI 绑死内核版本 + 内核补丁集。本源码是 MTK 魔改内核（HNAT / 私有补丁），
  官方 ImmortalWrt 仓库编出来的 kmod 装上去必然 `kernel version mismatch`。
- 纯用户态包（luci 主题、yq 之类）理论上可以复用，但它们依赖的 `libc`/`libustream` 等
  ABI 也得对齐，混用不同快照的包很容易出现符号缺失，收益远小于风险。

所以本工程走的是**「缓存编译产物」**而不是「下载别人的产物」——效果一样，且绝对安全：
工具链一旦编好就缓存起来，下次直接用，不再重复编译。

### 已生效的三层缓存

| 缓存 | 内容 | 命中后省下 |
| --- | --- | --- |
| `Restore build cache` | `dl/` 源码包、`build_dir/toolchain-*`、`staging_dir/toolchain-*`、`build_dir/host`、`staging_dir/host` | **约 45~60 分钟**（交叉编译器 + host 工具是整个构建最贵的一段） |
| `Restore ccache` | `~/.ccache` | 包编译阶段的重复目标文件，约 20~30% |
| `dl/` | 已在上面那层里 | 几分钟下载，同时避免上游抽风 |

缓存 key 里带了 `hashFiles('configs/**', 'device/**', 'dts/**')`，所以：

- **改配置/DTS/设备定义 → key 变 → 冷启动**（会重编工具链，属预期）
- **只改工作流其他部分 → key 不变 → 热启动**（几分钟出固件）

想强制清缓存，改 `build.yml` 里的 `CACHE_VER: v1` → `v2` 即可。

> GitHub 单仓库缓存上限 10GB，所以 `build_dir` 的完整内容（20GB+）没法整包缓存，
> 只挑工具链那部分。ccache 也限制在 2GB，避免把工具链缓存挤掉。

### 还能更快：自己出 SDK
如果以后要频繁改包，最优解是「编一次 → 导出 SDK → 之后只用 SDK 编增量」：

```bash
cd openwrt && make menuconfig   # 勾上 Build the OpenWrt SDK
make -j$(nproc)
# 产物：bin/targets/mediatek/filogic/immortalwrt-sdk-*.tar.zst
```

用 SDK 编增量固件通常 10~20 分钟，因为工具链和已编好的包都是现成的。代价是要先有一份 SDK。

---

## 九、调试安全：接设备前先隔离网络

刷机/调试时路由器会被反复重启，**如果本机默认网关指向这台路由器，你的外网会跟着一起断**。
接网线之前先做这三件事：

1. **把调试网卡设成固定 IP、网关留空**

   Windows「网络连接 → 以太网 → IPv4 属性」：

   ```
   IP 地址   192.168.1.190
   子网掩码  255.255.255.0
   默认网关  （留空）
   DNS       （留空）
   ```

   这样这张网卡只做二层通信，永远抢不走默认路由。

2. **确认默认路由仍在上网网卡上**

   ```powershell
   route print -4 | Select-String "0.0.0.0"
   Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Select-Object ifIndex,NextHop,RouteMetric
   ```

   只应该看到一条指向你真正上网那张网卡的默认路由。

3. **访问设备时绕开本机代理**

   ```bash
   curl --noproxy '*' http://192.168.1.1/
   ```

   本机若开了 Clash / 系统代理，`http_proxy` 会把 192.168.1.1 也转发出去，表现为「设备明明在线却连不上」。

调试完把网卡改回「自动获得 IP 地址」即可。

> 另外：u-boot 的 failsafe 网页服务是**单线程**的，在它的网页控制台里跑 `ping` / `tftp`
> 这类网络命令会把网卡 `eth_halt` 掉，网页服务当场死掉，只能断电重启。别在控制台里跑网络命令。
