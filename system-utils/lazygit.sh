#!/bin/bash

# Gebruik:

#    ./lazy-git.sh (gebruikt standaard "Update scripts")

#    ./lazy-git.sh "Nieuwe soundcloud fix toegevoegd" (gebruikt jouw tekst)


# Controleer of er een bericht is meegegeven, anders gebruik standaard
MESSAGE="${1:-Update scripts}"

echo "Bezig met toevoegen..."
git add .

echo "Vastleggen met bericht: $MESSAGE"
git commit -m "$MESSAGE"

echo "Uploaden naar GitHub..."
git push

echo "Klaar!"
