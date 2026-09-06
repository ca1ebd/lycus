# Architecture decisions

Standalone write-ups of *why* Lycus looks the way it does — the non-obvious
tradeoffs, not the configuration itself. `SPEC.md` describes the machine and
`AUTOMATION.md` the automation; these explain the choices behind both.

| # | Decision |
|---|---|
| [0001](0001-terraform-target-contract.md) | Pluggable Terraform targets behind a fixed output contract |
| [0002](0002-root-installs-hermes-user-runs-it.md) | Root installs Hermes, the `hermes` user runs it |
| [0003](0003-playwright-browsers-not-apt-chromium.md) | Playwright's own browsers, never apt chromium |
| [0004](0004-secrets-out-of-bashrc.md) | Secrets in a 0600 file, not in `.bashrc` |
| [0005](0005-rebuild-config-restore-state.md) | Rebuild configuration, restore only state |
| [0006](0006-nodesource-with-an-apt-pin.md) | Node from NodeSource, with an apt pin that actually binds |
