SHELL := /bin/bash

# Paths
ROOT            := $(PWD)
BUILD_ROOT      := $(ROOT)/build/weston
SRC_DIR         := $(BUILD_ROOT)/src
BUILD_DIR       := $(BUILD_ROOT)/build
PREFIX          := $(BUILD_ROOT)/prefix
STAMPS          := $(BUILD_ROOT)/.stamps

# Toolchain / container
CONTAINER       ?= weston-build
TOOLCHAIN_IMAGE ?= ghcr.io/loveretro/tg5040-toolchain/tg5040-toolchain:latest
WORKDIR         := /workspace

# Cross/meson config paths as seen inside the container
CROSSFILE       := $(WORKDIR)/build/weston/crossfile.meson
NATIVEFILE      := $(WORKDIR)/build/weston/native.meson
SYSROOT         := /opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc
PKG_PATH        := $(WORKDIR)/build/weston/prefix/lib/pkgconfig:$(WORKDIR)/build/weston/prefix/share/pkgconfig:$(WORKDIR)/build/x11/prefix/lib/pkgconfig:$(WORKDIR)/build/x11/prefix/share/pkgconfig

# Helpers
DOCKER_EXEC     = docker exec $(CONTAINER) bash -lc
ENV_EXPORT      = export PREFIX=$(WORKDIR)/build/weston/prefix; \
                  export PKG_CONFIG_SYSROOT_DIR=$(SYSROOT); \
                  export PKG_CONFIG_PATH=$(PKG_PATH); \
                  export PKG_CONFIG_LIBDIR=$(PKG_PATH):$(SYSROOT)/usr/lib/pkgconfig:$(SYSROOT)/usr/share/pkgconfig;

TARBALLS = \
	$(SRC_DIR)/libdrm-2.4.120.tar.xz \
	$(SRC_DIR)/wayland-1.22.0.tar.xz \
	$(SRC_DIR)/wayland-protocols-1.36.tar.xz \
	$(SRC_DIR)/libevdev-1.13.1.tar.xz \
	$(SRC_DIR)/libinput-1.25.0.tar.gz \
	$(SRC_DIR)/xkeyboard-config-2.42.tar.xz \
	$(SRC_DIR)/libxkbcommon-1.6.0.tar.xz \
	$(SRC_DIR)/0.8.0.tar.gz \
	$(SRC_DIR)/cairo-1.16.0.tar.xz \
	$(SRC_DIR)/weston-10.0.4.tar.xz

# Artifacts
WESTON_LAUNCH   := $(PREFIX)/bin/weston-launch
ZIP_BINARY      := ./zip

.PHONY: all deps weston weston-launch zip x11 x11-deps x11-download x11-xwayland verify-artifacts verify-x11 bundle deploy container clean clean-weston clean-zip clean-x11 help

all: weston

help:
	@echo "Makefile targets:"
	@echo "  make weston           - Build Weston 10.0.4 + dependencies + weston-launch (default)"
	@echo "  make weston-launch    - Verify weston-launch binary exists and is correctly linked"
	@echo "  make zip              - Build InfoZip 3.0 aarch64 binary"
	@echo "  make x11              - Build X11 server + dependencies (PowerVR/OpenGL ES optimized)"
	@echo "  make x11-deps         - Build only X11 dependencies (libX11, libXext, libXrender, mesa)"
	@echo "  make x11-download     - Download X11 source tarballs"
	@echo "  make x11-xwayland     - Build Xwayland binary for Weston"
	@echo "  make verify-artifacts - Verify both weston-launch and zip binaries"
	@echo "  make verify-x11       - Verify X11 server binary and OpenGL support"
	@echo "  make clean-x11        - Remove only X11 build (keep sources)"
	@echo "  make bundle           - Create deployable tar.gz archive"
	@echo "  make deploy           - Deploy bundle to device via adb"
	@echo "  make clean            - Remove all build artifacts and stamps"
	@echo "  make clean-weston     - Remove only weston build (keep deps)"
	@echo "  make clean-zip        - Remove only zip binary"
	@echo "  make container        - Start/ensure build container is running"

$(STAMPS):
	@mkdir -p $(STAMPS)

container:
	@if ! docker ps -a --format '{{.Names}}' | grep -w $(CONTAINER) >/dev/null; then \
		echo "Launching build container $(CONTAINER)..."; \
		docker run -d --name $(CONTAINER) -v "$(ROOT):$(WORKDIR)" -w "$(WORKDIR)" $(TOOLCHAIN_IMAGE) tail -f /dev/null; \
	else \
		docker start $(CONTAINER) >/dev/null; \
	fi

deps: | container
deps: $(STAMPS)/libdrm $(STAMPS)/wayland $(STAMPS)/wayland-protocols $(STAMPS)/libevdev $(STAMPS)/libinput $(STAMPS)/xkeyboard-config $(STAMPS)/libxkbcommon $(STAMPS)/seatd $(STAMPS)/cairo

weston: deps x11-xwayland $(STAMPS)/weston

bundle: weston
	@echo "Creating deployable archive..."
	@find $(PREFIX) \( -name '.DS_Store' -o -name '._*' \) -delete
	@COPYFILE_DISABLE=1 tar -C $(PREFIX) -czhf $(BUILD_ROOT)/weston.tar.gz --exclude=prefix --exclude='.DS_Store' --exclude='*/.DS_Store' --exclude='._*' --exclude='*/._*' .
	@echo "Archive written to $(BUILD_ROOT)/weston.tar.gz"

deploy: bundle
	@if ! command -v adb >/dev/null 2>&1; then echo "adb not found in PATH"; exit 1; fi
	@echo "Pushing weston bundle to device..."
	@adb shell "ts=\$$(date +%s); if [ -d /mnt/SDCARD/Tools/tg5040/Weston.pak ]; then mv /mnt/SDCARD/Tools/tg5040/Weston.pak /mnt/SDCARD/Tools/tg5040/Weston.pak.bak.\$${ts}; fi; mkdir -p /mnt/SDCARD/Tools/tg5040/Weston.pak"
	@adb push $(BUILD_ROOT)/weston.tar.gz /mnt/SDCARD/Tools/tg5040/Weston.pak/weston.tar.gz
	@adb shell "cd /mnt/SDCARD/Tools/tg5040/Weston.pak && tar xzf weston.tar.gz && rm weston.tar.gz"
	@echo "Deploy complete. Launch with /mnt/SDCARD/Tools/tg5040/Weston.pak/launch.sh (set WESTON_HEADLESS=1 for headless)"

clean:
	rm -rf $(BUILD_DIR) $(STAMPS) $(BUILD_ROOT)/weston.tar.gz $(ZIP_BINARY)
	$(MAKE) -C build/x11 clean 2>/dev/null || true
	@echo "Cleaned all artifacts and stamps."

clean-weston:
	rm -f $(STAMPS)/weston
	rm -rf $(PREFIX)/bin/weston $(PREFIX)/bin/weston.bin $(PREFIX)/bin/weston-launch $(PREFIX)/lib/aarch64-linux-gnu/libweston* $(PREFIX)/lib/aarch64-linux-gnu/weston
	@echo "Cleaned weston build (keeping deps in prefix)."

clean-zip:
	rm -f $(ZIP_BINARY)
	@echo "Cleaned zip binary."

# X11 build targets - delegate to build/x11/Makefile
x11:
	$(MAKE) -C build/x11 x11

x11-deps:
	$(MAKE) -C build/x11 x11-deps

x11-download:
	$(MAKE) -C build/x11 download

x11-xwayland:
	$(MAKE) -C build/x11 x11-xwayland

verify-x11:
	$(MAKE) -C build/x11 verify-x11

clean-x11:
	$(MAKE) -C build/x11 clean-x11

# Build and verify weston-launch (part of weston target)
weston-launch: $(WESTON_LAUNCH)
	@echo "✓ weston-launch verified at $(WESTON_LAUNCH)"
	@file $(WESTON_LAUNCH) | grep -q "aarch64" && echo "✓ Binary is ARM aarch64" || (echo "✗ Binary is not aarch64"; exit 1)
	@if command -v aarch64-linux-gnu-readelf >/dev/null 2>&1; then \
		aarch64-linux-gnu-readelf -d $(WESTON_LAUNCH) 2>/dev/null | grep -q "libpam.so.0" && echo "✓ Linked with libpam.so.0" || (echo "⚠ libpam.so.0 not detected"; exit 1); \
	fi

$(WESTON_LAUNCH): $(STAMPS)/weston
	@test -f $@ || (echo "✗ weston-launch not found after weston build"; exit 1)

# Build InfoZip 3.0 aarch64 binary
zip: $(ZIP_BINARY)
	@echo "✓ InfoZip binary ready at $(ZIP_BINARY)"
	@file $(ZIP_BINARY) | grep -q "aarch64" && echo "✓ Binary is ARM aarch64" || (echo "✗ Binary is not aarch64"; exit 1)
	@if command -v readelf >/dev/null 2>&1; then \
		readelf -V $(ZIP_BINARY) 2>/dev/null | grep -q "GLIBC_2.17" && echo "✓ Linked with GLIBC >= 2.17" || echo "⚠ GLIBC version not verified"; \
	fi

$(ZIP_BINARY): container
	@echo "Building InfoZip 3.0 aarch64..."
	@bash $(ROOT)/build-infozip.sh
	@if [ ! -f $(ZIP_BINARY) ]; then echo "✗ zip binary not found at $(ZIP_BINARY)"; exit 1; fi

# Verify both artifacts are built and valid
verify-artifacts: weston-launch zip
	@echo ""
	@echo "========== Artifact Verification =========="
	@echo "weston-launch: $$(test -f $(WESTON_LAUNCH) && echo '✓ Present' || echo '✗ Missing')"
	@echo "zip binary:    $$(test -f $(ZIP_BINARY) && echo '✓ Present' || echo '✗ Missing')"
	@echo "=========================================="
	@if command -v aarch64-linux-gnu-readelf >/dev/null 2>&1; then \
		aarch64-linux-gnu-readelf -d $(X11_SERVER) 2>/dev/null | grep -q "libGL.so" && echo "✓ Linked with OpenGL" || echo "⚠ OpenGL not linked"; \
	fi
	@test -d $(PREFIX)/lib && test -n "$$(find $(PREFIX)/lib -name 'libGL*' 2>/dev/null)" && echo "✓ OpenGL libraries present" || echo "⚠ OpenGL libraries not found"
	@echo "======================================"

# Individual build steps

$(STAMPS)/libdrm: | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston; mkdir -p build; cd build; \
		rm -rf libdrm-2.4.120 && tar xf $(WORKDIR)/build/weston/src/libdrm-2.4.120.tar.xz; \
		cd libdrm-2.4.120; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Dudev=false -Dvalgrind=disabled -Dcairo-tests=disabled -Dman-pages=disabled -Dtests=false \
			-Dintel=disabled -Dradeon=disabled -Damdgpu=disabled -Dnouveau=disabled -Dvmwgfx=disabled \
			-Domap=disabled -Dexynos=disabled -Detnaviv=disabled -Dtegra=disabled -Dvc4=disabled -Dfreedreno=disabled; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/wayland: $(STAMPS)/libdrm | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf wayland-1.22.0 && tar xf $(WORKDIR)/build/weston/src/wayland-1.22.0.tar.xz; \
		cd wayland-1.22.0; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Ddocumentation=false -Ddtd_validation=false -Dtests=false -Dscanner=true; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/wayland-protocols: $(STAMPS)/wayland | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf wayland-protocols-1.36 && tar xf $(WORKDIR)/build/weston/src/wayland-protocols-1.36.tar.xz; \
		cd wayland-protocols-1.36; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Dtests=false; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/libevdev: $(STAMPS)/wayland-protocols | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf libevdev-1.13.1 && tar xf $(WORKDIR)/build/weston/src/libevdev-1.13.1.tar.xz; \
		cd libevdev-1.13.1; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Dtests=disabled -Ddocumentation=disabled; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/libinput: $(STAMPS)/libevdev | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf libinput-1.25.0 && tar xf $(WORKDIR)/build/weston/src/libinput-1.25.0.tar.gz; \
		cd libinput-1.25.0; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Dlibwacom=false -Ddebug-gui=false -Ddocumentation=false -Dtests=false -Dudev-dir=/usr/lib/udev; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/xkeyboard-config: $(STAMPS)/libinput | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf xkeyboard-config-2.42 && tar xf $(WORKDIR)/build/weston/src/xkeyboard-config-2.42.tar.xz; \
		cd xkeyboard-config-2.42; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Dcompat-rules=false -Dxorg-rules-symlinks=false -Dnls=false; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/libxkbcommon: $(STAMPS)/xkeyboard-config | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf libxkbcommon-1.6.0 && tar xf $(WORKDIR)/build/weston/src/libxkbcommon-1.6.0.tar.xz; \
		cd libxkbcommon-1.6.0; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Denable-x11=false -Denable-wayland=false -Denable-tools=false -Denable-docs=false -Denable-xkbregistry=false -Denable-bash-completion=false; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/seatd: $(STAMPS)/libxkbcommon | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf seatd-0.8.0 && tar xf $(WORKDIR)/build/weston/src/0.8.0.tar.gz; \
		cd seatd-0.8.0; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Ddefaultpath=/mnt/SDCARD/Tools/tg5040/Weston.pak/run/seatd.sock \
			-Dexamples=disabled -Dman-pages=disabled -Dlibseat-logind=disabled -Dlibseat-seatd=enabled -Dlibseat-builtin=disabled -Dserver=enabled; \
		ninja -C _build install"
	@touch $@

$(STAMPS)/cairo: $(STAMPS)/seatd | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf cairo-1.16.0 && tar xf $(WORKDIR)/build/weston/src/cairo-1.16.0.tar.xz; \
		cd cairo-1.16.0; \
		./configure --host=aarch64-nextui-linux-gnu --prefix=\$$PREFIX --libdir=\$$PREFIX/lib \
			--enable-png=yes --enable-ft=no --enable-gobject=no --enable-ps=no --enable-pdf=no \
			--enable-xlib=no --enable-xlib-xrender=no --enable-xcb=yes --enable-xcb-shm=yes \
			--enable-glesv2=no --enable-gl=no --enable-svg=no; \
		make -C src -j$$(nproc) install"
	@touch $@

$(STAMPS)/weston: $(STAMPS)/cairo | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf weston-10.0.4 && tar xf $(WORKDIR)/build/weston/src/weston-10.0.4.tar.xz; \
		cd weston-10.0.4; \
		sed -i \"s/^subdir('tests')/# subdir('tests')/\" meson.build; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Drenderer-gl=false -Dbackend-drm=true -Dbackend-headless=true -Ddeprecated-backend-fbdev=true -Dbackend-default=drm \
			-Dbackend-rdp=false -Dbackend-wayland=false -Dbackend-x11=false \
			-Dbackend-drm-screencast-vaapi=false -Dscreenshare=false -Dpipewire=false -Dremoting=false -Dxwayland=false -Dsystemd=false \
			-Dlauncher-logind=false -Ddeprecated-weston-launch=true -Ddeprecated-wl-shell=false \
			-Dshell-desktop=false -Dshell-ivi=false -Dshell-kiosk=false -Dcolor-management-lcms=false -Dcolor-management-colord=false -Dimage-jpeg=false -Dimage-webp=false \
			-Ddemo-clients=false -Dsimple-clients=shm -Dtools=info -Dwcap-decode=false -Dlauncher-libseat=true \
			-Dxwayland=true -Dxwayland-path=/mnt/SDCARD/Tools/tg5040/Weston.pak/bin/Xwayland; \
		ninja -C _build install"
	@if [ -x "$(ROOT)/build/x11/prefix/bin/Xwayland" ]; then \
		cp -f "$(ROOT)/build/x11/prefix/bin/Xwayland" "$(PREFIX)/bin/Xwayland"; \
	fi
	@if [ -d "$(ROOT)/build/x11/prefix/lib" ]; then \
		cp -f "$(ROOT)/build/x11/prefix/lib/libX11.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libXext.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libXrender.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libXfixes.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libXcursor.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libXau.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libXfont2.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libfontenc.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libxkbfile.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libxcb.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libxcb-*.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
		cp -f "$(ROOT)/build/x11/prefix/lib/libpixman-1.so"* "$(PREFIX)/lib/" 2>/dev/null || true; \
	fi
	@if [ -x "$(PREFIX)/bin/weston" ]; then \
		mv "$(PREFIX)/bin/weston" "$(PREFIX)/bin/weston.bin"; \
		printf '%s\n' '#!/bin/sh' '' 'set -e' \
			'BASE="$$(cd "$$(dirname "$$0")/.." && pwd)"' \
			'export LD_LIBRARY_PATH="$$BASE/lib:$$BASE/lib/libweston-10:$$BASE/lib/weston$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}"' \
			'export XKB_CONFIG_ROOT="$$BASE/share/X11/xkb"' \
			'export WESTON_DATA_DIR="$$BASE/share/weston"' \
			'export WESTON_CONFIG_FILE="$$BASE/weston.ini"' \
			'export WESTON_MODULE_MAP="drm-backend.so=$$BASE/lib/libweston-10/drm-backend.so;headless-backend.so=$$BASE/lib/libweston-10/headless-backend.so;fbdev-backend.so=$$BASE/lib/libweston-10/fbdev-backend.so;xwayland.so=$$BASE/lib/libweston-10/xwayland.so;fullscreen-shell.so=$$BASE/lib/weston/fullscreen-shell.so;libexec_weston.so.0=$$BASE/lib/weston/libexec_weston.so.0"' \
			'export LIBSEAT_BACKEND=seatd' \
			'exec "$$BASE/bin/weston.bin" "$$@"' \
			> "$(PREFIX)/bin/weston"; \
		chmod +x "$(PREFIX)/bin/weston"; \
	fi
	@test -f $(WESTON_LAUNCH) && echo "✓ weston-launch built: $(WESTON_LAUNCH)" || (echo "✗ weston-launch build failed"; exit 1)
	@touch $@
