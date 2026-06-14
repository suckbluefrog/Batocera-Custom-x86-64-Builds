Place 86Box machine BIOS ROMs here.

Batocera uses this directory as the default 86Box ROM path:
/userdata/bios/86box

Both EmulationStation launches and the F1 desktop 86Box launcher pass this path to 86Box as --rompath unless an override is configured.

Keep the ROM set layout expected by 86Box inside this directory. This folder is for machine BIOS, video BIOS, adapter ROMs, and other ROM files used by the 86Box hardware database.

Do not put VM configs, hard disk images, floppy images, or CD images here.
Those belong under /userdata/roms/86box or inside each VM directory.

Typical VM layout:
/userdata/roms/86box/Windows 98 Pentium II/86box.cfg
/userdata/roms/86box/Windows 98 Pentium II/hdd.img
/userdata/roms/86box/Windows 98 Pentium II/install.iso

Recommended flow:
1. Open 86Box from F1 Applications or Tools/Start_86Box.sh.
2. Configure the machine and confirm the required BIOS entries are found.
3. Save the VM as 86box.cfg inside /userdata/roms/86box/<VM name>/.
4. Launch that VM directory from EmulationStation.
