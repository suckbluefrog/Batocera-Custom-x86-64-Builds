################################################################################
#
# fex-emu
#
################################################################################

FEX_EMU_VERSION = FEX-2603
FEX_EMU_SITE = https://github.com/FEX-Emu/FEX.git
FEX_EMU_SITE_METHOD = git
FEX_EMU_GIT_SUBMODULES = YES
FEX_EMU_LICENSE = MIT
FEX_EMU_LICENSE_FILES = LICENSE
FEX_EMU_SUPPORTS_IN_SOURCE_BUILD = NO

FEX_EMU_DEPENDENCIES += host-clang llvm openssl squashfs squashfuse

FEX_EMU_CMAKE_BACKEND = ninja

# Use clang (FEX requires it)
FEX_EMU_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
FEX_EMU_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
FEX_EMU_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lstdc++ -lm"
FEX_EMU_CONF_OPTS += -DCMAKE_CROSSCOMPILING=ON
FEX_EMU_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
FEX_EMU_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr
FEX_EMU_CONF_OPTS += -DUSE_LINKER=lld
FEX_EMU_CONF_OPTS += -DENABLE_LTO=True
FEX_EMU_CONF_OPTS += -DBUILD_TESTING=False
FEX_EMU_CONF_OPTS += -DENABLE_ASSERTIONS=False
FEX_EMU_CONF_OPTS += -DBUILD_FEXCONFIG=False
FEX_EMU_CONF_OPTS += -DBUILD_TESTS=False
FEX_EMU_CONF_OPTS += -DENABLE_JEMALLOC=False
FEX_EMU_CONF_OPTS += -DUSE_NATIVE_INSTRUCTIONS=OFF

define FEX_EMU_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) DESTDIR=$(TARGET_DIR) \
		$(HOST_DIR)/bin/cmake --install $(FEX_EMU_BUILDDIR)

	# ── Init script (binfmt_misc registration) ──
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/S30fex-emu \
		$(TARGET_DIR)/etc/init.d/S30fex-emu

endef

$(eval $(cmake-package))
