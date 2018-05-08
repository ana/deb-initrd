#!/bin/bash -x
#
# host package dependencies
# - debootstrap
# - debian-archive-keyring
# - qemu-user-static

MIRROR=http://deb.debian.org/debian/
KPKG=

#ARCH=arm64
#QEMU=/usr/bin/qemu-aarch64-static
#KPKG=linux-image-arm64

#ARCH=armel
#QEMU=/usr/bin/qemu-arm-static

ARCH=armhf
QEMU=/usr/bin/qemu-arm-static
#KPKG=linux-image-armmp

DIST=stretch
DEST=./$ARCH-$DIST

PACKAGES="$KPKG initramfs-tools sudo "
#PACKAGES="firmware-misc-nonfree"
#PACKAGES+="build-essential"

# Docker (c.f. https://docs.docker.com/install/linux/docker-ce/debian/)
PACKAGES+=" apt-transport-https ca-certificates curl gnupg2 software-properties-common"

#
# First stage
#
sudo debootstrap \
        --arch=$ARCH \
        --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
        --verbose \
        --foreign \
        $DIST \
        $DEST \
        $MIRROR

# customize
sudo sh -c "echo deb $MIRROR $DIST main > $DEST/etc/apt/sources.list"
sudo sh -c "echo $DEST > $DEST/etc/hostname"

# Setup QEMU (for chroot)
sudo cp $QEMU $DEST/usr/bin

#
# Second stage
#
sudo chroot $DEST /debootstrap/debootstrap --second-stage

# clear root passwd
sudo chroot $DEST passwd root -d

sudo sh -c "echo deb $MIRROR $DIST main non-free > $DEST/etc/apt/sources.list"
sudo chroot $DEST apt -q update
sudo chroot $DEST apt -y -q install --no-install-recommends $PACKAGES

# custom patches
for patch in $PWD/patches/*; do
    (cd $DEST; sudo sh -c "patch -p1 < $patch")
done

# Create a minimal ramdisk (dummy kernel version "min", so no modules or firmware)
KVER=min
sudo chroot $DEST update-initramfs -c -k $KVER
sudo chroot $DEST ln -rs /boot/initrd.img-$KVER /boot/rootfs.cpio.gz

#
# /etc/securetty
# - enable root login on non-standard serial console
#
sudo sh -c "echo # OMAP >> $DEST/etc/securetty"
sudo sh -c "echo ttyO0 >> $DEST/etc/securetty"
sudo sh -c "echo ttyO1 >> $DEST/etc/securetty"
sudo sh -c "echo ttyO2 >> $DEST/etc/securetty"
sudo sh -c "echo # Amlogic >> $DEST/etc/securetty"
sudo sh -c "echo ttyAML0 >> $DEST/etc/securetty"

#
# shell in the target
#
#sudo chroot ./$DEST /bin/bash
