#!/bin/zsh
# Builds "What Soccer Player Are Ya.app" into ./build.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/What Soccer Player Are Ya.app"
swift build -c release --product WhatSoccerPlayerAreYa
BIN="$(swift build -c release --show-bin-path)/WhatSoccerPlayerAreYa"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/What Soccer Player Are Ya"
cp Sources/SoccerCore/Resources/players.csv "$APP/Contents/Resources/players.csv"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>What Soccer Player Are Ya</string>
    <key>CFBundleDisplayName</key><string>What Soccer Player Are Ya</string>
    <key>CFBundleIdentifier</key><string>com.amalmehta.WhatSoccerPlayerAreYa</string>
    <key>CFBundleExecutable</key><string>What Soccer Player Are Ya</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.entertainment</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
