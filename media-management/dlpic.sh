#!/bin/bash
#Mike Dahlgren 2009

HOME=/mnt/VG_00/PUBLIC-LIBRARY/PICTURES/WALLPAPERS/WEBDL/
wget -O $HOME/picasa/explore.html http://picasaweb.google.com/lh/explore#
mkdir -p $HOME/picasa/pics

cat ~/picasa/explore.html | grep 'style="width' | awk '{print $2 " " $6}' | sed 's/s144-c/d/' > $HOME/picasa/pics_list.txt

cd $HOME/picasa/pics

exec < ../pics_list.txt
while read line
do
echo $line
wget -nc $line
done

rm $HOME/picasa/explore.html
rm $HOME/picasa/pics_list.txt
