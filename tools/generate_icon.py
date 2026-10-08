#!/usr/bin/env python3
# Génère l'icône de Type to Fight dans le style dupot.org (comme Save the Sheep et
# Beat And Match To Pass) : cercle blanc dégradé, onglet orange avec un « d »,
# personnage en pixel art cerné de noir ; ici le loup et les touches F et J aux
# couleurs du jeu.
#
# Sans argument, met à jour toutes les icônes du projet :
#   - export/Linux/flatpak/icons/<taille>.png (16 à 512 px, pour Flathub)
#   - icon.png (256 px, icône du projet Godot et des exports)
#   - export/Linux/snap/snap/gui/dupot-type-to-fight.png (icône du snap)
#
# Usage : python3 tools/generate_icon.py [dossier_de_sortie]
# Dépendance : Pillow (paquet python3-pil)
import os
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS_DIR = os.path.join(ROOT, "export", "Linux", "flatpak", "icons")
out = sys.argv[1] if len(sys.argv) > 1 else ICONS_DIR
os.makedirs(out, exist_ok=True)
root = ROOT

S = 512
ORANGE = (0xEE, 0x5F, 0x00, 255)

icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(icon)
# onglet orange en haut à droite, sous le cercle
d.rounded_rectangle((224, 0, S - 1, 288), radius=31, fill=ORANGE)
# cercle blanc avec dégradé horizontal blanc -> bleu très pâle
circle = Image.new("RGBA", (S, S), (0, 0, 0, 0))
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
for x in range(S):
    t = x / (S - 1)
    gd.line((x, 0, x, S), fill=(round(255 - (255 - 0xD6) * t), round(255 - (255 - 0xE1) * t), round(255 - (255 - 0xF5) * t), 255))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse((6, 18, 494, 506), fill=255)
circle.paste(grad, (0, 0), mask)
icon = Image.alpha_composite(icon, circle)
# « d » blanc dans l'onglet
def bold_font(size):
    for path in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    sys.exit("Police DejaVu Sans Bold introuvable (paquet fonts-dejavu-core)")
font = bold_font(92)
ImageDraw.Draw(icon).text((432, -6), "d", font=font, fill=(255, 255, 255, 255))

def outlined(sprite):
    # contour noir d'un pixel autour du sprite (avant agrandissement)
    w, h = sprite.size
    out_img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    alpha = Image.new("L", (w + 2, h + 2), 0)
    alpha.paste(sprite.getchannel("A"), (1, 1))
    border = alpha.filter(ImageFilter.MaxFilter(3))
    out_img.paste((0, 0, 0, 255), (0, 0), border)
    out_img.paste(sprite, (1, 1), sprite)
    return out_img

# le loup, épée tenue droite (1re image de l'attaque 1)
sheet = Image.open(root + "/src/Actors/Players/Player/player-attacking-01.png").convert("RGBA")
frame = sheet.crop((0, 0, 64, 64))
wolf = outlined(frame.crop(frame.getbbox()))
SCALE = 11
wolf = wolf.resize((wolf.width * SCALE, wolf.height * SCALE), Image.NEAREST)
icon.alpha_composite(wolf, (40, S - wolf.height - 22))

# touches F et J en pixel art, aux couleurs du jeu (FINGER_COLORS de GlobalLessons.gd)
FONT = {"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "J": ["..###", "....#", "....#", "....#", "#...#", "#...#", ".###."]}
def game_color(r, g, b):
    return (round(r * 255), round(g * 255), round(b * 255), 255)
def darkened(c, amount):
    return tuple(round(v * (1 - amount)) for v in c[:3]) + (255,)
def keycap(color, letter):
    k = Image.new("RGBA", (13, 15), (0, 0, 0, 0))
    kd = ImageDraw.Draw(k)
    kd.rounded_rectangle((0, 2, 12, 14), radius=2, fill=darkened(color, 0.55))
    kd.rounded_rectangle((0, 0, 12, 12), radius=2, fill=darkened(color, 0.2), outline=color)
    pixels = [(4 + i, 3 + j) for j, row in enumerate(FONT[letter]) for i, c in enumerate(row) if c == "#"]
    for px, py in pixels:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                kd.point((px + dx, py + dy), fill=(0, 0, 0, 255))
    for px, py in pixels:
        kd.point((px, py), fill=(255, 255, 255, 255))
    k = outlined(k)
    return k.resize((k.width * 8, k.height * 8), Image.NEAREST)
icon.alpha_composite(keycap(game_color(0.95, 0.93, 0.24), "F"), (292, 208))
icon.alpha_composite(keycap(game_color(0.45, 0.47, 1.00), "J"), (372, 318))

icon.save(out + "/512x512.png")
for size in [16, 24, 32, 48, 64, 128, 256]:
    icon.resize((size, size), Image.LANCZOS).save("%s/%dx%d.png" % (out, size, size))

# sans dossier de sortie précisé : on met aussi à jour l'icône du projet et du snap
if len(sys.argv) <= 1:
    shutil.copy(os.path.join(out, "256x256.png"), os.path.join(ROOT, "icon.png"))
    shutil.copy(os.path.join(out, "256x256.png"), os.path.join(ROOT, "export", "Linux", "snap", "snap", "gui", "dupot-type-to-fight.png"))
print("Icônes générées dans", out)
