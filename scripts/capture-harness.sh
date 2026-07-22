#!/usr/bin/env bash
# capture-harness.sh: READ-ONLY capture of a Claude Code setup.
#
# Two ways to use it, and most people end up on the second:
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
