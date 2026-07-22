# Security

## Reporting a problem

Please don't open a public issue for a security problem. Use GitHub's private vulnerability reporting on this repo, under the Security tab.

If the problem is that this repo leaked a credential of yours or of mine, say so in the first line, because that is time-sensitive and I will pick it up ahead of everything else.

## What this project touches, and why that matters

This is mostly documentation, but it ships one script that reads your machine, so here is exactly what that script touches.

`scripts/capture-harness.sh`:

- **Reads** your Claude Code configuration, your shell profiles, and your project folders' git status.
- **Writes** a single output folder, by default `~/claude-harness-backup/`.
- **Never** edits or deletes anything in `~/.claude/`, and never pushes anywhere.
- **Copies real credentials into that output folder on purpose.** Specifically `~/.claude.json`, which can hold tokens, and every `.env` file it finds. It does that so a migration does not silently lose them.

It warns you and waits for you to confirm before it copies anything.

**The one place it can delete** is inside its own output folder, and only when you ask for it. `CH_SYNC=1` turns on mirror mode, which propagates deletions so the backup does not accumulate files you removed on purpose. It is off by default, it only ever affects paths the script itself created under the output folder, and it refuses to start if the output folder is your home directory, an ancestor of it, or `/`. Nothing outside the output folder is ever deleted in any mode.

**It fails loudly rather than silently.** Every copy is checked. If any copy fails, the failure is named in the report, the closing message says the capture is incomplete, and the script exits `1`. Exit `0` means everything it tried to copy, it copied. Exit `2` means it refused to start. This matters more than it sounds: people read this report and then erase a disk, so a copy that quietly failed while the report said "Copied" would cost someone their work.

**That output folder isn't encrypted.** Treat it like a password file:

- Move it between machines over an encrypted channel.
- Delete it from the old machine once the move is done.
- If you version it for history, the repo must be **private**. The script writes a `.gitignore` into the output folder before anything can be committed, excluding `config/claude.json.SECRET`, `env-files/`, and `settings.json`. That ignore list covers what is secret **by design**; it cannot cover a token you once pasted into a rule or a memory file. Scan before your first push, and do not treat the `.gitignore` as permission to stop looking.
- This repo's own ignore file does **not** protect you: the output folder defaults to `~/claude-harness-backup/`, outside the repo entirely. If you keep your home directory under version control, add `claude-harness-backup/` to that ignore file yourself.

The readable report inside that folder is meant to be safe to share, so it records credential **names** and **locations** and never values. Hook commands quoted in the report are passed through a redactor, because an inline hook command can carry a token. If you ever find a real secret value in `report.md`, that is a bug and I want to hear about it.

## Scope

**In scope:** the script leaking a secret into its report, writing outside its output folder, deleting or changing anything, or any advice in the guide that would get a reader to expose a credential.

**Out of scope:** anything in Claude Code itself, in `gitleaks`, or in another tool the guide mentions. Those go to their own maintainers.

## Response times

This is a personal project, not a staffed one. I aim to acknowledge a report within 72 hours and fix a confirmed leak-class issue within a week. If it's a live credential exposure I'll drop everything else.

## A note on the advice in the guide

The guide points you at `gitleaks` and a set of grep patterns for catching secrets before a first commit, and **neither one is exhaustive.** Pattern matching can't catch a credential in a format it doesn't know, and it can't catch a secret sitting in an ordinary config file under an ordinary key name. The guide says so in the text and I'm repeating it here, because a scanner coming back clean is exactly the thing that makes people stop looking. Read what you're committing.
