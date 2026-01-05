#!/bin/sh
# Weston launcher in NextUI pak style with userdata logging.
set -eu

PAK_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAK_BASENAME=$(basename -- "$PAK_DIR")
PAK_NAME=${PAK_BASENAME%.*}

# Shared userdata/log paths (fallbacks)
SHARED_USERDATA_ROOT=${SHARED_USERDATA_PATH:-"$HOME/.userdata"}
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
export LD_LIBRARY_PATH="$PAK_DIR/lib:$PAK_DIR/lib/libweston-12:$PAK_DIR/lib/weston${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XKB_CONFIG_ROOT="$PAK_DIR/share/X11/xkb"
export WESTON_DATA_DIR="$PAK_DIR/share/weston"
export WESTON_CONFIG_FILE="$PAK_DIR/weston.ini"
export WESTON_MODULE_MAP="drm-backend.so=$PAK_DIR/lib/libweston-12/drm-backend.so;headless-backend.so=$PAK_DIR/lib/libweston-12/headless-backend.so;fullscreen-shell.so=$PAK_DIR/lib/weston/fullscreen-shell.so;libexec_weston.so.0=$PAK_DIR/lib/weston/libexec_weston.so.0"
export LIBSEAT_BACKEND=seatd
export SEATD_SOCK="$PAK_DIR/seatd.sock"
export XDG_RUNTIME_DIR="$PAK_DIR/run"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" || true

# Default to headless to avoid disrupting the UI
export WESTON_HEADLESS="${WESTON_HEADLESS:-1}"

echo "=== Weston starting (headless=$WESTON_HEADLESS) ==="
exec "$PAK_DIR/bin/run-weston.sh" "$@"
