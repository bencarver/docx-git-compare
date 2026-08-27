# Demo and screenshots

Everything here exists so the tool can be demonstrated publicly without a real document
ever appearing on screen.

```bash
./demo/make-demo-repo.sh
```

That builds `~/docx-git-compare-demo` — a git repo containing one fabricated mutual NDA
between Northwind Traders, Inc. and Contoso Ltd, committed four times with realistic legal
commit messages and backdated to February and March 2026. Nothing in it is real. It prints
the version list when it finishes, and it is safe to re-run: it rebuilds from scratch.

Redlines generated from that repo are attributed to "A. Lawyer", because the repo carries
its own `user.name` and `gitcompare` reads the document repo's config rather than your
global one. Your name will not appear in Word's markup.

## Ready-made images

`demo/assets/` holds two things, and they are not the same kind of artifact:

| File | What it is |
| --- | --- |
| `redline-page-1.png` | **A real render** of the actual output — page 1 of the demo redline, insertions underlined, deletions struck through, change bars in the margin. Produced by `render-redline.sh`, no screen capture involved |
| `finder-right-click.png` | **A real screenshot** of the Finder context menu, taken on the demo folder |
| `version-picker.png` | **A real screenshot** of the version picker listing the four demo commits |
| `flow.svg` | An illustration of the same flow, kept only as a diagram source. Superseded by the two screenshots above; do not pass it off as a capture |

Regenerate the redline render at any time:

```bash
./demo/make-demo-repo.sh
./gitcompare/gitcompare.sh ~/docx-git-compare-demo/Mutual-NDA-Northwind-Contoso.docx --pick 2,3
./demo/render-redline.sh ~/docx-git-compare-demo/Mutual-NDA-*-COMPARE-*.docx demo/assets
```

`render-redline.sh` goes through LibreOffice rather than Word on purpose. Word's AppleScript
`save as ... format PDF` exports the document as though every change had been accepted, and
it ignores `print revisions` on the document and `show revisions and comments` on the window
even when both read back as `true`. LibreOffice renders the markup properly.

## Recording it

`screencapture` needs Screen Recording permission, granted per app in
System Settings > Privacy & Security > Screen & System Audio Recording. Grant it to whatever
terminal you run these from.

Video, 30 seconds, to the Desktop:

```bash
screencapture -v -V 30 ~/Desktop/demo.mov
```

A single window, chosen by clicking it — the cleanest way to shoot the picker dialog or the
Word redline without catching anything else:

```bash
screencapture -w -o ~/Desktop/picker.png
```

A fixed region, if you want to frame it yourself:

```bash
screencapture -R 100,100,1200,800 ~/Desktop/region.png
```

## Before you post anything

The tool's output is safe. Your screen is not. Check for:

- **Other Finder windows and tabs.** Matter folder names in a sidebar or tab bar are the
  most likely leak. Open a single new window at the demo folder and close the rest.
- **Recent items.** Word's start screen, the File menu, and the Finder "Recents" sidebar
  entry all list real documents.
- **The menu bar and Dock.** Notifications, calendar titles, and unread badges.
- **Your home directory name**, which shows in the Finder title bar and in any terminal
  prompt. `~/docx-git-compare-demo` is deliberately at the top of home so the breadcrumb is
  short and contains nothing else.
- **Terminal scrollback**, if you record a terminal window at all.

## A run worth filming

The four versions produce a redline with real substance — 26 insertions and 23 deletions
between the first two, which is what a first markup of a counterparty's form actually looks
like:

| Compare | Shows |
| --- | --- |
| "standard form as received" vs "first markup" | The interesting one. One-way agreement made mutual, five-year term cut to three, confidentiality carve-outs and a compelled-disclosure clause added, unilateral injunctive relief made reciprocal |
| "first markup" vs "accept their 4-year term" | A small, legible counter: three years becomes four, injunctive relief narrowed |
| "as received" vs "for execution" | The whole negotiation in one redline |
