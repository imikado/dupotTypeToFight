#!/usr/bin/env bash
# Génère les GIF de présentation (docs/training.gif, docs/arcade.gif) et les
# captures d'écran (export/Linux/screenshots) : un bot joue à la place du joueur
# (voir tools/capture_media.gd). Ouvre brièvement des fenêtres du jeu.
#
# Usage : tools/capture_media.sh [chemin_vers_godot]
# Dépendances : Godot 4.7, ffmpeg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-$HOME/Apps/Godot_v4.7-stable_linux.x86_64}"
USER_DATA="$HOME/.local/share/godot/app_userdata/dupotTypeToFight"
WORK="$(mktemp -d)"
GIF_FPS=15
# le jeu est rendu en 1440x810 (taille de fenêtre du projet) : réduit à 480x270,
# la taille d'origine du jeu en pixel art, le GIF reste léger
GIF_WIDTH=480
GIF_SCALING=area

# les scénarios modifient les paramètres et la progression : on les restaure
if [ -d "$USER_DATA" ]; then
	cp -a "$USER_DATA" "$WORK/user_data"
fi
restore() {
	rm -rf "$USER_DATA"
	if [ -d "$WORK/user_data" ]; then
		cp -a "$WORK/user_data" "$USER_DATA"
	fi
	rm -rf "$WORK"
}
trap restore EXIT
# captures à partir de données vierges (pas les scores du joueur)
rm -rf "$USER_DATA"

run() {
	SCENARIO="$1" SHOT="${2:-}" "$GODOT" --path "$ROOT" "${@:3}" --script res://tools/capture_media.gd >/dev/null 2>&1
}

for mode in training arcade; do
	mkdir -p "$WORK/$mode"
	run "gif_$mode" "" --fixed-fps 30 --write-movie "$WORK/$mode/frame.png"
	ffmpeg -v error -y -framerate 30 -i "$WORK/$mode/frame%08d.png" \
		-vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=$GIF_SCALING,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none" \
		"$ROOT/docs/$mode.gif"
	echo "docs/$mode.gif"
done

SHOTS="$ROOT/export/Linux/screenshots"
i=1
for scenario in shot_training shot_arcade shot_ready shot_error shot_stats shot_menu shot_levels; do
	name="$(printf 'Screenshot_%02d_%s.png' "$i" "${scenario#shot_}")"
	run "$scenario" "$SHOTS/$name"
	echo "export/Linux/screenshots/$name"
	i=$((i + 1))
done
