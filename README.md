# aequalyn-iso

Builds the Aequalyn live / install ISO with archiso.

```sh
# next to checkouts of aequalyn, aequalyn-shell, aequalyn-installer,
# aequalyn-pkgs and aequalyn-themes:
sudo ./bin/aequalyn-iso-make
sudo ./bin/aequalyn-iso-make --local-source ~/src/aequalyn    # checkouts elsewhere
./bin/aequalyn-iso-test                                        # boot the newest ISO in QEMU (UEFI)
RAM=8192 CPUS=6 ./bin/aequalyn-iso-test
```

Missing repositories are cloned from github.com/Aequalyn. The build assembles
them into one tree (`work/source`), populates `/etc/skel` with the desktop,
copies the tree to `/opt/aequalyn` for the installer, bundles an offline
package repository and writes the ISO to `release/`.

| Variable | |
| --- | --- |
| `KEEP_WORK=1` | Keep `work/` between builds |
| `SKIP_DOWNLOAD=1` | Reuse the offline repository from the previous build |
| `AEQUALYN_GIT` | Clone base URL (default `https://github.com/Aequalyn`) |
| `AQ_WORK=<dir>` | Build on another disk: the work tree goes in `<dir>/aequalyn-iso-work` (the ISO still lands in `release/`) |
| `AQ_MIN_FREE_GB` | Free space the build checks for before starting (default 32: about 30 GB at its peak) |
| `AQ_MIRRORLIST` | A mirrorlist file to download from (default: a few Arch mirrors; the host's own mirrorlist is never used) |

SDDM owns the boot login: it autologs `live` into the `aequalyn` Wayland
session, which starts a single guarded Hyprland + QuickShell desktop. A root
rescue shell stays on tty2 (`Ctrl+Alt+F2`). Run `sudo aequalyn-install`
(or `Super + I`) to install.

The boot menu wears the Aequalyn look, on UEFI (GRUB, `boot/grub-theme/`) and BIOS
(syslinux, `boot/syslinux/`): the mark, the live desktop, safe graphics, speech, the installed
system, memory test, EFI shell, firmware settings, restart and power off, as far as the
machine has them. `boot/make-theme.py` draws its pictures.

![The boot menu](docs/boot-menu.png)

**Aequalyn live, safe graphics**, under the default entry, keeps the discrete GPU's drivers (nouveau, nvidia) from
loading, so the integrated GPU drives the screen. Use it on laptops with hybrid
graphics, or when a graphics card does not start the desktop.

Packages not in the Arch repositories (aequalyn-pkgs `local.packages`: mpvpaper,
DDWriter, nudu) are installed on the live system from a local repository made
from aequalyn-pkgs `aur-cache/`.

## Live session defaults

- The `live` user's password is **`live`**. Autologin means you normally never
  type it to reach the desktop, but it is needed to unlock the screen
  (hyprlock) or log in manually. `sudo` stays passwordless for `live` since the
  medium is ephemeral.
- **root** has the same password, **`live`** (set in `overlay/airootfs/etc/shadow`),
  so the tty2 root rescue shell and any `su -` from the live session work
  without a puzzle. Nothing in the installed system keeps this: the target's
  root password is whatever the installer's password field sets.
- The display scale is fixed at **1** — no HiDPI auto-detection. The live
  session's Hyprland config uses `scale = 1` instead of `scale = "auto"`;
  because that setting comes from the core `aequalyn` config, newly installed
  systems default to scale 1 as well. On the live image `monitors.lua` is empty,
  so nothing overrides it.

## Credits

[nightdevil00](https://github.com/nightdevil00) contributed to the code here.

## Documentation

- `SECURITY.md` — security model and concerns.
- `SKILL.md` — development/install skill reference.
