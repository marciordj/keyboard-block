# KeyboardBlock

**English** · [Português (BR)](README.pt-BR.md)

A menu bar app to **block the MacBook keyboard** while you wipe the keys down.

No shutdown required: the block happens with the Mac awake, so pressing a key
powers nothing on. The keyboard comes back with a mouse click.

```
⌨️  gray icon       → keyboard live
⌨️  1:47 (red)      → keyboard blocked, 1min47s left
```

## How it works

Creates a [`CGEventTap`](https://developer.apple.com/documentation/coregraphics)
at the session level and discards keyboard events (`keyDown`, `keyUp`,
`flagsChanged`, media keys). No `sudo`, nothing written to disk, no state left
behind in the system.

**Fails safe by construction:** the tap lives inside the process. If the app
hangs, gets killed, or you hit "Quit", the keyboard comes back immediately.
That is the main difference from remapping keys with `hidutil`, which leaves the
system in a persistent state and can lock you out.

## Install

Requires macOS 13+ and Xcode Command Line Tools.

```bash
./scripts/install.sh
```

Then:

1. Open it: `open -a KeyboardBlock`
2. Click the menu bar icon → **Bloquear teclado** (*Block keyboard*).
3. macOS will ask for **Accessibility**. Enable KeyboardBlock under
   *System Settings › Privacy & Security › Accessibility*.
4. **Quit and reopen the app** (the permission only applies on the next launch).

> Install to `/Applications` **before** granting the permission. macOS ties the
> permission to the app's path/signature — grant it in `build/` and then move the
> app, and you will have to grant it again.

## Usage

| Action | How |
|---|---|
| Block | click the icon → **Bloquear teclado** |
| Release | click the icon → **Liberar agora** (*Release now*) |
| Release without looking at the bar | **hold the right mouse button for 1.5s** |
| Release automatically | 1/2/5/10 min timer (default: 2 min) |

The duration is **always bounded** — there is no "block forever". Three
independent safety nets: the timer, the right-button gesture, and the tap dying
along with the process.

The menu itself is in Portuguese, hence the labels above.

## Honest limitations

- **It cannot stop the Mac from powering on.** With the machine off, no software
  runs — a keypress powers it on, period. The right flow is to clean with the Mac
  **on and the keyboard blocked**, not powered off.
- **Blocks every keyboard**, not just the built-in one. If you have an external
  keyboard and need it while cleaning, this is not the app (that would require
  `IOKit` seize with root).
- **Media/brightness keys** are blocked too, but the *display* can still wake on a
  keypress — the event dies after the power handler.
- **Needs Accessibility**, and the permission is tied to the binary's signature.
  With ad-hoc signing, every `./scripts/build-app.sh` may require re-granting.
  To avoid that:

  ```bash
  CODESIGN_IDENTITY="Apple Development: you@example.com (XXXXXXXXXX)" ./scripts/build-app.sh
  ```

  (or create a self-signed certificate in Keychain Access and use its name)
- **Not on the App Store.** Sandboxing does not work with a blocking event tap.
  Distributing to others would require notarization.

## App icon

`Resources/AppIcon.png` (square, 1024×1024, full-bleed) is converted to
`AppIcon.icns` at build time, with all 10 resolutions, and referenced by
`CFBundleIconFile`. A ready-made `.icns` placed at `Resources/AppIcon.icns` works
too.

On macOS 26 the system applies the squircle mask and the glass background on top
— which is why the artwork goes full-bleed, with no margin and no rounded
corners.

The **menu bar** icon is a different thing: an SF Symbol
(`keyboard` / `keyboard.fill`) set in `AppDelegate.updateAppearance()`.

## Layout

```
Sources/KeyboardBlock/
  main.swift            boots NSApplication as a menu bar app (LSUIElement)
  AppDelegate.swift     icon, menu, timer, escape gesture
  KeyboardBlocker.swift CGEventTap: creates the tap, drops events, re-enables
                        itself if the system disables it on timeout
Resources/Info.plist    bundle (LSUIElement=true, no Dock icon)
Resources/AppIcon.png   icon artwork (1024x1024, full-bleed)
scripts/build-app.sh    compiles and assembles the .app
scripts/make-icns.sh    PNG -> .icns with all 10 resolutions
scripts/install.sh      build + copy to /Applications
```

## Development

```bash
swift build            # compile
./scripts/build-app.sh # produce build/KeyboardBlock.app
```

Testing the block for real requires granting Accessibility — that cannot be
automated without interacting with the system dialog.
