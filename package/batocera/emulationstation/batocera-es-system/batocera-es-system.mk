################################################################################
#
# batocera-es-system
#
################################################################################

BATOCERA_ES_SYSTEM_VERSION=1.04a
BATOCERA_ES_SYSTEM_SOURCE=

BATOCERA_ES_SYSTEM_DEPENDENCIES = host-python3 host-python-pyyaml batocera-configgen host-gettext
BATOCERA_ES_SYSTEM_GUI_LAUNCHERS = \
	Configure_Azahar.sh \
	Configure_Cemu.sh \
	Configure_Dolphin.sh \
	Configure_DuckStation.sh \
	Configure_Eden.sh \
	Configure_Flycast.sh \
	Configure_PCSX2.sh \
	Configure_PPSSPP.sh \
	Configure_Play.sh \
	Configure_RPCS3.sh \
	Configure_RetroArch.sh \
	Configure_Ryujinx.sh \
	Configure_ScummVM.sh \
	Configure_Vita3K.sh \
	Configure_Xenia.sh \
	Configure_Xenia_Canary.sh \
	Configure_Xenia_Edge.sh \
	Configure_Yuzu.sh \
	File_Manager.sh

BATOCERA_ES_SYSTEM_LOCALES_DIR=$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/locales

ifeq ($(BR2_PACKAGE_BATOCERA_WINE),y)
BATOCERA_ES_SYSTEM_DEPENDENCIES += batocera-wine

define BATOCERA_ES_SYSTEM_INSTALL_WINE_TOOLS
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine/datainit/roms/emulator/Wine_Tools.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Wine_Tools.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine/datainit/roms/emulator/Wine_Tools.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Wine_Tools.sh.keys
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/wine-tools.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/wine-tools.png
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Wine_Tools.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Wine_Tools.sh</path>"; \
			print "    <name>Wine Tools</name>"; \
			print "    <image>./images/wine-tools.png</image>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
endif

define BATOCERA_ES_SYSTEM_BUILD_CMDS
	$(HOST_DIR)/bin/python \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/batocera-es-system.py \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/es_systems.yml        \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/es_features.yml       \
		$(@D)/es_external_translations.h \
		$(@D)/es_keys_translations.h \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/locales/blacklisted-words.txt \
		$(CONFIG_DIR)/.config \
		$(@D)/es_systems.cfg \
		$(@D)/es_features.cfg \
		$(STAGING_DIR)/usr/share/batocera/configgen/configgen-defaults.yml \
		$(STAGING_DIR)/usr/share/batocera/configgen/configgen-defaults-arch.yml \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/roms \
		$(@D)/roms $(BATOCERA_SYSTEM_ARCH)

	# Translation files are maintained in-tree; /build/package is read-only.
	# Validate existing translations without regenerating or merging them.
	for PO in $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/locales/*/batocera-es-system.po; do \
		printf "%s " $$(basename $$(dirname $${PO})) && \
		LANG=C msgfmt -o /dev/null $${PO} --statistics || exit 1; \
	done
	# install staging
	mkdir -p $(STAGING_DIR)/usr/share/batocera-es-system/locales
	cp $(@D)/es_external_translations.h $(STAGING_DIR)/usr/share/batocera-es-system/
	cp $(@D)/es_keys_translations.h $(STAGING_DIR)/usr/share/batocera-es-system/
	cp -pr $(BATOCERA_ES_SYSTEM_LOCALES_DIR) $(STAGING_DIR)/usr/share/batocera-es-system/
endef

define BATOCERA_ES_SYSTEM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit
	$(INSTALL) -m 0644 -D $(@D)/es_systems.cfg $(TARGET_DIR)/usr/share/emulationstation/es_systems.cfg
	$(INSTALL) -m 0644 -D $(@D)/es_features.cfg $(TARGET_DIR)/usr/share/emulationstation/es_features.cfg
	mkdir -p $(@D)/roms # in case there is no rom
	# Drop stale emulator-launcher datainit files from incremental target trees.
	rm -rf $(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator
	# Drop stale Steam datainit files from incremental target trees.
	rm -rf $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam
	cp -pr $(@D)/roms $(TARGET_DIR)/usr/share/batocera/datainit/
	for launcher in $(BATOCERA_ES_SYSTEM_GUI_LAUNCHERS); do \
		if [ -f "$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/$${launcher}" ]; then \
			$(INSTALL) -m 0644 \
				$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/gui-launcher.keys \
				$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/$${launcher}.keys; \
		fi; \
	done
	$(BATOCERA_ES_SYSTEM_INSTALL_WINE_TOOLS)
endef

$(eval $(generic-package))
