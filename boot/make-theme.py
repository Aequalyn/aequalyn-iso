#!/usr/bin/env python3
"""make-theme.py -- draws the ISO's boot menu: boot/grub-theme (UEFI) and boot/syslinux (BIOS).

The drawn files are in the repo, so an ISO build needs nothing of this; run it after a
change here. Needs rsvg-convert and JetBrainsMono Nerd Font. GRUB cannot draw a second
line or lay icons out, so each entry's card (icon, title, what it does) is one picture,
shown as that entry's icon; its own title is what the text menu shows.
"""
import os, pathlib, subprocess
HERE = pathlib.Path(__file__).resolve().parent
os.chdir(HERE)
FONT = 'font-family="JetBrainsMono Nerd Font"'
ACC, BG = "#4fc3b3", "#0c1113"
W, H = 610, 46                              # a card
ICON = {
 "screen": '<rect x="0" y="0" width="38" height="26" rx="4"/><path d="M12 36h14M19 26v10"/><path d="M12 13l5 5 9-10"/>',
 "speech": '<path d="M4 13h8l10-9v28l-10-9H4z"/><path d="M28 11a10 10 0 0 1 0 14M33 5a18 18 0 0 1 0 26"/>',
 "memory": '<rect x="6" y="8" width="26" height="20" rx="3"/><path d="M12 8V3M19 8V3M26 8V3M12 33v-5M19 33v-5M26 33v-5"/>',
 "shell": '<rect x="4" y="5" width="30" height="24" rx="4"/><path d="M11 13l5 4-5 4M19 22h8"/>',
 "gear": '<circle cx="19" cy="18" r="5"/><path d="M19 5v5M19 26v5M6 18h5M27 18h5M10 9l3.500 3.500M24.500 23.500L28 27M28 9l-3.500 3.500M13.500 23.500L10 27"/>',
 "restart": '<path d="M29 18a10 10 0 1 1-3-7.100M29 6v7h-7"/>',
 "power": '<path d="M19 4v13M12 9a11 11 0 1 0 14 0"/>',
}
CARDS = {                                    # GRUB class: icon, title, what it does
 "aequalyn":   (None, "Aequalyn live", "Try the desktop, or install it"),
 "aeqsafe":    ("screen", "Aequalyn live, safe graphics", "Integrated GPU only, if the screen stays black"),
 "aeqspeech":  ("speech", "Aequalyn live, with speech", "The screen reader speaks from the start"),
 "aeqmemory":  ("memory", "Memory test", ""),
 "aeqshell":   ("shell", "EFI shell", ""),
 "aeqfirmware":("gear", "Firmware settings", ""),
 "aeqrestart": ("restart", "Restart", ""),
 "aeqpower":   ("power", "Power off", ""),
}
def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}" {FONT}>{body}</svg>')
def png(name, w, h, body):
    (HERE / "t.svg").write_text(svg(w, h, body))
    subprocess.run(["rsvg-convert", "t.svg", "-o", name], check=True)
    (HERE / "t.svg").unlink()
    # GRUB and syslinux read plain 8-bit RGB(A)
    subprocess.run(["magick", name, "-strip", "-define", "png:color-type=" + ("2" if "background" in name or "splash" in name else "6"), "-depth", "8", name], check=True)
GLOW = f'<defs><radialGradient id="g" cx="50%" cy="0%" r="75%"><stop offset="0" stop-color="{ACC}" stop-opacity=".20"/><stop offset="1" stop-color="{ACC}" stop-opacity="0"/></radialGradient></defs>'
def ground(w, h): return f'{GLOW}<rect width="{w}" height="{h}" fill="{BG}"/><rect width="{w}" height="{h}" fill="url(#g)"/>'

png("grub-theme/background.png", 1920, 1080, ground(1920, 1080))
png("grub-theme/logo.png", 340, 124, '<image x="0" y="0" width="340" height="84" xlink:href="aequalyn-wordmark.svg"/><text x="172" y="118" fill="#7d8b8a" font-size="15" text-anchor="middle" letter-spacing="5">LIVE AND INSTALL</text>')
png("grub-theme/keys.png", 420, 24, '<text x="210" y="17" fill="#66736f" font-size="13" text-anchor="middle">↑ ↓ choose  ·  Enter start  ·  E edit</text>')
for cls, (icon, title, sub) in CARDS.items():
    b = ('<image x="10" y="6" width="56" height="35" xlink:href="ae-mark.svg"/>' if icon is None else
         f'<g fill="none" stroke="#9fb0ae" stroke-width="2.400" stroke-linejoin="round" stroke-linecap="round" transform="translate(19 5)">{ICON[icon]}</g>')
    if sub:
        b += f'<text x="92" y="18" fill="#eef4f3" font-size="18">{title}</text><text x="92" y="40" fill="#8b9a98" font-size="13">{sub}</text>'
    else:
        b += f'<text x="92" y="29" fill="#b9c6c4" font-size="17">{title}</text>'
    png(f"grub-theme/icons/{cls}.png", W, H, b)
# the chosen card, in nine parts
R = 12
def parts(prefix, fill, stroke):
    full, n = 48, {}
    sh = f'<rect x="0.750" y="0.750" width="{full-1.5}" height="{full-1.5}" rx="{R-1}" fill="{fill}" stroke="{stroke}" stroke-width="1.500"/>'
    m = full - 2 * R
    for k, (x, y, w, h) in {"nw": (0, 0, R, R), "n": (R, 0, m, R), "ne": (R+m, 0, R, R), "w": (0, R, R, m), "c": (R, R, m, m), "e": (R+m, R, R, m),
                            "sw": (0, R+m, R, R), "s": (R, R+m, m, R), "se": (R+m, R+m, R, R)}.items():
        png(f"grub-theme/{prefix}_{k}.png", w, h, f'<g transform="translate({-x} {-y})">{sh}</g>')
parts("item", "#12181a", "#202a2c")
parts("select", "#1b3a38", ACC)
# GRUB makes a bar at least a line of text high: only the middle of it is drawn, so it is thin
for k, c in (("bar", "#1b2325"), ("fill", ACC)):
    png(f"grub-theme/{k}_c.png", 4, 28, f'<rect y="12" width="4" height="4" fill="{c}"/>')
png("grub-theme/thumb_c.png", 4, 4, '<rect width="4" height="4" fill="#33413f"/>')
# The terminal is where GRUB says "Booting ..." while it loads the kernel, and where E
# edits an entry. GRUB will not make it smaller than about 80 x 24 characters, so it covers
# the whole screen; its colour is set by background_color in grub.cfg (aequalyn-iso-make),
# the background's own base, so choosing an entry leaves a calm, flat screen rather than
# a black box over the menu.
(HERE / "grub-theme/theme.txt").write_text('''# Aequalyn boot menu (drawn by boot/make-theme.py)
title-text: ""
desktop-image: "background.png"
desktop-image-scale-method: "stretch"
desktop-color: "#0c1113"
terminal-font: "Unifont Regular 16"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"

+ image {
    left = 50%-170
    top = 7%
    width = 340
    height = 124
    file = "logo.png"
}

+ boot_menu {
    left = 50%-357
    top = 7%+144
    width = 700
    height = 93%-254
    item_font = "Unifont Regular 16"
    # an entry's own title would come after its card: there, in the card's colour
    item_color = "#12181a"
    selected_item_color = "#1b3a38"
    item_height = 46
    item_padding = 0
    item_spacing = 32
    item_icon_space = 0
    icon_width = 610
    icon_height = 46
    item_pixmap_style = "item_*.png"
    selected_item_pixmap_style = "select_*.png"
    scrollbar = true
    scrollbar_width = 4
    scrollbar_thumb = "thumb_*.png"
}

+ progress_bar {
    id = "__timeout__"
    left = 50%-150
    top = 100%-96
    width = 300
    height = 28
    show_text = false
    bar_style = "bar_*.png"
    highlight_style = "fill_*.png"
}

+ image {
    left = 50%-210
    top = 100%-58
    width = 420
    height = 24
    file = "keys.png"
}
''')
# BIOS: syslinux draws its own list over a picture
png("syslinux/splash.png", 1024, 768, ground(1024, 768) + '<image x="362" y="70" width="300" height="74" xlink:href="aequalyn-wordmark.svg"/><text x="512" y="176" fill="#7d8b8a" font-size="14" text-anchor="middle" letter-spacing="5">LIVE AND INSTALL</text>')
print("drawn")
