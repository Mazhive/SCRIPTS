#!/bin/sh

## move single files user input

echo move single file with progress indicator
read -p "Please enter Path/Sourcefile :" 			sourcefile
echo "localpath is : " $sourcefile
    

echo " pleas enter destination path/dest.file :"
read -p "Destination Path/ file : " 			destfile

echo $sourcefile > $destfile

pv $sourcefile > $destfile

read -r -p "remove source file?" response
#read -r -p "is it a local path ? otherwise webadress [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 

echo " You answered yes"

echo "$sourcefile  file is going to be deleted"
rm $sourcefile
;;
esac  

















