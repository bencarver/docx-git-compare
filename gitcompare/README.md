# gitcompare

Right-click a Word document in Finder, pick two versions out of its git history by their
commit message, and get Word's own redline between them.

```bash
gitcompare.sh FILE.docx [--gui] [--list] [--pick N,M] [-a "Author"] [-o OUT.docx]
```

The Finder Quick Action is the point of it; the CLI is the same thing without the dialog.

## Install the Quick Action

```bash
gitcompare/install-quick-action.sh
```

That writes `~/Library/Services/Compare Versions.workflow` and flushes the Services cache.
Then right-click any `.docx` or `.doc` in Finder and look under **Services** for
**Compare Versions**. Re-run the installer any time to reinstall it; you may need
`killall Finder` before a reinstall shows up.

It lands in the Services submenu rather than Quick Actions on macOS 26. Both run the same
thing, so this is cosmetic.

`workflowTypeIdentifier` in `document.wflow` must be exactly `com.apple.Automator.servicesMenu`.
Get it wrong and the failure is silent and misleading: the service still registers, `pbs
-dump_pboard` still lists it with the right file types, Automator still runs the action —
but Finder shows nothing. The valid identifiers are not documented anywhere on disk; the
Automator binary is a dyld shared-cache stub and Apple's own service bundles ship no
`document.wflow` to copy. They can be recovered with
`strings -a /System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e.01 | grep "^com\.apple\.Automator\."`.

It only offers itself on Word files — the service declares
`org.openxmlformats.wordprocessingml.document` and `com.microsoft.word.doc`, so it stays
out of the way on everything else.

The first run will ask permission for Automator to control System Events and Microsoft
Word. Both are needed: System Events shows the version picker, Word does the compare.
Expect the Word prompt to arrive late and quietly, after the picker — the compare is
blocked behind it while it waits, so if the first run seems to hang or reports
`AppleEvent timed out`, go find the prompt and click Allow, then run it again. Once
granted, it is granted for good.

That is the only prompt you should ever see. If Word starts asking for folder access on
every run, the staging directory has stopped being a fixed path — see below.

## What it does

1. Runs `git log --follow` on the file, so a document keeps its history through renames.
2. Lists every commit that touched it, newest first, as
   `Aug 26, 2026 — Services agreement: revisions from counsel review  [14d82b8, A. Lawyer]`.
   If the working copy differs from HEAD, "Working copy" is offered as well, at the top.
3. You select two. **The older one is the original**, so the redline reads forward in time
   no matter which order you click them.
4. Extracts both with `git show`, hands them to [wordcompare](../wordcompare/), and writes
   `<name>-COMPARE-<old>-vs-<new>.docx` next to the original, then opens it and reveals it
   in Finder.

A few seconds end to end on a 40-page agreement.

## Using it from the command line

`--list` prints the numbered versions and exits. `--pick N,M` takes two of those numbers
instead of showing the dialog, which is what makes the thing scriptable and testable:

```bash
gitcompare.sh Agreement.docx --list
gitcompare.sh Agreement.docx --pick 1,3
```

## Notes and limits

Only what is committed can be compared, so a document has to have been checked in at least
twice for this to be useful. Version granularity is commit granularity — several days of
edits landing in one "Check in outstanding work" commit are one version here.

**Rewriting history invalidates old redlines.** The commit SHA is baked into the output
filename, so if you amend or rebase, the SHAs in filenames from before the rewrite no
longer resolve. Regenerating is cheap; there is nothing to repair.

Versions are extracted to a temp directory, then staged in `~/.gitcompare/staging`, and the
redline is written there and moved into place afterwards by the shell.

**That location is the only one that satisfies all three constraints, and each one rules out
an obvious alternative:**

| Constraint | What it rules out |
| --- | --- |
| Word's sandbox must be able to open the files | `/var/folders` — Word will not reliably open there |
| The Finder service must be able to create the folder | Word's own container. An Automator service is *not permitted* to write into another app's container, and fails with `Operation not permitted`. A Terminal with Full Disk Access can, which makes this trivially easy to "verify" from the command line and still ship broken |
| The path must never change | Anything with `$$`, `mktemp`, or a per-document folder in it. Word grants folder access **per folder**, so a fresh path re-prompts on every single run |

A fixed hidden folder in the home directory meets all three: no TCC protection, so any process
can create it, and one Word grant covers it for good.

The folder is emptied between runs but never deleted and recreated. Word's grant attaches to
the directory, so removing it would trigger a fresh prompt every run — the same bug as a
per-run path, reached from a different direction.

The lesson generalises. The command line and the Finder service are different security
contexts, and the service is the one that matters. Test changes to staging or file access
through the actual right-click, not through the CLI.

In `--gui` mode every failure becomes a dialog, since nothing launched from Finder has a
stderr anyone will read.
