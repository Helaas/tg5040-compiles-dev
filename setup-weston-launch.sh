#!/bin/bash
# Auto-setup weston-launch setuid on TrimUI device via adb
# Run this after deploying weston-launch to device

set -euo pipefail

TARGET_DIR="${1:-/mnt/SDCARD/Tools/tg5040/Weston.pak/bin}"
BINARY="weston-launch"
PATH_ON_DEVICE="${TARGET_DIR}/${BINARY}"

echo "==> Setting up weston-launch with setuid-root on device"
echo "Target: ${PATH_ON_DEVICE}"

# Verify adb is available
if ! command -v adb &>/dev/null; then
    echo "ERROR: adb not found in PATH" >&2
    exit 1
fi

# Verify device is connected
if ! adb devices | grep -E "device|emulator" >/dev/null 2>&1; then
    echo "ERROR: No ADB device connected" >/dev/null 2>&1
    echo "Connect device and try again."
    exit 1
fi

# Check if binary exists on device
if ! adb shell "test -f '${PATH_ON_DEVICE}'" 2>/dev/null; then
    echo "ERROR: ${BINARY} not found at ${PATH_ON_DEVICE} on device" >&2
    echo "Deploy with: adb push build/weston/prefix/bin/${BINARY} ${TARGET_DIR}/" >&2
    exit 1
fi

echo "Found: ${PATH_ON_DEVICE}"

# Set ownership to root
echo "==> Setting ownership to root:root"
adb shell "su -c 'chown root:root ${PATH_ON_DEVICE}'" 2>/dev/null || \
    adb shell "chown root:root ${PATH_ON_DEVICE}" 2>/dev/null || {
    echo "WARNING: Could not set ownership (may require root access on device)" >&2
}

# Set setuid bit
echo "==> Setting setuid-root"
adb shell "su -c 'chmod u+s ${PATH_ON_DEVICE}'" 2>/dev/null || \
    adb shell "chmod u+s ${PATH_ON_DEVICE}" 2>/dev/null || {
    echo "ERROR: Could not set setuid bit (requires root access)" >&2
    exit 1
}

# Verify
echo "==> Verifying setuid:"
STAT_OUT=$(adb shell "ls -l '${PATH_ON_DEVICE}'")
echo "$STAT_OUT"

if echo "$STAT_OUT" | grep -q " s "; then
    echo "✓ setuid-root successfully set"
    exit 0
else
    echo "✗ setuid bit not detected" >&2
    exit 1
fi
