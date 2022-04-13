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

    printf "\n${CYAN}Find current endeavouros-mirrorlist...${NC}\n\n"
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/aarch64 | grep "endeavouros-mirrorlist" |sed s'/^.*endeavouros-mirrorlist/endeavouros-mirrorlist/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g |tail -1 > mirrors
    tmpfile="mirrors"
    read -d $'\x04' currentmirrorlist < "$tmpfile"
    printf "\n${CYAN}Downloading endeavouros-mirrorlist...${NC}"
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/aarch64/$currentmirrorlist 2>> /root/enosARM.log
    
    printf "\n${CYAN}Installing endeavouros-mirrorlist...${NC}\n"
    pacman -U --noconfirm $currentmirrorlist &>> /root/enosARM.log

    printf "\n[endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n\n" >> /etc/pacman.conf
    rm mirrors
}  # end of function _find_mirrorlist


_find_keyring() {
    local tmpfile
    local currentkeyring

    printf "\n${CYAN}Find current endeavouros-keyring...${NC}\n\n"
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/aarch64 |grep endeavouros-keyring |sed s'/^.*endeavouros-keyring/endeavouros-keyring/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | tail -1 > keys
    tmpfile="keys"
    read -d $'\04' currentkeyring < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-keyring...${NC}"
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/aarch64/$currentkeyring 2>> /root/enosARM.log

    printf "\n${CYAN}Installing endeavouros-keyring...${NC}\n"
    pacman -U --noconfirm $currentkeyring &>> /root/enosARM.log
    rm keys
}   # End of function _find_keyring

_finish_up() {
    systemctl disable dhcpcd.service
    systemctl enable NetworkManager.service
    pacman -Rn --noconfirm dhcpcd
    rm /var/cache/pacman/pkg/*
    rm switch-kernel.sh enosARM.log # endeavouros-*    
    rm -rf /etc/pacman.d/gnupg
    printf "\n\n${CYAN}Your uSD is ready for creating an image.\n\nPress Return to poweroff.${NC}\n"
    read -n 1 z
    systemctl poweroff
}   # end of function _finish_up

######################   Start of Script   #################################
Main() {

   # Declare color variables
      GREEN='\033[0;32m'
      RED='\033[0;31m'
      CYAN='\033[0;36m'
      NC='\033[0m' # No Color

   # STARTS HERE
   dmesg -n 1 # prevent low level kernel messages from appearing during the script
   _check_if_root
   _check_internet_connection
   pacman-key --init
   pacman-key --populate archlinuxarm
   pacman -Syy
   pacman -R --noconfirm linux-aarch64 uboot-raspberrypi
   pacman -Syu --noconfirm --needed linux-rpi raspberrypi-bootloader raspberrypi-firmware git libnewt wget networkmanager autoconf automake bison flex groff m4 pkgconf
   _finish_up
}  # end of Main

Main "$@"
