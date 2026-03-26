################################################################################
#
# shadps4-pkg-extractor
#
################################################################################

SHADPS4_PKG_EXTRACTOR_VERSION = PKG_EXTRACTOR_1_1
SHADPS4_PKG_EXTRACTOR_SITE = https://github.com/AzaharPlus/shadPS4Plus/releases/download/$(SHADPS4_PKG_EXTRACTOR_VERSION)
SHADPS4_PKG_EXTRACTOR_SOURCE = ShadPs4Plus-PkgExtractor-1.1-linux.zip
SHADPS4_PKG_EXTRACTOR_LICENSE = GPL-2.0-only

define SHADPS4_PKG_EXTRACTOR_EXTRACT_CMDS
	mkdir -p $(@D)/source
	unzip -q $(DL_DIR)/$(SHADPS4_PKG_EXTRACTOR_DL_SUBDIR)/$(SHADPS4_PKG_EXTRACTOR_SOURCE) -d $(@D)/source
endef

define SHADPS4_PKG_EXTRACTOR_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/shadps4-pkg-extractor
	install -m 0644 \
		$(@D)/source/ShadPs4Plus-PkgExtractor-1.1-linux/pkg_extractor.AppImage \
		$(TARGET_DIR)/usr/share/shadps4-pkg-extractor/pkg_extractor.AppImage
	install -m 0644 \
		$(@D)/source/ShadPs4Plus-PkgExtractor-1.1-linux/readme_linux.txt \
		$(TARGET_DIR)/usr/share/shadps4-pkg-extractor/readme_linux.txt

	mkdir -p $(TARGET_DIR)/usr/bin
	install -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/shadps4-pkg-extractor/shadps4-pkg-extractor \
		$(TARGET_DIR)/usr/bin/shadps4-pkg-extractor
endef

$(eval $(generic-package))
