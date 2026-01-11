Progress Report - Weston on TrimUI
==================================

Current state
-------------
- Repo reorganized to root-level `build/weston`; cross toolchain container `weston-build` active.
- Deps cross-built into `build/weston/prefix`: libdrm 2.4.120, wayland 1.22.0/protocols 1.36, libevdev 1.13.1, libinput 1.25.0, xkeyboard-config 2.42, libxkbcommon 1.6.0, seatd/libseat 0.8.0 (default socket `/mnt/SDCARD/Tools/tg5040/Weston.pak/run/seatd.sock`), Cairo 1.16.0 with PNG.
- Weston 10.0.4 cross-built (pixman renderer only); backends: DRM + fbdev + headless; shells: fullscreen only; Xwayland/GL/pipewire/remoting/demo-clients/tests disabled. Installed under `build/weston/prefix` (modules in `lib/libweston-10`, libexec in `lib/weston`).
- Runtime helper script `build/weston/prefix/bin/run-weston.sh` mounts tmpfs at `run/`, clears stale sockets, starts seatd (logs to `logs/seatd.log`), and launches weston (headless if `WESTON_HEADLESS=1`). Default config at `build/weston/prefix/weston.ini`.
- Makefile in repo root automates rebuild (`make weston`), bundling (`make bundle`), and adb deploy (`make deploy`). Bundles strip macOS dotfiles. Latest deploy lives at `/mnt/SDCARD/Tools/tg5040/Weston.pak` with launch shim `launch.sh` in NextUI pak style; default backend now prefers fbdev when available; userdata logs at `/.userdata/logs/Weston.txt`, weston logs under `Weston.pak/logs/`.
- Device GLIBC max verified via adb: `/lib/libc.so.6` exports up to `GLIBC_2.33`.
- LWJGL native build automation added under `build/lwjgl/Makefile`, outputs to `build/lwjgl/prefix/lib` and enforces `GLIBC_2.33` max with a readelf check; GLFW is built for Wayland/EGL (X11 disabled) into the same prefix.
- Optional subproject `libdisplay-info` skipped because `/usr/share/hwdata/pnp.ids` missing; not required for DRM bring-up.

Next actions
------------
1) On-device: `/mnt/SDCARD/Tools/tg5040/Weston.pak/launch.sh` now defaults to fbdev (unset `WESTON_HEADLESS`); confirm framebuffer output and that `run/seatd.sock` plus `logs/seatd.log`/`logs/weston.log` look healthy.
2) Libinput quirks are missing on-device (warning in weston log); consider packaging `share/libinput` quirks or pointing `LIBINPUT_QUIRKS_DIR` at system files if available.
3) DRM backend still fails (no connectors); fbdev is the current path for on-screen. Keep `WESTON_HEADLESS=1` if you need headless runs.
4) If install location changes again, rebuild seatd/libseat with updated `-Ddefaultpath` via `make seatd` (or `make clean && make deploy`).

Notes
-----
- Meson cross/native files: `build/weston/crossfile.meson`, `build/weston/native.meson` (paths updated to `/workspace/build/weston/...`).
- Dependency prefix: `build/weston/prefix`; scratch builds under `build/weston/build`.
- Seat management: libseat/seatd built with seatd backend only (logind disabled). A symlink inside the container points to the new prefix for pkg-config/sysroot lookups.
