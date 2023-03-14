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


_find_mirrorlist() {
    # find and install current endevouros-arm-mirrorlist
    local tmpfile
    local currentmirrorlist
    local ARMARCH="aarch64"

    printf "\n${CYAN}Find current endeavouros-mirrorlist...${NC}\n\n"
    sleep 1
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$ARMARCH | grep "endeavouros-mirrorlist" | sed s'/^.*endeavouros-mirrorlist/endeavouros-mirrorlist/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | grep "any.pkg.tar.zst" | head -1 > mirrors

    tmpfile="mirrors"
    read -d $'\x04' currentmirrorlist < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-mirrorlist...${NC}"
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$ARMARCH/$currentmirrorlist

    printf "\n${CYAN}Installing endeavouros-mirrorlist...${NC}\n"
    pacman -U --noconfirm $currentmirrorlist

    # printf "\n[sar]\nSigLevel = PackageRequired\nServer = http://127.0.0.1:22122\n\n" >> /etc/pacman.conf
    printf "\n[endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n\n" >> /etc/pacman.conf

    rm mirrors
    rm $currentmirrorlist
}  # end of function _find_mirrorlist


_find_keyring() {
    local tmpfile
    local currentkeyring
    local ARMARCH="aarch64"

    printf "\n${CYAN}Find current endeavouros-keyring...${NC}\n\n"
    sleep 1
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$ARMARCH | grep endeavouros-keyring | sed s'/^.*endeavouros-keyring/endeavouros-keyring/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | grep 'endeavouros-keyring-\| -any.pkg.tar.zst' | head -1 > keys

    tmpfile="keys"
    read -d $'\04' currentkeyring < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-keyring...${NC}"
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$ARMARCH/$currentkeyring

    printf "\n${CYAN}Installing endeavouros-keyring...${NC}\n"
    pacman -U --noconfirm $currentkeyring

    rm keys
    rm $currentkeyring
}   # End of function _find_keyring


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
   pacman-key --init
   pacman-key --populate archlinuxarm
   pacman -Syy
   pacman -S --noconfirm wget
#   _find_mirrorlist
#   _find_keyring
   sed -i 's| Server = http://mirror.archlinuxarm.org/$arch/$repo|# Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://il.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://il.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   pacman -Syy


   case $PLATFORM_NAME in
     OdroidN2) pacman -R --noconfirm linux-odroid-n2 uboot-odroid-n2
               pacman -Syu --noconfirm --needed linux-odroid linux-odroid-headers uboot-odroid-n2plus  odroid-n2-post-install
               # cp /home/alarm/n2-boot.ini /boot/boot.ini
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
