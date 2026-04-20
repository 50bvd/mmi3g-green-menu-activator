# Audi MMI 3G — Green Engineering Menu Activator

[![License: BSD 2-Clause](https://img.shields.io/badge/License-BSD_2--Clause-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/50bvd/mmi3g-green-menu-activator)](https://github.com/50bvd/mmi3g-green-menu-activator/releases/latest)

Activates the hidden **Green Engineering Menu (GEM)** on Audi MMI 3G systems via SD card script — no VCDS, no OBDeleven, no dealer required.

Maintained by [50bvd](https://github.com/50bvd). Based on the original method by Vlasoff / Keldo (2016).

---

## ⬇️ Download

**[→ Download latest release (ZIP)](https://github.com/50bvd/mmi3g-green-menu-activator/releases/latest)**

Extract the ZIP directly to the root of a FAT32 formatted SD card (8–32 GB) and follow the [installation instructions](#installation) below.

---

## Compatibility

| System | Firmware prefix | Models |
|--------|----------------|--------|
| MMI 3G Basic | `BNav_EU_` | A4 B8, A5 8T, Q5, A6 C6, Q7 4L |
| MMI 3G High | `HNav_EU_` | A4 B8, A5 8T, Q5, A6 C6, A8 D3 |
| MMI 3G Plus | `HN+_EU_` | A4 B8.5, A5 8T FL, Q5 FL |

> **Not compatible with:** MMI RMC, MIB, MIB2, MMI 2G

Check your firmware version: `SETUP → Réglages → Informations sur la version`

---

## What it does

The script directly modifies the MMI persistent SQLite database (`DataPST.db`) to set `pst_key=4100` to `1` in namespace `4` — the internal flag controlling Green Menu access.

Three database locations are patched for full compatibility across MMI variants:
- `/mnt/efs-persist/DataPST.db`
- `/HBpersistence/DataPST.db`
- `/mnt/hmisql/DataPST.db`

A full log file (`green_menu_activator.log`) is written to the SD card for verification.

---

## Requirements

- SD card: **8–32 GB**, formatted **FAT32** (slow format recommended)
- Engine running (or battery charger connected) during script execution
- MMI fully booted (~3 min) before inserting SD card

> ⚠️ Do **not** use microSD + adapter — use full-size SD cards only

---

## Installation

1. **[Download the latest release ZIP](https://github.com/50bvd/mmi3g-green-menu-activator/releases/latest)**
2. Format your SD card as **FAT32** (slow/full format)
3. Extract the ZIP contents **directly to the root** of the SD card:
   ```
   SD:/
   ├── copie_scr.sh        ← encrypted launcher (do not modify)
   ├── copie_scr.sh.dec    ← decoded reference (informational only)
   ├── run.sh              ← main script
   ├── upd                 ← empty trigger file (required!)
   ├── DB/
   │   ├── efs-persist/{old,process,new}/
   │   ├── HBpersistence/{old,process,new}/
   │   └── hmisql/{old,process,new}/
   ├── screens/
   │   ├── scriptStart.png
   │   └── scriptDone.png
   └── utils/
       ├── sqlite3
       ├── showScreen
       └── ...
   ```
4. Start the car (engine running)
5. Wait for MMI to **fully boot** (~3 minutes) — verify by navigating MMI menus
6. Insert SD card into **Slot SD1** (left slot)
7. A confirmation screen appears → **press the rotary knob** to confirm
8. Wait for the completion screen
9. **Reboot the MMI**: hold `SETUP` + `RETURN` simultaneously ~5 seconds

---

## Accessing the Green Menu

After reboot, hold simultaneously for 5–6 seconds:

| Combination | Result |
|-------------|--------|
| `SETUP` + `CAR` | Green Engineering Menu |
| `MENU` + `CAR` | Green Engineering Menu (some models) |

---

## ⚠️ Warnings

- **Do not modify values blindly** — always note original values before changing anything
- **Stay away from Bootloader options** unless you know exactly what you are doing
- A wrong setting can disable MMI features (TPMS, A/C display, etc.)
- If something breaks, the script creates backups in `DB/*/old/` on the SD card
- Use at your own risk — no warranty expressed or implied

---

## Log file

After execution, `green_menu_activator.log` is written to the SD card root. It contains:
- Firmware version detected
- SQL operations performed
- Verification of inserted values
- Any errors encountered

---

## Technical background

The MMI 3G runs **QNX** (a real-time UNIX-like OS). The `copie_scr.sh` is an encrypted shell script recognized and executed by the MMI's `proc_scriptlauncher` process at SD card insertion. It decrypts and launches `run.sh` in the QNX shell environment.

The `pst_key=4100` value in namespace `4` corresponds to the Green Engineering Menu activation flag in the MMI adaptation database — equivalent to what VCDS sets in module `5F` channel `6`.

---

## Credits

- **Vlasoff** — original SD script method (2016)
- **Keldo** — original database patching method (2016)
- **DrGER2** — improved `copie_scr.sh` research (audizine.com)
- **50bvd** — cleanup, logging, documentation, BSD license

---

## License

[BSD 2-Clause](LICENSE) — free to use, modify and redistribute with attribution.
