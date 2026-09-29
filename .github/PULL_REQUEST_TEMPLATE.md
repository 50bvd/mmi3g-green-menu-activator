## What does this change?

<!-- Short description. Link the issue it fixes: "Fixes #123" -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Compatibility (new MMI variant or firmware)
- [ ] Documentation / tooling

## Tested on

- [ ] Simulated MMI (`tests/run_test.sh`)
- [ ] Real car: model / year / firmware: …

## Checklist

- [ ] The pull request targets `develop` (not `main`)
- [ ] `shellcheck`, `tests/run_test.sh` and `tests/payload_test.sh` pass
- [ ] New behaviour of `run.sh` has a test case
- [ ] `run.sh` only uses POSIX sh features and tools available on the MMI
- [ ] `copie_scr.sh` and `utils/` are unchanged, or their new SHA-256 is explained
- [ ] `CHANGELOG.md` is updated (section "Unreleased")
