################################################################################
#
# dhewm3
#
################################################################################
DHEWM3_VERSION = 1.5.5
DHEWM3_SITE = $(call github,dhewm,dhewm3,$(DHEWM3_VERSION))
DHEWM3_LICENSE = GPLv3
DHEWM3_LICENSE_FILES = COPYING.txt
DHEWM3_SUBDIR = neo

DHEWM3_DEPENDENCIES = host-libjpeg libcurl libogg libvorbis openal sdl2 zlib 

$(eval $(cmake-package))
