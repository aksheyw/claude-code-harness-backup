# Claude Code Harness Backup: move your whole Claude Code setup to a new laptop without losing the parts you wrote

Claude Code is Anthropic's AI coding assistant. It runs in your terminal, reads the files in your project, and can change them for you. Out of the box it knows nothing about how you work, so you teach it, and what you teach it piles up in a folder called `~/.claude/`, which is where it keeps everything on your machine. I call that pile your **harness**, and it's made of five kinds of thing:

- **Rules**: standing instructions it loads into every session.
- **Skills**: playbooks it follows when a matching task comes up.
- **Subagents**: separate assistants with one job each, that the main one hands work to. They live in a folder called `agents/`, so you'll see both words for the same thing.
- **Commands**: shortcuts you type to start something you do often.
- **Hooks**: small scripts that run automatically at a fixed moment, so they can block an action instead of politely asking you not to take it.

Nearly all of that exists only because you wrote it, and it's sitting on exactly one laptop. This repo is a guide and a script for moving it to a new machine, and for rebuilding it if you never backed it up.

> Reinstalling Claude Code takes two minutes. The corrections you taught it don't come back, because you were the only copy.

I ran the script against my own setup and it pulled across 27 rules, 304 skills, 93 subagents, 114 commands and 58 hook scripts, and the report it wrote had zero secrets in it.

## Why I built this

All my projects are on GitHub, so I assumed I was covered. Then I thought properly about losing the laptop, and the projects turned out to be the one part that was fine. What had no backup anywhere was the harness itself: the rules I had corrected into place over months, the skills, the subagents, the hooks. Everything that makes Claude Code work the way I work instead of the way it ships.

That's the part you can't reinstall. A new machine gives you a new Claude Code that knows nothing about you, and you teach it all of it again from scratch. I didn't want to spend a week of evenings rediscovering corrections I'd already made once.

So I built it, and the secrets turned out to be the harder half. Reviewing the design before writing any code turned up six ways a plain `cp -r` would have leaked a credential, including a skill that was quietly holding a live browser session. Then the first real run refused to continue: the secret scan found seven live credentials sitting in my own memory files, in a folder I had gone through by hand the day before and passed as clean.

That's why this repo spends as much time on secrets as on copying. Backing up a harness means backing up the folder you've been most casual about pasting things into, and the naive version of this tool is a credential leak with a friendly name.

## What's in this repo

| Path | What it is |
|---|---|
| [`GUIDE.md`](GUIDE.md) | The full guide. Capture, rebuild, a configuration reference I checked against the current docs, the secrets protocol, and the reasoning behind the design |
| [`scripts/capture-harness.sh`](scripts/capture-harness.sh) | The script. Reads your setup and writes a report of what's about to be lost. Run it once before a wipe, or weekly as a backup |
| [`templates/`](templates/) | Copy-paste starting points: an example environment file, a secrets inventory, a per-project instructions file, a baseline ignore file, and a project wiki schema |

## Start here

Pick the line that describes you, because they lead to different places, and doing them in the wrong order means running the capture after the machine is already gone.

**You're moving laptops and the old one still works.** This is the urgent one, and it's time-boxed by when that machine goes away. Run the script before anything else:

```bash
git clone https://github.com/aksheyw/claude-code-harness-backup.git
bash claude-code-harness-backup/scripts/capture-harness.sh
```

It doesn't touch your setup. The only thing it writes is its own output folder, and it never edits or deletes anything in `~/.claude/`, and never pushes anywhere. It tells you what to fix before you wipe. Then read [Part 2 of the guide](GUIDE.md#part-2-capture-the-old-machine).

**The old machine is already gone.** Start at [Part 3](GUIDE.md#part-3-rebuild-on-the-new-machine) and work from whatever backup you've got. Some of it you won't get back, and the guide says which parts instead of pretending there's a trick.

**You're setting up from scratch, or you want a better harness.** Skip the migration. [Part 5](GUIDE.md#part-5-the-layers-in-detail) builds the layers up in the order they become worth having, and [Part 9](GUIDE.md#part-9-principles-worth-stealing) is why it's shaped that way.

**Nothing is wrong, you just want this backed up every week.** This is the one most people should end up on, and it's the same script on a schedule rather than a separate tool. Re-running it is safe: the report is rewritten each time and the copies are updated in place.

```bash
CH_SYNC=1 CH_YES=1 bash claude-code-harness-backup/scripts/capture-harness.sh
```

`CH_SYNC=1` mirrors deletions, so a rule you delete stops living in the backup forever. `CH_YES=1` skips the prompt so it can run unattended. Then commit the output folder to a **private** repo for history. The script writes a `.gitignore` excluding the credential-bearing files before anything can be committed. [Part 2.5](GUIDE.md#25-using-this-weekly-instead-of-once) covers the scanning you should still do yourself.

**You want your AI assistant to do this for you.** Hand it `GUIDE.md` and say so. It opens with a brief written for exactly that, which tells the assistant what to do first, what to leave alone, and what to verify before it tells you it's finished.

## Verify it worked

Three things should be true after the script runs.

```bash
# 1. There's a report and it isn't empty
wc -l ~/claude-harness-backup/report.md

# 2. The parts nobody can regenerate actually came across.
#    Note: subagents live in a folder called `agents`.
for d in rules skills agents commands scripts hooks memory; do
  printf '%-10s %s files\n' "$d" "$(find -L ~/claude-harness-backup/claude/$d -type f 2>/dev/null | wc -l)"
done

# 3. The report itself has no secrets in it, only names and locations
grep -cE 'sk-[A-Za-z0-9]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_-]{30,}' ~/claude-harness-backup/report.md
```

That last one has to print `0`. Your real secrets do get copied into the folder, on purpose, so the migration doesn't lose them. They're kept out of the readable report, so you can paste that report into an issue without leaking anything.

## What it looks like running

This is the first table from a real run on my machine, with only the symlink target shortened:

```
| Layer | Path | Count |
|---|---|---|
| agents | `~/.claude/agents` | 93 files |
| commands | `~/.claude/commands` | 114 files |
| rules | `~/.claude/rules` | 27 files |
| skills | `~/.claude/skills` (symlink -> <elsewhere>) | 2142 files |
| hooks | `~/.claude/hooks` | 1 files |
| scripts | `~/.claude/scripts` | 214 files |
| memory | `~/.claude/memory` | 19 files |
| plugins | `~/.claude/plugins` | 40840 files |
| scheduled-tasks | `~/.claude/scheduled-tasks` | 16 files |
```

Two things worth reading off that. `skills` is a symlink pointing outside `~/.claude/`, which a naive copy would preserve as a dead link on the new machine, so the script follows it. And `plugins` is 40,840 files, which is why the script does not copy them: they reinstall from a marketplace, and carrying them would make the output enormous for no gain.

Then it checks your projects. That is a second safety net rather than the main event, since most people's code is already on a remote, but the report tells you where that assumption is wrong:

```
| Project        | Git?        | Remote                          | Unpushed        | Uncommitted |
|----------------|-------------|---------------------------------|-----------------|-------------|
| api-service    | yes (main)  | https://github.com/you/api.git  | 0               | 0           |
| design-notes   | **NO GIT**  | none                            | n/a             | **all of it** |
| mobile-app     | yes (dev)   | https://github.com/you/app.git  | 6               | 9           |
| scratch        | yes (main)  | **NONE**                        | **no upstream** | 3           |
```

That one is illustrative, not a real run. Three of those four rows are a problem. `design-notes` has no version history at all, `mobile-app` has 6 commits and 9 changed files that exist nowhere else, and `scratch` has history but nowhere to push it. Only the first row is safe.

## When to use this, and when not to

**Use it if** you're changing machines, or you've built up a real amount of custom setup, or you want a backup you can actually repeat instead of hoping a cloud sync picked the folder up.

**Don't bother if** you installed Claude Code last week and haven't customised anything. There's nothing to lose yet. Come back when there is.

**It's not a sync tool.** It won't keep two machines in step and it doesn't run in the background. You run it once, on purpose, when you're about to lose a machine, and if you want that automated the guide has enough reasoning for you to build it yourself.

## Security: what this touches

The script reads your config and copies some of it, including files with live credentials in them. That's deliberate, because the alternative is losing them, but it means you have to handle the output carefully.

- It warns you before it copies anything, and waits for you to confirm.
- The readable report has names and locations in it, never a value.
- The output folder itself does contain real credentials, in plain text. Move it over an encrypted channel, then delete it from the old machine.
- Don't put that folder in a git repo.

The guide's [secrets protocol](GUIDE.md#part-6-secrets-the-part-that-goes-wrong) covers the wider problem, and the part that matters most is that git history is append-only, so a secret has to be kept out of the first commit. Taking it out later doesn't help.

Found a security problem in this repo? Use [SECURITY.md](SECURITY.md), not a public issue.

## Troubleshooting

**The project table is empty, or it says no folder found.** The script looks in `~/Documents/Claude Code` by default. Point it wherever you actually keep projects:

```bash
PROJ_ROOT="$HOME/code" bash scripts/capture-harness.sh
```

**It says `command not found: jq`.** `jq` is a small command-line tool for reading JSON, which is the format Claude Code stores its config in. The script still runs without it, but it can't read your settings, so most of the report goes missing. `brew install jq` on macOS, `apt install jq` on Debian and Ubuntu, then run it again.

**Every session errors after you restore on the new machine.** Almost always the hooks. Your settings file records where each hook script lives as a full path with your old username in it, and that path doesn't exist on the new machine, so every session fails trying to run them. [Part 3.2](GUIDE.md#32-restore-the-identity) has the fix, and the bit people get wrong is that you rewrite the paths *before* you copy the settings file into place, not after.

**You want to run it unattended.** Set `CH_YES=1` and it skips the confirmation.

**You're on Windows.** Use WSL or Git Bash, which are both ways of getting a Linux-style terminal on Windows. Native PowerShell and `cmd` won't work.

## Companion repos

This sits in a family of Claude Code tooling I keep, and the guide's five layers each have a repo of their own:

- [claude-code-rules](https://github.com/aksheyw/claude-code-rules): the rules layer. Opinionated global rules covering honesty and earned confidence, TDD, immutability, and branch strategy.
- [claude-code-learned-skills](https://github.com/aksheyw/claude-code-learned-skills): the skills layer. 12 skills pulled out of real debugging and research sessions.
- [claude-code-pm-agents](https://github.com/aksheyw/claude-code-pm-agents): the subagents layer. Seven specialists covering the product-builder lifecycle.
- [claude-code-guardrail-hooks](https://github.com/aksheyw/claude-code-guardrail-hooks): the hooks layer. Four hooks that block or capture a mistake at the tool-call boundary, including the secret scan this guide leans on.
- [context-bridge](https://github.com/aksheyw/context-bridge): the per-project layer. A small project wiki plus a generated handoff prompt, so a session picks up warm instead of cold.
- [claude-code-ship-gate](https://github.com/aksheyw/claude-code-ship-gate): the gate that stops an un-reviewed push reaching your protected branch.
- [awesome-claude-code-toolkit](https://github.com/aksheyw/awesome-claude-code-toolkit): the wider toolkit these sit in.

If you're rebuilding a machine from scratch, those are a faster starting point than an empty `~/.claude/`.

## Credits

A few things I took from other people. Keeping a secret out of the first commit rather than scrubbing it later is standard practice, and [gitleaks](https://github.com/gitleaks/gitleaks) is what the guide points you at for the actual scanning, because it does that far better than the grep patterns I'd have written. The idea of a project wiki that compounds across sessions instead of being rewritten each time comes from [Andrej Karpathy's LLM wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## License

MIT. See [LICENSE](LICENSE).

---

Built by [Akshey Walia](https://github.com/aksheyw). If something here is wrong, or it broke on your setup, please open an issue and say what happened.
