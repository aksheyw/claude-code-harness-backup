#!/usr/bin/env bash
# test-capture.sh: asserts the promises the README and SECURITY.md make
# about scripts/capture-old-laptop.sh.
#
#   bash tests/test-capture.sh
#
# Runs the capture against a synthetic HOME, so it never touches yours.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$HERE/scripts/capture-old-laptop.sh"
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
s = (h / "scripts/capture-old-laptop.sh").read_text()
i = g.index("<summary><b>capture-old-laptop.sh</b>")
fo = g.index("```bash", i) + 8
fc = g.index("\n```\n", fo)
sys.exit(0 if g[fo:fc].strip() == s.strip() else 1)
PY
[ $? -eq 0 ] && ok "GUIDE.md copy matches the script" || bad "GUIDE.md copy matches the script"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
