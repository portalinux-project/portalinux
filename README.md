# PortaLinux

**NOTICE: This is a Beta Release**

A Linux distribution that tries to be as lightweight and small as possible
while also being as secure and compatible with as many components as it can.

# Minimum Requirements

- CPU: Intel 80486, ARMv5, RISC-V
- RAM: 48* MiB
- HDD: 8** MiB

**These metrics can vary drastically depending on the kernel config used and targeted architecture**

# Build Requirements

## Build tools

- Make >= 4.x
- GCC >= 7 or LLVM >= 14
- Flex >= 2.x
- Bison >= 3.x
- Gawk >= 3.x/Busybox Awk >= 1.30.1
- Rsync (for Linux kernel headers)

## System Requirements

- CPU: Doesn't matter. If it turns on and can read at least 2GiB RAM and at
least 16GiB of storage, it will work
- RAM: 2GiB
- Storage: 10GiB

# Configure PortaLinux

Before building PortaLinux, you must configure it. To do so, you must run
`./configure.rb -p` and the preset you want (The built-in presets are `llvm`
and `gcc`):
```sh
./configure.rb -p gcc # Example command
```
This command will download and unpack all of the packages needed as well as
apply any necessary patches and generate a configure file for the build system.

# Build instructions

## Toolchain

To build a toolchain, run the following:
```sh
./compile.rb -b toolchain
```
This will install a toolchain at `~/cross` under its toolchain type, although
this might be changed to preset name in the future.

## Root Filesystem

To build the PortaLinux root filesystem, run the following:
```sh
./compile.rb -b rootfs
```
This will generate a chrootable directory containing the PortaLinux root
filesystem. It will be located in the output directory

## Bootable Root Filesystem Image

To generate a bootable rootfs image, run the following:
```sh
./compile.rb -b boot-img
```
This will generate a compressed cpio archive that can be booted with a Linux
kernel that supports loading an external initramfs file. It will be located
in the output directory

## Kernel

To build the Linux kernel, run the following:
```sh
./compile.rb -b kernel
```
It will prompt you for the default kernel configuration to be used and whether
or not you want to configure it further. It will compile the kernel afterwards
and put the bootable image, alongside any device tree blobs generated
(if ARM target), in the output folder
