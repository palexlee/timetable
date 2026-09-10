#!/usr/bin/env bash
# Imports SBB icon SVGs (already downloaded+recolored to /tmp/sbb-icon-import)
# into TransitETAApp's asset catalog as tintable template images.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/TransitETAApp/Assets.xcassets"

# name:source pairs, not an associative array -- the system /bin/bash on
# macOS is 3.2 (pre-4.0, no `declare -A` support), so this must stay
# compatible with plain indexed arrays / word-splitting.
ICONS="
train-profile:train-profile-medium
tram-profile:tram-profile-medium
bus-profile:bus-profile-medium
underground-vehicule-profile:underground-vehicule-profile-medium
boat-profile:boat-profile-medium
cable-car-profile:cable-car-profile-medium
funicular-profile:funicular-profile-medium
station:station-small
magnifying-glass:magnifying-glass-small
key:key-small
circle-tick:circle-tick-small
circle-cross:circle-cross-small
chevron-left:chevron-left-small
platform:platform-small
"

for pair in $ICONS; do
  name="${pair%%:*}"
  source_name="${pair##*:}"
  src="/tmp/sbb-icon-import/${source_name}.svg"
  dest_dir="${name}.imageset"
  mkdir -p "$dest_dir"
  cp "$src" "$dest_dir/${name}.svg"
  cat > "$dest_dir/Contents.json" <<JSON
{
  "images": [
    { "filename": "${name}.svg", "idiom": "universal" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": {
    "template-rendering-intent": "template",
    "preserves-vector-representation": true
  }
}
JSON
  echo "imported $name"
done
