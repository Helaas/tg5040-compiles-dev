SHELL := /bin/bash

# Paths for LWJGL build
ROOT             := $(CURDIR)/../..
LWJGL_BUILD_ROOT := $(CURDIR)
LWJGL_SRC_DIR    := $(LWJGL_BUILD_ROOT)/src
LWJGL_BUILD_DIR  := $(LWJGL_BUILD_ROOT)/build
LWJGL_PREFIX     := $(LWJGL_BUILD_ROOT)/prefix
LWJGL_STAMPS     := $(LWJGL_BUILD_ROOT)/.stamps

# Toolchain / container (shared with weston)
CONTAINER       ?= weston-build
TOOLCHAIN_IMAGE ?= ghcr.io/loveretro/tg5040-toolchain/tg5040-toolchain:latest
WORKDIR         := /workspace

# Cross config as seen inside the container
CROSS_BINDIR    := /opt/aarch64-nextui-linux-gnu/bin
CROSS_TRIPLE    := aarch64-nextui-linux-gnu
CROSS_PREFIX    := $(CROSS_TRIPLE)-
SYSROOT         := /opt/aarch64-nextui-linux-gnu/aarch64-nextui-linux-gnu/libc
PKG_PATH        := $(WORKDIR)/build/weston/prefix/lib/pkgconfig:$(WORKDIR)/build/weston/prefix/share/pkgconfig:$(SYSROOT)/usr/lib/pkgconfig:$(SYSROOT)/usr/share/pkgconfig

# Helpers
DOCKER_EXEC     = docker exec $(CONTAINER) bash -lc

# LWJGL sources
LWJGL_COMMIT    := 91c0f8a62800f4af53d4e54c1772e6849d572a10
LWJGL_SHA256    := e89606d036596568c79dbb7b3115d42305e01889099a04fab636ab2cb33ebe4d
LWJGL_TARBALL   := lwjgl3-$(LWJGL_COMMIT).tar.gz
LWJGL_ARCHIVE   := $(LWJGL_SRC_DIR)/$(LWJGL_TARBALL)
LWJGL_SRC_PATH  := $(LWJGL_BUILD_DIR)/lwjgl3-$(LWJGL_COMMIT)
LWJGL_OUT_LIB   := $(LWJGL_PREFIX)/lib
LWJGL_STAMP     := $(LWJGL_STAMPS)/lwjgl

# Disable heavy bindings; keep OpenGL/OpenGL ES, GLFW, OpenAL, stb, etc.
LWJGL_BINDINGS_OFF := assimp bgfx egl fmod freetype harfbuzz hwloc jawt ktx llvm lmdb lz4 meshoptimizer msdfgen nanovg nfd nuklear odbc opencl openxr opus par remotery renderdoc rpmalloc shaderc spng spvc tinyexr vulkan vma xxhash yoga zstd
LWJGL_BINDING_FLAGS := $(foreach b,$(LWJGL_BINDINGS_OFF),-Dbinding.$(b)=false)
LWJGL_BINDING_FLAGS += -Dbinding.opengl=true -Dbinding.opengles=true -Dbinding.glfw=true -Dbinding.openal=true -Dbinding.jemalloc=true -Dbinding.sdl=true -Dbinding.stb=true -Dbinding.tinyfd=true

# GLFW (Wayland/EGL)
GLFW_VERSION    := 3.4
GLFW_TARBALL    := glfw-$(GLFW_VERSION).tar.gz
GLFW_SHA256     := c038d34200234d071fae9345bc455e4a8f2f544ab60150765d7704e08f3dac01
GLFW_ARCHIVE    := $(LWJGL_SRC_DIR)/$(GLFW_TARBALL)
GLFW_BUILD_DIR  := $(LWJGL_BUILD_DIR)/glfw-$(GLFW_VERSION)
GLFW_INSTALL    := $(WORKDIR)/build/x11/prefix
GLFW_STAMP      := $(LWJGL_STAMPS)/glfw

# GLIBC guardrail: device max is GLIBC_2.33.
GLIBC_MAX ?= 2.33

.PHONY: all lwjgl glfw download verify clean clean-lwjgl container help

all: lwjgl

help:
	@echo "LWJGL Build Targets:"
	@echo "  make lwjgl            - Build LWJGL natives for linux/arm64"
	@echo "  make glfw             - Build GLFW for Wayland/EGL (aarch64)"
	@echo "  make download         - Download LWJGL sources"
	@echo "  make verify           - Verify GLIBC version of built libs"
	@echo "  make clean-lwjgl      - Remove LWJGL build artifacts (keep sources)"
	@echo "  make clean            - Remove all LWJGL build artifacts (keep sources)"
	@echo "  make container        - Start/ensure build container is running"

container:
	@if ! docker ps -a --format '{{.Names}}' | grep -w $(CONTAINER) >/dev/null; then \
		echo "Launching build container $(CONTAINER)..."; \
		docker run -d --name $(CONTAINER) -v "$(ROOT):$(WORKDIR)" -w "$(WORKDIR)" $(TOOLCHAIN_IMAGE) tail -f /dev/null; \
	else \
		docker start $(CONTAINER) >/dev/null; \
	fi

download: $(LWJGL_ARCHIVE) $(GLFW_ARCHIVE)
	@echo "✓ LWJGL/GLFW sources downloaded"

lwjgl: container $(GLFW_STAMP) $(LWJGL_STAMP)
	@echo "✓ LWJGL natives built in $(LWJGL_OUT_LIB)"

glfw: container $(GLFW_STAMP)
	@echo "✓ GLFW built in $(LWJGL_PREFIX)/lib"

verify: container $(LWJGL_STAMP)
	@$(DOCKER_EXEC) "set -euo pipefail; \
		for lib in $(WORKDIR)/build/lwjgl/prefix/lib/liblwjgl*.so $(WORKDIR)/build/x11/prefix/lib/libglfw.so.3*; do \
			[ -f \"\$$lib\" ] || continue; \
			max=\$$(/opt/aarch64-nextui-linux-gnu/bin/$(CROSS_TRIPLE)-readelf -V \"\$$lib\" | sed -n 's/.*Name: GLIBC_\\([0-9.]*\\).*/\\1/p' | sort -V | tail -1); \
			if [ -n \"\$$max\" ]; then \
				if [ \"\$$({ printf '%s\n%s\n' \"$(GLIBC_MAX)\" \"\$$max\" | sort -V | tail -1; })\" != \"$(GLIBC_MAX)\" ]; then \
					echo \"✗ \$$lib requires GLIBC_\$$max (max allowed $(GLIBC_MAX))\"; \
					exit 1; \
				fi; \
			fi; \
		done; \
		echo \"✓ GLIBC version check passed (<= GLIBC_$(GLIBC_MAX))\""

$(LWJGL_ARCHIVE): | $(LWJGL_SRC_DIR)
	@echo "Downloading LWJGL sources..."
	@curl -L -o "$(LWJGL_ARCHIVE)" "https://github.com/LWJGL/lwjgl3/archive/$(LWJGL_COMMIT).tar.gz"
	@echo "Verifying LWJGL archive..."
	@python3 -c 'import hashlib, pathlib, sys; p=pathlib.Path("$(LWJGL_ARCHIVE)"); exp="$(LWJGL_SHA256)"; dig=hashlib.sha256(p.read_bytes()).hexdigest(); sys.exit(f"SHA256 mismatch for {p}\\nExpected: {exp}\\nActual:   {dig}\\n") if dig!=exp else print(f"Verified {p.name}")'

$(GLFW_ARCHIVE): | $(LWJGL_SRC_DIR)
	@echo "Downloading GLFW sources..."
	@curl -L -o "$(GLFW_ARCHIVE)" "https://github.com/glfw/glfw/archive/refs/tags/$(GLFW_VERSION).tar.gz"
	@echo "Verifying GLFW archive..."
	@python3 -c 'import hashlib, pathlib, sys; p=pathlib.Path("$(GLFW_ARCHIVE)"); exp="$(GLFW_SHA256)"; dig=hashlib.sha256(p.read_bytes()).hexdigest(); sys.exit(f"SHA256 mismatch for {p}\\nExpected: {exp}\\nActual:   {dig}\\n") if dig!=exp else print(f"Verified {p.name}")'

$(GLFW_STAMP): container $(GLFW_ARCHIVE) | $(LWJGL_BUILD_DIR) $(LWJGL_PREFIX) $(LWJGL_STAMPS)
	@echo "Building GLFW $(GLFW_VERSION) for Wayland/EGL..."
	@set -euo pipefail; \
	rm -rf "$(GLFW_BUILD_DIR)"; \
	tar -xzf "$(GLFW_ARCHIVE)" -C "$(LWJGL_BUILD_DIR)"; \
	$(DOCKER_EXEC) "set -euo pipefail; \
		apt-get update >/dev/null; \
		DEBIAN_FRONTEND=noninteractive apt-get install -y cmake ninja-build pkg-config >/dev/null; \
		export PATH=$(CROSS_BINDIR):\$$PATH; \
		export PKG_CONFIG_PATH=$(PKG_PATH); \
		export PKG_CONFIG_LIBDIR=$(PKG_PATH); \
		export PKG_CONFIG_SYSROOT_DIR=; \
		cd $(WORKDIR)/build/lwjgl/build/glfw-$(GLFW_VERSION); \
		mkdir -p build && cd build; \
		cmake -G Ninja .. \
			-DCMAKE_SYSTEM_NAME=Linux \
			-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
			-DCMAKE_SYSROOT=$(SYSROOT) \
			-DCMAKE_C_COMPILER=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-gcc \
			-DCMAKE_CXX_COMPILER=$(CROSS_BINDIR)/$(CROSS_TRIPLE)-g++ \
			-DCMAKE_FIND_ROOT_PATH=$(SYSROOT) \
			-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
			-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
			-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
			-DCMAKE_PREFIX_PATH=$(WORKDIR)/build/weston/prefix \
			-DCMAKE_INSTALL_PREFIX=$(GLFW_INSTALL) \
			-DBUILD_SHARED_LIBS=ON \
			-DGLFW_BUILD_WAYLAND=ON \
			-DGLFW_BUILD_X11=OFF \
			-DGLFW_USE_OSMESA=OFF \
			-DGLFW_BUILD_DOCS=OFF \
			-DGLFW_BUILD_EXAMPLES=OFF \
			-DGLFW_BUILD_TESTS=OFF; \
		ninja install"
	@touch "$(GLFW_STAMP)"

$(LWJGL_STAMP): container $(LWJGL_ARCHIVE) | $(LWJGL_BUILD_DIR) $(LWJGL_PREFIX) $(LWJGL_STAMPS)
	@echo "Building LWJGL natives (linux/arm64)..."
	@set -euo pipefail; \
	rm -rf "$(LWJGL_SRC_PATH)"; \
	tar -xzf "$(LWJGL_ARCHIVE)" -C "$(LWJGL_BUILD_DIR)"; \
	$(DOCKER_EXEC) "set -euo pipefail; \
		apt-get update >/dev/null; \
		DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk-headless ant unzip >/dev/null; \
		export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-\$$(dpkg --print-architecture); \
		export PATH=\"\$$JAVA_HOME/bin:$(CROSS_BINDIR):\$$PATH\"; \
		cd $(WORKDIR)/build/lwjgl/build/lwjgl3-$(LWJGL_COMMIT); \
		ant -f config/linux/build.xml compile-native-platform -Dgcc.prefix=$(CROSS_PREFIX) -DLWJGL_BUILD_ARCH=arm64 $(LWJGL_BINDING_FLAGS)"; \
	mkdir -p "$(LWJGL_OUT_LIB)"; \
	rm -f "$(LWJGL_OUT_LIB)/lib"*.so; \
	find "$(LWJGL_SRC_PATH)/bin/libs/native/linux/arm64/org/lwjgl" -maxdepth 4 -type f -name "lib*.so" -exec cp {} "$(LWJGL_OUT_LIB)/" \;; \
	$(DOCKER_EXEC) "set -euo pipefail; \
		for lib in $(WORKDIR)/build/lwjgl/prefix/lib/liblwjgl*.so $(WORKDIR)/build/lwjgl/prefix/lib/libglfw.so.3*; do \
			[ -f \"\$$lib\" ] || continue; \
			max=\$$(/opt/aarch64-nextui-linux-gnu/bin/$(CROSS_TRIPLE)-readelf -V \"\$$lib\" | sed -n 's/.*Name: GLIBC_\\([0-9.]*\\).*/\\1/p' | sort -V | tail -1); \
			if [ -n \"\$$max\" ]; then \
				if [ \"\$$({ printf '%s\n%s\n' \"$(GLIBC_MAX)\" \"\$$max\" | sort -V | tail -1; })\" != \"$(GLIBC_MAX)\" ]; then \
					echo \"✗ \$$lib requires GLIBC_\$$max (max allowed $(GLIBC_MAX))\"; \
					exit 1; \
				fi; \
			fi; \
		done; \
		echo \"✓ GLIBC version check passed (<= GLIBC_$(GLIBC_MAX))\""; \
	touch "$(LWJGL_STAMP)"

$(LWJGL_SRC_DIR) $(LWJGL_BUILD_DIR) $(LWJGL_PREFIX) $(LWJGL_STAMPS):
	@mkdir -p $@

clean-lwjgl:
	rm -rf $(LWJGL_BUILD_DIR) $(LWJGL_PREFIX) $(LWJGL_STAMPS)/lwjgl
	@echo "Cleaned LWJGL build (keeping sources)."

clean: clean-lwjgl
	@echo "Cleaned LWJGL build artifacts."
