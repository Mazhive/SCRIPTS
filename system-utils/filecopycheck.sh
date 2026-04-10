#!/bin/bash
WATCH_DIR=/directory/to/monitor
DEST_DIR=/x/y/z

/usr/bin/inotifywait --recursive --monitor --quiet -e moved_to -e close_write --format '%w%f' "$WATCH_DIR" | while read -r INPUT_FILE; do

mv "$0" "$DEST_DIR"

done

