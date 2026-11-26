#!/bin/sh
KEYS_DIR=/mnt/us/extensions/kindle-watch-keys
KEYS_RUN="$KEYS_DIR/runtime"
mkdir -p "$KEYS_RUN"
is_running() {
    [ -r "$KEYS_RUN/server.pid" ] || return 1
    KEYS_PID=$(cat "$KEYS_RUN/server.pid")
    case "$KEYS_PID" in ''|*[!0-9]*) return 1;; esac
    [ -r "/proc/$KEYS_PID/cmdline" ] || return 1
    tr '\000' ' ' < "/proc/$KEYS_PID/cmdline" | grep -q "$KEYS_DIR/server.lua"
}
stop_existing() {
    if is_running; then
        kill "$KEYS_PID" || return 1
        for KEYS_WAIT in 1 2 3 4 5; do
            sleep 1
            is_running || return 0
        done
        echo "Previous receiver has not stopped; refusing duplicate launch"
        return 1
    fi
    return 0
}
case "$1" in
read|start)
    stop_existing || exit 1
    if [ "$1" = read ]; then KEYS_MODE=reading; else KEYS_MODE=diagnostic; fi
    rm -f "$KEYS_RUN/server.pid"
    nohup /bin/sh "$KEYS_DIR/run.sh" "$KEYS_MODE" </dev/null >>"$KEYS_RUN/launcher.log" 2>&1 &
    sleep 2
    if is_running; then echo "V2.1 RUNNING; $KEYS_MODE; open a native-reader book"; else echo "V2.1 STOPPED; inspect runtime logs"; fi
    ;;
stop)
    stop_existing
    ;;
*) exit 2;;
esac
