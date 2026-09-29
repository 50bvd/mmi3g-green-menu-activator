# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-09-29

### Added
- **Backups you can trust**: each database is copied to `backup/<name>/` on the SD card and the copy is checked with `PRAGMA integrity_check` before anything is changed. The first backup ever made (`DataPST.db.orig`) is never overwritten, even if the script is run again.
- **Error screen** (`screens/scriptError.png`): shown when something went wrong, instead of the "Script applied" screen.
- **Switch the menu off**: put an empty file named `DISABLE` (or `DISABLE.txt`) at the root of the SD card and run the script again.
- The result (`RESULT: OK` or `RESULT: FAILED`) and the script version are written to the log.
- Tests that run the script on a simulated MMI (`tests/run_test.sh`), payload checks with pinned SHA-256 for the launcher and the QNX tools (`tests/payload_test.sh`), ShellCheck, CI and a release workflow (tag push or **Run workflow** in the Actions tab) that publishes the ZIP with `SHA256SUMS.txt` and a signed build provenance attestation.
- Repository files shared with the other 50bvd projects: security policy, contribution guide, code of conduct, issue and pull request templates, branch rulesets, `.editorconfig`, `.gitattributes`.

### Changed
- The delete and the insert are now **one SQL transaction**: a database is either fully changed or left as it was.
- A database that already has the right value is left untouched (no write, no new backup).
- A database that is missing on this MMI variant is skipped. Before, `sqlite3` created an empty `DataPST.db` at that path.
- If the MMI holds a lock on a database, each SQL call is tried three times before giving up.
- The SD card directory is the directory of `run.sh`, so a second card in the other slot cannot confuse the script.
- Files written to the MMI are flushed (`sync`) before the end screen.
- The SD card content moved to `sdcard/`; the decoded launcher moved to `docs/copie_scr.sh.dec` and is no longer copied to the card.
- Documented restart combination: **MENU + rotary knob + top-right soft key**.

### Fixed
- The backups were never written: the `DB/*/old`, `process` and `new` folders did not exist in the release (git does not store empty folders), so every `cp` failed and the databases were changed without a backup.
- Line endings are forced to LF for scripts and `copie_scr.sh` is marked binary, so a checkout on Windows cannot break them.

## [1.0.0] - 2026-04-20

### Added
- First release: SD card script that sets `pst_key=4100` to `1` in namespace `4` of the three `DataPST.db` locations, with a log file on the SD card.

[Unreleased]: https://github.com/50bvd/mmi3g-green-menu-activator/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/50bvd/mmi3g-green-menu-activator/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/50bvd/mmi3g-green-menu-activator/releases/tag/v1.0.0
