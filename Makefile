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
PKG_PATH        := $(WORKDIR)/build/weston/prefix/lib/pkgconfig:$(WORKDIR)/build/weston/prefix/share/pkgconfig

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
	$(SRC_DIR)/weston-12.0.4.tar.gz

.PHONY: all deps weston bundle deploy container clean

all: weston

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

weston: deps $(STAMPS)/weston

bundle: weston
	@echo "Creating deployable archive..."
	@tar -C $(PREFIX) -czhf $(BUILD_ROOT)/weston.tar.gz --exclude=prefix .
	@echo "Archive written to $(BUILD_ROOT)/weston.tar.gz"

deploy: bundle
	@if ! command -v adb >/dev/null 2>&1; then echo "adb not found in PATH"; exit 1; fi
	@echo "Pushing weston bundle to device..."
	@adb shell "rm -rf /mnt/SDCARD/Tools/tg5040/weston && mkdir -p /mnt/SDCARD/Tools/tg5040/weston"
	@adb push $(BUILD_ROOT)/weston.tar.gz /mnt/SDCARD/Tools/tg5040/weston/weston.tar.gz
	@adb shell "cd /mnt/SDCARD/Tools/tg5040/weston && tar xzf weston.tar.gz && rm weston.tar.gz"
	@echo "Deploy complete. Launch with /mnt/SDCARD/Tools/tg5040/weston/bin/run-weston.sh (set WESTON_HEADLESS=1 for headless)"

clean:
	rm -rf $(BUILD_DIR) $(STAMPS) $(BUILD_ROOT)/weston.tar.gz

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
			-Ddefaultpath=/mnt/SDCARD/Tools/tg5040/weston/seatd.sock \
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
			--enable-xlib=no --enable-xlib-xrender=no --enable-xcb=no --enable-xcb-shm=no \
			--enable-glesv2=no --enable-gl=no --enable-svg=no; \
		make -C src -j$$(nproc) install"
	@touch $@

$(STAMPS)/weston: $(STAMPS)/cairo | $(STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; $(ENV_EXPORT) \
		cd $(WORKDIR)/build/weston/build; \
		rm -rf weston-12.0.4 && tar xf $(WORKDIR)/build/weston/src/weston-12.0.4.tar.gz; \
		cd weston-12.0.4; \
		# Disable tests (not cross-safe) \
		sed -i \"s/^subdir('tests')/# subdir('tests')/\" meson.build; \
		meson setup _build --prefix=\$$PREFIX --libdir=lib --buildtype=release --cross-file=$(CROSSFILE) --native-file=$(NATIVEFILE) \
			-Drenderer-gl=false -Dbackend-drm=true -Dbackend-headless=true -Dbackend-default=drm \
			-Dbackend-pipewire=false -Dbackend-rdp=false -Dbackend-vnc=false -Dbackend-wayland=false -Dbackend-x11=false \
			-Dbackend-drm-screencast-vaapi=false -Dscreenshare=false -Dpipewire=false -Dremoting=false -Dxwayland=false -Dsystemd=false \
			-Dshell-desktop=false -Dshell-ivi=false -Dshell-kiosk=false -Dcolor-management-lcms=false -Dimage-jpeg=false -Dimage-webp=false \
			-Ddemo-clients=false -Dsimple-clients=shm -Dtools=info -Dwcap-decode=false -Dlauncher-libseat=true; \
		ninja -C _build install"
	@touch $@
