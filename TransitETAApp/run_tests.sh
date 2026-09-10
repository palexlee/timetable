#!/usr/bin/env bash
# Runs the Swift test suite via xcodebuild (no Xcode GUI needed).
set -euo pipefail
# xcode-select often points at Command Line Tools, which can't run xcodebuild
# test. Only a default -- an already-set DEVELOPER_DIR wins.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "${BASH_SOURCE[0]}")"
xcodebuild test \
  -project TransitETAApp.xcodeproj \
  -scheme TransitETAApp \
  -destination 'platform=macOS'
