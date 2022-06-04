# DoomLinux
A script to build a minimal live linux operating system that can run Doom.
## What it does
- Downloads Linux Kernel 5.4.3 source and compiles it with a minimal configuration
- Downloads Busybox 1.35.0 source and compiles it statically.
- Downloads FBDoom and compiles it statically.
- Creates rootfs for linux kernel to load.
- Creates grub configuration and builds a bootable iso.
## Build Dependencies
sudo apt install wget make gawk gcc bc bison flex xorriso libelf-dev libssl-dev grub-common
