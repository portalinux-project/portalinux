#!/usr/bin/make
MAKEPATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ARCH := $(shell uname -m)

.SILENT:
.PHONY: all clean init

all: build/compiled/vmlinuz64 build/compiled/initrfs.cpio.xz build/compiled/system.sb

init:
	if [ $(shell $(MAKEPATH)scripts/shell-check $(MAKEPATH)) -ne 0 ]; then \
		echo "Error: Current directory is not Makefile directory"; \
		exit 1; \
	fi

	mkdir -p build/compiled

build/tarballs/.done: init
	cd build && ../scripts/get-deps
	touch build/tarballs/.done

build/workdir/.done: build/tarballs/.done
	cd build/tarballs && ../../scripts/decompress-all
	rm build/tarballs/*.tar
	mv build/tarballs build/workdir
	ln -s $(MAKEPATH)/build/workdir $(MAKEPATH)/build/tarballs
	touch build/workdir/.done

build/compiled/vmlinuz32: build/workdir/.done
	scripts/compile -f configs/linux32.config -d build/workdir/linux-5.13.12 $(MAKE)
	mv build/compiled/bzImage build/compiled/vmlinuz32

build/compiled/vmlinuz64: build/workdir/.done
	scripts/compile -f configs/linux64.config -d build/workdir/linux-5.13.12 $(MAKE)
	mv build/compiled/bzImage build/compiled/vmlinuz64

build/compiled/cross-toolchain/bin/$(ARCH)-pocket-linux-gnu-gcc: build/workdir/.done
	scripts/create-toolchain $(MAKE) $(ARCH) --cross

build/compiled/native-toolchain/bin/gcc: build/compile/toolchain/bin/$(ARCH)-pocket-linux-gnu-gcc
	scripts/create-toolchain $(MAKE) $(ARCH) --native

build/compiled/busybox: build/compiled/toolchain/bin/$(ARCH)-pocket-linux-gnu-gcc
	scripts/compile -f configs/initrfs-busybox.config -d build/workdir/busybox-1.31.1 $(MAKE)
	mv build/workdir/busybox-1.31.1/busybox build/compiled/
	scripts/compile -f configs/main-busybox.config -d build/workdir/busybox-1.31.1 $(MAKE)

build/compiled/initrfs.cpio.xz: build/compiled/busybox
	mkdir -p build/compiled/initrfs/bin
	mv build/compiled/initrfs-busybox build/compiled/initrfs/bin
	for i in ls cat grep echo printf poweroff ; do \
		ln -s /bin/busybox build/compiled/initrfs/bin/$i; \
	done

build/compiled/rootfs/bin/sh: build/compiled/busybox
	mkdir -p build/compiled/rootfs/bin
	cd build/compiled/rootfs; \
	mkdir -p sbin usr/bin usr/sbin lib etc dev proc sys var run; \
	mv ../busybox bin; \
	for i in $(bin/busybox | tail -$(expr $(bin/busybox | wc -l) - $(bin/busybox | grep "Currently defined functions" -n | cut -d: -f1)) | tr "," "\n"); do \
		 ln -s /bin/busybox bin/$i; \
	done

build/compiled/system.sb: build/compiled/rootfs/bin/sh

build/compiled/compiler.sb: build/compiled/native-toolchain/bin/gcc

clean:
	rm -rf build
