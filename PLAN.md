# 实施方案 v3：NX30 Pro 112M 固件

> 状态：**待你修改/确认**。不触发编译。

---

## 一、指定输入

| 项 | 指定值 |
| --- | --- |
| 编译源码 | [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) 分支 `25.12`（内核 **6.12**） |
| 配置模板 | 该仓库自带的 **`defconfig/mt7981-ax3000.config`** |
| 分区依据 | [jerryhan77 nx30pro-112m 的 DTS](https://github.com/jerryhan77/immortalwrt-mt798x/blob/nx30pro-112m/target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek/mt7981-h3c-nx30pro-112M.dts) |
| 主题 / 代理 | luci-theme-glass（默认）/ nikki + mihomo |
| 刷写 | bl-mt798x-dhcpd 的 u-boot（`immortalwrt-112m` 布局，本机已验证可刷可启动） |

---

## 二、配置模板分析（已核实）

`defconfig/mt7981-ax3000.config` 在该分支里是**有效且较新**的（不像 padavanonly 那份已过期）：

```
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y        ← subtarget 正确
CONFIG_TARGET_MULTI_PROFILE=y
... 共选中 92 个 MT7981 设备 ...
CONFIG_DEVEL=y  CONFIG_TOOLCHAINOPTS=y  CONFIG_BUSYBOX_CUSTOM=y
```

关键点：

1. **已经包含 `h3c_magic-nx30-pro`**（还有 `h3c_magic-nx30-pro-mtkuboot`）——说明这个设备在模板里是受支持的，我们只是要加一个 112M 变体。
2. **已有 112M 先例**：`creatlentem_clt-r30b1-112m`，它的定义方式就是本树的标准做法（见下）。
3. 设备符号形式是 **`CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_<dev>`**（带 `TARGET_DEVICE_`）。
   `make defconfig` 会把它规范化成 `CONFIG_TARGET_<t>_DEVICE_<d>` 并写入 `CONFIG_TARGET_PROFILE`。

### ⚠️ 一个必须你拍板的点

模板选中 **92 个设备**。全部编译的话：

- 每个设备独立 rootfs + 独立镜像，保守估计 **10 小时以上**
- GitHub 单个 job 上限 **6 小时**，会直接被砍
- 而我们只需要 1 个

所以方案默认：**保留模板的全部软件包/工具链设置，只把设备列表裁到我们这一个**。
如果你要的是"原样 92 个"，需要拆成多个并行 job，成本很高。

---

## 三、借鉴本树自带的 112M 写法（`creatlentem_clt-r30b1-112m`）

该树里 112M 变体是这么写的，我们就照这个套路：

```makefile
define Device/creatlentem_clt-r30b1-112m
  DEVICE_VARIANT := 112M
  DEVICE_DTS := mt7981b-creatlentem-clt-r30b1-112m
  IMAGE_SIZE := 114688k
  $(call Device/creatlentem_clt-r30b1-common)   # 复用公共定义
endef
```

它的 DTS 更是极简——只覆盖 ubi 分区：

```dts
#include "mt7981b-creatlentem-clt-r30b1-common.dtsi"
&ubi { reg = <0x0580000 0x7000000>; };
```

**但 NX30 Pro 没有 `-common.dtsi`**（官方就是一个独立 `.dts`），所以我们的 112M DTS
只能复制整份再改分区，不能只写一行覆盖。

---

## 四、要落地的 5 个改动

### 1. 新 DTS `dts/mt7981b-h3c-magic-nx30-pro-112m.dts`

以 25.12 官方 `mt7981b-h3c-magic-nx30-pro.dts` 为骨架，**只改两处**：

| 改动 | 内容 |
| --- | --- |
| 分区 | `partition@580000` 的 `reg`：`<0x0580000 0x4000000>` → `<0x0580000 0x7000000>` |
| 分区 | 删除 `pdt_data`(0x4580000)/`pdt_data_1`(0x4b80000)/`exp`(0x5180000)/`plugin`(0x5280000) |
| model | → `"H3C Magic NX30 Pro (112M)"` |

**刻意不动**（每条都踩过坑）：

- `compatible` 保持 `h3c,magic-nx30-pro` —— `board.d/02_network` 按 `board_name` 分配 LAN/WAN
- 保留 `chosen { bootargs-append = " root=/dev/fit0 rootwait"; rootdisk = <&ubi_rootdisk>; }`
- 保留 `compatible = "linux,ubi"` + `ubi-volume-fit` 卷

**关于 jerryhan77 那份 DTS**：它是 21.02/内核 5.4 的 SDK 写法
（`files-5.4/`、`nmbm_spim_nand`、`forced-create`、老式 `&eth`/`gsw`），
6.12 树里既没有 `mt7981.dtsi` 也没有 NMBM 驱动，**原样放进去必然编译失败**。
我们只继承它的分区数字（`ubi = 0x580000 + 0x7000000`），其余全部沿用 6.12 主线写法。

> 补充核实：本树 kernel 6.12 **无 NMBM**（`filogic/config-6.12` 零 NMBM 项，
> generic 补丁也没有）。所以 `mediatek,nmbm` 在这棵树里是空属性，加了也不生效。
> 实测该闪存 **0 坏块、NMBM 映射恒等**，裸读完全正常——这也是上一版固件能启动的原因。

### 2. 设备定义 `Device/h3c_magic-nx30-pro-112m`

照抄官方 `Device/h3c_magic-nx30-pro`，只改三处：

| 字段 | 原值 | 112M |
| --- | --- | --- |
| `DEVICE_DTS` | `mt7981b-h3c-magic-nx30-pro` | `mt7981b-h3c-magic-nx30-pro-112m` |
| `IMAGE_SIZE` | `65536k` | `114688k` |
| `DEVICE_VARIANT` | `(OpenWrt U-Boot layout)` | `(112M OpenWrt U-Boot layout)` |

### 3. WiFi 三件套（上一版的致命缺陷）

官方 `Device/h3c_magic-nx30-pro` 的 `DEVICE_PACKAGES :=` **是空的**，照抄就没有无线：
补 `kmod-mt7915e` + `kmod-mt7981-firmware` + `mt7981-wo-firmware`（+ `wpad-openssl`）。

### 4. MAC 降级补丁

`pdt_data_1` 分区被吃掉后，`02_network` 里 `mtd_get_mac_ascii pdt_data_1 ethaddr` 取不到值：

```sh
pdt_data_1  →  Factory  →  fw_printenv ethaddr      # 三级降级
```

### 5. 用户态定制

`files/etc/uci-defaults/99-nx30pro-112m`：默认 Glass 主题 + 简体中文。

---

## 五、流水线

```
clone 25.12 → 恢复缓存(dl+toolchain+host)
→ 加 nikki feed + Glass 主题 → feeds update/install
→ 注入 DTS / 设备定义 / MAC 补丁 / files
→ cp defconfig/mt7981-ax3000.config .config
→ 裁设备列表（只留 h3c_magic-nx30-pro-112m）+ 追加 configs 增量
→ make defconfig → 校验 TARGET_PROFILE / 主题 / nikki / WiFi
→ make download → make -j$(nproc)
→ .manifest 校验包清单 → 收集产物 → tag 时发 Release
```

---

## 六、仓库回退

仓库现在是 padavanonly 6.6 那套，需回到 25.12：

| 提交 | 内容 | 处置 |
| --- | --- | --- |
| `8df7148` | 25.12 + WiFi 修复 + 缓存 + manifest 校验 | **回到这个状态** |
| `a8de73d` | 切到 6.6 | 回退 |
| `60125fef` | 6.6 defconfig 修复 | 回退 |

---

## 七、需要你拍板

| # | 问题 | 我的建议 |
| --- | --- | --- |
| 1 | 模板里 92 个设备：**全编**还是**只编我们这一个**？ | 只编一个（全编超 6h job 上限） |
| 2 | 模板里的 `CONFIG_DEVEL=y` / `CONFIG_TOOLCHAINOPTS=y` 保留吗？ | 建议**关掉**（会加长编译、且可能引入工具链差异），但保留其余软件包选择 |
| 3 | 回退方式：`git revert` 保留历史，还是重置到 `8df7148` 后新提交？ | `git revert`（历史可追溯） |
| 4 | 6.6 那套要不要留 `try-6.6` 分支备份？ | 留 |
| 5 | `model` 显示成什么？ | `H3C Magic NX30 Pro (112M)` |
| 6 | 附加软件包还要什么？ | 当前：glass / nikki+mihomo / htop / ttyd / package-manager |

**你确认（或直接改这份文件）后我再动代码；编译前会再问你一次。**
