#!/bin/bash
# Exporte le jeu en HTML5 (preset « Web ») puis met à jour le zip à publier
# (ex. itch.io : index.html à la racine du zip).
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/bin/godot")}"
PRESET="Web"
EXPORT_DIR="export/HTML5"
ZIP_NAME="dupotTypeToFight-html5.zip"

# Godot ne doit pas importer (ni réembarquer) les fichiers exportés
mkdir -p export
touch export/.gdignore

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

# Import des ressources puis export avec la version de Godot du projet
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "$PRESET" "$EXPORT_DIR/index.html"

# le zip est rangé avec l'export, sans s'inclure lui-même
(cd "$EXPORT_DIR" && rm -f "$ZIP_NAME" && zip -r -q "$ZIP_NAME" . -x "*.import" "$ZIP_NAME")

echo "Export : $EXPORT_DIR"
echo "Zip    : $EXPORT_DIR/$ZIP_NAME ($(du -h "$EXPORT_DIR/$ZIP_NAME" | cut -f1))"
