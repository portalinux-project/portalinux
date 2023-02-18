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
toybox_url="http://landley.net/toybox/downloads/toybox-0.8.8.tar.gz"
bash_url="http://ftp.gnu.org/gnu/bash/bash-5.1.tar.gz"
make_url="http://ftp.gnu.org/gnu/make/make-4.3.tar.gz" # update to 4.4?
python_url="https://www.python.org/ftp/python/3.10.8/Python-3.10.8.tar.xz"
nano_url="http://ftp.gnu.org/gnu/nano/nano-6.2.tar.gz"
ncurses_url="http://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz"
grub_url="https://ftp.gnu.org/gnu/grub/grub-2.06.tar.xz"
xserver_url="https://www.x.org/releases/individual/xserver/xorg-server-1.20.14.tar.xz"
bison_url="http://ftp.gnu.org/gnu/bison/bison-3.7.6.tar.gz"
pl32lib_url="https://github.com/pocketlinux32/pl32lib-ng/archive/refs/tags/v1.02-ng.tar.gz"
libplml_url="https://github.com/pocketlinux32/libplml/archive/refs/tags/v0.01.tar.gz"
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
grub_platform="efi"
abi=""
with_aoc=""
sysroot="$toolchain_prefix/$compile_target"
toolchain_bin="$toolchain_prefix/bin"

## Default Configs
kdefconfig="defconfig"
extra_gcc_flags=""
compression="gzip"
