# Batocera v44 –  x86-64-v3 Multilib (Beta) 
## Wayland & Xorg Builds

> Unofficial community variant built on Batocera v44.  
> Not affiliated with or supported by the Batocera team.

---

**Download:** 
Latest Build: June 14, 2026
[https://drive.proton.me/urls/CGJFSTPY18#rkYwVYC6BS94](https://drive.proton.me/urls/3AR99N2KSG#tnj16yBfpgjv)

---
## Video Preview:
https://youtu.be/26Kkne6lT0s  -- Note, Steam was launched without gamescope so Batocera recorder could capture.

 
---

  ## 📜 Changelog 14-6-2026

  ### Latest
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

  ---

## ⚠️ Target Audience

This build is intended for **advanced users** running x86-64-v3 class  AMD excavator (2015) / Intel 4th gen haswell (2013) and above hardware and handheld devices with Wayland or Xorg support.  Wayland works Works Best with AMD Radeon iGPUs and dGPUs from Polaris (around 2018) and Intel Skylake iGPUs / Arc dGPUs and newer. NVIDIA users should stick to Xorg.

- NVIDIA Proprietary driver support has been added with 580 and 590 drivers. Limited testing has reported success. Maxwell (9xx/750ti) and higher boards are supported
- Gamescope compatibility and performance on Nvidia boards may vary. Direct DRM/KMS gamescope sessions on nvidia devices are not validated. 
-  No official support is provided
- Based on Batocera's "zen3" (a misnomer) wayland build 

This variant includes additional integrated components and tooling beyond the standard distribution and is designed for users comfortable troubleshooting their own systems.

---

# Core Additions

## i386 / 32-bit Library Support

Full 32-bit compatibility layer included.

This improves compatibility with:

- Older Linux applications and games  
- Legacy audio and middleware dependencies  
- Lutris-installed Linux titles
- Steam integration

**Example:**  
AM2R (Linux version) via Lutris now works out-of-the-box.

---

## Gamescope Integration

Nested **Gamescope inside labwc** is integrated into the system.

Useful for scaling older titles cleanly on modern displays.

Includes:

- Advanced ES settings
- Debugging / experimental launch options
- Preconfigured launchers for:
  - Windows (Wine)  
  - DOS  
  - Cemu  
  - Ports  
  - Steam (Steam runs gamescope direct vis DRM/KMS without nesting on both builds)

<img width="1923" height="1253" alt="image" src="https://github.com/user-attachments/assets/2409f71f-f340-4f24-8661-7596dfada222" />



---

## Native Steam Integration


Steam is integrated directly into the base system.

<img width="1240" height="775" alt="image" src="https://github.com/user-attachments/assets/33312040-62e4-40ec-b30c-d1984c9e3c9f" />




- Integrated with EmulationStation (ES)
- Custom configgens (Advanced ES settings) and launchers
- Full  Gamescope support in steamOS mode 
- No Flatpak required
- No container add-ons required
- Network icon / Wi-Fi detection handled via custom DBus integration in steam deck mode
- Shutdown from gamepadui supported
- Automatically parses Steam games into ES
- Steam data stored in: `~/steam`

<img width="2256" height="1281" alt="image" src="https://github.com/user-attachments/assets/3b89f7f9-b1cd-445f-9cca-a51ba11a9298" />


<img width="1253" height="1377" alt="image" src="https://github.com/user-attachments/assets/0a3bc587-debb-4728-959d-5d31d835075d" />



### Optional

Decky Loader installer is available in the wine-gui tools menu.

```
batocera-steam-decky-install
batocera-steam-decky-tdp
```

Installs Decky Loader support and the SimpleDeckyTDP Decky plugin.



---

## Lutris & Heroic Game Launcher

Integrated:

- Native Lutris build
- Heroic AppImage
- ES menu integration
- Direct launcher access
- Created desktop shortcuts in those apps for es to parse when refreshing gamelist
---

## Improved Flatpak Support

Includes:

- XDG improvements
- DBus fixes
- Configgen enhancements
- Name parser fix

`--no-sandbox` can now be selected directly via Advanced Settings in ES  
(no custom wrapper scripts required).

<img width="1913" height="1306" alt="image" src="https://github.com/user-attachments/assets/ca2408e1-8410-427c-b6e9-0bb4df0beec7" />



---

## Expanded Ports Support

- Additional ES menu options
- More flexible launch configurations

---



# Waydroid (Android Subsystem - wayland build only)

Waydroid is included with support for **aarch64 Android applications**.

This allows running many Android apps directly on the system with hardware acceleration.

<img width="1409" height="801" alt="image" src="https://github.com/user-attachments/assets/6f967804-b2d7-4c74-b26c-0f202dda613f" />

<img width="1636" height="785" alt="image" src="https://github.com/user-attachments/assets/d7c8cb28-6a93-40a4-a525-38512534eb84" />

Features:

- Wayland-native integration
- Controller-friendly launcher support
- aarch64 Android application compatibility


### Google Play Services

If using a GApps Waydroid image, Google services may report that the device is **not certified**.

You can register the device ID by running:

```waydroid-get-android-id``` in ssh / terminal


Run this command over **SSH or terminal**, then register the generated ID with Google.

Alternatively, disable the warning notifications:

Settings  -> apps → Google Play Services → Notifications

Disable the **device certification warning**.

---

# Virtual Machine Manager

Virtualization support is included via:

- **QEMU**
- **libvirt**
- **Virtual Machine Manager (virt-manager)**

This allows running full virtual machines directly from the system.

Potential uses include:

- Windows virtual machines
- Linux testing environments
- Development systems




---
## Built-in Applications

Includes:

- Streaming clients
- Browsers
- Utility applications

---
## Other Additions
- TouchHLE is added (IOS emulator -- currently up to IOS 3.0)
- Applewin
- 86box
- Gopher64
- lr-azahar
- Nanoboy Advance
- Skyemu / lr-skyemu
- Unleashed Recomp, Dusk, and OpenGoal Engines
- Wine enhancements like UMU-Launcher & Dgvoodoo2
- FreeJ2ME
- Extra ES options for various emulators
- embedded wine tools
- N64 Recomp
- steam tools like rom manager and proton-up
  

---


## Docker

Docker and distrobox are included.

Enable via:

System Settings → Services

---

## Sunshine

Sunshine streaming server is included.

Enable via:

System Settings → Services

Access via:

`https://<your-ip>:47990`

---

## Emulator Settings Launcher

Dedicated emulator settings menu added for easier configuration access.

---

## Node.js / NPM

Node.js runtime and NPM included system-wide.

---

## Expanded CLI Toolset

Additional developer tools included:

- `strace`
- `pax-utils`
- `strings`
- `xmlstarlet` 
- `tree`
- `file`
and more low-level debugging utilities

---

# ROG Ally Enhancements

LED control fixed / added
*Note: due to 12 range controls, must toggle off/on to change color after setting in ES

### Command button mappings (enable rogallyhotkeys in services menu):

### Outside Steam
Command Button → `Alt + F4` (Quick close)

### Inside Steamdeck mode
Command Button → `Shift + Tab` (Steam overlay/menu)

### Armory Crate Button

- Tap once → Opens Batocera Control Center  
- Hold → Opens on-screen touch keyboard  
- Inside Steam → Opens Steam QAM (Quick Access Menu in GamepadUI)

---

# Summary

Batocera v43 – Zen3 Extended is a feature-focused variant intended for advanced users who prefer a broader integrated stack.

Includes:

- Native Steam + Gamescope integration
- 32-bit compatibility layer
- Extra libs for Appimages missing that are common on Desktop Distros
- Integrated Lutris & Heroic
- Docker & Sunshine
- Waydroid, Virtual Machines, LXC containers
- Enhanced ROG Ally mappings
- Expanded system and developer tooling

Not intended for beginners.

---

## Notes

- Approx. 6.5GB compressed image size
- Uses an 14GB System partition to allow room for future updates




---

# How to Upgrade

See Enclosed instructions with files


## ⚠️ Unofficial Build Notice

This is an unofficial build.

- Not supported by the Batocera team  - Don't ask on their discord or reddit for support.
- No warranty provided — use at your own risk  
- Built for power users — not for hand-holding  

This project is developed for fun and released *as-is*, with no guarantees of functionality, compatibility, or support.

Community help may be available through various channels, but support is not provided. If something breaks, you are expected to investigate, troubleshoot, and fix it yourself.

**Advanced users only — self-sufficiency required.**

---
# Upstream Contributions

This project focuses on building a modern, feature-rich Batocera variant. The goal is to deliver working integrations quickly, not to manage upstream contribution workflows.

All source code is provided in full compliance with open-source licensing.
If you would like a feature from this project included upstream:

- You are free to submit a PR upstream yourself
- You may reuse or adapt any code from this repository (per license terms)
- You are responsible for meeting upstream requirements, scope, and policies

Please do not request that features from this project be upstreamed on your behalf.

This project intentionally targets a different scope (modern hardware, newer graphics stack, etc.), and not all features are designed to align with upstream constraints.

---

## Credits

Thanks to:

- The Batocera Team for core development
- Rion for initial draft of gamescope 
- UUreel
- Cliffy
- Contributors from batocera.pro whose work was integrated

---
