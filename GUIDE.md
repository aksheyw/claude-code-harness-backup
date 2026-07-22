# Claude Code Harness: Backup, Migrate, Rebuild

**Everything your Claude Code setup is made of, how to get it off a dying laptop, how to stand it back up, and how to design one worth keeping.**

Four uses, in order of urgency:

- **Moving laptops right now?** [Part 2](#part-2-capture-the-old-machine) is time-critical. Do it before the old machine is gone.
- **Old machine already gone?** Start at [Part 3](#part-3-rebuild-on-the-new-machine).
- **Building from scratch?** Start at [Part 5](#part-5-the-layers-in-detail).
- **Nothing wrong, you just want this backed up every week?** That is the one most people should end up on, and it is the same script on a schedule. See [Part 2.5](#25-using-this-weekly-instead-of-once).

> **A migration is the emergency, not the point.** The script in Part 2 was written for the moment before a wipe, but re-running it is safe and expected, and running it weekly is what turns a rescue into a backup. If you only ever read one section past Part 2, read Part 2.5.

> **What you need to run this.** A POSIX shell, which means the macOS Terminal, any Linux shell, or WSL or Git Bash on Windows. Native PowerShell and `cmd` are not supported, so on Windows use WSL. Where a command differs between macOS and Linux, both versions are given.

Everything here is safe to publish. It contains no keys, no tokens, and no private data. Where a real value would go, you will find a placeholder and a note telling your agent where to get the real one.

---

## Read this first if you are an AI agent

You have probably been handed this file with an instruction like *"set up my Claude Code the way this describes"*. Here is your brief.

**Your job:** rebuild, or build from scratch, a Claude Code working environment for the person you are talking to. Not a copy of someone else's, theirs.

**Work in this order. Do not skip ahead.**

1. **Find out which situation you are in.** Ask one question: *"Do you still have access to the old machine?"*
   - **Yes, and it still works** → go to [Part 2: Capture](#part-2-capture-the-old-machine). This is urgent and time-boxed. Do it before anything else.
   - **No, it is already gone** → go to [Part 3: Rebuild](#part-3-rebuild-on-the-new-machine) and work from whatever backup exists. Tell them honestly what is unrecoverable.
   - **Neither, this is a fresh start** → go to [Part 5: The layers](#part-5-the-layers-in-detail) and build up from nothing.
2. **Never invent a file path, a config key, or a command.** If this guide does not state it and you have not verified it on disk, say so and check. A confidently wrong config wastes an afternoon.
3. **Never ask them for a value you can read from a file.** Read the file.
4. **Never put a real secret in a file that git tracks.** [Part 6](#part-6-secrets-the-part-that-goes-wrong) is the protocol. Follow it exactly.
5. **Verify before you claim done.** [Part 8](#part-8-the-acceptance-test) is the acceptance test. Run it and show the output. "Should work" is not an acceptable report.

**The one thing you must not do:** wipe, reformat, or `rm -rf` anything on the old machine. You do not have authority for that, and the guide never requires it. If a step seems to need it, stop and ask.

---

## Part 1: What a harness actually is

Claude Code out of the box is a capable generalist that knows nothing about you. A harness is the accumulated layer that makes it *yours*: your conventions, your review standards, the mistakes you have already made once and do not want to make again.

It is worth understanding as nine layers, because each one is backed up, broken, and restored differently.

| # | Layer | Lives in | What it does | If you lose it |
|---|---|---|---|---|
| 1 | **Settings** | `~/.claude/settings.json` | Permissions, hooks wiring, model, env | Rebuildable, but hook wiring is fiddly |
| 2 | **Memory / CLAUDE.md** | `~/.claude/CLAUDE.md`, per-project `CLAUDE.md` | Standing context loaded every session | Painful. This is accumulated knowledge |
| 3 | **Rules** | `~/.claude/rules/*.md` | Durable behavioural rules, auto-loaded | Painful. Each rule usually encodes a real mistake |
| 4 | **Skills** | `~/.claude/skills/<name>/SKILL.md` | Task-specific playbooks, invoked on demand | Painful, and often large |
| 5 | **Subagents** | `~/.claude/agents/*.md` | Named specialists you delegate to | Rebuildable if you kept the definitions |
| 6 | **Commands** | `~/.claude/commands/*.md` | Slash commands (now merged into skills) | Rebuildable |
| 7 | **Hooks** | `~/.claude/scripts/`, wired in settings | Deterministic code that fires on events | Rebuildable, but this is where enforcement lives |
| 8 | **Plugins + MCP** | `~/.claude/plugins/`, `~/.claude.json`, `.mcp.json` | External capability and tool servers | Mostly reinstallable. Some auth must be redone by hand |
| 9 | **Projects** | Wherever your code lives | Per-project `CLAUDE.md`, wiki, handoffs, lessons | **Catastrophic if the folder was never a git repo** |

**The asymmetry that matters:** layers 1 and 5 through 8 are mostly *reproducible*. You can reinstall a plugin. Layers 2, 3, 4, and 9 are *authored*. Nobody can regenerate them, they only exist because you wrote them. Spend your migration effort accordingly.

---

## Part 2: Capture the old machine

> **Do this part first, and do it today, if the old machine still exists.** Everything else in this guide can be done at leisure. This cannot.

### 2.1 What genuinely dies with the laptop

Be clear-eyed about this. Most things are recoverable. These are not.

**Start with the harness, because it is the reason this guide exists.** Your code is almost certainly on a remote already. The folder that makes Claude Code work the way *you* work is not, because none of it is version controlled by default:

- **Everything you authored under `~/.claude/`**: rules, skills, subagents, commands, hook scripts. Nobody can regenerate these. They exist because you wrote them, usually one correction at a time over months.
- **Your accumulated memory and standing context.** The most expensive thing here to rebuild, precisely because you cannot rebuild it deliberately. It was never written in one sitting.

**Then the usual suspects**, which matter but are more widely understood:

- **Project folders that were never git repos.** No remote, no history, no recovery.
- **Committed work that was never pushed**, and uncommitted changes. Living only on that disk.
- **Locally-uploaded plugins.** Installed from a local file rather than a marketplace. The source exists nowhere else.
- **Marketplaces registered from a local directory.** The registration points at a folder path on that machine.
- **SSH keys, and anything in your operating system's credential store.**
- **`~/.claude.json`.** Holds MCP server registrations plus account identity.
- **Anything in a `.env` file.** By design these are gitignored, so your repos do not have them.

**Sort every credential into one of two classes before you start.** This single distinction decides what you do with each one, and getting it wrong wastes hours:

| Class | How to tell | What to do |
|---|---|---|
| **OAuth / session** | It appears in your operating system's credential store, or as an account connector, or the tool has a `login` command | **Do not copy anything.** Log in again on the new machine. Copying the file either fails or carries a live token in plaintext for no benefit |
| **Static key material** | A `.pem`, an `id_ed25519`, an API key you were issued once from a dashboard | Restore the value from your password manager, place it at the same path, then `chmod 600` |

Your operating system's credential store is the macOS Keychain, gnome-keyring or kwallet on Linux, or Credential Manager on Windows. **None of them survive a filesystem copy**, and neither does an account connector. If you find yourself planning to copy one, stop: the answer is always to re-authenticate.

### 2.2 Run the capture script

This script is **read-only**. It does not modify `~/.claude`, does not delete anything, and does not push anywhere. It writes one folder containing a report plus copies of your config.

It is also **safe to re-run**. The report is rewritten from scratch each time and the copies are updated in place, so the same script covers both the panic before a wipe and an ordinary weekly backup. If you are here because a machine is dying, keep reading. If nothing is wrong and you just want this backed up regularly, read this section anyway and then go to [Part 2.5](#25-using-this-weekly-instead-of-once).

Save it as `capture-harness.sh` and run:

```bash
bash capture-harness.sh
```

If your projects do not live in `~/Documents/Claude Code`, point it at the right place:

```bash
PROJ_ROOT="$HOME/code" bash capture-harness.sh
```

<details>
<summary><b>capture-harness.sh</b> (click to expand)</summary>

```bash
#!/usr/bin/env bash
# capture-harness.sh: READ-ONLY capture of a Claude Code setup.
#
# Two ways to use it, and the second is the one most people should end up on:
#
#   1. ONCE, before you wipe a machine. Read the report, fix every warning,
#      move the folder to the new laptop over an encrypted channel.
#
#   2. EVERY WEEK, as an ongoing backup. Re-running is safe and expected: the
#      report is rewritten from scratch each run and the copies are updated in
#      place. Commit the folder to a PRIVATE git repo and you have history.
#      See "Using this weekly" below.
#
#   bash capture-harness.sh
#
# Output: ~/claude-harness-backup/  (report.md + the authored layers + config)
# It does NOT push anything anywhere and does NOT touch ~/.claude.
#
# WHAT IT COPIES: the authored ~/.claude layers (rules, agents, commands,
# skills, memory, scripts, CLAUDE.md), your config files, and every .env it
# finds. Caches, transcripts and plugin payloads are deliberately NOT copied
# (they are large and rebuildable).
#
# WARNING: the output folder WILL contain secrets (~/.claude.json and your
# .env files are copied verbatim, so nothing is lost). Move it with an
# encrypted disk / AirDrop / password manager.
#
# ---- Using this weekly -------------------------------------------------
#
#   CH_SYNC=1 bash capture-harness.sh
#
# CH_SYNC=1 turns on mirror mode: a file you DELETED from ~/.claude is also
# removed from the copy, so the folder stays a mirror instead of growing into
# an archive of things you got rid of on purpose. It is off by default because
# it is the only part of this script that can delete anything, and it refuses
# to run if the output folder is your home directory or an ancestor of it.
#
# For history, commit the folder to a PRIVATE repo. The script writes a
# .gitignore into the folder first, so the credential-bearing files are
# excluded before you can commit them:
#
#   cd ~/claude-harness-backup && git init && git add -A && git commit -m backup
#
# Read that .gitignore before your first push, and scan the folder for secrets
# yourself. Your own rules and memory files can contain credentials that this
# script has no way to recognise. The repo must be PRIVATE either way.
#
# ---- Exit codes --------------------------------------------------------
#   0  everything this script tried to copy, it copied
#   1  at least one copy FAILED; the report says which. Do not wipe anything
#      until you have resolved them.
#   2  refused to start (mirror mode with an unsafe output folder)

# No `set -e` on purpose: one unreadable file must not abort the whole
# capture, because a partial report is still useful. Instead every copy is
# checked and counted, and a non-zero FAILURES makes the script exit 1. A
# tool whose output tells you what is safe to delete has to fail loudly.
set -uo pipefail

OUT="${OUT:-$HOME/claude-harness-backup}"
# Where your project folders live. Override if yours are elsewhere:
#   PROJ_ROOT="$HOME/code" bash capture-harness.sh
PROJ_ROOT="${PROJ_ROOT:-$HOME/Documents/Claude Code}"
TILDE="~"
R="$OUT/report.md"

# ---- Mirror mode: refuse unsafe destinations BEFORE deleting anything ----
# The checks below compare RESOLVED physical paths, not the strings the user
# typed. A string comparison is trivially defeated by a trailing slash, by a
# `..` segment, or by an OUT that is a symlink to somewhere important, and the
# thing on the other side of that check is `rsync --delete`.
RSYNC_OPTS=(-a --copy-links)
SYNC_MODE="off"
mkdir -p "$OUT" 2>/dev/null
OUT_P=$(cd "$OUT" 2>/dev/null && pwd -P)
HOME_P=$(cd "$HOME" 2>/dev/null && pwd -P)
if [ "${CH_SYNC:-0}" = "1" ]; then
  if [ -z "$OUT_P" ]; then
    printf 'refusing: cannot resolve OUT (%s)\n' "${OUT:-empty}" >&2; exit 2
  fi
  if [ "$OUT_P" = "/" ]; then
    printf 'refusing: OUT resolves to /, which is not a safe mirror target\n' >&2; exit 2
  fi
  if [ -n "$HOME_P" ] && [ "$OUT_P" = "$HOME_P" ]; then
    printf 'refusing: OUT resolves to your home directory (%s); mirror mode would delete inside it\n' "$OUT_P" >&2
    exit 2
  fi
  case "$HOME_P" in
    "$OUT_P"/*) printf 'refusing: OUT (%s) contains your home directory\n' "$OUT_P" >&2; exit 2 ;;
  esac
  # Mirror mode is rsync-only. Falling back to `cp` would copy without
  # deleting, so the run would report "mirror" while quietly not mirroring.
  if ! command -v rsync >/dev/null 2>&1; then
    printf 'refusing: CH_SYNC=1 needs rsync, which is not installed.\n' >&2
    printf '          Install rsync, or re-run without CH_SYNC for an additive copy.\n' >&2
    exit 2
  fi
  RSYNC_OPTS+=(--delete)
  SYNC_MODE="on"
fi

# Every path this script writes to lives directly under OUT. If any of them is
# already a symlink, the write lands wherever it points, which is outside this
# folder and not something the user asked for. `copy_tree` guards the payload
# directories; these are the rest, including report.md itself. Refuse early
# rather than truncate somebody's file.
for _p in "$OUT/report.md" "$OUT/.gitignore" "$OUT/config" "$OUT/inventory" \
          "$OUT/env-files" "$OUT/claude"; do
  if [ -L "$_p" ]; then
    printf 'refusing: %s is a symlink, so writing here would modify whatever it\n' "$_p" >&2
    printf '          points at. Remove it, or choose a different OUT.\n' >&2
    exit 2
  fi
done

mkdir -p "$OUT/config" "$OUT/inventory"
ERRLOG="$OUT/inventory/errors.log"
: > "$ERRLOG"

FAILURES=0
say()  { printf '%s\n' "$*" >> "$R"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Record a copy that did not happen. Loud in the report, counted for the
# exit code. This is the difference between a backup and a belief.
fail() {
  FAILURES=$((FAILURES + 1))
  say "- **FAILED to copy \`$1\`. It is NOT in this folder.** See \`inventory/errors.log\`."
}

# copy_tree <src-dir> <dest-dir> ; honours mirror mode
copy_tree() {
  # Everything this writes to, and in mirror mode deletes in, must physically
  # live inside the output folder. Checking only the leaf is not enough: a
  # symlink at ANY level above it (say OUT/claude pointing at your home
  # directory) leaves the leaf looking like an ordinary directory while the
  # writes and deletes land somewhere else entirely. So resolve the parent
  # first, before creating the leaf, and refuse if it escapes.
  local _parent _parent_p
  _parent=$(dirname "$2")
  mkdir -p "$_parent" 2>>"$ERRLOG" || return 1
  _parent_p=$(cd "$_parent" 2>/dev/null && pwd -P) || return 1
  case "$_parent_p" in
    "$OUT_P" | "$OUT_P"/*) : ;;
    *)
      printf 'destination escapes the output folder, refusing: %s resolves to %s\n' \
        "$_parent" "$_parent_p" >>"$ERRLOG"
      return 1 ;;
  esac
  # And the leaf itself must not be a symlink, for the same reason.
  if [ -L "$2" ]; then
    printf 'destination is a symlink, refusing to write through it: %s\n' "$2" >>"$ERRLOG"
    return 1
  fi
  rsync "${RSYNC_OPTS[@]}" "$1/" "$2/" 2>>"$ERRLOG" && return 0
  # In mirror mode a `cp` fallback would copy without deleting, so the folder
  # would stop being a mirror while still claiming to be one. Fail instead.
  [ "$SYNC_MODE" = "on" ] && return 1
  # rsync may be absent (common on minimal Linux). -L follows symlinks, which
  # matters because ~/.claude/skills is very often a link to a repo elsewhere.
  # `$1/.` copies the CONTENTS: plain `cp -RL "$1" "$2"` would nest the source
  # inside an existing destination on the second run (claude/rules/rules/).
  mkdir -p "$2" 2>>"$ERRLOG" && cp -RL "$1/." "$2/" 2>>"$ERRLOG" && return 0
  return 1
}

# Strip credentials embedded in a URL. report.md is meant to be shareable,
# and a remote URL is one of the few places a live token reaches it without
# anyone intending to put it there. Two forms, and the second is easy to
# forget: `https://user:token@host` AND `https://token@host` with no colon
# at all, which is how most forge tokens are actually pasted.
REDACT_URL_SED='s#://[^/@[:space:]]*:[^/@[:space:]]*@#://<REDACTED>@#g; s#://[^/@[:space:]]+@#://<REDACTED>@#g'
redact_url() { printf '%s' "$1" | sed -E "$REDACT_URL_SED"; }

# copy_file <src> <dest> <label>
copy_file() {
  if cp "$1" "$2" 2>>"$ERRLOG"; then
    say "- Copied \`$3\` -> \`${2#"$OUT"/}\`"
  else
    fail "$3"
  fi
}

# ---- Warn BEFORE copying anything, not after. ----
# Set CH_YES=1 to skip the prompt (for non-interactive and scheduled use).
cat <<EOF

  This script is READ-ONLY toward your setup: it never edits or deletes
  anything in ~/.claude, and never pushes anywhere.

  But it COPIES REAL SECRETS, in plaintext, into:
      $OUT

  Specifically:
    - ~/.claude.json        (may contain MCP tokens)
    - every .env file under $PROJ_ROOT

  That output folder is NOT encrypted. Keep it on this machine only, or
  move it over an encrypted channel. If you commit it for history, the
  repo must be PRIVATE. A .gitignore excluding the files above is written
  into the folder for you.

  Mirror mode (deletes removed files from the copy): $SYNC_MODE

EOF
if [ "${CH_YES:-0}" != "1" ]; then
  printf '  Press Enter to continue, or Ctrl-C to abort. '
  read -r _ || true
  printf '\n'
fi

# ---- A .gitignore, written BEFORE anything can be committed --------------
# Ordering is the whole point. Adding this after a first `git add -A` would
# be too late: git history does not forget a credential you committed once.
cat > "$OUT/.gitignore" <<'EOF'
# Written by capture-harness.sh, so that `git init && git add -A` in this
# folder cannot commit a credential. Read this file before your first push.
#
# These are secret-bearing by design:
config/claude.json.SECRET
env-files/

# settings.json is genuinely useful to version (hooks, permissions) but it
# CAN carry tokens in env blocks. It is excluded by default. If you have
# checked yours and it is clean, delete these two lines.
config/settings.json
config/settings.local.json

# Local noise
.DS_Store
inventory/errors.log
EOF

: > "$R"
say "# Claude Code harness capture"
say ""
say "- Host: \`$(hostname)\`"
say "- User: \`$(whoami)\`"
say "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
say "- macOS/OS: \`$(uname -srm)\`"
say "- Mirror mode (\`CH_SYNC\`): \`$SYNC_MODE\`"
say ""
say "> Generated by capture-harness.sh (read-only capture). Safe to re-run:"
say "> this report is rewritten from scratch each time and the copies are"
say "> updated in place. Run it weekly and commit the folder to a PRIVATE"
say "> repo if you want history."
say ""

# ---------------------------------------------------------------- 1. versions
say "## 1. Tool versions on this machine"
say ""
say '```'
for t in claude node npm git gh python3 rsync jq gitleaks codex agy brew; do
  if have "$t"; then
    v="$("$t" --version 2>&1 | head -1)"
    printf '%-10s %s\n' "$t" "$v" >> "$R"
  else
    printf '%-10s (not installed)\n' "$t" >> "$R"
  fi
done
say '```'
say ""
if ! have rsync; then
  say "> \`rsync\` is not installed here, so the copies below use \`cp\` instead."
  say "> That copies fine, but it cannot remove files you have deleted, so mirror"
  say "> mode (\`CH_SYNC=1\`) refuses to run at all on this machine rather than"
  say "> quietly producing a backup that is not a mirror. Install rsync if you"
  say "> want the weekly workflow."
  say ""
fi

# ---------------------------------------------------------- 2. ~/.claude tree
say "## 2. The ~/.claude identity"
say ""
if [ -d "$HOME/.claude" ]; then
  say "Top-level layout:"
  say ""
  say '```'
  ls -la "$HOME/.claude" 2>/dev/null >> "$R"
  say '```'
  say ""
  say "Counts (what you must see again on the new machine):"
  say ""
  # This column states SCOPE (what this script tries to copy), not OUTCOME.
  # Outcome is the copy list below plus any FAILED lines, which are the only
  # things that reflect what actually happened. Deriving an outcome column
  # from the source path's existence would print "yes" next to a failed copy.
  say "| Layer | Path | Count | In scope? |"
  say "|---|---|---|---|"
  for d in agents commands rules skills hooks scripts memory plugins scheduled-tasks; do
    p="$HOME/.claude/$d"
    # `plugins` is inventoried but deliberately NOT copied: it is mostly
    # marketplace clones that reinstall from the lockfile in section 5, and it
    # can run to gigabytes. Saying so in the table stops it reading as backed up.
    copied="yes, see the copy list below"
    [ "$d" = "plugins" ] && copied="**no**, reinstalled (see section 5)"
    if [ -e "$p" ]; then
      n=$(find -L "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
      link=""
      [ -L "$p" ] && link=" (symlink -> $(readlink "$p"))"
      say "| $d | \`~/.claude/$d\`$link | $n files | $copied |"
    else
      say "| $d | \`~/.claude/$d\` | absent | n/a |"
    fi
  done
  say ""
  # full file list, for diffing after restore
  find -L "$HOME/.claude" -type f 2>/dev/null \
    | grep -v -e '/projects/' -e '/todos/' -e '/statsig/' -e '/\.git/' \
    | sed "s|^$HOME/.claude/||" | sort > "$OUT/inventory/claude-files.txt"
  say "Full file list (transcripts excluded): \`inventory/claude-files.txt\` ($(wc -l < "$OUT/inventory/claude-files.txt" | tr -d ' ') files)"
  say ""

  # ---- THE ACTUAL PAYLOAD COPY: the authored, irreplaceable layers ----
  mkdir -p "$OUT/claude"
  say "Copying the authored layers (this is the part nobody can regenerate):"
  say ""
  for d in rules agents commands memory scripts hooks scheduled-tasks docs; do
    src="$HOME/.claude/$d"
    if [ -d "$src" ]; then
      if copy_tree "$src" "$OUT/claude/$d"; then
        say "- \`$d/\` -> \`claude/$d/\` ($(find -L "$OUT/claude/$d" -type f 2>/dev/null | wc -l | tr -d ' ') files)"
      else
        fail "$TILDE/.claude/$d"
      fi
    fi
  done
  # skills is very often a SYMLINK to a repo elsewhere; follow it
  if [ -e "$HOME/.claude/skills" ]; then
    if copy_tree "$HOME/.claude/skills" "$OUT/claude/skills"; then
      say "- \`skills/\` -> \`claude/skills/\` ($(find -L "$OUT/claude/skills" -type f 2>/dev/null | wc -l | tr -d ' ') files)"
    else
      fail "$TILDE/.claude/skills"
    fi
    if [ -L "$HOME/.claude/skills" ]; then
      say "  (was a symlink to \`$(readlink "$HOME/.claude/skills")\`. Recreate the link on the new machine, or just use the copied folder)"
    fi
  fi
  for f in CLAUDE.md MEMORY.md; do
    [ -f "$HOME/.claude/$f" ] && copy_file "$HOME/.claude/$f" "$OUT/claude/$f" "$TILDE/.claude/$f"
  done
else
  say "**No ~/.claude directory found.**"
fi
say ""

# ------------------------------------------------------------- 3. settings
say "## 3. Settings + hooks"
say ""
for f in settings.json settings.local.json; do
  src="$HOME/.claude/$f"
  if [ -f "$src" ]; then
    copy_file "$src" "$OUT/config/$f" "$TILDE/.claude/$f"
    if have jq; then
      say ""
      say "  Top-level keys: \`$(jq -r 'keys | join(", ")' "$src" 2>/dev/null)\`"
      hooks=$(jq -r '.hooks // {} | keys | join(", ")' "$src" 2>/dev/null)
      [ -n "$hooks" ] && say "  Hook events wired: \`$hooks\`"
    fi
  fi
done
say ""
say "Hook scripts referenced by settings (these must exist on the new machine or every session errors):"
say ""
say "> Credential-shaped text below is replaced with \`<REDACTED>\`, but that only covers"
say "> the shapes it knows: provider key prefixes, \`NAME=value\`, auth headers, and URLs"
say "> with credentials in them. A secret passed as a bare argument, say \`--token abc123\`,"
say "> looks like an ordinary word and survives. **Read this block before you paste this"
say "> report anywhere.**"
say ""
say '```'
if have jq && [ -f "$HOME/.claude/settings.json" ]; then
  # Redact anything credential-shaped. A hook can legitimately be an inline
  # command, and an inline command can carry a token. Unlike the copied
  # config files, report.md is the part people paste into a chat or a ticket.
  jq -r '.. | .command? | if type=="array" then join(" ") elif type=="string" then . else empty end' "$HOME/.claude/settings.json" 2>/dev/null \
    | sed -E \
        -e 's/(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]+/\1<REDACTED>/g' \
        -e 's/(gh[pousr]_)[A-Za-z0-9]{10,}/\1<REDACTED>/g' \
        -e 's/(AIza)[0-9A-Za-z_-]{10,}/\1<REDACTED>/g' \
        -e 's/(AKIA)[0-9A-Z]{8,}/\1<REDACTED>/g' \
        -e 's/(xox[abprs]-)[A-Za-z0-9-]{10,}/\1<REDACTED>/g' \
        -e 's/([0-9]{8,12}:AA)[A-Za-z0-9_-]{10,}/\1<REDACTED>/g' \
        -e 's/((KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL)[A-Za-z0-9_]*=)[^[:space:]"'"'"']{8,}/\1<REDACTED>/g' \
        -e 's/(([Bb]earer|[Aa]uthorization:?)[[:space:]]+)[A-Za-z0-9._-]{12,}/\1<REDACTED>/g' \
        -e "$REDACT_URL_SED" \
    | sort -u >> "$R"
fi
say '```'
say ""

# ------------------------------------------------------------- 4. MCP servers
say "## 4. MCP servers  (SECRET-BEARING)"
say ""
if [ -f "$HOME/.claude.json" ]; then
  copy_file "$HOME/.claude.json" "$OUT/config/claude.json.SECRET" "$TILDE/.claude.json"
  say "  (**contains tokens; gitignored for you, never commit it**)"
  if have jq; then
    # names only into the report; values stay in the copied file
    say ""
    say "Server names configured (user scope):"
    say ""
    say '```'
    jq -r '.mcpServers // {} | keys[]' "$HOME/.claude.json" 2>/dev/null >> "$R"
    say '```'
    say ""
    say "Per-project MCP scopes present:"
    say ""
    say '```'
    jq -r '.projects // {} | to_entries[] | select(.value.mcpServers != null and (.value.mcpServers | length > 0)) | "\(.key)  ->  \(.value.mcpServers | keys | join(", "))"' "$HOME/.claude.json" 2>/dev/null >> "$R"
    say '```'
    say ""
    say "Env var NAMES each server needs (values are in the copied file, not here):"
    say ""
    say '```'
    jq -r '.mcpServers // {} | to_entries[] | "\(.key): \((.value.env // {}) | keys | join(", "))"' "$HOME/.claude.json" 2>/dev/null >> "$R"
    say '```'
  fi
else
  say "- No \`~/.claude.json\` found."
fi
# project-level .mcp.json files
say ""
say "Project-level \`.mcp.json\` files (committed, project-scope servers):"
say ""
say '```'
MCP_ALL=$(find "$PROJ_ROOT" -maxdepth 3 -name '.mcp.json' -not -path '*/node_modules/*' 2>/dev/null)
printf '%s\n' "$MCP_ALL" | grep -v '^$' | head -50 >> "$R"
say '```'
# Never truncate silently. A capped list reads as a complete one, and this
# report is used to decide what is safe to erase.
MCP_N=$(printf '%s\n' "$MCP_ALL" | grep -c '[^[:space:]]' || true)
if [ "${MCP_N:-0}" -gt 50 ]; then
  say ""
  say "> **This list is truncated at 50. $MCP_N were found.** Re-run the \`find\` above without \`head\` to see them all."
fi
say ""
say "> Scope note: this search covers 3 directory levels under \`$PROJ_ROOT\`, and the \`.env\` search below covers 4. Anything deeper is not listed, so it is not evidence of absence."
say ""

# ------------------------------------------------------------- 5. plugins
say "## 5. Plugins + marketplaces"
say ""
SET="$HOME/.claude/settings.json"
INST="$HOME/.claude/plugins/installed_plugins.json"
MKTS="$HOME/.claude/plugins/known_marketplaces.json"

for f in "$INST" "$MKTS"; do
  [ -f "$f" ] && copy_file "$f" "$OUT/config/$(basename "$f")" "${f/#"$HOME"/$TILDE}"
done

if have jq && [ -f "$SET" ]; then
  say ""
  say "Enabled plugins (from \`settings.json\` -> \`enabledPlugins\`, the reinstall source of truth):"
  say ""
  say '```'
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SET" 2>/dev/null >> "$R"
  say '```'
  say ""
  say "**Locally-uploaded plugins are NOT reinstallable from a marketplace**. Their source exists only on this laptop. Find and copy the originals for these:"
  say ""
  say '```'
  jq -r '.enabledPlugins // {} | keys[] | select(test("local-upload"))' "$SET" 2>/dev/null >> "$R"
  say '```'
fi

if have jq && [ -f "$MKTS" ]; then
  say ""
  say "Registered marketplaces (a \`directory\` source points at a LOCAL folder you must also copy):"
  say ""
  say '```'
  jq -r 'to_entries[] | "\(.key): \(.value.source.source // "?") \(.value.source.repo // .value.source.path // "")"' "$MKTS" 2>/dev/null \
    | sed -E "$REDACT_URL_SED" >> "$R"
  say '```'
fi

if have jq && [ -f "$INST" ] && [ -f "$SET" ]; then
  say ""
  say "Enabled but NOT installed (stale references, do not try to reinstall these):"
  say ""
  say '```'
  jq -r --slurpfile i "$INST" '(.enabledPlugins // {}) | to_entries[] | select(.value==true) | .key as $k | select((($i[0].plugins // $i[0]) | has($k)) | not) | $k' "$SET" 2>/dev/null >> "$R"
  say '```'
fi
# The plugin PAYLOADS are not copied, only measured. They reinstall from the
# lockfile above, except for local-uploads, which are called out separately.
if [ -d "$HOME/.claude/plugins" ]; then
  du -sh "$HOME/.claude/plugins" 2>/dev/null | awk '{print "\n- Plugins dir size: " $1 " (NOT copied; reinstalled from the list above)"}' >> "$R"
fi
say ""

# ------------------------------------------------------------- 6. projects
say "## 6. Project folders: the big risk"
say ""
say "Every folder below is a project. **A folder with no remote, or with unpushed work, dies with this laptop.**"
say ""
say "| Project | Git? | Remote | Unpushed commits | Uncommitted files |"
say "|---|---|---|---|---|"
if [ -d "$PROJ_ROOT" ]; then
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      remote=$(redact_url "$(git -C "$d" remote get-url origin 2>/dev/null || echo "**NONE**")")
      dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      br=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
      if git -C "$d" rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
        ahead=$(git -C "$d" rev-list --count "@{u}..HEAD" 2>/dev/null || echo "?")
      else
        ahead="**no upstream**"
      fi
      say "| $name | yes ($br) | $remote | $ahead | $dirty |"
    else
      say "| $name | **NO GIT** | n/a | n/a | **all of it** |"
    fi
  done < <(find "$PROJ_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
else
  say "| (no folder at $PROJ_ROOT, set PROJ_ROOT and re-run) | | | | |"
fi
say ""

# ------------------------------------------------------------- 7. other homes
say "## 7. Other agent/tool state worth taking"
say ""
say "| Path | Present | Notes |"
say "|---|---|---|"
check_path() {
  if [ -e "$1" ]; then
    sz=$(du -sh "$1" 2>/dev/null | awk '{print $1}')
    say "| \`${1/#"$HOME"/$TILDE}\` | yes ($sz) | $2 |"
  else
    say "| \`${1/#"$HOME"/$TILDE}\` | no | $2 |"
  fi
}
check_path "$HOME/.codex"           "Codex CLI config + auth.json (**secret**)"
check_path "$HOME/.ssh"             "SSH keys (**secret**, copy securely, chmod 600 on arrival)"
check_path "$HOME/.aws"             "AWS creds (**secret**)"
check_path "$HOME/.config/gh"       "GitHub CLI auth (**secret**; or just re-run gh auth login)"
check_path "$HOME/.zshrc"           "Shell profile, may export API keys"
check_path "$HOME/.zprofile"        "Shell profile"
check_path "$HOME/.gitconfig"       "Git identity + aliases"
check_path "$HOME/.claude/projects" "Session transcripts (large; optional)"
say ""

say "### Secret-shaped exports in shell profiles (NAMES only)"
say ""
say '```'
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
  [ -f "$f" ] || continue
  grep -oE '^[[:space:]]*export[[:space:]]+[A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|API|CREDENTIAL)[A-Z0-9_]*' "$f" 2>/dev/null \
    | awk -v f="$f" '{print f": "$NF}' >> "$R"
done
say '```'
say ""

# ------------------------------------------------------------- 8. env files
say "## 8. .env files across projects (NAMES only, values never printed)"
say ""
mkdir -p "$OUT/env-files"
# The loop below runs in a pipeline, i.e. its own subshell, so it cannot
# increment FAILURES directly. Failed copies are recorded to a file and
# folded into the count afterwards.
ENVFAIL="$OUT/inventory/env-copy-failures.txt"
: > "$ENVFAIL"
say '```'
find "$PROJ_ROOT" -maxdepth 4 -type f -name '.env*' -not -path '*/node_modules/*' -not -name '*.example' 2>/dev/null | while IFS= read -r e; do
  echo "--- ${e/#"$HOME"/$TILDE}"
  # names only into the report; handles both `VAR=` and `export VAR=`
  grep -oE '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' "$e" 2>/dev/null \
    | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/=$//; s/^/    /'
  # copy the real file, preserving its project path so you know where it goes back
  rel="${e#"$PROJ_ROOT"/}"
  dest="$OUT/env-files/$rel"
  if ! { mkdir -p "$(dirname "$dest")" && cp "$e" "$dest"; } 2>>"$ERRLOG"; then
    echo "    (NOT COPIED: this file failed to copy)"
    printf '%s\n' "$rel" >> "$ENVFAIL"
  fi
done >> "$R"
say '```'
say ""
while IFS= read -r rel; do
  [ -n "$rel" ] && fail ".env file: $rel"
done < "$ENVFAIL"
say "The real \`.env\` files are copied to \`env-files/\`, keeping their project sub-paths so you know where each one goes back. **These contain live values**, and are gitignored for you."
say ""
say "Separately, commit a \`.env.example\` to each repo (names + where to get each value, never the values)."
say ""

# ------------------------------------------------------------- 9. cannot move
say "## 9. Cannot be copied, must be re-authorized on the new machine"
say ""
say "- **claude.ai-managed MCP connectors** (Notion, Slack, Linear, Sentry, Vercel, GitHub, Figma, ...) live in your claude.ai account, not on disk. They return when you log in to claude.ai and re-authorize under connector settings."
say "- **Claude Code login** itself, re-run \`claude\` and sign in."
say "- **OAuth-based CLI logins**: \`gh auth login\`, Codex device-code flow, any browser-session tool."
say "- **Keychain items** do not survive a copy. Re-add from your password manager."
say ""

# ------------------------------------------------------------- done
say "---"
say ""
if [ "$FAILURES" -gt 0 ]; then
  say "## $FAILURES thing(s) FAILED to copy"
  say ""
  say "Search this report for **FAILED** to see each one, and read \`inventory/errors.log\`."
  say "**Do not wipe this machine until every one of them is resolved.**"
  say ""
fi
say "## What to do with this folder"
say ""
say "**If you are migrating (running this once):**"
say ""
say "1. Read this report top to bottom and fix every warning before wiping."
say "2. Push every project that has a remote; create remotes for the ones that say **NONE**."
say "3. Move this whole folder to the new machine over an **encrypted** channel (it holds real tokens)."
say "4. On the new machine, hand this report to Claude Code and ask it to rebuild from it."
say ""
say "**If you are using this as a weekly backup:**"
say ""
say "1. Re-run it on a schedule. \`CH_YES=1\` skips the prompt, so it works unattended."
say "2. Add \`CH_SYNC=1\` so files you delete are removed from the copy too, keeping it a mirror."
say "3. Commit the folder to a **private** repo for history. The \`.gitignore\` written here already"
say "   excludes the credential-bearing files, but **scan before your first push anyway**: your own"
say "   rules and memory can contain secrets that no generic scanner will recognise."
say "4. Check that it actually ran. A backup nobody has restored from is a hypothesis."

if [ "$FAILURES" -gt 0 ]; then
  printf '\n  %s COPY FAILURE(S). This capture is INCOMPLETE.\n\n' "$FAILURES"
  printf '   Report:  %s\n   Errors:  %s\n\n' "$R" "$ERRLOG"
  printf '   Do NOT wipe anything until the report says every failure is resolved.\n\n'
  exit 1
fi

printf '\n  Capture complete, no failures.\n\n   Report:  %s\n   Folder:  %s\n\n' "$R" "$OUT"
printf '   This folder contains REAL SECRETS (~/.claude.json, .env copies).\n'
printf '   Keep it encrypted. If you commit it for history, the repo must be PRIVATE.\n\n'
```

</details>

### 2.3 Act on the report

The report is not the backup. It is the to-do list. Work top to bottom:

**Section 6 is the one that matters most.** For every row:

- `**NO GIT**` → decide: does this folder matter? If yes, it needs a remote today.
  ```bash
  cd "/path/to/folder"
  git init && git add -A && git commit -m "initial: pre-migration snapshot"
  gh repo create <name> --private --source=. --push
  ```
  > Before that first push, run the secret scan in [Part 6.4](#64-before-the-first-push-of-any-new-repo). Redacting after the first commit does not help. Git history does not forget.
- `**no upstream**` → `git push -u origin HEAD`
- Unpushed count above zero → push it.
- Uncommitted count above zero → commit and push it, or accept losing it. Say which out loud.

**Then the rest:**

- **Locally-uploaded plugins**: find the original source folder or zip for each one and copy it into the migration folder. If you cannot find it, it is gone. Note that now rather than discovering it in three weeks.
- **Directory-sourced marketplaces**: copy the directory they point at.
- **`.env` files**: copy the real ones into the migration folder. Separately, commit a `.env.example` to each repo ([Part 6.2](#62-the-envexample-pattern)).
- **SSH keys**: copy `~/.ssh`. Note the permissions for arrival, because they differ for the directory and the files, and getting this wrong locks you out:
  ```bash
  chmod 700 ~/.ssh              # the DIRECTORY needs execute, or nothing in it is readable
  chmod 600 ~/.ssh/id_* ~/.ssh/config
  chmod 644 ~/.ssh/*.pub
  ```

### 2.4 Move the folder safely

The migration folder now contains real credentials. Treat it accordingly.

**Reasonable:** an encrypted external drive, an encrypted container, a direct transfer between your own devices, or your password manager's secure file storage. To make an encrypted container:

| Platform | Command or tool |
|---|---|
| macOS | `hdiutil create -encryption AES-256 -size 2g -volname migration -fs APFS migration.dmg` |
| Linux | `cryptsetup luksFormat` on a file or partition, or a VeraCrypt container |
| Windows | BitLocker To Go on a USB drive, or a VeraCrypt container |

**Not reasonable:** a git push, email, Slack, a public cloud folder, or a USB stick you then lend to someone.

---

### 2.5 Using this weekly instead of once

Everything above is written for the hour before a wipe. That is the emergency, and it is not the point. The same script run every week is a backup, and a backup is what stops the emergency from mattering.

**Re-running is safe.** The report is rewritten from scratch each run and the copies are updated in place, so running it a hundred times leaves the same folder you would get from running it once.

Three things change when you move from once to weekly.

**1. Turn on mirror mode, or the folder slowly stops being true.**

```bash
CH_SYNC=1 CH_YES=1 bash capture-harness.sh
```

By default the script only ever adds and overwrites. That is the right default for a one-time rescue, where deleting nothing is the safest thing a script can do. But run it weekly for a year without `CH_SYNC=1` and every rule, agent, and skill you have ever deleted on purpose is still sitting in the folder. You end up restoring from an archive of your own mistakes.

`CH_SYNC=1` makes the copy a mirror: delete a rule from `~/.claude` and it goes from the folder too. It is off by default because it is the only part of the script that can delete anything. It refuses to run at all if the output folder is your home directory, an ancestor of it, or `/`.

`CH_YES=1` skips the confirmation prompt, which you need for anything unattended.

**2. Commit it to a private repo, or you have one point in time and call it history.**

A folder that overwrites itself every week tells you what your setup looked like this morning and nothing else. The value of a weekly backup is answering "what did this look like before I broke it," and that needs git.

```bash
cd ~/claude-harness-backup
git init && git add -A && git commit -m "backup"
gh repo create my-harness-backup --private --source=. --push
```

The script writes a `.gitignore` into the folder before anything can be committed, excluding `config/claude.json.SECRET`, `env-files/`, and `settings.json`. That ordering is the whole point: adding an ignore rule after a first `git add -A` is too late, because git history does not forget a credential you committed once.

> **Read that `.gitignore` before your first push, and scan the folder yourself.** The ignore list covers the files that are secret *by design*. It cannot cover a token you once pasted into a rule, or an API key sitting in a memory file from six months ago. Run the scan in [Part 6.4](#64-before-the-first-push-of-any-new-repo) against the folder before the first push, and keep the repo **private** regardless of what the scan says.
>
> This guide deliberately does not make the script scan for you. A scanner that returns a false clean is worse than no scanner, because a green result stops people looking. Deciding your own backup is clean is a judgement call, and it should stay yours.

**3. Check that it actually ran.**

Schedule it however you already schedule things, `cron`, a systemd timer, a launchd agent, or a reminder you actually honour. Then confirm the folder's date changes. The exit code is meaningful: `0` means everything it tried to copy, it copied; `1` means at least one copy failed and the report says which; `2` means it refused to start.

```bash
# a crude but honest weekly check
find ~/claude-harness-backup/report.md -mtime +8 \
  && echo "BACKUP IS STALE, it has not run in over a week"
```

A backup you have never restored from is a hypothesis. Once a year, restore it into a throwaway location and see whether it actually stands your setup back up.

---

## Part 3: Rebuild on the new machine

### 3.1 Prerequisites

```bash
# macOS
brew install git gh jq rsync gitleaks
```

**Restore SSH before anything that talks to git.** If any of your remotes use SSH, cloning and pushing fail until the keys are back and their permissions are right.

```bash
mkdir -p ~/.ssh
cp migration/ssh/* ~/.ssh/           # from your encrypted transfer
chmod 700 ~/.ssh                     # directory needs execute
chmod 600 ~/.ssh/id_* ~/.ssh/config  # keys and config must be private
chmod 644 ~/.ssh/*.pub
ssh -T git@github.com                # expect a success or a named greeting
```

Then authenticate git and install Claude Code:

```bash
gh auth login
gh auth setup-git
```

Launch Claude Code once and sign in. That creates a baseline `~/.claude` you are about to layer on top of, and it is also what pulls your account-level MCP connectors back.

### 3.2 Restore the identity

If you have a backup repo, clone it and run its restore script. If you are working from the capture folder, restore in this order. Order matters: settings last, because plugins rewrite it.

```bash
# 1. The authored layers, the irreplaceable ones
rsync -a  migration/claude/rules/    ~/.claude/rules/
rsync -a  migration/claude/agents/   ~/.claude/agents/
rsync -a  migration/claude/commands/ ~/.claude/commands/
rsync -a  migration/claude/skills/   ~/.claude/skills/
rsync -a  migration/claude/memory/   ~/.claude/memory/
cp        migration/claude/CLAUDE.md ~/.claude/CLAUDE.md   # if you have one

# 2. Hook scripts BEFORE the settings that reference them
rsync -a  migration/claude/scripts/  ~/.claude/scripts/
chmod +x  ~/.claude/scripts/hooks/*

# 3. Settings last, and FIX ITS PATHS BEFORE COPYING (see below)
```

> **The most common failure at this step, and it is worth pre-empting rather than debugging.** Hook commands in `settings.json` are usually stored as absolute paths containing the *old* username. On the new machine they point at nothing, so every single session throws hook errors before you have typed anything.
>
> **Rewrite the file first, then copy it.** Doing it the other way round means every session in between is broken.
>
> ```bash
> # 1. See what paths it references
> jq -r '.. | .command? // empty' migration/config/settings.json | sort -u
>
> # 2. Rewrite old-user paths to $HOME-relative, so this never bites again.
> #    `sed -i` differs between macOS and Linux, so use the portable form:
> sed -i.bak 's|/Users/<old-username>|'"$HOME"'|g' migration/config/settings.json \
>   && rm -f migration/config/settings.json.bak
>
> # 3. Confirm nothing stale is left
> grep -o '/Users/[a-z0-9._-]*' migration/config/settings.json | sort -u   # expect no output
>
> # 4. NOW copy it in
> cp migration/config/settings.json ~/.claude/settings.json
> ```
>
> If a hook script genuinely lives outside `~/.claude` (a plugin repo, for instance), make sure that repo is cloned to the new machine before you rely on the hook.

### 3.3 Reinstall plugins

Register marketplaces first, then install. Read the names from the captured `known_marketplaces.json` and `settings.json`.

```bash
claude plugin marketplace add <owner/repo>
claude plugin install <plugin-name>@<marketplace-name> --scope user
```

> **If those commands look wrong, check anyway.** On the build this guide was tested against, `claude plugin --help` lists only `details`, `disable`, `enable`, and `eval`. It does *not* list `install`, `list`, or `marketplace`, yet all three work. So do not conclude from the help text that the command does not exist. Test it directly:
> ```bash
> claude plugin list --help && echo "available"
> ```
> If your build genuinely lacks them, use the `/plugin` command inside an interactive session instead, or declare `enabledPlugins` and `extraKnownMarketplaces` directly in `settings.json` and restart.

Three cases need hands:

- **Marketplaces with a `directory` source** need that directory present first. Copy it, then register the new path.
- **Locally-uploaded plugins** cannot be installed from a marketplace at all. Re-upload from the source you copied in [2.3](#23-act-on-the-report).
- **Stale entries** flagged by the capture script (enabled in settings, never installed) should simply be deleted from `enabledPlugins`. Do not chase them.

### 3.4 Re-add MCP servers

**This step is far smaller than you expect, and that surprises people.**

On a mature setup you might see fifty-odd MCP tools in a session and assume there is a large config file to move. There usually is not. The overwhelming majority are **account-level connectors**: they live server-side against your Claude account, not on your disk. Log into the same account on the new machine and re-authorize each one in your account's connector settings. There is nothing to copy, and nothing you can copy.

On a mature setup it is normal for the large majority of visible MCP servers to be account connectors, with only a small handful genuinely registered on disk. So:

1. **First, just log in.** Then look at what is genuinely missing. That list is your actual work.
2. **For the few local ones**, do not copy `~/.claude.json` wholesale. It mixes server config with machine-specific session state and account identity. Read the server list out of it and re-add each one:

```bash
# stdio server
claude mcp add <name> --scope user -- <command> <args...>

# HTTP server
claude mcp add --transport http <name> <url>
```

3. **Project-scoped `.mcp.json` files** come back with the repo when you clone it. Usually they declare only a URL, with auth handled by browser OAuth on first use, so there is nothing to restore.

Verify with `claude mcp list`. Anything showing "needs authentication" just needs a first use to trigger its login.

### 3.5 Re-enter secrets

Work through your `secrets.template.md` ([Part 6.3](#63-secretstemplatemd-the-inventory-that-is-safe-to-commit)). For each entry, pull the value from your password manager or reissue it from the origin dashboard, and set it where the template says.

### 3.6 Re-clone projects

Clone each repo from the remote you confirmed in the capture. Then, per project, restore its `.env` from the migration folder using its committed `.env.example` as the checklist.

Restart Claude Code so settings and plugins take effect, then run [Part 8](#part-8-the-acceptance-test).

---

## Part 4: Where the config actually lives

Verified against the current documentation at `code.claude.com/docs` on 2026-07-21. These things change. Re-check before trusting any specific key.

### 4.1 Settings precedence

Highest wins:

1. Enterprise managed policy (`/Library/Application Support/ClaudeCode/managed-settings.json` on macOS)
2. Command line arguments
3. `.claude/settings.local.json` (project, gitignored, personal)
4. `.claude/settings.json` (project, committed, shared with the team)
5. `~/.claude/settings.json` (user, applies everywhere)

Permission rules merge across scopes. Other keys follow strict precedence.

Source: [code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings)

### 4.2 Settings keys worth knowing

| Key | Does |
|---|---|
| `permissions` | allow / ask / deny tool rules |
| `hooks` | event to matcher to command wiring |
| `env` | env vars for every session |
| `model` | default model |
| `enabledPlugins` | which plugins are on, keyed `name@marketplace` |
| `extraKnownMarketplaces` | marketplace registration, checked in for reproducibility |
| `statusLine` | custom status line script |
| `disableAllHooks` | kill switch, useful when debugging |
| `cleanupPeriodDays` | how long session files survive |
| `autoMemoryEnabled` | auto-memory toggle |

There are 60+ documented keys. The two above that matter for migration are `enabledPlugins` and `extraKnownMarketplaces`: committed together, they are the closest thing Claude Code has to a plugin lockfile.

### 4.3 Hooks

The config shape:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$HOME/.claude/scripts/hooks/my-check.sh\"", "timeout": 600 }
        ]
      }
    ]
  }
}
```

- **Matcher**: `"*"` or omitted matches everything. Alphanumeric plus `_-,|` is an exact or list match. Anything else is treated as an unanchored regex.
- **Exit codes**: `0` succeeds and stdout JSON is parsed. `2` is a blocking error for most events, though it does *not* block `PostToolUse`. Anything else is non-blocking, with stderr shown in the transcript.
- **Feeding findings back to the agent**: emit `{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "..."}}`.

The documented event list runs to roughly 28 events and is growing. Fetch the current list rather than trusting any number written down, including this one.

Source: [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks)

**Hooks that earn their place** (each replaces a rule you would otherwise have to remember):

| Hook | Event | Why |
|---|---|---|
| Secret scan on write | `PostToolUse` on `Write\|Edit` | Catches a pasted key at the moment it lands |
| Protected-branch push block | `PreToolUse` on `Bash` | Makes "never push straight to main" structural |
| Auto-format after edit | `PostToolUse` on `Write\|Edit` | Removes an entire class of review comment |
| Subagent output capture | `PostToolUse` on `Task` | Stops research dying in the context window |
| Config protection | `PreToolUse` on `Write\|Edit` | Stops the agent weakening a linter rule to pass it |

### 4.4 Skills, agents, commands

**Skills** live at `~/.claude/skills/<name>/SKILL.md` (personal) or `.claude/skills/<name>/SKILL.md` (project). No frontmatter field is strictly required, but `description` is what the model uses to decide when to invoke, so treat it as required in practice.

```markdown
---
name: my-skill
description: Use when <specific trigger condition>. Covers <what it does>.
---

# My Skill
Instructions the model follows when this is invoked.
```

> **Important change:** custom commands have been merged into skills. `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both produce `/deploy` and behave identically. Existing `commands/` files keep working, so there is no migration to do. New work should probably go in `skills/`, which also supports a folder of supporting files.

**Subagents** live at `~/.claude/agents/<name>.md`. `name` and `description` are required.

```markdown
---
name: my-reviewer
description: Reviews X for Y. Use after writing X.
tools: Read, Grep, Glob
model: inherit
---

System prompt for the subagent.
```

Sources: [skills](https://code.claude.com/docs/en/skills), [sub-agents](https://code.claude.com/docs/en/sub-agents)

### 4.5 CLAUDE.md and memory

Discovered files are **concatenated**, not overridden, from broadest to most specific: user `~/.claude/CLAUDE.md`, then project `./CLAUDE.md`, then `./CLAUDE.local.md` (gitignore this one).

Import other files with `@path/to/file`. Paths resolve relative to the *importing* file, and imports nest up to 4 levels deep.

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If you also use tools that read `AGENTS.md`, import it rather than maintaining two copies:

```markdown
@AGENTS.md
```

Source: [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory)

### 4.6 MCP

- **Local and user scope** live in `~/.claude.json`. Machine-specific, do not copy wholesale.
- **Project scope** lives in `.mcp.json` at the repo root. Meant to be committed.
- Scope precedence, highest first: local, project, user, plugin-provided, account connectors.

`.mcp.json` supports env var expansion, which is what makes it safe to commit:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@example/mcp-server"],
      "env": { "API_TOKEN": "${MY_SERVICE_TOKEN}" }
    }
  }
}
```

The token stays in your environment. The file references it by name. Commit this freely.

Source: [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp)

### 4.7 There is no official migration command

Searched specifically for one. As of 2026-07-21 there is no first-party export/import or sync feature. Community tools exist; this guide deliberately uses plain `git`, `rsync`, and the documented CLI instead, because those will not be abandoned.

---

## Part 5: The layers in detail

If you are building from scratch rather than migrating, build in this order. Each layer is only worth adding once the previous one is doing work.

### Layer 1: One CLAUDE.md

Start here. A single file of standing context. Do not over-engineer it.

### Layer 2: Rules, when a correction repeats

**Do not write rules speculatively.** A rule earns its place by being a mistake that already happened, ideally twice. Speculative rules are noise, and noise costs you attention on every single session.

The shape that works:

```markdown
# <Rule name>

**The failure this prevents:** <what actually went wrong, concretely>

## The rule
<what to do instead, stated so it is checkable>

## Why
<the origin story, one paragraph>
```

Writing the failure down is what makes the rule survive scrutiny later, including your own.

### Layer 3: Skills, when a task repeats

A skill is a playbook for a task you do often enough that re-explaining it is annoying. Trigger conditions in the `description` matter more than the body, because a skill that never triggers does nothing.

### Layer 4: Subagents, when you want isolation

Reach for a subagent when you want work done in a *separate context*: a fan-out search, an independent review, a mechanical sweep you do not want filling your main context.

The rule of thumb: delegate the mechanical, keep the judgment.

### Layer 5: Hooks, when a rule keeps getting missed

This is the important one, and the thing most people skip.

**A rule the model has to remember is the weakest enforcement you have.** Under context pressure, at the end of a long session, a text rule loses. A hook does not. If a rule is safety-critical, expensive to violate, or has been violated more than once, promote it from prose to code.

The test: *"if the model forgets this, what happens?"* If the answer is bad, write the hook.

### Layer 6: Plugins and MCP, last

Capability from outside. Add these when you have a specific need, not to fill out a collection. Every MCP server costs context on every session.

---

## Part 6: Secrets, the part that goes wrong

The rule underneath all of this: **git history is append-only.** Redacting a secret in the current commit does nothing about the previous one. "Private repo" reduces exposure, it does not remove it, because repos gain collaborators and change visibility.

So the fix always has to happen *before* the first commit.

### 6.1 The .gitignore baseline

```gitignore
# Regenerable, reinstall from lockfiles
node_modules/
.venv/
__pycache__/
dist/
build/
.next/
coverage/
*.log

# Live session / credential state
**/browser_profile/
**/Cookies*
*.sqlite*
**/auth_info.json

# Secrets, never commit a real value
.env
.env.*
secrets*
*.pem
*.key
id_rsa
id_ed25519

# Negation: keep the TEMPLATE. Must come AFTER `secrets*`,
# because the last matching rule wins.
!secrets.template.md
!.env.example

# Editor and OS detritus
*.bak
*.orig
.DS_Store
```

> **A secret `.gitignore` cannot save you from.** Pattern-based ignores only catch secrets that live in *predictably named files*. They do not catch a secret sitting inside an ordinary config file. A real example found while researching this guide: an `~/.ssh/config` where one host's authentication token was placed in the `User` field, so the credential was inline in a file that no `*.pem` or `id_rsa` rule would ever match.
>
> So: **never copy a config file into a repo without reading it first.** `.gitignore` handles the predictable cases. Files like `~/.ssh/config`, CI configs, and editor settings need a human or an agent to actually look at the contents, line by line, before they are committed.

> **The trap that eats agent config.** A bare `.claude/` line in `.gitignore` silently untracks `.claude/agents/` and `.claude/wiki/` too. A fresh clone then loses every agent definition you wrote, and nothing warns you. If you want to ignore local `.claude` state but keep the authored parts:
> ```gitignore
> .claude/*
> # Negate every AUTHORED subdirectory. Both lines are needed per directory:
> # one for the directory itself, one for its contents.
> !.claude/agents/
> !.claude/agents/**
> !.claude/skills/
> !.claude/skills/**
> !.claude/commands/
> !.claude/commands/**
> !.claude/rules/
> !.claude/rules/**
> !.claude/wiki/
> !.claude/wiki/**
> !.claude/settings.json
> ```
> Do not stop at the two you happen to use today. The whole point of the pattern is that it fails *silently*, so the directory you add next month is the one that quietly goes untracked.
>
> Verify, per directory:
> ```bash
> git check-ignore -v .claude/agents/some-agent.md   # expect no output
> git ls-files .claude | head                        # expect your authored files
> ```
> This is a real pattern found in the wild, in a repo whose entire wiki was untracked without anyone noticing.

### 6.2 The .env.example pattern

Every project gets one, committed. It is the machine-readable version of "what do I need to set up here", and it is what lets an agent guide someone through re-adding keys.

**Names and sources, never values:**

```bash
# ───────────────────────────────────────────────
# Database
# ───────────────────────────────────────────────

# Project URL. Not a secret, safe to commit in your own notes.
# Where: your database provider dashboard -> Project -> API
DATABASE_URL=https://your-project-ref.example.com

# Public/anon key. Safe to expose to the browser.
# Where: same page as above, labelled "anon" or "publishable"
PUBLIC_API_KEY=your-public-key-here

# SECRET. Full admin access, bypasses all row-level security.
# Server-side only. Never ship this to a client bundle.
# Where: same page, labelled "service_role". Treat like a password.
SERVICE_ROLE_KEY=

# ───────────────────────────────────────────────
# Third-party APIs
# ───────────────────────────────────────────────

# Where: <provider> dashboard -> API keys -> Create new key
# Scope needed: read-only is sufficient
SOME_PROVIDER_API_KEY=

# Signing secret for webhook verification.
# Generate locally: openssl rand -hex 32
WEBHOOK_SIGNING_SECRET=
```

Three conventions that make this work well with an agent:

1. **A comment above every variable** saying what it is for and exactly where to get it. That sentence is what your agent reads out to you later.
2. **Leave secret values blank.** Placeholder text for non-secret URLs is fine and helps show the expected shape.
3. **Flag the dangerous ones explicitly.** "Server-side only" and "bypasses security" are notes your future self will thank you for.

### 6.3 secrets.template.md, the inventory that is safe to commit

`.env.example` covers one project. This covers the whole machine: every credential the setup needs, where it comes from, and nothing else.

```markdown
# secrets.template.md

This file lists WHICH secrets a restored machine needs and WHERE to get them.
It contains NO values. Values live in a password manager.

## 1. MCP server credentials

| Server | Env var | Where to get it |
|---|---|---|
| <server-name> | `<VAR_NAME>` | <provider> dashboard -> API tokens |

## 2. Account-managed connectors

These are NOT local config. They live in your Claude account and return
automatically when you log in on the new machine. Nothing to re-enter.

## 3. Per-project secrets

| Project | Var | Where to get it |
|---|---|---|
| <project> | `<VAR_NAME>` | <origin system> |

## 4. SSH keys

| Key | Location | Notes |
|---|---|---|
| <name> | `~/.ssh/<name>` | Restore from password manager. `chmod 700 ~/.ssh`, then `chmod 600` the key itself |

## 5. Rotation status

Note here which credentials were exposed and scrubbed but NOT rotated, and
what would break if you rotated them. A shared key powering several live
integrations needs each one migrated before rotation, or they all break.
```

That last section is the one people skip and later regret. Scrubbing a key from a repo does not make it dead. Track which ones are still live.

### 6.4 Before the first push of any new repo

Run every one of these from the repo root. They cost seconds.

```bash
# JWTs
git grep -E 'eyJ[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+\.[A-Za-z0-9_.+/=-]{20,}'
# Common API key shapes
git grep -E 'sk-[A-Za-z0-9]{30,}'
git grep -E 'sk-ant-[A-Za-z0-9_-]{20,}'
git grep -E 'gh[pousr]_[A-Za-z0-9]{30,}'
git grep -E 'AIza[0-9A-Za-z_-]{30,}'
git grep -E 'AKIA[0-9A-Z]{16}'
git grep -E 'xox[baprs]-[A-Za-z0-9-]{10,}'
# Bot tokens (numeric:alnum)
git grep -E '[0-9]{8,12}:[A-Za-z0-9_-]{35,}'
# Private keys
git grep -E -- '-----BEGIN [A-Z ]*PRIVATE KEY-----'
# Generic assignments
git grep -E '(secret|api[_-]?key|password|access[_-]?token)[[:space:]]*[:=][[:space:]]*["'"'"'`][A-Za-z0-9_+/=-]{20,}'
```

Or, better, install `gitleaks` and run `gitleaks detect --no-git` on the working tree plus `gitleaks detect` on history.

**If anything matches, stop.** Do not "fix it in the next commit". Pick one:

- **History worth keeping, or already pushed anywhere**: `git filter-repo --replace-text <patterns-file>`. This is the default choice and the only safe one if a remote already has your commits.
- **Brand-new repo, never pushed, history worth nothing**: redact in the working tree, then re-init from scratch.
  ```bash
  git remote -v          # MUST be empty. If it is not, use filter-repo instead.
  rm -rf .git && git init && git add -A && git commit -m "initial commit"
  ```
  > Only do this when `git remote -v` prints nothing. It destroys all history, branches, and tags. If the repo was ever pushed, this does not help you anyway: the secret is already on the remote, and re-initialising then force-pushing just overwrites shared history while leaving the leak in the remote's reflog.
- **Already live and dangerous**: rotate the value at its origin *first*, then do one of the above. Rotation is what actually makes the secret safe. Scrubbing only stops it spreading further.

### 6.5 Automate it

A `PostToolUse` hook on `Write|Edit` running that same pattern set catches a pasted key the moment it lands, months before it would reach a commit. Report the file and line and the pattern name, never the matched value, so the secret does not end up in your transcript too.

---

## Part 7: Per-project scaffolding

Global config makes Claude Code yours. Per-project scaffolding makes it useful *in a specific codebase*. This is the pattern, distilled from the projects where it was most developed.

### 7.1 CLAUDE.md skeleton

Keep it under about 200 lines. When a section wants to grow, push the depth into a doc and leave a pointer.

```markdown
# CLAUDE.md, <Project>

## Project Overview          <- one paragraph, what and why
## Tech Stack
## Project Structure         <- folder map
## Key Concepts              <- domain vocabulary
## Data Schema / Design System
## API Endpoints
## Environment Variables     <- which exist, never values
## Authentication
## Testing                   <- commands + coverage expectation
## MANDATORY: QA Before Claiming Done   <- the hard gate
## Coding Conventions
## Document Ownership        <- one fact, one owning file, others cross-reference
## Key Reference Documents
## What to Consult Before Making Changes
## Known Technical Debt
## Context Budget
## Self-Review Before Declaring Done    <- always last
```

Two of these do disproportionate work:

- **Document Ownership.** Name exactly one authoritative source per fact. Everything else cross-references it. Without this, the same number drifts across four files and nobody knows which is right.
- **Self-Review Before Declaring Done.** Last section, deliberately, so it is the last thing in context before the model reports back.

### 7.2 A project wiki

For anything long-lived, a `.claude/wiki/` folder compounds. Convention:

- Topic pages in category folders, `lowercase-kebab-case.md`, with prefixes by kind (`d-` for decisions, `gotcha-` for traps).
- Meta pages prefixed `_`:
  - `_index.md`, the navigator
  - `_hot.md`, current focus, kept small and rewritten often
  - `_log.md`, one line per session
  - `_findings.md`, open issues with severity and status
  - `_schema.md`, the wiki's own rules

Frontmatter that works, seven fields:

```yaml
---
created: 2026-01-15
updated: 2026-07-21
source: <file path, session, or URL this came from>
tags: [category/subcategory]
aliases: []
status: stable | evolving | uncertain | deprecated
confidence: high | medium | low
---
```

`source` and `confidence` are the two that matter. Together they let a later session tell *verified fact* from *someone's guess written confidently*, which is otherwise impossible.

**The ingest bar:** capture only what is non-obvious and durable. If a future session could re-derive it from the code or the git log, do not write it down. A wiki full of restated code is worse than no wiki, because it costs attention and rots silently.

### 7.3 A session handoff

One running file, `tasks/session-handoff.md`. Not one file per session.

```markdown
# Session Handoff

## Current state          <- explicitly supersedes everything below
## Resume prompt          <- paste-ready for a cold session
## Next session: P0 / P1 / P2
## Snapshot               <- branch, commit, test count, infra pointers
## Session history        <- newest first, one paragraph each
## Open findings
## Useful commands
```

Mark superseded sections as superseded rather than deleting them. The trail is worth more than the tidiness.

**And label provenance.** When a handoff says something, mark whether it is a decision the human made (binding, do not relitigate) or a claim the previous agent session produced (a hypothesis, recheck it). Without that label, every claim arrives wearing the same confident tone, and stale numbers get repeated to third parties.

---

## Part 8: The acceptance test

Do not report success until every line here passes, and show the output.

```bash
# 1. Layers present, counts match the capture report
for d in agents commands rules skills; do
  printf '%-10s %s\n' "$d" "$(find -L ~/.claude/$d -type f 2>/dev/null | wc -l | tr -d ' ')"
done

# 2. Settings parses
jq empty ~/.claude/settings.json && echo "settings.json OK"

# 3. Every hook script referenced actually exists
jq -r '.. | .command? // empty' ~/.claude/settings.json \
  | grep -oE '(/[^ "]+)+\.(sh|js|py)' | sort -u | while read -r f; do
      [ -f "$f" ] && echo "ok   $f" || echo "MISSING  $f"
    done

# 4. No stale absolute paths from the old machine
grep -o '/Users/[a-z0-9._-]*' ~/.claude/settings.json | sort -u

# 5. Plugins installed, and nothing enabled-but-missing
claude plugin list 2>/dev/null | head -40
jq -r --slurpfile i ~/.claude/plugins/installed_plugins.json \
  '(.enabledPlugins // {}) | to_entries[] | select(.value==true) | .key as $k
   | select(((($i[0].plugins // $i[0])) | has($k)) | not) | "STALE: \($k)"' \
  ~/.claude/settings.json 2>/dev/null

# 6. SSH permissions are right (wrong ones lock you out silently)
ls -ld ~/.ssh && ls -l ~/.ssh/ | head

# 7. No secret is tracked in the backup repo
gitleaks detect --no-banner 2>&1 | tail -5
```

Then the checks a script cannot do:

- [ ] Start a session. Does it load without hook errors?
- [ ] Invoke one skill. Does it trigger?
- [ ] Call one subagent by name. Does it resolve?
- [ ] Does an MCP tool actually return data, not just appear in the list?
- [ ] Open a project. Does its `CLAUDE.md` load?
- [ ] Every project from the capture report: cloned, and `.env` restored?
- [ ] Every warning in the capture report: resolved or consciously accepted?

---

## Part 9: Principles worth stealing

The file layout is the easy part and it will change. These are why the layout is shaped the way it is.

**1. A rule the model must remember is the weakest rule you have.** Under context pressure a text rule loses. Anything safety-critical or repeatedly violated should be promoted from prose to a hook. The strongest rules in any mature harness are the ones with code behind them.

**2. Chat is not storage.** Research, subagent output, and evidence all feel handled the moment they inform an answer. Then the context compacts and they are gone. Write to a file the moment substantive output exists, not at a convenient stopping point. Automate it where you can.

**3. An inherited claim is a hypothesis, not a fact.** A number written by a previous session arrives in exactly the same confident voice as a verified one, and nothing strips that voice off. Distinguish hard: a decision the *human* made is binding, a claim the *agent* made is always recheckable. Label provenance when you write a handoff.

**4. Look fast-moving facts up, do not recall them.** Model capabilities, API syntax, pricing, and tool landscapes move faster than any training cutoff or week-old note. Re-derive at decision time and cite the source with its date. This guide follows its own advice, which is why Part 4 carries URLs and a date.

**5. Verification means checking against something external.** Rereading your own work against your own memory of what you meant reproduces the blind spot that caused the error. Check against the rendered artifact, the source file, or the running system.

**6. Reading the repo is not checking the system.** What is in git and what is running can differ. Source tells you whether something is wired up. Only the running system tells you whether it works.

**7. Recommending is not doing.** After surfacing a recommendation on anything irreversible, cost-bearing, or genuinely someone else's call, stop and wait. Giving advice is not the same as receiving permission.

**8. Match process weight to blast radius, not task size.** A one-line change near a payment path deserves more care than a 200-line documentation edit. Size is the wrong variable. Reversibility is the right one.

**9. Delegate the mechanical, keep the judgment.** Push fan-out, sweeps, and repetitive work to subagents and preserve your main context for synthesis. But never delegate the irreversible step just to save tokens. There, correctness beats efficiency.

**10. Name the ceiling on every deliberate shortcut.** When you knowingly ship a hack, mark it with both what was cut *and* the condition that means it is time to fix it. A marked shortcut is an auditable decision. An unmarked one is a landmine.

```javascript
// shortcut: global lock, switch to per-account locks if throughput matters
// shortcut: O(n squared) scan, fine under ~500 rows, index it past that
```

**11. Redact before the first commit, never after.** Append-only logs do not forget. This applies to git history, sent messages, and published records alike.

**12. Separate "save locally" from "publish externally."** Make them different actions with different triggers and different gates, so a routine save can never become an accidental push to production.

**13. Rotate a review across lenses until a full pass finds nothing new.** One pass has a structural blind spot: it only catches what its single lens is tuned for. Different angles catch materially different things.

**14. Write for a reader with zero context, and test that externally.** Correct and short are both necessary and neither is sufficient. The real bar is whether an uninvolved reader can restate your point after one read. Rereading your own draft does not test that.

**15. A mistake made twice becomes a rule, not another apology.** Individual corrections are cheap to make and cheap to lose. Writing every correction down, and promoting the recurring ones into standing rules, is the thing that compounds.

---

## Part 10: Keep it backed up

A migration you do once will be needed again. Make it repeatable.

**Start with the cheap version.** If you want a weekly backup today, you do not need any of the machinery below: schedule the Part 2 script with `CH_SYNC=1` and commit its output to a private repo. That is [Part 2.5](#25-using-this-weekly-instead-of-once), it takes about ten minutes, and for most people it is where this ends.

The rest of this section is what you build when the cheap version is no longer enough, which usually means you are backing up several machines or several people, or you want the restore itself to be verifiable rather than hopeful.

**The design that works:**

- **An explicit allowlist, never auto-discovery.** List the paths that get backed up. Blind discovery sweeps up caches, transcripts, and gigabytes of dependencies, and eventually a secret.
- **Gitignore first.** Every mirror gets the baseline `.gitignore` before its first `git add`, not after.
- **A secret scan gate that fails closed.** Runs before every commit. If the scanner errors, the commit is refused, not waved through. Layer two independent checks: an entropy-based scanner like `gitleaks`, plus a plain prefix-pattern grep that catches structured low-entropy keys entropy misses.
- **Per-target isolation.** One repo failing must never abort the others.
- **A manifest.** Per-file checksums plus counts, regenerated each run. Without it "the restore worked" is an opinion. With it, it is `N/N match, 0 mismatch, 0 missing`.
- **A plugin lockfile.** `enabledPlugins` plus `extraKnownMarketplaces`, committed.
- **Source only, never live state.** Back up a skill's source, not its cached session data or its virtualenv.
- **A dry run that proves it.** Restore into a throwaway `HOME` and diff against the manifest:
  ```bash
  HOME=$(mktemp -d) bash restore.sh
  ```
  A restore procedure nobody has ever executed is a hypothesis.

Then schedule it, weekly is plenty, and confirm it actually ran. A backup you have never restored from is not a backup.

---

## Appendix: Quick reference

**Where things live**

| What | Path |
|---|---|
| User settings | `~/.claude/settings.json` |
| Rules | `~/.claude/rules/*.md` |
| Skills | `~/.claude/skills/<name>/SKILL.md` |
| Subagents | `~/.claude/agents/<name>.md` |
| Commands | `~/.claude/commands/<name>.md` |
| Hook scripts | wherever you keep them, referenced by absolute path in settings |
| Plugin registry | `~/.claude/plugins/installed_plugins.json` |
| Marketplace registry | `~/.claude/plugins/known_marketplaces.json` |
| MCP (local/user) | `~/.claude.json` |
| MCP (project) | `<repo>/.mcp.json` |
| User memory | `~/.claude/CLAUDE.md` |
| Project memory | `<repo>/CLAUDE.md` |

**Never commit**

```
.env, .env.*        secrets*        *.pem, *.key
id_rsa, id_ed25519  ~/.claude.json  auth.json / auth blobs
*.sqlite*           browser profiles and cookie jars
```

**Always commit**

```
.env.example        secrets.template.md    .mcp.json (with ${VAR} refs)
CLAUDE.md           .claude/agents/**      .claude/wiki/**
.gitignore
```

**Docs**

- Settings: <https://code.claude.com/docs/en/settings>
- Hooks: <https://code.claude.com/docs/en/hooks>
- Skills: <https://code.claude.com/docs/en/skills>
- Subagents: <https://code.claude.com/docs/en/sub-agents>
- Plugins: <https://code.claude.com/docs/en/plugins>
- MCP: <https://code.claude.com/docs/en/mcp>
- Memory: <https://code.claude.com/docs/en/memory>

---

*Config details verified against the official documentation on 2026-07-21. Claude Code moves quickly. Re-check Part 4 against the live docs before relying on any specific key or event name.*
