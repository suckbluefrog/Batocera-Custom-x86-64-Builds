################################################################################
#
# unleashedrecomp
#
################################################################################

UNLEASHED_RECOMP_VERSION = v1.0.3
UNLEASHED_RECOMP_SITE = https://github.com/hedge-dev/UnleashedRecomp/releases/download/$(UNLEASHED_RECOMP_VERSION)
UNLEASHED_RECOMP_SOURCE = UnleashedRecomp-Flatpak.zip
UNLEASHED_RECOMP_LICENSE = GPL-3.0

UNLEASHED_RECOMP_DEPENDENCIES += libgtk3 vulkan-loader flatpak
UNLEASHED_RECOMP_FLATPAK = $(TARGET_DIR)/usr/bin/flatpak
UNLEASHED_RECOMP_TARGET_LD = $(TARGET_DIR)/lib/ld-linux-x86-64.so.2
UNLEASHED_RECOMP_TARGET_LIBPATH = $(TARGET_DIR)/lib:$(TARGET_DIR)/usr/lib
UNLEASHED_RECOMP_TARGET_ENV = \
	PATH="$(TARGET_DIR)/usr/bin:$(TARGET_DIR)/bin:$(PATH)"

define UNLEASHED_RECOMP_EXTRACT_CMDS
	unzip -q -o $(DL_DIR)/$(UNLEASHED_RECOMP_DL_SUBDIR)/$(UNLEASHED_RECOMP_SOURCE) -d $(@D)
endef

define UNLEASHED_RECOMP_INSTALL_TARGET_CMDS
	test -n "$(UNLEASHED_RECOMP_FLATPAK)"
	rm -rf $(@D)/flatpak-home $(@D)/flatpak-config $(@D)/flatpak-data
	mkdir -p $(@D)/flatpak-home $(@D)/flatpak-config $(@D)/flatpak-data
	$(UNLEASHED_RECOMP_TARGET_ENV) \
	HOME=$(@D)/flatpak-home \
	XDG_CONFIG_HOME=$(@D)/flatpak-config \
	XDG_DATA_HOME=$(@D)/flatpak-data \
		$(UNLEASHED_RECOMP_TARGET_LD) \
		--library-path "$(UNLEASHED_RECOMP_TARGET_LIBPATH)" \
		$(UNLEASHED_RECOMP_FLATPAK) install --user --noninteractive --no-deps \
		$(@D)/io.github.hedge_dev.unleashedrecomp.flatpak
	$(INSTALL) -D -m 0755 \
		$$(find $(@D)/flatpak-data/flatpak/app/io.github.hedge_dev.unleashedrecomp -path '*/files/bin/UnleashedRecomp' -print -quit) \
		$(TARGET_DIR)/usr/lib/unleashedrecomp/UnleashedRecomp
	$(SED) 's#/var/data#/userdata#g' \
		$(TARGET_DIR)/usr/lib/unleashedrecomp/UnleashedRecomp
	$(INSTALL) -D -m 0755 $(UNLEASHED_RECOMP_PKGDIR)/unleashedrecomp-wrapper \
		$(TARGET_DIR)/usr/bin/unleashedrecomp
	$(INSTALL) -D -m 0644 $(UNLEASHED_RECOMP_PKGDIR)/_info.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/unleashedrecomp/_info.txt
	$(INSTALL) -D -m 0644 $(UNLEASHED_RECOMP_PKGDIR)/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/unleashedrecomp/gamelist.xml
	icon="$$(find $(@D)/flatpak-data -type f -name 'io.github.hedge_dev.unleashedrecomp.png' -print 2>/dev/null | sort -V | tail -n 1)"; \
	if [ -n "$$icon" ]; then \
		$(INSTALL) -D -m 0644 "$$icon" \
			$(TARGET_DIR)/usr/share/batocera/datainit/roms/unleashedrecomp/images/unleashedrecomp.png; \
	fi
	touch "$(TARGET_DIR)/usr/share/batocera/datainit/roms/unleashedrecomp/Sonic Unleashed Recompiled.unleashedrecomp"
endef

$(eval $(generic-package))
