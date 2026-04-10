#!/bin/bash

# Controleer of de juiste argumenten zijn meegegeven
if [ "$#" -ne 2 ]; then
    echo "Gebruik: $0 <bron_map> <doel_map>"
    exit 1
fi

# Zorg voor absolute paden om fouten te voorkomen
SOURCE_DIR=$(realpath "$1")
TARGET_DIR=$(realpath "$2")

# Check of bronmap bestaat
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Fout: Bronmap '$SOURCE_DIR' bestaat niet."
    exit 1
fi

echo "Start met verwerken van: $SOURCE_DIR"
echo "Bestanden worden opgeslagen in: $TARGET_DIR"
echo "-------------------------------------------"

# Gebruik -print0 om problemen met spaties en vreemde tekens te voorkomen
find "$SOURCE_DIR" -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.ogg" -o -name "*.opus" \) -print0 | while IFS= read -r -d '' FILE; do
    
    # Bepaal het relatieve pad op een veiligere manier
    RELATIVE_PATH="${FILE#$SOURCE_DIR/}"
    
    # Bepaal de doel-bestandsnaam en de doelmap
    DEST_FILE="$TARGET_DIR/$RELATIVE_PATH"
    DEST_DIR=$(dirname "$DEST_FILE")
    
    # Maak de benodigde submappen aan
    mkdir -p "$DEST_DIR"
    
    echo "Repareren: $RELATIVE_PATH"
    
    # Voer ffmpeg uit met dubbele quotes om alle tekens in de bestandsnaam te beschermen
    ffmpeg -loglevel error -i "$FILE" -map_metadata 0 -c copy "$DEST_FILE" -y </dev/null

done

echo "-------------------------------------------"
echo "Klaar! Controleer de map: $TARGET_DIR"
