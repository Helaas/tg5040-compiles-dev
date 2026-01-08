# X11 Build System (Separate from Weston)

## Overview

X11 is now built in a completely separate directory structure (`/build/x11/`) instead of being mixed with the Weston compositor build. This provides:

- **Cleaner separation of concerns** - X11 and Weston are distinct display servers
- **Independent build management** - Each has its own Makefile, sources, and prefix
- **Easier debugging** - Failures in X11 don't affect Weston build cache
- **Parallel development** - Can work on each independently

## Directory Structure

```
build/
├── weston/                     # Weston compositor (unchanged)
│   ├── src/                    # Weston + deps sources only
│   ├── build/                  # Build intermediates
│   ├── prefix/                 # Weston install prefix
│   └── .stamps/                # Build state tracking
│
└── x11/                        # X11 stack (NEW - separate)
    ├── src/                    # X11 sources only (~35MB)
    ├── build/                  # Build intermediates
    ├── prefix/                 # X11 install prefix
    ├── .stamps/                # Build state tracking
    └── Makefile                # X11-specific build rules
```

## Building X11

### From root directory:

```bash
# Download sources (one-time)
cd build/x11
make download

# Build X11 stack
make x11              # Full X11 stack (Xorg server + libs)
make x11-deps         # Just libraries and dependencies
make verify-x11       # Verify build succeeded
make clean-x11        # Remove build, keep sources
```

### Or use the X11 Makefile directly:

```bash
cd build/x11
make help             # Show available targets
make x11
```

## X11 Components

Built in dependency order:

1. **xcb-proto** (1.17.0) - X11 protocol definitions
2. **xproto** (7.0.31) - X11 core protocol headers
3. **libXau** (1.0.12) - X11 authority library
4. **libxcb** (1.16) - X11 protocol bindings
5. **mesa** (23.3.5) - OpenGL ES 2.0+ with swrast fallback
6. **libX11** (1.8.7) - X11 core library
7. **libXext** (1.3.5) - X11 extensions
8. **libXrender** (0.9.11) - X11 render extension
9. **xorg-server** (1.20.14) - X11 server (Xvfb for headless)

## Artifacts

After successful build, X11 binaries and libraries are in:

```
build/x11/prefix/
├── bin/
│   └── Xvfb           # Virtual framebuffer X server
├── lib/
│   ├── libX11.so*     # X11 core library
│   ├── libXext.so*    # X11 extensions
│   ├── libXrender.so* # X11 render library
│   ├── libGL.so*      # Mesa OpenGL (ES 2.0 + swrast)
│   └── ...
└── include/
    └── X11/           # X11 headers
```

## Configuration

### Cross-Compilation Setup

The X11 build uses the same toolchain as Weston:
- **Toolchain**: `ghcr.io/loveretro/tg5040-toolchain:latest`
- **Architecture**: `aarch64-nextui-linux-gnu`
- **SYSROOT**: `/opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc`

### GPU Optimization

Mesa is configured for:
- **OpenGL ES 2.0+** support (primary rendering API)
- **Software rasterizer** (swrast) as fallback
- **No GLX** (headless/framebuffer only)
- **PowerVR GPU acceleration** available via DRM render nodes

## Cleanup

```bash
# Remove X11 build files (keep sources)
cd build/x11 && make clean

# Or just specific components
rm -rf build/x11/build/*
rm -rf build/x11/prefix/lib/libX11* build/x11/prefix/lib/libGL*
```

## Notes

- Weston build is **unaffected** - X11 tarballs removed from `/build/weston/src/`
- Weston Makefile **no longer includes** X11 targets
- X11 sources are in `/build/x11/src/` (~35MB total)
- Both systems use the same Docker container but separate prefix directories
- `make` from root directory now **only builds Weston** (use `cd build/x11 && make` for X11)

## Troubleshooting

If X11 build fails:

1. Check Docker container is running: `docker ps | grep weston-build`
2. Check sources are present: `ls build/x11/src/*.tar*`
3. Clean and retry: `cd build/x11 && make clean && make x11`
4. Check logs: `docker logs weston-build | tail -50`

## Related

- **Weston**: `make weston` (from root) - builds compositor
- **InfoZip**: `make zip` (from root) - builds compression utility
- **Cross-compilation**: See [CROSS-COMPILATION.md](CROSS-COMPILATION.md)
