#!/bin/sh
set -e
PATH=$HOME/cross/bin:$PATH

compile_toolchain(){
	# musl headers
	if [ ! -r "$HOME/cross/i486-pocket-linux-musl/include" ]; then
		cd musl-1.2.3
		make ARCH=i386 prefix=$HOME/cross/i486-pocket-linux-musl install-headers
		cd ..
	fi

	# binutils
	if [ ! -r "$HOME/cross/bin/i486-pocket-linux-musl-as" ]; then
		cd binutils-2.36
		mkdir -p build
		cd build
		../configure --prefix=$HOME/cross --target=i486-pocket-linux-musl --disable-multilib --disable-werror
		make -j4
		make install-strip
		cd ../..
	fi

	# gcc compilers + libgcc static lib
	if [ ! -r "$HOME/cross/lib/gcc/i486-pocket-linux-musl/10.3.0/libgcc.a" ]; then
		if [ ! -f gcc-10.3.0/mpfr ]; then
			set +e
			ln $(pwd)/gmp-6.2.1 gcc-10.3.0/gmp -s
			ln $(pwd)/mpc-1.2.1 gcc-10.3.0/mpc -s
			ln $(pwd)/mpfr-4.1.0 gcc-10.3.0/mpfr -s
			set -e
		fi
		cd gcc-10.3.0
		mkdir -p build
		cd build
		../configure --prefix=$HOME/cross --target=i486-pocket-linux-musl --disable-multilib --disable-bootstrap --disable-libsanitizer --enable-initfini-array --with-arch=i686 --with-tune=generic --enable-languages=c,c++
		make -j4 all-gcc
		make -j4 enable_shared=no all-target-libgcc
		make install-strip-gcc
		make install-strip-target-libgcc
		cd ../..
	fi

	# musl libc
	if [ ! -r "$HOME/cross/i486-pocket-linux-musl/lib/libc.so" ]; then
		cd musl-1.2.3
		ARCH=i686 CC=i486-pocket-linux-musl-gcc CROSS_COMPILE=i486-pocket-linux-musl- LIBCC=$HOME/cross/lib/gcc/i486-pocket-linux-musl/10.3.0/libgcc.a ./configure --host=i486-pocket-linux-musl --disable-multilib --prefix=~/cross/i486-pocket-linux-musl
		make -j4 AR=i486-pocket-linux-musl-ar RANLIB=i486-pocket-linux-musl-ranlib
		make AR=i486-pocket-linux-musl-ar RANLIB=i486-pocket-linux-ranlib install
		cd ..
	fi

	# libgcc shared lib
	if [ ! -r "$HOME/cross/i486-pocket-linux-musl/lib/libgcc_s.so" ]; then
		cd gcc-10.3.0/build
		make -C i486-pocket-linux-musl/libgcc distclean
		make enable_shared=yes all-target-libgcc
		make install-strip-target-libgcc
		cd ../..
	fi

	# linux headers
	if [ ! -r "$HOME/cross/i486-pocket-linux-musl/include/linux" ]; then
		cd linux-5.16.10
		make ARCH=i386 INSTALL_HDR_PATH=$HOME/cross/i486-pocket-linux-musl headers_install
		cd ..
	fi

	# libstdc++
	if [ ! -r "$HOME/cross/i486-pocket-linux-musl/lib/libstdc++.so" ]; then
		cd gcc-10.3.0/build
		make -j4
		make install-strip
	fi
}

compile_toolchain
