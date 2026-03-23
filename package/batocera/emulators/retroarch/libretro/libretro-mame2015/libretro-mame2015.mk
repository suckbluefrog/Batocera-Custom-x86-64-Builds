################################################################################
#
# libretro-mame2015
#
################################################################################

LIBRETRO_MAME2015_VERSION = 316cd06349f2b34b4719f04f7c0d07569a74c764
LIBRETRO_MAME2015_SITE = $(call github,libretro,mame2015-libretro,$(LIBRETRO_MAME2015_VERSION))
LIBRETRO_MAME2015_LICENSE = MAME

LIBRETRO_MAME2015_PLATFORM = $(LIBRETRO_PLATFORM)

ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2836),y)
LIBRETRO_MAME2015_PLATFORM = rpi2
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2837),y)
LIBRETRO_MAME2015_PLATFORM = rpi3_64
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2711),y)
LIBRETRO_MAME2015_PLATFORM = rpi4
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2712),y)
LIBRETRO_MAME2015_PLATFORM = rpi5
else ifeq ($(BR2_aarch64),y)
LIBRETRO_MAME2015_PLATFORM = unix
else ifeq ($(BR2_arm),y)
LIBRETRO_MAME2015_PLATFORM = armv
endif

ifeq ($(BR2_x86_64),y)
LIBRETRO_MAME2015_EXTRA_ARGS = PTR64=1 AMD64=1
endif

define LIBRETRO_MAME2015_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CXX)" LD="$(TARGET_CXX)" \
		-C $(@D)/ -f Makefile platform="$(LIBRETRO_MAME2015_PLATFORM)" \
		$(LIBRETRO_MAME2015_EXTRA_ARGS)
endef

define LIBRETRO_MAME2015_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/mame2015_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/mame0160_libretro.so
endef

$(eval $(generic-package))
