#!/bin/bash

_check_if_root() {
    local whiptail_installed

    if [ $(id -u) -ne 0 ]
    then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "Please run this script as root" 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. Please run this script with as root.${NC}\n"
          exit
       fi
    fi
}

_unmount_partitions() {
    local count
    local i
    local u
    local x

    lsblk $DEVICENAME -o MOUNTPOINT | grep /run/media >> mounts
    count=$(wc -l mounts | awk '{print $1}')
    if [ $count -gt 0 ]
    then
       for ((i = 1 ; i <= $count ; i++))
       do
          u=$(awk -v "x=$i" 'NR==x' mounts)
          umount $u
       done
    fi
    rm mounts
}

##################### Start of Scipt #################

_check_if_root
mkdir MP1
mkdir MP1/boot

lsblk -f
printf "\nEnter device name of the image donor in a /dev/sda format\n"
read DEVICENAME

if [[ ${DEVICENAME:5:6} = "mmcblk" ]]
then
   DEVICENAME=$DEVICENAME"p"
fi
   
PARTNAME1=$DEVICENAME"1"
PARTNAME2=$DEVICENAME"2"
_unmount_partitions
printf "\nSource Partitions unmounted\n"

mount $PARTNAME2 MP1
mount $PARTNAME1 MP1/boot
cd MP1
printf "\nbsdtar is creating the image, may take a few minutes\n"
bsdtar -czf /home/don/create-image/enosLinuxARM-rpi-aarch64-latest.tar.gz *
printf "\nbsdtar is finished creating the image.\nand will calculate a sha512sum\n\n"
cd ..
sha512sum enosLinuxARM-rpi-aarch64-latest.tar.gz > enosLinuxARM-rpi-aarch64-latest.tar.gz.sha512sum
umount MP1/boot MP1
rm -rf MP1



