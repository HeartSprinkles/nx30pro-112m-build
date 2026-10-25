#-------------------------------------------------------------
# H3C Magic NX30 Pro - 112M large partition layout
# Appended to target/linux/mediatek/image/filogic.mk at build time
#
# Cloned from Device/h3c_magic-nx30-pro (OpenWrt U-Boot layout), the only
# differences are DEVICE_DTS, IMAGE_SIZE and the DTS file itself.
#
# IMAGE_SIZE == size of the ubi partition (0x7000000 = 112M = 114688k),
# same convention as the stock definition (0x4000000 = 64M = 65536k).
#-------------------------------------------------------------
define Device/h3c_magic-nx30-pro-112m
  DEVICE_VENDOR := H3C
  DEVICE_MODEL := Magic NX30 Pro
  DEVICE_VARIANT := (112M OpenWrt U-Boot layout)
  DEVICE_DTS := mt7981b-h3c-magic-nx30-pro-112m
  DEVICE_DTS_DIR := ../dts
  SUPPORTED_DEVICES := h3c,magic-nx30-pro
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  KERNEL_IN_UBI := 1
  UBOOTENV_IN_UBI := 1
  IMAGE_SIZE := 114688k
  IMAGES := sysupgrade.itb
  KERNEL_INITRAMFS_SUFFIX := -recovery.itb
  KERNEL := kernel-bin | gzip
  KERNEL_INITRAMFS := kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  IMAGE/sysupgrade.itb := append-kernel | \
	fit gzip $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb external-static-with-rootfs | append-metadata
  # WiFi 用 MTK 闭源驱动（mtk-openwrt-feeds 的 mt_wifi），不是开源 mt76。
  # 相关开关由 defconfig 模板统一打开，对所有设备生效，所以这里保持空：
  #   CONFIG_PACKAGE_kmod-mt_wifi=y            （KernelPackage/mt_wifi）
  #   CONFIG_MTK_CHIP_MT7981=y
  #   CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673=y
  #   CONFIG_MTK_MT_WIFI_FIRMWARE_PATH_MT7981="mt7981-fw-20260601"
  #   CONFIG_PACKAGE_mtwifi-cfg-ucode=y
  #   CONFIG_PACKAGE_luci-app-mtwifi-cfg=y
  # ⚠️ 不要再加 kmod-mt7915e / kmod-mt7981-firmware / mt7981-wo-firmware：
  #    mt76 与 mt_wifi 会抢同一个 WiFi 硬件，导致两边都起不来。
  DEVICE_PACKAGES :=
endef
TARGET_DEVICES += h3c_magic-nx30-pro-112m
