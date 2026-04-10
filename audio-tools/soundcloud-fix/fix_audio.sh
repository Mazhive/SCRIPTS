#!/bin/bash

# --- Kleuren voor de output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function show_help() {
    echo -e "${BLUE}Audio Seek Fixer${NC}"
    echo "Repareert corrupte audio tijdlijnen (seeking) door de container te herbouwen."
    echo ""
    echo -e "Gebruik: $0 ${GREEN}<bron_map>${NC} ${GREEN}<doel_map>${NC}"
    echo "Voorbeeld: $0 ./downloads ./muziek_gefixt"
}

# Controleer argumenten
if [ "$#" -ne 2 ]; then
    show_help
    exit 1
fi

# Controleer of ffmpeg aanwezig is
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Fout: ffmpeg is niet geïnstalleerd.${NC}"
    echo "Installeer het met: sudo apt install ffmpeg"
    exit 1
fi

SOURCE_DIR=$(realpath "$1")
TARGET_DIR=$(realpath "$2")

# Check of bronmap bestaat
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Fout: Bronmap '$SOURCE_DIR' bestaat niet.${NC}"
    exit 1
fi

echo -e "${BLUE}--- Start Reparatie Process ---${NC}"
echo "Bron: $SOURCE_DIR"
echo "Doel: $TARGET_DIR"

# Zoek bestanden en verwerk ze
# -print0 zorgt voor veilige verwerking van spaties en speciale tekens
find "$SOURCE_DIR" -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.ogg" -o -name "*.opus" \) -print0 | while IFS= read -r -d '' FILE; do
    
    RELATIVE_PATH="${FILE#$SOURCE_DIR/}"
    DEST_FILE="$TARGET_DIR/$RELATIVE_PATH"
    DEST_DIR=$(dirname "$DEST_FILE")
    
    mkdir -p "$DEST_DIR"
    
    echo -e "${GREEN}Verwerken:${NC} $RELATIVE_PATH"
    
    # Herbouw de container zonder her-coderen (stream copy)
    ffmpeg -loglevel error -i "$FILE" -map_metadata 0 -c copy "$DEST_FILE" -y </dev/null

done

echo -e "${BLUE}--- Klaar! ---${NC}"
