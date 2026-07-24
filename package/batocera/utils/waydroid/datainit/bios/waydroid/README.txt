Waydroid ARM translation (AMD x86_64 only)
================================================

Waydroid is x86_64-only unless you explicitly install an ARM translation
bridge. Without the bridge, nothing is broken: Google Play only offers apps
that provide a compatible x86/x86_64 build.

Use "Waydroid Tools" in the Emulator system for the guided installer. It can
download the pinned recovery image directly from Google's server, or you can
download it on another computer and place it in:

  /userdata/bios/waydroid/dump_here/

(This is the waydroid/dump_here folder inside Batocera's network "bios"
share.)

Required official Google file:

  chromeos_16238.47.0_zork_recovery_stable-channel_ZorkMPKeys-v12.bin.zip

Google URL:

  https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_16238.47.0_zork_recovery_stable-channel_ZorkMPKeys-v12.bin.zip

The extractor also accepts the .bin contained inside that ZIP. Keep only one
ZIP or BIN in dump_here. Extraction temporarily needs about 14 GiB free under
/userdata. Temporary BIN, ROOT-A, and extracted EROFS work images are deleted
automatically when extraction finishes.

After a successful install, Waydroid Tools offers to remove the large ZIP/BIN
and the redundant BIOS staging copy. The protected installed payload remains
available for normal Waydroid reconciliation. If you later remove the bridge
or factory-reset Waydroid, installing it again will require another recovery
download.

The verified files are staged in:

  /userdata/bios/waydroid/overlay/system/

Source metadata and the Google-provided license are saved alongside the staged
overlay. Staging alone never enables the bridge. "Waydroid Tools" must perform
the explicit install into the live Waydroid overlay.

An already initialized standard x86_64 Waydroid container can be converted in
place; its Android apps and data do not need to be erased. Removing the bridge
also preserves Android data, but any already-installed ARM-only app will stop
working until translation is installed again.

This pinned libndk payload is licensed for AMD and is rejected on Intel CPUs.
Both WayDroid-ATV variants are x86_64 Android images that supply their own
ARM-app translation layer. Its implementation can change with the Android TV
image release; Waydroid Tools reports the bridge property from running Android.
This installer therefore does not mix the separately provisioned Chromebook
zork libndk payload into Android TV images.

WayDroid-ATV source:

  https://github.com/WayDroid-ATV/waydroid-androidtv-builds

Advanced/manual commands:

  ./extract.sh
  /usr/bin/batocera-waydroid-arm install
  /usr/bin/batocera-waydroid-arm verify
  /usr/bin/batocera-waydroid-arm cleanup-source
  /usr/bin/batocera-waydroid-arm remove
