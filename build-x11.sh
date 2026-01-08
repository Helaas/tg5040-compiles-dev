#!/bin/bash
# Download X11 source tarballs for cross-compilation
# PowerVR GPU optimized with OpenGL ES support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/build/x11/src"

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# Define downloads as array of "filename:url" pairs
DOWNLOADS=(
    "xorg-server-1.20.14.tar.gz:https://www.x.org/archive/individual/xserver/xorg-server-1.20.14.tar.gz"
    "xorgproto-2024.1.tar.xz:https://www.x.org/archive/individual/proto/xorgproto-2024.1.tar.xz"
    "xtrans-1.6.0.tar.gz:https://www.x.org/archive/individual/lib/xtrans-1.6.0.tar.gz"
    "libX11-1.8.7.tar.gz:https://www.x.org/archive/individual/lib/libX11-1.8.7.tar.gz"
    "libXext-1.3.5.tar.gz:https://www.x.org/archive/individual/lib/libXext-1.3.5.tar.gz"
    "libXrender-0.9.11.tar.gz:https://www.x.org/archive/individual/lib/libXrender-0.9.11.tar.gz"
    "libXfixes-6.0.1.tar.gz:https://www.x.org/archive/individual/lib/libXfixes-6.0.1.tar.gz"
    "libXcursor-1.2.2.tar.gz:https://www.x.org/archive/individual/lib/libXcursor-1.2.2.tar.gz"
    "libepoxy-1.5.10.tar.gz:https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz"
    "libXfont2-2.0.7.tar.gz:https://www.x.org/archive/individual/lib/libXfont2-2.0.7.tar.gz"
    "libfontenc-1.1.8.tar.gz:https://www.x.org/archive/individual/lib/libfontenc-1.1.8.tar.gz"
    "libxkbfile-1.1.3.tar.gz:https://www.x.org/archive/individual/lib/libxkbfile-1.1.3.tar.gz"
    "xproto-7.0.31.tar.gz:https://www.x.org/archive/individual/proto/xproto-7.0.31.tar.gz"
    "libXau-1.0.12.tar.gz:https://www.x.org/archive/individual/lib/libXau-1.0.12.tar.gz"
    "libxcb-1.16.tar.xz:https://xcb.freedesktop.org/dist/libxcb-1.16.tar.xz"
    "xcb-proto-1.17.0.tar.xz:https://xcb.freedesktop.org/dist/xcb-proto-1.17.0.tar.xz"
    "pixman-0.42.2.tar.gz:https://www.x.org/archive/individual/lib/pixman-0.42.2.tar.gz"
    "util-macros-1.20.2.tar.gz:https://www.x.org/archive/individual/util/util-macros-1.20.2.tar.gz"
    "mesa-23.3.5.tar.xz:https://archive.mesa3d.org/mesa-23.3.5.tar.xz"
)

echo "=== Downloading X11 source tarballs ==="
echo "Destination: $SRC_DIR"
echo ""

for entry in "${DOWNLOADS[@]}"; do
    filename="${entry%:*}"
    url="${entry#*:}"
    
    if [ -f "$filename" ]; then
        echo "✓ $filename (already present)"
    else
        echo "⏳ Downloading $filename..."
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL -o "$filename.tmp" "$url" || {
                echo "✗ Failed to download $filename"
                rm -f "$filename.tmp"
                exit 1
            }
            mv "$filename.tmp" "$filename"
        elif command -v wget >/dev/null 2>&1; then
            wget --quiet -O "$filename" "$url" || {
                echo "✗ Failed to download $filename"
                exit 1
            }
        else
            echo "✗ Neither curl nor wget found"
            exit 1
        fi
        echo "✓ Downloaded $filename"
    fi
done

echo ""
echo "All X11 tarballs ready. Run 'make x11' to build."
