#!/usr/bin/env bash
# archiso runs this in the airootfs chroot after /etc/skel has been copied to
# user homes. mkarchiso's `cp -af --no-preserve=ownership,mode` strips exec bits
# from custom airootfs files, so restore them here (file_permissions in
# profiledef.sh cannot cover every generated file).
set -e
# whatever mask this was started under: what it writes is for every user to read
umask 022

# Live user helpers (aequalyn-session-start is exec'd by the Hyprland session).
chmod 755 /etc/skel/.local/bin/* 2>/dev/null || true
if [[ -d /home/live/.local/bin ]]; then
    chmod 755 /home/live/.local/bin/* 2>/dev/null || true
fi
# mkarchiso strips exec bits when it copies airootfs and skel into homes
# ("cp -af --no-preserve=ownership,mode"), so restore what the shell runs at
# runtime from its own tree BEFORE anything tests for it: the watchdog, and
# every plugin's helper bins. Skel and the live home alike.
for base in /etc/skel /home/live; do
    [[ -d "$base/.config/quickshell" ]] || continue
    chmod 755 "$base/.config/quickshell/tools/watchdog/aequalyn-watchdog" 2>/dev/null || true
    find "$base/.config/quickshell" -type f -path "*/bin/*" -exec chmod 755 {} + 2>/dev/null || true
done
# install.sh copies the shell from /opt/aequalyn/shell into new homes. That
# source tree went through mkarchiso's mode-stripping too, so fix it as well;
# otherwise the installed launcher is 644 and its .desktop entry cannot run.
if [[ -d /opt/aequalyn/shell ]]; then
    chmod 755 /opt/aequalyn/shell/tools/watchdog/aequalyn-watchdog \
              /opt/aequalyn/shell/plugins/clipboard/capture.sh 2>/dev/null || true
    find /opt/aequalyn/shell -type f -path "*/bin/*" -exec chmod 755 {} + 2>/dev/null || true
fi
# The watchdog lives in the shell tree; install.sh links it into ~/.local/bin
# for real homes, but skips skel (its symlink would point back into /etc/skel).
# The live user's home is a real home now, so give it the real link: the live
# desktop starts supervised, with the sandbox and the root gate, exactly like
# an installed one.
if [[ -f /home/live/.config/quickshell/tools/watchdog/aequalyn-watchdog ]]; then
    ln -sfn /home/live/.config/quickshell/tools/watchdog/aequalyn-watchdog \
        /home/live/.local/bin/aequalyn-watchdog
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
chmod 755 /etc/skel/.config/quickshell/plugins/clipboard/capture.sh 2>/dev/null || true
if [[ -d /home/live/.config/quickshell/plugins/clipboard ]]; then
    chmod 755 /home/live/.config/quickshell/plugins/clipboard/capture.sh 2>/dev/null || true
fi

# The plugins' own command helpers. Most are called through `bash` or
# `python3`, but the FM's launcher is exec'd directly (its desktop entry and
# the D-Bus service file), so keep every plugin bin runnable.
for d in /etc/skel/.config/quickshell/plugins/*/bin; do
    [[ -d $d ]] && chmod 755 "$d"/* 2>/dev/null || true
done
for d in /home/live/.config/quickshell/plugins/*/bin; do
    [[ -d $d ]] && chmod 755 "$d"/* 2>/dev/null || true
done
# And their daemons: desktop-icons.py is exec'd directly for the desktop
# icons feature (git carries it executable; the mode must survive the ISO).
# Everything in a daemon dir is a helper nobody sources, so the lot may run.
for d in /etc/skel/.config/quickshell/plugins/*/daemon /home/live/.config/quickshell/plugins/*/daemon; do
    [[ -d $d ]] && chmod 755 "$d"/* 2>/dev/null || true
done
# Same for the tree the installer copies from. install.sh repeats this after
# the copy, but fixing the source too keeps a live install and a later
# aequalyn-update from ever installing a non-executable aequalyn-fm.
for d in /opt/aequalyn/shell/plugins/*/bin /opt/aequalyn/shell/plugins/*/daemon; do
    [[ -d $d ]] && chmod 755 "$d"/* 2>/dev/null || true
done

# The live user may install without a password.

chmod 440 /etc/sudoers.d/live 2>/dev/null || true

# Raise the pam_faillock retry limit from the default 3 to 10 for the live
# user (system-auth is shared by sudo), mirroring increase-lockout-limit.sh.
if [[ -f /etc/pam.d/system-auth ]]; then
    sed -i 's|^\(auth\s\+required\s\+pam_faillock.so\)\s\+preauth.*$|\1 preauth silent deny=10 unlock_time=120|' \
        /etc/pam.d/system-auth
    sed -i 's|^\(auth\s\+\[default=die\]\s\+pam_faillock.so\)\s\+authfail.*$|\1 authfail deny=10 unlock_time=120|' \
        /etc/pam.d/system-auth
fi
if [[ -f /etc/pam.d/sddm-autologin ]]; then
    sed -i '/pam_faillock\.so preauth/d'  /etc/pam.d/sddm-autologin
    sed -i '/pam_faillock\.so authsucc/d' /etc/pam.d/sddm-autologin
    sed -i '/auth.*pam_permit\.so/a auth        required    pam_faillock.so authsucc' \
        /etc/pam.d/sddm-autologin
fi

# Plymouth boot splash: the theme is staged in the image by the ISO build.
# Set it as the default and rebuild the initramfs in the same step, because the
# initramfs built during pacstrap used the package's default theme.
if [[ -f /usr/share/plymouth/themes/aequalyn/aequalyn.plymouth ]]; then
    echo "Plymouth: setting aequalyn theme and rebuilding the initramfs"
    plymouth-set-default-theme aequalyn -R
else
    echo "WARNING: /usr/share/plymouth/themes/aequalyn is missing; no boot splash" >&2
fi

# Fix directory permissions: pacstrap may inherit a restrictive umask from the
# build environment, leaving /, /etc, /var, /home, /boot unreadable by non-root
# users (dbus, sddm, systemd services). That breaks D-Bus and SDDM autologin.
chmod 755 / 2>/dev/null || true
for d in etc var home boot usr opt srv mnt; do
    [[ -e /$d ]] || continue
    chmod 755 /$d 2>/dev/null || true
done
chmod 700 /root 2>/dev/null || true
chmod 1777 /tmp 2>/dev/null || true

# pacstrap/mkarchiso create these nested dirs under the same restrictive umask.
# They must stay world-traversable: package tools and unprivileged helpers read
# the local package database and the package cache (a+rx, not just root-only).
for d in /var/lib/pacman /var/lib/pacman/local /var/lib/pacman/sync \
         /var/cache/pacman /var/cache/pacman/pkg; do
    [[ -d $d ]] && chmod 755 "$d" 2>/dev/null || true
done
# Its version file above all: pacman, run by a user who cannot read it, says the database is of
# an incorrect version and ends with 255.
[[ -f /var/lib/pacman/local/ALPM_DB_VERSION ]] && chmod 644 /var/lib/pacman/local/ALPM_DB_VERSION 2>/dev/null || true
# Chromium-family browsers run as the desktop user and read their managed
# policy from /etc/<browser>/policies/managed. A restrictive build umask can
# leave /etc/opt and friends 0700: the 0644 color.json is then unreadable and
# the user half of aequalyn-browser-theme cannot see it, so every theme change
# asks for approval again. Keep the whole path traversable in the live image.
for d in /etc/opt /etc/chromium /etc/brave /etc/vivaldi /etc/yandex-browser; do
    [[ -d $d ]] && chmod 755 "$d" 2>/dev/null || true
done
for d in /etc/opt/* /etc/chromium/* /etc/brave/* /etc/vivaldi/* /etc/yandex-browser/*; do
    [[ -d $d ]] && chmod 755 "$d" 2>/dev/null || true
done
for d in /etc/opt/*/policies/managed /etc/chromium/policies/managed \
         /etc/brave/policies/managed /etc/vivaldi/policies/managed \
         /etc/yandex-browser/policies/managed; do
    [[ -d $d ]] || continue
    chmod 755 "$d" 2>/dev/null || true
    [[ -f $d/color.json ]] && chmod 644 "$d/color.json" 2>/dev/null || true
done
# The desktop watches /usr/share/aequalyn/lockscreens.enabled with a FileView;
# mkarchiso's mode stripping can leave this directory root-only.
chmod 755 /usr/share/aequalyn 2>/dev/null || true
[[ -e /usr/share/aequalyn/lockscreens.enabled ]] \
    && chmod 644 /usr/share/aequalyn/lockscreens.enabled 2>/dev/null || true
# The Quickshell lock plugin will not lock without its PAM service files. The
# live image has no migration runner, so install them here. SUDO_USER makes the
# helper read the live user's templates rather than root's.
for apply_lock in /home/live/.local/bin/aequalyn-apply-lock \
                  /etc/skel/.local/bin/aequalyn-apply-lock; do
    [[ -x $apply_lock ]] || continue
    if ! SUDO_USER=live "$apply_lock" >/dev/null 2>&1; then
        echo "WARNING: could not install the live lock screen's PAM stacks" >&2
    fi
    break
done
# SDDM owns the boot login: it autologins `live` into the guarded Hyprland
# session. This runs in the archiso chroot, so `systemctl enable` just writes
# the display-manager.service alias (no daemon is started here).
# Make sure the autologin config is present and points at a real session.
mkdir -p /etc/sddm.conf.d
if [[ ! -f /etc/sddm.conf.d/autologin.conf ]]; then
    cat > /etc/sddm.conf.d/autologin.conf <<'EOF'
[Autologin]
User=live
Session=aequalyn
Relogin=false
EOF
fi
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

# The optional floating titlebar plugin: ship it into the live user's home (and
# skel) so the deferred load in aequalyn-session-start and Super + Shift + T
# can find it. The core tree carries it in /opt/aequalyn/bin.
for base in /etc/skel /home/live; do
    [[ -d "$base" ]] || continue
    mkdir -p "$base/.local/lib/aequalyn"
    if [[ -f /opt/aequalyn/bin/hyprbars.so ]]; then
        cp -f /opt/aequalyn/bin/hyprbars.so "$base/.local/lib/aequalyn/hyprbars.so"
        chmod 755 "$base/.local/lib/aequalyn/hyprbars.so"
    fi
done
if [[ -d /home/live/.local/lib/aequalyn ]]; then
    chown -R 1000:1000 /home/live/.local/lib/aequalyn 2>/dev/null || true
fi

exit 0
