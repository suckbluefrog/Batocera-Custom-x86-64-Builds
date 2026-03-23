################################################################################
#
# python-libvirt
#
################################################################################

PYTHON_LIBVIRT_VERSION = 7.10.0
PYTHON_LIBVIRT_SITE = https://files.pythonhosted.org/packages/75/cc/9deb320e9b14ff466adf6693794ad866e0949ebcd84a70d63742a0d64aa1
PYTHON_LIBVIRT_SOURCE = libvirt-python-$(PYTHON_LIBVIRT_VERSION).tar.gz
PYTHON_LIBVIRT_SETUP_TYPE = setuptools
PYTHON_LIBVIRT_LICENSE = LGPL-2.1+
PYTHON_LIBVIRT_LICENSE_FILES = COPYING COPYING.LESSER
PYTHON_LIBVIRT_DEPENDENCIES = libvirt python3
PYTHON_LIBVIRT_ENV = \
	PKG_CONFIG_PATH="$(BUILD_DIR)/libvirt-$(LIBVIRT_VERSION)/build/src:$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig"

define PYTHON_LIBVIRT_GENERATE_API_XML
	mkdir -p $(BUILD_DIR)/libvirt-$(LIBVIRT_VERSION)/build/docs
	$(HOST_DIR)/bin/python3 \
		$(BUILD_DIR)/libvirt-$(LIBVIRT_VERSION)/scripts/apibuild.py \
		$(BUILD_DIR)/libvirt-$(LIBVIRT_VERSION)/docs \
		$(BUILD_DIR)/libvirt-$(LIBVIRT_VERSION)/build/docs
endef

PYTHON_LIBVIRT_PRE_BUILD_HOOKS += PYTHON_LIBVIRT_GENERATE_API_XML

$(eval $(python-package))
