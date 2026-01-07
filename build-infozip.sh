#!/bin/bash

# InfoZip 3.0 Cross-Compilation Script for TrimUI TG5040
# Builds a statically-linked zip binary compatible with GLIBC 2.17+

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFOZIP_VERSION="30"
INFOZIP_URL="https://sourceforge.net/projects/infozip/files/Zip%203.x%20%28latest%29/3.0/zip30.tar.gz"
BUILD_DIR="$SCRIPT_DIR/build/infozip"
OUTPUT_BINARY="$SCRIPT_DIR/zip"
WORKSPACE_DIR="$SCRIPT_DIR/llm/toolchain/tg5040-toolchain/workspace"
TOOLCHAIN_DIR="$SCRIPT_DIR/llm/toolchain/tg5040-toolchain"

# Colors for output
BOLD=$(tput bold 2>/dev/null || echo "")
GREEN=$(tput setaf 2 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
NORM=$(tput sgr0 2>/dev/null || echo "")

echo "${BOLD}${GREEN}==> Building InfoZip 3.0 for aarch64${NORM}"

# Create workspace directory if it doesn't exist
mkdir -p "$WORKSPACE_DIR"

# Download and extract InfoZip source
echo "${BOLD}==> Downloading InfoZip 3.0...${NORM}"
if [ ! -f "$WORKSPACE_DIR/zip30.tar.gz" ]; then
    curl -L --progress-bar "$INFOZIP_URL" -o "$WORKSPACE_DIR/zip30.tar.gz"
fi

echo "${BOLD}==> Extracting source...${NORM}"
rm -rf "$WORKSPACE_DIR/zip30"
cd "$WORKSPACE_DIR"
tar -xzf zip30.tar.gz

# Create build script to run inside Docker container
cat > "$WORKSPACE_DIR/build-zip-internal.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

cd ~/workspace/zip30

# Configure for cross-compilation with static linking
# InfoZip uses a simple Makefile-based build system
# We need to set the compiler and flags for cross-compilation

# Set compiler and flags for aarch64 with GLIBC 2.17 compatibility
export CC="${CROSS_TRIPLE}-gcc"
export CPP="${CROSS_TRIPLE}-cpp"
export LD="${CROSS_TRIPLE}-ld"

# Build with generic Unix target, static linking
# -static: Create statically linked binary
# -O2: Optimize
# NO_BZIP2_SUPPORT: Don't require bzip2 library
make -f unix/Makefile generic \
    CC="$CC" \
    CFLAGS="-O2 -DNO_BZIP2_SUPPORT" \
    LDFLAGS="-static" \
    -j$(nproc)

# Strip the binary to reduce size
${CROSS_TRIPLE}-strip zip

# Copy to output location
cp zip ~/workspace/zip-binary

echo ""
echo "==> Build complete!"
echo "==> Binary location: ~/workspace/zip-binary"
echo ""
echo "==> Verifying binary..."
file ~/workspace/zip-binary
echo ""
echo "==> Checking GLIBC version requirements..."
${CROSS_TRIPLE}-readelf -V ~/workspace/zip-binary | grep -A 10 "Version needs section" || true
echo ""
echo "==> Checking symbols..."
${CROSS_TRIPLE}-nm -D ~/workspace/zip-binary 2>/dev/null | head -20 || echo "Static binary (no dynamic symbols)"

EOF

chmod +x "$WORKSPACE_DIR/build-zip-internal.sh"

# Build using Docker toolchain
echo "${BOLD}==> Building toolchain Docker image (if needed)...${NORM}"
cd "$TOOLCHAIN_DIR"

# Check if Docker image exists
IMAGE_NAME="ghcr.io/loveretro/tg5040-modernize"
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "${BOLD}==> Building Docker image (this may take 10-15 minutes on first run)...${NORM}"
    mkdir -p ./workspace
    docker build -t "$IMAGE_NAME" .
    touch .build
else
    echo "${BOLD}==> Docker image already built${NORM}"
fi

# Run the build inside the Docker container
echo "${BOLD}==> Running build in container...${NORM}"
docker run --rm \
    -v "$WORKSPACE_DIR":/root/workspace \
    "$IMAGE_NAME" \
    /bin/bash -c "/root/workspace/build-zip-internal.sh"

# Copy the binary to the final location
if [ -f "$WORKSPACE_DIR/zip-binary" ]; then
    cp "$WORKSPACE_DIR/zip-binary" "$OUTPUT_BINARY"
    echo ""
    echo "${BOLD}${GREEN}==> Success! Binary copied to: $OUTPUT_BINARY${NORM}"
    echo ""
    echo "${BOLD}==> Final verification:${NORM}"
    file "$OUTPUT_BINARY"
    ls -lh "$OUTPUT_BINARY"
    echo ""
    echo "${YELLOW}Note: If you need to verify GLIBC requirements, run:${NORM}"
    echo "  strings $OUTPUT_BINARY | grep GLIBC"
else
    echo "${BOLD}Error: Build failed, binary not found${NORM}" >&2
    exit 1
fi
