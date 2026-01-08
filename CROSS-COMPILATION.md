# Cross-Compilation Setup & Architecture

This document explains the build architecture and how the cross-compilation toolchain works.

## Overview

All builds happen **inside a Docker container** using a pre-built cross-compilation toolchain. This ensures:
- Reproducibility (same image, same output)
- Isolation (no system dependencies)
- Portability (runs on macOS, Linux, Windows+WSL)

## Toolchain Details

### Image

**Repository**: `ghcr.io/loveretro/tg5040-toolchain/tg5040-toolchain:latest`

**Built for**: TrimUI family (aarch64-nextui-linux-gnu)

**Contents**:
- GCC 8.3.0 (cross-compiler)
- Binutils (cross-assembler, linker)
- GLIBC 2.17+ (C runtime library)
- Meson 1.3.2 (build system)
- Ninja (build tool)
- Standard autotools (for projects using Autoconf)

### Cross Triple

```
aarch64-nextui-linux-gnu
│       │         │      │
│       │         │      └─ GNU C library
│       │         └────────── Operating system (Linux)
│       └────────────────────── Vendor/platform (nextui)
└──────────────────────────────── Architecture (aarch64 = ARM 64-bit)
```

This means: "Build for 64-bit ARM using the NextUI platform libraries on Linux with GNU C"

### Sysroot

**Location (in container)**: `/opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc`

The **sysroot** is the "root filesystem" for the target platform—contains:
- C library headers and libraries (`usr/include/`, `usr/lib/`)
- Platform-specific includes
- Cross-compiled libraries (libdrm, wayland, etc.)
- Linux PAM (libpam) for weston-launch

#### Environment Variables

Inside the container, the toolchain provides:
```bash
export CROSS_TRIPLE=aarch64-nextui-linux-gnu
export SYSROOT=/opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc
export CC=${CROSS_TRIPLE}-gcc
export CXX=${CROSS_TRIPLE}-g++
export AR=${CROSS_TRIPLE}-ar
export RANLIB=${CROSS_TRIPLE}-ranlib
export LD=${CROSS_TRIPLE}-ld
```

## Build Flow

### 1. Container Initialization

```
make weston  →  Makefile runs  →  docker start weston-build
                                     (or creates if missing)
```

Container mounts the workspace:
- **Host**: `/Users/kevinvranken/GitHub/tg5040-compiles-dev` (PWD)
- **Container**: `/workspace`

### 2. Dependency Build (Sequential)

Each dependency is built with **meson/ninja** (except cairo, which uses autotools):

```
libdrm
  ↓
wayland (depends on libdrm)
  ↓
wayland-protocols
  ↓
libevdev → libinput → xkeyboard-config → libxkbcommon
  ↓
seatd/libseat
  ↓
cairo
  ↓
weston (depends on all above)
```

Each build:
1. **Extracts** tarball from `build/weston/src/`
2. **Configures** with cross-triple and sysroot
3. **Compiles** using host tools (cross-compiler)
4. **Installs** to `build/weston/prefix/`

### 3. Weston + weston-launch

Weston is built with meson options that:
- Enable `deprecated-weston-launch=true` (builds weston-launch)
- Link against `-lpam` (Linux-PAM library)
- Disable features not in SDK (GL renderer, X11, WebP, etc.)

Output binaries in `build/weston/prefix/bin/`:
- **weston**: Main compositor (~13KB)
- **weston-launch**: Session launcher (linked with libpam) (~33KB)
- **weston-info**: Display info utility (~48KB)
- **weston-simple-shm**: Wayland client example (~35KB)

### 4. InfoZip Build

Separate from Weston, the **zip** binary is built by:
1. `make zip` calls `build-infozip.sh`
2. Script downloads InfoZip 3.0 source
3. Runs configure with cross-triple
4. Compiles and strips
5. Verifies GLIBC symbols (must be ≥ 2.17)
6. Outputs `./zip` (~196KB)

## Cross-Compilation Mechanics

### Meson Cross-File

Located at: `build/weston/crossfile.meson`

Tells Meson about the target architecture:
```meson
[binaries]
c = 'aarch64-nextui-linux-gnu-gcc'
cpp = 'aarch64-nextui-linux-gnu-g++'
ar = 'aarch64-nextui-linux-gnu-ar'
ld = 'aarch64-nextui-linux-gnu-ld'

[properties]
c_args = ['-O3', '-march=armv8-a']
c_link_args = ['-Wl,-rpath-link,/workspace/build/weston/prefix/lib']

[paths]
prefix = '/workspace/build/weston/prefix'
libdir = 'lib'
```

### pkg-config Configuration

Cross-compilation requires special pkg-config setup:

```bash
export PKG_CONFIG_SYSROOT_DIR=/opt/.../libc
export PKG_CONFIG_PATH=/workspace/build/weston/prefix/lib/pkgconfig
export PKG_CONFIG_LIBDIR=/workspace/build/weston/prefix/lib/pkgconfig:\
  /opt/.../libc/usr/lib/pkgconfig
```

This ensures:
1. `pc` files are found in both prefix (newly built deps) and sysroot (system libs)
2. Include/lib paths point to cross-compilation targets
3. Native build tools (on macOS/Linux host) are NOT used

## Binaries & Linkage

### Dynamic vs Static

All binaries in this build are **dynamically linked**:
- Easier to update (change library, not binary)
- Smaller on disk
- Requires GLIBC >= 2.17 on device

Example for weston-launch:
```bash
$ aarch64-linux-gnu-readelf -d ./build/weston/prefix/bin/weston-launch | grep NEEDED
NEEDED libpam.so.0
NEEDED libdrm.so.2
NEEDED libc.so.6
```

### GLIBC Verification

Ensuring compatibility with device (GLIBC 2.17+):

```bash
# Check symbols used by zip binary
strings ./zip | grep GLIBC_

# Output should be: GLIBC_2.17 (or higher versions like 2.27, 2.29)
# If shows 2.31+, binary may not work on older GLIBC
```

## Caching & Rebuilding

### Stamp Files

`.build/weston/.stamps/` markers track completed builds:
- `libdrm`: libdrm is built
- `cairo`: cairo is built
- `weston`: weston is built
- etc.

If stamp exists, Make skips that target.

### Force Rebuild

```bash
# Rebuild one component
rm .stamps/libxkbcommon && make weston

# Rebuild everything
make clean && make weston

# Rebuild just Weston (keep deps)
make clean-weston && make weston
```

## Differences from Native Build

| Aspect | Native | Cross |
|--------|--------|-------|
| **Compiler** | gcc (host) | aarch64-...-gcc (cross) |
| **Sysroot** | System `/usr` | Explicit sysroot path |
| **Tests** | `make test` works | Tests disabled (ARM binary) |
| **Graphics** | libGL, Mesa | Not available (SDK minimal) |
| **Linking** | Native libs | Sysroot libs only |

## Troubleshooting

### "command not found: aarch64-nextui-linux-gnu-gcc"

**Cause**: Running outside container or toolchain not in PATH

**Fix**: Always use `docker exec weston-build` or `make` targets

### "ERROR: Cannot find -lpam"

**Cause**: Linux-PAM not installed in SYSROOT

**Fix**:
```bash
docker exec weston-build bash llm/toolchain/tg5040-toolchain/support/build-linux-pam.sh
```

### "Dependency 'gbm' not found"

**Cause**: Optional graphics feature requires library not in SDK

**Fix**: Disable feature in Meson flags:
```makefile
-Drenderer-gl=false      # Disable OpenGL renderer
-Dbackend-drm=true       # Use DRM backend instead
```

### Binary works on macOS but not on device

**Likely cause**: Binary is host (x86_64), not target (aarch64)

**Check**:
```bash
file ./zip
# Should show: aarch64, not x86_64
```

### GLIBC symbol mismatch

**Symptom**: "version `GLIBC_2.34' not found" on device

**Cause**: Binary compiled for newer GLIBC than device has

**Check**:
```bash
strings ./binary | grep GLIBC_ | sort
```

Should all be <= 2.17 for TrimUI compatibility

## Advanced: Adding New Dependencies

To add a library (e.g., libpng for image support):

1. **Download tarball** to `build/weston/src/libpng-X.Y.Z.tar.xz`

2. **Add Makefile target**:
```makefile
$(STAMPS)/libpng: $(STAMPS)/zlib | $(STAMPS)
    @$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
        cd $(WORKDIR)/build/weston/build; \
        rm -rf libpng-X.Y.Z && tar xf $(WORKDIR)/build/weston/src/libpng-X.Y.Z.tar.xz; \
        cd libpng-X.Y.Z; \
        ./configure --host=aarch64-nextui-linux-gnu --prefix=\$$PREFIX ...; \
        make -j$$(nproc) install"
    @touch $@
```

3. **Add to weston dependencies**:
```makefile
$(STAMPS)/weston: $(STAMPS)/cairo $(STAMPS)/libpng | $(STAMPS)
```

4. **Rebuild**:
```bash
make clean && make weston
```

## References

- [Meson Cross-Compilation](https://mesonbuild.com/Cross-compilation.html)
- [GCC Cross-Compilation](https://gcc.gnu.org/onlinedocs/)
- [pkg-config for Cross-Compilation](https://www.freedesktop.org/wiki/Software/pkg-config/)
- [GNU Autotools Cross-Compilation](https://autotools.io/autoconf/cross-compiling.html)

---

**Last Updated**: January 8, 2026  
**Toolchain**: aarch64-nextui-linux-gnu (GCC 8.3.0, GLIBC 2.17+)  
**Target**: TrimUI aarch64
