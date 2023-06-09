# SPDX-License-Identifier: MPL-2.0

## Default Directory and Logfile Locations
build="$pldir/build"
output="$pldir/output"
output_rootfs="$output/rootfs"
output_initramfs="$output/initramfs"
toolchain_prefix="$(echo ~/cross)"
logfile="$pldir/log.txt"

## Default URLS
kernel_url="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.79.tar.xz"
musl_url="https://musl.libc.org/releases/musl-1.2.3.tar.gz"
toybox_url="http://landley.net/toybox/downloads/toybox-0.8.9.tar.gz"
pl32lib_url="https://github.com/pocketlinux32/pl32lib-ng/archive/refs/tags/v1.04-ng.tar.gz"
libplml_url="https://github.com/pocketlinux32/libplml/archive/refs/heads/main.tar.gz"
plsrv_url="https://github.com/pocketlinux32/pl-srv/archive/refs/tags/v0.02.tar.gz"
# llvm toolchain url
llvm_url="https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-14.0.6.tar.gz"
# gcc toolchain urls
binutils_url="http://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.gz"
gcc_url="http://ftp.gnu.org/gnu/gcc/gcc-10.3.0/gcc-10.3.0.tar.gz" # update to 10.4? ver num is hardcoded in some places
gmp_url="http://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz"
mpc_url="http://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz"
mpfr_url="http://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.gz"

## Default Target
llvm_targets="AArch64;ARM;Mips;PowerPC;RISCV;Sparc;SystemZ;X86"
compile_target="i486-pocket-linux-musl"
linux_arch="i386"
specific_arch="i486"
arch="i486"
libdir="lib"
abi=""
with_aoc=""
sysroot="$toolchain_prefix/$compile_target"
toolchain_bin="$toolchain_prefix/bin"

## Default Configs
kdefconfig="defconfig"
extra_gcc_flags=""
compression="gzip"
