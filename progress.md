Progress Report - Weston on TrimUI
==================================

Current state
-------------
- Repo reorganized to root-level `build/weston`; cross toolchain container `weston-build` active.
- Deps cross-built into `build/weston/prefix`: libdrm 2.4.120, wayland 1.22.0/protocols 1.36, libevdev 1.13.1, libinput 1.25.0, xkeyboard-config 2.42, libxkbcommon 1.6.0, seatd/libseat 0.8.0 (default socket `/mnt/SDCARD/Tools/tg5040/Weston.pak/run/seatd.sock`), Cairo 1.16.0 with PNG.
- Weston 12.0.4 cross-built with pixman renderer only; backends: DRM + headless; shells: fullscreen only; Xwayland/GL/pipewire/remoting/demo-clients/tests disabled. Installed under `build/weston/prefix` (modules in `lib/libweston-12`, libexec in `lib/weston`).
- Runtime helper script `build/weston/prefix/bin/run-weston.sh` mounts tmpfs at `run/`, clears stale sockets, starts seatd (logs to `logs/seatd.log`), and launches weston (headless if `WESTON_HEADLESS=1`). Default config at `build/weston/prefix/weston.ini`.
- Makefile in repo root automates rebuild (`make weston`), bundling (`make bundle`), and adb deploy (`make deploy`). Bundles strip macOS dotfiles. Latest deploy lives at `/mnt/SDCARD/Tools/tg5040/Weston.pak` with launch shim `launch.sh` in NextUI pak style; userdata logs at `/.userdata/logs/Weston.txt`, weston logs under `Weston.pak/logs/`.
- Optional subproject `libdisplay-info` skipped because `/usr/share/hwdata/pnp.ids` missing; not required for DRM bring-up.

Next actions
------------
1) On-device: use `/mnt/SDCARD/Tools/tg5040/Weston.pak/launch.sh` (or `start-stop-daemon -S -b -m -p /tmp/weston.pid -x ...`) and confirm weston stays up; verify `run/seatd.sock` and `logs/seatd.log`/`logs/weston.log`.
2) Confirm runtime deps on device (needs sysroot libs: libpixman-1, libpng12, libmtdev, libudev, libffi, glibc/pthread/m/dl/rt); drop missing ones into `lib/` if needed.
3) Once headless is stable, try DRM backend (`WESTON_HEADLESS=0 launch.sh`) when safe to stop the UI; iterate `weston.ini`/launcher args for seat/tty/output quirks.
4) If install location changes again, rebuild seatd/libseat with updated `-Ddefaultpath` via `make seatd` (or `make clean && make deploy`).

Notes
-----
- Meson cross/native files: `build/weston/crossfile.meson`, `build/weston/native.meson` (paths updated to `/workspace/build/weston/...`).
- Dependency prefix: `build/weston/prefix`; scratch builds under `build/weston/build`.
- Seat management: libseat/seatd built with seatd backend only (logind disabled). A symlink inside the container points to the new prefix for pkg-config/sysroot lookups.
