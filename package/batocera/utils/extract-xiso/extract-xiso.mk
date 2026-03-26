################################################################################
#
# extract-xiso
#
################################################################################

EXTRACT_XISO_VERSION = b72e5b60d598ec6df80534cda19cdcd4361aa18c
EXTRACT_XISO_SITE = https://github.com/xboxdev/extract-xiso.git
EXTRACT_XISO_SITE_METHOD = git
EXTRACT_XISO_LICENSE = BSD-4-Clause
EXTRACT_XISO_LICENSE_FILES = LICENSE.TXT

$(eval $(cmake-package))
