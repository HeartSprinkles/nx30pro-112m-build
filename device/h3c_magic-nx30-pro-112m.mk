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
  # 上游 Device/h3c_magic-nx30-pro 的 DEVICE_PACKAGES 是空的，直接照抄会导致
  # 固件里没有任何 WiFi 驱动/固件（LuCI 里看不到"无线"菜单）。
  # 这里补上 MT7981 的标准三件套（同类设备 asus_rt-ax57m / cudy_m3000 等都是这么写的）。
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
endef
TARGET_DEVICES += h3c_magic-nx30-pro-112m
