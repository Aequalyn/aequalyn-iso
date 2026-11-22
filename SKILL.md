---
name: aequalyn-iso
description: Build and test the Aequalyn live/install ISO with archiso.
---

# Aequalyn ISO — skill

## Overview

Builds the Aequalyn live/install ISO with archiso. Consumes sibling checkouts
(`aequalyn`, `aequalyn-shell`, `aequalyn-installer`, `aequalyn-pkgs`,
`aequalyn-themes`) and assembles them into one tree.

## Build

```sh
sudo ./bin/aequalyn-iso-make
sudo ./bin/aequalyn-iso-make --local-source ~/src/aequalyn    # checkouts elsewhere
./bin/aequalyn-iso-test                                        # boot newest ISO in QEMU (UEFI)
RAM=8192 CPUS=6 ./bin/aequalyn-iso-test
```

Missing repositories are cloned from github.com/Aequalyn. The build assembles them into
`work/source`, populates `/etc/skel` with the desktop, copies the tree to `/opt/aequalyn`
for the installer, bundles an offline package repository, and writes the ISO to `release/`.

## Environment variables

- `KEEP_WORK=1` — keep `work/` between builds.
- `SKIP_DOWNLOAD=1` — reuse offline repository from previous build.
- `AEQUALYN_GIT` — clone base URL (default `https://github.com/Aequalyn`).
- `AQ_WORK=<dir>` — build on another disk: work tree in `<dir>/aequalyn-iso-work` (ISO still lands in `release/`).
- `AQ_MIN_FREE_GB` — free space checked before starting (default 32: ~30 GB at peak).
- `AQ_MIRRORLIST` — mirrorlist file to download from (default: a few Arch mirrors; host's own mirrorlist never used).

## Build stages

1. Prereqs: ensures `mkarchiso`, `repo-add`; requires `/usr/share/archiso/configs/releng`.
2. Work dir + free-space check (default 32 GB); unmounts stale mounts before wipe.
3. Mirrors: writes its own mirrorlist.
4. Source assembly: sibling checkout or shallow clone; copies whitelisted items; strips `.git`/`__pycache__`; drops generated lockscreen/webapp files.
5. Releng base copied into `work/profile`; restores kept offline repo.
6. Boot beep disabled in loader.conf/grub.cfg.
7. Boot menus: renames to "Aequalyn live"; adds "safe graphics" entry (blacklists nouveau/nvidia) to systemd-boot, GRUB (incl. loopback), syslinux.
8. Plymouth staged (live mode, 12 s).
9. Overlay `overlay/airootfs/` copied into profile; ships core `bin/aequalyn-*` into `/usr/local/bin`.
10. Desktop defaults: mutates `config/aequalyn/settings.json` to "Islands" bar/docks look; hides many widgets.
11. Skel population: runs `install.sh --target $SKEL --skel`; sets live theme/wallpaper to `aequalyn` night; pins dock apps (kitty, chromium, aequalyn.fm, aequalyn-install); chowns skel to root.
12. `/opt/aequalyn`: copies whitelisted tree (shell, config, bin, assets, packages, installer, themes, plymouth, migrations, docs, install.sh, VERSION, README).
13. Packages: reads `desktop.packages` + `offline-extra.packages` + ISO extras; filters `linux-lts*` and `*-dkms` from live ISO list; enables multilib; writes into `packages.x86_64`.
14. Local repo: builds `[aequalyn-local]` from `packages/aur-cache` for `local.packages` (mpvpaper, ddwriter, nudu) with `SigLevel = Never`.
15. Offline repo: downloads base+desktop+minimal+offline-extra+plymouth (+deps) via `pacman -Sw` into `work/pkg-cache`, hard-links into profile offline-repo, `repo-add`; skips if `SKIP_DOWNLOAD=1` and db exists. Then adds `aur-cache/*.pkg.tar.zst`.
16. Metadata: rewrites `profiledef.sh` (iso name/label/publisher/application, file_permissions).
17. `mkarchiso` into `work/mkarchiso-work`, output `work/out`; moves ISO to `release/`; cleans mkarchiso tree unless `KEEP_WORK=1`.

## Live session

- SDDM is display manager: `etc/sddm.conf.d/aequalyn-theme.conf` sets `Current=aequalyn`; `autologin.conf` autologs `live` into the `aequalyn` Wayland session (`Relogin=false`).
- `wayland-sessions/aequalyn.desktop` runs `/usr/local/bin/aequalyn-live-session`.
- Guarded single-instance launcher: exclusive flock, pgrep pre-flight, caps `start-hyprland` to one instance; waits for `$XDG_RUNTIME_DIR/bus`, then spawns `aequalyn-session-start` once.
- Root rescue shell: `getty@tty2.service.d/autologin.conf` runs `agetty --autologin root`.
- Environment: `profile.d/aequalyn.sh` adds `~/.local/bin` to PATH; XDG homes.
- Scale fixed at 1 (Hyprland `scale = 1`, empty `monitors.lua`) — no HiDPI auto-detection; affects installed systems too.
- Themes/wallpaper: `/usr/share/aequalyn/themes` → `/opt/aequalyn/themes`; skel has `theme.conf` = `theme:aequalyn` and `wallpaper.conf` pointing to night wallpaper.
- Watchdog budgets: `skel/.config/aequalyn/watchdog.json` = `{shellRamMb:1600, pluginRamMb:384}`.
- Live dock pinned: kitty, chromium, aequalyn.fm, aequalyn-install.
- Refresh: `aequalyn-live-update` pulls latest repos from GitHub into `/opt/aequalyn` and live home, restarts shell.
- Install entry point: `aequalyn-install.desktop` calls `qs ipc call aequalyn install` (root gate).

## Live session defaults

- `live` and `root` password: `live`. Autologin means you normally never type it to reach desktop, but needed to unlock screen (hyprlock) or log in manually. `sudo` requires password for `live` (not passwordless).
- Root has same password `live`, so tty2 rescue shell and `su -` work.
- Nothing in installed system keeps this: target's root password is whatever installer's password field sets.
- Display scale fixed at 1.

## Packages

- Base (`base.packages`): base/base-devel, linux, firmware, mkinitcpio, sudo, git, polkit; btrfs/cryptsetup/dosfstools/efibootmgr/limine/plymouth/snapper/snap-pac/zram; microcode/sof; NM/iwd/wpa_supplicant/bluez; PipeWire; power profiles.
- Desktop (`desktop.packages`): Hyprland, xorg-xwayland, quickshell, matugen, awww, polkit-gnome, hyprlock/idle/shutdown; Qt6/GTK runtime; fonts; Bluetooth; screenshot/clipboard tools; browsers (chromium, vivaldi); kitty/foot/fuzzel; btop/fastfetch/mpv; opencode; nautilus + python-gobject; udisks2/gvfs/tumbler.
- Hardware (`hardware.packages`): conditional by CPU/GPU/wifi/laptop (amd/intel ucode; nvidia-open-dkms; mesa/vulkan; broadcom-wl-dkms; tlp).
- Profiles: minimal, creative, dev, gaming, student.
- Offline-extra: firefox, flatpak, tlp, broadcom-wl-dkms, nvidia stack, mesa/vulkan, linux-lts.
- Local (prebuilt): mpvpaper, ddwriter, nudu (from aur-cache, installed via local repo on live ISO and staged for installs).
- AUR (`aur.packages`): limine-mkinitcpio-hook, limine-snapper-sync, yay-bin, bibata-cursor-theme, adwaita-qt6, zen/brave/edge browsers, localsend, postman, VS Code.
- ISO-only extras: sddm, arch-install-scripts, limine, efibootmgr, parted, gptfdisk, openssl, git, gum, dialog, jq, python, dbus, snapper, snap-pac, zram-generator, mkinitcpio, plymouth, networkmanager, wpa_supplicant.
- AUR cache binaries: ddwriter, limine hooks, mpvpaper, nudu, yay-bin.

## Scripts

- `bin/aequalyn-iso-build`: sudo wrapper, interactive menu (fresh vs skip download), forwards env.
- `bin/aequalyn-iso-make`: full build (see stages).
- `bin/aequalyn-iso-test`: QEMU UEFI boot (OVMF, virtio-gpu, gtk, configurable RAM/CPUS).
- `overlay/.../root/customize_airootfs.sh`: archiso post-pacstrap hook (chmods, plymouth theme, enables sddm/NetworkManager, pacman keyring, hyprbars.so copy).
- `overlay/.../usr/local/bin/aequalyn-install`: execs installer.
- `overlay/.../usr/local/bin/aequalyn-live-session`: guarded Hyprland launcher.
- `overlay/.../usr/local/bin/aequalyn-live-update`: refresh live session from GitHub.
- `overlay/.../usr/local/bin/aequalyn-repair`: execs repair.
- Shipped core scripts (42 in `/usr/local/bin`): aequalyn, aequalyn-ai-tool, apply-palette, askpass, bluetooth-audio, browser-theme, default-apps, detect, dpms, export/import-settings, hypr-apply, idle, layout, lock-*, lockscreen, nautilus-palette, pkg-aur-install, pkg-install, plymouth-calibrate, provision-user, qt5-dialogs, record, repaint, screenshot, sddm, session-start, settings, shell-restart, snapshot, store, temperature, theme, themes, update, wallpaper, webapp, plus hyprbars.so.

## Configs

- `etc/passwd` / `etc/shadow`: root & live (password `live`).
- `etc/sudoers.d/live`: live passworded sudo, no lecture.
- `etc/profile.d/aequalyn.sh`: PATH/XDG/EDITOR.
- `etc/sddm.conf.d/aequalyn-theme.conf` & `autologin.conf`: default theme + autologin.
- `etc/systemd/system/getty@tty2.service.d/autologin.conf`: root rescue shell.
- `etc/motd`: live desktop help.
- `etc/pacman.conf`: standard SigLevel Required; `etc/pacman-offline.conf`: SigLevel Never, file repo.
- `etc/pacman.d/hooks/zz-aequalyn-stop-gpg-agent.hook`.
- `etc/skel/.config/aequalyn/watchdog.json` (`{shellRamMb:1600, pluginRamMb:384}`).
- `usr/share/wayland-sessions/aequalyn.desktop`.
- `usr/share/applications/aequalyn-install.desktop`.
- SDDM themes (50) under `usr/share/sddm/themes/`, default `aequalyn`.
- Build-generated: `work/mirrorlist`, `work/pacman-dl.conf`, `work/local-repo`, `work/profile/pacman.conf` (multilib + mirrors), `work/profile/profiledef.sh` (permissions/metadata), `work/profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf` (plymouth hook).
- Core mutated configs: `config/aequalyn/settings.json` (Islands bar/docks), skel `theme.conf`/`wallpaper.conf`, dock pinned apps.

## Security

- Credentials: both `live` and `root` password is `live` (hashes in `etc/shadow`). Root gets tty2 autologin. Installed systems do not retain this — root password comes from installer.
- sudo: `etc/sudoers.d/live` grants `live ALL=(ALL) ALL` with password (live not in `wheel`), `Defaults:live lecture=never` (needed because root gate feeds password via pipe).
- Offline repo: `pacman-offline.conf` and `[aequalyn-local]` use `SigLevel = Never` — bundled media must be trusted.
- First-boot AUR bootstrap (if enabled) runs unverified `makepkg`.
- Build artifacts: `work/` can be ~30 GB; keep only if trusted; build requires free space check.
- Safe graphics boot entry blacklists nouveau/nvidia drivers for hybrid-GPU laptops.
- Session hardening: live-session flock/pgrep/instance-cap prevent compositor spawn storms.
- File permissions: `profiledef.sh` sets `0:0:755` for core scripts, `0:0:440` for `/etc/sudoers.d/live`, etc.; `customize_airootfs.sh` restores exec bits stripped by mkarchiso.
- GPG agent: hook `zz-aequalyn-stop-gpg-agent.hook` kills agent after transactions.
- Pacman keyring: `pacman-key --init/--populate` in customize script.
- See `aequalyn/Security.md` for system-level concerns.

## References

- Aequalyn core: https://github.com/Aequalyn/aequalyn
- Aequalyn shell: https://github.com/Aequalyn/aequalyn-shell
- Aequalyn installer: https://github.com/Aequalyn/aequalyn-installer
- Aequalyn packages: https://github.com/Aequalyn/aequalyn-pkgs
- Aequalyn themes: https://github.com/Aequalyn/aequalyn-themes
- Aequalyn store: https://github.com/Aequalyn/aequalyn-store
- Aequalyn lockscreens: https://github.com/Aequalyn/aequalyn-lockscreens
