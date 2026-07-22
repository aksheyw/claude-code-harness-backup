#!/usr/bin/env bash
# test-capture.sh: asserts the promises the README and SECURITY.md make
# about scripts/capture-harness.sh.
#
#   bash tests/test-capture.sh
#
# Runs the capture against a synthetic HOME, so it never touches yours.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$HERE/scripts/capture-harness.sh"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected '$2', got '$1')"; fi; }

# ---- build a synthetic machine ------------------------------------------
FAKE=$(mktemp -d) || { echo "cannot create temp dir"; exit 1; }
[ -n "$FAKE" ] && [ -d "$FAKE" ] || { echo "temp dir invalid"; exit 1; }
trap 'rm -rf "$FAKE"' EXIT

mkdir -p "$FAKE/home/.claude"/{rules,agents,commands,scripts/hooks,memory}
mkdir -p "$FAKE/home/.claude/skills/demo-skill"
echo "a rule"                  > "$FAKE/home/.claude/rules/style.md"
echo "an agent"                > "$FAKE/home/.claude/agents/reviewer.md"
echo "a command"               > "$FAKE/home/.claude/commands/deploy.md"
echo "a skill"                 > "$FAKE/home/.claude/skills/demo-skill/SKILL.md"
echo "a memory"                > "$FAKE/home/.claude/memory/MEMORY.md"
echo "echo hi"                 > "$FAKE/home/.claude/scripts/hooks/check.sh"
printf '{"hooks":{},"enabledPlugins":{}}' > "$FAKE/home/.claude/settings.json"

# Credential FIXTURES. Deliberately NOT shaped like any real provider's key:
# the assertion below is "does the report echo this VALUE back", which does not
# depend on the value looking real. Using a provider-shaped string here would
# put fake keys in /tmp for any scanner watching a CI runner to trip over.
PRE="notarealkey"; MID="fixture"
FAKE_A="${PRE}-${MID}-abcdefghijklmnopqrstuvwxyz0123456789"
FAKE_B="${PRE}-${MID}-zyxwvutsrqponmlkjihgfedcba9876543210"
FAKE_C="${PRE}-${MID}-000111222333444555666777888999aaabbb"

printf '{"mcpServers":{"demo":{"env":{"API_TOKEN":"%s"}}}}' "$FAKE_A" \
  > "$FAKE/home/.claude.json"
{ echo "export PATH=/usr/bin"
  echo "export DEMO_SERVICE_API_KEY=$FAKE_B"
} > "$FAKE/home/.zshrc"

# projects: one clean with a remote, one with no git at all
mkdir -p "$FAKE/proj/clean-repo" "$FAKE/proj/no-git"
( cd "$FAKE/proj/clean-repo" && git init -q . \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
  && git remote add origin https://example.com/x.git ) >/dev/null 2>&1
[ -d "$FAKE/proj/clean-repo/.git" ] || { echo "could not build the synthetic git repo (is git installed?)"; exit 1; }
echo "untracked work" > "$FAKE/proj/no-git/notes.md"
printf 'SECRET_VALUE=%s\n' "$FAKE_C" > "$FAKE/proj/clean-repo/.env"

OUT="$FAKE/out"
CH_YES=1 HOME="$FAKE/home" OUT="$OUT" PROJ_ROOT="$FAKE/proj" bash "$SCRIPT" >/dev/null 2>&1
RC=$?

echo "test-capture.sh"

# ---- 1. it completes -----------------------------------------------------
check "$RC" "0" "exits cleanly"
[ -f "$OUT/report.md" ] && ok "writes a report" || bad "writes a report"

# ---- 2. THE promise: no credential VALUE in the readable report ----------
# Assert the report EXISTS first. Without this the grep below returns
# non-zero on a missing file and the assertion passes vacuously, which is
# the exact failure mode this whole file is meant to catch.
if [ ! -s "$OUT/report.md" ]; then
  bad "report contains no credential values (NO REPORT PRODUCED, cannot assert)"
elif grep -qE "${PRE}-${MID}-[A-Za-z0-9]{20,}" "$OUT/report.md"; then
  bad "report contains no credential values"
else
  ok "report contains no credential values"
fi
# but it SHOULD name the variable, or the report is useless
grep -q 'DEMO_SERVICE_API_KEY' "$OUT/report.md" && ok "report names the credential variable" \
  || bad "report names the credential variable"

# ---- 3. the authored layers are actually COPIED, not just counted -------
for d in rules agents commands skills memory; do
  n=$(find -L "$OUT/claude/$d" -type f 2>/dev/null | wc -l | tr -d ' ')
  n=${n:-0}
  [ "$n" -ge 1 ] && ok "copies $d/ ($n)" || bad "copies $d/ (found $n)"
done

# ---- 4. it never mutates the source setup -------------------------------
[ -f "$FAKE/home/.claude/rules/style.md" ] && ok "leaves ~/.claude intact" \
  || bad "leaves ~/.claude intact"

# ---- 5. project risk detection ------------------------------------------
grep -q 'no-git' "$OUT/report.md" && ok "reports the project folder with no git" \
  || bad "reports the project folder with no git"
grep -qi 'NO GIT' "$OUT/report.md" && ok "flags it as NO GIT" || bad "flags it as NO GIT"

# ---- 6. .env is captured so a migration does not lose it ----------------
find "$OUT/env-files" -type f 2>/dev/null | grep -q . && ok "captures .env files" \
  || bad "captures .env files"

# ---- 7. the guide's embedded copy has not drifted -----------------------
python3 - "$HERE" <<'PY'
import pathlib, sys
h = pathlib.Path(sys.argv[1])
g = (h / "GUIDE.md").read_text()
s = (h / "scripts/capture-harness.sh").read_text()
i = g.index("<summary><b>capture-harness.sh</b>")
fo = g.index("```bash", i) + 8
fc = g.index("\n```\n", fo)
sys.exit(0 if g[fo:fc].strip() == s.strip() else 1)
PY
[ $? -eq 0 ] && ok "GUIDE.md copy matches the script" || bad "GUIDE.md copy matches the script"

# ---- 8. a .gitignore is written, and it covers the secret-bearing paths --
# Ordering is the point: it must exist before a first `git add -A` can run.
if [ -f "$OUT/.gitignore" ]; then
  ok "writes a .gitignore into the output folder"
  miss=""
  for pat in 'config/claude.json.SECRET' 'env-files/' 'config/settings.json'; do
    grep -qxF "$pat" "$OUT/.gitignore" || miss="$miss $pat"
  done
  [ -z "$miss" ] && ok "the .gitignore excludes the secret-bearing paths" \
    || bad "the .gitignore excludes the secret-bearing paths (missing:$miss)"
  # and prove it actually works, rather than trusting the text
  if command -v git >/dev/null 2>&1; then
    ( cd "$OUT" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1
      if git status --porcelain 2>/dev/null | grep -qE 'claude\.json\.SECRET|env-files/|config/settings'; then
        exit 1
      fi ) && ok "git add -A in the output folder stages no secret file" \
           || bad "git add -A in the output folder stages no secret file"
    rm -rf "$OUT/.git"
  fi
else
  bad "writes a .gitignore into the output folder"
  bad "the .gitignore excludes the secret-bearing paths (no file)"
fi

# ---- 9. re-run safety, and the additive-vs-mirror distinction -----------
# The script is documented as safe to re-run and as the basis of a weekly
# backup, so both halves of that promise get asserted here.
SB="$FAKE/rerun"
mkdir -p "$SB/home/.claude/rules" "$SB/proj"
echo "keep" > "$SB/home/.claude/rules/keep.md"
echo "drop" > "$SB/home/.claude/rules/drop.md"
printf '{"mcpServers":{}}' > "$SB/home/.claude.json"
# `env` matters here: a VAR=val word arriving via "$@" is NOT treated as an
# assignment, because bash resolves those at parse time. Without env, passing
# CH_SYNC=1 would try to run a command by that name and the script would
# never execute, which reads as a passing additive-mode test and a failing
# mirror-mode one.
run_sb() { env CH_YES=1 HOME="$SB/home" OUT="$SB/out" PROJ_ROOT="$SB/proj" "$@" bash "$SCRIPT" >/dev/null 2>&1; }

run_sb
hdr=$(grep -c '^# Claude Code harness capture' "$SB/out/report.md" 2>/dev/null | tr -d ' ')
run_sb
hdr2=$(grep -c '^# Claude Code harness capture' "$SB/out/report.md" 2>/dev/null | tr -d ' ')
check "${hdr:-0}" "1" "one run writes exactly one report header"
check "${hdr2:-0}" "1" "re-running rewrites the report, it does not append"

# default mode is additive: a deleted source file STAYS in the copy
rm -f "$SB/home/.claude/rules/drop.md"
run_sb
[ -f "$SB/out/claude/rules/drop.md" ] \
  && ok "default mode is additive (a deleted file remains in the copy)" \
  || bad "default mode is additive (a deleted file remains in the copy)"

# mirror mode propagates the deletion, which is what makes a weekly backup honest
run_sb CH_SYNC=1
[ -f "$SB/out/claude/rules/drop.md" ] \
  && bad "CH_SYNC=1 mirrors deletions" \
  || ok "CH_SYNC=1 mirrors deletions"
[ -f "$SB/out/claude/rules/keep.md" ] \
  && ok "CH_SYNC=1 keeps the files that still exist" \
  || bad "CH_SYNC=1 keeps the files that still exist"

# ---- 10. mirror mode refuses an unsafe destination ---------------------
# --delete is the only thing here that can remove a file, so the guard that
# stops it pointing at a home directory is load-bearing, not decorative.
CH_YES=1 CH_SYNC=1 HOME="$SB/home" OUT="$SB/home" bash "$SCRIPT" >/dev/null 2>&1
check "$?" "2" "CH_SYNC refuses when OUT is the home directory"
[ -f "$SB/home/report.md" ] && bad "the refusal writes nothing into that directory" \
  || ok "the refusal writes nothing into that directory"
CH_YES=1 CH_SYNC=1 HOME="$SB/home" OUT="$SB" bash "$SCRIPT" >/dev/null 2>&1
check "$?" "2" "CH_SYNC refuses when OUT is an ancestor of home"

# ---- 11. THE failure promise: a copy that fails is never reported as done
# This is the whole reason the script counts failures. People read this
# report and then erase a disk.
FB="$FAKE/failure"
mkdir -p "$FB/home/.claude/rules" "$FB/proj" "$FB/out"
echo "r" > "$FB/home/.claude/rules/a.md"
printf '{"mcpServers":{}}' > "$FB/home/.claude.json"
# Induce the failure with a destination that CANNOT be written rather than a
# source that cannot be read. `chmod 000` is not a barrier to root, so a
# permission-based fixture turns into a silent no-op on a root CI container,
# and the single most important assertion in this file would pass vacuously.
# A regular file where a directory must be fails for every user, root included.
: > "$FB/out/config"
CH_YES=1 HOME="$FB/home" OUT="$FB/out" PROJ_ROOT="$FB/proj" bash "$SCRIPT" >/dev/null 2>&1
FRC=$?
check "$FRC" "1" "a failed copy makes the script exit 1"
if [ -f "$FB/out/report.md" ]; then
  grep -q 'FAILED to copy' "$FB/out/report.md" \
    && ok "the report names the failed copy" || bad "the report names the failed copy"
  # the actual bug this replaced: the report claimed success for a file it never copied
  grep -q '^- Copied .*claude\.json' "$FB/out/report.md" \
    && bad "the report must NOT claim it copied the file that failed" \
    || ok "the report does not claim it copied the file that failed"
  grep -q 'FAILED to copy' "$FB/out/report.md" && grep -q 'Do not wipe this machine' "$FB/out/report.md" \
    && ok "the report tells the reader not to wipe" || bad "the report tells the reader not to wipe"
else
  bad "the report names the failed copy (no report produced)"
  bad "the report does not claim it copied the file that failed (no report)"
  bad "the report tells the reader not to wipe (no report)"
fi

# ---- 11b. mirror mode must never silently degrade into a non-mirror ------
# Without rsync there is no way to propagate a deletion, so claiming to
# mirror would be a lie. It has to refuse rather than half-do the job.
MB="$FAKE/nomirror"
mkdir -p "$MB/home/.claude/rules" "$MB/bin"
echo "r" > "$MB/home/.claude/rules/a.md"
# Build a PATH holding every usual tool EXCEPT rsync. Simply emptying PATH
# does not work: `env` resolves the program it runs through the new PATH, so
# the test would die at 127 before the script ever started, which looks like
# a failing assertion but tests nothing.
for _p in /bin /usr/bin; do
  [ -d "$_p" ] || continue
  for _f in "$_p"/*; do
    _n=$(basename "$_f")
    [ "$_n" = "rsync" ] && continue
    [ -e "$MB/bin/$_n" ] || ln -s "$_f" "$MB/bin/$_n" 2>/dev/null
  done
done
if [ -x "$MB/bin/bash" ] && ! [ -e "$MB/bin/rsync" ]; then
  env PATH="$MB/bin" CH_YES=1 CH_SYNC=1 HOME="$MB/home" OUT="$MB/out" \
    "$MB/bin/bash" "$SCRIPT" >/dev/null 2>&1
  check "$?" "2" "CH_SYNC refuses when rsync is unavailable"
else
  bad "CH_SYNC refuses when rsync is unavailable (could not build an rsync-free PATH)"
fi

# ---- 11c. re-running without rsync must not nest the copy ---------------
# `cp -RL src dest` puts src INSIDE dest once dest exists, so a second run
# would build claude/rules/rules/ and the file count would double.
NB="$FAKE/norsync"
mkdir -p "$NB/home/.claude/rules" "$NB/proj" "$NB/stub"
echo "r" > "$NB/home/.claude/rules/a.md"
printf '{"mcpServers":{}}' > "$NB/home/.claude.json"
printf '#!/bin/sh\nexit 1\n' > "$NB/stub/rsync"; chmod +x "$NB/stub/rsync"   # force the cp path
for _ in 1 2; do
  env PATH="$NB/stub:$PATH" CH_YES=1 HOME="$NB/home" OUT="$NB/out" PROJ_ROOT="$NB/proj" \
    bash "$SCRIPT" >/dev/null 2>&1
done
[ -e "$NB/out/claude/rules/rules" ] \
  && bad "the cp fallback does not nest on a re-run" \
  || ok "the cp fallback does not nest on a re-run"
[ -f "$NB/out/claude/rules/a.md" ] \
  && ok "the cp fallback still captures the files" \
  || bad "the cp fallback still captures the files"

# ---- 11c-2. nothing is written or deleted outside the output folder ------
# A symlink ANYWHERE above the destination redirects the copy, and in mirror
# mode the delete, to wherever it points. The leaf can look like an ordinary
# directory while the parent is the link, so both levels get a case here.
for _case in parent leaf; do
  XB="$FAKE/escape-$_case"
  mkdir -p "$XB/home/.claude/rules" "$XB/out" "$XB/victim/rules"
  echo "irreplaceable" > "$XB/victim/rules/precious.md"
  echo "r" > "$XB/home/.claude/rules/a.md"
  printf '{"mcpServers":{}}' > "$XB/home/.claude.json"
  if [ "$_case" = "parent" ]; then
    ln -sfn "$XB/victim" "$XB/out/claude"          # the PARENT is the symlink
  else
    mkdir -p "$XB/out/claude"
    ln -sfn "$XB/victim/rules" "$XB/out/claude/rules"   # the LEAF is the symlink
  fi
  CH_YES=1 CH_SYNC=1 HOME="$XB/home" OUT="$XB/out" PROJ_ROOT="$XB/nothing" \
    bash "$SCRIPT" >/dev/null 2>&1
  _rc=$?
  # The assertion that matters, in both shapes: the external file lives.
  [ -f "$XB/victim/rules/precious.md" ] \
    && ok "mirror mode cannot delete outside the output folder ($_case symlink)" \
    || bad "mirror mode cannot delete outside the output folder ($_case symlink)"
  # Two safe outcomes, depending on which guard catches it first. Refusing up
  # front (exit 2, no report) is the stricter one; running and recording the
  # failure is the other. What must never happen is a silent success.
  if [ "$_rc" = "2" ] && [ ! -e "$XB/out/report.md" ]; then
    ok "refuses up front rather than proceeding ($_case symlink)"
  elif [ -s "$XB/out/report.md" ] && grep -q 'FAILED to copy' "$XB/out/report.md"; then
    ok "records the escaping copy as a failure ($_case symlink)"
  else
    bad "the escape is neither refused nor recorded ($_case symlink, rc=$_rc)"
  fi
done

# ---- 11d. a credential inside a git remote URL never reaches the report --
if command -v git >/dev/null 2>&1; then
  GB="$FAKE/giturl"
  mkdir -p "$GB/home/.claude" "$GB/proj/repo"
  echo "r" > "$GB/home/.claude/r.md"
  printf '{"mcpServers":{}}' > "$GB/home/.claude.json"
  # DISTINCT secrets per repo. With a shared value, repo2 alone satisfies both
  # assertions and the user:pass case is never actually proven.
  URL_SECRET_A="notarealtokenaaa0123456789"
  URL_SECRET_B="notarealtokenbbb0123456789"
  mkdir -p "$GB/proj/repo2"
  ( cd "$GB/proj/repo" && git init -q . \
    && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m i \
    && git remote add origin "https://oauth2:$URL_SECRET_A@example.com/o/r1.git" ) >/dev/null 2>&1
  # The colon-free form is how most forge tokens are actually pasted, and a
  # redactor written only for user:pass@ sails straight past it.
  ( cd "$GB/proj/repo2" && git init -q . \
    && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m i \
    && git remote add origin "https://$URL_SECRET_B@example.com/o/r2.git" ) >/dev/null 2>&1
  CH_YES=1 HOME="$GB/home" OUT="$GB/out" PROJ_ROOT="$GB/proj" bash "$SCRIPT" >/dev/null 2>&1
  for _c in "r1:$URL_SECRET_A:user-password form" "r2:$URL_SECRET_B:colon-free token form"; do
    _repo=${_c%%:*}; _rest=${_c#*:}; _sec=${_rest%%:*}; _label=${_rest#*:}
    if [ ! -s "$GB/out/report.md" ]; then
      bad "a git remote URL is redacted, $_label (no report produced)"
    elif ! grep -q "o/$_repo.git" "$GB/out/report.md"; then
      # Without this the absence of the secret proves nothing: the row may
      # simply never have reached the report.
      bad "a git remote URL is redacted, $_label (that remote never reached the report)"
    elif grep -q "$_sec" "$GB/out/report.md"; then
      bad "a git remote URL is redacted, $_label"
    else
      ok "a git remote URL is redacted, $_label"
    fi
  done
fi

# ---- 11e. the output folder's own paths are not written through symlinks --
# report.md, config/, inventory/ and env-files/ are written directly, not via
# copy_tree, so they need their own containment check.
for _target in report.md config inventory env-files; do
  YB="$FAKE/sym-$_target"
  mkdir -p "$YB/home/.claude" "$YB/out" "$YB/victim"
  echo "irreplaceable" > "$YB/victim/keep.md"
  echo "r" > "$YB/home/.claude/r.md"
  printf '{"mcpServers":{}}' > "$YB/home/.claude.json"
  if [ "$_target" = "report.md" ]; then
    echo "someone else's file" > "$YB/victim/file"
    ln -sfn "$YB/victim/file" "$YB/out/report.md"
  else
    ln -sfn "$YB/victim" "$YB/out/$_target"
  fi
  CH_YES=1 HOME="$YB/home" OUT="$YB/out" PROJ_ROOT="$YB/none" bash "$SCRIPT" >/dev/null 2>&1
  _rc=$?
  if [ "$_target" = "report.md" ]; then
    [ "$(cat "$YB/victim/file" 2>/dev/null)" = "someone else's file" ] \
      && ok "refuses rather than truncating a symlinked $_target" \
      || bad "refuses rather than truncating a symlinked $_target"
  else
    [ -f "$YB/victim/keep.md" ] && [ "$_rc" = "2" ] \
      && ok "refuses rather than writing through a symlinked $_target/" \
      || bad "refuses rather than writing through a symlinked $_target/ (rc=$_rc)"
  fi
done

# ---- 12. hook commands are redacted before they reach the report --------
# An inline hook command can carry a token, and report.md is the file people
# paste into an issue. Values go, structure stays.
HB="$FAKE/hooks"
mkdir -p "$HB/home/.claude" "$HB/proj"
HOOK_SECRET="notarealsecretvalue0123456789"
cat > "$HB/home/.claude/settings.json" <<JSON
{"hooks":{"PostToolUse":[{"hooks":[{"type":"command","command":"notify --auth AUTH_TOKEN=$HOOK_SECRET"}]}]}}
JSON
printf '{"mcpServers":{}}' > "$HB/home/.claude.json"
CH_YES=1 HOME="$HB/home" OUT="$HB/out" PROJ_ROOT="$HB/proj" bash "$SCRIPT" >/dev/null 2>&1
if [ ! -s "$HB/out/report.md" ]; then
  bad "hook commands are redacted in the report (no report produced)"
elif ! grep -q 'notify --auth' "$HB/out/report.md"; then
  # Guard against a vacuous pass: if the command never reached the report at
  # all, "the secret is absent" proves nothing about the redactor.
  bad "hook commands are redacted (the command never reached the report, cannot assert)"
else
  grep -q "$HOOK_SECRET" "$HB/out/report.md" \
    && bad "hook commands are redacted in the report" \
    || ok "hook commands are redacted in the report"
  grep -q 'AUTH_TOKEN=<REDACTED>' "$HB/out/report.md" \
    && ok "redaction keeps the command readable" || bad "redaction keeps the command readable"
fi

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
