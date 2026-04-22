#!/bin/bash

REPO_URL="$1"
TARGET_DIR="$2"

if [ -z "$REPO_URL" ]; then
    echo "Usage: $0 <repo_url> [target_dir]"
    exit 1
fi

# standaard map naam = repo naam
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR=$(basename "$REPO_URL" .git)
fi

if [ -d "$TARGET_DIR/.git" ]; then
    echo "[INFO] Repo bestaat, pull uitvoeren..."
    cd "$TARGET_DIR" || exit
    git pull --recurse-submodules
    git submodule update --init --recursive
else
    echo "[INFO] Repo clonen..."
    git clone --recurse-submodules "$REPO_URL" "$TARGET_DIR"
fi
