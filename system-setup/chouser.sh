#!/bin/bash

# change users home folder ,need sudo to work
clear
read -p "new user home folder :" path
echo -e "\n the new path is $path"
echo -e "\n Is this correct? you have 5 seconds to abort with ctrl+c"
sleep 5
read -p "What user is going to have the new path " user
echo "user :$user is going to have the new home folder path $path"
read -rsp $'Press any key to continue...\n' -n1 key
usermod -d $path $user


