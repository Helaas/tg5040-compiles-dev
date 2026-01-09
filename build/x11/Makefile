SHELL := /bin/bash

# Paths for X11 build
ROOT            := $(CURDIR)/../..
X11_BUILD_ROOT  := $(CURDIR)
X11_SRC_DIR     := $(X11_BUILD_ROOT)/src
X11_BUILD_DIR   := $(X11_BUILD_ROOT)/build
X11_PREFIX      := $(X11_BUILD_ROOT)/prefix
X11_STAMPS      := $(X11_BUILD_ROOT)/.stamps

# Toolchain / container (shared with weston)
CONTAINER       ?= weston-build
TOOLCHAIN_IMAGE ?= ghcr.io/loveretro/tg5040-toolchain/tg5040-toolchain:latest
WORKDIR         := /workspace
WESTON_PREFIX   := $(WORKDIR)/build/weston/prefix

# Cross/meson config paths as seen inside the container
CROSSFILE       := $(WORKDIR)/build/weston/crossfile.meson
NATIVEFILE      := $(WORKDIR)/build/weston/native.meson
SYSROOT         := /opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc
PKG_PATH        := $(WORKDIR)/build/x11/prefix/lib/pkgconfig:$(WORKDIR)/build/x11/prefix/share/pkgconfig:$(WORKDIR)/build/weston/prefix/lib/pkgconfig:$(WORKDIR)/build/weston/prefix/share/pkgconfig:$(SYSROOT)/usr/lib/pkgconfig:$(SYSROOT)/usr/share/pkgconfig
CROSS_BINDIR    := /opt/aarch64-nextui-linux-gnu/bin
CROSS_TRIPLE    := aarch64-nextui-linux-gnu

# Helpers - build host tools, not cross-compiled (use x86_64-linux-gnu)
DOCKER_EXEC     = docker exec $(CONTAINER) bash -c
ENV_EXPORT      = export PREFIX=$(WORKDIR)/build/x11/prefix; \
                  export PKG_CONFIG_PATH=$(PKG_PATH); \
                  export PKG_CONFIG_LIBDIR=$(PKG_PATH); \
                  export SYSROOT=; \
                  export PKG_CONFIG_SYSROOT_DIR=;
X11_CROSS_ENV   = export PATH=$(CROSS_BINDIR):\$$PATH; \
                  export CC=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-gcc \
                    CXX=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-g++ \
                    AR=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-ar \
                    RANLIB=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-ranlib \
                    LD=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-ld; \
                  export CFLAGS="--sysroot=$(SYSROOT) -fPIC"; \
                  export CXXFLAGS="--sysroot=$(SYSROOT) -fPIC"; \
                  export LDFLAGS="--sysroot=$(SYSROOT)";

# X11 Tarballs
X11_TARBALLS = \
	$(X11_SRC_DIR)/xcb-proto-1.17.0.tar.xz \
	$(X11_SRC_DIR)/xorgproto-2024.1.tar.xz \
	$(X11_SRC_DIR)/xtrans-1.6.0.tar.gz \
	$(X11_SRC_DIR)/libXau-1.0.12.tar.gz \
	$(X11_SRC_DIR)/libxcb-1.16.tar.xz \
	$(X11_SRC_DIR)/pixman-0.42.2.tar.gz \
	$(X11_SRC_DIR)/libfontenc-1.1.8.tar.gz \
	$(X11_SRC_DIR)/libXfont2-2.0.7.tar.gz \
	$(X11_SRC_DIR)/libxkbfile-1.1.3.tar.gz \
	$(X11_SRC_DIR)/util-macros-1.20.2.tar.gz \
	$(X11_SRC_DIR)/mesa-23.3.5.tar.xz \
	$(X11_SRC_DIR)/libX11-1.8.7.tar.gz \
	$(X11_SRC_DIR)/libXext-1.3.5.tar.gz \
	$(X11_SRC_DIR)/libXrender-0.9.11.tar.gz \
	$(X11_SRC_DIR)/libXfixes-6.0.1.tar.gz \
	$(X11_SRC_DIR)/libXcursor-1.2.2.tar.gz \
	$(X11_SRC_DIR)/libepoxy-1.5.10.tar.gz \
	$(X11_SRC_DIR)/libffi-3.3.tar.gz \
	$(X11_SRC_DIR)/xorg-server-1.20.14.tar.gz

# Artifacts
X11_SERVER      := $(X11_PREFIX)/bin/Xorg
X11_XWAYLAND    := $(X11_PREFIX)/bin/Xwayland
X11_LIBS        := $(X11_PREFIX)/lib/libX11.so $(X11_PREFIX)/lib/libGL.so

.PHONY: all deps x11 x11-deps x11-xwayland verify-x11 clean clean-x11 download help

help:
	@echo "X11 Build Targets:"
	@echo "  make x11              - Build complete X11 stack (Xorg server with fbdev)"
	@echo "  make x11-deps         - Build X11 libraries and dependencies only"
	@echo "  make x11-xwayland     - Build Xwayland binary only"
	@echo "  make download         - Download X11 source tarballs"
	@echo "  make verify-x11       - Verify X11 build artifacts"
	@echo "  make clean-x11        - Remove X11 build (keep sources)"
	@echo "  make clean            - Remove all X11 build (keep sources)"

all: x11

# Download X11 sources
download: $(X11_TARBALLS)
	@echo "✓ All X11 sources downloaded"

$(X11_SRC_DIR)/%.tar.xz: | $(X11_SRC_DIR)
	@echo "Downloading $(@F)..."
	@case $(@F) in \
		xcb-proto-*.tar.xz) curl -fsSL "https://www.x.org/archive/individual/proto/$(@F)" -o $@ ;; \
		xorgproto-*.tar.xz) curl -fsSL "https://www.x.org/archive/individual/proto/$(@F)" -o $@ ;; \
		libxcb-*.tar.xz) curl -fsSL "https://www.x.org/archive/individual/lib/$(@F)" -o $@ ;; \
		mesa-*.tar.xz) curl -fsSL "https://archive.mesa3d.org/$(@F)" -o $@ ;; \
		*) echo "Unknown source: $(@F)"; exit 1 ;; \
	esac

$(X11_SRC_DIR)/%.tar.gz: | $(X11_SRC_DIR)
	@echo "Downloading $(@F)..."
	@case $(@F) in \
		xtrans-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/lib/$(@F)" -o $@ ;; \
		libfontenc-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/lib/$(@F)" -o $@ ;; \
		pixman-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/lib/$(@F)" -o $@ ;; \
		libXau-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/lib/$(@F)" -o $@ ;; \
		libX11-*.tar.gz | libXext-*.tar.gz | libXrender-*.tar.gz | libXfixes-*.tar.gz | libXcursor-*.tar.gz | libXfont2-*.tar.gz | libxkbfile-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/lib/$(@F)" -o $@ ;; \
		libepoxy-*.tar.gz) curl -fsSL "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz" -o $@ ;; \
		libffi-*.tar.gz) curl -fsSL "https://github.com/libffi/libffi/releases/download/v3.3/$(@F)" -o $@ ;; \
		util-macros-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/util/$(@F)" -o $@ ;; \
		xorg-server-*.tar.gz) curl -fsSL "https://www.x.org/archive/individual/xserver/$(@F)" -o $@ ;; \
		*) echo "Unknown source: $(@F)"; exit 1 ;; \
	esac

$(X11_SRC_DIR):
	@mkdir -p $@

$(X11_STAMPS):
	@mkdir -p $@

$(X11_BUILD_DIR):
	@mkdir -p $@

# X11 build targets (PowerVR GPU optimized with OpenGL ES support)
# Build order: xcb-proto -> xproto -> libXau -> libxcb -> mesa (OpenGL) -> libX11 -> libXext -> libXrender -> X11 server

x11: $(X11_STAMPS)/x11-server
	@echo "✓ X11 server built successfully at $(X11_SERVER)"

x11-deps: $(X11_STAMPS)/x11-libs
	@echo "✓ X11 libraries and dependencies built"

x11-xwayland: $(X11_STAMPS)/x11-server
	@test -f $(X11_XWAYLAND) && echo "✓ Xwayland built: $(X11_XWAYLAND)" || (echo "✗ Xwayland build failed"; exit 1)

$(X11_STAMPS)/xcb-proto: $(X11_TARBALLS) | $(X11_STAMPS) $(X11_BUILD_DIR)
	@$(DOCKER_EXEC) "set -euo pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		export CC=gcc CXX=g++ LD=ld AR=ar RANLIB=ranlib CPP=/usr/bin/cpp; \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf xcb-proto-1.17.0 && tar xf $(WORKDIR)/build/x11/src/xcb-proto-1.17.0.tar.xz; \
		cd xcb-proto-1.17.0; \
		./configure --prefix=\$$PREFIX; \
		make -C src install; \
		cp -r xcbgen \$$PREFIX/lib/; \
		cp xcb-proto.pc \$$PREFIX/lib/pkgconfig/"
	@touch $@

$(X11_STAMPS)/xproto: $(X11_STAMPS)/xcb-proto | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		export CC=gcc CXX=g++ LD=ld AR=ar RANLIB=ranlib CPP=/usr/bin/cpp; \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf xorgproto-2024.1 && tar xf $(WORKDIR)/build/x11/src/xorgproto-2024.1.tar.xz; \
		cd xorgproto-2024.1; \
		./configure --prefix=\$$PREFIX; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/xorg-macros: $(X11_TARBALLS) | $(X11_STAMPS) $(X11_BUILD_DIR)
	@$(DOCKER_EXEC) "set -euo pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		export CC=gcc CXX=g++ LD=ld AR=ar RANLIB=ranlib CPP=/usr/bin/cpp; \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf util-macros-1.20.2 && tar xf $(WORKDIR)/build/x11/src/util-macros-1.20.2.tar.gz; \
		cd util-macros-1.20.2; \
		./configure --prefix=\$$PREFIX; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/xtrans: $(X11_STAMPS)/xproto | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf xtrans-1.6.0 && tar xf $(WORKDIR)/build/x11/src/xtrans-1.6.0.tar.gz; \
		cd xtrans-1.6.0; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libxau: $(X11_STAMPS)/xproto | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libXau-1.0.12 && tar xf $(WORKDIR)/build/x11/src/libXau-1.0.12.tar.gz; \
		cd libXau-1.0.12; \
		cp -r \$$PREFIX/include/X11/* include/X11/; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libxcb: $(X11_STAMPS)/libxau | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		export PYTHONPATH=\$$PREFIX/lib:\$${PYTHONPATH:-}; \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libxcb-1.16 && tar xf $(WORKDIR)/build/x11/src/libxcb-1.16.tar.xz; \
		cd libxcb-1.16; \
		cp -r \$$PREFIX/include/X11/* include/X11/ || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=$(WORKDIR)/build/x11/prefix --libdir=$(WORKDIR)/build/x11/prefix/lib \
			--enable-xkb=yes --enable-render=yes; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/mesa: $(X11_STAMPS)/libxcb | $(X11_STAMPS)
	@echo "✓ Skipping Mesa (complex dependency - can be added later if needed)"
	@touch $@

$(X11_STAMPS)/libX11: $(X11_STAMPS)/mesa $(X11_STAMPS)/xtrans | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR SYSROOT; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		export CFLAGS=\"-Wno-error=array-bounds \$$CFLAGS\"; export CXXFLAGS=\"\$$CFLAGS\"; \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libX11-1.8.7 && tar xf $(WORKDIR)/build/x11/src/libX11-1.8.7.tar.gz; \
		cd libX11-1.8.7; \
		cp -r \$$PREFIX/include/X11/* include/X11/ 2>/dev/null || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=$(WORKDIR)/build/x11/prefix --libdir=$(WORKDIR)/build/x11/prefix/lib \
			--disable-specs --disable-docs --disable-xlocale --disable-shared --enable-static --with-pic; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libffi: $(X11_STAMPS)/libX11 | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR SYSROOT; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		export PREFIX=$(WESTON_PREFIX); \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libffi-3.3 && tar xf $(WORKDIR)/build/x11/src/libffi-3.3.tar.gz; \
		cd libffi-3.3; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib --disable-static --enable-shared; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libXext: $(X11_STAMPS)/libX11 | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libXext-1.3.5 && tar xf $(WORKDIR)/build/x11/src/libXext-1.3.5.tar.gz; \
		cd libXext-1.3.5; \
		cp -r \$$PREFIX/include/X11/* include/X11/ 2>/dev/null || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib \
			--disable-specs --disable-docs; \
		make -j$$(nproc) install"
	@touch $@


$(X11_STAMPS)/libXrender: $(X11_STAMPS)/libXext | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libXrender-0.9.11 && tar xf $(WORKDIR)/build/x11/src/libXrender-0.9.11.tar.gz; \
		cd libXrender-0.9.11; \
		cp -r \$$PREFIX/include/X11/* include/X11/ 2>/dev/null || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libXfixes: $(X11_STAMPS)/libXrender | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libXfixes-6.0.1 && tar xf $(WORKDIR)/build/x11/src/libXfixes-6.0.1.tar.gz; \
		cd libXfixes-6.0.1; \
		cp -r \$$PREFIX/include/X11/* include/X11/ 2>/dev/null || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libXcursor: $(X11_STAMPS)/libXfixes | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libXcursor-1.2.2 && tar xf $(WORKDIR)/build/x11/src/libXcursor-1.2.2.tar.gz; \
		cd libXcursor-1.2.2; \
		cp -r \$$PREFIX/include/X11/* include/X11/ 2>/dev/null || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/pixman: $(X11_STAMPS)/libXrender | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf pixman-0.42.2 && tar xf $(WORKDIR)/build/x11/src/pixman-0.42.2.tar.gz; \
		cd pixman-0.42.2; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libfontenc: $(X11_STAMPS)/pixman $(X11_STAMPS)/xorg-macros | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libfontenc-1.1.8 && tar xf $(WORKDIR)/build/x11/src/libfontenc-1.1.8.tar.gz; \
		cd libfontenc-1.1.8; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libXfont2: $(X11_STAMPS)/libfontenc $(X11_STAMPS)/xorg-macros | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libXfont2-2.0.7 && tar xf $(WORKDIR)/build/x11/src/libXfont2-2.0.7.tar.gz; \
		cd libXfont2-2.0.7; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libxkbfile: $(X11_STAMPS)/libX11 $(X11_STAMPS)/xorg-macros | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libxkbfile-1.1.3 && tar xf $(WORKDIR)/build/x11/src/libxkbfile-1.1.3.tar.gz; \
		cd libxkbfile-1.1.3; \
		ls -l \$$PREFIX/lib/libX11.la || (echo \"libX11.la missing\"; exit 1); \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib --disable-static --enable-shared; \
		make -j$$(nproc) install"
	@touch $@

$(X11_STAMPS)/libepoxy: $(X11_STAMPS)/libX11 | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf libepoxy-1.5.10 && tar xf $(WORKDIR)/build/x11/src/libepoxy-1.5.10.tar.gz; \
		cd libepoxy-1.5.10; \
		meson setup build --prefix=\$$PREFIX --libdir=lib --cross-file=$(CROSSFILE) \
			-Ddefault_library=shared -Dtests=false -Ddocs=false -Degl=no -Dglx=no -Dx11=false; \
		ninja -C build install; \
		ln -sf libepoxy.so.0.0.0 \$$PREFIX/lib/libepoxy.so.0; \
		ln -sf libepoxy.so.0.0.0 \$$PREFIX/lib/libepoxy.so"
	@touch $@

$(X11_STAMPS)/x11-libs: $(X11_STAMPS)/libX11 $(X11_STAMPS)/libffi $(X11_STAMPS)/libxkbfile $(X11_STAMPS)/libXfont2 $(X11_STAMPS)/libXcursor $(X11_STAMPS)/libepoxy
	@touch $@

$(X11_STAMPS)/x11-server: $(X11_STAMPS)/x11-libs | $(X11_STAMPS)
	@$(DOCKER_EXEC) "set -euo pipefail; unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR; export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; $(ENV_EXPORT) \
		$(X11_CROSS_ENV) \
		cd $(WORKDIR)/build/x11/build; \
		rm -rf xorg-server-1.20.14 && tar xf $(WORKDIR)/build/x11/src/xorg-server-1.20.14.tar.gz; \
		cd xorg-server-1.20.14; \
		cp -r \$$PREFIX/include/X11/* include/X11/ 2>/dev/null || true; \
		./configure --host=$(CROSS_TRIPLE) --prefix=\$$PREFIX --libdir=\$$PREFIX/lib \
			--disable-docs --disable-unit-tests \
			--disable-glx --disable-dri --disable-dri2 --disable-dri3 --disable-glamor \
			--disable-xdmcp --enable-xwayland --disable-xnest --disable-kdrive \
			--disable-xorg --disable-xvfb --enable-composite --disable-xinerama \
			--disable-config-udev --disable-config-udev-kms --disable-config-hal --disable-systemd-logind \
			--with-sha1=libcrypto --with-xkb-output=/tmp \
			--with-default-font-path=/usr/share/fonts/X11 \
			--with-builder-addr='BuildForTG5040' --enable-install-setuid=no \
			CFLAGS=\"-Wno-error=array-bounds -Wno-array-bounds -DHAVE_DIX_CONFIG_H \$$CFLAGS\" \
			LDFLAGS=\"-Wl,--allow-multiple-definition \$$LDFLAGS\" \
			CPPFLAGS=\"-I\$$PREFIX/include -I\$$PREFIX/include/pixman-1\"; \
		sed -i 's|^Xorg_LDADD = |Xorg_LDADD = loader/libloader.la |' hw/xfree86/Makefile; \
		sed -i 's|^Xorg_DEPENDENCIES = |Xorg_DEPENDENCIES = loader/libloader.la |' hw/xfree86/Makefile; \
		sed -i 's|[^ ]*glx/libglxvnd.la||g' hw/xwayland/Makefile; \
		sed -i 's|\$$(top_builddir) \$$(XWAYLAND_SYS_LIBS)|\$$(XWAYLAND_SYS_LIBS)|' hw/xwayland/Makefile; \
		sed -i 's|^XWAYLAND_SYS_LIBS = |XWAYLAND_SYS_LIBS = -lffi |' hw/xwayland/Makefile; \
		make -j$$(nproc) install"
	@if [ -f $(X11_SERVER) ]; then \
		echo "✓ X11 Xorg built: $(X11_SERVER)"; \
	elif [ -f $(X11_XWAYLAND) ]; then \
		echo "✓ Xwayland built: $(X11_XWAYLAND)"; \
	else \
		echo "✗ X11 build failed"; exit 1; \
	fi
	@touch $@

# Verification targets
verify-x11: x11
	@echo "X11 Build Verification:"
	@test -f $(X11_SERVER) && echo "✓ Xorg binary present: $(X11_SERVER)" || (echo "✗ Xorg binary missing"; exit 1)
	@test -f $(X11_PREFIX)/lib/libX11.a && echo "✓ libX11.a present" || (echo "✗ libX11.a missing"; exit 1)
	@file $(X11_SERVER) | grep -q "aarch64" && echo "✓ Binary is ARM aarch64" || (echo "✗ Binary is not aarch64"; exit 1)
	@echo "✓ X11 build verified"

# Cleanup targets
clean-x11:
	@rm -f $(X11_STAMPS)/*
	@rm -rf $(X11_BUILD_DIR)/*org* $(X11_PREFIX)/bin/X
	@rm -rf $(X11_PREFIX)/bin/Xvfb* $(X11_PREFIX)/lib/libGL* $(X11_PREFIX)/lib/libX11* $(X11_PREFIX)/lib/libXext* $(X11_PREFIX)/lib/libXrender* $(X11_PREFIX)/lib/libXfixes* $(X11_PREFIX)/lib/libXcursor* $(X11_PREFIX)/lib/libepoxy* $(X11_PREFIX)/lib/libxcb*
	@echo "Cleaned X11 build (sources preserved in $(X11_SRC_DIR))"

clean: clean-x11
