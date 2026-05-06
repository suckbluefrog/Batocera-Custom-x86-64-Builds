################################################################################
#
# wxwidgets
#
################################################################################

WXWIDGETS_VERSION = v3.3.2
WXWIDGETS_SITE = https://github.com/wxWidgets/wxWidgets
WXWIDGETS_SITE_METHOD = git
WXWIDGETS_GIT_SUBMODULES = YES

WXWIDGETS_DEPENDENCIES = gdk-pixbuf gst1-plugins-base gstreamer1 host-libgtk3 host-wayland
WXWIDGETS_DEPENDENCIES += jpeg libcurl libglu libgtk3 libpng libsecret pcre2
WXWIDGETS_DEPENDENCIES += sdl2 webp xz zlib

WXWIDGETS_SUPPORTS_IN_SOURCE_BUILD = NO
WXWIDGETS_INSTALL_STAGING = YES

define WXWIDGETS_GENERATE_WAYLAND_PROTOCOLS
	mkdir -p $(@D)/buildroot-build/lib/wx/include/gtk3-unicode-3.3/wx/protocols
	$(HOST_DIR)/bin/wayland-scanner client-header \
		$(@D)/src/unix/protocols/pointer-warp-v1.xml \
		$(@D)/buildroot-build/lib/wx/include/gtk3-unicode-3.3/wx/protocols/pointer-warp-v1-client-protocol.h
	$(HOST_DIR)/bin/wayland-scanner private-code \
		$(@D)/src/unix/protocols/pointer-warp-v1.xml \
		$(@D)/buildroot-build/lib/wx/include/gtk3-unicode-3.3/wx/protocols/pointer-warp-v1-client-protocol.c
endef

WXWIDGETS_POST_CONFIGURE_HOOKS += WXWIDGETS_GENERATE_WAYLAND_PROTOCOLS

define WXWIDGETS_FIXUP_WXWIDGET_CONFIG
    ln -sf $(STAGING_DIR)/usr/lib/wx/config/*gtk3-unicode-* \
	   $(STAGING_DIR)/usr/bin/wx-config
	$(SED) 's%^prefix=.*%prefix=$(STAGING_DIR)/usr%' \
		$(STAGING_DIR)/usr/bin/wx-config
	$(SED) 's%^exec_prefix=.*%exec_prefix=$${prefix}%' \
		$(STAGING_DIR)/usr/bin/wx-config
	rm -rf $(STAGING_DIR)/usr/lib/cmake/wxWidgets
	ln -snf wxWidgets-3.3 $(STAGING_DIR)/usr/lib/cmake/wxWidgets
endef

WXWIDGETS_POST_INSTALL_STAGING_HOOKS += WXWIDGETS_FIXUP_WXWIDGET_CONFIG

$(eval $(cmake-package))
