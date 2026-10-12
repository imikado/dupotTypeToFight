#!/usr/bin/env bash
# Enregistre des parties jouées par un bot (tools/capture_media.gd, Movie Maker
# de Godot) en 1920x1080 avec le son du jeu, puis monte la vidéo de promotion
# YouTube export/promo/type_to_fight.mp4 :
#   - le menu
#   - une partie en mode Training (lettre par lettre), puis en mode Arcade (mots)
#   - écran de fin (titre, lien itch.io) sur la musique du menu
#
# Les parties sont reproductibles (temps fixe, graine fixe) : les extraits
# ci-dessous désignent toujours le même moment. Après un changement de
# gameplay, vérifier la vidéo et ajuster SEGMENTS si besoin.
#
# Usage : tools/promo_video.sh [dossier_enregistrements]
#   dossier_enregistrements : réutilise un enregistrement existant (un
#   sous-dossier par scénario avec f*.png + f.wav) au lieu de rejouer les parties
# Dépendances : Godot 4.7, ffmpeg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/Apps/Godot_v4.7-stable_linux.x86_64")}"
USER_DATA="$HOME/.local/share/godot/app_userdata/dupotTypeToFight"
FPS=60
# Extraits : scénario:début:fin (secondes):position verticale de la légende
# (fraction de la hauteur):légende
SEGMENTS=(
	"promo_menu:0.5:4.5::"
	"promo_training:1:14:0.79:TRAINING : LETTER BY LETTER"
	"promo_arcade:1:14:0.89:ARCADE : WHOLE WORDS"
)
FADE=0.5
END_CARD=7
FONT="src/UI/Controls/Shared/Jersey10.ttf"
END_MUSIC="src/Audio/Music/menu.wav"
VIDEO="export/promo/type_to_fight.mp4"

command -v ffmpeg >/dev/null || { echo "ffmpeg est requis" >&2; exit 1; }

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

calc() { awk "BEGIN { print $1 }"; }

if [ -n "${1:-}" ]; then
	RECORD_DIR="$1"
else
	if [ ! -x "$GODOT" ]; then
		echo "Godot introuvable ($GODOT) : définir la variable GODOT" >&2
		exit 1
	fi
	if [ -e override.cfg ]; then
		echo "override.cfg existe déjà : le supprimer d'abord" >&2
		exit 1
	fi
	RECORD_DIR="$WORK_DIR/record"

	# les scénarios modifient les paramètres et la progression : on les
	# restaure, et on enregistre à partir de données vierges
	if [ -d "$USER_DATA" ]; then
		cp -a "$USER_DATA" "$WORK_DIR/user_data"
	fi
	cleanup() {
		rm -f override.cfg
		rm -rf "$USER_DATA"
		if [ -d "$WORK_DIR/user_data" ]; then
			cp -a "$WORK_DIR/user_data" "$USER_DATA"
		fi
		rm -rf "$WORK_DIR"
	}

	# La taille de fenêtre du projet (1440x810) l'emporte sur --resolution :
	# override.cfg temporaire pour enregistrer en 1920x1080 (viewport x4)
	cat > override.cfg <<-EOF
		[display]

		window/size/window_width_override=1920
		window/size/window_height_override=1080
		window/size/borderless=true
	EOF
	for segment in "${SEGMENTS[@]}"; do
		scenario="${segment%%:*}"
		rm -rf "$USER_DATA"
		mkdir -p "$RECORD_DIR/$scenario"
		echo "Enregistrement : $scenario"
		# Avec une sortie .png, Godot écrit aussi le son dans f.wav
		SCENARIO="$scenario" "$GODOT" --path . --fixed-fps "$FPS" \
			--write-movie "$RECORD_DIR/$scenario/f.png" \
			--script res://tools/capture_media.gd >/dev/null 2>&1
	done
	rm -f override.cfg
fi

# Textes (fichiers : pas d'échappement des « : »)
echo "TYPE TO FIGHT" > "$WORK_DIR/title.txt"
echo "LEARN TO TYPE WITH TEN FINGERS" > "$WORK_DIR/tagline.txt"
echo "FREE AND OPEN SOURCE" > "$WORK_DIR/free.txt"
echo "PLAY IN YOUR BROWSER ON ITCH.IO" > "$WORK_DIR/web.txt"
echo "dupot-org.itch.io/type-to-fight" > "$WORK_DIR/url.txt"

HEIGHT=1080
text() { # fichier taille couleur y [options] (taille et y en fraction de la hauteur)
	echo "drawtext=fontfile=$FONT:textfile=$WORK_DIR/$1:fontsize=$(calc "int($HEIGHT * $2)"):fontcolor=$3:x=(w-text_w)/2:y=$(calc "int($HEIGHT * $4)"):borderw=$(calc "int($HEIGHT / 135)"):bordercolor=black${5:-}"
}

# Extraits : coupe, légende en fondu, enchaînés par des fondus (image et son)
INPUTS=()
GRAPH=""
VIDEO_CHAIN=""
AUDIO_CHAIN=""
LENGTH=0
i=0
for segment in "${SEGMENTS[@]}"; do
	IFS=: read -r scenario start end caption_y caption <<< "$segment"
	INPUTS+=(-framerate "$FPS" -i "$RECORD_DIR/$scenario/f%08d.png" -i "$RECORD_DIR/$scenario/f.wav")
	duration=$(calc "$end - $start")
	caption_filter=""
	if [ -n "$caption" ]; then
		echo "$caption" > "$WORK_DIR/caption$i.txt"
		caption_filter=",$(text "caption$i.txt" 0.045 0xFFC83C "$caption_y" ":alpha='min(1,max(0,min(t-0.6,$duration-0.6-t)/0.4))'")"
	fi
	GRAPH+="[$((2 * i)):v]trim=start=$start:end=$end,setpts=PTS-STARTPTS,fps=$FPS,settb=1/$FPS,format=yuv420p$caption_filter[v$i];"
	GRAPH+="[$((2 * i + 1)):a]aformat=sample_rates=48000:channel_layouts=stereo,atrim=start=$start:end=$end,asetpts=PTS-STARTPTS[a$i];"
	if [ "$i" -eq 0 ]; then
		VIDEO_CHAIN="[v0]"
		AUDIO_CHAIN="[a0]"
		LENGTH=$duration
	else
		GRAPH+="${VIDEO_CHAIN}[v$i]xfade=transition=fade:duration=$FADE:offset=$(calc "$LENGTH - $FADE")[vx$i];"
		GRAPH+="${AUDIO_CHAIN}[a$i]acrossfade=d=$FADE[ax$i];"
		VIDEO_CHAIN="[vx$i]"
		AUDIO_CHAIN="[ax$i]"
		LENGTH=$(calc "$LENGTH + $duration - $FADE")
	fi
	i=$((i + 1))
	LAST_SCENARIO=$scenario
	LAST_END=$end
done
TOTAL=$(calc "$LENGTH + $END_CARD - 1")

# Écran de fin : dernière image de jeu floutée et assombrie
CARD_FRAME="$(printf "%s/%s/f%08d.png" "$RECORD_DIR" "$LAST_SCENARIO" "$(calc "int($LAST_END * $FPS) - 1")")"
INPUTS+=(-loop 1 -framerate "$FPS" -t "$END_CARD" -i "$CARD_FRAME" -i "$END_MUSIC")
CARD=$((2 * i))
GRAPH+="[$CARD:v]gblur=sigma=14,eq=brightness=-0.3,
	$(text title.txt 0.13 0x33C247 0.14),
	$(text tagline.txt 0.055 white 0.33),
	$(text free.txt 0.055 0xFFC83C 0.48),
	$(text web.txt 0.05 white 0.62),
	$(text url.txt 0.045 0xFFC83C 0.72),
	fps=$FPS,settb=1/$FPS,format=yuv420p[card];
	${VIDEO_CHAIN}fade=in:d=0.5[game];
	[game][card]xfade=transition=fade:duration=1:offset=$(calc "$LENGTH - 1"),
		fade=out:st=$(calc "$TOTAL - 1"):d=1[v];
	[$((CARD + 1)):a]aformat=sample_rates=48000:channel_layouts=stereo,atrim=duration=$END_CARD[music];
	${AUDIO_CHAIN}[music]acrossfade=d=1,afade=out:st=$(calc "$TOTAL - 1.5"):d=1.5[a]"

mkdir -p "$(dirname "$VIDEO")"
ffmpeg -v error -stats -y "${INPUTS[@]}" \
	-filter_complex "$GRAPH" \
	-map "[v]" -map "[a]" -r "$FPS" \
	-c:v libx264 -preset slow -crf 18 -profile:v high -pix_fmt yuv420p \
	-c:a aac -b:a 192k -movflags +faststart \
	"$VIDEO" || {
	if [ -z "${1:-}" ]; then
		# Les enregistrements sont longs : on les garde pour relancer le montage
		KEEP="$(mktemp -d)"
		mv "$RECORD_DIR" "$KEEP/"
		echo "Échec du montage : enregistrement conservé, relancer avec $0 $KEEP/record" >&2
	fi
	exit 1
}

echo "Vidéo : $VIDEO (${TOTAL} s, $(du -h "$VIDEO" | cut -f1))"
