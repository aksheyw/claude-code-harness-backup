<div align="center">

# 📦 Claude Code Harness Backup: move your Claude Code setup to a new laptop without losing the parts you wrote

### Reinstalling Claude Code takes two minutes. The corrections you taught it don't come back, because you were the only copy.

![requires](https://img.shields.io/badge/requires-Claude%20Code-D97757) ![your setup](https://img.shields.io/badge/your%20setup-never%20modified-0E9384) ![output folder](https://img.shields.io/badge/output%20folder-holds%20real%20secrets-B42318) ![license](https://img.shields.io/badge/license-MIT-green) ![CI](https://github.com/aksheyw/claude-code-harness-backup/actions/workflows/ci.yml/badge.svg)

</div>

---

Claude Code is Anthropic's AI coding assistant. It runs in your terminal, reads the files in your project, and can change them for you. Out of the box it knows nothing about how you work, so you teach it, and what you teach it piles up in a folder called `~/.claude/` on one laptop. I call that pile your **harness**. This repo is a guide and a script for moving it to a new machine, and for rebuilding it if you never backed it up.

![What a reinstall gives you back, and what it doesn't. You can get this back, though each one takes a manual step: Claude Code itself in about two minutes, plugins installed from a marketplace, which reinstall from the list in the report, though locally uploaded ones do not, and any project you have already pushed. Doesn't come back, because you wrote it: 27 rules, standing instructions loaded into every session; 304 skills, playbooks it follows when a task matches; 93 subagents, separate assistants with one job each, in a folder called agents; 114 commands, shortcuts you type to start something you do often; and 58 hook scripts, which fire automatically and can block an action. Those counts are from one real run on my own machine. Nothing on the right reinstalls, it exists because you taught it, on exactly one laptop, and this repo copies that side to a folder you can move and tells you what it could not save.](docs/what-a-reinstall-gives-back.svg)

## What you'd lose, and why it isn't your code

All my projects are on GitHub, so I assumed I was covered. When I actually thought about losing the laptop, the projects turned out to be the one part that was fine. What had no backup anywhere was the harness itself, the parts I had written: everything that makes Claude Code work the way I work instead of the way it ships. A new machine gives you one that knows nothing about you, and you teach all of it again from scratch.

## Why I built this, and why the secrets were the harder half

I didn't want to spend a week of evenings rediscovering corrections I had already made once.

So I built it, and the secrets turned out to be the harder half. Reviewing the design before writing any code turned up six ways a plain `cp -r` would have leaked a credential, including a skill that was quietly holding a live browser session. Then the first real run refused to continue: the secret scan found seven live credentials sitting in my own memory files, in a folder I had gone through by hand the day before and passed as clean.

That's why this repo spends as much time on secrets as on copying. Backing up a harness means backing up the folder you've been most casual about pasting things into, and the naive version of this tool is a credential leak with a friendly name.

## What it copies, and what that means for your secrets

The script reads your setup and copies part of it into one folder, `~/claude-harness-backup/`, which is the thing you carry to the new machine. It never edits or deletes anything in `~/.claude/`, and it never pushes anywhere.

That output folder is the part to be careful with.

- **It holds real credentials, in plain text.** At minimum your `~/.claude.json`, which can hold access tokens for the other tools you've connected, and every `.env` file it finds under your projects folder. Your settings, rules and memory files come across too, and a memory file is exactly where a pasted token ends up, which is where the seven above were sitting. This script doesn't hunt for those, so checking is still on you. All of it is deliberate, because the alternative is a migration that loses them.
- **It warns you and pauses for Enter** before it copies anything, as long as you're running it in a terminal. `CH_YES=1` skips that pause so it can run on a schedule, and so does a run with nothing on its input at all, which is what cron gives it.
- **The readable report is built to hold names and locations, never a value.** This repo's tests plant fake credentials in a synthetic setup, run the real script against it, and fail if any of those values turn up in the report.
- **Move the folder over an encrypted channel**, then delete it from the old machine, but not until the new one actually works. [Part 8](GUIDE.md#part-8-the-acceptance-test) is the check for that. I have done every piece of the restore, just never the whole sequence in one go on a machine that wasn't mine, so keep the old copy until you have.
- **Only put it in a git repo if that repo is private.** The script writes a `.gitignore` into the folder before anything can be committed, which is the ordering that matters. Read that list before your first push, because it covers what's secret by design, not a token you once pasted into a rule.

I ran this against my own setup, and the report it wrote had zero secrets in it.

The guide's [secrets protocol](GUIDE.md#part-6-secrets-the-part-that-goes-wrong) covers the wider problem, and the part that matters most is that git history is append-only, so a secret has to be kept out of the first commit. Taking it out later doesn't help.

Found a security problem in this repo? Use [SECURITY.md](SECURITY.md), not a public issue.

## Start here

Pick the line that describes you, because they lead to different places, and doing them in the wrong order means running the capture after the machine is already gone.

**You're moving laptops and the old one still works.** This is the urgent one, and it's time-boxed by when that machine goes away. Run the script before anything else:

```bash
git clone https://github.com/aksheyw/claude-code-harness-backup.git
bash claude-code-harness-backup/scripts/capture-harness.sh
```

It leaves your setup alone. The one thing it writes is `~/claude-harness-backup/`, and that folder will hold your credentials in plain text. That's deliberate, because the alternative is losing them in the move. The script says so on screen and, in a terminal, waits for you to press Enter before it copies anything, and the report it writes tells you what to fix before you wipe. Then run the checks below, and read [Part 2 of the guide](GUIDE.md#part-2-capture-the-old-machine).

It looks for your projects in `~/Documents/Claude Code`. If you keep them somewhere else, say so, or it will find none of them and none of their `.env` files:

```bash
PROJ_ROOT="$HOME/code" bash claude-code-harness-backup/scripts/capture-harness.sh
```

**The old machine is already gone.** Start at [Part 3](GUIDE.md#part-3-rebuild-on-the-new-machine) and work from whatever backup you've got. Some of it you won't get back, and the guide says which parts instead of pretending there's a trick.

**You're setting up from scratch, or you want a better harness.** Skip the migration. [Part 5](GUIDE.md#part-5-the-layers-in-detail) builds the layers up in the order they become worth having, and [Part 9](GUIDE.md#part-9-principles-worth-stealing) is why it's shaped that way.

**Nothing is wrong, you just want this backed up every week.** It's the same script on a schedule rather than a separate tool. Re-running it is safe: the report is rewritten each time and the copies are updated in place.

```bash
CH_SYNC=1 CH_YES=1 bash claude-code-harness-backup/scripts/capture-harness.sh
```

`CH_SYNC=1` mirrors deletions in the `~/.claude` folders it copies, so a rule you delete there goes from the backup too. It needs `rsync` installed and refuses to start without it, rather than quietly making a copy that isn't a mirror. `CH_YES=1` skips the confirmation, which is what lets it run unattended, so read that warning once yourself before you schedule it. Then commit the output folder to a **private** repo for history. [Part 2.5](GUIDE.md#25-using-this-weekly-instead-of-once) covers the scanning you should still do yourself.

**You want your AI assistant to do this for you.** Hand it `GUIDE.md` and say so. It opens with a brief written for exactly that, which tells the assistant what to do first, what to leave alone, and what to verify before it tells you it's finished.

## Did it work?

Start with the one that matters most. If anything failed to copy, the script tells you: it exits with an error and writes **FAILED** into the report beside whatever it couldn't take. Search the report for that word, and don't wipe the old machine until every one of them is resolved. If it refuses to start at all, which mirror mode does on an unsafe output folder, it leaves the previous report sitting there untouched, so check the date at the top is from this run before you trust it.

Then three things should be true: there is a report, the folders nobody can regenerate actually came across, and no secret values leaked into the readable report. The second check names two folders the picture above doesn't: `scripts/`, the helper scripts your setup calls, and `memory/`, the notes Claude Code keeps for itself. Both get carried across.

```bash
# 1. There's a report and it isn't empty
wc -l ~/claude-harness-backup/report.md

# 2. The parts nobody can regenerate actually came across.
#    Note: subagents live in a folder called `agents`.
for d in rules skills agents commands scripts hooks memory scheduled-tasks; do
  printf '%-10s %s files\n' "$d" "$(find -L ~/claude-harness-backup/claude/$d -type f 2>/dev/null | wc -l)"
done

# 3. The report has none of these key shapes in it
grep -cE 'sk-[A-Za-z0-9]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_-]{30,}' ~/claude-harness-backup/report.md
```

That last one has to print `0`. Your real secrets do get copied into the folder, on purpose, so the migration doesn't lose them, and they're kept out of the readable report so that report is the part you can share. The redaction works on shapes it recognises though, so something like `--token abc123` still reads as an ordinary word, which is why the report tells you to read its hook-commands block before you paste it anywhere.

<details>
<summary>📄 <b>What the report looks like on a real run</b>, and the rows worth arguing with</summary>

This is the first table from a real run on my machine, with only the symlink target shortened:

```
| Layer | Path | Count | In scope? |
|---|---|---|---|
| agents | `~/.claude/agents` | 93 files | yes, see the copy list below |
| commands | `~/.claude/commands` | 114 files | yes, see the copy list below |
| rules | `~/.claude/rules` | 27 files | yes, see the copy list below |
| skills | `~/.claude/skills` (symlink -> <elsewhere>) | 2142 files | yes, see the copy list below |
| hooks | `~/.claude/hooks` | 1 files | yes, see the copy list below |
| scripts | `~/.claude/scripts` | 214 files | yes, see the copy list below |
| memory | `~/.claude/memory` | 23 files | yes, see the copy list below |
| plugins | `~/.claude/plugins` | 39873 files | **no**, reinstalled (see section 5) |
| scheduled-tasks | `~/.claude/scheduled-tasks` | 16 files | yes, see the copy list below |
```

A few things worth reading off that. The counts here are **files**, which is why they don't match the picture at the top of the page: 2,142 files is what those 304 skills are made of, one folder each. `skills` is also a symlink pointing outside `~/.claude/`, which a naive copy would preserve as a dead link on the new machine, so the script follows it. `plugins` is 39,873 files and is the one row marked **no**, because plugins reinstall from a marketplace and carrying them would make the output enormous for no gain. And that column says what the script *tries* to copy, not what it managed to copy: the outcome is the copy list underneath, plus any line marked FAILED. Those are separate on purpose, because a table that reported success before the copy ran would be the most dangerous thing in the report.

The `hooks` count is 1 because on this machine the hook scripts themselves live under `scripts/`, and `hooks/` holds a single config file. Yours may be arranged differently.

Then it checks your projects. That's a second safety net rather than the main event, since most people's code is already on a remote:

```
| Project        | Git?        | Remote                          | Unpushed        | Uncommitted |
|----------------|-------------|---------------------------------|-----------------|-------------|
| api-service    | yes (main)  | https://github.com/you/api.git  | 0               | 0           |
| design-notes   | **NO GIT**  | none                            | n/a             | **all of it** |
| mobile-app     | yes (dev)   | https://github.com/you/app.git  | 6               | 9           |
| scratch        | yes (main)  | **NONE**                        | **no upstream** | 3           |
```

That one is illustrative, not a real run. Three of those four rows are a problem. `design-notes` has no version history at all, `mobile-app` has 6 unpushed commits and 9 changed files, and `scratch` has history but no `origin` remote.

</details>

## When to use this, and when not to

**Use it if** you're changing machines, or you've built up a real amount of custom setup, or you want a backup you can actually repeat instead of hoping a cloud sync picked the folder up.

**Don't bother if** you installed Claude Code last week and haven't customised anything. There's nothing to lose yet. Come back when there is.

**It won't keep two machines in step.** It copies one machine's setup into a folder, and it doesn't run in the background, so scheduling it is something you set up yourself. [Part 2.5](GUIDE.md#25-using-this-weekly-instead-of-once) is the ten-minute version of that.

<details>
<summary>🔧 <b>Troubleshooting</b>: an empty project table, a missing <code>jq</code>, every session erroring after you restore, Windows</summary>

**The project table is empty, or it says no folder found.** The script looks in `~/Documents/Claude Code` by default. Point it wherever you actually keep projects:

```bash
PROJ_ROOT="$HOME/code" bash scripts/capture-harness.sh
```

**It says `command not found: jq`.** `jq` is a small command-line tool for reading JSON, which is the format Claude Code stores its config in. The script still runs without it, but it can't read your settings. `brew install jq` on macOS, `apt install jq` on Debian and Ubuntu, then run it again.

**Every session errors after you restore on the new machine.** Almost always the hooks. Your settings file records where each hook script lives as a full path with your old username in it, and that path doesn't exist on the new machine, so every session fails trying to run them. [Part 3.2](GUIDE.md#32-restore-the-identity) has the fix, and the bit people get wrong is that you rewrite the paths *before* you copy the settings file into place, not after.

**You want to run it unattended.** Set `CH_YES=1` and it skips the confirmation.

**You're on Windows.** Use WSL or Git Bash, which are both ways of getting a Linux-style terminal on Windows. Native PowerShell and `cmd` won't work.

</details>

<details>
<summary>📋 <b>What's in this repo</b>: the guide, the script, and five copy-paste templates</summary>

| Path | What it is |
|---|---|
| [`GUIDE.md`](GUIDE.md) | The full guide. Capture, rebuild, a configuration reference I checked against the docs, the secrets protocol, and the reasoning behind the design |
| [`scripts/capture-harness.sh`](scripts/capture-harness.sh) | The script. Reads your setup, copies part of it into one folder, and writes a report of what's about to be lost |
| [`templates/`](templates/) | Copy-paste starting points: an example environment file, a secrets inventory, a per-project instructions file, a baseline ignore file, and a project wiki schema |

</details>

## Companion repos

This sits in a family of Claude Code tooling I keep. Each of these publishes a few of my own rules, skills, subagents or hooks as a starting point, which is why the counts below are so much smaller than the ones in the picture at the top:

- [claude-code-rules](https://github.com/aksheyw/claude-code-rules): the rules layer. Opinionated global rules covering honesty and earned confidence, TDD, immutability, and branch strategy.
- [claude-code-learned-skills](https://github.com/aksheyw/claude-code-learned-skills): the skills layer. 12 skills pulled out of real debugging and research sessions.
- [claude-code-pm-agents](https://github.com/aksheyw/claude-code-pm-agents): the subagents layer. Seven specialists covering the product-builder lifecycle.
- [claude-code-guardrail-hooks](https://github.com/aksheyw/claude-code-guardrail-hooks): the hooks layer. Four hooks that block or capture a mistake at the tool-call boundary, including the secret scan this guide leans on.
- [context-bridge](https://github.com/aksheyw/context-bridge): the per-project layer. A small project wiki plus a generated handoff prompt, so a session picks up warm instead of cold.
- [claude-code-ship-gate](https://github.com/aksheyw/claude-code-ship-gate): the gate that stops an un-reviewed push reaching your protected branch.
- [awesome-claude-code-toolkit](https://github.com/aksheyw/awesome-claude-code-toolkit): the wider toolkit these sit in.

If you're rebuilding a machine from scratch, those are a faster starting point than an empty `~/.claude/`.

## Credits

Keeping a secret out of the first commit rather than scrubbing it later is standard practice, and [gitleaks](https://github.com/gitleaks/gitleaks) is what the guide points you at for the actual scanning, because it does that far better than the grep patterns I'd have written. The idea of a project wiki that compounds across sessions instead of being rewritten each time comes from [Andrej Karpathy's LLM wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## License

MIT. See [LICENSE](LICENSE).

---

Built by [Akshey Walia](https://github.com/aksheyw). If something here is wrong, or it broke on your setup, please open an issue and say what happened.
