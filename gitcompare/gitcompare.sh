#!/usr/bin/env bash
# gitcompare.sh — pick two committed versions of a document from its git history
# and redline them against each other with Word's own Compare.
#
#   gitcompare.sh FILE.docx [--gui] [--list] [--pick N,M] [-a "Author"] [-o OUT.docx]
#
# Lists every commit that touched FILE (following renames), plus the working copy
# if it differs from HEAD, and asks which two to compare. The older selection is
# the original, the newer is the revised.
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORDCOMPARE="$HERE/../wordcompare/wordcompare.sh"

# Tracked changes need an author name. Take the user's own, not the packager's.
default_author() {
  git config --get user.name 2>/dev/null || echo "${USER:-Compare}"
}

GUI=0; LIST=0; PICK=""; AUTHOR=$(default_author); OUT=""; FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gui) GUI=1; shift ;;
    --list) LIST=1; shift ;;
    --pick) PICK="$2"; shift 2 ;;
    -a|--author) AUTHOR="$2"; shift 2 ;;
    -o|--output) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) FILE="$1"; shift ;;
  esac
done

# In GUI mode every failure has to become a dialog; nobody sees stderr from Finder.
die() {
  if [ "$GUI" -eq 1 ]; then
    osascript -e 'on run {m}' -e 'tell application "System Events" to activate' \
      -e 'display alert "Compare Versions" message m as critical' -e 'end run' "$1" >/dev/null 2>&1 || true
  fi
  echo "$1" >&2; exit 1
}

[ -n "$FILE" ] || die "No file given."
[ -f "$FILE" ] || die "Not a file: $FILE"
[ -x "$WORDCOMPARE" ] || die "wordcompare.sh not found at $WORDCOMPARE"

FILE=$(python3 -c 'import os,sys;print(os.path.realpath(os.path.expanduser(sys.argv[1])))' "$FILE")
DIR=$(dirname "$FILE"); BASE=$(basename "$FILE"); STEM="${BASE%.*}"; EXT="${BASE##*.}"

ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) \
  || die "$BASE is not inside a git repository, so it has no version history."
REL=$(python3 -c 'import os,sys;print(os.path.relpath(sys.argv[1],sys.argv[2]))' "$FILE" "$ROOT")

# --- build the version list, newest first -------------------------------------
SHAS=(); PATHS=(); LABELS=()

if ! git -C "$ROOT" diff --quiet -- "$REL" 2>/dev/null \
   || ! git -C "$ROOT" ls-files --error-unmatch -- "$REL" >/dev/null 2>&1; then
  SHAS+=("WORKING"); PATHS+=("$REL")
  LABELS+=("Working copy — unsaved to git ($(date -r "$FILE" '+%b %e, %Y at %-I:%M %p' | tr -s ' '))")
fi

while IFS= read -r line; do
  case "$line" in
    C*) IFS=$'\037' read -r _ sha adate aname subj <<<"$line"; pending_sha=$sha
        pending_label="$adate — $subj  [${sha:0:7}, $aname]" ;;
    "") ;;
    *)  if [ -n "${pending_sha:-}" ]; then
          SHAS+=("$pending_sha"); PATHS+=("$line"); LABELS+=("$pending_label"); pending_sha=""
        fi ;;
  esac
done < <(git -C "$ROOT" log --follow --name-only \
           --format="C%x1f%H%x1f%ad%x1f%an%x1f%s" --date=format:'%b %e, %Y' -- "$REL")

N=${#LABELS[@]}

if [ "$LIST" -eq 1 ]; then
  for i in $(seq 0 $((N-1))); do printf '%2d  %s\n' "$i" "${LABELS[$i]}"; done
  exit 0
fi

[ "$N" -ge 2 ] || die "$BASE has only $N version(s) in git — nothing to compare yet."

# --- ask which two ------------------------------------------------------------
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
BASE_AS=$(printf '%s' "$BASE" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '%s\n' "${LABELS[@]}" > "$TMP/labels.txt"

if [ -n "$PICK" ]; then
  IFS=, read -r A B <<<"$PICK"
  case "$A$B" in *[!0-9]*|"") die "--pick needs two indices, e.g. --pick 0,2" ;; esac
  { [ "$A" -lt "$N" ] && [ "$B" -lt "$N" ] && [ "$A" != "$B" ]; } \
    || die "--pick indices must be two different numbers between 0 and $((N-1))."
else
CHOSEN=$(osascript <<APPLESCRIPT
set f to POSIX file "$TMP/labels.txt"
set txt to read f as «class utf8»
set AppleScript's text item delimiters to linefeed
set items_ to every text item of txt
set opts to {}
repeat with t in items_
  if (t as text) is not "" then set end of opts to (t as text)
end repeat
tell application "System Events" to activate
set picked to choose from list opts with title "Compare Versions" ¬
  with prompt "$BASE_AS" & return & return & ¬
  "Select two versions. The older one is treated as the original." ¬
  OK button name "Compare" with multiple selections allowed
if picked is false then return "CANCELLED"
set AppleScript's text item delimiters to linefeed
return picked as text
APPLESCRIPT
) || die "Could not show the version picker."

[ "$CHOSEN" = "CANCELLED" ] && exit 0

SEL=()
while IFS= read -r c; do [ -n "$c" ] && SEL+=("$c"); done <<<"$CHOSEN"
[ "${#SEL[@]}" -eq 2 ] || die "Please select exactly two versions (you selected ${#SEL[@]})."

idx_of() { local i; for i in $(seq 0 $((N-1))); do [ "${LABELS[$i]}" = "$1" ] && { echo "$i"; return; }; done; echo -1; }
A=$(idx_of "${SEL[0]}"); B=$(idx_of "${SEL[1]}")
[ "$A" -ge 0 ] && [ "$B" -ge 0 ] || die "Could not match the selection back to a commit."
fi

# The list is newest-first, so the LARGER index is the older = the original.
if [ "$A" -gt "$B" ]; then OLD=$A; NEW=$B; else OLD=$B; NEW=$A; fi

# --- extract both versions ----------------------------------------------------
tag() { [ "${SHAS[$1]}" = "WORKING" ] && echo "working" || echo "${SHAS[$1]:0:7}"; }
extract() { # index outpath
  if [ "${SHAS[$1]}" = "WORKING" ]; then cp "$FILE" "$2"
  else git -C "$ROOT" show "${SHAS[$1]}:${PATHS[$1]}" > "$2" || die "Could not read version $(tag "$1") of $BASE."; fi
  [ -s "$2" ] || die "Version $(tag "$1") of $BASE came out empty."
}
OLDF="$TMP/$STEM ($(tag "$OLD")).$EXT"; NEWF="$TMP/$STEM ($(tag "$NEW")).$EXT"
extract "$OLD" "$OLDF"; extract "$NEW" "$NEWF"

[ -n "$OUT" ] || OUT="$DIR/$STEM-COMPARE-$(tag "$OLD")-vs-$(tag "$NEW").$EXT"

# Word is sandboxed, and it asks for access per folder. Inside its own container it needs no
# permission at all, so do the whole compare there and move the result out with the shell —
# that way Word never touches a folder it has to ask about. The path is fixed, not per-run:
# a unique staging folder would re-prompt every single time.
WORDBOX="$HOME/Library/Containers/com.microsoft.Word/Data"
if [ -d "$WORDBOX" ]; then STAGE="$WORDBOX/gitcompare"; else STAGE="$DIR/.gitcompare"; fi
rm -rf "$STAGE"; mkdir -p "$STAGE"
trap 'rm -rf "$TMP" "$STAGE"' EXIT
cp "$OLDF" "$STAGE/"; cp "$NEWF" "$STAGE/"
STAGED_OUT="$STAGE/$(basename "$OUT")"

"$WORDCOMPARE" "$STAGE/$(basename "$OLDF")" "$STAGE/$(basename "$NEWF")" "$STAGED_OUT" -a "$AUTHOR" \
  || die "Word's Compare failed. Is Microsoft Word installed?"

[ -f "$STAGED_OUT" ] || die "The comparison produced no output."
mv "$STAGED_OUT" "$OUT" || die "Could not move the redline to $OUT."

if [ "$GUI" -eq 1 ]; then
  open -R "$OUT"; open "$OUT"
else
  echo "wrote $OUT"
fi
