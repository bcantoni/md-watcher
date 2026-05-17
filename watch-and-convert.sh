#!/usr/bin/env bash
#
# watch-and-convert.sh — watch ~/Documents for new or edited Markdown files
# and convert each to BOTH PDF and styled HTML with pandoc, then post a
# macOS notification.
#
# Scope (decided 2026-05-17):
#   - Triggers on created OR edited .md files (any change to a top-level .md).
#   - Top level of ~/Documents only — subfolders are NOT watched.
#   - Each FILE.md -> FILE.pdf and FILE.html (self-contained, CSS embedded).
#   - "Quick" mode: run this in a terminal. Ctrl-C to stop. (No launchd yet.)
#
# Usage:  ./watch-and-convert.sh
#   PANDOC_CSS=/path/to/other.css ./watch-and-convert.sh   # override stylesheet
#
set -u

WATCH_DIR="${WATCH_DIR:-$HOME/Documents}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# HTML stylesheet (absolute, so it resolves no matter the working directory).
CSS="${PANDOC_CSS:-$SCRIPT_DIR/pandoc2.css}"

# --- preflight ------------------------------------------------------------
for bin in fswatch pandoc osascript; do
    command -v "$bin" >/dev/null 2>&1 || {
        echo "error: '$bin' not found on PATH" >&2
        exit 1
    }
done
[ -d "$WATCH_DIR" ] || { echo "error: '$WATCH_DIR' is not a directory" >&2; exit 1; }
[ -f "$CSS" ] || { echo "error: CSS not found: $CSS (set PANDOC_CSS to override)" >&2; exit 1; }

notify() {  # title, message, sound-name (a name in /System/Library/Sounds)
    # osascript, NOT terminal-notifier: the Homebrew terminal-notifier 2.0.0
    # binary silently no-ops on macOS Tahoe (unmaintained since 2019). Custom
    # osacompile applets are silently blocked too (ad-hoc signed, never
    # registered for notifications), so a clickable/actionable notification is
    # not feasible here without Developer-ID signing. osascript (attributed to
    # the pre-authorized "Script Editor") is the only path that works on this
    # macOS, and it is informational only — no click action.
    local title msg
    title=${1//\\/\\\\}; title=${title//\"/\\\"}
    msg=${2//\\/\\\\};   msg=${msg//\"/\\\"}
    osascript -e "display notification \"$msg\" with title \"$title\" sound name \"$3\"" >/dev/null 2>&1 || true
}

convert() {
    local src="$1"
    local dir base name pdf html made ok
    dir=$(dirname "$src")          # --resource-path: resolve images the doc
    base="${src%.md}"              #   references relatively (else not embedded)
    name=$(basename "$base")
    pdf="$base.pdf"
    html="$base.html"

    # Dedup fswatch event bursts: skip only if BOTH outputs are already newer
    # than the source (a single save fires created+modified).
    if [ -f "$pdf" ] && [ "$pdf" -nt "$src" ] \
       && [ -f "$html" ] && [ "$html" -nt "$src" ]; then
        return
    fi

    made=""; ok=1
    if pandoc "$src" --resource-path "$dir" -o "$pdf" 2>/tmp/pandoc-watcher.err; then
        made="PDF"
    else
        ok=0
        echo "[$(date '+%H:%M:%S')] PDF FAILED: $src" >&2
        sed 's/^/    /' /tmp/pandoc-watcher.err >&2
    fi
    if pandoc "$src" -s --css "$CSS" --embed-resources --resource-path "$dir" \
              -o "$html" 2>/tmp/pandoc-watcher.err; then
        made="${made:+$made + }HTML"
    else
        ok=0
        echo "[$(date '+%H:%M:%S')] HTML FAILED: $src" >&2
        sed 's/^/    /' /tmp/pandoc-watcher.err >&2
    fi

    if [ "$ok" -eq 1 ]; then
        echo "[$(date '+%H:%M:%S')] converted: $src -> $made"
        notify "Pandoc Watcher" "Converted: $name ($made)" Glass
    elif [ -n "$made" ]; then
        echo "[$(date '+%H:%M:%S')] partial: $src -> $made only" >&2
        notify "Pandoc Watcher" "Partial: $name (only $made)" Basso
    else
        echo "[$(date '+%H:%M:%S')] FAILED: $src (no output)" >&2
        notify "Pandoc Watcher" "Failed: $name" Basso
    fi
}

echo "Watching $WATCH_DIR (top level only) for *.md -> PDF + HTML — Ctrl-C to stop."

# -0: null-separated paths (safe for spaces/newlines), paired with read -d ''.
# --latency 2: coalesce rapid event bursts from a single save.
# No -r and no --event filter: any change to a top-level .md is a candidate;
# the loop below enforces top-level-only and skips deleted/temp files.
fswatch -0 --latency 2 "$WATCH_DIR" | while IFS= read -r -d '' path; do
    case "$path" in
        *.md) ;;
        *)    continue ;;
    esac
    # top level only: parent directory must be exactly WATCH_DIR
    [ "$(dirname "$path")" = "$WATCH_DIR" ] || continue
    # must be an existing regular file (skips removes, atomic-save temp files,
    # editor lock symlinks like .#name.md)
    [ -f "$path" ] || continue

    convert "$path"
done
