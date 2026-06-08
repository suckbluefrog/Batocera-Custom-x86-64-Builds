################################################################################
#
# cargo-c
#
################################################################################

CARGO_C_VERSION = v0.10.19
CARGO_C_SITE = $(call github,lu-zero,cargo-c,$(CARGO_C_VERSION))
CARGO_C_LICENSE = MIT License
CARGO_C_LICENSE_FILES = LICENSE

HOST_CARGO_C_DEPENDENCIES = host-pkgconf host-rustc host-openssl
HOST_CARGO_C_DL_ENV += BR_CARGO_UPDATE_PRECISE='cargo-util@0.2.29=0.2.27 crates-io@0.40.19=0.40.17 cargo-credential-libsecret@0.5.7=0.5.5'

$(eval $(host-cargo-package))
