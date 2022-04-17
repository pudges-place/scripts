#!/bin/bash

_check_if_root() {
    local whiptail_installed

    if [ $(id -u) -ne 0 ]
    then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "Please run this script with sudo or as root" 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. Please run this script with sudo or as root.${NC}\n"
          exit
       fi
    fi
    if [[ "$SUDO_USER" == "" ]]; then
        USERNAME=$USER
    else
        USERNAME=$SUDO_USER  
    fi
}   # end of function _check_if_root

_choose_device() {

   local base_dialog_content
   local dialog_content
   local finished
   local exit_status

   base_dialog_content="\nThe following storage devices were found\n\n$(lsblk -o NAME,MODEL,FSTYPE,SIZE,FSUSED,FSAVAIL,MOUNTPOINT)\n\n \
   Enter source device name without a partition designation (e.g. /dev/sda or /dev/mmcblk0):"
   dialog_content="$base_dialog_content"
   finished=1
   while [ $finished -ne 0 ]
   do
       DEVICENAME=$(whiptail --title "EndeavourOS ARM Setup - micro SD Configuration" --inputbox "$dialog_content" 27 115 3>&2 2>&1 1>&3)
      exit_status=$?
      if [[ "$exit_status" == "1" ]]; then           
         printf "\nScript aborted by user\n\n"
         exit
      fi
      if [[ ! -b "$DEVICENAME" ]]; then
         dialog_content="$base_dialog_content\n    Not a listed block device, or not prefaced by /dev/ Try again."
      else   
         case $DEVICENAME in
            /dev/sd*)     if [[ ${#DEVICENAME} -eq 8 ]]; then
                             finished=0
                          else
                             dialog_content="$base_dialog_content\n    Input improperly formatted. Try again."   
                          fi ;;
            /dev/mmcblk*) if [[ ${#DEVICENAME} -eq 12 ]]; then
                             finished=0
                          else
                             dialog_content="$base_dialog_content\n    Input improperly formatted. Try again."   
                          fi ;;
         esac
      fi      
   done
}   # end of function _choose_device

_unmount_partitions() {
    local count
    local i
    local u
    local x

    lsblk $DEVICENAME -o MOUNTPOINT | grep /run/media > mounts
    count=$(wc -l mounts | awk '{print $1}')
    if [[ "$count" -gt "0" ]]
    then
       for ((i = 1 ; i <= $count ; i++))
       do
          u=$(awk -v "x=$i" 'NR==x' mounts)
          umount $u
       done
       printf "\nSource Partitions unmounted\n"
    fi
    rm mounts
}   # end of function _umount_partitions

##################### Start of Scipt #################

DEVICENAME=" "

_check_if_root
_choose_device
mkdir MP1
mkdir MP1/boot
if [[ ${DEVICENAME:5:6} = "mmcblk" ]]
then
   DEVICENAME=$DEVICENAME"p"
fi
   
PARTNAME1=$DEVICENAME"1"
PARTNAME2=$DEVICENAME"2"
_unmount_partitions

mount $PARTNAME2 MP1
mount $PARTNAME1 MP1/boot

cd MP1
printf "\nbsdtar is creating the image, may take a few minutes\n"
bsdtar -czf /home/$USERNAME/pudges-place/images/enosLinuxARM-rpi-aarch64-latest.tar.gz *
printf "\n\nbsdtar is finished creating the image.\nand will calculate a sha512sum\n\n"
cd ..
sha512sum /home/$USERNAME/pudges-place/images/enosLinuxARM-rpi-aarch64-latest.tar.gz > /home/$USERNAME/pudges-place/images/enosLinuxARM-rpi-aarch64-latest.tar.gz.sha512sum
umount MP1/boot MP1
rm -rf MP1



