#!/bin/bash


# rename files to modified date
exiftool '-filename<CreateDate' -d %m.%d.%Y%%-.4nc.%%le -r *

# move files to modified date
exiftool -d %m.%d.%Y "-directory<datetimeoriginal" *.jpg
exiftool -d %m.%d.%Y "-directory<datetimeoriginal" *.jpeg
exiftool -d recordings.%m.%d.%Y "-directory<createdate" *.mov
exiftool -d recordings.%m.%d.%Y "-directory<createdate" *.mp4
exiftool -d recordings.%m.%d.%Y "-directory<createdate" *.3gp

# create list files according to modified date

#ls -lrt > filelist.txt

# stat %w * |grep -E "File|Modify" > filelist.txt
