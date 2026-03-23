################################################################################
#
# yuzu (AppImage)
#
################################################################################

YUZU_VERSION = EA-4176
YUZU_LICENSE = GPL-2.0
YUZU_STRIP = NO
YUZU_TOOLCHAIN = manual

YUZU_SITE = https://archive.org/download/citra-linux-appimage-20240304-d996981.7z
YUZU_SOURCE = Linux-Yuzu-EA-4176.AppImage

################################################################################
# Extract
################################################################################

define YUZU_EXTRACT_CMDS
	cp $(DL_DIR)/$(YUZU_DL_SUBDIR)/$(YUZU_SOURCE) \
		$(@D)/yuzu.AppImage
endef

################################################################################
# Install
################################################################################

define YUZU_INSTALL_TARGET_CMDS
	# Install AppImage to non-ELF-scanned location
	mkdir -p $(TARGET_DIR)/usr/share/yuzu
	cp $(@D)/yuzu.AppImage \
		$(TARGET_DIR)/usr/share/yuzu/yuzu.AppImage

	# Wrapper (exec-time chmod avoids fix-rpath)
	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' \
		'#!/bin/sh' \
		'chmod +x /usr/share/yuzu/yuzu.AppImage 2>/dev/null' \
		'exec /usr/share/yuzu/yuzu.AppImage "$$@"' \
		> $(TARGET_DIR)/usr/bin/yuzu
	chmod 0755 $(TARGET_DIR)/usr/bin/yuzu
endef

$(eval $(generic-package))
