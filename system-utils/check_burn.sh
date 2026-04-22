#!/bin/bash

# --- CONFIGURATIE ---
DEVICE="/dev/sr0"

# --- STAP 0: DISC CHECK ---
echo "--- STAP 0: DISC CHECK ---"

# 1. Haal de ruwe info op van de ASUS-drive
RAW_INFO=$(dvd+rw-mediainfo $DEVICE 2>/dev/null)

# 2. Extraheer het getal en haal de *2KB suffix weg
BLOCKS=$(echo "$RAW_INFO" | grep -i "Free Blocks" | awk '{print $NF}' | sed 's/\*.*//')

# 3. Bepaal de capaciteit (1 blok = 2048 bytes)
if [ -z "$BLOCKS" ] || ! [[ "$BLOCKS" =~ ^[0-9]+$ ]]; then
    MAX_CAPACITY=$(lsblk -bno SIZE $DEVICE 2>/dev/null | head -n1)
else
    MAX_CAPACITY=$((BLOCKS * 2048))
fi

if [ -z "$MAX_CAPACITY" ] || [ "$MAX_CAPACITY" -eq 0 ]; then
    echo "❌ FOUT: Geen disc gevonden in $DEVICE of de disc is niet leeg."
    exit 1
fi

MAX_GIB=$(echo "scale=2; $MAX_CAPACITY / 1024 / 1024 / 1024" | bc)
echo "✅ Disc herkend! Capaciteit: $MAX_GIB GiB ($MAX_CAPACITY bytes)"
echo ""

# --- STAP 1: HOOFDMAP SELECTEREN ---
echo "--- STAP 1: HOOFDMAP SELECTEREN ---"
read -e -p "Wat is het pad naar de hoofdmap? " INPUT_DIR

# Pad opschonen
MAIN_DIR=$(echo "$INPUT_DIR" | sed 's/\/\//\//g' | sed 's/\/$//')

if [ ! -d "$MAIN_DIR" ]; then
    echo "❌ FOUT: Map $MAIN_DIR niet gevonden!"
    exit 1
fi

cd "$MAIN_DIR" || exit 1

echo ""
echo "--- STAP 2: KIES DE SUBMAPPEN ---"
mapfile -t SUBFOLDERS < <(find . -maxdepth 1 -type d ! -path . | sed 's|^\./||' | sort)

if [ ${#SUBFOLDERS[@]} -eq 0 ]; then
    echo "Geen submappen gevonden."
    exit 1
fi

for i in "${!SUBFOLDERS[@]}"; do
    printf "[%2d] %s\n" "$i" "${SUBFOLDERS[$i]}"
done

echo ""
read -p "Welke mappen wil je branden? " CHOICES

# --- STAP 3: GRAFT-POINTS OPBOUWEN ---
SELECTED_GRAFTS=()
for choice in $CHOICES; do
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "${#SUBFOLDERS[@]}" ]; then
        FOLDER_NAME="${SUBFOLDERS[$choice]}"
        FULL_PATH="$MAIN_DIR/$FOLDER_NAME"
        CLEAN_PATH=$(echo "$FULL_PATH" | sed 's/\/\//\//g')
        SELECTED_GRAFTS+=("$FOLDER_NAME=$CLEAN_PATH")
    fi
done

if [ ${#SELECTED_GRAFTS[@]} -eq 0 ]; then
    echo "❌ FOUT: Geen mappen geselecteerd."
    exit 1
fi

# --- STAP 4: BEREKENEN EXACTE ISO-GROOTTE ---
echo ""
echo "--- STAP 4: BEREKENEN EXACTE ISO-GROOTTE ---"
echo "Bezig met simuleren van Rock Ridge + UDF + Symlink data..."

# CRUCIAAL: De '-f' vlag volgt de symlinks om de echte bestandsgrootte te meten
SECTORS=$(genisoimage -print-size -quiet -graft-points -f -rational-rock -udf -iso-level 3 "${SELECTED_GRAFTS[@]}")

if [ $? -ne 0 ] || [ -z "$SECTORS" ] || [ "$SECTORS" -eq 0 ]; then
    echo "❌ FOUT: genisoimage kon de grootte niet berekenen."
    exit 1
fi

PROJECT_SIZE=$((SECTORS * 2048))
MB_FREE=$(( (MAX_CAPACITY - PROJECT_SIZE) / 1024 / 1024 ))

echo "------------------------------------------------"
echo "Capaciteit op disc: $((MAX_CAPACITY / 1024 / 1024)) MB"
echo "Project grootte:    $((PROJECT_SIZE / 1024 / 1024)) MB"
echo "------------------------------------------------"

if [ "$PROJECT_SIZE" -lt "$MAX_CAPACITY" ]; then
    echo "✅ SUCCES: Dit past!"
    echo "Vrije ruimte over: $MB_FREE MB"
    
    # We houden 400MB marge aan voor de Lead-out en filesystem overhead
    if [ "$MB_FREE" -lt 400 ]; then
        echo "⚠️  PAS OP: Erg krap! Verwijder een map om een 'Cancelled' burn te voorkomen."
    else
        echo "Deze selectie is veilig om te branden."
    fi
else
    OVER=$(( (PROJECT_SIZE - MAX_CAPACITY) / 1024 / 1024 ))
    echo "❌ FOUT: Past NIET! Je komt $OVER MB tekort."
    echo "Door symlinks is het project groter dan de ruwe mapgrootte."
fi
