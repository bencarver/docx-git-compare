# wordcompare

Drives Microsoft Word's own Compare (Legal Blackline) from the command line on macOS.

```bash
wordcompare.sh ORIGINAL.docx REVISED.docx [OUTPUT.docx] [-a "Author Name"] [--keep-open]
```

Defaults the author to your `git config user.name` and, if no output path is given, writes
`<revised>-WORDCOMPARE.docx` alongside the revised file. Prints the insertion and
deletion counts and the revision authors so you can confirm it worked.

## The thing that makes it work

Word's AppleScript `compare` verb has to be addressed to a document by **name or index**.
Passing the value returned by `open file name ...` fails with `-1708`
("doesn't understand the compare message"), which is what makes this look impossible.

Works:

```applescript
tell document "Original.docx" to compare path "/abs/path/Revised.docx" ¬
    author name "A. Lawyer" target compare target new
```

Fails:

```applescript
set o to open file name "/abs/path/Original.docx"
compare o path "/abs/path/Revised.docx"        -- error -1708
```

Absolute paths are required. The script converts whatever you pass.

## Why use this over python-redlines

Both produce genuine Word tracked changes. They differ in how they group edits.

| | python-redlines (OOXML PowerTools) | Word compare |
| --- | --- | --- |
| Same 40-page services agreement | 184 insertions, 119 deletions | 140 insertions, 103 deletions |
| Grouping | word level, so rewritten clauses fragment | coarser, reads more like a human redline |
| Runs headless | yes | no, needs Word on a Mac |

Use python-redlines in scripts and pipelines. Use this when a human has to read the
result, particularly where whole clauses were rewritten.

## Caveats

Word must be installed and will be launched. Tested against Word 16.111.3 on macOS.

The first run on a given Mac fails with `-1712 (AppleEvent timed out)`. That is not a slow
compare — macOS has put up an "allow this to control Microsoft Word" permission prompt, and
the AppleEvent sits blocked behind it until the default 120-second timeout expires. Grant
it and run again. The script now wraps the Word block in `with timeout of 900 seconds`
(`--timeout SECONDS` changes it), which gives you time to find the prompt and click Allow.

The script closes the documents it opens; pass `--keep-open` to leave the comparison
on screen instead. If Word is sandboxed away from a location, move the files somewhere
under your home directory first.
