
# DoomLinux
A single script to build a minimal live Linux operating system from source code that runs Doom on boot.
```bash
./DoomLinux.sh
```
This command will create an iso of DoomLinux which is bootable from USB stick.

## What it does
- Downloads Linux Kernel 5.4.3 source and compiles it with a minimal configuration
- Downloads Busybox 1.35.0 source and compiles it statically.
- Downloads FBDoom and compiles it statically.
- Creates rootfs for linux kernel.
- Generates grub configuration
- Creates a bootable live Linux iso that runs Doom on boot.

## Build Dependencies
```bash 
sudo apt install wget make gawk gcc bc bison flex xorriso libelf-dev libssl-dev grub-common
```
## Explanation
### Creating folders and downloading the source codes 

We need to create some folders for managing the codes
```bash
mkdir -p rootfs
mkdir -p staging
mkdir -p iso/boot
```
- rootfs - It is the root file system of DoomLinux. 
```
		rootfs
		├── bin (Busybox and fbdoom binaries)
		├── dev (All the available devices)
		├── mnt (Mount point for temporary external media)
		├── proc (Different information of currently running kernel)
		├── sys (Directory for virtual filesystem)
		└── tmp (Directory for temporary files required during runtime)
```
- staging - Here all the source codes are downloaded and compiled.
- iso - It is the folder structure for grub to make a bootable iso. In boot folder we will place grub.cfg  
```
		iso
		└── boot
		    ├── bzImage (Compiled Linux Kernel)
		    ├── grub
		    │   └── grub.cfg (Grub Configuration)
		    ├── rootfs.gz (Compressed root file system)
		    └── System.map (System map that is compiled with kernel)
```
Setting variables to make things easy
```bash
KERNEL_VERSION=5.4.3
BUSYBOX_VERSION=1.35.0

SOURCE_DIR=$PWD
ROOTFS=$SOURCE_DIR/rootfs
STAGING=$SOURCE_DIR/staging
ISO_DIR=$SOURCE_DIR/iso
```
We need to download the required source codes in staging folder and extract them.
- Linux kernel 5.4.3
- Busybox 1.35.0 - For creating minimum shell environment. 
- FBDoom - A port of Doom original source code for Linux framebuffer.
- Doom shareware - The shareware version of Doom. You can use other versions if you want.

```bash
cd $STAGING
wget -nc -O kernel.tar.xz http://kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VERSION}.tar.xz
wget -nc -O busybox.tar.bz2 http://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
wget -nc -O fbDOOM-master.zip https://github.com/maximevince/fbDOOM/archive/refs/heads/master.zip
wget -nc -O doom1.wad https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad

tar -xvf kernel.tar.xz
tar -xvf busybox.tar.bz2
unzip fbDOOM-master.zip
```
### Configuring the kernel and compile it
Change directory to kernel source.
```bash
cd $STAGING
cd linux-${KERNEL_VERSION}
```
Creating a config file for kernel.
You can use either of the following
```bash
make -j$(nproc) defconfig # Creates a ".config" file with default options from current architecture
make -j$(nproc) menuconfig # Menu-driven user interface for configuring kernel
make -j$(nproc) xconfig # GUI based user interface for configuring kernel
```
-j$(nproc) flag sets the number of jobs to the number of CPU cores/threads available. It make things compile faster. 

Now we will make a couple of changes in the .config file to make our kernel size smaller. It will also reduce the compile time.

Use xz kernel compression instead of gzip
```bash
sed -i "s|.*# CONFIG_KERNEL_XZ is not set.*|CONFIG_KERNEL_XZ=y|" .config
sed -i "s|.*CONFIG_KERNEL_GZIP=y.*|# CONFIG_KERNEL_GZIP is not set|" .config
```
Disable sound drivers.
```bash
sed -i "s|.*CONFIG_SOUND=y.*|# CONFIG_SOUND is not set|" .config
```
Disable network drivers.
```bash
sed -i "s|.*CONFIG_NET=y.*|# CONFIG_NET is not set|" .config
```
Disable EFI stubs.
```bash
sed -i "s|.*CONFIG_EFI=y.*|# CONFIG_EFI is not set|" .config 
sed -i "s|.*CONFIG_EFI_STUB=y.*|# CONFIG_EFI_STUB is not set|" .config
```
Disable kernel debug.
```bash  
sed -i "s/^CONFIG_DEBUG_KERNEL.*/\\# CONFIG_DEBUG_KERNEL is not set/" .config
```
Optimize for size. 
```bash
sed -i "s|.*CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y.*|# CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE is not set|" .config
sed -i "s|.*# CONFIG_CC_OPTIMIZE_FOR_SIZE is not set.*|CONFIG_CC_OPTIMIZE_FOR_SIZE=y|" .config
```
Change host name
```bash
sed -i "s|.*CONFIG_DEFAULT_HOSTNAME=*|CONFIG_DEFAULT_HOSTNAME=\"DoomLinux\"|" .config
```


Now compile the kernel and copy the binaries.
```bash
make -j$(nproc) bzImage
cp arch/x86/boot/bzImage $SOURCE_DIR/iso/boot/bzImage
cp System.map $SOURCE_DIR/iso/boot/System.map
```
### Configuring busybox and compile it
```bash
cd  $STAGING
cd busybox-${BUSYBOX_VERSION}
make defconfig
sed -i "s|.*CONFIG_STATIC.*|CONFIG_STATIC=y|" .config
make -j$(nproc) busybox install
cd _install
cp -r ./ $ROOTFS/
cd $ROOTFS
rm -f linuxrc
```
These commands will statically compile busybox. The default installation folder for busybox is _install. We will copy the compiled binaries from there to our rootfs. 

### Compile FBDoom statically
```bash
cd $STAGING
cd fbDOOM-master/fbdoom
sed -i "s|CFLAGS+=-ggdb3 -Os|CFLAGS+=-ggdb3 -Os -static|" Makefile
make -j$(nproc)
cp fbdoom $ROOTFS/bin/fbdoom
cp $STAGING/doom1.wad $ROOTFS/bin/doom1.wad
```
We need to statically compile FBDoom to work it in our system with minimal dependencies. The above commands will do that for us and it will also copy the doom1.wad in our root folder.

### Archive rootfs
We will create additional folders so that Linux kernel can use them on runtime.
```bash
cd $ROOTFS
mkdir -p dev proc sys mnt tmp
```
Now we will create a init file for our kernel.
```bash
echo '#!/bin/sh' > init
```
Suppress all messages from the kernel except panic messages.
```bash
echo 'dmesg -n 1' >> init
```
Mount dev folder to devtmpfs
```bash
echo 'mount -t devtmpfs none /dev' >> init
```
Mount proc folder to proc
```bash
echo 'mount -t proc none /proc' >> init
```
Mount sys folder to sysfs
```bash
echo 'mount -t sysfs none /sys' >> init
```
Run doom right after booting the kernel. After that we will run busybox with cttyhack to stop kernel panic if we want to exit busybox. It will open another shell instead.
```bash
echo 'fbdoom -iwad /bin/doom1.wad' >> init
echo 'setsid cttyhack /bin/sh' >> init
```
We must have to make the init file executable. 
```bash
chmod +x init
```
Now archive the rootfs with cpio.
```bash
cd $ROOTFS
find . | cpio -R root:root -H newc -o | gzip > $SOURCE_DIR/iso/boot/rootfs.gz
```
### Using GRUB bootloader to boot DoomLinux
Create a grub configuration file in iso/boot directory.
```bash
cd $SOURCE_DIR/iso/boot
mkdir -p grub
cd grub
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
```
These are the location of our compiled kernel and archived rootfs.
```
  linux  /boot/bzImage
  initrd /boot/rootfs.gz
```
Finally create DoomLinux bootable iso
```bash
cd $SOURCE_DIR
grub-mkrescue --compress=xz -o DoomLinux.iso iso
```

## Acknowledgements
- [Write your own Operating System](https://www.youtube.com/watch?v=asnXWOUKhTA)
- [Minimal linux script](https://github.com/ivandavidov/minimal-linux-script)

## Disclaimer
This project is made just for those who wants to learn how basic linux systems works. Under no circumstances shall the author be liable for any damage.

## Licence 
Licensed under the MIT License.
