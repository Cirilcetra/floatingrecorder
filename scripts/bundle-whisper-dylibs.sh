#!/usr/bin/env bash
# Copy whisper.cpp shared libraries next to the bundled `whisper` CLI and rewrite
# @rpath / build-machine paths → @loader_path so transcription works on any Mac
# (hardened runtime ignores DYLD_LIBRARY_PATH, so bundling + @loader_path is required).
#
# Prerequisites: local whisper.cpp checkout with an existing CMake build.
#   export WHISPER_CPP=/path/to/whisper.cpp   # optional; defaults to repo sibling or ./whisper.cpp
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/FloatingRecorder/Resources/whisper"
WHISPER_BIN="$DEST/whisper"

die() { printf '%s\n' "bundle-whisper-dylibs: $*" >&2; exit 1; }

[[ -f "$WHISPER_BIN" ]] || die "missing $WHISPER_BIN"

WHISPER_CPP="${WHISPER_CPP:-}"
if [[ -z "$WHISPER_CPP" ]]; then
  if [[ -d "$ROOT/whisper.cpp/build" ]]; then
    WHISPER_CPP="$ROOT/whisper.cpp"
  elif [[ -d "$ROOT/../whisper.cpp/build" ]]; then
    WHISPER_CPP="$(cd "$ROOT/.." && pwd)/whisper.cpp"
  else
    die "whisper.cpp build not found. Clone whisper.cpp, cmake --build, then set WHISPER_CPP=/path/to/whisper.cpp"
  fi
fi

BUILD_SRC="$WHISPER_CPP/build/src"
BUILD_GGML="$WHISPER_CPP/build/ggml/src"
[[ -f "$BUILD_SRC/libwhisper.1.7.5.dylib" ]] || [[ -f "$BUILD_SRC/libwhisper.1.dylib" ]] || die "missing libwhisper in $BUILD_SRC (run cmake build first)"

LIBWHISPER_SRC="$BUILD_SRC/libwhisper.1.7.5.dylib"
[[ -f "$LIBWHISPER_SRC" ]] || LIBWHISPER_SRC="$BUILD_SRC/libwhisper.1.dylib"

echo "Using WHISPER_CPP=$WHISPER_CPP"
echo "Bundling dylibs into $DEST"

cp -f "$LIBWHISPER_SRC" "$DEST/libwhisper.1.dylib"
cp -f "$BUILD_GGML/libggml.dylib" "$DEST/"
cp -f "$BUILD_GGML/libggml-cpu.dylib" "$DEST/"
cp -f "$BUILD_GGML/libggml-base.dylib" "$DEST/"
cp -f "$BUILD_GGML/ggml-blas/libggml-blas.dylib" "$DEST/"
cp -f "$BUILD_GGML/ggml-metal/libggml-metal.dylib" "$DEST/"

LIBS=(
  libwhisper.1.dylib
  libggml.dylib
  libggml-cpu.dylib
  libggml-base.dylib
  libggml-blas.dylib
  libggml-metal.dylib
)

patch_install_names() {
  local f="$1"
  local base="$2"
  install_name_tool -id "@loader_path/$base" "$f"
  for lib in "${LIBS[@]}"; do
    install_name_tool -change "@rpath/$lib" "@loader_path/$lib" "$f" 2>/dev/null || true
  done
}

for lib in "${LIBS[@]}"; do
  patch_install_names "$DEST/$lib" "$lib"
done

# Strip absolute LC_RPATH entries from the whisper CLI, then point deps at the dylibs folder.
while otool -l "$WHISPER_BIN" | grep -q 'cmd LC_RPATH'; do
  rp=$(otool -l "$WHISPER_BIN" | sed -n 's/^[[:space:]]*path \(.*\) (offset.*/\1/p' | head -n1)
  [[ -z "$rp" ]] && break
  install_name_tool -delete_rpath "$rp" "$WHISPER_BIN"
done

for lib in "${LIBS[@]}"; do
  install_name_tool -change "@rpath/$lib" "@loader_path/$lib" "$WHISPER_BIN" 2>/dev/null || true
done

chmod +x "$WHISPER_BIN"
chmod 644 "$DEST/"*.dylib 2>/dev/null || true

echo "Verifying whisper loads (otool first line / self):"
otool -L "$WHISPER_BIN" | head -n 8

if ! "$WHISPER_BIN" --help >/dev/null 2>&1; then
  die "'$WHISPER_BIN --help' failed — otool/LC_RPATH may still be wrong. Try: otool -L $WHISPER_BIN"
fi

echo "OK: whisper --help succeeded"
