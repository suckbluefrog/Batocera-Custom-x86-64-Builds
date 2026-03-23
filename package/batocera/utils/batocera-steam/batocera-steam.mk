# SPDX-FileCopyrightText: 2026 suckbluefrog
################################################################################
#
# batocera-steam
#
################################################################################

BATOCERA_STEAM_VERSION = latest
BATOCERA_STEAM_SOURCE = steam.deb
BATOCERA_STEAM_SITE = https://cdn.cloudflare.steamstatic.com/client/installer

define BATOCERA_STEAM_EXTRACT_CMDS
	mkdir -p $(@D)/steam-bootstrap
	cd $(@D)/steam-bootstrap && \
		ar p $(DL_DIR)/$(BATOCERA_STEAM_DL_SUBDIR)/$(BATOCERA_STEAM_SOURCE) data.tar.xz | \
		tar -xJ ./usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz ./usr/lib/steam/bin_steam.sh
endef

define BATOCERA_STEAM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	mkdir -p $(TARGET_DIR)/usr/share/steam/bootstrap
	mkdir -p $(TARGET_DIR)/etc/init.d

	tar -xJf $(@D)/steam-bootstrap/usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz \
	    -C $(TARGET_DIR)/usr/share/steam/bootstrap
	install -m 0644 $(@D)/steam-bootstrap/usr/lib/steam/bin_steam.sh \
	    $(TARGET_DIR)/usr/share/steam/bin_steam.sh
	if grep -q "# Don't allow running as root" "$(TARGET_DIR)/usr/share/steam/bin_steam.sh"; then \
		awk 'BEGIN{skip=0} /# Don'\''t allow running as root/{skip=5} {if(skip>0){skip--;next} print}' \
		    "$(TARGET_DIR)/usr/share/steam/bin_steam.sh" > "$(TARGET_DIR)/usr/share/steam/bin_steam.sh.tmp"; \
		mv "$(TARGET_DIR)/usr/share/steam/bin_steam.sh.tmp" "$(TARGET_DIR)/usr/share/steam/bin_steam.sh"; \
	fi
	chmod 0755 "$(TARGET_DIR)/usr/share/steam/bin_steam.sh"
	ln -sf ../share/steam/bin_steam.sh $(TARGET_DIR)/usr/bin/bin_steam.sh
	ln -sf ../share/steam/bin_steam.sh $(TARGET_DIR)/usr/bin/bin_steam

	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-users \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-session \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-displaymanager-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-networkmanager-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-login1-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-consolekit-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-desktop-switch \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-desktop-launcher \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-uimode-watch \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/steam-direct-session.sh \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/steamos-session-select \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-decky-install \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-update \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/S92steam-hotkeys-reset \
	    $(TARGET_DIR)/etc/init.d/S92steam-hotkeys-reset

	mkdir -p $(TARGET_DIR)/etc/dbus-1/system.d
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.DisplayManager.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.NetworkManager.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.login1.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.ConsoleKit.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/

	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
	ln -sf /usr/bin/batocera-steam-update \
	    $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-steam
endef

$(eval $(generic-package))
