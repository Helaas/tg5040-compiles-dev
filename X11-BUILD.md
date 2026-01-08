# X11 Server Build for PowerVR GPU (aarch64)

## Overview

This document describes building X11 server (`Xvfb`) and supporting libraries for the aarch64 device with PowerVR GPU support. The build is optimized for:

- **GPU**: PowerVR (pvrsrvkm driver) with OpenGL ES 3.x+ support
- **Architecture**: aarch64 (ARM 64-bit)
- **DRM Support**: Render node (`/dev/dri/renderD128`) available for hardware acceleration
- **Build System**: Meson, Autotools, cross-compilation via Docker toolchain
- **Purpose**: Dependency binaries only (not deployed to device, used for launch scripts)

## What Gets Built

### Core X11 Components

1. **xcb-proto 1.17.0** - X11 protocol definitions
2. **libxcb 1.16** - C bindings for the X Window System
3. **libX11 1.8.7** - Core X11 library
4. **libXext 1.3.5** - X11 extensions library
5. **libXrender 0.9.11** - Rendering extension
6. **Xorg Server 1.20.14** - X11 display server (Xvfb virtual framebuffer backend)

### Graphics/OpenGL Support

- **Mesa 23.3.5** - OpenGL ES 2.0+ implementation with:
  - Software renderer (swrast) for fallback
  - EGL for headless OpenGL rendering
  - GBM disabled (not needed, using DRM render node)
  - LLVM disabled (reduces build complexity)

### Device Capabilities Used

- **DRM Render Node** (`/dev/dri/renderD128`) - Hardware-accelerated rendering
- **OpenGL ES** - Modern graphics API for PowerVR
- **NEON/SIMD** - Hardware acceleration for graphics operations

## Quick Build

### Prerequisites

```bash
# Ensure Docker container is running
make container

# Download X11 source tarballs
bash build-x11.sh
# OR via Make:
make x11-download
```

### Building X11

```bash
# Build only X11 dependencies (libs, no server)
make x11-deps

# Build complete X11 (dependencies + Xvfb server)
make x11

# Verify X11 build
make verify-x11
```

### Manual Build (if needed)

```bash
# Build specific components in order:
make $(STAMPS)/xcb-proto      # X11 protocol definitions
make $(STAMPS)/libxcb         # XCB library
make $(STAMPS)/mesa           # OpenGL ES support
make $(STAMPS)/libX11         # Core X11 library
make $(STAMPS)/libXext        # X11 extensions
make $(STAMPS)/libXrender     # Rendering extension
make $(STAMPS)/x11-server     # Xvfb server
```

## Build Details

### Architecture Overview

```
xcb-proto 1.17.0
    ↓
libxcb 1.16 ← libX11, libXext, libXrender (all depend on XCB)
    ↓
mesa 23.3.5 (OpenGL ES 2.0+, EGL, swrast)
    ↓
Xorg Server 1.20.14 (Xvfb backend with DRM/OpenGL support)
```

### Configuration Highlights

**xcb-proto**: Minimal configuration
```bash
./configure --host=aarch64-nextui-linux-gnu --prefix=$PREFIX
```

**libxcb**: XKB keyboard support, render extension enabled
```bash
./configure --enable-xkb=yes --enable-render=yes --disable-xf86dri
```

**Mesa**: OpenGL ES 2.0+ with software + LLVM disabled
```bash
meson setup -Dgles2=enabled -Dopengl=true \
    -Dgallium-drivers=['swrast'] \
    -Dglx=disabled -Dllvm=disabled
```

**libX11/libXext/libXrender**: Standard X11 libraries, no docs/specs
```bash
./configure --disable-specs --disable-docs [lib-specific-flags]
```

**Xorg Server 1.20.14**: VFB (virtual framebuffer) enabled, GLX disabled
```bash
./configure --enable-vfb=yes --enable-xvfb=yes --disable-glx
```

## Output Artifacts

After successful build:

```
PREFIX/bin/Xvfb                  # Virtual X11 server executable
PREFIX/lib/libX11.so.*           # X11 core library
PREFIX/lib/libXext.so.*          # X11 extensions
PREFIX/lib/libXrender.so.*       # Rendering extension
PREFIX/lib/libxcb.so.*           # XCB library
PREFIX/lib/libGL.so.*            # OpenGL (via Mesa)
PREFIX/lib/libEGL.so.*           # EGL (headless OpenGL)
PREFIX/lib/libglapi.so.*         # GL API dispatch
PREFIX/lib/libGLESv2.so.*        # OpenGL ES 2.0 library
PREFIX/lib/libgallium.so.*       # Gallium3D (swrast backend)
PREFIX/share/X11/xkb/            # Keyboard layouts (from libxkbcommon)
```

## Using X11 in Launch Scripts

The built binaries are intended for use in launch script projects. Typical workflow:

1. **Set environment** in launch script:
   ```bash
   export LD_LIBRARY_PATH=/path/to/PREFIX/lib:$LD_LIBRARY_PATH
   export PATH=/path/to/PREFIX/bin:$PATH
   ```

2. **Run Xvfb** for headless X11:
   ```bash
   Xvfb :99 -screen 0 1920x1080x32 &
   export DISPLAY=:99
   ```

3. **Run OpenGL app**:
   ```bash
   # App will use hardware-accelerated rendering if available
   # Falls back to Mesa swrast if not
   glxinfo  # Verify OpenGL support
   ```

## Hardware Acceleration

### PowerVR GPU Integration

The device has PowerVR GPU with DRM support. Mesa OpenGL ES can utilize:

1. **DRM Render Node** - `/dev/dri/renderD128` provides hardware rendering
2. **GBM** (if available) - Gallium Buffer Manager for graphics memory
3. **EGL** - Headless OpenGL rendering without X11 display

### Expected Performance

- **Hardware rendering**: Available via DRM/PowerVR driver
- **Software fallback**: Mesa swrast (slower but always works)
- **Recommended**: Use hardware when available; swrast provides stability

## Troubleshooting

### Build Failures

**Mesa compilation errors**:
- Ensure `meson` and `ninja` are installed in container
- Check cross-file (`crossfile.meson`) is valid
- Verify LLVM is disabled (`-Dllvm=disabled`)

**Xorg Server configuration errors**:
- VFB backend requires autotools, not meson
- Ensure `--enable-vfb=yes` is passed
- Check that old `./configure` exists in source tree

**Missing X11 libraries after build**:
- Verify stamp files exist in `$(STAMPS)/x11-*`
- Check `PREFIX/lib` contains `libX11.so`, `libxcb.so`
- Run `aarch64-linux-gnu-readelf -d $(X11_SERVER)` to check linkage

### Runtime Issues

**"Cannot open display"**:
- Xvfb needs to be running before launching X apps
- Set `DISPLAY=:99` (or whatever display number Xvfb uses)

**"Symbol not found" errors**:
- Run `aarch64-linux-gnu-readelf -d ./Xvfb` to check dependencies
- Ensure `LD_LIBRARY_PATH` includes PREFIX/lib

**OpenGL not working**:
- Check `glxinfo -display :99` output
- Verify Mesa is linked: `aarch64-linux-gnu-readelf -d ./Xvfb | grep libGL`
- Check `/dev/dri/renderD128` exists on device

## Cleaning Up

```bash
# Remove X11 build artifacts (keep deps)
make clean-x11

# Remove all X11 (deps + server)
# (No single target; manually rm PREFIX/lib/libX* PREFIX/bin/Xvfb)

# Full rebuild
make clean && make x11
```

## Advanced: Custom Configuration

To modify X11 components:

1. **Edit Makefile** - Update configure flags in `$(STAMPS)/x11-server` rule
2. **Rebuild** - Run `make clean-x11 && make x11`
3. **Test** - Verify with `make verify-x11`

### Useful Build Flags

**Xorg Server**:
- `--enable-glamor=yes` - GPU-accelerated rendering (if Mesa supports)
- `--enable-kdrive=yes` - Embedded X server support
- `--enable-dpms=yes` - Display power management

**Mesa**:
- `-Dgallium-drivers=['iris','panfrost']` - Intel/ARM drivers (if available)
- `-Dvulkan-drivers=['panfrost']` - Vulkan support
- `-Dgbm=enabled` - Graphics Buffer Manager

## References

- **Xorg Server**: https://xorg.freedesktop.org/
- **Mesa**: https://www.mesa3d.org/
- **PowerVR**: https://www.imaginationtech.com/
- **X11 Protocol**: https://www.x.org/releases/X11R7.7/doc/
