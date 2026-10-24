#!/bin/bash
#
# 把 112M 大分区支持应用到 OpenWrt/ImmortalWrt 源码树
#
# 用法: bash scripts/apply-nx30pro-112m.sh <源码目录>
#
set -euo pipefail

TOP="${1:-openwrt}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$TOP/target/linux/mediatek" ]; then
	echo "ERROR: '$TOP' 不是一个 ImmortalWrt 源码树" >&2
	exit 1
fi

echo "==> [1/4] 安装 112M DTS"
install -m 0644 "$SRC/dts/mt7981b-h3c-magic-nx30-pro-112m.dts" \
	"$TOP/target/linux/mediatek/dts/mt7981b-h3c-magic-nx30-pro-112m.dts"

echo "==> [2/4] 注册新设备 h3c_magic-nx30-pro-112m"
FILOGIC_MK="$TOP/target/linux/mediatek/image/filogic.mk"
if grep -q 'Device/h3c_magic-nx30-pro-112m' "$FILOGIC_MK"; then
	echo "    已存在，跳过"
else
	printf '\n' >> "$FILOGIC_MK"
	cat "$SRC/device/h3c_magic-nx30-pro-112m.mk" >> "$FILOGIC_MK"
fi

echo "==> [3/4] 安装自定义 files/ (默认主题、中文等)"
mkdir -p "$TOP/files"
cp -a "$SRC/files/." "$TOP/files/"

echo "==> [4/4] 给 NX30 Pro 的 MAC 获取加降级链"
# 112M 布局不再保留 pdt_data_1 分区，而 stock 的 02_network 正是从
# pdt_data_1 里读 ASCII 文件 ethaddr 来取 MAC 的。这里追加
# Factory / u-boot 环境变量 的降级读取，避免刷机后 MAC 随机。
NET="$TOP/target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
if [ -f "$NET" ]; then
	python3 - "$NET" <<'PY'
import sys, io

path = sys.argv[1]
old = "mtd_get_mac_ascii pdt_data_1 ethaddr"
new = ("mtd_get_mac_ascii pdt_data_1 ethaddr 2>/dev/null || "
       "mtd_get_mac_ascii Factory ethaddr 2>/dev/null || "
       "fw_printenv -n ethaddr 2>/dev/null")

with io.open(path, "r", encoding="utf-8") as f:
    src = f.read()

if new in src:
    print("    已打过补丁，跳过")
elif old not in src:
    print("    WARNING: 未找到 '%s'，02_network 结构可能已变化" % old)
    sys.exit(0)
else:
    src = src.replace(old, new)
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print("    已打补丁: %s" % path)
PY
else
	echo "    WARNING: 未找到 $NET，跳过"
fi

echo "==> 完成"
