#!/bin/sh

# pl-rt installation
if [ ! -f /usr/lib/libplrt.so ]; then
	if [ ! -d pl-rt-main ]; then
		curl https://codeload.github.com/portalinux-project/pl-rt/tar.gz/refs/heads/main -o - | gzip -dc | tar xv
	fi
	cd pl-rt-main
	./configure --prefix="/usr"
	./compile build
	sudo ./compile install
	cd .. && rm -rf pl-rt-main
fi

# compile and install plml ruby bindings
gem build plml.gemspec
gem install plml
