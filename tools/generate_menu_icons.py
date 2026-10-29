#!/usr/bin/env python3
# Génère l'icône de langue (globe) du menu, dans le style de icon-keyboard.png
# (contour clair, fond bleu nuit) : src/UI/Controls/Shared/icon-language.png
#
# Usage : python3 tools/generate_menu_icons.py
# Dépendance : Pillow (paquet python3-pil)
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "UI", "Controls", "Shared", "icon-language.png")

COLORS = {
    "A": (230, 235, 255, 255),  # trait clair
    "B": (40, 45, 100, 255),  # fond bleu nuit
    ".": (0, 0, 0, 0),
}

GLOBE = [
    "...AAA...",
    ".AABABAA.",
    ".ABBABBA.",
    "AAAAAAAAA",
    "ABBBABBBA",
    "AAAAAAAAA",
    ".ABBABBA.",
    ".AABABAA.",
    "...AAA...",
]

image = Image.new("RGBA", (len(GLOBE[0]), len(GLOBE)))
for y, row in enumerate(GLOBE):
    for x, char in enumerate(row):
        image.putpixel((x, y), COLORS[char])
image.save(OUT)
print(OUT)
