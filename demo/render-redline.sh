#!/usr/bin/env bash
# render-redline.sh — render a redlined .docx to PNG pages with the tracked changes VISIBLE.
# Produces a shareable picture of real output without capturing the screen, so it needs no
# Screen Recording permission and cannot accidentally include anything else on your display.
#
#   ./render-redline.sh REDLINE.docx [OUT_DIR]
#
# Uses LibreOffice, not Word, and that is deliberate. Word's AppleScript `save as ... format
# PDF` exports the document as if every change had been accepted — it ignores the document's
# `print revisions` and the window's `show revisions and comments`, both of which read back as
# true. LibreOffice's PDF export renders insertions underlined, deletions struck through and
# change bars in the margin, which is what a redline is supposed to look like.
set -euo pipefail

SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
DPI=144

[ $# -ge 1 ] || { echo "usage: render-redline.sh REDLINE.docx [OUT_DIR]" >&2; exit 2; }
[ -x "$SOFFICE" ] || { echo "LibreOffice not found at $SOFFICE" >&2; exit 1; }
command -v pdftoppm >/dev/null 2>&1 || { echo "pdftoppm not found (brew install poppler)" >&2; exit 1; }

abspath() { python3 -c 'import os,sys;print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$1"; }
DOC=$(abspath "$1")
OUTDIR=$([ $# -ge 2 ] && abspath "$2" || dirname "$DOC")
[ -f "$DOC" ] || { echo "not found: $DOC" >&2; exit 1; }
mkdir -p "$OUTDIR"

NAME=$(basename "${DOC%.*}")
"$SOFFICE" --headless --convert-to pdf --outdir "$OUTDIR" "$DOC" >/dev/null 2>&1
PDF="$OUTDIR/$NAME.pdf"
[ -f "$PDF" ] || { echo "LibreOffice produced no PDF" >&2; exit 1; }

pdftoppm -png -r "$DPI" "$PDF" "$OUTDIR/$NAME-page"
echo "PDF: $PDF"
for f in "$OUTDIR/$NAME"-page*.png; do
  [ -f "$f" ] || continue
  echo "PNG: $f ($(python3 -c "
import struct,sys
d=open(sys.argv[1],'rb').read(33)
print('%dx%d' % struct.unpack('>II', d[16:24]))
" "$f"))"
done
