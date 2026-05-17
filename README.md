# Automatic Markdown to HTML and PDF

This is a simple project to watch my Documents folder and automatically create
PDF and HTML versions of any new or updated Markdown files.

My use case: I have a few long-running Claude Code skills that produce Markdown
files as their output. Rather than burdening the AI tool with creating a couple
different formats, I created this watcher script to do it in the background.

The implementation uses the [Pandoc universal document converter][pandoc] and is
built for macOS. (It could be adapted to other platforms.)

My idea - Claude's code.

## watch-and-convert.sh

Watches the **top level** of `~/Documents`. Any `.md` file that is **created
or edited** is converted to a sibling `.pdf` _and_ a self-contained `.html`
(stylesheet and images embedded) via `pandoc`. A native notification reports
success (`Glass` sound) or failure/partial (`Basso` sound). Subfolders are not
watched.

The HTML stylesheet is `pandoc2.css` (repo root, alongside the script).
Override it with the `PANDOC_CSS` env var (must be an existing file). Relative
image references in a document are resolved against that document's folder via
`--resource-path`, so they get embedded into both outputs.

### Run

```shell
./watch-and-convert.sh        # runs in the foreground; Ctrl-C to stop
```

Override the watched directory with the `WATCH_DIR` env var if needed.

This is the "quick" mode — it runs only while the terminal/process is alive.
Making it survive logout/reboot (a `launchd` LaunchAgent) is a deliberate
future step, not yet done.

### Requirements

```shell
brew install pandoc fswatch
pandoc --version

brew install --cask basictex
# link pdflatex to a location already in my PATH
ln -s -v /Library/TeX/texbin/pdflatex ~/.local/bin/pdflatex
pdflatex --version
```

### macOS notification permission

Notifications use the built-in `osascript` (`display notification`), so there
is no notifier to install. **Notifications are attributed to "Script Editor"**,
not "terminal-notifier" — grant/allow notifications for **Script Editor** in
System Settings → Notifications if banners don't appear.

Conversions still happen even if notifications are blocked — the script also
logs each result to stdout.

### Behavior notes

- A burst of filesystem events from a single save is coalesced (2s latency)
  and de-duplicated: it is skipped only when **both** the `.pdf` and `.html`
  are already newer than the `.md`.
- If only one of the two conversions fails, the other is still written and the
  notification says "Partial (only PDF/HTML)".
- Editor temp/lock files (atomic-save temp files, `.#name.md` symlinks,
  `name.md~` backups, `.swp`) do not trigger conversion.
- pandoc errors are printed to stderr and surfaced in a failure notification;
  the source file is left as-is.
- Todo: set this up to run with `launchd` to avoid the need for the watcher
  script always running

[pandoc]: https://pandoc.org/
