# Security

## Reporting a problem

Please don't open a public issue for a security problem. Use GitHub's private vulnerability reporting on this repo, under the Security tab.

If the problem is that this repo leaked a credential of yours or of mine, say so in the first line, because that's time-sensitive and I'll pick it up ahead of everything else.

## What this project touches, and why that matters

This is mostly documentation, but it ships one script that reads your machine, so here's exactly what that script touches.

`scripts/capture-old-laptop.sh`:

- **Reads** your Claude Code configuration, your shell profiles, and your project folders' git status.
- **Writes** a single output folder, by default `~/claude-migration/`.
- **Never** edits or deletes anything in `~/.claude/`, and never pushes anywhere.
- **Copies real credentials into that output folder on purpose.** Specifically `~/.claude.json`, which can hold tokens, and every `.env` file it finds. It does that so a migration doesn't silently lose them.

It warns you and waits for you to confirm before it copies anything.

**That output folder isn't encrypted.** Treat it like a password file:

- Move it between machines over an encrypted channel.
- Delete it from the old machine once the move is done.
- Don't commit it. The ignore file here excludes `claude-migration/` as a backstop, but don't rely on that.

The readable report inside that folder is meant to be safe to share, so it records credential **names** and **locations** and never values. If you ever find a real secret value in `report.md`, that's a bug and I want to hear about it.

## Scope

**In scope:** the script leaking a secret into its report, writing outside its output folder, deleting or changing anything, or any advice in the guide that would get a reader to expose a credential.

**Out of scope:** anything in Claude Code itself, in `gitleaks`, or in another tool the guide mentions. Those go to their own maintainers.

## Response times

This is a personal project, not a staffed one. I aim to acknowledge a report within 72 hours and fix a confirmed leak-class issue within a week. If it's a live credential exposure I'll drop everything else.

## A note on the advice in the guide

The guide points you at `gitleaks` and a set of grep patterns for catching secrets before a first commit, and **neither one is exhaustive.** Pattern matching can't catch a credential in a format it doesn't know, and it can't catch a secret sitting in an ordinary config file under an ordinary key name. The guide says so in the text and I'm repeating it here, because a scanner coming back clean is exactly the thing that makes people stop looking. Read what you're committing.
