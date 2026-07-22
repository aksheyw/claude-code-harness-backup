# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- **The script is now named `capture-harness.sh`, and the default output folder is `~/claude-harness-backup/`.** The old name described the emergency rather than the tool. Re-running it has always been safe, and running it weekly is what turns a one-time rescue into a backup, so the name and the docs now say that. If you cloned before this change, the old path is gone; update your command.
- **`GUIDE.md` gained Part 2.5, "Using this weekly instead of once".** The guide previously offered two rungs: run this once before you wipe, or build a full backup engine. There was nothing in between. Part 2.5 is the rung most people actually need, which is the same script, scheduled, committed to a private repo.

### Added

- **`CH_SYNC=1` turns on mirror mode**, so a file deleted from `~/.claude` is also removed from the backup. Off by default, because it is the only part of the script that can delete anything. It refuses to start if the output folder is your home directory, an ancestor of it, or `/`.
- **A `.gitignore` is written into the output folder** before anything can be committed, excluding `config/claude.json.SECRET`, `env-files/`, and `settings.json`. Ordering is the point: an ignore rule added after a first `git add -A` is too late.
- **Exit codes are now meaningful.** `0` means every copy succeeded, `1` means at least one failed, `2` means it refused to start.

### Fixed

- **A failed copy is no longer reported as a success.** Every copy is now checked. Previously `cp` failures were unchecked and the following report line said "Copied" regardless, so an unreadable `~/.claude.json`, the file holding every MCP token, produced a report claiming it was saved and an exit code of `0`. Someone acting on that report before wiping a disk would have lost those tokens. Failures are now named in the report, counted, and the closing message says the capture is incomplete.
- **The `skills/` copy had no fallback when `rsync` is missing**, unlike every other layer. On a machine without `rsync`, common on minimal Linux, the largest and least replaceable directory was silently not copied.
- **Hook commands quoted in the report are redacted.** An inline hook command can carry a token, and `report.md` is the file people paste into an issue.
- **`plugins` no longer reads as backed up.** It was listed in the counts table alongside directories that genuinely are copied, while the code only measured its size. The table now says explicitly that it is reinstalled rather than copied.
- **A failed `.env` copy is recorded** instead of passing silently under a blanket claim that the files were copied.

### Security

- **The output folder's own paths are no longer written through symlinks.** `report.md`, `.gitignore`, `config/`, `inventory/`, `env-files/` and `claude/` were written directly, so a symlink at any of them redirected the write, or in mirror mode the delete, to whatever it pointed at. The script now refuses to start if any of them is a symlink, and `copy_tree` resolves its destination's parent and refuses anything that does not physically live under the output folder.
- **URL credential redaction now covers the colon-free form** (`https://token@host`, how most forge tokens are actually pasted), not only `https://user:password@host`, and applies to marketplace URLs and hook commands as well as git remotes.
- **The report says plainly what its hook-command redaction cannot catch.** A secret passed as a bare argument such as `--token abc123` is indistinguishable from an ordinary word, and the report now says so where it matters rather than implying the block is clean.
- **The `.mcp.json` list says when it has been truncated**, and both searches state their depth. A capped list read as a complete one in a report used to decide what is safe to erase.

### Known limits

- Redaction is shape-based and cannot be exhaustive. Read `report.md` before sharing it.
- The containment checks are not atomic. A symlink swapped into the output folder in the moment between the check and the copy would defeat them. This is worth knowing if the folder lives somewhere other processes can write; it is not a concern for an ordinary folder in your home directory.

---

## [1.0.0] - 2026-07-21

First public release.

### Added

- **`GUIDE.md`**: the full guide. Capturing a setup off an old machine, rebuilding on a new one, a configuration reference checked against the current documentation, the secrets protocol, per-project scaffolding, and the reasoning behind the design.
- **`scripts/capture-harness.sh`**: reads a Claude Code setup and writes one output folder. Copies the authored layers, inventories projects for unpushed and untracked work, keeps credential values out of the readable report, and warns and waits for confirmation before copying anything.
- **`templates/`**: an example environment file, a secrets inventory, a per-project instructions file, a baseline ignore file, and a project wiki schema.
- **CI** that enforces this repo's own rules: shell syntax, shellcheck, the script staying in sync with its copy in the guide, a secret scan, and a run asserting the generated report contains no credential-shaped strings.

### Notes on what is verified and what is not

- The capture path has been run end to end repeatedly against a real setup, and every claim the README and `SECURITY.md` make about the script has been checked against the code.
- **The restore path has not been walked end to end on a genuinely fresh machine.** Its pieces have been, but not the whole sequence by someone starting cold. That is the single most useful thing a contributor could report back.
- Platform notes for Linux and Windows are reasoned from documentation, not all verified on those platforms. This was written on macOS.
