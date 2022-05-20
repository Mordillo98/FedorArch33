#!/bin/bash

set -e  # Script must stop if there is an error.

# +-+-+-+-+
# SETTINGS
# +-+-+-+-+

source ./SETTINGS

#
# FUNCTIONS
# ========
# 

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# AVAILABLE_MEMORY
# ================
#
# Will determine what is the current memory,
# add 1GB to it and make it the swap size when
# formatting the HD.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

function make_swap_size () {
	
  physical_memory=$(
	dmidecode -t memory |
	awk '$1 == "Size:" && $2 ~ /^[0-9]+$/ {print $2$3}' |
	numfmt --from=iec --suffix=B |
	awk '{total += $1}; END {print total}' |
	numfmt --to=iec --suffix=B --format=%0f
  )


  SWAP_SIZE=${physical_memory%.*}
  SWAP_SIZE=$((SWAP_SIZE+1))
  SWAP_SIZE=$((SWAP_SIZE * 1024))

  if [ ${FIRMWARE} = "BIOS" ]; then
    SWAP_SIZE=$((SWAP_SIZE + 2176))
  else 
    SWAP_SIZE=$((SWAP_SIZE + 129))
  fi

}

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-
# YES_OR_NO (question, default answer)
# =========
#
# Ask a yes or no question.
# $1: Question
# $2: Default answer (Y or N)
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-

function yes_or_no {

   QUESTION=$1
   DEFAULT_ANSWER=$2
   DEFAULT_ANSWER=${DEFAULT_ANSWER^^}
  
   Y_N_ANSWER=""
   until [ "$Y_N_ANSWER" == Y ] || [ "$Y_N_ANSWER" == N ]; do

      yn=""
 
      printf "${QUESTION}"
      if [ ${DEFAULT_ANSWER} == "Y" ]
        then
	  printf " ${WHITE}[Y/n]: ${NC}"
          read yn
        else
	  printf " ${WHITE}[y/N]: ${NC}"
          read yn
      fi

      if [ "$yn" == "" ]
        then Y_N_ANSWER=$DEFAULT_ANSWER
      fi

      case $yn in
         [Yy]*) Y_N_ANSWER="Y" ;;
         [Nn]*) Y_N_ANSWER="N" ;;
      esac

   done

   Y_N_ANSWER=${Y_N_ANSWER^^}

}

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#
# COUNTSLEEP (message, secs delay)
#
# This function is used to pause the 
# installation at start with a message 
# for x seconds.
#
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

function countsleep {
  
  MESSAGE=$1
  END=$2
  TIME_REMAINING=$((END+1))
  
  for ((i = 1; i <= ${END}; i++)); do
    TIME_REMAINING=$((TIME_REMAINING-1))
    printf "${YELLOW}${MESSAGE}${WHITE}${TIME_REMAINING} \r"
    sleep 1
  done	

  printf "${NC}\n\n"

}

#
# MAIN SCRIPT
# ===========	
# 

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# NEED TO BE RAN WITH ADMIN PRIVILEGES
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

if [ "$EUID" -ne 0 ]
  then
    printf "\n${CYAN}This script needs to be ran with admin privileges to execute properly.\n"

  yes_or_no "${YELLOW}Would you like to run it again with the SUDO command?${NC}" "y"

  case $Y_N_ANSWER in
    [Yy]* ) printf "${NC}"; sudo ./archbangretroinstall.sh; exit;;
    [Nn]* ) printf "\n${CYAN}Bye bye...\n\n${NC}"; exit;;
  esac

fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# ENABLE ALL OUTPUTS TO BE SENT
# TO LOG.OUT DURING THE SCRIPT
# FOR DEBUGGING USAGE.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

echo ""
yes_or_no "Would you like to have the outputs into log.out?" "n"

if [ "$Y_N_ANSWER" == Y ]; then
  exec 3>&1 4>&2
  trap 'exec 2>&4 1>&3' 0 1 2 3
  exec 1>log.out 2>&1
fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# SHOW THE PARAMETERS ON SCREEN
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

clear
printf "\n\n${WHITE}FEDORARCH INSTALL SCRIPT\n"
printf "========================\n\n"
printf "${CYAN}Press Control-C to Cancel\n\n"
printf "${GREEN}FIRMWARE      = ${CYAN}${FIRMWARE}\n\n"
printf "${GREEN}TIMEZONE      = ${CYAN}${TIMEZONE}\n"
printf "${GREEN}REGION        = ${CYAN}${REGION}\n"
printf "${GREEN}LANGUAGE      = ${CYAN}${LANGUAGE}\n"
printf "${GREEN}KEYMAP        = ${CYAN}${KEYMAP}\n\n"
printf "${GREEN}HOSTNAME      = ${CYAN}${HOSTNAME}\n\n"
printf "${GREEN}ARCH_FULLNAME = ${CYAN}${ARCH_FULLNAME}\n"
printf "${GREEN}ARCH_USER     = ${CYAN}${ARCH_USER}\n"
printf "${GREEN}USER_PSW      = ${CYAN}${USER_PSW}\n"
printf "${GREEN}ROOT_PSW      = ${CYAN}${ROOT_PSW}\n\n"
printf "${GREEN}MIRRORS COUNTRY = ${CYAN}${REFLECTOR_COUNTRY}\n\n"

printf "${WHITE}*********************************************${NC}\n\n"

printf "${RED}THIS WILL DESTROY ALL CONTENT OF ${WHITE}${BCK_RED}${DRIVE^^}${NC}${RED} !!!\n\n"

printf "${GREEN}BOOT = ${CYAN}${DRIVE_PART1}\n"
printf "${GREEN}SWAP = ${CYAN}${DRIVE_PART2}\n"
printf "${GREEN}ROOT = ${CYAN}${DRIVE_PART3}\n\n"

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# COUNTDOWN WARNING
# =================
# 
# This is needed to not only warn the HD will be 
# wiped, but for the install to work on slow hardware 
# as not all the services are started when the auto-login 
# occurs on the live CD, making this script fails when 
# launched too early.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

countsleep "Automatic install will start in... " 30 

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# INSTALL THE NEEDED DEPENDENCIES 
# TO RUN THIS SCRIPT FROM ARCH LIVE CD
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

printf "${CYAN}Updating archlinux's repos.\n${NC}"
pacman -Sy > /dev/null

printf "\n${WHITE}"

if ! pacman -Qs dmidecode > /dev/null ; then
	printf "Installing dmidecode...\n"
	pacman -S dmidecode --noconfirm > /dev/null
fi

if ! pacman -Qs reflector > /dev/null ; then
	printf "Installing reflector...\n"
	pacman -S reflector --noconfirm > /dev/null
fi

printf "\n${NC}"

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# ENABLE MIRRORS FROM $MIRROR_LINK
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

printf "${YELLOW}Setting up best mirrors from ${REFLECTOR_COUNTRY} for this live session and FEDORARCH.\n\n${NC}" 

reflector --country ${REFLECTOR_COUNTRY} --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null

countsleep "Partitioning the disk will start in... " 5

# +-+-+-+-+-+-+-+-+-+-+-+-
# UPDATE THE SYSTEM CLOCK 
# +-+-+-+-+-+-+-+-+-+-+-+-

timedatectl set-ntp true

# +-+-+-+-+-+-+-+-+-+-
# PARTITION THE DISKS
# +-+-+-+-+-+-+-+-+-+-

make_swap_size

if mount | grep /mnt > /dev/null; then
  umount -R /mnt
fi 

wipefs -a $DRIVE --force 

if [ ${FIRMWARE} = "BIOS" ]; then
  parted -a optimal $DRIVE --script mklabel msdos
  parted -a optimal $DRIVE --script unit mib

  parted -a optimal $DRIVE --script mkpart primary 2048 2176
  parted -a optimal $DRIVE --script set 1 boot on

  parted -a optimal $DRIVE --script mkpart primary 2176 $SWAP_SIZE

  parted -a optimal $DRIVE --script mkpart primary $SWAP_SIZE -- -1

else
  parted -a optimal $DRIVE --script mklabel gpt
  parted -a optimal $DRIVE --script unit mib

  parted -a optimal $DRIVE --script mkpart primary 1 129
  parted -a optimal $DRIVE --script name 1 boot
  parted -a optimal $DRIVE --script set 1 boot on

  parted -a optimal $DRIVE --script mkpart primary 129 $SWAP_SIZE
  parted -a optimal $DRIVE --script name 2 swap

  parted -a optimal $DRIVE --script mkpart primary $SWAP_SIZE -- -1
  parted -a optimal $DRIVE --script name 3 rootfs

fi


# +-+-+-+-+-+-+-+-+-+-+-
# FORMAT THE PARTITIONS
# +-+-+-+-+-+-+-+-+-+-+-

if [ ${FIRMWARE} = "BIOS" ]; then
  yes | mkfs.ext2 ${DRIVE_PART1}
else
  yes | mkfs.fat -F32 ${DRIVE_PART1}
fi

yes | mkswap ${DRIVE_PART2}
yes | swapon ${DRIVE_PART2}
yes | mkfs.ext4 ${DRIVE_PART3}

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# MOUNT THE NEWLY CREATED PARTITIONS
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

mount /${DRIVE_PART3} /mnt
mkdir /mnt/boot
mount ${DRIVE_PART1} /mnt/boot

# +-+-+-+-+-+-+-+-+
# INSTALL PACKAGES
# +-+-+-+-+-+-+-+-+

EDITOR="vim"
DEPENDENCIES="git reflector net-tools moreutils"
NETWORK="network-manager-applet iwd broadcom-wl xfce4-notifyd"
OPENSSH="openssh"
DISPLAY_MANAGER="lxde xorg-xinit"
APPS="galculator leafpad xarchiver xpad gpicview midori pidgin transmission-gtk efl abiword gnumeric osmo asunder brasero pavucontrol obconf xscreensaver firewalld" 
ICONS="gvfs xdg-user-dirs perl-xml-namespacesupport perl-xml-sax perl-xml-sax-base perl-xml-sax-expat perl-xml-simple icon-naming-utils"
DEPENDS="go perl-xml-parser intltool compface tcl tk docbook-xml docbook-xsl cython libibus ibus"


pacstrap /mnt base base-devel linux linux-firmware man-db man-pages texinfo grub efibootmgr $EDITOR $DEPENDENCIES $NETWORK $OPENSSH $DISPLAY_MANAGER $APPS $ICONS $DEPENDS

# +-+-+-+-+-+-+-+-+
# SETUP /ETC/FSTAB
# +-+-+-+-+-+-+-+-+

genfstab -U /mnt >> /mnt/etc/fstab

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# FEDORARCH (where the magic starts :)
#
# Copying custom files needed during 
# arch-chroot script.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

mkdir -p /mnt${FEDORARCH_FOLDER}
cd /mnt${FEDORARCH_FOLDER}

curl -fLO https://sourceforge.net/projects/fedorarch33/files/fedorarch33.tar.xz
tar -xvf fedorarch33.tar.xz
rm -f fedorarch33.tar.xz

#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# COPYING MIRRORSELECT TO ARCHROOT
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# +-+-+-+-+-+-+-
# CHROOT SCRIPT
# +-+-+-+-+-+-+-

arch-chroot /mnt /bin/bash << EOF

# +-+-+-+-+-+-+-+-
# ENABLE MULTILIB
# +-+-+-+-+-+-+-+-

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy > /dev/null

# +-+-+-+-+-+ 
# TIME ZONE
# +-+-+-+-+-+

ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# +-+-+-+-+-+-+-
# LOCALIZATION
# +-+-+-+-+-+-+-

sed -i "s/#${REGION}/${REGION}/" /etc/locale.gen

locale-gen

printf "LANG=${LANGUAGE}" > /etc/locale.conf 

printf "KEYMAP=${KEYMAP}" > /etc/vconsole.conf


# +-+-+-+-+-+-+-+
# SETUP HOSTNAME
# +-+-+-+-+-+-+-+

printf "${HOSTNAME}" > /etc/hostname

# +-+-+-+-+-+-+-+-+
# SETUP /ETC/HOSTS
# +-+-+-+-+-+-+-+-+

printf "127.0.0.1       localhost\n" > /etc/hosts
printf "::1             localhost\n" >> /etc/hosts
printf "127.0.0.1       ${HOSTNAME}\n" >> /etc/hosts

# +-+-+-+-+-+-+-
# SETUP ROOT PASSWORD
# +-+-+-+-+-+-+-

echo "root:${ROOT_PSW}" | chpasswd

# +-+-+-+-+-+-+-+-+-+
# INSTALL BOOTLOADER
# +-+-+-+-+-+-+-+-+-+

cp ${FEDORARCH_FOLDER}/grub/10_linux /etc/grub.d/
cp ${FEDORARCH_FOLDER}/grub/30_uefi-firmware /etc/grub.d/
cp ${FEDORARCH_FOLDER}/grub/grub /etc/default/

if [ ${FIRMWARE} = "BIOS" ]; then
  grub-install --target=i386-pc ${DRIVE}
else
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
fi

grub-mkconfig -o /boot/grub/grub.cfg

sed -i '/Linux linux/d' /boot/grub/grub.cfg
sed -i '/initial ramdisk/d' /boot/grub/grub.cfg

   # Making sure it's 100% silent during plymouth

   cp ${FEDORARCH_FOLDER}/grub/mkinitcpio.conf /etc/   
   mkinitcpio -p linux
   
   cp ${FEDORARCH_FOLDER}/grub/systemd-fsck-root.service /usr/lib/systemd/system/
   cp ${FEDORARCH_FOLDER}/grub/systemd-fsck@.service /usr/lib/systemd/system/

# +-+-+-+-+-+-+-+-+-+-+-+-+-+
# VI --> VIM symbolink link.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+

ln -s /usr/bin/vim /usr/bin/vi

# +-+-+-+-+-
# NETWORKING
# +-+-+-+-+-

systemctl enable NetworkManager.service

# +-+-+-+-+-+-+-+
# ENABLE OPENSSH
# +-+-+-+-+-+-+-+

systemctl enable sshd

# +-+-+-+-+-+-+-+-+-+-+-+-
# SET DEFAULT ICONS THEME
# +-+-+-+-+-+-+-+-+-+-+-+-

# cat > "/usr/share/icons/default/index.theme" << "EOT"
# [Icon Theme]
# Inherits=gnome-carbonate
# EOT

#+-+-+-+-+-+-+-+-+-+
# ADWAITA & HICOLOR
#+-+-+-+-+-+-+-+-+-+

# rm -rf /usr/share/icons/Adwaita
cp -R ${FEDORARCH_FOLDER}/Adwaita/usr/share/icons/Adwaita /usr/share/icons/
cp -R ${FEDORARCH_FOLDER}/Adwaita/usr/share/licenses/adwaita-icon-theme /usr/share/licenses/
cp -R ${FEDORARCH_FOLDER}/hicolor /usr/share/icons/

gtk-update-icon-cache /usr/share/icons/hicolor
gtk-update-icon-cache /usr/share/icons/Adwaita

#+-+-+-+-+-+-+-+-+-+-+
# BACKGROUND PICTURES
#+-+-+-+-+-+-+-+-+-+-+

mkdir /usr/share/backgrounds
cp -R ${FEDORARCH_FOLDER}/backgrounds /usr/share/

#+-+-+-+-+-+-+-+-+
# BLUECURVE ICONS
#+-+-+-+-+-+-+-+-+

cp -R ${FEDORARCH_FOLDER}/Bluecurve /usr/share/icons/

# +-+-+-+-+-
# /ETC/SKEL
# +-+-+-+-+-

cp -R ${FEDORARCH_FOLDER}/skel /etc/

mkdir /etc/skel/Desktop
mkdir /etc/skel/Documents
mkdir /etc/skel/Downloads
mkdir /etc/skel/Music
mkdir /etc/skel/Pictures
mkdir /etc/skel/Public
mkdir /etc/skel/Templates
mkdir /etc/skel/Videos

# +-+-+-+-+-+-
# CREATE USER
# +-+-+-+-+-+-

useradd -G wheel -s /bin/bash -c "${ARCH_FULLNAME}" ${ARCH_USER} --create-home

echo "${ARCH_USER}:${USER_PSW}" | chpasswd

sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# +-+-+-+-+-+
# ALPM-HOOKS
# +-+-+-+-+-+

mkdir -p /etc/pacman.d/hooks

   # +-+-+-+-
   # TO DO
   # +-+-+-+-

#   printf "Exec = ${FEDORARCH_FOLDER}/HOOKS/scripts/pcmanfm_install.sh" >> ${FEDORARCH_FOLDER}/HOOKS/pcmanfm_install.hook
#   printf "rm /usr/share/applications/pcmanfm-desktop-pref.desktop" >> ${FEDORARCH_FOLDER}/HOOKS/scripts/pcmanfm_install.sh
#   printf "cp ${FEDORARCH_FOLDER}/applications/pcmanfm.desktop /usr/share/applications/" >> ${FEDORARCH_FOLDER}/HOOKS/scripts/pcmanfm_install.sh

# cp -R ${FEDORARCH_FOLDER}/iHOOKS/* /etc/pacman.d/hooks/ 

# +-+-+-+-+-+-+-+-+-+-+-+-+-
# YAY INSTALLS
# +-+-+-+-+-+-+-+-+-+-+-+-+-

# +-+-+-+
# CLIPIT
# +-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/clipit.git
cd /home/${ARCH_USER}/clipit
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./clipit*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/clipit

# +-+-+-+-+
# SYLPHEED 
# +-+-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/sylpheed.git
cd /home/${ARCH_USER}/sylpheed
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./sylpheed*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/sylpheed

# +-+-+-+-
# YAY-BIN
# +-+-+-+-

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/yay.git
cd /home/${ARCH_USER}/yay
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./yay*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/yay


# +-+-+-+-+
# PLYMOUTH
# +-+-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/plymouth.git
cd /home/${ARCH_USER}/plymouth
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./plymouth*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/plymouth

# +-+-+-+
# GIGOLO
# +-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/gigolo.git
cd /home/${ARCH_USER}/gigolo
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./gigolo*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/gigolo

# +-+-+-+-+-+-+
# TKPACMAN
# +-+-+-+-++-+-

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/tkpacman.git
cd /home/${ARCH_USER}/tkpacman
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./tkpacman*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/tkpacman

# +-+-+-+-+-+-+
# LIBCANGJIE
# +-+-+-+-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/libcangjie.git
cd /home/${ARCH_USER}/libcangjie
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./libcangjie*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/libcangjie

# +-+-+-+-+-+-+-+-+
# PYTHON-PYCANGJIE
# +-+-+-+-+-+-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/python-pycangjie.git
cd /home/${ARCH_USER}/python-pycangjie
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./python-pycangjie*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/python-pycangjie

# +-+-+-+-+-+-+
# IBUS-CANGJIE 
# +-+-+-+-+-+-+

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/ibus-cangjie.git
cd /home/${ARCH_USER}/ibus-cangjie
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./ibus-cangjie*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/ibus-cangjie



# +-+-+-+-+-+-+
# MHWD-MANJARO
# +-+-+-+-+-+-+

cd /home/${ARCH_USER}
curl -fLO https://sourceforge.net/projects/archbangretro/files/mhwd-manjaro.tar.xz
tar -xvf mhwd-manjaro.tar.xz
cd /home/${ARCH_USER}/mhwd-manjaro

pacman -U ./v86d-0.1.10-5.1-x86_64.pkg.tar.xz --noconfirm
pacman -U ./mhwd-amdgpu-19.1.0-1-any.pkg.tar.zst --noconfirm
pacman -U ./mhwd-ati-19.1.0-1-any.pkg.tar.zst --noconfirm
pacman -U ./mhwd-nvidia-390xx-390.147-2-any.pkg.tar.zst --noconfirm
pacman -U ./mhwd-nvidia-470xx-470.103.01-1-any.pkg.tar.zst --noconfirm
pacman -U ./mhwd-nvidia-510.54-1-any.pkg.tar.zst --noconfirm
pacman -U ./mhwd-db-0.6.5-21-x86_64.pkg.tar.zst --noconfirm
pacman -U ./mhwd-0.6.5-2-x86_64.pkg.tar.zst --noconfirm

cd /home/${ARCH_USER}
rm /home/${ARCH_USER}/mhwd-manjaro.tar.xz
rm -rf /home/${ARCH_USER}/mhwd-manjaro

mhwd -a pci free 0300


# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# SLIM THEMES AND CONFIGURATION
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

# cp -R ${FEDORARCH_FOLDER}/slim/themes /usr/share/slim/

# cp ${FEDORARCH_FOLDER}/slim/slim.conf /etc/

# +-+-+-+-
# RC.CONF
# +-+-+-+-

# cp ${FEDORARCH_FOLDER}/RC_conf/rc.conf /etc/

# +-+-+-+-+-+-+-+-+-+-+-
# FEDORA 33 MENU SCHEME
# +-+-+-+-+-+-+-+-+-+-+- 

cp ${FEDORARCH_FOLDER}/apps_menu/lxde-applications.menu /etc/xdg/menus/ 

# +-+-+-+-+-+-
# ENABLE PLYMOUTH-LXDM
# +-+-+-+-+-+-

systemctl enable lxdm-plymouth.service

sed -i 's/# bg=\/usr\/share\/backgrounds\/default.png/bg=\/usr\/share\/backgrounds\/default.png/' /etc/lxdm/lxdm.conf


cp ${FEDORARCH_FOLDER}/plymouth/plymouthd.defaults /usr/share/plymouth/
cp ${FEDORARCH_FOLDER}/plymouth/watermark.png /usr/share/plymouth/themes/spinner/

cp ${FEDORARCH_FOLDER}/plymouth/plymouth-* /usr/lib/systemd/system

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# /ETC/PROFILE 
#
# Make HD resolution available 
# under VMware video.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

# cat ${FEDORARCH_FOLDER}/profile/profile >> /etc/profile

#+-+-+-+-+-+-
# NM-APPLET
#+-+-+-+-+-+-

sed -i 's/Exec=nm-applet/Exec=nm-applet --sm-disable/g' /etc/xdg/autostart/nm-applet.desktop

#+-+-+-+-+-+-+-+
# XFCE4-NOTIFYD
#+-+-+-+-+-+-+-+

gawk -i inplace '!/OnlyShowIn/' /etc/xdg/autostart/xfce4-notifyd.desktop

#
# FIREWALLD
# 

systemctl enable firewalld

#+-+-+-+-+-+-+-+-+-
# FEDORA 33 THEMES
#+-+-+-+-+-+-+-+-+-

cp -R ${FEDORARCH_FOLDER}/themes /usr/share/

#+-+-+-+-+-+-+-+-+
# FEDORA 33 FONTS
#+-+-+-+-+-+-+-+-+

# rm -rf /usr/share/fonts
cp -R ${FEDORARCH_FOLDER}/fonts /usr/share/

# +-+-+-+-+-+-+-+-+-
# CLEANUP LXDE MENU
# +-+-+-+-+-+-+-+-+-

cp -R ${FEDORARCH_FOLDER}/applications/* /usr/share/applications/

# cp /usr/share/applications/volumeicon.desktop /etc/xdg/autostart

rm /usr/share/applications/bssh.desktop
rm /usr/share/applications/bvnc.desktop
rm /usr/share/applications/vim.desktop
rm /usr/share/applications/qv4l2.desktop
rm /usr/share/applications/avahi-discover.desktop
rm /usr/share/applications/org.freedesktop.IBus.Setup.desktop
rm /usr/share/applications/ibus-setup-quick.desktop
rm /usr/share/applications/scim-setup.desktop
rm /usr/share/applications/lxhotkey-gtk.desktop
rm /usr/share/applications/qvidcap.desktop

EOF

#
# DONE
#

echo ""
echo "INSTALLATION COMPLETED SUCCESSFULLY !"
echo ""
