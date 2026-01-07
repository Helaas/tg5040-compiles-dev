# InfoZip 3.0 Build for TrimUI TG5040

This directory contains the build script for creating a GLIBC 2.17-compatible `zip` binary for the TrimUI TG5040 device (ARM aarch64).

## Quick Start

```bash
./build-infozip.sh
```

This will:
1. Download InfoZip 3.0 source from SourceForge
2. Build the Docker cross-compilation toolchain (if not already built)
3. Cross-compile `zip` for aarch64 with static linking
4. Output the binary to `./zip`

## Requirements

- Docker installed and running
- ~2GB of free disk space
- Internet connection (for first-time setup)

## Technical Details

### Target Platform
- **Device**: TrimUI TG5040
- **Architecture**: ARM aarch64 (64-bit)
- **GLIBC**: 2.33 (requires binaries compatible with ≥2.17)

### Build Configuration
- **Source**: InfoZip 3.0
- **Compilation**: Static linking (no dynamic library dependencies)
- **Toolchain**: GCC 8.3 aarch64 cross-compiler
- **Flags**: `-O2 -static -DNO_BZIP2_SUPPORT`

### Why Static Linking?
The TrimUI device has GLIBC 2.33, but standard Debian binaries require GLIBC 2.34+. By statically linking the binary:
- No external library dependencies
- Maximum compatibility across GLIBC versions
- Self-contained binary that works on the device

## Verification

After building, verify the binary:

```bash
# Check architecture
file ./zip
# Output should show: ELF 64-bit LSB executable, ARM aarch64

# Check GLIBC requirements (static binaries may not show this)
strings ./zip | grep GLIBC

# Check size
ls -lh ./zip
```

## Usage on Device

Transfer the `zip` binary to your TrimUI device and use it like:

```bash
# Make executable
chmod +x ./zip

# Use it
./zip -q -r output.jar input_directory/
```

## Troubleshooting

### Docker build fails with memory error
Increase Docker's memory limit in Docker Desktop settings (Preferences → Resources → Memory). Recommended: 4GB minimum.

### Download fails
InfoZip 3.0 is hosted on SourceForge. If downloads fail:
1. Manually download from: https://sourceforge.net/projects/infozip/files/Zip%203.x%20%28latest%29/3.0/zip30.tar.gz
2. Place it in: `llm/toolchain/tg5040-toolchain/workspace/zip30.tar.gz`
3. Re-run the build script

### Binary doesn't work on device
Check GLIBC compatibility:
```bash
# On your Mac/Linux
strings ./zip | grep GLIBC_

# All versions should be ≤ 2.33
```

If you see GLIBC_2.34 or higher, the binary needs to be rebuilt with stricter compatibility flags.

## Clean Build

To start fresh:

```bash
rm -rf llm/toolchain/tg5040-toolchain/workspace/zip30
rm -rf llm/toolchain/tg5040-toolchain/workspace/zip30.tar.gz
rm -f ./zip
./build-infozip.sh
```

## Alternative: Manual Build

If you prefer to build manually:

1. Enter the toolchain environment:
```bash
cd llm/toolchain/tg5040-toolchain
make shell
```

2. Inside the container:
```bash
cd ~/workspace
wget https://sourceforge.net/projects/infozip/files/Zip%203.x%20%28latest%29/3.0/zip30.tar.gz
tar -xzf zip30.tar.gz
cd zip30

make -f unix/Makefile generic \
    CC="${CROSS_TRIPLE}-gcc" \
    CFLAGS="-O2 -DNO_BZIP2_SUPPORT" \
    LDFLAGS="-static" \
    -j$(nproc)

${CROSS_TRIPLE}-strip zip
cp zip ~/workspace/
```

3. Exit the container and find your binary in:
```
llm/toolchain/tg5040-toolchain/workspace/zip
```

## Files

- `build-infozip.sh` - Main build script
- `zip` - Output binary (created after successful build)
- `llm/toolchain/tg5040-toolchain/workspace/` - Build workspace (temporary files)

## License

InfoZip is distributed under the Info-ZIP License. See the InfoZip source code for details.

## Credits

- InfoZip: https://infozip.sourceforge.net/
- TrimUI TG5040 Toolchain: https://github.com/LoveRetro/gcc-arm-8.3-aarch64-tg5040
