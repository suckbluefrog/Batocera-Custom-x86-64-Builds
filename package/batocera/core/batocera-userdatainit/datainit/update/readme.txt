Drop update.tar and update.tar.md5 in this folder.

Batocera verifies update.tar.md5 during boot. If the checksum matches, the boot
files are updated and the new system/batocera.update payload is installed as the
single squashfs on the SYSTEM partition.
