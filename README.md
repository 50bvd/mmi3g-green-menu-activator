# 🟢 MMI 3G Green Menu Activator

[![CI](https://github.com/50bvd/mmi3g-green-menu-activator/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/50bvd/mmi3g-green-menu-activator/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/50bvd/mmi3g-green-menu-activator?include_prereleases&sort=semver)](https://github.com/50bvd/mmi3g-green-menu-activator/releases)
[![License: BSD 2-Clause](https://img.shields.io/badge/License-BSD_2--Clause-blue.svg)](LICENSE)

Activates the hidden **Green Engineering Menu (GEM)** of Audi MMI 3G units from an SD card — no VCDS, no OBDeleven, no dealer visit.

## ✨ Features

- 💾 **SD card only** — insert the card, press the knob, restart the MMI
- 🛟 **Checked backups** — every database is copied to the SD card and verified before it is changed; the first backup is never overwritten
- ⚛️ **All or nothing** — the change is a single SQL transaction, read back afterwards
- 🎯 **Minimal change** — one row (`namespace 4`, `key 4100`), the same flag VCDS/ODIS sets in control unit 5F
- 🔁 **Safe to run twice** — a database that is already set is left untouched
- 🔙 **Reversible** — an empty `DISABLE` file on the card switches the menu off again
- 📝 **Log file** on the SD card, with a clear `RESULT: OK` / `RESULT: FAILED`
- 🧪 **Tested** on a simulated MMI in CI, with the launcher and QNX tools pinned by SHA-256

## 📥 Download

Get the latest version on the [releases page](https://github.com/50bvd/mmi3g-green-menu-activator/releases/latest): `mmi3g-green-menu-activator-<version>.zip`.

> Do **not** use GitHub's "Source code" archive: the SD card content is in its `sdcard/` folder, not at the root.

### Verify your download

The ZIP is built by GitHub Actions from this repository and comes with a signed [build provenance attestation](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations) and a `SHA256SUMS.txt` file:

```bash
# Proves the file was built by this repository's release workflow
gh attestation verify mmi3g-green-menu-activator-1.1.0.zip --repo 50bvd/mmi3g-green-menu-activator

# Checks the file was not corrupted or modified
sha256sum -c SHA256SUMS.txt --ignore-missing
```

On Windows (PowerShell): `Get-FileHash .\mmi3g-green-menu-activator-1.1.0.zip` and compare with `SHA256SUMS.txt`.

## 🚗 Compatibility

| System | Firmware prefix (example) | Models |
|--------|---------------------------|--------|
| MMI 3G Basic | `BNav_` | A4 B8, A5 8T, Q5 8R, A6 C6, Q7 4L |
| MMI 3G High | `HNav_` | A4 B8, A5 8T, Q5 8R, A6 C6, A8 D3, Q7 4L |
| MMI 3G Plus | `HN+_` | A4 B8.5, A5 8T FL, Q5 8R FL, A6 C7, A7 4G, A8 D4 |

**Not compatible:** MMI 2G, MMI RMC, MIB / MIB2 (MMI Navigation plus, MMI Radio, Virtual Cockpit…).

Your firmware is shown in **SETUP › Version information**, and in the log after the first run.
Worked on your car? Please [send a compatibility report](https://github.com/50bvd/mmi3g-green-menu-activator/issues/new?template=compatibility.yml).

## 🧰 Before you start: Audi workshop guidelines

The script changes the MMI's configuration database. Prepare the car the way an Audi workshop does before any work on a control unit:

1. **Stable power supply.** Connect a **battery charger / maintainer** (workshops use a VAS power supply unit). A low voltage during the write can corrupt the database.
   No charger? Let the **engine run — outdoors only**, never in a closed garage.
2. **Car stationary and safe:** gear in **P** (or neutral on a manual), **parking brake applied**.
3. **Ignition on for the whole procedure.** Do not switch it off, do not lock the car and do not remove the key until the end screen appears.
4. **Switch off large consumers:** headlights, blower, seat and rear-window heating.
5. **Let the MMI boot completely** (about 3 minutes, navigate a few menus) before inserting the card.
6. **Do not touch the MMI** while the script runs (except to confirm the screens), and **do not remove the SD card** before the end screen.

Also good to know:

- The Green Menu is a **workshop/developer menu**. Changing values in it can disable features (TPMS, A/C display, Bluetooth, navigation…) or make the MMI unstable. **Write down every value before you change it.**
- Never touch the **bootloader, flash or "SWDL" entries**.
- Changes made to the vehicle's software may be refused under **warranty**. Switch the menu off again (see [Switch the menu off](#switch-the-menu-off)) before a dealer visit if you wish.
- The official way to do the same thing is a diagnostic tool (ODIS / VCDS): control unit **5F – Information Electronics**, adaptation *developer mode* (channel 6 on older VCDS labels).

## 🚀 Quick Start

1. Format an **SD card** (full size, 8–32 GB) as **FAT32**. Avoid microSD adapters: some MMIs do not read them reliably.
2. Extract the release ZIP **to the root** of the card:
   ```
   SD:/
   ├── copie_scr.sh     ← encrypted launcher, started by the MMI (do not edit)
   ├── run.sh           ← the script
   ├── upd              ← empty file, keep it
   ├── screens/         ← start, done and error screens
   └── utils/           ← QNX tools (sqlite3, showScreen, …)
   ```
3. Prepare the car (see [the guidelines](#-before-you-start-audi-workshop-guidelines)) and wait until the MMI has fully booted.
4. Insert the card in **slot SD1**.
5. *Press any key to execute the script* appears → **press the rotary knob**. Nothing is changed before this.
6. *Script applied* appears → press a key and **remove the card**.
   If the **error screen** appears instead, nothing more is needed: read the log (see [Troubleshooting](#-troubleshooting)).
7. **Restart the MMI:** hold **MENU + rotary knob + top-right soft key** for about 5 seconds.

## 📖 Usage

### Open the Green Menu

After the restart, hold **CAR + SETUP** for about 5 seconds.
On some models, the combination is **CAR + BACK** (or **CAR + RETURN**).

### Switch the menu off

1. Create an empty file named `DISABLE` at the root of the SD card (`DISABLE.txt` also works).
2. Run the procedure again: the flag is set back to `0`.
3. Delete the file from the card afterwards, or the next run will switch the menu off again.

### Log file

The script appends to `green_menu_activator.log` at the root of the card:

```
======================================
 MMI 3G Green Menu Activator 1.1.0
 https://github.com/50bvd/mmi3g-green-menu-activator
======================================
Date    : Tue Sep 29 18:12:03 2026
SD card : /mnt/sdcard10t12
Firmware: HN+_EU_AU_K0942_4
Action  : enable (pst_namespace=4 pst_key=4100 value=1)

>> efs-persist (/mnt/efs-persist/DataPST.db)
   before  : rows=0 value=none
   backup  : /mnt/sdcard10t12/backup/efs-persist/DataPST.db.20260929-181203
   after   : rows=1 value=1
   check   : ok

>> HBpersistence (/HBpersistence/DataPST.db)
   not present on this MMI, skipped
...
RESULT: OK
```

### Backups

Each database that is changed is copied to `backup/<name>/` on the card:

| File | Content |
|------|---------|
| `DataPST.db.orig` | The state before the **first** run. Never overwritten: keep it safe. |
| `DataPST.db.<date>` | The state before each run that changed something. |

## 🩺 Troubleshooting

| Symptom | What to do |
|---------|------------|
| Nothing happens when the card is inserted | Check that `copie_scr.sh` is at the **root** of a **FAT32** card, wait for a full MMI boot, try the other slot or another card. |
| Error screen | Open `green_menu_activator.log` and look at the lines with `ERROR`. Databases in error were **left as they were**. |
| `no DataPST.db found` | This is not an MMI 3G (see [Compatibility](#-compatibility)). |
| `attempt 3 failed` | The MMI was writing to its database. Wait a minute and run the script again. |
| `RESULT: OK` but no menu | Make sure you restarted the MMI, then try the other key combinations. |

## 🔧 How it works

The MMI 3G runs **QNX**. When an SD card is inserted, the MMI's `proc_scriptlauncher` looks for an **encrypted** `copie_scr.sh`, decodes it and runs it. The one shipped here ([decoded copy](docs/copie_scr.sh.dec)) only changes to the SD card and starts `run.sh`.

`run.sh` shows the start screen, then for each persistence database found — `/mnt/efs-persist/DataPST.db`, `/HBpersistence/DataPST.db`, `/mnt/hmisql/DataPST.db`, depending on the variant — it:

1. checks that the table `tb_intvalues` exists and reads the current value;
2. stops there if the value is already right;
3. copies the database to the SD card and checks the copy (`PRAGMA integrity_check`);
4. deletes and inserts the row `pst_namespace=4, pst_key=4100, pst_value=1` in **one transaction**;
5. reads the value back and runs `PRAGMA quick_check`.

## 🛠️ Development

Requirements: `bash`, `mksh` (closest shell to the QNX Korn shell), `sqlite3`, `shellcheck`, `zip`.

```bash
git clone https://github.com/50bvd/mmi3g-green-menu-activator.git
cd mmi3g-green-menu-activator
shellcheck -s ksh sdcard/run.sh
tests/run_test.sh        # runs run.sh on a simulated MMI
tests/payload_test.sh    # checks the SD card files
scripts/package.sh       # builds dist/mmi3g-green-menu-activator-<version>.zip
```

## 🧱 Project structure

```
mmi3g-green-menu-activator/
├── sdcard/                 # Exactly what goes on the SD card
│   ├── copie_scr.sh        # Encrypted launcher (pinned by SHA-256)
│   ├── run.sh              # The script
│   ├── upd
│   ├── screens/            # scriptStart / scriptDone / scriptError
│   └── utils/              # QNX SH4 tools
├── docs/copie_scr.sh.dec   # Decoded launcher, for review
├── tests/                  # Simulated MMI and payload checks
├── scripts/package.sh      # Release ZIP
└── .github/                # CI, release, templates, rulesets
```

## 🤝 Contributing

Contributions are welcome: bug reports, compatibility reports and code.

- Read the [contribution guide](CONTRIBUTING.md). Pull requests target the **`develop`** branch; `main` only holds released versions.
- Security issue? See the [security policy](SECURITY.md). Please do not open a public issue.
- Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).
- See the [changelog](CHANGELOG.md) for what changed in each version.

## 📄 License

This project is licensed under the BSD 2-Clause License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Loup LIGNON KRASNIQI**
- GitHub: [@50bvd](https://github.com/50bvd)
- Email: loup.lk-pro@protonmail.ch

## ⚠️ Disclaimer

This project is not affiliated with, authorized or endorsed by AUDI AG or the Volkswagen Group.
"Audi" and "MMI" are trademarks of AUDI AG. The script changes the configuration of your
vehicle's infotainment unit: **use it at your own risk**, following the guidelines above.
The author is not responsible for any damage, loss of function or warranty claim.

## 🙏 Acknowledgments

- **Vlasoff** — original SD card script method (2016)
- **Keldo** — original database patching method (2016)
- **DrGER2** — `copie_scr.sh` research ([audizine.com](https://www.audizine.com/))

---

**⭐ Star this repo if you find it useful!**
