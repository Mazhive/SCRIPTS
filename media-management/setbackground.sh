#!/bin/bash

  function make_js {
       js=$(mktemp)
       cat > $js <<_EOF
      var wallpaper = "$X";
      var activity = activities()[0];
      activity.currentConfigGroup = new Array("Wallpaper", "image");
      activity.writeConfig("wallpaper", wallpaper);
      activity.writeConfig("userswallpaper", wallpaper);
      activity.reloadConfig();
_EOF
}

 function kde_wallpaper {
   make_js
   qdbus org.kde.plasma-desktop /MainApplication loadScriptInInteractiveConsole $js > /dev/null
   # sleep 2
   xdotool search --name "Desktop Shell Scripting Console -- Plasma Desktop Shell" windowactivate key ctrl+e key ctrl+w
   rm -f "$js"
   dbus-send --dest=org.kde.plasma-desktop /MainApplication org.kde.plasma-desktop.reparseConfiguration
   dbus-send --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
   dbus-send --dest=org.kde.kwin /KWin org.kde.KWin.reloadConfig
   # kbuildsycoca4 2>/dev/null && kquitapp plasma-desktop 2>/dev/null ; kstart plasma-desktop > /dev/null 2>&1
 }

 function xfce_wallpaper {
   xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s "$X"
 }

 function lxde_wallpaper {
   pcmanfm -w "$X"
 }

 function mate_wallpaper {
   gsettings set org.mate.background picture-filename "$X"
 }

 function e17_wallpaper {
   OUTPUT_DIR=~/.e/e/backgrounds
   FileName="$X"
   edcFile=~/tmp/SlideShow.edc

   echo 'images { image: "'$FileName'" LOSSY 90; }' > $edcFile
   echo 'collections {' >> $edcFile
   echo 'group { name: "e/desktop/background";' >> $edcFile
   echo 'data { item: "style" "4"; }' >> $edcFile
   echo 'data.item: "noanimation" "1";' >> $edcFile
   echo 'max: 990 742;' >> $edcFile
   echo 'parts {' >> $edcFile
   echo 'part { name: "bg"; mouse_events: 0;' >> $edcFile
   echo 'description { state: "default" 0.0;' >> $edcFile
   echo 'aspect: 1.334231806 1.334231806; aspect_preference: NONE;' >> $edcFile
   echo 'image { normal: "'$FileName'";  scale_hint: STATIC; }' >> $edcFile
   echo '} } } } }' >> $edcFile
   edje_cc -nothreads ~/tmp/SlideShow.edc -o $OUTPUT_DIR/SlideShow.edj
   sleep 2 && rm -f ~/tmp/SlideShow.edc
   echo 'Enlightenment e17 SlideShow.edj file created'
   enlightenment_remote -desktop-bg-del 0 0 -1 -1
   enlightenment_remote -desktop-bg-add 0 0 -1 -1 $OUTPUT_DIR/SlideShow.edj;
 }

 function usage {
   printf "%s\n%s\n\n%s\n%s\n\n%s\n\n%s" \
   "Automatically set a random image as the desktop wallpaper,"\
   "from the user's ~/Wallpaper directory."\
   "Idea from a script by Just17. Written by Paul Arnote for PCLinuxOS."\
   "Originally published in The PCLinuxOS Magazine (http://pclosmag.com), Jan. 2014 issue."\
   "Works for KDE4, Xfce, LXDE, Mate and e17 desktops."\
   "Usage: $0 [arguments]"\

   printf "\n %s\t%s" \
   "-h, --help" "This help text"
   printf "\n %s\t\tSetup for the %s" \
   "--xfce"    "XFCE4 Desktop"\
   "--mate"    "Mate Desktop"\
   "--lxde"    "LXDE Desktop"\
   "--kde4"    "KDE4 Desktop"\
   "--e17"    "Enlightenment Desktop"
   printf "\n"
 }

DIR=/mnt/VG_00/PUBLIC-LIBRARY/PICTURES/WALLPAPERS/

 if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "" ]; then
   usage
   exit
 fi

while true; do
X=`find $DIR -type f \( -name '*.jpg' -o -name '*.png' \) -print0 | shuf -n1 -z`

   # For Xfce
   if [ "$1" == "--xfce" ]; then
     xfce_wallpaper
   fi
   # For LXDE
   if [ "$1" == "--lxde" ]; then
     lxde_wallpaper
   fi
   # For Mate
   if [ "$1" == "--mate" ]; then
     mate_wallpaper
   fi
   # For KDE4
   if [ "$1" == "--kde4" ]; then
     kde_wallpaper
   fi
   # For e17
   if [ "$1" == "--e17" ]; then
     e17_wallpaper
   fi
   #
# If using Cairo-Dock add the following line
#         killall cairo-dock && sleep 0.3 && exec cairo-dock

   sleep 5

done
exit 0
