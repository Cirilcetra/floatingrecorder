#!/bin/bash
# Removes the macOS quarantine attribute from FloatingRecorder.app so it can
# launch without the "cannot be opened" warning. Safe to run multiple times.

set -e

echo "🔧  FloatingRecorder — Security Fix"
echo "====================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CANDIDATES=(
    "$SCRIPT_DIR/FloatingRecorder.app"
    "/Applications/FloatingRecorder.app"
    "$HOME/Applications/FloatingRecorder.app"
)

APP_PATH=""
for p in "${CANDIDATES[@]}"; do
    if [ -d "$p" ]; then
        APP_PATH="$p"
        break
    fi
done

if [ -z "$APP_PATH" ]; then
    echo "❌  FloatingRecorder.app not found."
    echo ""
    echo "    Searched:"
    for p in "${CANDIDATES[@]}"; do echo "      • $p"; done
    echo ""
    echo "    Drag FloatingRecorder.app into /Applications first, then run this script."
    echo ""
    read -p "Press Enter to close..."
    exit 1
fi

echo "📦  Found app: $APP_PATH"
echo "🔓  Clearing quarantine attributes..."
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true

echo ""
echo "✅  Done. You can now open FloatingRecorder normally."
echo ""
read -p "Press Enter to close..."
