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
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$ARMARCH | grep "endeavouros-mirrorlist" | sed s'/^.*endeavouros-mirrorlist/endeavouros-mirrorlist/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | tail -1 > mirrors

    tmpfile="mirrors"
    read -d $'\x04' currentmirrorlist < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-mirrorlist...${NC}"
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$ARMARCH/$currentmirrorlist 2>> /root/enosARM.log

    printf "\n${CYAN}Installing endeavouros-mirrorlist...${NC}\n"
    pacman -U --noconfirm $currentmirrorlist

    # printf "\n[sar]\nSigLevel = PackageRequired\nServer = http://127.0.0.1:22122\n\n" >> /etc/pacman.conf
    printf "\n[endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n\n" >> /etc/pacman.conf

    rm mirrors
}  # end of function _find_mirrorlist


_find_keyring() {
    local tmpfile
    local currentkeyring
    local ARMARCH="aarch64"

    printf "\n${CYAN}Find current endeavouros-keyring...${NC}\n\n"
    sleep 1
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$ARMARCH | grep endeavouros-keyring | sed s'/^.*endeavouros-keyring/endeavouros-keyring/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | tail -1 > keys

    tmpfile="keys"
    read -d $'\04' currentkeyring < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-keyring...${NC}"
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$ARMARCH/$currentkeyring 2>> /root/enosARM.log

    printf "\n${CYAN}Installing endeavouros-keyring...${NC}\n"
    pacman -U --noconfirm $currentkeyring

    rm keys
}   # End of function _find_keyring

_base_addons() {
    ### the following installs all packages needed to match the EndeavourOS base install
    printf "\n${CYAN}Installing EndeavourOS Base Addons...${NC}\n"
    eos-packagelist --arch arm "Desktop-Base + Common packages" "Firefox and language package" > base-addons
    printf "openbox\npcmanfm-gtk3\ntint2\nnetwork-manager-applet\nxfce4-terminal\nflameshot" >> base-addons
    pacman -S --noconfirm --needed - < base-addons
    ### Install Calamares Arm
    pacman -U --noconfirm /home/alarm/configs/xkeyboard-config-2.35.1-1-any.pkg.tar.xz
    pacman -S --noconfirm --needed calamares_current_arm calamares_config_default_arm calamares_config_ce_arm
    rm -rf base-addons
}   # end of function _base_addons

_finish_up() {
    case $OPSYSTEM in
    Desktop) printf "alarm ALL=(ALL:ALL) NOPASSWD: ALL\n" >> /etc/sudoers
        gpasswd -a alarm wheel
        printf "exec openbox-session\n" >> /home/alarm/.xinitrc
        printf "if [ -z \"\${DISPLAY}\" ] && [ \"\${XDG_VTNR}\" -eq 1 ]; then\n  exec startx\nfi\n" >> /home/alarm/.bash_profile
        chown alarm:alarm /home/alarm/.xinitrc
        chmod 644 /home/alarm/.xinitrc
        systemctl disable dhcpcd.service
        systemctl enable NetworkManager.service
        pacman -Rn --noconfirm dhcpcd
        cp /home/alarm/configs/ORION-sky-ARM.png /usr/share/endeavouros/backgrounds/endeavouros-wallpaper.png
        cp /home/alarm/configs/EOS-PLANETS-ARM.png /usr/share/endeavouros/backgrounds/endeavouros-calamares-wallpaper.png
        rm -rf /endeavouros*
        usermod -u 2001 alarm
        groupmod -g 2001 alarm
        cd /home/alarm/
        rm -rf .config
        mkdir .config
        mkdir Desktop
        cd configs/
        # cp /boot/config.txt /boot/config.txt.orig
        # cp rpi4-config.txt /boot/config.txt
        cp /usr/lib/systemd/system/getty@.service /usr/lib/systemd/system/getty@.service.bak
        cp getty@.service /usr/lib/systemd/system/getty@.service
        cp clean-up.sh /usr/local/bin/clean-up.sh
        chmod +x /usr/local/bin/clean-up.sh
        cp clean-up.service /etc/systemd/system/clean-up.service
       ./alarmconfig.sh
       ./calamares.sh
       cd ..
       chown -R alarm .config Desktop .Xauthority
       printf "[Match]\nName=wlan*\n\n[Network]\nDHCP=yes\nDNSSEC=no\n" > /etc/systemd/network/wlan.network
       timedatectl set-ntp true
       timedatectl timesync-status ;;
    esac
    printf "\nalias ll='ls -l --color=auto'\n" >> /etc/bash.bashrc
    printf "alias la='ls -al --color=auto'\n" >> /etc/bash.bashrc
    printf "alias lb='lsblk -o NAME,FSTYPE,FSSIZE,LABEL,MOUNTPOINT'\n\n" >> /etc/bash.bashrc
    rm /var/cache/pacman/pkg/*
    rm /root/build-image-chroot.sh
    rm /root/enosARM.log
    rm -rf /etc/pacman.d/gnupg
    printf "\n\n${CYAN}Your uSD is ready for creating an image.${NC}\n"
}   # end of function _finish_up

_switch_mirrors_local() {
   sed -i 's|Server = http://mirror.archlinuxarm.org/$arch/$repo|#Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|Server|#Server|g' /etc/pacman.d/endeavouros-mirrorlist
   echo "Server = http://127.0.0.1:21212" >> /etc/pacman.d/mirrorlist
   echo "Server = http://10.42.0.1:9129/repo/archlinux_\$arch/\$repo" >> /etc/pacman.d/mirrorlist
   echo "Server = http://10.42.0.1:9129/repo/endeavouros/\$repo/\$arch" >> /etc/pacman.d/endeavouros-mirrorlist
   # echo "Server = https://github.com/endeavouros-arm/repo/raw/master/\$repo/\$arch" >> /etc/pacman.d/endeavouros-mirrorlist
   # printf "\n[sar]\nSigLevel = PackageRequired\nServer = http://127.0.0.1:22122\n\n" >> /etc/pacman.conf

}

_switch_mirrors_back() {
    sed -i 's|#Server = http://mirror.archlinuxarm.org/$arch/$repo|Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
    sed -i 's|Server = http://127.0.0.1:21212||g' /etc/pacman.d/mirrorlist
    sed -i 's|Server = http://10.42.0.1:9129/repo/archlinux_$arch/$repo||g' /etc/pacman.d/mirrorlist
    sed -i 's|Server = http://10.42.0.1:9129/repo/endeavouros/$repo/$arch||g' /etc/pacman.d/endeavouros-mirrorlist
    # sed -i 's|Server = https://github.com/endeavouros-arm/repo/raw/master/$repo/$arch||g' /etc/pacman.d/endeavouros-mirrorlist
    sed -i 's|#Server|Server|g' /etc/pacman.d/endeavouros-mirrorlist
    sed -i 's|\[sar\]||g' /etc/pacman.conf
    sed -i 's|SigLevel = PackageRequired||g' /etc/pacman.conf
    sed -i 's|Server = http://127.0.0.1:22122||g' /etc/pacman.conf
}

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
   file="/root/mirrors"
   read -d $'\x04' LOCAL < "$file"
   file="/root/operatingsystem"
   read -d $'\x04' OPSYSTEM < "$file"
   _check_if_root
   _check_internet_connection
   sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf
   sed -i "s|#Color|Color\nILoveCandy|g" /etc/pacman.conf
   sed -i "s|#VerbosePkgLists|VerbosePkgLists\nDisableDownloadTimeout|g" /etc/pacman.conf
   pacman-key --init
   pacman-key --populate archlinuxarm
   pacman -Syy
   pacman -S --noconfirm wget
   _find_mirrorlist
   _find_keyring
   # Switch Mirrors to Local server for faster image creation
   # and low bandwidth usage
   if $LOCAL ; then
        _switch_mirrors_local
        pacman -Syy
   fi

   case $PLATFORM_NAME in
     OdroidN2) pacman -R --noconfirm linux-odroid-n2 uboot-odroid-n2
               pacman -Syu --noconfirm --needed linux-odroid linux-odroid-headers uboot-odroid-n2plus # odroid-n2-post-install
               cp /home/alarm/n2-boot.ini /boot/boot.ini
               ;;
     RPi64)    pacman -R --noconfirm linux-aarch64 uboot-raspberrypi
               pacman -Syu --noconfirm --needed linux-rpi raspberrypi-bootloader raspberrypi-firmware
               cp /boot/config.txt /boot/config.txt.orig
               cp /home/alarm/rpi4-config.txt /boot/config.txt
               ;;
   esac

   case $OPSYSTEM in
      Desktop) pacman -S --noconfirm --needed eos-packagelist
              _base_addons ;;
   esac

   if $LOCAL ; then
       # Switch Mirrors back to original
       _switch_mirrors_back
   fi

   _finish_up
}  # end of Main

Main "$@"
