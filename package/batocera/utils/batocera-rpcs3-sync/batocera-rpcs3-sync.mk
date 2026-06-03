################################################################################
#
# batocera-rpcs3-sync
#
################################################################################

BATOCERA_RPCS3_SYNC_VERSION = 1.0
BATOCERA_RPCS3_SYNC_SOURCE =
BATOCERA_RPCS3_SYNC_LICENSE = Proprietary
BATOCERA_RPCS3_SYNC_PKGDIR = \
	$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-rpcs3-sync

define BATOCERA_RPCS3_SYNC_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	install -m 0755 \
		$(BATOCERA_RPCS3_SYNC_PKGDIR)/batocera-rpcs3-sync \
		$(TARGET_DIR)/usr/bin/batocera-rpcs3-sync
	install -m 0755 \
		$(BATOCERA_RPCS3_SYNC_PKGDIR)/batocera-rpcs3-sync-onchange \
		$(TARGET_DIR)/usr/bin/batocera-rpcs3-sync-onchange
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
	ln -sf /usr/bin/batocera-rpcs3-sync-onchange \
		$(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-rpcs3
endef

$(eval $(generic-package))
