#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
package="$root/macos"
version="$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$root/Directory.Build.props")"
stage="$root/artifacts/macos"
app="$stage/Move.app"
dmg="$root/artifacts/installer/Move-$version-macOS.dmg"

rm -rf "$stage" "$dmg"
for arch in arm64 x86_64; do
    swift build --package-path "$package" -c release --triple "$arch-apple-macosx14.0"
done

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$(dirname "$dmg")"
lipo -create \
    "$package/.build/arm64-apple-macosx/release/Move" \
    "$package/.build/x86_64-apple-macosx/release/Move" \
    -output "$app/Contents/MacOS/Move"
cp "$package/Resources/AppIcon.icns" "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Move</string>
    <key>CFBundleDisplayName</key>
    <string>Move</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.berkpolatCE.Move</string>
    <key>CFBundleExecutable</key>
    <string>Move</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Berk Polat. MIT License.</string>
</dict>
</plist>
EOF
codesign --force --sign - "$app"

ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname Move -srcfolder "$stage" -format UDZO "$dmg"
rm "$stage/Applications"

ls -l "$dmg"
