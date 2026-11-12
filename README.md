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

The live session logs in as `live` straight into the desktop; run
`sudo aequalyn-install` (or `Super + I`) to install.

## Credits

[nightdevil00](https://github.com/nightdevil00) contributed to the code here.
