#!/bin/bash
# Exporte le jeu (pck) puis prépare export/Linux/bundle.tar.gz pour le manifeste
# Flathub (org.dupot.typetofight) : pck, icônes, appdata et .desktop.
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/bin/godot")}"
PRESET="Linux"
PCK_NAME="dupotTypeToFight.pck"

# Godot ne doit pas importer (ni réembarquer) les fichiers exportés
touch export/.gdignore

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-pack "$PRESET" "export/Linux/$PCK_NAME"

rm -rf export/Linux/bundle
rm -f export/Linux/bundle.tar.gz
mkdir -p export/Linux/bundle/icons
cp "export/Linux/$PCK_NAME" export/Linux/bundle/
cp export/Linux/flatpak/icons/*.png export/Linux/bundle/icons/
cp export/Linux/flatpak/org.dupot.typetofight.appdata.xml export/Linux/bundle/
cp export/Linux/flatpak/org.dupot.typetofight.desktop export/Linux/bundle/
tar -cvzf export/Linux/bundle.tar.gz -C export/Linux/bundle .

echo "Bundle : export/Linux/bundle.tar.gz"
