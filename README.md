# Kindle Watch Page Turner

[中文说明](README.zh-CN.md)

Turn pages in the **native Kindle reader** from an Apple Watch Shortcut or an
AssistiveTouch finger gesture. The Kindle receiver sends X11 PageDown/PageUp
key press/release events to the foreground reader window. It does not inject
touchscreen events or require you to read inside KOReader.

Version: **0.2.1** · License: **GPL-3.0-or-later**

## Verified setup and limits

The local test setup was a jailbroken **Kindle Paperwhite 5 / 11th generation**
with firmware **5.16.2.1.1**, an existing KOReader **v2023.10** runtime, and an
Apple Watch **Series 11** reported as running **watchOS 27.2**.

Observed tests covered desktop page requests, multiple Watch gesture requests,
Kindle sleep/wake, and the two-hour reading mode's startup. The user confirmed
actual page changes and a normal screen; subsequent read-only checks found the
same Xorg process. A full two-hour endurance run and other device/firmware
combinations have **not** been verified. This is a small, experimental project,
not an Amazon- or Apple-supported accessory.

An earlier local prototype that wrote touch events was associated with Xorg
crashes and persistent white screens. **That implementation is not included.**
This receiver has no touch, evdev, or uinput fallback.

## Requirements

- A jailbroken Kindle with KUAL and an existing compatible KOReader LuaJIT /
  LuaSocket runtime at `/mnt/us/koreader`.
- A native X11 reader window named for `com.lab126.booklet.reader`.
- Kindle commands `timeout`, `lipc-get-prop`, and `iptables`.
- A reachable local network between the Kindle and the phone/Watch network path.
  A phone hotspot is optional; client-isolated campus or guest Wi-Fi may not work.
- The Apple Shortcuts app, plus AssistiveTouch for gesture activation.

No computer is required during normal reading. The receiver does not install
kernel modules, change firmware, alter keymaps/focus, or configure boot services.

## Install

1. Download or clone this repository. Generate a **local-only** configuration:

   ```sh
   python3 scripts/setup_config.py --host 192.168.1.50
   ```

   Replace the example IP with the Kindle's address. This creates
   `extension/kindle-watch-keys/config.lua` and `shortcut-urls.txt`, both ignored
   by Git. The random control token is not printed to the terminal.

2. Copy the whole `extension/kindle-watch-keys` folder to the Kindle's
   `extensions` directory using USB, then safely eject it.
3. Open **KUAL → Watch Keys v2 → Start reading (2 hours)**.
4. Open a book in the **normal Kindle reader**.

When updating, keep the existing device `config.lua` to preserve the token used
by your Shortcuts. Preserve `runtime/` if you need its log history. Do not copy
someone else's private configuration.

## Create the Watch Shortcut

1. On iPhone, create a Shortcut named **Kindle Next Page**.
2. Add **Get Contents of URL**. Set its URL field to the complete Next URL from
   your local `shortcut-urls.txt` and use the **GET** method.
3. Run it manually once. Allow the relevant local-network access when requested,
   and visually confirm that the Kindle turns one page.
4. Enable **Show on Apple Watch** in the Shortcut details. Test it manually in
   the Watch Shortcuts app before assigning a gesture.
5. In the iPhone Watch app, open **Accessibility → AssistiveTouch → Hand
   Gestures**. Enable the feature and assign **Double Tap → Siri Shortcut →
   Kindle Next Page**. This is the AssistiveTouch gesture, not the separate
   native Double Tap setting.
6. If desired, select **Activation Gesture → None** when that option is available,
   so a separate fist gesture is not required first. Raise your wrist to wake
   the Watch before performing the finger gesture.

The previous-page URL uses `/prev` instead of `/next`.

In the tested Watch configuration, enabling AssistiveTouch conflicted with
native Wrist Flick. This project does not remove that system restriction.
See Apple's [AssistiveTouch guide](https://support.apple.com/en-gb/111111).

## Daily use

- Start **Start reading (2 hours)** in KUAL, open the book, and use the Shortcut.
- The receiver stops after two hours. Start it again if you keep reading.
- After a Kindle reboot, start it again; there is **no boot autostart**.
- **Stop v2** ends the session early. Temporary port rules are removed on exit.
- Keep the Kindle awake and the native reader in front. Other screens or sleep
  cause that request to be refused rather than redirected somewhere else.
- The minimum interval between page requests is 1.5 seconds.
- If the Kindle's local IP changes, update the URL in the Shortcut.

The token travels over local HTTP. Keep it private and do not forward the
receiver port to the internet. Real configurations, URLs, logs, and signed
Shortcut exports are intentionally absent from this repository.

## Diagnostics and recovery

**Start diagnostics (15 min)** starts a separate, initially disarmed mode.
See [the protocol and diagnostic guide](docs/architecture.md) for bounded tests.
The optional desktop client needs Python 3 and curl 7.76 or later:

```sh
python3 scripts/remote_client.py 192.168.1.50 health
python3 scripts/remote_client.py 192.168.1.50 probe
```

On a Mac with a VPN routing local requests incorrectly, an individual request
can specify `--interface en0`. It does not change system routing.

An HTTP acknowledgement confirms that X11 processed the key-event requests. It
does **not** prove that the displayed page changed; check the device. An X11
error or changed Xorg process disables further page actions for that session.

If a persistent white screen occurs, stop triggering commands and preserve
`runtime/server.log` and `runtime/launcher.log`. Amazon documents holding the
power button for 40 seconds, then releasing it to restart a frozen Kindle:
[restart instructions](https://digprjsurvey.amazon.com/csad/help/node/G9WDGDTCSDQMSU7Z).
The Kindle's `;dm` search command can export system logs for investigation.
Do not publish those raw logs without checking their personal data.

## Tests

```sh
python3 -m pip install -r requirements-dev.txt
python3 tests/test_kindle_keys.py
sh -n extension/kindle-watch-keys/control.sh extension/kindle-watch-keys/run.sh
```

Tests cover X11 packet framing and both directions, reader-window matching,
read-only probing, errors/disconnections without retries, arming quotas,
reading-mode expiry, rate limits, foreground/sleep refusals, and backend-error
lockout. Socket/HTTP tests use mocks and do not control a physical device.

## Source and license

The X11 wire implementation is adapted from
[kindle-button-mapper-rs/src/xkey.rs](https://github.com/zampierilucas/kindle-button-mapper-rs/blob/master/src/xkey.rs)
by zampierilucas and contributors. See [NOTICE](NOTICE) and [LICENSE](LICENSE).
The protocol reference is the
[X Consortium X11 protocol specification](https://www.x.org/releases/current/doc/xproto/x11protocol.pdf).
