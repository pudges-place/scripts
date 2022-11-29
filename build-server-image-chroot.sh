#!/bin/bash

_check_if_root() {
    if [ $(id -u) -ne 0 ]
    then
      printf "\n\n${RED}PLEASE RUN THIS SCRIPT AS ROOT OR WITH SUDO${NC}\n\n"
      exit
    fi
}   # end of function _check_if_root

_check_internet_connection() {
    printf "\n${CYAN}Checking Internet Connection...${NC}\n\n"
    ping -c 3 endeavouros.com -W 5
    if [ "$?" != "0" ]
    then
       printf "\n\n${RED}No Internet Connection was detected\nFix your Internet Connectin and try again${NC}\n\n"
       exit
    fi
}   # end of function _check_internet_connection

_finish_up() {
    printf "\nalias ll='ls -l --color=auto'\n" >> /etc/bash.bashrc
    printf "alias la='ls -al --color=auto'\n" >> /etc/bash.bashrc
    printf "alias lb='lsblk -o NAME,FSTYPE,FSSIZE,LABEL,MOUNTPOINT'\n\n" >> /etc/bash.bashrc

    sed -i 's|# Server = http://mirror.archlinuxarm.org/$arch/$repo| Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
    sed -i 's| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
    sed -i 's| Server = http://il.us.mirror.archlinuxarm.org/$arch/$repo|# Server = http://il.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist

    rm /var/cache/pacman/pkg/*
    rm /root/build-server-image-chroot.sh
    rm /root/platformname
    rm -rf /etc/pacman.d/gnupg
    rm /home/alarm/smb.conf
    rm /home/alarm/server-addons
    cp /home/alarm/config-server.service /etc/systemd/system/
    systemctl enable config-server.service
    rm /home/alarm/config-server.service
    printf "\n\n${CYAN}Your uSD is ready for creating an image.${NC}\n"
}   # end of function _finish_up


######################   Start of Script   #################################
Main() {

    PLATFORM_NAME=" "

   # Declare color variables
      GREEN='\033[0;32m'
      RED='\033[0;31m'
      CYAN='\033[0;36m'
      NC='\033[0m' # No Color

   # STARTS HERE
   dmesg -n 1 # prevent low level kernel messages from appearing during the script

   # read in platformname passed by install-image-aarch64.sh
   file="/root/platformname"
   read -d $'\x04' PLATFORM_NAME < "$file"
   _check_if_root
   _check_internet_connection
   sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf
   sed -i 's|#Color|Color\nILoveCandy|g' /etc/pacman.conf
   sed -i 's|#VerbosePkgLists|VerbosePkgLists\nDisableDownloadTimeout|g' /etc/pacman.conf
   sed -i 's| Server = http://mirror.archlinuxarm.org/$arch/$repo|# Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://il.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://il.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist

   pacman-key --init
   pacman-key --populate archlinuxarm
   pacman -Syy
#   pacman -S --noconfirm wget

   case $PLATFORM_NAME in
     OdroidN2) pacman -R --noconfirm linux-odroid-n2 uboot-odroid-n2
               pacman -Syu --noconfirm --needed linux-odroid linux-odroid-headers uboot-odroid-n2plus # odroid-n2-post-install
#               cp /home/alarm/n2-boot.ini /boot/boot.ini
               ;;
     RPi64)    pacman -R --noconfirm linux-aarch64 uboot-raspberrypi
               pacman -Syu --noconfirm --needed linux-rpi raspberrypi-bootloader raspberrypi-firmware
               cp /boot/config.txt /boot/config.txt.orig
               cp /home/alarm/rpi4-config.txt /boot/config.txt
               ;;
   esac

   pacman -S --noconfirm --needed - < /home/alarm/server-addons
   mkdir -p /etc/samba
   cp /home/alarm/smb.conf /etc/samba/
   _finish_up
}  # end of Main

Main "$@"
