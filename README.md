# PortaLinux

A Linux distribution that tries to be as lightweight and small as possible
while also being as secure and compatible with as many components as it can.

# Minimum Requirements

- CPU: Intel 80486
- RAM: 110 MiB
- HDD: 22 MiB

# Build Requirements

## Build tools

- Make >= 4.x
- GCC >= 7
- GLIBC >= 2.31
- Flex >= 2.x
- Bison >= 3.x
- Gawk >= 3.x/Busybox Awk >= 1.30.1

## System Requirements

- CPU: Doesn't matter. If it turns on and can read at least 2GiB RAM and at
least 16GiB of storage, it will work
- RAM: 2GiB
- Storage: 10GiB

# Build instructions

Before building PortaLinux, you must initialize the script by running the 
following:
```
./compile --init
```
This will download all of the necessary components to compile the target
toolchain, the target root filesystem and the target kernel.

Whenever you want to target a system different from the default, you must
change the compile target with the `--target-compile` option (`$arch` being
the target architecture and `$dist` being the distribution, `musl` and `gnu`
being the only valid options).
```
./compile --target-system $arch-$dist --init
```

## Toolchain

To compile the target toolchain, run the following:
```
./compile --build toolchain
```
If targeting a different system from the default, use the `--target-system`
option to change the compile target.
```
./compile --target-system $arch-$dist --build toolchain
```

## Root Filesystem

To compile the target root filesystem, run the following
```
./compile --build rootfs
```
If targeting a different system from the default, use the `--target-system`
option to change the compile target.
```
./compile --target-system $arch-$dist --build rootfs
```

## Kernel

Before compiling the kernel, you must configure it by running the following:
```
./compile --config-kernel
```
After you're done configuring the kernel, run the following:
```
./compile --build kernel
```
