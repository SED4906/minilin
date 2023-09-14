#!/bin/sh
set -ex
. ./helper.sh
## Specific versions of packages
KERNEL_VERSION="6.1.52"
BUSYBOX_VERSION="1.36.1"
SYSLINUX_VERSION="6.03"
DROPBEAR_VERSION="2022.83"
MUSL_VERSION="1.2.4"
## Put musl cross-compiler in PATH
PATH="${PATH}:${PWD}/sources/x86_64-linux-musl-cross/bin/"
## Download packages
touch_dir packages
wget -c -O packages/kernel-${KERNEL_VERSION}.tar.xz http://kernel.org/pub/linux/kernel/v$(echo $KERNEL_VERSION | cut -d. -f1).x/linux-${KERNEL_VERSION}.tar.xz
wget -c -O packages/busybox-${BUSYBOX_VERSION}.tar.bz2 http://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
wget -c -O packages/syslinux-${SYSLINUX_VERSION}.tar.xz http://kernel.org/pub/linux/utils/boot/syslinux/syslinux-${SYSLINUX_VERSION}.tar.xz
wget -c -O packages/dropbear-${DROPBEAR_VERSION}.tar.gz https://github.com/mkj/dropbear/archive/refs/tags/DROPBEAR_${DROPBEAR_VERSION}.tar.gz
wget -c -O packages/musl-${MUSL_VERSION}.tar.gz https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz
wget -c -O packages/x86_64-linux-musl-cross.tar.gz https://musl.cc/x86_64-linux-musl-cross.tgz
## Unpack sources
touch_dir sources
pushd sources
tar xvf ../packages/kernel-${KERNEL_VERSION}.tar.xz
tar xvf ../packages/busybox-${BUSYBOX_VERSION}.tar.bz2
tar xvf ../packages/syslinux-${SYSLINUX_VERSION}.tar.xz
tar xvf ../packages/dropbear-${DROPBEAR_VERSION}.tar.gz
tar xvf ../packages/musl-${MUSL_VERSION}.tar.gz
tar xvf ../packages/x86_64-linux-musl-cross.tar.gz
popd
## Populate rootfs
truncate_dir rootfs
pushd rootfs
mkdir boot dev etc proc root sys usr
mkdir_under usr bin lib lib64 sbin
ln -s usr/bin bin
ln -s usr/lib lib
ln -s usr/lib64 lib64
ln -s usr/sbin sbin
popd
## Build musl
pushd sources/musl-${MUSL_VERSION}
make distclean
./configure --prefix=/usr --disable-static
make -j$(nproc)
## Install musl
make DESTDIR=../../rootfs install
popd
## Build Busybox
pushd sources/busybox-${BUSYBOX_VERSION}
make distclean defconfig
sed -i "s|.*CONFIG_INSTALL_NO_USR.*|CONFIG_INSTALL_NO_USR=y|" .config
sed -i "s|.*CONFIG_LINUXRC.*|CONFIG_LINUXRC=n|" .config
sed -i "s|.*CONFIG_CROSS_COMPILER_PREFIX.*|CONFIG_CROSS_COMPILER_PREFIX=\"x86_64-linux-musl-\"|" .config
make -j$(nproc) busybox
make install
popd
## Install Busybox
cp -P sources/busybox-${BUSYBOX_VERSION}/_install/bin/* rootfs/bin/
cp -P sources/busybox-${BUSYBOX_VERSION}/_install/sbin/* rootfs/sbin/
cp sources/busybox-${BUSYBOX_VERSION}/busybox rootfs/bin/
## Build Dropbear
pushd sources/dropbear-DROPBEAR_${DROPBEAR_VERSION}
if [ -e Makefile ]; then
make distclean
fi
./configure --disable-zlib --prefix=/usr --host=x86_64-linux-musl
make -j$(nproc) PROGRAMS="dropbear dropbearkey"
## Install Dropbear
make PROGRAMS="dropbear dropbearkey" DESTDIR=../../rootfs install
popd
mkdir rootfs/etc/dropbear
touch authorized_keys
cp authorized_keys rootfs/etc/dropbear
chmod 644 rootfs/etc/dropbear/authorized_keys
## Pack rootfs into isoimage
truncate_dir isoimage
pushd rootfs
cp -rvf ../defaults/* .
chmod +x etc/init.d/rcS
chmod +x usr/share/udhcpc/default.script
mkdir var
mkdir var/run
ln -s var/run run
ln -s bin/busybox init
pushd etc/network
mkdir if-pre-down.d if-down.d if-post-down.d if-pre-up.d if-up.d
popd
find . | cpio -R root:root -H newc -o | gzip > ../isoimage/rootfs.gz
popd
## Build Linux
pushd sources/linux-${KERNEL_VERSION}
make mrproper defconfig
make -j$(nproc) bzImage
popd
## Build ISO
cp sources/linux-${KERNEL_VERSION}/arch/x86/boot/bzImage isoimage/kernel.gz
cp sources/syslinux-${SYSLINUX_VERSION}/bios/core/isolinux.bin isoimage
cp sources/syslinux-${SYSLINUX_VERSION}/bios/com32/elflink/ldlinux/ldlinux.c32 isoimage
pushd isoimage
echo 'default kernel.gz initrd=rootfs.gz' > ./isolinux.cfg
xorriso \
  -as mkisofs \
  -V MINILIN \
  -o ../minilin.iso \
  -b isolinux.bin \
  -c boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  ./
popd
set +ex