#!/bin/zsh
set -euo pipefail
here=${0:A:h}
stage="$here/ffmpeg-stage"
app="$here/build/Audio to Apple Music.app"
contents="$app/Contents"
iconset="$here/build/AppIcon.iconset"

if [[ ! -x "$stage/bin/ffmpeg" || ! -x "$stage/bin/ffprobe" ]]; then
  print "Bundled FFmpeg tools are missing. Run Build Bundled FFmpeg.command first."
  exit 1
fi

rm -rf "$app" "$iconset"
mkdir -p "$contents/MacOS" "$contents/Resources" "$iconset"

swift "$here/AppIcon.swift" "$iconset"
iconutil -c icns -o "$here/AppIcon.icns" "$iconset"
cp "$here/AppIcon.icns" "$contents/Resources/AppIcon.icns"

cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AudioToMusic</string>
<key>CFBundleIdentifier</key><string>local.codex.audiotoapplemusic</string>
<key>CFBundleName</key><string>Audio to Apple Music</string>
<key>CFBundleDisplayName</key><string>Audio to Apple Music</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleShortVersionString</key><string>2.0.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSAppleEventsUsageDescription</key><string>Add converted local audio files to your Apple Music library and verify their file location.</string>
<key>LSApplicationCategoryType</key><string>public.app-category.music</string>
</dict></plist>
PLIST

swiftc -parse-as-library -O -target arm64-apple-macosx14.0 -sdk "$(xcrun --show-sdk-path)" -framework AppKit "$here/AudioToMusicApp.swift" -o "$contents/MacOS/AudioToMusic"
cp "$stage/bin/ffmpeg" "$contents/Resources/ffmpeg"
cp "$stage/bin/ffprobe" "$contents/Resources/ffprobe"
cp "$here/COPYING.LGPLv2.1" "$contents/Resources/FFmpeg-LGPLv2.1.txt"
cp "$here/ffmpeg-9.0.2.tar.xz" "$contents/Resources/FFmpeg-9.0.2-Source.tar.xz"
chmod 755 "$contents/Resources/ffmpeg" "$contents/Resources/ffprobe"
codesign --force --sign - "$contents/Resources/ffmpeg"
codesign --force --sign - "$contents/Resources/ffprobe"
codesign --force --deep --sign - "$app"

staging="$here/package-root"
mkdir -p "$staging/Applications"
rm -rf "$staging/Applications/FLAC to Apple Music.app"
rm -rf "$staging/Applications/Audio to Apple Music.app"
COPYFILE_DISABLE=1 ditto --norsrc "$app" "$staging/Applications/Audio to Apple Music.app"
pkgbuild --root "$staging" --identifier local.codex.audiotoapplemusic.pkg --version 2.0.1 --install-location / "$here/Audio to Apple Music.pkg"
open -R "$here/Audio to Apple Music.pkg"
