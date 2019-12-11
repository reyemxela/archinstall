#!/bin/bash

if [ "${1}" = "" ]; then
    timedatectl set-ntp true

    fdisk -l

    read -p 'Enter drive name (/dev/xxx): ' drive
    parted $drive

    read -p 'Enter root partition name (/dev/xxx1): ' rootpart
    mkfs.ext4 $rootpart

    read -p 'Swap partition? [y/N]: ' swapyesno
    case $swapyesno in
        [yY]*)
            read -p 'Enter swap partition name (/dev/xxx2): ' swappart
            mkswap $swappart
            swapon $swappart
            ;;
    esac

    echo 'https://mirrors.kernel.org/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist.new
    cat /etc/pacman.d/mirrorlist >> /etc/pacman.d/mirrorlist.new
    mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist

    mount $rootpart /mnt

    pacstrap /mnt base base-devel linux linux-firmware grub
    pacstrap /mnt vim sudo

    genfstab -U /mnt >> /mnt/etc/fstab

    cp ${0} /mnt/root
    chmod 755 /mnt/root/$(basename "${0}")
    arch-chroot /mnt /root/$(basename "${0}") chroot

    umount $rootpart

    echo "Installation finished, you can now reboot"
fi

if [ "${1}" = "chroot" ]; then
    ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
    hwclock --systohc

    echo 'en_US.UTF-8 UTF-8' >/etc/locale.gen
    echo 'LANG=en_US.UTF-8' >/etc/locale.conf
    locale-gen &>/dev/null

    read -p 'Enter hostname: ' hostname
    read -p 'Enter dns suffix: ' domain
    echo "${hostname}" >/etc/hostname
    echo "127.0.0.1   localhost" >>/etc/hosts
    echo "::1         localhost" >>/etc/hosts
    echo "127.0.1.1   ${hostname}.${domain}   ${hostname}" >>/etc/hosts

    passwd

    grub-mkconfig -o /boot/grub/grub.cfg
    read -p 'Enter drive name to install GRUB (/dev/xxx): ' drive
    grub-install $drive

    exit
fi
