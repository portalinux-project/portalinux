# PortaLinux v0.12 Beta

**NOTICE: This is an Beta Release**

PortaLinux is a Linux-based operating system made to be as lightweight and
versatile as possible. While it's mainly made for embedded systems, it can be
used for containers, recovery partitions, rescue media, suckless Linux installs
and more.

The root filesystem is built in the form of a gzipped cpio archive that can be
booted as an initramfs, thus you will have to provide your own kernel (or you
can compile the mainline/upstream one using `kernel.rb`). Its build system is
built around the Ruby-powered PortaLinux Ports System, which allows you to
easily customize the root filesystem and add your own packages.

# Minimum Hardware Requirements

**NOTICE: These metrics are based on stock PortaLinux. Adding more packages will make it heavier**

## Boot Requirements

- CPU: Intel 80486, ARMv5, RISCV-32
- Memory: 64MiB (x86), 32MiB (ARM/RISCV)
- Storage: 8-10MiB (Depends on arch)

## Build Requirements

- CPU: Irrelevant. Memory and Storage are more important here
- Memory: 2GiB at 2 threads
- Storage: 16GiB

# Build Dependencies

- Ruby >= 3.0 (for now, needs to be confirmed)
- GCC >= 9 / Clang >= 14
- Make >= 4.0
- CMake >= 3.0 (for compiling LLVM)
- Flex >= 2.0
- Bison >= 3.0
- GNU Awk >= 3.0
- Rsync (Required for Linux headers)

# Contributions

Contributions to the root filesystem are not open yet, but you can submit
packages for the Ports User Repo once that is fully set up.

# v0.11 Maintenance Mode Notice

PortaLinux Release v0.11 will keep being maintained until v0.12 gets a proper
release. Until `v0.12-rootfs-test`, v0.11 will remain at the project root, and
v0.12 development will continue in [`v0.12/`](v0.12)
