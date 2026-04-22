#!/bin/bash

COMMIT_MSG="$1"

if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="auto commit $(date)"
fi

# check of dit een git repo is
if [ ! -d ".git" ]; then
    echo "[ERROR] Geen git repo hier"
    exit 1
fi

echo "[INFO] Submodules updaten..."
git submodule update --init --recursive

echo "[INFO] Alles toevoegen..."
git add .

echo "[INFO] Committen..."
git commit -m "$COMMIT_MSG"

echo "[INFO] Pushen..."
git push

# submodules ook pushen
echo "[INFO] Submodules pushen..."
git submodule foreach 'git add . && git commit -m "'"$COMMIT_MSG"'" || true && git push || true'
