# Installing FloatingRecorder

FloatingRecorder is distributed as a signed (ad-hoc) DMG. Because it isn't
notarized by Apple, macOS will show a one-time security warning the first time
you run it. Here's exactly how to install and allow it.

---

## 1. Download and open the DMG

1. Download `FloatingRecorder.dmg` from the website.
2. Double-click the DMG to open it.
3. Drag **FloatingRecorder.app** onto the **Applications** folder shortcut.

That's the install done. Now to run it for the first time.

---

## 2. First launch — allow the app in System Settings

When you first double-click FloatingRecorder in **Applications**, macOS may
show a dialog like:

> **"FloatingRecorder" cannot be opened because Apple cannot check it for malicious software.**

Or on older macOS:

> **"FloatingRecorder" is damaged and can't be opened.**

This is expected for indie macOS apps that aren't paying Apple's $99/yr
notarization fee. The app is safe — the source code is open. Here's how to
allow it:

### The easy way (macOS 15 Sequoia and later)

1. Try to open **FloatingRecorder.app** once. Dismiss the warning.
2. Open **System Settings** → **Privacy & Security**.
3. Scroll down to the **Security** section. You'll see:
   > "FloatingRecorder" was blocked to protect your Mac.
4. Click **Open Anyway**.
5. Confirm with Touch ID / your password.
6. The app launches — you'll see the microphone icon appear in your menu bar.

### Alternative: right-click → Open

1. Open **Applications**.
2. **Right-click** (or Control-click) **FloatingRecorder.app**.
3. Choose **Open** from the menu.
4. You'll get the same warning, but this time with an **Open** button — click it.
5. Confirm with Touch ID / your password.

### If the app says "is damaged"

This can happen if macOS stripped the quarantine attribute weirdly. Fix it in
one of two ways:

**Option A — double-click the helper script** included in the DMG:

- `Fix Security Warning.command`
- Double-click it; it will prompt for your password and unblock the app.

**Option B — one line in Terminal:**

```bash
xattr -dr com.apple.quarantine /Applications/FloatingRecorder.app
```

Then open FloatingRecorder normally.

---

## 3. Grant permissions

On first run FloatingRecorder will walk you through two permissions:

### Microphone

macOS will pop up a dialog — click **Allow**. If you miss it, go to
**System Settings → Privacy & Security → Microphone** and enable
**FloatingRecorder**.

### Accessibility (required for global hotkey + auto-paste)

1. Open **System Settings → Privacy & Security → Accessibility**.
2. If you ever installed an older FloatingRecorder (or a build from another folder), **remove every old “FloatingRecorder” row** with the **minus (−)** button first. Otherwise macOS may keep toggling the wrong entry and the app will not see permission.
3. Click **+**, choose **FloatingRecorder** from **Applications**, and turn the switch **On**.
4. **Quit and reopen** FloatingRecorder (menu bar icon → Quit, then launch from Applications). macOS only refreshes Accessibility trust for a running app after a new launch.

Until you relaunch, the global hotkey may not register even if the toggle looks correct.

---

## 4. Using the app

- **Tap ⌥⌘** (Option + Command) to toggle the recorder on/off.
- **Hold ⌥⌘** while speaking, release to transcribe and auto-paste into the
  focused text field (falls back to the clipboard if no text field is focused).
- Change the hotkey, manage speech models, or toggle auto-paste in the
  menu-bar icon → **Preferences**.

---

## Uninstalling

Drag **FloatingRecorder.app** from `/Applications` to the Trash. That's it.

Downloaded speech models live under:
```
~/Library/Application Support/FloatingRecorder/
```
Delete that folder to also remove them.

Transcription text files saved through "Output save location" are not touched
by uninstall; remove them manually if desired.

---

## Verifying the download (optional)

Alongside the DMG you'll find `FloatingRecorder.dmg.sha256`. Compare it to
the hash you get locally:

```bash
shasum -a 256 ~/Downloads/FloatingRecorder.dmg
```

The hashes must match. If they don't, do not open the DMG and please report
the issue.
