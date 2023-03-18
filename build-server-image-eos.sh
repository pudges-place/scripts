#!/bin/bash

_partition_OdroidN2() {
    parted --script -a minimal $DEVICENAME \
    mklabel msdos \
    unit mib \
    mkpart primary fat32 2MiB 258MiB \
    mkpart primary 258MiB $DEVICESIZE"MiB" \
    quit
}

_partition_RPi4() {
    parted --script -a minimal $DEVICENAME \
    mklabel gpt \
    unit MiB \
    mkpart primary fat32 2MiB 202MiB \
    mkpart primary ext4 202MiB $DEVICESIZE"MiB" \
    quit
}

_copy_stuff_for_chroot() {
    cp build-server-image-chroot.sh /mnt/root/
    cp eos-ARM-server-config.sh /mnt/root/
    cp smb.conf /mnt/home/alarm
    cp server-addons /mnt/home/alarm
    cp config-server.service /mnt/home/alarm/
    cp lsb-release /mnt/home/alarm
    cp os-release /mnt/home/alarm
    case $PLATFORM in
      RPi64)    cp rpi4-config.txt /mnt/home/alarm/ ;;
      OdroidN2) cp n2-boot.ini /mnt/home/alarm ;;
    esac
    printf "$PLATFORM\n" > platformname
    cp platformname /mnt/root/
    rm platformname
}

_install_OdroidN2_image() {
    local user_confirm
    if $DOWNLOAD ; then
        wget http://os.archlinuxarm.org/os/ArchLinuxARM-odroid-n2-latest.tar.gz
    fi
    printf "\n\n${CYAN}Untarring the image...might take a few minutes.${NC}\n"
    bsdtar -xpf ArchLinuxARM-odroid-n2-latest.tar.gz -C /mnt
    dd if=/mnt/boot/u-boot.bin of=$DEVICENAME conv=fsync,notrunc bs=512 seek=1
    sed -i '/setenv bootargs "root=UUID=/c\setenv bootargs "root=/dev/mmcblk1p2 rootwait rw"' /mnt/boot/boot.ini
    _copy_stuff_for_chroot
}   # End of function _install_OdroidN2_image


_install_RPi4_image() { 
    local failed=""   
    if $DOWNLOAD ; then
        wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
    fi
    printf "\n\n${CYAN}Untarring the image...may take a few minutes.${NC}\n"
    bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C /mnt
    printf "\n\n${CYAN}syncing files...may take a few minutes.${NC}\n"
    sync
    _copy_stuff_for_chroot
    sed -i 's/mmcblk0/mmcblk1/' /mnt/etc/fstab
}  # End of function _install_RPi4_image

_partition_format_mount() {
   local count
   local i
   local u
   local x

   ##### Determine data device size in MiB and partition ###
   printf "\n${CYAN}Partitioning, & formatting storage device...${NC}\n"
   DEVICESIZE=$(fdisk -l | grep "Disk $DEVICENAME" | awk '{print $5}')
   ((DEVICESIZE=$DEVICESIZE/1048576))
   ((DEVICESIZE=$DEVICESIZE-1))  # for some reason, necessary for USB thumb drives
   printf "\n${CYAN}Partitioning storage device $DEVICENAME...${NC}\n"
   # umount partitions before partitioning and formatting
   lsblk $DEVICENAME -o MOUNTPOINT | grep "/" > mounts
   count=$(wc -l mounts | awk '{print $1}')
   if [[ "$count" -gt "0" ]]
   then
      for ((i = 1 ; i <= $count ; i++))
      do
         u=$(awk -v "x=$i" 'NR==x' mounts)
         umount $u
#         rm -rf $u
      done
   fi
   rm mounts

   case $PLATFORM in   
      RPi64)    _partition_RPi4 ;;
      OdroidN2) _partition_OdroidN2 ;;
   esac
  
   printf "\n${CYAN}Formatting storage device $DEVICENAME...${NC}\n"
   printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears, Enter: y${NC}\n\n\n"

   if [[ ${DEVICENAME:5:6} = "mmcblk" ]]
   then
      DEVICENAME=$DEVICENAME"p"
   fi

   PARTNAME1=$DEVICENAME"1"
   mkfs.fat $PARTNAME1
   PARTNAME2=$DEVICENAME"2"
   mkfs.ext4 $PARTNAME2
   mount $PARTNAME2 /mnt
   mkdir /mnt/boot
   mount $PARTNAME1 /mnt/boot
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
}  # end of function _check_if_root



_arch_chroot(){
    arch-chroot /mnt /root/build-server-image-chroot.sh
}

_create_image(){
    case $PLATFORM in
       OdroidN2)# time bsdtar --use-compress-program=zstdmt -cf $IMAGEDIR/enosARM-server-odroid-n2-latest.tar.zst *
          time bsdtar -cf - * | zstd -z --rsyncable -10 -T0 -of /$IMAGEDIR/enosARM-server-odroid-n2-latest.tar.zst
          printf "\n\nbsdtar is finished creating the image.\nand will calculate a sha512sum\n\n"
          cd ..
          dir=$(pwd)
          cd $IMAGEDIR
          sha512sum enosARM-server-odroid-n2-latest.tar.zst > enosARM-server-odroid-n2-latest.tar.zst.sha512sum
          cd $dir ;;
       RPi64) # time bsdtar --use-compress-program=zstdmt -cf $IMAGEDIR/enosARM-server-rpi-latest.tar.zst *
          time bsdtar -cf - * | zstd -z --rsyncable -10 -T0 -of $IMAGEDIR/enosARM-server-rpi-latest.tar.zst
          printf "\n\nbsdtar is finished creating the image.\nand will calculate a sha512sum\n\n"
          cd ..
          dir=$(pwd)
          cd $IMAGEDIR
          sha512sum enosARM-server-rpi-latest.tar.zst > enosARM-server-rpi-latest.tar.zst.sha512sum
          cd $dir ;;
    esac
}

_help() {
   # Display Help
   printf "\nHELP\n"
   printf "Build EndeavourOS ARM Images\n"
   printf "options:\n"
   printf " -h  Print this Help.\n\n"
   printf "These options are required\n"
   printf " -d  enter device name for ex: sda\n"
   printf " -p  enter platform: rpi or odn\n"
   printf "These options are optional\n"
   printf " -i  download base image: (y) or n\n"
   printf " -c  create image: (y) or n\n"
   printf "example: sudo ./build-server-image-eos.sh -d sda -p rpi -i y -c y\n"
   printf "Ensure that the directory $IMAGEDIR exists\n\n"
}

_read_options() {
    # Available options
    opt=":d:p:i:c:h:"
    local OPTIND

    if [[ ! $@ =~ ^\-.+ ]]
    then
      echo "The script requires an argument, aborting"
      _help
      exit 1
    fi

    while getopts "${opt}" arg; do
      case $arg in
        d)
          DEVICENAME="/dev/${OPTARG}"
          ;;
        p)
          PLAT="${OPTARG}"
          ;;
        i)
          DOWN="${OPTARG}"
          ;;
        c)
          CRE="${OPTARG}"
          ;;
        \?)
          echo "Option -${OPTARG} is not valid, aborting"
          _help
          exit 1
          ;;
        h|?)
          _help
          exit 1
          ;;
        :)
          echo "Option -${OPTARG} requires an argument, aborting"
          _help
          exit 1
          ;;
      esac
    done
    shift $((OPTIND-1))

case $PLAT in
     rpi) PLATFORM="RPi64" ;;
     odn) PLATFORM="OdroidN2" ;;
     *) PLAT1=true;;
esac

case $DOWN in
     y) DOWNLOAD=true ;;
     n) DOWNLOAD=false ;;
     *) DOWNLOAD=true ;;
esac

case $CRE in
     y) CREATE=true ;;
     n) CREATE=false ;;
     *) CREATE=true ;;
esac
}

#################################################
# beginning of script
#################################################

Main() {
    # VARIABLES
    PLAT=""
    PLATFORM=" "     # e.g. OdroidN2, RPi4b, etc.
    DEVICENAME=" "   # storage device name e.g. /dev/sda
    IMAGEDIR="/home/don/pudges-place/server-images"
#   OPSYS=" "        # operating system e.g. Desktop, Server
    DEVICESIZE="1"
    PARTNAME1=" "
    PARTNAME2=" "
    DEVICETYPE=" "
    DOWN=" "
    DOWNLOAD=" "
    CREATE=" "
    LOC=" "
#   LOCAL=" "
    
    # Declare color variables
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    pacman -S --noconfirm --needed libnewt arch-install-scripts time sed &>/dev/null # for whiplash dialog
    _check_if_root
    _read_options "$@"

    _partition_format_mount  # function to partition, format, and mount a uSD card or eMMC card
    case $PLATFORM in
       RPi64)    _install_RPi4_image ;;
       OdroidN2) _install_OdroidN2_image ;;
    esac

    printf "\n\n${CYAN}arch-chroot to switch kernel.${NC}\n\n"
    _arch_chroot

    if $CREATE ; then
        printf "\n\n${CYAN}Creating Image${NC}\n\n"
        case $PLATFORM in
            RPi64) imagetype="rpi" ;;
            OdroidN2) imagetype="odroid-n2";;
        esac
        if [ -f "$IMAGEDIR/enosARM-server-$imagetype-latest.tar.zst" ]; then
           rm $IMAGEDIR/enosARM-server-$imagetype-latest.tar.zst $IMAGEDIR/enosARM-server-$imagetype-latest.tar.zst.sha512sum
       fi

        printf "\nCheck for existing images\n\n"
        ls $IMAGEDIR
        printf "\n\n"

        cd /mnt
        _create_image
        printf "\n\n${CYAN}Created Image${NC}\n\n"
    fi

    umount /mnt/boot /mnt
#    rm -rf MP2
    # rm ArchLinuxARM*

    exit
}

Main "$@"
