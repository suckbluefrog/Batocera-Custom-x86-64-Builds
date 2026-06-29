################################################################################
#
# mtools
#
################################################################################

MTOOLS_VERSION = 4.0.45
MTOOLS_SOURCE = mtools-$(MTOOLS_VERSION).tar.lz
MTOOLS_SITE = $(BR2_GNU_MIRROR)/mtools
MTOOLS_LICENSE = GPL-3.0+
MTOOLS_LICENSE_FILES = COPYING
MTOOLS_CONF_OPTS = --without-x
HOST_MTOOLS_CONF_OPTS = --without-x
HOST_MTOOLS_DEPENDENCIES += host-patchelf

define HOST_MTOOLS_FIX_HOST_TOOLS_RPATH
	rm -f $(HOST_DIR)/bin/floppyd $(HOST_DIR)/bin/floppyd_installtest
	for tool in mtools mkmanifest; do \
		if test -x $(HOST_DIR)/bin/$${tool}; then \
			$(HOST_DIR)/bin/patchelf --set-rpath '$$ORIGIN/../lib' $(HOST_DIR)/bin/$${tool}; \
		fi; \
	done
endef

HOST_MTOOLS_POST_INSTALL_HOOKS += HOST_MTOOLS_FIX_HOST_TOOLS_RPATH

# info documentation not needed
MTOOLS_CONF_ENV = \
	ac_cv_func_setpgrp_void=yes \
	ac_cv_lib_bsd_gethostbyname=no \
	ac_cv_lib_bsd_main=no \
	ac_cv_path_INSTALL_INFO=

HOST_MTOOLS_CONF_ENV = \
	ac_cv_lib_bsd_gethostbyname=no \
	ac_cv_lib_bsd_main=no \
	ac_cv_path_INSTALL_INFO=

# link with iconv if enabled
ifeq ($(BR2_PACKAGE_LIBICONV),y)
MTOOLS_DEPENDENCIES += libiconv
MTOOLS_CONF_ENV += LIBS=-liconv
endif

# Package does not build in parallel due to improper make rules
MTOOLS_MAKE = $(MAKE1)

$(eval $(autotools-package))
$(eval $(host-autotools-package))
