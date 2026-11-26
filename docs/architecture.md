# Protocol and diagnostic notes

## Request path

```text
Watch AssistiveTouch / Shortcuts
    -> local HTTP receiver on the Kindle
    -> token, session, rate, power and foreground checks
    -> bounded local X11 Unix-socket connection
    -> identify exactly one native-reader window
    -> PageDown/PageUp KeyPress + KeyRelease + X11 round trip
```

The receiver uses the existing KOReader Lua runtime, not the KOReader reader UI.
It does not open `/dev/input`, create a uinput keyboard, load a kernel module,
change the keyboard map, change focus, or fall back to simulated touch.

## HTTP API

Requests use GET on port 8888. Except `/health`, the exact query is
`?token=YOUR_LOCAL_TOKEN`. Unknown routes, extra query fields, and invalid tokens
are rejected. Treat the token as a local control credential.

| Path | Effect |
| --- | --- |
| `/health` | Receiver liveness and startup mode; no page action. |
| `/probe` | Read power state, foreground application and X11 window/process information. No key event. |
| `/status` | Reading-session expiry, diagnostic quota, or error-lockout state. |
| `/next` | One PageDown press/release if permitted. |
| `/prev` | One PageUp press/release if permitted. |
| `/stop` | End the receiver loop and clean up temporary port rules. |
| `/arm-once` | Diagnostic mode only: authorize one action for at most 120 seconds. |
| `/arm-five` | Diagnostic mode only: authorize five actions for at most 120 seconds. |

Reading mode lasts 7200 seconds and does not require an arming call. Diagnostic
mode lasts 900 seconds and begins with no page actions authorized. The two modes
are selected locally through KUAL, not by a remote mode-switch endpoint.

## Refusal and error handling

The receiver only targets an awake native reader with the expected application
window identity. It refuses missing or ambiguous windows and limits X11 tree
traversal, packet sizes, socket timeouts and total operation time.

Normal sleep/home-screen or foreground-change refusals return a conflict
response without permanently disabling a reading session. Actual X11 transport
or protocol errors disable further page actions. A changed Xorg peer PID is
rejected rather than silently reconnecting and continuing the same test.

Press, release and a synchronization request are queued together. Actions are
consumed before sending in diagnostic mode. There is no automatic retry when a
response is lost: the event might already have reached the reader.

The X11 acknowledgement establishes protocol processing, not visual success or
long-term stability. Keep user-observed results separate from receiver logs.

## Tests versus device observations

`tests/test_kindle_keys.py` runs the actual Lua modules under Lua 5.1 through
Lupa, with scripted I/O. It checks packet fields and ordering, window filters,
handshake/query errors, disconnect-without-retry behavior, session quota/expiry,
rate limits, native-reader context guards, and the HTTP dispatcher.

The Linux ARM FFI transport and real Kindle UI are not emulated by those tests.
Short physical tests covered page changes, repeated Watch requests and
sleep/wake on the setup in the README. Other models, firmware versions, and
long-duration sessions remain unverified.

## Files and lifecycle

- `config.lua` is generated locally and must never be committed.
- `runtime/server.log`, `runtime/launcher.log`, and `runtime/server.pid` are local
  runtime state and ignored by Git.
- No system boot entry is installed.
- KUAL starts a small supervisor, which adds port rules, waits for the Lua
  receiver, and removes those rules on normal exit.
- Runtime logs append instead of being erased on each start.
- Kindle system logs exported with `;dm` can contain network/account/book data;
  they do not belong in the source repository.
