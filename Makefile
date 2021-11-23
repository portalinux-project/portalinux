#!/usr/bin/make
MAKEPATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
WGETOPTS := "-q"

.SILENT:
.PHONY: all clean init

all: build/compiled/vmlinuz64 build/compiled/initrfs.cpio.xz #build/compiled/system.sb

init:
	if [ $(shell $(MAKEPATH)scripts/shell-check $(MAKEPATH)) -ne 0 ]; then \
		echo "Error: Current directory is not Makefile directory"; \
		exit 1; \
	fi

	mkdir -p build/compiled

build/tarballs/.done: init
	cd build; ../scripts/get-deps $(WGETOPTS)
	touch build/tarballs/.done

build/workdir/.done: build/tarballs/.done
	cd build/tarballs; ../../scripts/decompress-all;
	rm build/tarballs/*.tar;
	mv build/tarballs build/workdir
	touch build/workdir/.done

build/compiled/vmlinuz32: build/workdir/.done
	scripts/compile -f configs/linux32.config -d build/workdir/linux-5.13.12
	mv build/compiled/bzImage build/compiled/vmlinuz32

build/compiled/vmlinuz64: build/workdir/.done
	scripts/compile -f configs/linux64.config -d build/workdir/linux-5.13.12
	mv build/compiled/bzImage build/compiled/vmlinuz64

build/compiled/initrfs.cpio.xz: build/workdir/.done
	mkdir -p build/compiled/initrfs/bin
	scripts/compile -f configs/initrfs-busybox.config -d build/workdir/busybox-1.31.1
	for i in ls cat grep echo printf poweroff ; do \
		ln -s /bin/busybox build/compiled/initrfs/bin/$i; \
	done

clean:
	rm -rf build
