Progress Report - Weston on TrimUI
==================================

Current state
-------------
- Repo reorganized to root-level `build/weston`; cross toolchain container `weston-build` active.
- Deps cross-built into `build/weston/prefix`: libdrm 2.4.120, wayland 1.22.0/protocols 1.36, libevdev 1.13.1, libinput 1.25.0, xkeyboard-config 2.42, libxkbcommon 1.6.0, seatd/libseat 0.8.0 (socket default `/mnt/SDCARD/Tools/tg5040/weston/seatd.sock`), Cairo 1.16.0 with PNG.
- Weston 12.0.4 cross-built with pixman renderer only; backends: DRM + headless; shells: fullscreen only; Xwayland/GL/pipewire/remoting/demo-clients/tests disabled. Installed under `build/weston/prefix` (modules in `lib/libweston-12`, libexec in `lib/weston`).
- Runtime helper script `build/weston/prefix/bin/run-weston.sh` sets env, starts seatd, and launches weston (headless if `WESTON_HEADLESS=1`). Default config at `build/weston/prefix/weston.ini`.
- Makefile in repo root automates rebuild (`make weston`), bundling (`make bundle`), and adb deploy (`make deploy`). Bundles dereference symlinks for FAT filesystems. Latest deploy pushed to `/mnt/SDCARD/Tools/tg5040/weston`.
- Optional subproject `libdisplay-info` skipped because `/usr/share/hwdata/pnp.ids` missing; not required for DRM bring-up.

Next actions
------------
1) On-device: run `/mnt/SDCARD/Tools/tg5040/weston/bin/run-weston.sh` (set `WESTON_HEADLESS=1` for headless) and capture `logs/weston.log`. Verify seatd.sock is created under the same path.
2) Confirm runtime deps on device (needs sysroot libs: libpixman-1, libpng12, libmtdev, libudev, libffi, glibc/pthread/m/dl/rt); drop missing ones into `lib/` if needed.
3) Once headless works, try DRM backend when safe to stop the UI; iterate `weston.ini`/launcher args for seat/tty/output quirks.
4) If the install location changes, rebuild seatd/libseat with a new `-Ddefaultpath` via `make seatd` (or `make clean && make deploy`).

Notes
-----
- Meson cross/native files: `build/weston/crossfile.meson`, `build/weston/native.meson` (paths updated to `/workspace/build/weston/...`).
- Dependency prefix: `build/weston/prefix`; scratch builds under `build/weston/build`.
- Seat management: libseat/seatd built with seatd backend only (logind disabled). A symlink inside the container points to the new prefix for pkg-config/sysroot lookups.
