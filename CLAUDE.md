# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A document-conversion project built around [Pandoc](https://pandoc.org/).
Two strands:

1. **Manual conversion** — turn Markdown into standalone, self-contained
   HTML/PDF with custom CSS. This is where the repo started; see `notes.txt`
   and `testfiles/`.
2. **Automated watcher (current direction)** — a macOS background process that
   watches `~/Documents` for new Markdown files, converts each to PDF via
   `pandoc`, and shows a native notification banner on success/failure.

The repository is still pre-code: `notes.txt` (working notes) plus a
`testfiles/` directory of sample inputs, rendered outputs, and candidate
stylesheets. No build system or test suite.

## Verified environment state

- `pandoc` 3.9.0.2 installed; `fswatch` 1.21.0 and `terminal-notifier` 2.0.0
  installed.
- **PDF pipeline works out of the box** — `echo "# test" | pandoc -o x.pdf`
  succeeds. The LaTeX engine (`pdflatex` from `basictex`) is installed at
  `~/.local/bin/pdflatex`. No alternate `--pdf-engine` needed.

## Conversion commands

```shell
# Markdown -> standalone HTML, CSS inlined so the file is fully portable
pandoc README.md -s --css pandoc2.css --embed-resources -o README-p2.html

# Markdown -> PDF (Pandoc's default LaTeX template)
pandoc input.md -s -V geometry:margin=1in -o output.pdf
```

`-s` (standalone) and `--embed-resources` (inline CSS/images into one portable
file) are the defining flags for HTML output.

## Watcher — `watch-and-convert.sh` (implemented & tested)

Built and verified end-to-end on 2026-05-17. Decisions made with the user:

1. **Trigger scope:** created **or** edited `.md` files (no event-type filter;
   any change to a top-level `.md` is a deduped conversion candidate).
2. **Recursion:** top level of `~/Documents` only — enforced by a
   `dirname == WATCH_DIR` guard, not just fswatch flags.
3. **Durability:** "quick" mode — `fswatch` script run in a terminal. A
   `launchd` LaunchAgent (survives reboot/logout) is the deliberate next step,
   **not yet done**.

Implementation notes:

- **Dual output:** each `FILE.md` → `FILE.pdf` (default LaTeX) **and**
  `FILE.html` (`-s --css $CSS --embed-resources`, self-contained). `CSS`
  defaults to `pandoc2.css` at the repo root (the script's dir), overridable
  via `PANDOC_CSS`; an absolute path so it resolves regardless of cwd.
  `--resource-path <doc dir>` lets relative image refs embed into both outputs.
  Notification reports which outputs were produced; one side failing →
  "Partial" (Basso), neither → "Failed".
- 2s fswatch latency coalesces save bursts; conversion is skipped only when
  **both** `.pdf` and `.html` are already newer than the `.md`, so a single
  save converts once.
- Skips removes, atomic-save temp files, and editor lock/backup files via
  `[ -f ]` + `*.md` matching.
- Written for macOS default bash 3.2 — no associative arrays.
- Notifier is built-in `osascript` `display notification` (`Glass` = success,
  `Basso` = failure), **not** `terminal-notifier`: the Homebrew
  terminal-notifier 2.0.0 binary silently no-ops on macOS Tahoe (verified
  2026-05-17, unmaintained since 2019). osascript notifications are attributed
  to **"Script Editor"** — that's the app to allow in System Settings →
  Notifications. notify() escapes `\` and `"` so filenames with quotes don't
  break the AppleScript. Conversions happen and are logged regardless.

## Project-specific decisions

- **`pandoc2.css` (now at the repo root) is the preferred stylesheet** and is
  what the watcher uses for HTML by default. `testfiles/github.css` looks good
  but needs wider margins; `testfiles/pandoc.css` is an earlier draft. Build
  new styling on `pandoc2.css`.
- **PDF output uses Pandoc's default LaTeX template** for now. A custom LaTeX
  template is a known future direction, not yet started.
- `testfiles/` holds parallel renderings of the same source (`README.md`) under
  different stylesheets (`-p`/`-p2` = pandoc CSS variants, `-g` = github.css)
  for visual comparison. Treat these as generated artifacts.
