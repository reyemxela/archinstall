#!/bin/bash

if [ "${1}" = "" ]; then
    timedatectl set-ntp true

    fdisk -l

    echo -e '\n--------------------------------------------'
    read -p 'Enter drive name (/dev/xxx): ' drive
    #cfdisk $drive
    parted -s "$drive" \
        mklabel msdos \
        mkpart primary ext2 1 100% \
        set 1 boot on

    fdisk -l $drive
    echo -e '\n--------------------------------------------'
    read -p 'Enter root partition name (/dev/xxx1): ' rootpart
    echo 'Formatting with ext4...'
    mkfs.ext4 $rootpart

    #echo -e '\n--------------------------------------------'
    #read -p 'Swap partition? [y/N]: ' swapyesno
    #case $swapyesno in
    #    [yY]*)
    #        read -p 'Enter swap partition name (/dev/xxx2): ' swappart
    #        mkswap $swappart
    #        swapon $swappart
    #        ;;
    #esac

    echo 'Setting up custom mirror...'
    echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist.new
    cat /etc/pacman.d/mirrorlist >> /etc/pacman.d/mirrorlist.new
    mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist

    echo 'Mounting root filesystem...'
    mount $rootpart /mnt

    echo 'Copying pacman mirrorlist to new filesystem...'
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

    echo 'Running pacstrap'
    pacstrap /mnt base base-devel linux linux-firmware grub openssh dhcpcd git vim sudo zsh

    echo 'Running genfstab...'
    genfstab -U /mnt >> /mnt/etc/fstab

    echo 'Copying script to new filesystem...'
    cp ${0} /mnt/root
    chmod 755 /mnt/root/$(basename "${0}")
    echo 'Running script in chroot environment...'
    arch-chroot /mnt /root/$(basename "${0}") chroot

    echo 'Unmounting filesystem...'
    umount $rootpart

    echo "Installation finished, you can now reboot"
fi

if [ "${1}" = "chroot" ]; then
    echo 'Setting zoneinfo...'
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
    echo 'Syncing clock...'
    hwclock --systohc

    echo 'Setting locale...'
    echo 'en_US.UTF-8 UTF-8' >/etc/locale.gen
    echo 'LANG=en_US.UTF-8' >/etc/locale.conf
    locale-gen &>/dev/null
    
    echo 'Setting pacman preferences...'
    sed -i 's/#Color/Color/' /etc/pacman.conf
    
    echo 'Installing yay...'
    sudo -u nobody git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    sudo -u nobody makepkg -s
    pacman -U yay-bin*.pkg.tar.xz
    
    echo 'Setting sudo preferences...'
    echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers.d/wheel

    read -p 'Enter hostname: ' hostname
    read -p 'Enter dns suffix: ' domain
    echo 'Setting hostname...'
    echo "${hostname}" >/etc/hostname
    echo "127.0.0.1   localhost" >>/etc/hosts
    echo "::1         localhost" >>/etc/hosts
    echo "127.0.1.1   ${hostname}.${domain}   ${hostname}" >>/etc/hosts

    echo 'Enabling dhcpcd...'
    systemctl enable dhcpcd

    echo 'Setting new root password'
    passwd
    
    echo 'Setting up new user...'
    read -p 'New user name: ' username
    useradd -m -G wheel,video $username
    passwd $username
    chsh $username

    read -p 'Enter drive name to install GRUB (/dev/xxx): ' drive
    echo 'Running grub-install...'
    grub-install $drive
    echo 'Generating GRUB config...'
    grub-mkconfig -o /boot/grub/grub.cfg

    exit
fi
