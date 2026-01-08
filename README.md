# TrimUI Weston + InfoZip Build System

This repository contains a complete build system for cross-compiling **Weston 10.0.4** (Wayland compositor) and **InfoZip 3.0** as aarch64 binaries for TrimUI targets.

## Quick Start

### Build Everything

```bash
# Build Weston 10.0.4 + dependencies + weston-launch
make weston

# Build InfoZip 3.0 aarch64
make zip

# Verify both artifacts
make verify-artifacts
```

### Deploy to Device

```bash
# Create deployable bundle
make bundle

# Push to device via adb
make deploy

# Or set weston-launch setuid manually
./setup-weston-launch.sh
```

---

## Artifacts

### Weston 10.0.4

**Location**: `build/weston/prefix/`

- **weston**: Main compositor binary
- **weston-launch**: Session launcher (requires setuid-root on device)
- **weston-simple-shm**: Test client
- **libweston-10.so**: Core library
- **Backends**: DRM, headless, framebuffer
- **Dependencies**: libwayland, libdrm, libinput, xkbcommon, cairo, seatd

**Key Configuration**:
- `-Ddeprecated-weston-launch=true`: Enable weston-launch
- `-Dlauncher-libseat=true`: Enable libseat support (seatd-launch)
- `-Drenderer-gl=false`: Disable GL (not in SDK)
- `-Dimage-jpeg=false, -Dimage-webp=false`: Minimal image formats
- `-Dsimple-clients=shm`: Only SHM client (avoids GBM)

### InfoZip 3.0

**Location**: `./zip`

- **zip**: aarch64 command-line compression utility
- **GLIBC requirement**: ≥ 2.17 (verified on build)
- **Status**: Statically verified via `readelf` and `strings` for GLIBC symbols

---

## Build System

### Makefile Targets

| Target | Purpose | Output |
|--------|---------|--------|
| `make weston` | Build Weston stack (default) | `build/weston/prefix/` |
| `make weston-launch` | Verify weston-launch binary | Checks aarch64 + libpam |
| `make zip` | Build InfoZip 3.0 | `./zip` |
| `make verify-artifacts` | Check both binaries | Status report |
| `make bundle` | Create tar.gz archive | `build/weston/weston.tar.gz` |
| `make deploy` | Push to device via adb | On device: `/mnt/SDCARD/Tools/tg5040/Weston.pak/` |
| `make clean` | Remove all artifacts | Resets to clean state |
| `make clean-weston` | Remove only weston | Keeps deps |
| `make clean-zip` | Remove only zip | Keeps weston |
| `make help` | Show all targets | Usage info |

### Container Build

All compilation happens in a Docker container (`weston-build`) using the **tg5040-toolchain**:

```bash
# Ensure container is running
make container

# Or start manually
docker run -d --name weston-build -v "$(pwd):/workspace" \
  ghcr.io/loveretro/tg5040-toolchain/tg5040-toolchain:latest tail -f /dev/null
```

**Toolchain Details**:
- **Cross triple**: `aarch64-nextui-linux-gnu`
- **GCC**: 8.3.0
- **SYSROOT**: `/opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc`
- **C Library**: GLIBC 2.17+

---

## Documentation

### weston-launch Setup

See [WESTON-LAUNCH-SETUP.md](WESTON-LAUNCH-SETUP.md) for:
- Deployment methods (adb, manual, tar bundle)
- Setuid configuration on device
- Usage with environment variables
- Troubleshooting & alternatives
- seatd-launch as modern alternative

### InfoZip Build

See [INFOZIP-BUILD-README.md](INFOZIP-BUILD-README.md) for:
- Standalone build instructions
- GLIBC verification steps
- Usage examples

### Scripts

- **[build-infozip.sh](build-infozip.sh)**: Containerized InfoZip build (called by `make zip`)
- **[setup-weston-launch.sh](setup-weston-launch.sh)**: Automated setuid setup via adb

---

## Customization

### Adjust Weston Build Flags

Edit the `$(STAMPS)/weston` target in [Makefile](Makefile):

```makefile
# Example: enable X11 backend
-Dbackend-x11=true \

# Example: disable headless backend
-Dbackend-headless=false \

# Example: enable GL renderer (requires libgbm)
-Drenderer-gl=true \
```

Then rebuild:

```bash
make clean-weston
make weston
```

### Update Dependency Versions

Modify `TARBALLS` in [Makefile](Makefile) to download new versions:

```makefile
TARBALLS = \
    $(SRC_DIR)/wayland-1.23.0.tar.xz \  # <- Updated version
    ...
```

Then:

```bash
make clean
make weston
```

---

## Troubleshooting

### Issue: Container not found

```bash
# Restart container
docker start weston-build

# Or recreate
docker rm weston-build
make container
```

### Issue: Dependencies fail to build

```bash
# Check container logs
docker logs weston-build

# Rebuild specific dependency
make clean
make deps
```

### Issue: weston-launch won't build

Check that Linux-PAM is installed in SYSROOT:

```bash
docker exec weston-build ls -l /opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc/usr/include/security/pam_appl.h
```

If missing, run the PAM build script:

```bash
docker exec weston-build bash llm/toolchain/tg5040-toolchain/support/build-linux-pam.sh
```

### Issue: zip binary fails GLIBC check

Verify GLIBC symbols:

```bash
aarch64-linux-gnu-strings ./zip | grep GLIBC_
```

Should show `GLIBC_2.17` or later.

---

## File Structure

```
tg5040-compiles-dev/
├── Makefile                          # Main build orchestration
├── build-infozip.sh                  # InfoZip build script
├── setup-weston-launch.sh            # adb setuid automation
├── WESTON-LAUNCH-SETUP.md            # weston-launch deployment guide
├── INFOZIP-BUILD-README.md           # zip build documentation
├── README.md                         # This file
│
├── build/weston/
│   ├── src/                          # Tarballs (auto-fetched)
│   ├── build/                        # Build directories
│   ├── prefix/                       # Installation prefix
│   ├── .stamps/                      # Build status markers
│   ├── crossfile.meson               # Meson cross-config
│   ├── native.meson                  # Meson native config
│   └── weston.tar.gz                 # Bundled archive
│
├── llm/toolchain/
│   └── tg5040-toolchain/
│       └── support/
│           └── build-linux-pam.sh    # Linux-PAM build helper
│
└── zip                               # Final aarch64 zip binary
```

---

## Performance & Caching

The build system uses **stamp files** (`.stamps/`) to track completed builds and avoid redundant recompilation:

- Each dependency has a `.stamps/<name>` marker
- Deleting a stamp forces a rebuild: `rm .stamps/libdrm`
- Rebuilding a dependency automatically rebuilds all downstream targets

**Build times** (first run):
- libdrm + wayland deps: ~2 min
- cairo: ~1 min
- weston: ~3 min
- **Total**: ~6 min

**Rebuild after change** (no deps affected): ~30 sec

---

## Development Workflow

### Modify Weston Source

```bash
# Edit weston source (after first build)
vim build/weston/build/weston-10.0.4/compositor/main.c

# Rebuild only weston (deps cached)
make clean-weston
make weston
```

### Add Custom Patch

```bash
# Create patch
cd build/weston/build/weston-10.0.4
git diff > /tmp/my.patch

# Apply on next rebuild (edit build-weston target)
# Add: patch -p1 < /tmp/my.patch
```

---

## Contributing

To improve the build system:

1. Test changes locally in the container
2. Update this README if adding new targets/options
3. Keep documentation in sync with Makefile changes

---

## License & Attribution

- **Weston**: Licensed under MIT (https://gitlab.freedesktop.org/wayland/weston)
- **InfoZip**: Licensed under Info-ZIP (https://infozip.sourceforge.net/)
- **tg5040-toolchain**: Cross-compilation toolchain for TrimUI/ARM targets
- **Build scripts**: MIT (this repository)

---

## Support & Issues

For issues with:

- **Weston**: Check [WESTON-LAUNCH-SETUP.md](WESTON-LAUNCH-SETUP.md) troubleshooting
- **zip**: Check [INFOZIP-BUILD-README.md](INFOZIP-BUILD-README.md)
- **Build system**: Review Makefile comments and `make help`

---

**Last Updated**: January 8, 2026
**Weston Version**: 10.0.4
**InfoZip Version**: 3.0
**Target Architecture**: aarch64 (ARM 64-bit)
