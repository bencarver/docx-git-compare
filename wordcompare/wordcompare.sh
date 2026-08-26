#!/usr/bin/env bash
# wordcompare.sh — drive Microsoft Word's own Compare (Legal Blackline) from the command line.
#
#   wordcompare.sh ORIGINAL.docx REVISED.docx [OUTPUT.docx] [-a "Author Name"] [--keep-open]
#                  [--timeout SECONDS]
#
# Word's AppleScript `compare` verb must be addressed to a document by NAME or INDEX.
# Passing the value returned by `open` fails with -1708.
set -euo pipefail

# Tracked changes need an author name. Take the user's own, not the packager's.
default_author() {
  git config --get user.name 2>/dev/null || echo "${USER:-Compare}"
}

AUTHOR=$(default_author); KEEP=0; TIMEOUT=900; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -a|--author) AUTHOR="$2"; shift 2 ;;
    --keep-open) KEEP=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[ "${#ARGS[@]}" -ge 2 ] || { echo "usage: wordcompare.sh ORIGINAL.docx REVISED.docx [OUTPUT.docx] [-a AUTHOR] [--keep-open]" >&2; exit 2; }

abspath() { python3 -c 'import os,sys;print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$1"; }
ORIG=$(abspath "${ARGS[0]}"); REV=$(abspath "${ARGS[1]}")
if [ "${#ARGS[@]}" -ge 3 ]; then OUT=$(abspath "${ARGS[2]}")
else OUT="$(dirname "$REV")/$(basename "${REV%.*}")-WORDCOMPARE.docx"; fi

for f in "$ORIG" "$REV"; do [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }; done
ORIGNAME=$(basename "$ORIG")
rm -f "$OUT"

osascript <<EOF >/dev/null
with timeout of $TIMEOUT seconds
tell application "Microsoft Word"
  open file name "$ORIG"
  tell document "$ORIGNAME" to compare path "$REV" author name "$AUTHOR" ¬
      target compare target new detect format changes false ¬
      ignore all comparison warnings true add to recent files false
  set r to active document
  save as r file name "$OUT" file format format document
  $( [ "$KEEP" -eq 1 ] || echo 'close r saving no' )
  close document "$ORIGNAME" saving no
end tell
end timeout
EOF

[ -f "$OUT" ] || { echo "compare produced no output" >&2; exit 1; }
python3 - "$OUT" <<'PY'
import sys,zipfile,re
x=zipfile.ZipFile(sys.argv[1]).read("word/document.xml").decode("utf8","ignore")
ins=len(re.findall(r"<w:ins ",x)); dele=len(re.findall(r"<w:del ",x))
au=sorted(set(re.findall(r'w:author="([^"]+)"',x)))
print(f"{sys.argv[1]}\n  {ins} insertions, {dele} deletions, authors: {', '.join(au) or 'none'}")
PY
