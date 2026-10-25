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
grep -E '^CONFIG_TARGET_PROFILE=' .config || echo "!! CONFIG_TARGET_PROFILE 缺失"
echo "设备条目数: $(grep -c '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_.*=y' .config || true)"
echo "--- 工具链 / 开发选项（按模板保留）---"
grep -E '^CONFIG_(DEVEL|TOOLCHAINOPTS|TARGET_MULTI_PROFILE)=' .config || true
echo "--- WiFi（预期：.config 里没有，靠设备定义 DEVICE_PACKAGES 带入）---"
grep -E 'mt7915|mt7981-firmware|mt7981-wo|wpad' .config || echo "（.config 中无 WiFi 包，符合预期）"
echo "--- 主题 / 代理 ---"
grep -E '^CONFIG_PACKAGE_(luci-theme-glass|luci-app-nikki|nikki|mihomo|luci-i18n-nikki-zh-cn)=' .config || true
echo "--- 编译缓存 ---"
grep -E '^CONFIG_CCACHE=' .config || true
echo "============================================="
