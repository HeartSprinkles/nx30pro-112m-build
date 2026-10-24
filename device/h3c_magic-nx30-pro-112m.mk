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
  DEVICE_PACKAGES :=
endef
TARGET_DEVICES += h3c_magic-nx30-pro-112m
