Kindle Watch Keys v2.1

Use the repository README.md / README.zh-CN.md for installation and setup.
Generate a private config.lua before copying this folder to the Kindle.
For an update, preserve your existing config.lua and runtime/ logs.

KUAL > Watch Keys v2 > Start reading (2 hours)
Open a book in the native reader, then run the local page-turn Shortcut.
Start diagnostics (15 min) is a separate, initially disarmed test mode.

Requires a jailbroken Kindle and an existing compatible KOReader Lua runtime.
KOReader does not need to be the reading interface.
The extension sends X11 PageDown/PageUp key events and never falls back to
touchscreen injection. No kernel-module, keymap, firmware, or boot-service changes.
No boot autostart. See COPYING and NOTICE.txt for licensing and attribution.
