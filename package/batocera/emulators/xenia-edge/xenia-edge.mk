################################################################################
#
# xenia-edge
#
################################################################################

XENIA_EDGE_VERSION = 9593224
XENIA_EDGE_SOURCE = xenia_edge_linux.AppImage
XENIA_EDGE_SITE = https://github.com/has207/xenia-edge/releases/download/$(XENIA_EDGE_VERSION)
XENIA_EDGE_LICENSE = BSD
XENIA_EDGE_LICENSE_FILE = LICENSE
XENIA_EDGE_STRIP = NO
XENIA_EDGE_TOOLCHAIN = manual

XENIA_EDGE_DEPENDENCIES = python-toml

define XENIA_EDGE_EXTRACT_CMDS
	cp $(DL_DIR)/$(XENIA_EDGE_DL_SUBDIR)/$(XENIA_EDGE_SOURCE) \
		$(@D)/xenia_edge.AppImage
endef

define XENIA_EDGE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/xenia-edge
	cp $(@D)/xenia_edge.AppImage \
		$(TARGET_DIR)/usr/share/xenia-edge/xenia_edge.AppImage

	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' \
		'#!/bin/sh' \
		'chmod +x /usr/share/xenia-edge/xenia_edge.AppImage 2>/dev/null' \
		'exec /usr/share/xenia-edge/xenia_edge.AppImage "$$@"' \
		> $(TARGET_DIR)/usr/bin/xenia-edge
	chmod 0755 $(TARGET_DIR)/usr/bin/xenia-edge
endef

define XENIA_EDGE_POST_PROCESS
	mkdir -p $(TARGET_DIR)/usr/share/xenia-edge/patches
	mkdir -p $(@D)/temp
	( cd $(@D)/temp && $(GIT) init && \
	  $(GIT) remote add origin https://github.com/xenia-canary/game-patches.git && \
	  $(GIT) config core.sparsecheckout true && \
	  echo "patches/*.toml" >> .git/info/sparse-checkout && \
	  $(GIT) pull --depth=1 origin main && \
	  mv -f patches/*.toml $(TARGET_DIR)/usr/share/xenia-edge/patches \
	)
	rm -rf $(@D)/temp
endef

XENIA_EDGE_POST_INSTALL_TARGET_HOOKS = XENIA_EDGE_POST_PROCESS

$(eval $(generic-package))
