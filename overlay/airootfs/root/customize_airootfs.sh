#!/usr/bin/env bash
# archiso runs this in the airootfs chroot after /etc/skel has been copied to
# user homes. mkarchiso's `cp -af --no-preserve=ownership,mode` strips exec bits
# from custom airootfs files, so restore them here (file_permissions in
# profiledef.sh cannot cover every generated file).
set -e

# Live user helpers (aequalyn-session-start is exec'd by the Hyprland session).
chmod 755 /etc/skel/.local/bin/* 2>/dev/null || true
if [[ -d /home/live/.local/bin ]]; then
    chmod 755 /home/live/.local/bin/* 2>/dev/null || true
fi

# Installer source tree in /opt/aequalyn (wrappers use `bash`, but keep these sane).
if [[ -d /opt/aequalyn/bin ]]; then
    chmod 755 /opt/aequalyn/bin/* 2>/dev/null || true
fi
if [[ -d /opt/aequalyn/installer ]]; then
    chmod 755 /opt/aequalyn/installer/aequalyn-* /opt/aequalyn/installer/lib/*.sh 2>/dev/null || true
fi
chmod 755 /opt/aequalyn/install.sh /usr/local/bin/aequalyn-* 2>/dev/null || true

# Universal clipboard: wl-paste --watch runs this capture helper.
chmod 755 /etc/skel/.config/quickshell/clipboard/capture.sh 2>/dev/null || true
if [[ -d /home/live/.config/quickshell/clipboard ]]; then
    chmod 755 /home/live/.config/quickshell/clipboard/capture.sh 2>/dev/null || true
fi

# The live user may install without a password.
chmod 440 /etc/sudoers.d/live 2>/dev/null || true

# Plymouth boot splash: the theme is staged in the image by the ISO build.
# Set it as the default and rebuild the initramfs in the same step, because the
# initramfs built during pacstrap used the package's default theme.
if [[ -f /usr/share/plymouth/themes/aequalyn/aequalyn.plymouth ]]; then
    echo "Plymouth: setting aequalyn theme and rebuilding the initramfs"
    plymouth-set-default-theme aequalyn -R
else
    echo "WARNING: /usr/share/plymouth/themes/aequalyn is missing; no boot splash" >&2
fi

# SDDM owns the boot login: it autologins `live` into the guarded Hyprland
# session. This runs in the archiso chroot, so `systemctl enable` just writes
# the display-manager.service alias (no daemon is started here).
systemctl enable sddm.service 2>/dev/null || true

# NetworkManager must come up at boot: the shell bar's network indicator talks
# to it via nmcli/D-Bus and the live session needs connectivity for updates and
# online installs. Like sddm above, this only records the default target
# symlink -- nothing is started inside the build chroot.
systemctl enable NetworkManager.service 2>/dev/null || true

# Guarantee a usable pacman keyring in the live image. archlinux-keyring's
# install scriptlet normally populates it, but if that step was skipped the
# online installer dies at pacstrap with "invalid or corrupted package (PGP
# signature)" for every mirror package. `--init` is idempotent and only mints
# the local signing key when one is missing.
pacman-key --init >/dev/null 2>&1 || true
pacman-key --populate archlinux >/dev/null 2>&1 || true
# pacman-key starts gpg-agent; do not leave it running inside the image.
gpgconf --homedir /etc/pacman.d/gnupg --kill all >/dev/null 2>&1 || true

exit 0
