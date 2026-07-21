# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0]

First public release.

### Added

- **`GUIDE.md`**: the full guide. Capturing a setup off an old machine, rebuilding on a new one, a configuration reference checked against the current documentation, the secrets protocol, per-project scaffolding, and the reasoning behind the design.
- **`scripts/capture-old-laptop.sh`**: reads a Claude Code setup and writes one output folder. Copies the authored layers, inventories projects for unpushed and untracked work, keeps credential values out of the readable report, and warns and waits for confirmation before copying anything.
- **`templates/`**: an example environment file, a secrets inventory, a per-project instructions file, a baseline ignore file, and a project wiki schema.
- **CI** that enforces this repo's own rules: shell syntax, shellcheck, the script staying in sync with its copy in the guide, a secret scan, and a run asserting the generated report contains no credential-shaped strings.

### Notes on what is verified and what is not

- The capture path has been run end to end repeatedly against a real setup, and every claim the README and `SECURITY.md` make about the script has been checked against the code.
- **The restore path has not been walked end to end on a genuinely fresh machine.** Its pieces have been, but not the whole sequence by someone starting cold. That is the single most useful thing a contributor could report back.
- Platform notes for Linux and Windows are reasoned from documentation, not all verified on those platforms. This was written on macOS.
