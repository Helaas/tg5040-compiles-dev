# weston-launch Setup & Deployment

## Overview

`weston-launch` is a deprecated session launcher that provides privileged access to device nodes (DRM, input devices, etc.) without running the entire Weston compositor as root. It requires **setuid-root** to function.

**Status**: Weston 10.0.4 with weston-launch built and ready for deployment.  
**Binary location**: `build/weston/prefix/bin/weston-launch` (aarch64, ~33KB)

---

## Prerequisites

1. **Filesystem**: weston-launch must reside on a **native Linux filesystem** (ext4, btrfs, etc.)
   - ❌ Does NOT work on FAT32, exFAT, or other non-POSIX filesystems
   - The TrimUI device likely has a Linux partition; verify your deployment target

2. **Dependencies**: weston-launch links against:
   - `libpam.so.0` — Linux-PAM (installed in SYSROOT; must exist on device)
   - `libdrm.so` — Device Independent Rendering (included in Weston bundle)

3. **Device access**: Requires access to:
   - `/dev/dri/*` (DRM devices)
   - `/dev/input/*` (input devices)

---

## Deployment Steps

### Option A: Auto-deploy with adb (Recommended)

If you have `adb` configured with the device:

```bash
# Copy weston-launch to device
adb push build/weston/prefix/bin/weston-launch /mnt/SDCARD/Tools/tg5040/Weston.pak/bin/

# Set ownership and setuid
adb shell "chown root:root /mnt/SDCARD/Tools/tg5040/Weston.pak/bin/weston-launch"
adb shell "chmod u+s /mnt/SDCARD/Tools/tg5040/Weston.pak/bin/weston-launch"

# Verify
adb shell "ls -l /mnt/SDCARD/Tools/tg5040/Weston.pak/bin/weston-launch"
# Output should show: -rwsr-xr-x (note the 's' in owner execute position)
```

### Option B: Manual via Linux filesystem

If deploying to a Linux partition on the device (e.g., `/mnt/var` or system ext4):

1. **Copy the binary** to a Linux filesystem path on the device:
   ```bash
   # Via adb to a Linux FS (e.g., /data/weston or /mnt/var)
   adb push build/weston/prefix/bin/weston-launch /data/local/weston-launch
   ```

2. **Set permissions** on the device (via `adb shell` or SSH):
   ```bash
   adb shell
   # Inside device shell:
   su root  # Switch to root if needed
   cd /data/local
   chown root:root weston-launch
   chmod u+s weston-launch
   ls -l weston-launch
   # Output: -rwsr-xr-x (s = setuid-root)
   ```

3. **Verify setuid is set**:
   ```bash
   adb shell "ls -l /data/local/weston-launch"
   ```

### Option C: Include in tar bundle

If bundling Weston (via `make bundle`), the tar includes binaries but **does not preserve setuid bits**:

1. **Deploy bundle**:
   ```bash
   make deploy  # or manually push weston.tar.gz
   ```

2. **On device, after extracting**:
   ```bash
   cd /mnt/SDCARD/Tools/tg5040/Weston.pak
   tar xzf weston.tar.gz
   
   # Set setuid on weston-launch in the extracted tree
   chown root:root bin/weston-launch
   chmod u+s bin/weston-launch
   ```

---

## Usage

### Launch Weston with weston-launch

On the device:

```bash
# Basic headless launch (no display)
export WESTON_HEADLESS=1
/mnt/SDCARD/Tools/tg5040/Weston.pak/bin/weston-launch -- /mnt/SDCARD/Tools/tg5040/Weston.pak/bin/weston

# Or with a specific backend/config
WESTON_HEADLESS=1 weston-launch -- weston --backend=headless-backend.so --config=weston.ini
```

### Environment Variables

- `WESTON_HEADLESS=1` — Run in headless mode (no display output)
- `WESTON_SEAT_ID` — Override seat (default: "seat0")
- `WESTON_SOCKET_DIR` — Custom Wayland socket directory

---

## Troubleshooting

### Error: "Operation not permitted" when running weston-launch

**Cause**: setuid bit not set or binary on non-POSIX filesystem.

**Fix**:
1. Verify setuid:
   ```bash
   ls -l /path/to/weston-launch
   # Should show: -rwsr-xr-x (s in owner execute position)
   ```
2. If not set, re-run:
   ```bash
   chown root:root /path/to/weston-launch
   chmod u+s /path/to/weston-launch
   ```
3. If on FAT32/exFAT, move to a Linux filesystem:
   ```bash
   cp /mnt/SDCARD/weston-launch /data/weston-launch
   chown root:root /data/weston-launch
   chmod u+s /data/weston-launch
   ```

### Error: "libpam.so.0: cannot open shared object file"

**Cause**: Linux-PAM library not available on device.

**Fix**: Ensure libpam is in the Weston bundle or copied separately:
```bash
# Check if available in prefix
ls build/weston/prefix/lib/libpam*.so*

# Include in bundle or deploy separately
adb push build/weston/prefix/lib/libpam.so.0 /mnt/SDCARD/Tools/tg5040/Weston.pak/lib/
```

### Error: "cannot access /dev/dri/*, /dev/input/*"

**Cause**: Insufficient permissions or device nodes not present.

**Fix**:
1. Verify device nodes exist:
   ```bash
   adb shell "ls -l /dev/dri/ /dev/input/"
   ```
2. If running as non-root user, ensure they're in `video` and `input` groups:
   ```bash
   adb shell "usermod -aG video,input myuser"
   ```
3. Or run with root/elevated privileges.

---

## Alternatives to weston-launch

If setuid or weston-launch presents issues, consider:

### 1. seatd-launch (Preferred)

Use libseat + seatd instead (Weston 10.0.4 supports `-Dlauncher-libseat=true`):

```bash
# Ensure seatd is running on device
/path/to/seatd -u 0 &

# Launch Weston without weston-launch
/path/to/weston --launcher=libseat
```

**Advantages**:
- Modern, supported session launcher
- No setuid needed
- Better multi-seat support

### 2. Run Weston as root

```bash
export WESTON_HEADLESS=1
/path/to/weston
```

**Disadvantages**:
- Security risk if Weston is compromised
- Not recommended for production use

---

## Verification

### Confirm weston-launch is built and linked correctly

```bash
# Check binary exists and is aarch64
file build/weston/prefix/bin/weston-launch
# Expected: ELF 64-bit LSB executable, ARM aarch64

# Check PAM linkage
aarch64-linux-gnu-readelf -d build/weston/prefix/bin/weston-launch | grep NEEDED
# Should include: libpam.so.0
```

### Test setuid on device

```bash
adb shell "test -u /mnt/SDCARD/Tools/tg5040/Weston.pak/bin/weston-launch && echo 'setuid OK' || echo 'setuid NOT SET'"
```

---

## Summary

| Step | Action | Status |
|------|--------|--------|
| Build weston-launch | `make weston` with `-Ddeprecated-weston-launch=true` | ✅ Complete |
| Deploy to device | `adb push` to Linux filesystem | ⏳ Manual or script-based |
| Set setuid | `chmod u+s` on device | ⏳ Manual or adb shell command |
| Test launch | `weston-launch -- weston` | ⏳ Device-side test |

Once setuid is set, weston-launch is ready to provide unprivileged session management for Weston.

