#!/bin/bash
# prevent screen from disabling display
# gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

xset -s off
xset -dpms
echo installing pv
sleep 1
apt install -y pv

echo "Checking if user $USER is priviliged to run script".| pv -qL 10
sleep 5

(( EUID )) && { echo 'Run this script with root priviliges.'; exit 1; } || echo 'Running as root, starting service...'

echo update distro and upgrade
apt update && apt upgrade

## install fonts - xterm
echo installing xfonts-cyrillic nfs-common | pv -qL 10
sleep 1
echo libutempter0 | pv -qL 10
sleep 1
echo xterm | pv -qL 10
sleep 1
apt install -y xfonts-cyrillic libutempter0 xterm geany nfs-common gnome-system-tools

## install openscad
echo Installing openscad | pv -qL 10
apt install -y openscad
## install webdav for webdav connections
echo installing and making webdav connections | pv -qL 10
sleep 1
apt-get install -y davfs2


# make first folder tree 
echo "make first folder tree" | pv -qL 10
sleep 1
mkdir /mnt/VG_00

# make second tree
echo "make second folder tree" | pv -qL 10
sleep 1
mkdir /mnt/VG_00/HOME
mkdir /mnt/VG_00/PUBLIC-LIBRARY
mkdir /mnt/VG_00/PRIVATE-LIBRARY/
# make second third tree
echo " make third folder tree" | pv -qL 10
sleep 1
mkdir /mnt/VG_00/HOME/noa
mkdir /mnt/VG_00/HOME/peter
mkdir /mnt/VG_00/HOME/desiree
mkdir /mnt/VG_00/HOME/djuga
mkdir /mnt/VG_00/PRIVATE-LIBRARY/Prive.Docs
# make second fourth tree



# add user and change home path for user
# id noa     1002
# id peter   1000
# id djuga   1011
# id desiree 1003
echo "Add users with appropriate id and set ownership" | pv -qL 10
echo "make noa" | pv -qL 10
/usr/sbin/useradd noa     -u 1002 -d /mnt/VG_00/HOME/noa
echo "make peter" | pv -qL 10
sleep 1
/usr/sbin/useradd peter   -u 1000 -d /mnt/VG_00/HOME/peter
/usr/sbin/usermod peter -d /mnt/VG_00/HOME/peter
echo "make desiree" | pv -qL 10
sleep 1
/usr/sbin/useradd desiree -u 1003 -d /mnt/VG_00/HOME/desiree
echo "make djuga" | pv -qL 10
sleep 1
/usr/sbin/useradd djuga   -u 1011 -d /mnt/VG_00/HOME/djuga

# change ownership

chown noa:noa         -R /mnt/VG_00/HOME/noa
chown peter:peter     -R /mnt/VG_00/HOME/peter
chown desiree:desiree -R /mnt/VG_00/HOME/desiree
chown djuga:djuga     -R /mnt/VG_00/HOME/djuga

# nfs entries in fstab
echo "make /etc/fstab entries" | pv -qL 10
echo " " >> /etc/fstab
echo "############################### NFS entries ##############################################" >> /etc/fstab
echo "192.168.4.17:/mnt/VG_00/HOME/noa       				/mnt/VG_00/HOME/noa             	  nfs defaults       0 0" >> /etc/fstab
echo "192.168.4.17:/mnt/VG_00/HOME/desiree   				/mnt/VG_00/HOME/desiree         	  nfs defaults       0 0" >> /etc/fstab
echo "192.168.4.17:/mnt/VG_00/PUBLIC-LIBRARY 				/mnt/VG_00/PUBLIC-LIBRARY             nfs defaults       0 0" >> /etc/fstab
echo "192.168.4.17:/mnt/VG_00/HOME/peter     				/mnt/VG_00/HOME/peter          		  nfs defaults       0 0" >> /etc/fstab
echo "192.168.4.17:/mnt/VG_00/PRIVATE-LIBRARY/Prive.Docs/ /mnt/VG_00/PRIVATE-LIBRARY/Prive.Docs   nfs defaults		 0 0" >> /etc/fstab
echo "192.168.4.17:/mnt/VG_00/HOME/djuga     				/mnt/VG_00/HOME/djuga          		  nfs defaults       0 0" >> /etc/fstab
echo "################################## WEBDAV ###############################################" >> /etc/fstab


apt update
sleep 2

## mounting only possible if server side nfs export file is being changed
#mount -a
echo "Mounting home folders is only possible when at the serverside the client is added" | pv -qL 10

# install sudo 
echo "Install sudo and add peter to sudoer" | pv -qL 10

apt install -y sudo

## add user to sudo list
usermod -aG sudo peter

# set time zone 
echo "set timezone to america curacao" | pv -qL 10
sleep 2
timedatectl set-timezone America/Curacao

## wine install
echo " set wine arch and install dependencies" | pv -qL 10
sleep 1
dpkg --add-architecture i386

apt update
apt -y install gnupg2 software-properties-common
wget -qO - https://dl.winehq.org/wine-builds/winehq.key | apt-key add -

apt-add-repository https://dl.winehq.org/wine-builds/debian/
apt update

wget -O- -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_11/Release.key | sudo apt-key add -    
echo "deb http://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_11 ./" | sudo tee /etc/apt/sources.list.d/wine-obs.list

apt update
echo "Install WineHQ & Staging" | pv -qL 10
apt install -y --install-recommends winehq-stable
sleep 1
apt install -y winehq-staging
sleep 1

## end wine install
## minecraft windows . Wine needs mono
## https://dl.winehq.org/wine/wine-mono/6.2.0/

###############################
# need to make choice
###############################

##    Minecraft Windows Version   ##

echo "Download Minecraft Windows msi version" | pv -qL 10
apt install -y libcurl4 libjsoncpp* libminizip* libre2-*
wget https://launcher.mojang.com/download/MinecraftInstaller.msi
echo "Download Minecraft Windows  exe version" | pv -qL 10
sleep 1
wget https://launcher.mojang.com/download/Minecraft.exe
echo "Download JDK-16.0.1-Windows-x64" | pv -qL 10
sleep 1
wget https://download.oracle.com/otn-pub/java/jdk/16.0.1+9/7147401fd7354114ac51ef3e1328291f/jdk-16.0.1_windows-x64_bin.exe
echo "Download Minecraft native versions" | pv -qL 10
sleep 1
wget https://launcher.mojang.com/download/Minecraft.deb

read -p "Do you want to install Minecraft Windows version? (yes/no)" reply

choice=$(echo $reply|sed 's/(.*)/L1/')

if [ "$choice" = 'yes' ] 
then
  echo "You selected yes, wait for 3 seconds to get respond";
  sleep 3;
  wine jdk-16.0.1_windows-x64_bin.exe && wine MinecraftInstaller.msi WIXUI_DONTVALIDATEPATH="1" && echo "jdk and Minecraft installed";

elif [ "$choice" = 'no'  ]
then

  echo "You selected 'no', hence exiting in 3 seconds";
  sleep 3
  echo "no is selected"
else
echo "invalid answer, type yes or no";
fi
echo " "

##    Minecraft native version    ##

read -p "Do you want to install Minecraft native version? (yes/no)" reply

choice=$(echo $reply|sed 's/(.*)/L1/')

if [ "$choice" = 'yes' ] 
then
  echo "You selected yes, wait for 3 seconds to get respond";
  sleep 3;
  dpkg -i Minecraft.deb && echo "Minecraft native version installed";

elif [ "$choice" = 'no'  ]
then

  echo "You selected 'no', hence exiting in 3 seconds";
  sleep 3
  echo "no is selected"
else
echo "invalid answer, type yes or no";
fi
echo " "



##################################
# install chromium and firefox-esr
##################################



read -p "Do you want to install chromium ? (yes/no)" reply

choice=$(echo $reply|sed 's/(.*)/L1/')

if [ "$choice" = 'yes' ] 
then
  echo "You selected yes, wait for 3 seconds to get respond";
  sleep 3;
  apt install -y chromium && echo " " && echo "Chromium installed ";

elif [ "$choice" = 'no'  ]
then

  echo "You selected 'no', hence exiting in 3 seconds";
  sleep 3
  echo "no is selected"
else
echo "invalid answer, type yes or no";
fi

#apt install -y firefox

read -p "Do you want to install Firefox ? (yes/no)" reply

choice=$(echo $reply|sed 's/(.*)/L1/')

if [ "$choice" = 'yes' ] 
then
  echo "You selected yes, wait for 3 seconds to get respond";
  sleep 3;
  apt install -y firefox-esr && echo "Firefox-esr installed";

elif [ "$choice" = 'no'  ]
then

  echo "You selected 'no', hence exiting in 3 seconds";
  sleep 3
  echo "no is selected"
else
echo "invalid answer, type yes or no";
fi
echo " "
sleep 2

## opengl
echo " installing lshw,opengl,mesa,vulkan,game mode,git,cpufrequtils" | pv -qL 10
sleep 1
apt-get install -y libgl1-mesa-dev

## install -y vulkan 
apt install -y libvulkan1 mesa-vulkan-drivers vulkan-utils libvulkan-dev

## Install lshw ,gamemode ,git ,cpufrequtils ,ufw
apt install -y lshw gamemode git cpufrequtils ufw

systemctl enable ufw
systemctl start ufw

# set maximum performance
echo "Set maximum performance" | pv -qL 10
sed -i 's/^GOVERNOR=.*/GOVERNOR="performance"/' /etc/init.d/cpufrequtils

#  enable ufw on boot and set variables
systemctl enable ufw

ufw allow 20/tcp
ufw allow 21/tcp
ufw allow 990/tcp
ufw allow 40000:50000/tcp
ufw allow ssh
ufw allow 22

### install cups
echo "Installing cups" | pv -qL 10
sleep 1
apt install -y cups
sleep 1

### install inkscape and thunar keepassx
echo "Installing inkscape and thunar keepassx" | pv -qL 10
sleep 1
apt install -y inkscape thunar keepassx
sleep 1

#####################################################################
## enable opengl on none supported hardware by using software render
## LIBGL_ALWAYS_SOFTWARE=1 *command*
#####################################################################

#################
###  Add printer
#################

echo adding network printer now
sleep 2
echo " "
/usr/sbin/lpadmin -p Samsung_M262x_282x_Series -L "kantoor" -m gutenprint.5.3://samsung-ml-85 -o PageSize=A4 -o printer-is-shared=false -u allow:all -E -v dnssd://Samsung%20M262x%20282x%20Series%20kantoor._printer._tcp.local/
echo " "
echo " "

#########################################################
 
read -p "Do you want to install Compiz ? (yes/no)" reply

choice=$(echo $reply|sed 's/(.*)/L1/')

if [ "$choice" = 'yes' ] 
then
  echo "You selected yes, wait for 3 seconds to get respond";
  sleep 3;
  apt install -y compiz && echo "Compiz installed ";

elif [ "$choice" = 'no'  ]
then

  echo "You selected 'no', hence exiting in 3 seconds";
  sleep 3
  echo "no is selected"
else
echo "invalid answer, type yes or no";
fi
echo " "
sleep 2
##  add repos
echo "deb http://http.us.debian.org/debian bullseye main contrib non-free" >> /etc/apt/sources.list
echo "deb http://security.debian.org bullseye/updates main contrib non-free" >> /etc/apt/sources.list
echo "deb [trusted=yes] http://deb.opera.com/opera-stable/ stable non-free" >> /etc/apt/sources.list
apt update 
echo " Installing Opera-stable & Steam " |pv -qL 10
apt install -y opera-stable build-essential gtk2-engines-murrine:i386 libatk-adaptor:i386 libgail-common:i386 gtk2-engines libatk-adaptor libgail-common linux-headers-$(uname -r) steam

##### mangohud steam options
## LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libgamemodeauto.so.0 mangohud  %command%
##### 
echo "Installing mangohud" |pv -qL 10
apt install -y gcc-multilib g++-multilib python3-pip python3-setuptools python3-wheel libxnvctrl-dev libdbus-1-dev

git clone --recurse-submodules https://github.com/flightlessmango/MangoHud.git && cd MangoHud && ./build.sh build


## set background script ##
echo Copying setbackground script| pv -qL 10
sleep 1
wget https://github.com/Mazhive/SCRIPTS/blob/main/setbackground.sh
cp setbackground.sh /usr/bin/setbackground
chmod +x /usr/bin/setbackground
echo " make symlink to 3d print profiles" | pv -qL 10

### ln -s /mnt/VG_00/HOME/peter/.config/PrusaSlicer /mnt/VG_00/HOME/desiree/.config/PrusaSlicer
###            dest                                             link
###

ln -s /mnt/VG_00/PUBLIC-LIBRARY/3D.STL/PrusaProfiles/PrusaSlicer /mnt/VG_00/HOME/desiree/.config/PrusaSlicer
ln -s /mnt/VG_00/PUBLIC-LIBRARY/3D.STL/PrusaProfiles/PrusaSlicer /mnt/VG_00/HOME/peter/.config/PrusaSlicer
ln -s /mnt/VG_00/PUBLIC-LIBRARY/3D.STL/PrusaProfiles/PrusaSlicer /mnt/VG_00/HOME/djuga/.config/PrusaSlicer
ln -s /mnt/VG_00/PUBLIC-LIBRARY/3D.STL/PrusaProfiles/PrusaSlicer /mnt/VG_00/HOME/noa/.config/PrusaSlicer
echo " done " | pv -qL 10

## add lutris
echo 'deb http://download.opensuse.org/repositories/home:/strycore/Debian_10/ /' | sudo tee /etc/apt/sources.list.d/home:strycore.list
curl -fsSL https://download.opensuse.org/repositories/home:strycore/Debian_10/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_strycore.gpg > /dev/null
sudo apt update
sudo apt install -y lutris menulibre flatpak

sudo apt-get install -y libsdl2-2.0 libjpeg-dev libpng-dev libvulkan1 vulkan-utils

## proprietary drivers ppa
## insert key
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FCAE110B1118213C
add-apt-repository ppa:graphics-drivers/ppa

## Install PTS and benchmark your gear:
##  SQLite3 and SDL need to be installed 
## dependencies 
apt install -y libpcre2-dev libsdl1.2-dev libsdl-gfx1.2-dev libsdl-net1.2-dev libsdl-image1.2-dev libsdl-ttf2.0-dev libsdl-mixer1.2-dev libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
##  
#    sudo apt-get install phoronix-test-suite
#
## Run the benchmark:
#
#    phoronix-test-suite default-benchmark openarena xonotic tesseract gputest unigine-valley
#
#########
#install blender - obs-studio
apt install -y blender obs-studio
## Set xsetwacom buttons
apt install -y xserver-xorg-input-wacom
## apt install -y xsetwacom

xsetwacom --set "Wacom Intuos BT M Pad pad" Button 1 "key shift"
xsetwacom --set "Wacom Intuos BT M Pad pad" Button 2 "key ctrl"
##### buttons set

## debian nvidia fbc
apt install -y libnvidia-fbc1

### lightdm greeter settings   change your background loginscreen and positioning
apt install -y lightdm-gtk-greeter lightdm-gtk-greeter-settings
### CPU info 
apt install -y python3-cpuinfo python-cpuinfo py-cpuinfo

## add flatpak repo
apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

## add flatpak dolphin-emu
flatpak install dolphin-emu


### nvidia patch fbc , only working with proprietary drivers
# git clone https://github.com/keylase/nvidia-patch.git
# cd nvidia-patch
# ./patch-fbc.sh

#### frame buffer capture for obs-studio 
# git clone https://gitlab.com/fzwoch/obs-nvfbc.git
# cd obs-nvfbc-master
# apt install libgl-dev libobs-dev libsimde-dev meson ninja-build
# meson build
# ninja -C build
# cd build
## cp nvfbc.so for each user in ~/.config/obs-studio/plugins/nvfbc/nvfbc.so

## if a upgrade fails 
## apt-get --fix-broken upgrade




