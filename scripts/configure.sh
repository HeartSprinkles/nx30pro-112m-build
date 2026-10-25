#!/bin/bash
#
# 用源码自带的 defconfig/mt7981-ax3000.config 生成 .config
#   1) 以模板为基准（保留它的全部软件包 / 工具链 / DEVEL 等设置）
#   2) 只把设备列表裁到我们这一个
#   3) 叠加 configs/nx30pro-112m.config（主题、nikki 等增量）
#   4) make defconfig 并输出校验信息
#
# 用法: bash scripts/configure.sh <openwrt 源码目录>
#
set -euo pipefail

TOP="${1:-openwrt}"
DEV="${DEVICE:-h3c_magic-nx30-pro-112m}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$TOP"

if [ ! -f defconfig/mt7981-ax3000.config ]; then
	echo "ERROR: 找不到 defconfig/mt7981-ax3000.config" >&2
	exit 1
fi

echo "==> [1/4] 以模板为基准"
cp defconfig/mt7981-ax3000.config .config

echo "==> [2/4] 裁设备列表（只留 ${DEV}）"
before=$(grep -c '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_' .config || true)
sed -i '/^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_/d' .config
sed -i '/^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_/d' .config
echo "    移除设备条目 ${before} 条"
echo "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_${DEV}=y" >> .config

echo "==> [3/4] 叠加增量配置"
cat "$SRC/configs/nx30pro-112m.config" >> .config

echo "==> [4/4] make defconfig"
make defconfig

echo
echo "================= 配置结果 =================="
echo "--- 目标 / 设备 ---"
grep -E '^CONFIG_TARGET_(mediatek|mediatek_filogic)=' .config || true
if grep -q '^CONFIG_TARGET_MULTI_PROFILE=y' .config; then
	echo "MULTI_PROFILE 模式：无 CONFIG_TARGET_PROFILE，改用设备符号校验"
else
	grep -E '^CONFIG_TARGET_PROFILE=' .config || echo "!! CONFIG_TARGET_PROFILE 缺失"
fi
echo "设备条目数: $(grep -c '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y' .config || true)"
grep -E '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y' .config || true
echo "--- 工具链 / 开发选项（按模板保留）---"
grep -E '^CONFIG_(DEVEL|TOOLCHAINOPTS|TARGET_MULTI_PROFILE)=' .config || true
echo "--- WiFi（模板不写 CONFIG_PACKAGE_*，靠设备定义 DEVICE_PACKAGES → MODULE_DEFAULT）---"
grep -E 'mt7915|mt7981-firmware|mt7981-wo|wpad-openssl' .config || echo "（无）"
echo "--- 主题 / 代理 ---"
grep -E '^CONFIG_PACKAGE_(luci-theme-glass|luci-app-nikki|nikki|mihomo|luci-i18n-nikki-zh-cn)=' .config || true
echo "--- 编译缓存 ---"
grep -E '^CONFIG_CCACHE=' .config || true
echo "============================================="

# ---------------- 硬性校验（不通过就退出非 0）----------------
echo
echo "==> 校验"
rc=0
if grep -q '^CONFIG_TARGET_MULTI_PROFILE=y' .config; then
	grep -qx "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_${DEV}=y" .config \
		|| { echo "::error::多 profile 模式下未选中 ${DEV}"; rc=1; }
else
	grep -qx "CONFIG_TARGET_PROFILE=\"DEVICE_${DEV}\"" .config \
		|| { echo "::error::TARGET_PROFILE 不是 ${DEV}"; rc=1; }
fi

n=$(grep -c '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y' .config || true)
[ "$n" = "1" ] || { echo "::error::设备条目应为 1 个，实际 ${n} 个（裁剪失效？）"; rc=1; }

grep -qx 'CONFIG_PACKAGE_luci-theme-glass=y' .config \
	|| { echo "::error::luci-theme-glass 未被选中"; rc=1; }
grep -qx 'CONFIG_PACKAGE_luci-app-nikki=y' .config \
	|| { echo "::error::luci-app-nikki 未被选中"; rc=1; }
grep -qE '^CONFIG_PACKAGE_mihomo(-meta)?=y' .config \
	|| { echo "::error::mihomo 内核未被选中"; rc=1; }

# WiFi：模板不写 CONFIG_PACKAGE_kmod-mt7915e，而是由设备 DEVICE_PACKAGES 生成
# CONFIG_MODULE_DEFAULT_* 。两者任一存在即视为通过。
if grep -qE '^CONFIG_PACKAGE_kmod-mt7915e=y|^CONFIG_MODULE_DEFAULT_kmod-mt7915e=y' .config; then
	echo "WiFi 驱动: 已包含"
else
	echo "::error::WiFi 驱动 kmod-mt7915e 未生效"
	rc=1
fi
if grep -qE '^CONFIG_PACKAGE_mt7981-wo-firmware=y|^CONFIG_MODULE_DEFAULT_mt7981-wo-firmware=y' .config; then
	echo "WiFi 固件: 已包含"
else
	echo "::error::WiFi 固件 mt7981-wo-firmware 未生效"
	rc=1
fi

if [ "$rc" != "0" ]; then
	echo
	echo "--- 诊断 ---"
	grep -E 'h3c|nikki|glass|mihomo|mt79|wpad' .config || true
	exit 1
fi

echo "✅ 配置校验通过"
