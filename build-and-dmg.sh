#!/usr/bin/env bash
# Build FloatingRecorder, ad-hoc sign it, and produce a distributable DMG.
# Usage: ./build-and-dmg.sh
#
# Notes:
# - Uses ad-hoc signing ("-") because we don't have an Apple Developer ID.
#   Users will need to allow the app once via System Settings -> Privacy & Security.
#   See docs/INSTALL.md for the user-facing instructions shipped alongside the DMG.

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="FloatingRecorder"
DMG_NAME="FloatingRecorder"
RELEASE_BIN=".build/release/FloatingRecorder"
STAGING_DIR="build/dmg-staging"
OUTPUT_DIR="build/output"
RESOURCES="FloatingRecorder/Resources"
ENTITLEMENTS="Build/entitlements.plist"
WHISPER_ENTITLEMENTS="Build/whisper-cli-entitlements.plist"
INFO_PLIST="Build/Info.plist"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "\033[33m!\033[0m %s\n" "$1"; }
die()  { printf "\033[31m✗\033[0m %s\n" "$1"; exit 1; }

# ----------------------------------------------------------------------
bold "▶ Preflight"

command -v swift    >/dev/null || die "swift not found"
command -v codesign >/dev/null || die "codesign not found"
command -v hdiutil  >/dev/null || die "hdiutil not found"
command -v shasum   >/dev/null || die "shasum not found"

[[ -f "$ENTITLEMENTS" ]] || die "Missing $ENTITLEMENTS"
[[ -f "$WHISPER_ENTITLEMENTS" ]] || die "Missing $WHISPER_ENTITLEMENTS"
[[ -f "$INFO_PLIST"   ]] || die "Missing $INFO_PLIST"

# ----------------------------------------------------------------------
bold "▶ Checking bundled whisper resources"

if [[ ! -d "$RESOURCES/whisper" ]]; then
  mkdir -p "$RESOURCES/whisper"
fi

if [[ ! -f "$RESOURCES/whisper/whisper" ]]; then
  die "Missing $RESOURCES/whisper/whisper — build it from whisper.cpp first"
fi

# whisper.cpp is often built with shared libs + absolute LC_RPATHs; ship dylibs next to the CLI.
if otool -l "$RESOURCES/whisper/whisper" 2>/dev/null | sed -n 's/^[[:space:]]*path \(.*\) (offset.*/\1/p' | grep -qE '(whisper\.cpp/build|/Users/|/home/)'; then
  if [[ -x "scripts/bundle-whisper-dylibs.sh" ]] && [[ -d "whisper.cpp/build" ]]; then
    bold "▶ Bundling whisper shared libraries (fixing @rpath for distribution)"
    ./scripts/bundle-whisper-dylibs.sh
    ok "Whisper dylibs bundled"
  else
    die "The bundled whisper still references a local whisper.cpp build path. Clone/build whisper.cpp in ./whisper.cpp then run: ./scripts/bundle-whisper-dylibs.sh (or set WHISPER_CPP=...)"
  fi
fi

# At least one model must be bundled so the app works on first launch
HAS_MODEL=0
for m in ggml-tiny.en.bin ggml-base.en.bin; do
  if [[ -f "$RESOURCES/whisper/$m" ]]; then
    HAS_MODEL=1
    ok "Bundled model present: $m"
  fi
done
[[ $HAS_MODEL -eq 1 ]] || die "No bundled ggml model under $RESOURCES/whisper/ — add ggml-tiny.en.bin or ggml-base.en.bin"

# ----------------------------------------------------------------------
bold "▶ Building release binary"

swift build -c release
[[ -f "$RELEASE_BIN" ]] || die "Build failed: $RELEASE_BIN not found"
ok "Built $RELEASE_BIN"

# ----------------------------------------------------------------------
bold "▶ Assembling app bundle"

rm -rf "$STAGING_DIR"
APP_DIR="$STAGING_DIR/${APP_NAME}.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$RELEASE_BIN"    "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST"     "$APP_DIR/Contents/Info.plist"
cp -R "$RESOURCES/"* "$APP_DIR/Contents/Resources/"

# Copy the existing app icon if we have one
if [[ -f "FloatingRecorder.app/Contents/Resources/appicon.icns" ]]; then
  cp "FloatingRecorder.app/Contents/Resources/appicon.icns" "$APP_DIR/Contents/Resources/"
  ok "Copied appicon.icns"
fi

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/Resources/whisper/whisper"
shopt -s nullglob
for dylib in "$APP_DIR/Contents/Resources/whisper/"*.dylib; do
  chmod 644 "$dylib" || true
done
shopt -u nullglob

# ----------------------------------------------------------------------
bold "▶ Ad-hoc signing"

# Sign nested dylibs (plain ad-hoc — no hardened runtime on dylibs).
# The whisper CLI uses separate entitlements with disable-library-validation so
# ad-hoc Team IDs across whisper + dylibs do not trip dyld (see README).
shopt -s nullglob
for dylib in "$APP_DIR/Contents/Resources/whisper/"*.dylib; do
  codesign --force --timestamp=none --sign - "$dylib"
done
shopt -u nullglob

codesign --force --timestamp=none --sign - \
  --options runtime \
  --entitlements "$WHISPER_ENTITLEMENTS" \
  "$APP_DIR/Contents/Resources/whisper/whisper"

codesign --force --timestamp=none --sign - \
  --options runtime \
  --entitlements "$ENTITLEMENTS" \
  "$APP_DIR/Contents/MacOS/$APP_NAME"

# Do not use --deep here: it would re-sign Resources/whisper/whisper with the main
# app entitlements and strip com.apple.security.cs.disable-library-validation, breaking dyld.
codesign --force --timestamp=none --sign - \
  --options runtime \
  --entitlements "$ENTITLEMENTS" \
  "$APP_DIR"

codesign --verify --deep --strict "$APP_DIR" || die "Signature verification failed"
ok "Signed $APP_DIR"

# ----------------------------------------------------------------------
bold "▶ Creating DMG"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/${DMG_NAME}.dmg"

# Applications symlink so users can drag to install
ln -sfh /Applications "$STAGING_DIR/Applications"

# Ship the 'Fix Security Warning' helper script if present
if [[ -f "Fix Security Warning.command" ]]; then
  cp "Fix Security Warning.command" "$STAGING_DIR/"
  chmod +x "$STAGING_DIR/Fix Security Warning.command"
fi

# Ship the user-facing install guide
if [[ -f "docs/INSTALL.md" ]]; then
  cp "docs/INSTALL.md" "$STAGING_DIR/README.txt"
fi

hdiutil create \
  -volname "$DMG_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_DIR/${DMG_NAME}.dmg" >/dev/null

ok "DMG created: $OUTPUT_DIR/${DMG_NAME}.dmg"

# ----------------------------------------------------------------------
bold "▶ Checksums"

(cd "$OUTPUT_DIR" && shasum -a 256 "${DMG_NAME}.dmg" | tee "${DMG_NAME}.dmg.sha256")

# ----------------------------------------------------------------------
bold "▶ Copying .app next to the DMG for convenience"
rm -rf "$OUTPUT_DIR/${APP_NAME}.app"
cp -R "$APP_DIR" "$OUTPUT_DIR/"

ok "All done"
echo ""
echo "  App bundle : $OUTPUT_DIR/${APP_NAME}.app"
echo "  DMG        : $OUTPUT_DIR/${DMG_NAME}.dmg"
echo "  Checksum   : $OUTPUT_DIR/${DMG_NAME}.dmg.sha256"
echo ""
echo "  Distribute the DMG and link users to docs/INSTALL.md for first-launch instructions."
