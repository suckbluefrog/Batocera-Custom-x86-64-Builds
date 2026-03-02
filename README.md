# Batocera v43 – Zen3 Multilib (Beta)
## Zen3 / Wayland Build

> Unofficial community variant built on Batocera v43.  
> Not affiliated with or supported by the Batocera team.

---

**Download:**  
https://drive.proton.me/urls/CGJFSTPY18#rkYwVYC6BS94

---

## ⚠️ Target Audience

This build is intended for **advanced users** running Zen 3–class AMD/Intel hardware and handheld devices with Wayland support.

- NVIDIA support is **experimental and untested**
- May function on **RTX 2000-series (Turing) and newer GPUs**
- Stability is **not guaranteed**
- No official support is provided

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
  - Steam  

---

## Native Steam Integration

Steam is integrated directly into the base system.

- Integrated with EmulationStation (ES)
- Custom configgens (Advanced ES settings) and launchers
- Full Gamescope support
- No Flatpak required
- No container add-ons required
- Network icon / Wi-Fi detection handled via custom DBus integration
- Automatically parses Steam games into ES
- Steam data stored in: `~/steam`

### Optional

```
batocera-steam-decky-install
```

Installs Decky Loader support.

**Note:**  
Wait 10–20 seconds after exiting Steam before relaunching to avoid race conditions with lingering processes.

---

## Lutris & Heroic Game Launcher

Integrated:

- Native Lutris build
- Heroic AppImage
- ES menu integration
- Direct launcher access

---

## Improved Flatpak Support

Includes:

- XDG improvements
- DBus fixes
- Configgen enhancements
- Name parser fix

`--no-sandbox` can now be selected directly via Advanced Settings in ES  
(no custom wrapper scripts required).

---

## Expanded Ports Support

- Additional ES menu options
- More flexible launch configurations

---

## Built-in Applications

Includes:

- Streaming clients
- Browsers
- Utility applications

---

## Docker

Docker is included.

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
- Low-level debugging utilities

---

# ROG Ally Enhancements

Custom command button mappings:

### Outside Steam
Command Button → `Alt + F4` (Quick close)

### Inside Steam
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
- Enhanced ROG Ally mappings
- Expanded system and developer tooling

Not intended for beginners.

---

## Notes

- Due to recent API limitations, the GamesDB scraper is not included.
- Approx. 5.5GB compressed image size
- Uses an 18GB Batocera partition to allow room for future updates

---

## Disclaimer

This is an unofficial build.

- Not supported by the Batocera team
- No warranty provided
- Use at your own risk
- Advanced users only

---

## Credits

Thanks to:

- The Batocera Team for core development
- Rion for initial draft of gamescope 
- UUreel
- Cliffy
- Contributors from batocera.pro whose work was integrated

---

# Installation (Internal Drive Flashing)

### Step 1
Flash this image to an external bootable USB or SD card first.

### Step 2
Boot from it, connect to network, configure as usual.

Copy the `.img.gz` file to:

`/userdata/system`  
or  
`~/`

### Step 3
Find your internal drive:

```
lsblk
```

### Step 4
From the directory containing the image:

```
e.g. cd ~/
batocera-install install <drive> <filename.img.gz>
```

⚠️ **WARNING:**  
This will completely erase the target internal drive.

### Example

```
batocera-install install nvme0n1 batocera-zen3-x86-64-v3-43-20260302.img.gz
```

Make sure you specify the drive (e.g., `nvme0n1`), NOT a partition (e.g., `nvme0n1p1`).
