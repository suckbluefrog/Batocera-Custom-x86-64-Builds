# Batocera v43 –  x86-64-v3 Multilib (Beta) 
## Wayland Build

> Unofficial community variant built on Batocera v43.  
> Not affiliated with or supported by the Batocera team.

---

**Download:**  
[https://drive.proton.me/urls/CGJFSTPY18#rkYwVYC6BS94](https://drive.proton.me/urls/3AR99N2KSG#tnj16yBfpgjv)

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


## ⚠️ Target Audience

This build is intended for **advanced users** running x86-64-v3 class  AMD excavator (2015) / Intel 4th gen haswell (2013) and above hardware and handheld devices with Wayland support.  Works Best with AMD Radeon iGPUs and dGPUs from Polaris (around 2018) and Intel Skylake iGPUs / Arc dGPUs and newer

- NVIDIA support is **experimental and untested**
- May function on **RTX 2000-series (Turing) and newer GPUs** using NVK drivers. Expect stutter and worse performance than proprietary Nvidia on Xorg/X11
- Stability is **not guaranteed**
- No official support is provided
- Based on Batocera's "zen3" (a misnomer) build 

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
  - Steam (Steam runs gamescope direct without nesting)

<img width="1923" height="1253" alt="image" src="https://github.com/user-attachments/assets/2409f71f-f340-4f24-8661-7596dfada222" />



---

## Native Steam Integration

Steam is integrated directly into the base system.

Note: patched issues since recent runtime update from previous image

- Integrated with EmulationStation (ES)
- Custom configgens (Advanced ES settings) and launchers
- Full  Gamescope support in steamdeck mode (note first launch in SteamDeck mode may show blank display during runtime download
- No Flatpak required
- No container add-ons required
- Network icon / Wi-Fi detection handled via custom DBus integration in steam deck mode
- Reboot / Shutdown from gamepadui supported
- Automatically parses Steam games into ES
- Steam data stored in: `~/steam`

<img width="2256" height="1281" alt="image" src="https://github.com/user-attachments/assets/3b89f7f9-b1cd-445f-9cca-a51ba11a9298" />


<img width="1253" height="1377" alt="image" src="https://github.com/user-attachments/assets/0a3bc587-debb-4728-959d-5d31d835075d" />



### Optional

```
batocera-steam-decky-install
```

Installs Decky Loader support.



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



# Waydroid (Android Subsystem)

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
- 86box
- Gopher 64
- Nanoboy Advance
- Skyemu / lr-skyemu
- Wine enhancements like UMU-Launcher & Dgvoodoo2
- FreeJ2ME
- Extra ES options for various emulators
- embedded wine tools
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

- Due to recent API limitations, the GamesDB scraper is not included.
- Approx. 5.5GB compressed image size
- Uses an 18GB Batocera partition to allow room for future updates




---

# How to Upgrade

1. Create the upgrade directory: `/userdata/system/upgrade`
2. put `boot.tar.xz` in it
3. run `batocera-upgrade manual`
4. reboot   

If your Batocera partition is too small to upgrade, you may need to resize it.

See the ModHacks guide:

https://www.youtube.com/watch?v=lYOOFJO8y_k

Recommended size:

**At least 15GB Batocera partition**

---

## Disclaimer

This is an unofficial build.

- Not supported by the Batocera team
- No warranty provided
- Use at your own risk
- Advanced users only

---
Upstream Contributions

This project focuses on building a modern, feature-rich Batocera variant. The goal is to deliver working integrations quickly, not to manage upstream contribution workflows.

All source code is provided in full compliance with open-source licensing.
If you would like a feature from this project included upstream:

You are free to submit a PR upstream yourself
You may reuse or adapt any code from this repository (per license terms)
You are responsible for meeting upstream requirements, scope, and policies

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
