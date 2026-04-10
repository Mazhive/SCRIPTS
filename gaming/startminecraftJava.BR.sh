#!/bin/bash
##
##
##
echo #########################################
echo -----Bedrock server-port=25565 ----------
echo -----JAVA	  server-port=19132 ----------
echo #########################################

echo " "
# Minecraft JAVA
cd /mnt/VG_00/PUBLIC-LIBRARY/GAMES/LINUX/MINECRAFT_SERVER/JAVA/
# Minecraft Paper
cd /mnt/VG_00/PUBLIC-LIBRARY/GAMES/LINUX/MINECRAFT_SERVER/JAVA/MCpaper_server/

minimal=1.16
clear
read -p "hoe heet je ? " naam

echo Hallo $naam welke versie gaan we nu spelen
echo voorbeeld is 1.17 or 1.12
echo dus alleen de eerste 3 getallen.
read -p "type je versie nummer: " version



## Mincraft JAVA
# java -jar plugins/Geyser.jar | java -Xmx4096M -Xms1024M -jar minecraft_server.$version.jar nogui
#echo " is deze versie goed $version "
#echo minecraft_server.$version.jar wordt nu gestart
#sleep 5


## Minecraft JAVA Paper.

echo " is dit de goede $version versie "
echo "minimal version = $minimal"
echo "version input = $version"

if [ 1 -eq "$(echo "${version} < ${minimal}" | bc)" ]

then
	echo "it is below 1.16 using java 11"
execute="/usr/lib/jvm/jdk-13/bin/java"
#execute="/usr/lib/jvm/java-16-openjdk-amd64/bin/java"
	else
execute="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
fi
## test

echo "$execute -Xmx4096M -Xms1024M -jar paper-$version.*.jar nogui"

echo "minecraft_server.$version.jar wordt nu gestart"

sleep 5
filename="server.properties"	
if [ -d "/mnt/VG_00/PUBLIC-LIBRARY/GAMES/LINUX/MINECRAFT_SERVER/JAVA/MCpaper_server/world.$version" ] 
then
    echo "Directory exists." 
    echo " version used $version"

sed -i "s/.*level-name=.*/level-name=world.$version/" $filename
## test
#$execute -Xmx4096M -Xms1024M -jar paper-$version.*.jar nogui
echo "java $execute is being used"

echo "$execute -Xmx4096M -Xms1024M -jar paper-$version.*.jar nogui"

else
    echo "Directory does not exists. making the directory! "
sed -i "s/.*level-name=.*/level-name=world.$version/" $filename
mkdir /mnt/VG_00/PUBLIC-LIBRARY/GAMES/LINUX/MINECRAFT_SERVER/JAVA/MCpaper_server/world.$version
mkdir /mnt/VG_00/PUBLIC-LIBRARY/GAMES/LINUX/MINECRAFT_SERVER/JAVA/MCpaper_server/world_nether.$version
mkdir /mnt/VG_00/PUBLIC-LIBRARY/GAMES/LINUX/MINECRAFT_SERVER/JAVA/MCpaper_server/world_the_end.$version
fi



echo "java $execute is being used"
$execute -Xmx4096M -Xms1024M -jar paper-$version.*.jar nogui


#./startminecraft$versie
