################################################################################
#
# waydroid
#
################################################################################

WAYDROID_VERSION = 1.6.2
WAYDROID_SITE = $(call github,waydroid,waydroid,$(WAYDROID_VERSION))
WAYDROID_LICENSE = GPL-3.0-or-later
WAYDROID_LICENSE_FILES = LICENSE
WAYDROID_DEPENDENCIES = \
	dbus \
	dbus-python \
	dnsmasq \
	iptables \
	lxc \
	python-gbinder \
	python-gobject \
	python3

ifeq ($(BR2_x86_64),y)
WAYDROID_DEPENDENCIES += dialog erofs-utils libcurl p7zip sqlite xterm

define WAYDROID_INSTALL_X86_64_TOOLS
	rm -rf $(TARGET_DIR)/usr/share/batocera/waydroid/libndk
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-arm \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-arm
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-tools \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-tools
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-tools-launcher \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-tools-launcher
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/waydroid-get-android-id \
		$(TARGET_DIR)/usr/bin/waydroid-get-android-id
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/libndk-files.list \
		$(TARGET_DIR)/usr/share/batocera/waydroid/libndk-files.list
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/datainit/bios/waydroid/README.txt \
		$(TARGET_DIR)/usr/share/batocera/waydroid/README.libndk
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/datainit/bios/waydroid/README.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/bios/waydroid/README.txt
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/datainit/bios/waydroid/extract.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/bios/waydroid/extract.sh
	mkdir -p \
		$(TARGET_DIR)/usr/share/batocera/datainit/bios/waydroid/dump_here \
		$(TARGET_DIR)/usr/share/batocera/datainit/bios/waydroid/overlay
endef
endif

define WAYDROID_BUILD_CMDS
	true
endef

define WAYDROID_INSTALL_TARGET_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D) \
		DESTDIR=$(TARGET_DIR) \
		PREFIX=/usr \
		SYSCONFDIR=/etc \
		USE_SYSTEMD=0 \
		USE_DBUS_ACTIVATION=1 \
		USE_NFTABLES=0 \
		install

	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-init \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-init
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-session \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-session
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-postboot \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-postboot
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-app \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-app
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-app-session \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-app-session
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-platform-launch \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-platform-launch
	$(INSTALL) -D -m 0755 $(WAYDROID_PKGDIR)/batocera-waydroid-update \
		$(TARGET_DIR)/usr/bin/batocera-waydroid-update
	rm -f $(TARGET_DIR)/usr/share/batocera/services/waydroid
	rm -f $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-waydroid
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
	ln -sf /usr/bin/batocera-waydroid-update \
		$(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-android

	# Batocera overrides: keep Waydroid LXC session config behavior stable.
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/files/usr/lib/waydroid/tools/helpers/lxc.py \
		$(TARGET_DIR)/usr/lib/waydroid/tools/helpers/lxc.py
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/files/usr/lib/waydroid/tools/services/user_manager.py \
		$(TARGET_DIR)/usr/lib/waydroid/tools/services/user_manager.py
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/files/usr/lib/waydroid/data/configs/config_1 \
		$(TARGET_DIR)/usr/lib/waydroid/data/configs/config_1
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/files/usr/lib/waydroid/data/configs/config_3 \
		$(TARGET_DIR)/usr/lib/waydroid/data/configs/config_3
	$(INSTALL) -D -m 0644 $(WAYDROID_PKGDIR)/android.keys \
		$(TARGET_DIR)/usr/share/evmapy/android.keys
	ln -sf android.keys $(TARGET_DIR)/usr/share/evmapy/waydroid.keys
	$(WAYDROID_INSTALL_X86_64_TOOLS)
endef

$(eval $(generic-package))
