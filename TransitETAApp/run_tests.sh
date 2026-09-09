#!/usr/bin/env bash
# Runs the Swift test suite via xcodebuild (no Xcode GUI needed).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
xcodebuild test \
  -project TransitETAApp.xcodeproj \
  -scheme TransitETAApp \
  -destination 'platform=macOS'
