#!/bin/sh
KEYS_DIR=/mnt/us/extensions/kindle-watch-keys
KEYS_RUN="$KEYS_DIR/runtime"
INPUT_ADDED=0
OUTPUT_ADDED=0
cleanup() {
    [ "$INPUT_ADDED" = 0 ] || iptables -D INPUT -p tcp --dport 8888 -j ACCEPT
    [ "$OUTPUT_ADDED" = 0 ] || iptables -D OUTPUT -p tcp --sport 8888 -m conntrack --ctstate ESTABLISHED -j ACCEPT
    rm -f "$KEYS_RUN/server.pid"
}
trap cleanup EXIT
cd /mnt/us/koreader || exit 1
[ -x ./luajit ] || exit 1
command -v timeout >/dev/null 2>&1 || { echo "timeout command required; refusing to start"; exit 1; }
iptables -I INPUT 1 -p tcp --dport 8888 -j ACCEPT || exit 1
INPUT_ADDED=1
if iptables -I OUTPUT 1 -p tcp --sport 8888 -m conntrack --ctstate ESTABLISHED -j ACCEPT; then OUTPUT_ADDED=1; fi
export LD_LIBRARY_PATH="/mnt/us/koreader/libs:/mnt/us/koreader/rocks/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
./luajit "$KEYS_DIR/server.lua" "${1:-diagnostic}" >>"$KEYS_RUN/server.log" 2>&1 &
KEYS_CHILD=$!
trap 'kill "$KEYS_CHILD" 2>/dev/null' TERM INT HUP
wait "$KEYS_CHILD"
