#!/usr/bin/make
MAKEPATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.SILENT:
.PHONY: all clean init

all: build/compiled/vmlinuz build/compiled/initrfs.cpio.xz build/compiled/system.sb

init:
	if [ $(shell $(MAKEPATH)scripts/shell-check $(RPATH); echo $$?) -ne 0 ]; then \
		echo "Error: Current directory is not Makefile directory"; \
		exit 1; \
	fi

	mkdir -p build


build/compiled/vmlinuz: init
	com
