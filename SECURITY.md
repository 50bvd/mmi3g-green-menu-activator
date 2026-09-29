# Security Policy

This script changes the configuration database of a car's infotainment unit,
so reports about anything that could damage an MMI are taken seriously.

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.1.x | ✅ |
| 1.0.x | ❌ please upgrade (backups were not written) |

## Reporting a vulnerability

**Do not open a public issue.** Report it privately through
[GitHub Security Advisories](https://github.com/50bvd/mmi3g-green-menu-activator/security/advisories/new).

Please include the version, your MMI variant and firmware (`Firmware:` line of
`green_menu_activator.log`) and the steps to reproduce.
You should receive an answer within 7 days. Once a fix is released, the advisory is published
and you are credited unless you prefer otherwise.

## How the script protects your MMI

- Nothing is changed before you confirm the start screen.
- Only one row is written: `tb_intvalues`, namespace `4`, key `4100`. No other table or value is touched.
- Every database is backed up to the SD card and the backup is checked before the change.
- The change is one SQL transaction, and it is read back afterwards.
- The script makes no network access and does not start any other program on the MMI.

## Verify what you run

- Releases are built by GitHub Actions from this repository. Check the ZIP with
  `gh attestation verify <file> --repo 50bvd/mmi3g-green-menu-activator` and
  with `SHA256SUMS.txt`.
- `copie_scr.sh` is encrypted (the MMI only runs encrypted launchers). Its decoded
  content is in [`docs/copie_scr.sh.dec`](docs/copie_scr.sh.dec): it only changes to the SD card
  and starts `run.sh`. Its SHA-256 and those of the QNX tools are pinned in
  `tests/payload_test.sh`, so they cannot change unnoticed.

## Scope

In scope: anything that changes the MMI beyond the Green Menu flag, a failure that leaves a
database changed without a valid backup, a way to run other code through the SD card content.

Out of scope: settings changed by hand in the Green Menu, and MMI variants listed as not compatible.
