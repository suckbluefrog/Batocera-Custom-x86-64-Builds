################################################################################
#
# opengoal
#
################################################################################

OPENGOAL_VERSION = v0.3.3
OPENGOAL_SITE = https://github.com/open-goal/jak-project/releases/download/$(OPENGOAL_VERSION)
OPENGOAL_SOURCE = opengoal-linux-$(OPENGOAL_VERSION).tar.gz
OPENGOAL_LICENSE = ISC

OPENGOAL_DEPENDENCIES += zlib

define OPENGOAL_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/opengoal
	cp -a $(@D)/gk $(@D)/goalc $(@D)/extractor $(@D)/data \
		$(TARGET_DIR)/usr/lib/opengoal/
	$(INSTALL) -D -m 0755 $(OPENGOAL_PKGDIR)/opengoal-wrapper \
		$(TARGET_DIR)/usr/bin/opengoal
	$(INSTALL) -D -m 0644 $(OPENGOAL_PKGDIR)/_info.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/opengoal/_info.txt
	$(INSTALL) -D -m 0644 $(OPENGOAL_PKGDIR)/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/opengoal/gamelist.xml
endef

$(eval $(generic-package))
