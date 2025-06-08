#!/bin/bash

echo "🔧 FloatingRecorder Security Fix"
echo "================================"
echo ""
echo "This script will remove the security warning from FloatingRecorder.app"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📂 Script location: $SCRIPT_DIR"

# Find the app bundle relative to script location
APP_PATH=""
if [ -f "$SCRIPT_DIR/FloatingRecorder.app/Contents/Info.plist" ]; then
    APP_PATH="$SCRIPT_DIR/FloatingRecorder.app"
elif [ -f "$SCRIPT_DIR/../FloatingRecorder.app/Contents/Info.plist" ]; then
    APP_PATH="$SCRIPT_DIR/../FloatingRecorder.app"
else
    # Try to find it in common locations
    for possible_path in \
        "$SCRIPT_DIR/FloatingRecorder.app" \
        "$SCRIPT_DIR/../FloatingRecorder.app" \
        "$(dirname "$SCRIPT_DIR")/FloatingRecorder.app" \
        "$(pwd)/FloatingRecorder.app"
    do
        if [ -f "$possible_path/Contents/Info.plist" ]; then
            APP_PATH="$possible_path"
            break
        fi
    done
fi

if [ -z "$APP_PATH" ]; then
    echo "❌ FloatingRecorder.app not found!"
    echo ""
    echo "Please make sure FloatingRecorder.app is in the same folder as this script."
    echo "Script is located at: $SCRIPT_DIR"
    echo ""
    echo "Looking for app in these locations:"
    echo "  • $SCRIPT_DIR/FloatingRecorder.app"
    echo "  • $SCRIPT_DIR/../FloatingRecorder.app"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

echo "📱 Found app at: $APP_PATH"
echo ""
echo "🔓 Removing security restrictions..."

# Remove quarantine attributes
xattr -cr "$APP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Security restrictions removed successfully!"
    echo ""
    echo "🎉 FloatingRecorder.app is now ready to use!"
    echo "You can double-click the app to run it normally."
else
    echo "❌ Failed to remove restrictions"
    echo "You may need to run this command manually:"
    echo "xattr -cr '$APP_PATH'"
fi

echo ""
read -p "Press Enter to close this window..." 