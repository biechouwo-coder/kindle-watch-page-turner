# Changelog

## 0.2.1

- Added a locally started two-hour reading mode, without manual per-page quotas.
- Retained the initially disarmed 15-minute diagnostic mode.
- Refuse normal sleep/foreground changes without permanently locking reading mode.
- Keep backend-error lockout, Xorg-process checks, and the minimum request interval.
- Preserve runtime logs and stop an existing receiver before switching modes.

## 0.2.0

- Replaced the local prototype's touchscreen injection with native-reader X11
  PageDown/PageUp press/release events.
- Added exact reader-window matching, bounded X11 operations and no-touch fallback.
- Verified short desktop/Watch page-turn and sleep/wake tests on one PW5 setup.

The earlier local touch-injection prototype is not distributed in this project.
