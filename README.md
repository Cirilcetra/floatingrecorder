# FloatingRecorder

A floating audio recorder with real-time transcription for macOS.

![FloatingRecorder](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## 🚀 Quick Start

**Just want to use the app?**

1. **Download this repository** (Code → Download ZIP)
2. **Extract the ZIP file**
3. **Double-click `FloatingRecorder.app`** to run
4. **If you see a security warning**: Right-click → Open → Confirm

That's it! The app is ready to use.

## ✨ Features

- 🎙️ **Floating Audio Recorder** - Always accessible recording interface
- 🤖 **Real-time Transcription** - Powered by Whisper.cpp AI
- ⌨️ **Global Hotkeys** - Record from anywhere on your Mac
- 📋 **Auto-paste** - Automatically paste transcriptions to active apps
- 💾 **Audio Storage** - Saves recordings to "FloatingRecorder Transcriptions" folder
- 🎯 **Lightweight** - Self-contained with no external dependencies

## 🔧 System Requirements

- macOS 14.0 (Sonoma) or later
- Microphone access permission
- ~150MB disk space

## 📱 How to Use

1. **Launch** FloatingRecorder.app
2. **Grant microphone permission** when prompted
3. **Click the record button** or use global hotkey
4. **Speak** - transcription appears in real-time
5. **Stop recording** - text is automatically copied and can be pasted

## 🛠️ For Developers

This is a SwiftUI application that bundles:
- **Whisper.cpp** for AI transcription
- **HotKey library** for global shortcuts
- **Complete model** (ggml-base.en.bin) included

### Build from Source
```bash
swift build -c release
```

### Project Structure
- `FloatingRecorder/` - Swift source code
- `FloatingRecorder.app/` - Ready-to-run application
- `whisper.cpp/` - Whisper AI engine
- `Package.swift` - Swift Package Manager configuration

## 🔒 Security Note

This app is not notarized by Apple (requires $99/year developer account). When you first open it:

1. **Right-click** on FloatingRecorder.app
2. **Select "Open"**
3. **Click "Open"** in the security dialog

This is normal for open-source Mac apps and only needs to be done once.

## 📁 What Gets Installed

- App runs from anywhere (no installation to Applications required)
- Audio recordings saved to: `~/Documents/FloatingRecorder Transcriptions/`
- No other files or system changes

## 🗑️ Uninstall

Simply delete the `FloatingRecorder.app` file. No other cleanup needed.

## 📝 License

This project includes:
- **FloatingRecorder** - Original application code
- **Whisper.cpp** - MIT License
- **HotKey** - MIT License

## 💬 Support

If you encounter any issues:
1. Check that microphone permissions are granted
2. Verify you're running macOS 14.0+
3. Try the security steps above if the app won't open

---

**Ready to use?** Just download this repository and run `FloatingRecorder.app`! 