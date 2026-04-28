#!/bin/bash

# --- CONFIGURATIE ---
CONFIG_FILE="$HOME/.mazhive_git_config"

# --- SMART SETUP ---
if [ ! -f "$CONFIG_FILE" ]; then
    CURRENT_LOC=$(pwd)
    echo "🔍 Eerste keer instellen..."
    echo "Is dit de centrale kluis (waar de .git mappen staan)?"
    echo "📍 $CURRENT_LOC"
    read -p "[y/n]: " IS_ROOT
    
    if [[ "$IS_ROOT" =~ ^[Yy]$ ]]; then
        GIT_DIR="$CURRENT_LOC"
    else
        read -p "Voer het volledige pad naar de GIT-kluis in: " GIT_DIR
    fi

    echo ""
    echo "Voer het pad naar je universele WERKMAP in (waar je de bestanden bewerkt)."
    echo "Voorbeeld: /mnt/SteamLibrary/Photogrammetry_Pipeline"
    read -p "Werkmap Pad: " WORK_DIR

    echo "GIT_DIR=${GIT_DIR%/}" > "$CONFIG_FILE"
    echo "WORK_DIR=${WORK_DIR%/}" >> "$CONFIG_FILE"
    echo "✅ Configuratie opgeslagen in $CONFIG_FILE"
    echo "--------------------------------------------------"
fi

source "$CONFIG_FILE"

# --- PAD LOGICA ---
CURRENT_DIR=$(pwd)
CLEAN_WORK_DIR="${WORK_DIR%/}"
CLEAN_GIT_DIR="${GIT_DIR%/}"

if [[ "$CURRENT_DIR" == "$CLEAN_WORK_DIR"* ]]; then
    RELATIVE_PATH=${CURRENT_DIR#$CLEAN_WORK_DIR}
    RELATIVE_PATH=${RELATIVE_PATH#/}
    PROJECT_NAME=$(echo "$RELATIVE_PATH" | cut -d'/' -f1)
    
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(basename "$CLEAN_WORK_DIR")
        SOURCE_WORK="$CLEAN_WORK_DIR"
    else
        SOURCE_WORK="$CLEAN_WORK_DIR/$PROJECT_NAME"
    fi
    TARGET_GIT="$CLEAN_GIT_DIR/$PROJECT_NAME"
else
    echo "❌ Je bent niet in een bekende werkmap!"
    echo "📍 Huidige map: $CURRENT_DIR"
    echo "🏠 Verwachte werkmap: $CLEAN_WORK_DIR"
    exit 1
fi

echo "=================================================="
echo "🤖 Mazhive Git Manager v2.1"
echo "📂 Project: $PROJECT_NAME"
echo "🛠️  Bron:    $SOURCE_WORK"
echo "📦 Doel:    $TARGET_GIT"
echo "=================================================="

echo "1) UPLOAD (Alles naar GitHub)"
echo "2) DOWNLOAD (Alles van GitHub)"
echo "3) RESET CONFIG (Paden opnieuw instellen)"
read -p "Keuze [1-3]: " CHOICE

case $CHOICE in
    1)
        if [ "$SOURCE_WORK" != "$TARGET_GIT" ]; then
            echo "🔄 Synchroniseren naar kluis..."
            if [ ! -d "$TARGET_GIT" ]; then mkdir -p "$TARGET_GIT"; fi
            rsync -av --delete --exclude='.git/' --exclude='projects/' --exclude='MeshroomCache/' --exclude='bak/' "$SOURCE_WORK/" "$TARGET_GIT/"
        else
            echo "ℹ️  Bron en Doel zijn gelijk. Rsync overgeslagen."
        fi

        cd "$TARGET_GIT" || exit

        # --- VERBETERDE REMOTE CHECK ---
        if [ ! -d ".git" ]; then
            echo "⚠️  Geen .git gevonden. Initialiseren..."
            git init
        fi

        # Controleer of 'origin' bestaat
        if ! git remote | grep -q "origin"; then
            echo "❓ Geen GitHub koppeling (origin) gevonden voor dit project."
            read -p "Voer de GitHub SSH URL in (bijv. git@github.com:Mazhive/$PROJECT_NAME.git): " REPO_URL
            if [ ! -z "$REPO_URL" ]; then
                git remote add origin "$REPO_URL"
                echo "✅ Remote 'origin' toegevoegd."
            else
                echo "❌ Geen URL ingevoerd. Push afgebroken."
                exit 1
            fi
        fi

        # Forceer SSH als het HTTPS is
        REMOTE_URL=$(git remote get-url origin 2>/dev/null)
        if [[ $REMOTE_URL == https://* ]]; then
            echo "🔄 Remote staat op HTTPS. Omzetten naar SSH..."
            SSH_URL=$(echo $REMOTE_URL | sed 's/https:\/\/github.com\//git@github.com:/')
            git remote set-url origin "$SSH_URL"
        fi

        echo "➕ Toevoegen en committen..."
        git add .
        git status -s
        
        # Check of er wijzigingen zijn om te committen
        if git diff-index --quiet HEAD --; then
            echo "☕ Niets om te committen, alles is gelijk."
        else
            read -p "Commit bericht: " MSG
            git commit -m "${MSG:-Auto-update $(date +'%Y-%m-%d %H:%M')}"
        fi
        
        echo "🚀 Pushen naar GitHub..."
        git push origin $(git branch --show-current)
        ;;

    2)
        cd "$TARGET_GIT" || exit
        if git remote | grep -q "origin"; then
            echo "📥 Gegevens ophalen van GitHub..."
            git pull origin $(git branch --show-current) --rebase
            
            if [ "$SOURCE_WORK" != "$TARGET_GIT" ]; then
                echo "🔄 Terugzetten naar werkmap..."
                rsync -av --exclude='.git/' "$TARGET_GIT/" "$SOURCE_WORK/"
            fi
            echo "✨ Klaar!"
        else
            echo "❌ Kan niet downloaden: geen 'origin' geconfigureerd."
        fi
        ;;

    3)
        rm "$CONFIG_FILE"
        echo "✅ Configuratie verwijderd."
        ;;
    *)
        echo "❌ Ongeldige keuze."
        ;;
esac
