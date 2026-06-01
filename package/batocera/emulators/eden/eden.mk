################################################################################
#
# eden
#
################################################################################

EDEN_VERSION = refs/tags/v0.2.0
EDEN_LICENSE = GPL-3.0-or-later
EDEN_LICENSE_FILES = LICENSES/GPL-3.0-or-later.txt
EDEN_SITE = https://git.eden-emu.dev/eden-emu/eden.git
EDEN_SITE_METHOD = git
EDEN_SUPPORTS_IN_SOURCE_BUILD = NO

EDEN_DEPENDENCIES = host-pkgconf boost enet ffmpeg fmt json-for-modern-cpp libopenssl \
	opus qt6base qt6charts sdl2 vulkan-headers vulkan-loader vulkan-utility-libraries \
	zlib zstd

EDEN_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
EDEN_CONF_OPTS += -DBUILD_TESTING=OFF
EDEN_CONF_OPTS += -DYUZU_TESTS=OFF
EDEN_CONF_OPTS += -DENABLE_QT=ON
EDEN_CONF_OPTS += -DENABLE_QT_TRANSLATION=OFF
EDEN_CONF_OPTS += -DENABLE_UPDATE_CHECKER=OFF
EDEN_CONF_OPTS += -DENABLE_WEB_SERVICE=OFF
EDEN_CONF_OPTS += -DUSE_DISCORD_PRESENCE=OFF
EDEN_CONF_OPTS += -DENABLE_LIBUSB=OFF
EDEN_CONF_OPTS += -DENABLE_WIFI_SCAN=OFF
EDEN_CONF_OPTS += -DENABLE_CUBEB=OFF
EDEN_CONF_OPTS += -DYUZU_USE_BUNDLED_QT=OFF
EDEN_CONF_OPTS += -DYUZU_USE_BUNDLED_SDL2=OFF
EDEN_CONF_OPTS += -DYUZU_USE_EXTERNAL_SDL2=OFF
EDEN_CONF_OPTS += -DYUZU_USE_BUNDLED_FFMPEG=OFF
EDEN_CONF_OPTS += -DYUZU_USE_EXTERNAL_FFMPEG=OFF
EDEN_CONF_OPTS += -DYUZU_USE_BUNDLED_OPENSSL=OFF
EDEN_CONF_OPTS += -DYUZU_USE_QT_MULTIMEDIA=OFF
EDEN_CONF_OPTS += -DYUZU_USE_QT_WEB_ENGINE=OFF

define EDEN_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	find $(@D) -maxdepth 5 -name "eden" -type f -perm /111 \
		| head -1 \
		| xargs -I{} $(INSTALL) -D -m 0755 {} $(TARGET_DIR)/usr/bin/eden

	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	cp -prn $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/switch.eden.keys \
		$(TARGET_DIR)/usr/share/evmapy/
endef

$(eval $(cmake-package))
