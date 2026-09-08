#!/usr/bin/env bash
# Installs the Transit ETA plugin into SwiftBar's plugin folder.
#
# Usage:
#   ./install.sh                      # uses SwiftBar's default plugin folder
#   ./install.sh /path/to/plugins     # or a custom one you've set in SwiftBar

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/swiftbar_plugin"
DEST_DIR="${1:-$HOME/Library/Application Support/SwiftBar/Plugins}"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This installs a SwiftBar plugin, which only runs on macOS." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. macOS ships one at /usr/bin/python3; install Xcode Command Line Tools if missing." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp -R "$SRC_DIR/transit_eta" "$DEST_DIR/"
cp "$SRC_DIR/transit-eta.10s.py" "$DEST_DIR/"
chmod +x "$DEST_DIR/transit-eta.10s.py"

echo "Installed to: $DEST_DIR"
echo "If SwiftBar is running, refresh it (menu bar icon > Refresh All) or restart it."
echo "Then set your API key via the plugin's dropdown, or:"
echo "  export TRANSIT_ETA_API_KEY=... (and restart SwiftBar so it inherits the env var)"
