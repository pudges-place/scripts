
#!/bin/bash

_partition_RPi4() {
    parted --script -a minimal $DEVICENAME \
    mklabel gpt \
    unit MiB \
    mkpart primary fat32 2MiB 202MiB \
    mkpart primary ext4 202MiB $DEVICESIZE"MiB" \
    quit
}

_install_RPi4_image() { 
    local failed=""   

    wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
    printf "\n\n${CYAN}Untarring the image...may take a few minutes.${NC}\n"
    bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C MP2
    printf "\n\n${CYAN}syncing files...may take a few minutes.${NC}\n"
    sync
    mv MP2/boot/* MP1
    cp switch-kernel.sh MP2/root/
    failed=$?
    if [[ "$failed" != "0" ]]; then
        printf "\n\n${CYAN}The switch-kernel.sh script failed to be copied to /root.${NC}\n"
    else
        printf "\n\n${CYAN}The switch-kernel.sh script was copied to /root.${NC}\n"
    fi
    sed -i 's/mmcblk0/mmcblk1/' MP2/etc/fstab
}  # End of function _install_RPi4_image


_partition_format_mount() {
   local finished
   local base_dialog_content
   local dialog_content
   local exit_status
   local count
   local i
   local u
   local x

   base_dialog_content="\nThe following storage devices were found\n\n$(lsblk -o NAME,MODEL,FSTYPE,SIZE,FSUSED,FSAVAIL,MOUNTPOINT)\n\n \
   Enter target device name without a partition designation (e.g. /dev/sda or /dev/mmcblk0):"
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
   ##### Determine data device size in MiB and partition ###
   printf "\n${CYAN}Partitioning, & formatting storage device...${NC}\n"
   DEVICESIZE=$(fdisk -l | grep "Disk $DEVICENAME" | awk '{print $5}')
   ((DEVICESIZE=$DEVICESIZE/1048576))
   ((DEVICESIZE=$DEVICESIZE-1))  # for some reason, necessary for USB thumb drives
   printf "\n${CYAN}Partitioning storage device $DEVICENAME...${NC}\n"
   printf "\ndevicename = $DEVICENAME     devicesize = $DEVICESIZE\n" >> /root/enosARM.log
   # umount partitions before partitioning and formatting
   lsblk $DEVICENAME -o MOUNTPOINT | grep /run/media > mounts
   count=$(wc -l mounts | awk '{print $1}')
   if [[ "$count" -gt "0" ]]
   then
      for ((i = 1 ; i <= $count ; i++))
      do
         u=$(awk -v "x=$i" 'NR==x' mounts)
         umount $u
      done
   fi
   rm mounts
   _partition_RPi4
  
   printf "\npartition name = $DEVICENAME\n\n" >> /root/enosARM.log
   printf "\n${CYAN}Formatting storage device $DEVICENAME...${NC}\n"
   printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears, Enter: y${NC}\n\n\n"

   if [[ ${DEVICENAME:5:6} = "mmcblk" ]]
   then
      DEVICENAME=$DEVICENAME"p"
   fi
   
   PARTNAME1=$DEVICENAME"1"
   mkfs.fat $PARTNAME1   2>> /root/enosARM.log
   PARTNAME2=$DEVICENAME"2"
   mkfs.ext4 $PARTNAME2   2>> /root/enosARM.log
   mkdir MP1 MP2
   mount $PARTNAME1 MP1
   mount $PARTNAME2 MP2

} # end of function _partition_format_mount

_check_if_root() {
    local whiptail_installed

    if [ $(id -u) -ne 0 ]
    then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "  Please run this script as sudo or root" 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. Please run this script as sudo or root.${NC}\n"
          exit
       fi
    fi
    if [[ "$SUDO_USER" == "" ]]; then     
         USERNAME=$USER
    else
         USERNAME=$SUDO_USER  
    fi
}

_check_all_apps_closed() {
    whiptail --title "CAUTION" --msgbox "Ensure ALL apps are closed, especially any file manager such as Thunar" 8 74 3>&2 2>&1 1>&3
}


#################################################
# beginning of script
#################################################

Main() {
    # VARIABLES
    PLATFORM=" "     # e.g. OdroidN2, RPi4b, etc.
    DEVICENAME=" "   # storage device name e.g. /dev/sda
    DEVICESIZE="1"
    PARTNAME1=" "
    PARTNAME2=" "
    USERNAME=" "

    # Declare color variables
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    pacman -S --noconfirm --needed libnewt &>/dev/null # for whiplash dialog
    _check_if_root
    _check_all_apps_closed
    _partition_format_mount  # function to partition, format, and mount a uSD card or eMMC card
    _install_RPi4_image

    printf "\n\n${CYAN}Almost done! Just a couple of minutes more for the last step.${NC}\n\n"

    umount MP1 MP2
    rm -rf MP1 MP2
    rm ArchLinuxARM*
    
    printf "\n\n${CYAN}End of script!${NC}\n"
    printf "\n${CYAN}Be sure to use a file manager to umount the device before removing the USB SD reader${NC}\n"

    printf "\n${CYAN}The default user is ${NC}alarm${CYAN} with the password ${NC}alarm\n"
    printf "${CYAN}The default root password is ${NC}root\n\n\n"

    exit
}

Main "$@"
