# Aequalyn ISO — security notes

- Live session: user `live` password `live`; root password `live`; sudo passwordless for
  `live` (ephemeral medium). Autologin into the `aequalyn` Wayland session.
- Root rescue shell on tty2 (`Ctrl+Alt+F2`).
- Display scale fixed at 1 (no HiDPI auto-detection).
- Offline package repo uses `SigLevel = Never` (bundled media must be trusted).
- First-boot AUR bootstrap (if enabled) runs unverified `makepkg`.
- Build requires ~30 GB free space; keep `work/` between builds only if trusted.

See `aequalyn/Security.md` for system-level concerns.
