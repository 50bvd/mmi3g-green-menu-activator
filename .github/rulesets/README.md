# Branch rulesets

Versioned copies of this repo's branch protection, so it is documented and easy
to re-apply.

- `main.json` — protects the default branch: no deletion, no force-push, requires
  a pull request (0 approvals — solo friendly) and the CI checks `ShellCheck` and
  `Test` to pass. Repository admins can bypass.
- `develop.json` — lighter: no deletion, no force-push.

## Apply them (choose one)

### A. Import in the UI (easiest)
**Settings → Rules → Rulesets → New ruleset → Import a ruleset**, then select the
JSON file. Repeat for each file. Review and **Save**.

### B. GitHub CLI

```bash
gh api --method POST repos/50bvd/mmi3g-green-menu-activator/rulesets --input .github/rulesets/main.json
gh api --method POST repos/50bvd/mmi3g-green-menu-activator/rulesets --input .github/rulesets/develop.json
```

## Note on required checks
`main.json` requires the `ShellCheck` and `Test` jobs from `.github/workflows/ci.yml`.
If a job name changes, update the matching `context` value (or pick it from the
dropdown when importing) so pull requests are not blocked waiting on a
non-existent check.
