#!/bin/bash

# Paden bepalen
BASE_DIR=$(pwd)
UNSORTED="$BASE_DIR/ongesorteerd"

# Controleer of de map bestaat
if [ ! -d "$UNSORTED" ]; then
    echo "Fout: Map 'ongesorteerd' niet gevonden."
    exit 1
fi

# Functie voor veilig verplaatsen
move_item() {
    local item=$1
    local target=$2
    if [ -e "$UNSORTED/$item" ]; then
        mkdir -p "$BASE_DIR/$target"
        echo "Verplaatsen: $item -> $target/"
        mv "$UNSORTED/$item" "$BASE_DIR/$target/"
    fi
}

echo "Starten met sorteren van Mazhive/SCRIPTS..."

# --- 1. Virtualization ---
move_item "winerunner" "virtualization"

# --- 2. Gaming ---
move_item "steam" "gaming"

# --- 3. Media Management ---
move_item "shader" "media-management"
move_item "convert2mpeg.py" "media-management"

# --- 4. System Utils ---
move_item "automountiso" "system-utils"
move_item "check_burn.sh" "system-utils"
move_item "lazygit.sh" "system-utils"
move_item "lazygit.upload.sh" "system-utils"

# --- 5. Opschonen ---
# Controleer of de map nu leeg is
if [ -z "$(ls -A "$UNSORTED")" ]; then
    echo "Succes: De map 'ongesorteerd' is nu leeg."
else
    echo "Waarschuwing: Er staan nog onbekende bestanden in 'ongesorteerd':"
    ls -A "$UNSORTED"
fi

echo "Klaar!"
