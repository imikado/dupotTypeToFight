#!/usr/bin/env python3
# Génère l'image de couverture itch.io (630x500, taille recommandée) à partir des
# assets du jeu : forêt en décor, titre en police Pixeled, grande touche F au
# centre comme en jeu, le loup face aux ennemis.
# L'image est composée à 315x250 puis doublée sans lissage (pixels nets).
#
# Usage : python3 tools/generate_itch_cover.py [fichier_de_sortie]
# Dépendance : Pillow (paquet python3-pil)
import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "export", "itch", "cover.png")
W, H = 315, 250


def asset(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGBA")


def tint(img, factor):
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = Image.eval(rgb, lambda v: round(v * factor))
    return Image.merge("RGBA", (*rgb.split(), a))


def tiled(img, y, width):
    layer = Image.new("RGBA", (width, H), (0, 0, 0, 0))
    for x in range(0, width, img.width):
        layer.alpha_composite(img, (x, y))
    return layer


def outlined(sprite):
    # contour noir d'un pixel autour du sprite (comme l'icône)
    w, h = sprite.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    alpha = Image.new("L", (w + 2, h + 2), 0)
    alpha.paste(sprite.getchannel("A"), (1, 1))
    out.paste((0, 0, 0, 255), (0, 0), alpha.filter(ImageFilter.MaxFilter(3)))
    out.paste(sprite, (1, 1), sprite)
    return out


def frame(path, index, flip=False):
    sheet = asset(path)
    f = sheet.crop((index * 64, 0, index * 64 + 64, 64))
    f = f.crop(f.getbbox())
    if flip:
        f = f.transpose(Image.FLIP_LEFT_RIGHT)
    f = outlined(f)
    return f.resize((f.width * 2, f.height * 2), Image.NEAREST)


cover = Image.new("RGBA", (W, H), (0, 50, 74, 255))

# décor : ciel, arbres lointains (assombris), arbres proches, sol, buissons
cover.alpha_composite(asset("src/Levels/Shared/sky.png").crop((0, 0, W, 120)), (0, 0))
trees = asset("src/Levels/Shared/background-trees-up.png")
cover.alpha_composite(tint(trees, 0.55).crop((150, 0, 150 + W, trees.height)), (0, 84))
cover.alpha_composite(trees.crop((0, 0, W, trees.height)), (0, 100))
cover.alpha_composite(tiled(asset("src/Levels/Shared/background.png"), 158, W))
cover.alpha_composite(asset("src/Levels/Shared/background-brushes-down.png").crop((0, 0, W, 18)), (0, 150))

# personnages, les pieds sur la même ligne
GROUND = 214
player = frame("src/Actors/Players/Player/player-attacking-02.png", 1)
cover.alpha_composite(player, (20, GROUND - player.height))
for path, index, x in [("src/Actors/Enemies/Ant/ant-walking.png", 0, 160),
                       ("src/Actors/Enemies/Spider/spider-walking.png", 1, 226)]:
    enemy = frame(path, index, flip=True)
    cover.alpha_composite(enemy, (x, GROUND - enemy.height))

# buissons sombres au premier plan
brushes = asset("src/Levels/Shared/background-brushes-down.png").crop((200, 0, 200 + W // 2 + 10, 18))
brushes = tint(brushes.resize((brushes.width * 2, brushes.height * 2), Image.NEAREST), 0.35)
cover.alpha_composite(brushes, (0, H - brushes.height + 4))

draw = ImageDraw.Draw(cover)
draw.fontmode = "1"  # pas d'anticrénelage : texte en pixels nets
font_path = os.path.join(ROOT, "src/UI/Controls/Shared/Pixeled.ttf")

# grande touche F au centre, comme en jeu (couleur de l'index gauche), avec son anneau
F_COLOR = (242, 237, 61)
J_COLOR = (115, 120, 255)
cx, cy = 150, 104
draw.ellipse((cx - 27, cy - 27, cx + 27, cy + 27), outline=(77, 230, 102), width=2)
draw.rounded_rectangle((cx - 17, cy - 17, cx + 17, cy + 17), radius=4,
                       fill=tuple(round(v * 0.55) for v in F_COLOR), outline=F_COLOR, width=2)
key_font = ImageFont.truetype(font_path, 16)
draw.text((cx, cy), "F", font=key_font, anchor="mm", fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
# touche suivante, plus petite
small_font = ImageFont.truetype(font_path, 12)
draw.text((cx + 42, cy), "J", font=small_font, anchor="mm", fill=J_COLOR, stroke_width=2, stroke_fill=(0, 0, 0))

# titre et accroche
title_font = ImageFont.truetype(font_path, 24)
draw.text((W // 2, 26), "Type to Fight", font=title_font, anchor="mm", fill=(51, 194, 71), stroke_width=3, stroke_fill=(10, 20, 30))
tagline_font = ImageFont.truetype(font_path, 8)
draw.text((W // 2, 54), "Learn to type with ten fingers!", font=tagline_font, anchor="mm", fill=(255, 255, 255), stroke_width=2, stroke_fill=(10, 20, 30))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
cover.resize((W * 2, H * 2), Image.NEAREST).convert("RGB").save(OUT, optimize=True)
print("Couverture itch.io générée :", OUT)
