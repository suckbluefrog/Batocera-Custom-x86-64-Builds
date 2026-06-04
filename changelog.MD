# Changelog

## 📜 Changelog 17-5-2026

  ### Latest
  - Added SteamGridDB artwork scraping support to EmulationStation, including
  alternate artwork selection, logo support, and hero artwork handling through
  marquee assets.
  - Added Manual IP configuration option in Emulationsation Settings
  - Added Game Launch videos in emulationstation option per-system or per-game
  for splash launch videos 
  - Added user-provided API key support for SteamGridDB and TheGamesDB, with
  keys usable from ES or from system text files.
  - Added richer metadata paths for HowLongToBeat, ProtonDB, PCGamingWiki,
  Heroic, Lutris, GOG, Epic, and mixed scraper priority rules.
  - Added PCGamingWiki result text to game descriptions when a matching entry is
  found.
  - Added AppleWin fullscreen launch support.
  - Added AppleWin ES options for Mockingboard and Phasor slot configuration.
  - Added configgen and package support for Dusk, OpenGOAL, and Unleashed
  Recompiled ports.
  - Added Tailscale and ZeroTier service packages.
  - Added RapidYAML target install support for emulator runtime dependencies.
  - Expanded Nanoboy Advance packaging, controls, archive support, and ES
  metadata.
  - Expanded RetroArch/libretro options, including Super Game Boy, BSNES, HD
  Mode 7, and save-location controls.
  - Bumped and fixed multiple emulator packages including PCSX2, PPSSPP, RPCS3,
  Xemu, Xenia Edge, TSugaru, OpenMSX, Python Pyxel, and related libretro cores.
  - Updated audio, ConnMan, and post-build handling for the x86-64-v3 image.
  - Bumped kernel/header to 7.0.8 and Mesa packages to 26.1.0 for the x86-64-v3 build.

  ---

  ## 📜 Changelog 6-5-2026

  - Updated Steam integration, Steam Deck mode session handling, Steam user
  setup, Decky/TDP hooks, night-mode handling, and SteamOS manager support.
  - Added Control Center TDP controls and expanded handheld power-management
  integration.
  - Added LSFG/Vulkan frame-generation support hooks for Wine and Windows launch
  paths.
  - Improved Wine, Lutris, Heroic, and LutrisView integration, including ES
  parsing and launcher support.
  - Updated Gamescope handling, recording scripts, and fake-output support for
  Wayland/labwc workflows.
  - Bumped or repaired Azahar, Cemu, MAME/libretro MAME, RPCS3, ShadPS4,
  VPinball, Xenia Edge, and related dependency packages.
  - Added and updated VPinball support libraries including libwinevbs, libvni,
  libdmdutil, libdof, libpinmame, libpupdmd, libserum, libzedmd, and wxWidgets
  wiring.
  - Added RPCS3 save and screenshot sync helper support.
  - Updated MangoHud/MangoApp packaging and wrapper handling.

## 📜 Changelog 14-4-2026


- Bump RPCS3
- Add Retroachivements to MelonDS
- Fixed N64 Launch issues


---
## 📜 Changelog 29-3-2026

### Latest
- Bump Azahar-sa to 2125.0
- Switch lr-citra to lr-azahar core

---
## 📜 Changelog 26-3-2026

### Latest
- More ES/Configgen options added to Xenia emulators
- Added Gamescope to Xenia emulators
- Fixed Skyemu Standalone not closing 
- Enabled Retroachievements to lr-skyemu
- Pached Dolphin Standalone to play achievement sound (can disable in es options)
- Testing Achievement sounds on Xenia, RPCS3, Shadps4
- Extract XISO and Pkg tool added to F1 (experimental -- needs more work)
- Fixed Docker
- Proton-GE to 10-34
- Kernel to 6.19.10
---

## 📜 Changelog 23-3-2026


- Added  Xenia-Edge (linux vulkan tuned build), Skyemu with Retroachievemnts, lr-skyemu, Gopher64, Nanoboy-advance, free2jme, lr-Mame2015/0.160 (lr-Mame2010/0.139 was already previously added)
- Restored lr-citra, Future Pinball, 
- Bumped shadps4 to 0.15 and added more settings/configgen options
- bumped dolphin to latest and added wii retroachivements
- more flatpak fixes
- bumped Wine-tkg-staging-wow64 and added Proton-GE 10-33
- Added umu-launcher and dgvoodoo2 with settings/configgen options to toggle in ES
- Bumped dosbox-x
- Moved ROG ally hotkeys into services to prevent issues with keyboard on other devices
- Added TDP controls to bactocera-control-center as well as Reboot and Shutdown options
- Kernel to 6.19.9
- Mesa to 26.0.3
---
