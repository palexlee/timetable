#!/usr/bin/env bash
# Runs the test suite with only the standard library (no pip installs needed).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
PYTHONPATH="swiftbar_plugin" python3 -m unittest discover -s tests -v
