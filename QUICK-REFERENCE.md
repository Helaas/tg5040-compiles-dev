# Build System Quick Reference

## One-Liner Builds

```bash
# Build everything (Weston + dependencies + weston-launch)
make weston

# Build InfoZip 3.0 aarch64
make zip

# Build X11 server + libraries (PowerVR optimized)
make x11-download && make x11

# Verify all are correct and linked properly
make verify-artifacts && make verify-x11
```

## Deployment

```bash
# Create archive
make bundle

# Deploy to device
make deploy

# Or setup weston-launch setuid manually
./setup-weston-launch.sh
```

## Cleaning

```bash
# Clean everything
make clean

# Keep deps, rebuild just Weston
make clean-weston && make weston

# Keep everything except zip
make clean-zip && make zip

# Keep everything except X11
make clean-x11 && make x11
```

## Verification

```bash
# Check weston-launch
file build/weston/prefix/bin/weston-launch
# Output: ELF 64-bit LSB executable, ARM aarch64

# Check weston-launch links PAM
docker exec weston-build aarch64-nextui-linux-gnu-readelf -d \
  /workspace/build/weston/prefix/bin/weston-launch | grep NEEDED

# Check zip GLIBC
strings ./zip | grep GLIBC_
# Output: GLIBC_2.17 (or higher)
```

## Artifacts Location

| Artifact | Path | Size | Type |
|----------|------|------|------|
| weston-launch | `build/weston/prefix/bin/weston-launch` | ~33KB | aarch64 binary |
| zip | `./zip` | ~196KB | aarch64 binary |
| Xvfb (X11) | `build/weston/prefix/bin/Xvfb` | ~3MB | aarch64 binary |
| X11 libs | `build/weston/prefix/lib/libX11*` | ~4MB | aarch64 shared libs |
| OpenGL (Mesa) | `build/weston/prefix/lib/libGL*` | ~8MB | aarch64 shared libs |
| Full bundle | `build/weston/weston.tar.gz` | Variable | Compressed archive |

## Dependencies

All built and cached in `build/weston/prefix/`:
- libwayland 1.22.0
- libdrm 2.4.120
- libinput 1.25.0
- libxkbcommon 1.6.0
- cairo 1.16.0
- seatd/libseat 0.8.0
- Linux-PAM 1.5.3 (in SYSROOT)

### X11 Dependencies (if building X11)
- xcb-proto 1.17.0
- libxcb 1.16
- mesa 23.3.5 (OpenGL ES)
- libX11 1.8.7
- libXext 1.3.5
- libXrender 0.9.11
- Xorg Server 1.20.14 (Xvfb backend)

## Container

```bash
# Start/restart build container
docker start weston-build

# Check if running
docker ps | grep weston-build

# View logs
docker logs weston-build

# Shell into container
docker exec -it weston-build bash
```

## Customization

### Change Weston options

Edit the `$(STAMPS)/weston` target in `Makefile`, then:
```bash
make clean-weston && make weston
```

### Update component versions

Edit `TARBALLS` in `Makefile`, then:
```bash
make clean && make weston
```

### Rebuild single dependency

```bash
rm .build/weston/.stamps/libxkbcommon
make weston  # Rebuilds libxkbcommon and weston only
```

## Help & Documentation

```bash
# Show all targets
make help

# weston-launch setup guide
cat WESTON-LAUNCH-SETUP.md

# InfoZip build details
cat INFOZIP-BUILD-README.md

# Full system documentation
cat README.md
```

## Troubleshooting

**Container not found:**
```bash
make container
```

**weston-launch won't build (libpam missing):**
```bash
docker exec weston-build bash llm/toolchain/tg5040-toolchain/support/build-linux-pam.sh
make clean-weston && make weston
```

**Need to inspect build output:**
```bash
docker exec weston-build cat /workspace/build/weston/build/weston-10.0.4/_build/meson-logs/meson-log.txt
```

**Verify adb is working:**
```bash
adb devices
```

---

**Created**: January 8, 2026  
**Weston Version**: 10.0.4  
**InfoZip Version**: 3.0  
**Target**: aarch64 (TrimUI)
