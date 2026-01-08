# Build System Overview

This workspace contains independent build systems for **Weston** (compositor) and **X11** (display server).

## Quick Start

### Build Weston (compositor only)
```bash
make weston          # Full Weston with weston-launch
make weston-launch   # Just weston-launch
make zip             # InfoZip 3.0 utility
```

### Build X11 (display server)
```bash
cd build/x11
make x11             # Full X11 stack (Xvfb + OpenGL)
make verify-x11      # Verify build succeeded
```

## Project Structure

```
├── Makefile                      # Root build (Weston + InfoZip only)
├── build-x11.sh                  # X11 source downloader
├── build/
│   ├── weston/                   # Weston compositor build
│   │   ├── src/                  # Weston + dependencies sources
│   │   ├── build/                # Build intermediates
│   │   ├── prefix/               # Installation prefix
│   │   ├── .stamps/              # Build state tracking
│   │   ├── crossfile.meson       # Meson cross-compile config
│   │   └── native.meson          # Meson native config
│   │
│   └── x11/                      # X11 display server (SEPARATE)
│       ├── Makefile              # X11-specific build rules
│       ├── src/                  # X11 sources (9 tarballs, ~35MB)
│       ├── build/                # Build intermediates
│       ├── prefix/               # Installation prefix
│       └── .stamps/              # Build state tracking
│
└── Documentation/
    ├── X11-README.md             # X11 build guide
    ├── X11-CLEANUP-SUMMARY.md    # Separation details
    ├── QUICK-REFERENCE.md        # Build cheat sheet
    ├── BUILD-SUMMARY.md          # Historical progress
    └── [other docs]
```

## What's Built

### Weston Build (InfoZip + Weston compositor)
- **zip**: InfoZip 3.0 aarch64 binary with GLIBC ≥ 2.17
- **weston-launch**: Secure launcher with libpam integration
- **weston**: Full compositor with:
  - DRM backend (GPU support)
  - Framebuffer backend (fallback)
  - libseat integration (multi-seat)
  - Wayland protocol support

### X11 Build (Independent)
- **Xvfb**: Virtual framebuffer X11 server
- **libX11**: X11 core library
- **libGL**: Mesa OpenGL ES 2.0+ with software rasterizer
- **libXext**, **libXrender**: X11 extensions
- Supporting libs: libxcb, libXau, xcb-proto, xproto

## Build System Details

### Toolchain
- **Image**: `ghcr.io/loveretro/tg5040-toolchain:latest`
- **Container**: `weston-build`
- **Target**: `aarch64-nextui-linux-gnu`
- **Compiler**: GCC 8.3.0
- **GLIBC**: ≥ 2.17

### Cross-Compilation
- **Host**: x86_64 (macOS/Linux)
- **Target**: aarch64 (Android tablet device)
- **SYSROOT**: `/opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc`
- **Methods**: Meson (Weston), Autotools (X11), cargo (InfoZip)

### Device Specs
- **CPU**: aarch64 quad-core (NEON/AES/SHA support)
- **GPU**: PowerVR (pvrsrvkm driver, DRM render node at /dev/dri/renderD128)
- **Display**: Framebuffer-based (no native X11)

## Key Files

| File | Purpose |
|------|---------|
| `Makefile` | Root build orchestration (Weston + zip) |
| `build/x11/Makefile` | X11-specific build rules |
| `build-x11.sh` | Download X11 sources |
| `build/weston/crossfile.meson` | Meson cross-compile config |
| `build/weston/native.meson` | Meson native build config |

## Build Targets

### Root Makefile
```make
all              # Default: build weston
weston           # Full Weston compositor
weston-launch    # Launcher binary only
zip              # InfoZip 3.0 utility
deps             # Build all dependencies (internal)
verify-artifacts # Verify built binaries
clean-weston     # Remove Weston build
clean-zip        # Remove InfoZip
clean            # Remove everything
container        # Start Docker container
help             # Show all targets
```

### X11 Makefile (in build/x11/)
```make
x11              # Full X11 stack
x11-deps         # Libraries only
download         # Download sources
verify-x11       # Verify build
clean-x11        # Clean X11 build
clean            # Clean all
help             # Show targets
```

## Build Characteristics

- **Reproducible**: All builds use specific versions and stamped targets
- **Cross-compiled**: Optimized for aarch64 PowerVR GPU
- **Headless**: No native display (Xvfb virtual, Weston headless mode)
- **Minimal**: Disabled unused features (X11 GLX, Wayland on Weston, etc.)
- **Separated**: Weston and X11 build in completely independent directories
- **Containerized**: Docker container handles all compilation

## Artifacts Location

### After Building

**Weston**:
```
build/weston/prefix/
├── bin/
│   ├── weston                    # Compositor
│   ├── weston-launch             # Launcher
│   └── ...
├── lib/
│   ├── libweston-10.so           # Core library
│   ├── libwayland-*.so           # Wayland protocol
│   └── ...
└── share/
    └── weston/                   # Config/data
```

**X11** (separate):
```
build/x11/prefix/
├── bin/
│   ├── Xvfb                      # Virtual framebuffer server
│   └── ...
├── lib/
│   ├── libX11.so                 # X11 core
│   ├── libGL.so                  # Mesa OpenGL
│   ├── libxcb.so                 # X11 protocol
│   └── ...
└── include/
    └── X11/                      # Headers
```

## Common Tasks

### Build Everything
```bash
make weston
cd build/x11 && make x11
```

### Rebuild After Changes
```bash
make clean-weston
make weston
```

### Verify Builds
```bash
make verify-artifacts
cd build/x11 && make verify-x11
```

### Clean Everything
```bash
make clean
cd build/x11 && make clean
```

## Troubleshooting

**Docker container not running?**
```bash
docker run -it -d --name weston-build -v $(pwd):/workspace ghcr.io/loveretro/tg5040-toolchain:latest sleep infinity
```

**X11 build fails?**
```bash
cd build/x11
make clean-x11
make download         # Verify sources
make x11              # Retry
```

**Check container logs:**
```bash
docker logs weston-build | tail -100
```

## Related Documentation

- [X11-README.md](X11-README.md) - X11 build guide
- [X11-CLEANUP-SUMMARY.md](X11-CLEANUP-SUMMARY.md) - Separation details
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Command cheat sheet
- [CROSS-COMPILATION.md](CROSS-COMPILATION.md) - Details on cross-compilation setup
- [BUILD-SUMMARY.md](BUILD-SUMMARY.md) - Historical progress and versions

## Version Information

- **Weston**: 10.0.4
- **Wayland**: 1.22.0
- **InfoZip**: 3.0
- **Xorg Server**: 1.20.14
- **Mesa**: 23.3.5
- **libX11**: 1.8.7
- **Toolchain**: GCC 8.3.0, GLIBC 2.17+

---

**Last Updated**: January 8, 2026  
**Status**: ✅ Ready for production builds
