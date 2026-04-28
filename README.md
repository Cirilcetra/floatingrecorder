# FloatingRecorder

A floating, hotkey-driven voice-to-text recorder for macOS. Runs entirely
on-device using Whisper.cpp — no cloud, no telemetry, no account.

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

---

## Install

1. Download **FloatingRecorder.dmg** from the latest release.
2. Open the DMG and drag **FloatingRecorder.app** to **Applications**.
3. The first time you launch it, macOS will show a security warning — see
   [docs/INSTALL.md](docs/INSTALL.md) for the one-time allow step in System
   Settings. It takes about 20 seconds.
4. Grant microphone and Accessibility permissions when prompted (onboarding
   walks you through it).

That's it.

---

## Website

A marketing landing page (Next.js) lives in [`website/`](website/). It explains features, first-run **Privacy & Security → Open anyway**, and permission steps. See [`website/README.md`](website/README.md) for how to run and build it.

---

## How it works

- **Tap ⌥⌘** (Option + Command) → toggles the floating recorder on/off.
- **Hold ⌥⌘** → push-to-talk: records while held, releases to transcribe
  and auto-paste into the focused text field (falls back to clipboard if no
  text field is focused).
- Menu-bar icon gives you: toggle, active model, preferences, and quit.

### Features

- Local Whisper transcription — nothing leaves your Mac.
- Tap-to-toggle **and** push-to-talk in one hotkey.
- Smart auto-paste: activates the app you were using and pastes into the
  focused text field via the Accessibility API.
- On-demand model manager: download Tiny / Base / Small / Medium / Large v3
  straight from the app.
- Live permission status for Microphone and Accessibility.
- Full transcription history with search.

---

## Build from source

Requirements: macOS 14+, Swift 5.9, Xcode command line tools.

```bash
# Build a debug binary (fast iteration)
swift build

# Build a release bundle + a distributable DMG
./build-and-dmg.sh
```

**Whisper “Library not loaded” / `dyld` errors:** the bundled `whisper` CLI is
usually linked to `libggml*.dylib` and `libwhisper*.dylib`. Those libraries must
live **next to** `whisper` in `FloatingRecorder/Resources/whisper/` with
`@loader_path` (not hard-coded paths into your `whisper.cpp/build` folder). Run
`./scripts/bundle-whisper-dylibs.sh` once after building whisper.cpp; `build-and-dmg.sh`
does this automatically when it sees stale RPATHs and `./whisper.cpp/build` exists.

**“different Team IDs” when loading `libwhisper`:** ad-hoc signing assigns a unique
anonymous team to each binary; the bundled `whisper` tool is signed with
`com.apple.security.cs.disable-library-validation` so it may load those dylibs.
Rebuild with the current `build-and-dmg.sh` (do not strip that step).

Outputs land in `build/output/`:

- `FloatingRecorder.app` — the signed app bundle
- `FloatingRecorder.dmg` — the distributable disk image
- `FloatingRecorder.dmg.sha256` — SHA-256 checksum

Before running `build-and-dmg.sh` you need the Whisper binary and at least
one ggml model under `FloatingRecorder/Resources/whisper/`:

```
FloatingRecorder/Resources/whisper/
├── whisper               # whisper.cpp CLI binary
└── ggml-base.en.bin      # or ggml-tiny.en.bin — the bundled default model
```

Additional models are downloaded on demand from
[huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp)
through the in-app model manager.

---

## Project layout

```
FloatingRecorder/
├── FloatingRecorderApp.swift   – app delegate, menu bar, windows
├── HotkeyEngine.swift          – CGEventTap-based tap/hold hotkey
├── AudioRecorder.swift         – AVAudioEngine input + level metering
├── WhisperTranscriber.swift    – whisper.cpp process + smart auto-paste
├── ModelManager.swift          – on-demand model download / verify
├── AppPreferences.swift        – UserDefaults-backed settings
├── FloatingRecorderView.swift  – the floating pill UI
├── MainAppView.swift           – Preferences + History windows
├── OnboardingView.swift        – first-run permission walkthrough
└── Resources/                  – bundled whisper binary + default model
```

---

## Where things are stored

| What                 | Where                                                       |
| -------------------- | ----------------------------------------------------------- |
| Downloaded models    | `~/Library/Application Support/FloatingRecorder/models/`    |
| Saved transcriptions | the folder you pick in Preferences (default: `~/Documents`) |
| Settings             | `UserDefaults` (standard macOS preferences)                 |
| Audio recordings     | written to `/tmp`, deleted after transcription              |

---

## Licenses

- FloatingRecorder — app code (see LICENSE if present)
- Whisper.cpp — MIT

---

## Troubleshooting

See [docs/INSTALL.md](docs/INSTALL.md) for the security-warning fix,
the one-click `Fix Security Warning.command` helper included in the DMG,
and permission walkthroughs.
  