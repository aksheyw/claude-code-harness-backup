# Contributing

Corrections are welcome, especially from anyone who ran this on something that isn't a Mac.

The bar is high in one place. `scripts/capture-harness.sh` runs on a machine that's about to be erased, and people act on what it tells them, so if it says something is backed up when it isn't, someone loses work permanently and doesn't find out for weeks. That means changes to what it copies, or to what the report claims, have to be demonstrably correct. Plausible isn't enough.

Everything else, the prose and the templates and the platform notes, is much lower stakes. Send those freely.

## Running it

There's no build and nothing to install beyond a POSIX shell. To test a change safely, send the output somewhere disposable:

```bash
OUT=/tmp/capture-test bash scripts/capture-harness.sh
```

Then check three things:

```bash
# It exits cleanly
echo $?

# It copied the layers nobody can regenerate
for d in rules skills agents commands scripts; do
  printf '%-10s %s\n' "$d" "$(find -L /tmp/capture-test/claude/$d -type f 2>/dev/null | wc -l)"
done

# The readable report leaked nothing
grep -cE 'sk-[A-Za-z0-9]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|AIza[0-9A-Za-z_-]{30,}' /tmp/capture-test/report.md
```

That last number has to be `0`. If a change makes it non-zero the change is wrong, however useful it otherwise is.

The script is embedded a second time inside `GUIDE.md` so the guide reads on its own. **If you change the script, the copy in the guide has to change too.** They're meant to be byte-identical, and I'll check.

## What to know before you open a pull request

Some things that look like bugs are on purpose:

- **It copies real secrets into its output folder.** That's intentional, because a migration that loses your credentials has failed at the one job it had. The safety comes from warning you first, keeping values out of the readable report, and telling you to delete the folder afterwards.
- **It doesn't encrypt its own output.** Encryption belongs to the transfer, and rolling my own would be worse than pointing you at tools that already do it properly.
- **It never deletes anything**, including on a re-run. A tool you run on a machine you're about to wipe has no business deleting files.
- **The report is long.** You read it once, carefully, at a point where getting it wrong is expensive, so I'd rather it be complete than short.
- **There are no version numbers in the prose.** They go stale and then quietly mislead, so where a fact can drift the guide tells you how to check it live instead.

## Opening a pull request

1. Say which platform you tested on. If you can only do one of macOS and Linux, say which, and I'll cover the other.
2. Keep the script and its copy in `GUIDE.md` in sync.
3. Explain any term the first time it shows up. Someone who has never used Claude Code should still be able to follow the page they landed on.
4. If your change touches what gets copied or what the report claims, include the before and after of the verification commands above.

## Things I would especially like

- Linux and WSL testing. I wrote this on a Mac, and the portability notes are reasoned rather than all verified on the actual platform.
- A report from anyone who did a full restore onto a genuinely fresh machine. I've done every piece of it, just never the whole thing in one go on a machine that wasn't mine.
- Anywhere the guide states something as fact that turned out not to be true on your version.
