#!/usr/bin/env bash
# Installs the Transit ETA plugin into SwiftBar's plugin folder.
#
# Usage:
#   ./install.sh                      # uses SwiftBar's default plugin folder
#   ./install.sh /path/to/plugins     # or whatever you've set in SwiftBar
#
# Only transit-eta.10s.py itself is placed inside the Plugins folder.
# SwiftBar scans that folder recursively and tries to run every file it
# finds as its own plugin, so the transit_eta/ support package is instead
# installed to a sibling "TransitEtaLib" folder that SwiftBar never looks
# at, and the deployed script is rewritten to import from there.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/swiftbar_plugin"
DEST_DIR="${1:-$HOME/Library/Application Support/SwiftBar/Plugins}"
LIB_DIR="$(dirname "$DEST_DIR")/TransitEtaLib"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This installs a SwiftBar plugin, which only runs on macOS." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. macOS ships one at /usr/bin/python3; install Xcode Command Line Tools if missing." >&2
  exit 1
fi

# Clean up a previous install that (before this fix) copied transit_eta/
# straight into the Plugins folder, which SwiftBar then tried to run.
if [[ -d "$DEST_DIR/transit_eta" ]]; then
  echo "Removing stale transit_eta/ found inside $DEST_DIR (SwiftBar was treating its files as plugins)."
  rm -rf "$DEST_DIR/transit_eta"
fi

mkdir -p "$DEST_DIR" "$LIB_DIR"
rm -rf "$LIB_DIR/transit_eta"
cp -R "$SRC_DIR/transit_eta" "$LIB_DIR/"

sed "s|^TRANSIT_ETA_LIB_DIR = None.*|TRANSIT_ETA_LIB_DIR = r\"$LIB_DIR\"|" \
  "$SRC_DIR/transit-eta.10s.py" > "$DEST_DIR/transit-eta.10s.py"
chmod +x "$DEST_DIR/transit-eta.10s.py"

echo "Plugin installed to: $DEST_DIR/transit-eta.10s.py"
echo "Support library installed to: $LIB_DIR"
echo "If SwiftBar is running, refresh it (menu bar icon > Refresh All) or restart it."
echo "Then set your API key via the plugin's dropdown, or:"
echo "  export TRANSIT_ETA_API_KEY=... (and restart SwiftBar so it inherits the env var)"
