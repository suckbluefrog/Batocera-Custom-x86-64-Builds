# Changelog

 ## 📜 Changelog 3-7-2026


  - Bumped Mesa and Mesa headers to 26.1.4.
  - Initial **System Night Mode** support, including EmulationStation controls and Wayland gamma handling.
  - Added **Ryzen FPS Auto-TDP** support and expanded Control Center / TDP hooks for handheld power management.
  - Improved **Steam Mode** launchers, Steam shortcut parsing, Steam Tools, Protontricks, and Wine Tools integration.
  - Enhanced the **Arch Plasma LXC** launcher provisioning.
  - Added LED handheld mode improvements, including EmulationStation LED controls and achievement-triggered LED feedback.
  - Updated and fixed **MAME**, **Ymir**, **Gopher64**, **Yaba Sanshiro**, **DraStic**, **Cemu**, **RPCS3**, **Ryujinx**, **Xemu**, **Supermodel**, **Dolphin**, and numerous other emulator/configgen components.
  - Added **Mupen64Plus-Next ParaLLEl** plugin support and improved Nintendo 64 upscaling and configgen handling.
  - Improved **Flatpak**, Waydroid launcher behavior, Dusklight launchers, Steam desktop/session switching, and supporting runtime tools.
  - Updated NVIDIA proprietary drivers to **595.84**, with legacy drivers updated to **580.159.04**.


  ---

 ## 📜 Changelog 14-6-2026


  - Updated the build base to Batocera v44 and refreshed the Wayland stack, including wlroots 0.20.1 and labwc fixes for cursor hiding and XWayland absolute pointer handling.
  - Improved Steam GamepadUI and desktop switching paths, including cleaner session selection, updated DBus stubs, update/preflight handling, and SDL renderer fixes for Proton/EAC/EOS splash windows.
  - Added and improved 86Box and EKA2L1 integration, including desktop/config launchers, userdata BIOS notes, Symbian/N-Gage device-pack seeding, and expanded ES documentation.
  - Added RPCS3 game-profile database support with new ES options for database defaults vs manual compatibility settings.
  - Bumped and fixed VPinball, Dusk, RPCS3, DuckStation, Solarus, MAME, and other emulator/configgen paths.
  - Reworked VPinball packaging around system bgfx/libframeutil and updated DMD/pinball support libraries.
  - Updated Wine/Proton components including Wine Proton 11.0 experimental, Wine-TKG 11.10, VKD3D-Proton 3.0.1, DXVK-NVAPI 0.9.2, and Wine Mono 11.1.0.
  - Added SimpleDeckyTDP installation support to batocera-wine-tools and improved AMD TDP/control-center hooks.
  - Improved NVIDIA proprietary driver setup and related runtime handling.

  
  ---

  ## 📜 Changelog 8-6-2026

 
  - Added experimental xorg v3 build.
  - Bumped Mame to 0.288

  ---

  ## 📜 Changelog 4-6-2026


  - Updated the x86-64-v3 build base with kernel 7.0.11 support and Mesa 26.1.2.
  - Cleaned and refocused the tree layout for the x86-64-v3 build, removing unused non-x86 board targets from this branch.
  - Added visible Steam update/preflight handling so Steam verification and update progress no longer appears as a blank launch.
  - Improved Steam Deck mode/session handling, including cleanup paths for Steam, Gamescope, helper processes, and EmulationStation return behavior.
  - Expanded Batocera Control Center features and fixes, including better focus handling, quick actions, screenshot support, recent-game launching, and gaming/system tab updates.
  - Added GMU music player support as an EmulationStation system with improved gamepad navigation.
  - Added Xenia Canary Linux binary support for the Vulkan path, and kept the Windows binary/Wine VKD3D path available for D3D12.
  - Added NVIDIA proprietary 580.x and 590.x driver support for Maxwell-class GPUs (GTX 900 / GTX 750 Ti) and newer; Gamescope performance and compatibility may vary by GPU.
  - Bumped and fixed RPCS3, DuckStation, ShadPS4, Xenia Edge/Canary, RetroArch, Kronos, GMU, and other emulators.
  - Converted Sunshine to a native build and fixed Boost/quadmath link issues.
  - Updated Wine tools, Lutris, Heroic, N64 recomp launcher, install-internal tools, desktop apps, and supporting configgen/hotkey paths.
  - Moved the main squashfs into `/system` on ext4 to avoid FAT32 limits and multi-squashfs `/boot` complications, with a new `/userdata/update` flow using `update.tar` and `update.tar.md5`; older layouts require a fresh install.

  Older changelog entries are archived in [changelog.MD](changelog.MD).


## 📜 Changelog 17-5-2026


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
