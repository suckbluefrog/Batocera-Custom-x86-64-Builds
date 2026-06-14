################################################################################
#
# batocera userdata init
#
################################################################################

BATOCERA_USERDATAINIT_VERSION = 1.0
BATOCERA_USERDATAINIT_LICENSE = GPL
BATOCERA_USERDATAINIT_SOURCE=

define BATOCERA_USERDATAINIT_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera
	rsync -arv $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-userdatainit/datainit/ $(TARGET_DIR)/usr/share/batocera/datainit/
	if [ "$(BR2_PACKAGE_WAYDROID)" = "y" ]; then \
		mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images; \
		printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'exec /usr/bin/batocera-waydroid-session' \
			> $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Waydroid.sh; \
		chmod 0755 $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Waydroid.sh; \
		install -D -m 0644 \
			$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/waydroid.png \
			$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/waydroid.png; \
		gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/gamelist.xml"; \
		if [ ! -f "$${gamelist}" ]; then \
			printf '%s\n' '<?xml version="1.0"?>' '<gameList>' '</gameList>' > "$${gamelist}"; \
		fi; \
		if ! grep -q '<path>\./Waydroid\.sh</path>' "$${gamelist}"; then \
			sed -i '/<\/gameList>/i\  <game>\n    <path>./Waydroid.sh</path>\n    <name>Waydroid</name>\n    <image>./images/waydroid.png</image>\n  </game>' \
				"$${gamelist}"; \
		fi; \
	else \
		rm -f $(TARGET_DIR)/usr/share/batocera/datainit/roms/tools/Start_Waydroid.sh; \
		rm -f $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Waydroid.sh; \
		rm -f $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/waydroid.png; \
	fi
endef

$(eval $(generic-package))
