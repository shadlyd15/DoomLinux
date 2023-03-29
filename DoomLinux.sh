#!/bin/sh
KERNEL_VERSION=5.4.3
BUSYBOX_VERSION=1.35.0

mkdir -p rootfs
mkdir -p staging
mkdir -p iso/boot

SOURCE_DIR=$PWD
ROOTFS=$SOURCE_DIR/rootfs
STAGING=$SOURCE_DIR/staging
ISO_DIR=$SOURCE_DIR/iso
STAGING=$SOURCE_DIR/staging

cd $_

export numcpus=$(nproc)
export numcpusplusone=$(( NUMCPUS + 1 ))

set -ex
wget -nc -O kernel.tar.xz http://kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VERSION}.tar.xz
wget -nc -O busybox.tar.bz2 http://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
wget -nc -O fbDOOM-master.zip https://github.com/maximevince/fbDOOM/archive/refs/heads/master.zip
wget -nc -O doom1.wad https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad

tar -xvf kernel.tar.xz
tar -xvf busybox.tar.bz2
unzip fbDOOM-master.zip

cd busybox-${BUSYBOX_VERSION}
make defconfig
LDFLAGS="--static" make busybox install -j$(numcpusplusone)
cd _install
cp -r ./ $ROOTFS/
cd $ROOTFS
rm -f linuxrc

cd $STAGING
cd fbDOOM-master/fbdoom
sed -i "s|CFLAGS+=-ggdb3 -Os|CFLAGS+=-ggdb3 -Os -static|" Makefile
sed -i "s|ifneq (\$(NOSDL),1)|ifeq (\$(LINK_SDL),1)|" Makefile
make -j$(nproc)
cp fbdoom $ROOTFS/bin/fbdoom

cp $STAGING/doom1.wad $ROOTFS/bin/doom1.wad

cd $ROOTFS
mkdir -p bin dev mnt proc sys tmp

echo '#!/bin/sh' > init
echo 'dmesg -n 1' >> init
echo 'mount -t devtmpfs none /dev' >> init
echo 'mount -t proc none /proc' >> init
echo 'mount -t sysfs none /sys' >> init
echo 'fbdoom -iwad /bin/doom1.wad' >> init
echo 'clear' >> init
echo 'setsid cttyhack /bin/sh' >> init

chmod +x init

cd $ROOTFS
find . | cpio -R root:root -H newc -o | gzip > $SOURCE_DIR/iso/boot/rootfs.gz

cd $STAGING
cd linux-${KERNEL_VERSION}
make -j$(numcpusplusone) defconfig
sed -i "s|.*CONFIG_NET=y.*|# CONFIG_NET is not set|" .config
sed -i "s|.*CONFIG_SOUND=y.*|# CONFIG_SOUND is not set|" .config
sed -i "s|.*CONFIG_EFI=y.*|# CONFIG_EFI is not set|" .config
sed -i "s|.*CONFIG_EFI_STUB=y.*|# CONFIG_EFI_STUB is not set|" .config
sed -i "s/^CONFIG_DEBUG_KERNEL.*/\\# CONFIG_DEBUG_KERNEL is not set/" .config
sed -i "s|.*# CONFIG_KERNEL_XZ is not set.*|CONFIG_KERNEL_XZ=y|" .config
sed -i "s|.*CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y.*|# CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE is not set|" .config
sed -i "s|.*# CONFIG_CC_OPTIMIZE_FOR_SIZE is not set.*|CONFIG_CC_OPTIMIZE_FOR_SIZE=y|" .config
sed -i "s|.*CONFIG_KERNEL_GZIP=y.*|# CONFIG_KERNEL_GZIP is not set|" .config
sed -i "s|.*CONFIG_DEFAULT_HOSTNAME=*|CONFIG_DEFAULT_HOSTNAME=\"DoomLinux\"|" .config
sed -i "s|.*# CONFIG_DRM_BOCHS is not set*|CONFIG_DRM_BOCHS=y|" .config

make bzImage -j$(numcpusplusone)
cp arch/x86/boot/bzImage $SOURCE_DIR/iso/boot/bzImage
cp System.map $SOURCE_DIR/iso/boot/System.map

make INSTALL_HDR_PATH=$ROOTFS headers_install -j$(numcpusplusone)

cd $SOURCE_DIR/iso/boot
mkdir -p grub
cd $_
cat > grub.cfg << EOF
set default=0
set timeout=30

# Menu Colours
set menu_color_normal=white/black
set menu_color_highlight=white/green

root (hd0,0)

menuentry "DoomLinux" {      
    linux  /boot/bzImage
    initrd /boot/rootfs.gz
}
EOF

cd $SOURCE_DIR
grub-mkrescue --compress=xz -o DoomLinux.iso iso 
set +ex
