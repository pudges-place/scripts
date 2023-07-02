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
    sed -i 's| Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo|# Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
    sed -i 's| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist

    rm /root/build-server-image-chroot.sh
    rm /root/platformname
    rm /home/alarm/smb.conf
    rm /root/type
    cp /home/alarm/config-server.service /etc/systemd/system/
    cp /home/alarm/lsb-release /etc/
    cp /home/alarm/os-release /etc/
    sed -i 's/Arch/EndeavourOS/g' /etc/issue
    sed -i 's/Arch/EndeavourOS/g' /usr/share/factory/etc/issue
    systemctl enable config-server.service
    systemctl enable NetworkManager
    rm /home/alarm/config-server.service

    printf "\n${CYAN}Ready to create an image.${NC}\n"
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

   useradd -p "alarm" -G users -s /bin/bash -u 1010 "alarm"
   printf "\n${CYAN}Setting root user password...\n\n"
   echo "root:root" | chpasswd

   sed -i 's| Server = http://mirror.archlinuxarm.org/$arch/$repo|# Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist

   case $PLATFORM_NAME in
     OdroidN2) _find_mirrorlist
               _find_keyring
               pacman -Syy
               pacman -R --noconfirm linux-odroid-n2 uboot-odroid-n2
               pacman -Syu --noconfirm --needed linux-odroid linux-odroid-headers uboot-odroid-n2plus
               cp /home/alarm/n2-boot.ini /boot/boot.ini
               pacman -R --noconfrm endeavouros-mirrorlist endeavouros-keyring
               sed -i '/endeavouros/d' /etc/pacman.conf
               sed -i '/SigLevel = PackageRequired/d' /etc/pacman.conf
               rm /etc/pacman.d/endeavouros-mirrorlist
               ;;
     RPi64)    cp /boot/config.txt /boot/config.txt.orig
               cp /home/alarm/rpi4-config.txt /boot/config.txt
               ;;
   esac

   mkdir -p /etc/samba
   cp /home/alarm/smb.conf /etc/samba/
   _finish_up
   printf "\n${CYAN}Exiting arch-chroot${NC}\n"
}  # end of Main

Main "$@"
