#!/bin/bash
_now=$(date +"%m_%d_%Y")
_folder="/home/peter/ipwebcam/"
_file="webcam_$_now.avi"

ls -1 $folder*jpg > /tmp/files.txt

echo "Starting backup to $_folder$_file..."

mencoder -nosound -ovc lavc -lavcopts vcodec=mpeg4 -o $_folder$_file  -mf type=jpeg:fps=2 mf://@/tmp/files.txt

rm -f $_folder*jpg

exit
