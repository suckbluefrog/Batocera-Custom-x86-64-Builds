#
# This file is part of the batocera distribution (https://batocera.org).
# Copyright (c) 2025+.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# YOU MUST KEEP THIS HEADER AS IT IS
#
################################################################################
#
# shadps4
#
################################################################################

SHADPS4_VERSION = v.0.15.0
SHADPS4_SITE = https://github.com/shadps4-emu/shadPS4
SHADPS4_SITE_METHOD = git
#SHADPS4_GIT_SUBMODULES = YES

SHADPS4_SOURCE = shadps4-$(SHADPS4_VERSION).tar.gz
SHADPS4_SUBMODULE_STAMP = $(SHADPS4_DL_DIR)/.shadps4_submodules_fixed_$(SHADPS4_VERSION)

SHADPS4_LICENSE = GPLv2
SHADPS4_LICENSE_FILE = LICENSE

SHADPS4_SUPPORTS_IN_SOURCE_BUILD = NO

SHADPS4_DEPENDENCIES += host-shadps4 alsa-lib pulseaudio openal openssl libzlib
SHADPS4_DEPENDENCIES += libedit udev libevdev jack2 vulkan-headers vulkan-loader
SHADPS4_DEPENDENCIES += vulkan-validationlayers sdl3

SHADPS4_CMAKE_BACKEND = ninja
# Use clang for performance
SHADPS4_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
SHADPS4_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
SHADPS4_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lm -lstdc++"

SHADPS4_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
SHADPS4_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr
SHADPS4_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
SHADPS4_CONF_OPTS += -DENABLE_DISCORD_RPC=OFF
SHADPS4_CONF_OPTS += -DENABLE_UPDATER=OFF
SHADPS4_CONF_OPTS += -DVMA_ENABLE_INSTALL=ON

# Fix MoltenVK submodule bug
define SHADPS4_FIX_AND_FETCH_SUBMODULES
    flock $(SHADPS4_DL_DIR)/.shadps4.lock -c ' \
    set -e; \
    tar_listing_file="$$(mktemp)"; \
    cleanup() { rm -f "$$tar_listing_file"; }; \
    trap cleanup EXIT; \
    if [ -f $(SHADPS4_SUBMODULE_STAMP) ] && \
       [ -f $(SHADPS4_DL_DIR)/$(SHADPS4_SOURCE) ] && \
       tar -tzf $(SHADPS4_DL_DIR)/$(SHADPS4_SOURCE) > "$$tar_listing_file" && \
       git -C $(SHADPS4_DL_DIR)/git config -f .gitmodules --get-regexp "^submodule\\..*\\.path$$" | \
       while read -r _ submodule_path; do \
           grep -Eq "^(\./)?$${submodule_path}/.+" "$$tar_listing_file"; \
       done; then \
        echo "shadPS4 source tarball already contains populated submodules. Skipping..."; \
    else \
        echo "Acquired lock. Refreshing shadPS4 submodules..."; \
        cd $(SHADPS4_DL_DIR)/git && git submodule absorbgitdirs; \
        cd $(SHADPS4_DL_DIR)/git && (git rm --cached -rf externals/MoltenVK || true); \
        cd $(SHADPS4_DL_DIR)/git && (git config --file .gitmodules --remove-section submodule.externals/MoltenVK || true); \
        rm -rf $(SHADPS4_DL_DIR)/git/externals/MoltenVK; \
        rm -rf $(SHADPS4_DL_DIR)/git/.git/modules/externals/MoltenVK; \
        cd $(SHADPS4_DL_DIR)/git && git submodule sync --recursive; \
        cd $(SHADPS4_DL_DIR)/git && git config -f .gitmodules --name-only --get-regexp "^submodule\\..*\\.path$$" | \
            while read -r submodule_key; do \
                git config "$${submodule_key%.path}.shallow" false; \
            done; \
        cd $(SHADPS4_DL_DIR)/git && git submodule update --init --recursive --checkout; \
        cd $(SHADPS4_DL_DIR)/git && git submodule foreach --recursive "git checkout -f HEAD >/dev/null"; \
        cd $(SHADPS4_DL_DIR)/git && git config -f .gitmodules --get-regexp "^submodule\\..*\\.path$$" | \
            while read -r _ submodule_path; do \
                find "$${submodule_path}" -mindepth 1 -not -name .git -print -quit | grep -q .; \
            done; \
        echo "Creating source tarball..."; \
        rm -f $(SHADPS4_DL_DIR)/$(SHADPS4_SOURCE); \
        tar --exclude=.git -czf $(SHADPS4_DL_DIR)/$(SHADPS4_SOURCE) -C $(SHADPS4_DL_DIR)/git .; \
        tar -tzf $(SHADPS4_DL_DIR)/$(SHADPS4_SOURCE) > "$$tar_listing_file"; \
        git -C $(SHADPS4_DL_DIR)/git config -f .gitmodules --get-regexp "^submodule\\..*\\.path$$" | \
            while read -r _ submodule_path; do \
                grep -Eq "^(\./)?$${submodule_path}/.+" "$$tar_listing_file"; \
            done; \
        touch $(SHADPS4_SUBMODULE_STAMP); \
    fi'
endef

HOST_SHADPS4_POST_DOWNLOAD_HOOKS = SHADPS4_FIX_AND_FETCH_SUBMODULES
SHADPS4_POST_DOWNLOAD_HOOKS = SHADPS4_FIX_AND_FETCH_SUBMODULES

define SHADPS4_INSTALL_TARGET_CMDS
	 mkdir -p $(TARGET_DIR)/usr/bin/shadps4
	 $(INSTALL) -m 0755 $(@D)/buildroot-build/shadps4 $(TARGET_DIR)/usr/bin/shadps4/
	 if [ -d $(@D)/buildroot-build/translations ]; then \
		 cp -pr $(@D)/buildroot-build/translations $(TARGET_DIR)/usr/bin/shadps4/; \
	 fi
endef

define HOST_SHADPS4_BUILD_CMDS
	$(CXX) $(@D)/externals/dear_imgui/misc/fonts/binary_to_compressed_c.cpp -o \
	    $(@D)/shadps4_Dear_ImGui_FontEmbed
endef

define HOST_SHADPS4_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/shadps4_Dear_ImGui_FontEmbed \
	    $(HOST_DIR)/usr/bin/shadps4_Dear_ImGui_FontEmbed
endef

$(eval $(cmake-package))
$(eval $(host-generic-package))
