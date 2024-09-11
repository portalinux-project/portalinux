#!/bin/sh
set -e

TOOLCHAIN_DIR="$HOME/cross_test"
OLD_PATH="$PATH"

GCC_ARCH_LIST="i486 i586 i686 x86_64 armv5"
export PATH="$TOOLCHAIN_DIR/gcc/bin:$OLD_PATH"

# cleanup from previous runs
#rm -rf "$TOOLCHAIN_DIR/gcc/output"
#rm -rf "$TOOLCHAIN_DIR/gcc/logs"

# GCC tests
for arch in $GCC_ARCH_LIST
do
	# toolchain
	./configure.rb -p gcc -t "$TOOLCHAIN_DIR" -a $arch
	./build.rb -b toolchain
	./build.rb -b toolchain # try this a second time to make sure the lib64
	                          # bug never resurfaces

	# rootfs
	mkdir -p "$TOOLCHAIN_DIR/gcc/output"
	./build.rb -b rootfs
	mv output "$TOOLCHAIN_DIR/gcc/output/$arch"

	# logs
	mkdir -p "$TOOLCHAIN_DIR/gcc/logs"
	mv logs "$TOOLCHAIN_DIR/gcc/logs/$arch"

	./build.rb -c 3
	rm -rf build/
done

LLVM_ARCH_LIST="i486 i586 i686 x86_64 armv6 armv7 aarch64 riscv64"
export PATH="$TOOLCHAIN_DIR/llvm/bin:$OLD_PATH"
# LLVM tests
for arch in $LLVM_ARCH_LIST
do
	# toolchain
	./configure.rb -p llvm -t "$TOOLCHAIN_DIR" -a $arch
	./build.rb -b toolchain
	./build.rb -b toolchain # try this a second time to make sure the lib64
	                          # bug never resurfaces

	# rootfs
	mkdir -p "$TOOLCHAIN_DIR/llvm/output"
	./build.rb -b rootfs
	mv output "$TOOLCHAIN_DIR/llvm/output/$arch"

	# logs
	mkdir -p "$TOOLCHAIN_DIR/llvm/logs"
	mv logs "$TOOLCHAIN_DIR/llvm/logs/$arch"

	./build.rb -c 3
	rm -rf build/
done
