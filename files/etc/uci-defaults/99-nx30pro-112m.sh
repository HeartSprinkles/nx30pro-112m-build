#!/bin/sh
#
# 首次启动的默认设置：简体中文界面
#
[ -f /etc/config/luci ] || exit 0

uci -q batch <<-EOF
	set luci.main.lang='zh_cn'
	commit luci
EOF

exit 0
