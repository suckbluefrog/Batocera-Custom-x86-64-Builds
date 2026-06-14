Optional EKA2L1 firmware import directory.

Use this for Symbian or N-Gage firmware files, or for .zip device packs containing devices.yml plus matching drives and roms directories.

Batocera also scans this directory when seeding EKA2L1 device data.
Seeded data is copied into /userdata/saves/eka2l1/EKA2L1/data before launch.

Example archive:
/userdata/bios/symbian/Nokia N-Gage & N-Gage QD (S60v1).zip

Example expanded layout:
/userdata/bios/symbian/devices.yml
/userdata/bios/symbian/drives/z/NEM-4/System/...
/userdata/bios/symbian/roms/NEM-4/SYM.ROM

The original Nokia N-Gage and N-Gage QD are S60v1/EPOC 6.x devices.
Later .n-gage installer packages are usually Symbian OS 9.x/N-Gage 2.0 packages and need matching S60v3 or newer device data.

The EKA2L1 GUI can be opened from F1 Applications or from Tools/Start_EKA2L1.sh.
