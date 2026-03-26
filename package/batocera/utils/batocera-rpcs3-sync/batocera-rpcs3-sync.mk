################################################################################
#
# batocera-rpcs3-sync
#
################################################################################

BATOCERA_RPCS3_SYNC_VERSION = 1.0
BATOCERA_RPCS3_SYNC_SOURCE =
BATOCERA_RPCS3_SYNC_LICENSE = Proprietary

define BATOCERA_RPCS3_SYNC_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	install -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/batocera-rpcs3-sync \
		$(TARGET_DIR)/usr/bin/batocera-rpcs3-sync
endef

$(eval $(generic-package))
