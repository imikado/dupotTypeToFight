<div align="center">

<img src="export/Linux/flatpak/icons/128x128.png" alt="Type to Fight" width="128" />

# ⌨️ Type to Fight

**An arcade game to learn touch typing: type the right key to strike the enemies.**

Free · All ages · Play in your browser · Made with Godot 4.7

[![itch.io](https://img.shields.io/badge/itch.io-Play%20in%20browser-FA5C5C?logo=itchdotio&logoColor=white)](https://dupot-org.itch.io/type-to-fight)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org)
[![License: LGPL-2.1](https://img.shields.io/badge/License-LGPL--2.1-blue.svg)](LICENSE)

**▶️ [Play now on itch.io](https://dupot-org.itch.io/type-to-fight)**

<img src="docs/gameplay.gif" alt="Type to Fight gameplay" width="720" />

</div>

---

## 📖 About

Enemies keep coming from the right. The next key to type **falls in the center of the screen**: type it to strike the enemy, or rush towards it if it is still far away. Miss too often and they will reach you!

- 🎓 **Tutorial before playing**: where to put your hands, the small bumps on F and J, one finger per color, shown with zoomed keys and pixel art hands (with a Skip button, and it can be turned off in the settings)
- 🎯 **Progressive lessons**: start with the **F** and **J** home keys, then D K, S L, Q M, G H, the top row and the bottom row, in **AZERTY** or **QWERTY**
- 🖐️ **One color per finger**: warm colors for the left hand, complementary colors for the right hand, darker on the top row and lighter on the bottom row
- 🥁 **Rhythm-game feel**: the key falls in the center with an approach ring, the next keys slide along the lane at the bottom of the screen
- ✅ **Get ready**: each level starts by placing your index fingers on F and J and finding the new keys
- ❌ **Learn from mistakes**: a keyboard shows the wrong key and the expected one, and your weak keys come back more often until you master them
- 📊 **Earn your progress**: 94% accuracy is needed to unlock the next level (or 90%, 80%, 70% in the settings), with live per-key stats and a recap at the end of each level
- 🏃 **Runner style**: the camera follows the player through an endless parallax forest
- 🌍 Available in **English** and **French**

## 📸 Screenshots

<div align="center">

| Type the falling key | Get ready: index fingers on F and J | The key to type, colored by finger |
|:---:|:---:|:---:|
| ![Gameplay](export/Linux/screenshots/Screenshot_01_gameplay.png) | ![Ready screen](export/Linux/screenshots/Screenshot_02_ready.png) | ![Keyboard layout](export/Linux/screenshots/Screenshot_03_layout.png) |
| **Wrong key? The keyboard shows you** | **Level results** | **Main menu** |
| ![Error](export/Linux/screenshots/Screenshot_04_error.png) | ![Level results](export/Linux/screenshots/Screenshot_05_stats.png) | ![Menu](export/Linux/screenshots/Screenshot_06_menu.png) |

</div>

## 🎮 Controls

| Action | Keyboard |
|---|---|
| Strike an enemy | Type the key shown in the center |
| Start a level | Press F, J and the new keys of the level |
| Show / hide the small keyboard | `Tab` (or the keyboard button at the top) |
| Continue after the level results | `Space` or `Enter` |
| Pause | `Esc` |
| Tutorial: next page / skip | `Space` or `Enter` / `Esc` |

The **Settings** of the main menu let you choose the difficulty, the keyboard layout (AZERTY / QWERTY), the language, the accuracy needed to pass a level (94%, 90%, 80% or 70%) and whether the tutorial is shown before level 1.

## 📦 Play

### itch.io (browser)

Play it in your browser, no install needed: **[dupot-org.itch.io/type-to-fight](https://dupot-org.itch.io/type-to-fight)**

### Flathub and Snap Store (Linux): coming soon

Linux packages are being prepared (`org.dupot.typetofight` on Flathub, `dupot-type-to-fight` on the Snap Store). The packaging files and the icon are ready in `export/Linux`; they will be published soon.

## 🛠️ Build from source

1. Install [Godot 4.7](https://godotengine.org/download).
2. Clone the repository:
   ```bash
   git clone https://github.com/imikado/dupotTypeToFight.git
   ```
3. Open `project.godot` in Godot and press **F5** to play.

Export presets for **Linux** and **HTML5** are included in `export_presets.cfg`, with helper scripts (they use `godot` from your `PATH`, or the `GODOT` environment variable):

| Script | Result |
|---|---|
| `./export_html5.sh` | HTML5 export in `export/HTML5/` and `dupotTypeToFight-html5.zip` (the build uploaded to itch.io) |
| `./bundle.sh` | `export/Linux/bundle.tar.gz` for the Flathub manifest (pck, icons, appdata, .desktop) |
| `./export/Linux/snap/update-version.sh` | syncs the snap version with `config/version` in `project.godot` |
| `./export/Linux/snap/build-snap.sh` | exports the Linux build and packs the snap |
| `python3 tools/generate_icon.py` | regenerates the game icon in the dupot.org style (Flathub sizes, `icon.png`, snap icon) from the player sprite; needs Pillow |
| `python3 tools/generate_itch_cover.py` | regenerates the itch.io cover image (630x500) in `export/itch/cover.png` from the game assets; needs Pillow |
| `python3 tools/generate_tutorial_hands.py` | regenerates the pixel art hands of the tutorial (`src/UI/Hands/hand-left.png`, `hand-right.png`); needs Pillow |

## 🌍 Translations

Texts live in `src/Locales/translations.csv` (one column per language). To add a language: add a column to the CSV, register its generated `.translation` file in `project.godot` (Internationalization), add its code to `GlobalGame.LANGUAGES` and an entry in the menu. Note that the Pixeled font does not include every accented letter (no ê, à, â, î, ô, û…).

## 🗂️ Project structure

- `src/Autoload`: global state (game, player, lessons and finger colors, events, transition)
- `src/Actors`: player and enemies (ant, spider, beetle)
- `src/Levels`: main level and parallax background
- `src/UI`: HUD, key lane, center key, keyboards, level results, tutorial, screens (boot, menu with settings, tutorial, game over)
- `src/Locales`: translations
- `tools`: Python scripts generating the icon, the itch.io cover and the tutorial hands
- `docs`: gameplay GIFs
- `export/Linux`: Flathub and Snap packaging files, store screenshots
- `export/itch`: itch.io cover image

Sprites and font come from Beat And Match To Pass.

## 🕹️ More from dupot.org

Also from the same developer:

- **Save the Sheep**
- **Beat And Match To Pass**
- **Little Adventure**
- **Easyflatpak**

See them all on [dupot.org](https://www.dupot.org/games.html).

## 🐛 Feedback

Found a bug or have an idea? [Open an issue](https://github.com/imikado/dupotTypeToFight/issues).

## 📜 License

This game is released under the [GNU LGPL v2.1](LICENSE).

---

<div align="center">

Made with ❤️ and [Godot Engine](https://godotengine.org) by [Michael Bertocchi](https://www.dupot.org/games.html) · [dupot.org](https://www.dupot.org)

</div>
