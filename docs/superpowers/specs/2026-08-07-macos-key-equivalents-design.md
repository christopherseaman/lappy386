# macOS Key Equivalents Design

## Goal

Configure the macOS keyboard shortcuts for Safari and the Codex app during
machine setup, including when the Codex app has not yet created its preference
domain.

## Design

Append an unconditional keyboard-shortcuts section to `tools/setup-macos.sh`
immediately after `./setup-common.sh`. `setup-common.sh` invokes
`setup-cli.sh`, which installs or updates the Codex CLI, so this keeps the
preference writes after the existing Codex installation path.

The section will run these idempotent preference updates:

```bash
defaults write com.apple.Safari NSUserKeyEquivalents -dict-add "Close Tab" '@w'
defaults write com.openai.codex NSUserKeyEquivalents -dict-add "New Window" '@n'
```

No application-presence check, launch, quit, or restart is needed. The
`defaults` command writes the preference domain and nested dictionary before
the app exists; each app will use the mapping the next time it reads its
preferences.

## Error handling and validation

The setup script will retain its existing behavior and will not add a
destructive cleanup path. Validation will consist of shell syntax checking,
confirming the commands occur after the common setup call, and an isolated
`defaults` smoke test using a temporary preference domain with no pre-existing
`NSUserKeyEquivalents` dictionary.
