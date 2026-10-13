#!/bin/zsh
# Copies the files the website shares with the Mac app into web/.
# Run after changing the bundled players or the app icon; web/tests fails if they drift.
set -euo pipefail
cd "$(dirname "$0")/.."
cp Sources/SoccerCore/Resources/players.csv web/players.csv
sips -Z 256 Assets/AppIcon.png --out web/icon.png >/dev/null
echo "Synced web/players.csv and web/icon.png"
