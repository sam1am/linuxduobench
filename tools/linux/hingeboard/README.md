# hingeboard (vendored)

`hingeboard` and `hingeboard-dictate.py` are copied unchanged from
[github.com/brysonwf/hingeboard](https://github.com/brysonwf/hingeboard) at commit
`d5c6337855aeb28b5cb14f8f348f8a65c582ddd3` (2026-11-11), GPL-2.0-or-later (`LICENSE`). Its author is this repo's
original author.

Not installed by default since 2026-11-13 (the Sxmo desktop's on-screen keyboard is wvkbd, tools/linux/sxmo). How the
fork used it under Debian + Plasma Mobile (removed; kept for reference):
- `duo-posture` starts it whenever the two screens are stacked (phone rotated to landscape, both screens on, not
  folded): the keyboard fills the **lower** screen, apps live on the upper one, and maliit is switched off
  (KWin `VirtualKeyboard.enabled`), so the keyboard never pops up on the upper screen.
  Environment: `HINGEBOARD_OUTPUT=<lower>`, `HINGEBOARD_OTHER=<upper>`, `HINGEBOARD_ROTATE=0` (KWin already rotates
  the output; hingeboard's own 90 is for Phosh's portrait screen).
- Its Exit key closes it until the screens are stacked again. Never: `touch ~/.config/duo-posture-no-hingeboard`.
- Its `hingeboard-display-mode` (Phosh / Mutter DisplayConfig) is not installed: under KWin it does nothing.
- Needs: `python3-gi python3-gi-cairo python3-cairo python3-evdev gir1.2-gtk-4.0 gir1.2-gtk4layershell-1.0
  libgtk4-layer-shell0`, and `/dev/uinput` writable by the `input` group (`70-hingeboard-uinput.rules`).
  Dictation (the microphone key) also needs Vosk, which is not installed.

Update: copy the two files from a newer commit and change the commit above.
