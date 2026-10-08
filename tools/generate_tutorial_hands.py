#!/usr/bin/env python3
# Génère les mains en pixel art du tutoriel (vue de dessus, doigts vers le haut) :
# src/UI/Hands/hand-left.png et hand-right.png (miroir).
# Les doigts sont espacés de 20 px : affichées en x2 dans le tutoriel, ils tombent
# pile sur des touches espacées de 40 px.
#
# Repères utilisés par src/UI/tutorial.gd (main gauche, avant agrandissement) :
#   centres des doigts (auriculaire -> index) : x = 10, 30, 50, 70
#   bout de l'index : y = 4
#
# Usage : python3 tools/generate_tutorial_hands.py
# Dépendance : Pillow (paquet python3-pil)
import os
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "src", "UI", "Hands")

W, H = 96, 55
CENTERS = [10, 30, 50, 70]   # auriculaire, annulaire, majeur, index
TIPS = [12, 4, 0, 4]
PALM_TOP = 30

OUTLINE = (60, 35, 25, 255)
SKIN = (250, 205, 160, 255)
SHADE = (222, 162, 122, 255)
NAIL = (255, 238, 225, 255)
CREASE = (214, 152, 112, 255)

mask = [[False] * W for _ in range(H)]


def fill(x0, y0, x1, y1):
    for y in range(max(0, y0), min(H, y1 + 1)):
        for x in range(max(0, x0), min(W, x1 + 1)):
            mask[y][x] = True


def unset(x, y):
    if 0 <= x < W and 0 <= y < H:
        mask[y][x] = False


# doigts, bouts arrondis
for cx, tip in zip(CENTERS, TIPS):
    fill(cx - 5, tip, cx + 4, PALM_TOP + 2)
    for x, y in [(cx - 5, tip), (cx + 4, tip), (cx - 5, tip + 1), (cx + 4, tip + 1), (cx - 4, tip), (cx + 3, tip)]:
        unset(x, y)
# paume aux coins arrondis
fill(3, PALM_TOP, 78, 53)
for x, y in [(3, 53), (78, 53), (3, 52), (78, 52), (4, 53), (77, 53)]:
    unset(x, y)
# pouce court en diagonale qui sort de la paume, vers la barre d'espace
for y in range(38, 54):
    d = y - 38
    fill(70 + d, y, 80 + d, y)
for x, y in [(85, 53), (95, 53), (94, 53), (86, 53), (80, 38), (79, 38)]:
    unset(x, y)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()


def inside(x, y):
    return 0 <= x < W and 0 <= y < H and mask[y][x]


for y in range(H):
    for x in range(W):
        if not mask[y][x]:
            continue
        edge = not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        px[x, y] = OUTLINE if edge else SKIN

# ombre sur le côté droit des doigts, ongles, plis des articulations
for cx, tip in zip(CENTERS, TIPS):
    for y in range(tip + 2, PALM_TOP + 2):
        for x in (cx + 2, cx + 3):
            if px[x, y] == SKIN:
                px[x, y] = SHADE
    for y in range(tip + 2, tip + 6):
        for x in range(cx - 3, cx + 2):
            if px[x, y] == SKIN:
                px[x, y] = NAIL
    for x in range(cx - 3, cx + 2):
        if px[x, tip + 14] == SKIN:
            px[x, tip + 14] = CREASE
for x in range(5, 77):
    if px[x, PALM_TOP + 4] == SKIN:
        px[x, PALM_TOP + 4] = CREASE
for y in range(48, 53):
    for x in range(5, 77):
        if px[x, y] == SKIN:
            px[x, y] = SHADE

os.makedirs(OUT_DIR, exist_ok=True)
img.save(os.path.join(OUT_DIR, "hand-left.png"))
ImageOps.mirror(img).save(os.path.join(OUT_DIR, "hand-right.png"))
print("Mains du tutoriel générées dans", OUT_DIR)
