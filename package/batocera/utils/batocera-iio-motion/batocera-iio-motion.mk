################################################################################
#
# batocera-iio-motion
#
################################################################################

BATOCERA_IIO_MOTION_VERSION = 1
BATOCERA_IIO_MOTION_SOURCE =
BATOCERA_IIO_MOTION_LICENSE = GPL-3.0+, Apache-2.0
BATOCERA_IIO_MOTION_DEPENDENCIES = zlib

BATOCERA_IIO_MOTION_PATH = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-iio-motion

define BATOCERA_IIO_MOTION_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -std=c11 -Wall -Wextra -Werror \
		$(BATOCERA_IIO_MOTION_PATH)/batocera-iio-motion.c \
		-o $(@D)/batocera-iio-motion \
		$(TARGET_LDFLAGS) -lz -lm
endef

define BATOCERA_IIO_MOTION_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/batocera-iio-motion \
		$(TARGET_DIR)/usr/bin/batocera-iio-motion
	$(INSTALL) -D -m 0755 $(BATOCERA_IIO_MOTION_PATH)/S29iio-motion \
		$(TARGET_DIR)/etc/init.d/S29iio-motion
endef

$(eval $(generic-package))
