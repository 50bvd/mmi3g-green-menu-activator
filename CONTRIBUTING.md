# Contributing to MMI 3G Green Menu Activator

Thanks for your interest! Bug reports, compatibility reports (which car, which firmware, did it work)
and code are all welcome.

## Project layout

| Path | Purpose |
|------|---------|
| `sdcard/` | Exactly what goes on the SD card (the release ZIP is this folder) |
| `sdcard/copie_scr.sh` | Encrypted launcher, run by the MMI when the card is inserted. **Never edit.** |
| `sdcard/run.sh` | The script that changes the databases (QNX Korn shell) |
| `sdcard/screens/` | 800×480 8-bit PNG screens shown by `utils/showScreen` |
| `sdcard/utils/` | QNX SH4 tools (`sqlite3` 3.6.20, `showScreen`, …) |
| `docs/copie_scr.sh.dec` | Decoded content of `copie_scr.sh`, for review |
| `tests/run_test.sh` | Runs `run.sh` on a simulated MMI (fake databases, stubbed tools) |
| `tests/payload_test.sh` | Checks the SD card files and the pinned SHA-256 |
| `scripts/package.sh` | Builds the release ZIP |

## Branches

| Branch | Role |
|--------|------|
| `main` | Stable releases only. Never commit directly. |
| `develop` | Pre-production. Every pull request targets this branch. |
| `feature/<name>`, `fix/<name>`, `docs/<name>` | Your work, created from `develop`. |
| `hotfix/<name>` | Urgent fix for a released version, created from `main` and merged into `main` **and** `develop`. |

## Workflow

1. Fork the repository (or create a branch if you are a maintainer).
2. Create your branch from `develop`:
   ```bash
   git checkout develop && git pull
   git checkout -b fix/my-fix
   ```
3. Make your change, then run (needs `mksh`, `sqlite3` and `shellcheck`):
   ```bash
   shellcheck -s ksh sdcard/run.sh
   shellcheck tests/*.sh scripts/*.sh
   tests/run_test.sh
   tests/payload_test.sh
   ```
4. Open a pull request **against `develop`** and fill in the template.
5. CI must be green and the maintainer must approve before merging. Pull requests are squash-merged.

## Rules for `run.sh`

The script runs on a car. A mistake can leave an MMI misconfigured, so:

- **Keep to POSIX sh features.** The MMI runs the QNX 6 Korn shell (pdksh): no arrays, no `[[ ]]`,
  no `local` (use `typeset`), no GNU options. The tests run it under `mksh`, the closest shell.
- **Only use tools that exist on the MMI** or that ship in `sdcard/utils/`. `sqlite3` is version 3.6.20:
  no `PRAGMA busy_timeout`, no `-cmd`, no `UPSERT`.
- **Never change anything before the start screen**, and never change a database without a
  checked backup.
- **Never create a file on the MMI.** A missing database is skipped.
- Every new behaviour gets a case in `tests/run_test.sh`.
- Files for the SD card keep LF line endings (`.gitattributes` enforces it).

Changing `copie_scr.sh` or a binary in `utils/` requires updating its SHA-256 in
`tests/payload_test.sh` and explaining where the new file comes from in the pull request.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: switch the menu off with a DISABLE file
fix: skip databases that do not exist
docs: add the A6 C6 firmware to the compatibility table
```

Types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `chore`, `ci`.

## Releases

1. Update `VERSION` in `sdcard/run.sh` and move the `Unreleased` notes of `CHANGELOG.md` to the new version.
2. Merge `develop` into `main` with a pull request "Release x.y.z".
3. **Actions › Release › Run workflow** on `main` with the tag `vx.y.z` (or push that tag): the
   workflow creates the tag, builds the ZIP, `SHA256SUMS.txt` and the provenance attestation, and
   uses the changelog section as the release description.

## Compatibility reports

Open an issue with the **Compatibility report** template: model, year, MMI variant, firmware
(`Firmware:` line of the log) and whether it worked. Attach `green_menu_activator.log`.
