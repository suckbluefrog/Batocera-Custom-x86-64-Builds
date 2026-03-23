################################################################################
#
# libretro-citra
#
################################################################################
# Version: Commits on Aug 17, 2025
LIBRETRO_CITRA_VERSION = 5263fae3344e5e9af43036e0e38bec2d10fb2407
LIBRETRO_CITRA_SITE = https://github.com/libretro/citra.git
LIBRETRO_CITRA_SITE_METHOD = git
LIBRETRO_CITRA_GIT_SUBMODULES = YES
LIBRETRO_CITRA_LICENSE = GPLv2
LIBRETRO_CITRA_DEPENDENCIES = retroarch
LIBRETRO_CITRA_EMULATOR_INFO = citra.libretro.core.yml

LIBRETRO_CITRA_PLATFORM = $(LIBRETRO_PLATFORM)
LIBRETRO_CITRA_EXTRA_ARGS = HAVE_RPC=0
LIBRETRO_CITRA_EXTRA_ARGS += DEFINES+='-DHAVE_LIBRETRO -DUSING_GLES -DZSTD_DISABLE_ASM'

ifeq ($(BR2_x86_64),y)
LIBRETRO_CITRA_EXTRA_ARGS += ARCH=x86_64
else ifeq ($(BR2_i386),y)
LIBRETRO_CITRA_EXTRA_ARGS += ARCH=x86
else ifeq ($(BR2_aarch64),y)
LIBRETRO_CITRA_EXTRA_ARGS += ARCH=aarch64
endif

define LIBRETRO_CITRA_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
		-C $(@D) -f Makefile platform="$(LIBRETRO_CITRA_PLATFORM)" \
		$(LIBRETRO_CITRA_EXTRA_ARGS)
endef

define LIBRETRO_CITRA_FIXUP_SOURCES
	$(SED) '\|common/misc.cpp|d' $(@D)/Makefile.common
	$(SED) '/core\/hle\/service\/boss\/boss_u.cpp/a\               $$(SRC_DIR)\/core\/hle\/service\/boss\/online_service.cpp \\' $(@D)/Makefile.common
endef

LIBRETRO_CITRA_POST_PATCH_HOOKS += LIBRETRO_CITRA_FIXUP_SOURCES

define LIBRETRO_CITRA_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/citra_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/citra_libretro.so
endef

$(eval $(generic-package))
$(eval $(emulator-info-package))
