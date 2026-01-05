#!/bin/sh

set -e

BASE="$(cd "$(dirname "$0")/.." && pwd)"
export LD_LIBRARY_PATH="$BASE/lib:$BASE/lib/libweston-12:$BASE/lib/weston${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XKB_CONFIG_ROOT="$BASE/share/X11/xkb"
export WESTON_DATA_DIR="$BASE/share/weston"
export WESTON_CONFIG_FILE="$BASE/weston.ini"
export WESTON_MODULE_MAP="drm-backend.so=$BASE/lib/libweston-12/drm-backend.so;headless-backend.so=$BASE/lib/libweston-12/headless-backend.so;fullscreen-shell.so=$BASE/lib/weston/fullscreen-shell.so;libexec_weston.so.0=$BASE/lib/weston/libexec_weston.so.0"
export LIBSEAT_BACKEND=seatd

RUNDIR="$BASE/run"
mkdir -p "$RUNDIR" "$BASE/logs"
# Attempt to mount a tmpfs here so UNIX sockets work on FAT; ignore failure.
if ! grep -qs " $RUNDIR " /proc/mounts; then
	mount -t tmpfs -o size=8M tmpfs "$RUNDIR" 2>/dev/null || true
fi
chmod 700 "$RUNDIR"
# Clean up any stale sockets from previous runs so seatd always starts fresh.
rm -f "$RUNDIR"/seatd.sock "$RUNDIR"/wayland-* "$RUNDIR"/wayland-*.lock
export XDG_RUNTIME_DIR="$RUNDIR"
export SEATD_SOCK="$RUNDIR/seatd.sock"

if [ ! -S "$SEATD_SOCK" ]; then
	"$BASE/bin/seatd" -l info >>"$BASE/logs/seatd.log" 2>&1 &
	SEATD_PID=$!
	sleep 0.5
fi

BACKEND_ARGS="--backend=drm-backend.so --shell=fullscreen-shell.so"
if [ "$WESTON_HEADLESS" = "1" ]; then
	BACKEND_ARGS="--backend=headless-backend.so --shell=fullscreen-shell.so --width=640 --height=480"
fi

"$BASE/bin/weston" $BACKEND_ARGS --log="$BASE/logs/weston.log" "$@"
STATUS=$?
if [ -n "$SEATD_PID" ]; then
	kill "$SEATD_PID" 2>/dev/null || true
fi
exit $STATUS
