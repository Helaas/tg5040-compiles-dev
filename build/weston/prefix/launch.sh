#!/bin/sh
# Weston launcher in NextUI pak style with userdata logging.
set -eu

PAK_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAK_BASENAME=$(basename -- "$PAK_DIR")
PAK_NAME=${PAK_BASENAME%.*}

# Shared userdata/log paths (fallbacks)
DEFAULT_UD_DEVICE="/mnt/SDCARD/.userdata/tg5040"
DEFAULT_UD="/mnt/SDCARD/.userdata"
if [ -d "$DEFAULT_UD_DEVICE" ]; then
	SHARED_USERDATA_ROOT=${SHARED_USERDATA_PATH:-"$DEFAULT_UD_DEVICE"}
elif [ -d "$DEFAULT_UD" ]; then
	SHARED_USERDATA_ROOT=${SHARED_USERDATA_PATH:-"$DEFAULT_UD"}
else
	SHARED_USERDATA_ROOT=${SHARED_USERDATA_PATH:-"$HOME/.userdata"}
fi
HOME="$SHARED_USERDATA_ROOT/$PAK_NAME"
mkdir -p "$HOME"

LOG_ROOT=${LOGS_PATH:-"$SHARED_USERDATA_ROOT/logs"}
mkdir -p "$LOG_ROOT"
LOG_FILE="$LOG_ROOT/$PAK_NAME.txt"
: >"$LOG_FILE"

# Redirect stdout/stderr to log
exec >>"$LOG_FILE"
exec 2>&1

echo "=== Launching $PAK_NAME at $(date) ==="
echo "Args: $*"

# Ensure we run from the pak dir
cd "$PAK_DIR"

# Env for weston
export PATH="$PAK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PAK_DIR/lib:$PAK_DIR/lib/libweston-10:$PAK_DIR/lib/weston${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XKB_CONFIG_ROOT="$PAK_DIR/share/X11/xkb"
export WESTON_DATA_DIR="$PAK_DIR/share/weston"
export WESTON_CONFIG_FILE="$PAK_DIR/weston.ini"
export WESTON_MODULE_MAP="drm-backend.so=$PAK_DIR/lib/libweston-10/drm-backend.so;headless-backend.so=$PAK_DIR/lib/libweston-10/headless-backend.so;fbdev-backend.so=$PAK_DIR/lib/libweston-10/fbdev-backend.so;fullscreen-shell.so=$PAK_DIR/lib/weston/fullscreen-shell.so;libexec_weston.so.0=$PAK_DIR/lib/weston/libexec_weston.so.0"
export LIBSEAT_BACKEND=seatd
export SEATD_SOCK="$PAK_DIR/seatd.sock"
export XDG_RUNTIME_DIR="$PAK_DIR/run"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true

# Default to headless to avoid disrupting the UI
export WESTON_HEADLESS="${WESTON_HEADLESS:-0}"

echo "=== Weston starting (headless=$WESTON_HEADLESS) ==="
"$PAK_DIR/bin/run-weston.sh" "$@" &
WESTON_PID=$!

# Wait for Wayland socket
WAYLAND_DISPLAY=
for candidate in wayland-0 wayland-1; do
	i=0
	while [ $i -lt 50 ]; do
		if [ -S "$XDG_RUNTIME_DIR/$candidate" ]; then
			WAYLAND_DISPLAY=$candidate
			break 2
		fi
		i=$((i+1))
		sleep 0.1
	done
done
[ -z "$WAYLAND_DISPLAY" ] && WAYLAND_DISPLAY=wayland-0

# Fire up a simple-shm client so we see something on screen
if [ -x "$PAK_DIR/bin/weston-simple-shm" ]; then
	echo "=== Launching simple-shm demo ==="
	WAYLAND_DISPLAY=$WAYLAND_DISPLAY "$PAK_DIR/bin/weston-simple-shm" >/dev/null 2>&1 &
	DEMO_PID=$!
fi

# Keep things alive briefly for demo visibility
sleep 15

# Tear down demo and weston
if [ -n "${DEMO_PID:-}" ]; then
	kill "$DEMO_PID" 2>/dev/null || true
fi
kill "$WESTON_PID" 2>/dev/null || true
wait "$WESTON_PID" 2>/dev/null || true
