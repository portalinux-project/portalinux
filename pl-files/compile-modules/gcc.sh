# SPDX-License-Identifier: GPL-2.0-or-later

_setup_gcc(){
	if [ ! -r "$gcc_dir/mpfr" ]; then
		ln "$gmp_dir" "$gcc_dir/gmp" -s 2>/dev/null || true
		ln "$mpc_dir" "$gcc_dir/mpc" -s 2>/dev/null || true
		ln "$mpfr_dir" "$gcc_dir/mpfr" -s 2>/dev/null || true
	fi

	if [ "$1" = "rfs" ]; then
		ln -s "$toolchain_prefix/bin/$compile_target-gcc" "$toolchain_prefix/bin/cc" 2>/dev/null || true
		ln -s "$toolchain_prefix/bin/$compile_target-g++" "$toolchain_prefix/bin/c++" 2>/dev/null || true
	fi
}

_setup_glibc(){
	mkdir -p "$output_rootfs/opt/include/gnu"
	touch "$output_rootfs/opt/include/gnu/stubs.h"
	touch "$output_rootfs/opt/include/gnu/stubs-32.h"
	touch "$output_rootfs/opt/include/gnu/stubs-64.h"
	if [ "$1" = "tc" ]; then
		$compile_target-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o "$toolchain_prefix/$compile_target/lib/libc.so"
	fi
}

compile_toolchain(){
	extra_flags=""
	common_flags="$compile_target --disable-multilib"
	gnu_flags="$common_flags $with_aoc --disable-werror --disable-doc"
	libc_flags=""
	_get_pkg_names $dist

	# binutils
	_compile_pkg "$toolchain_prefix/bin/$compile_target-as" "$binutils_dir" "Configuring Binutils" "--prefix=$toolchain_prefix --target=$gnu_flags" "Compiling Binutils" "" "Installing Binutils" "install-strip"

	# gcc c/c++ compilers
	_setup_gcc cross
	if [ "$dist" = "musl" ]; then
		extra_flags="--disable-libsanitizer --enable-initfini-array"
	fi
	_compile_pkg "$toolchain_prefix/bin/$compile_target-gcc" "$gcc_dir" "Configuring GCC" "--prefix=$toolchain_prefix --target=$gnu_flags --enable-languages=c,c++ --disable-libstdcxx-debug --disable-bootstrap $extra_flags $extra_gcc_flags" "Compiling GCC C/C++ compilers" "all-gcc" "Installing GCC C/C++ compilers" "install-strip-gcc"

	# linux headers
	if [ ! -r "$toolchain_prefix/$compile_target/include/linux" ]; then
		cd "$linux_dir"
		_exec "Installing Linux headers" "make ARCH=$linux_arch INSTALL_HDR_PATH=$toolchain_prefix/$compile_target headers_install"
	fi

	# libc headers + start files (glibc-only)
	if [ ! -r "$toolchain_prefix/$compile_target/include/stdio.h" ]; then
		cd "$libc_dir"
		if [ "$dist" = "gnu" ]; then
			mkdir -p "build" && cd "build"
			if [ ! -r "$libc_dir/build/Makefile" ]; then
				_exec "Configuring glibc" "../configure --prefix=$toolchain_prefix/$compile_target --host=$gnu_flags --with-headers=$toolchain_prefix/$compile_target/include libc_cv_forced_unwind=yes"
			fi
			_exec "Compiling glibc start files" "make -j$threads csu/subdir_lib CFLAGS_FOR_TARGET='-s -O2' CXXFLAGS_FOR_TARGET='-s -O2'"
			_exec "Installing glibc start files" "install csu/crti.o csu/crtn.o csu/crt1.o '$toolchain_prefix/$compile_target/lib'"
			_exec "Installing glibc headers" "make install-bootstrap-headers=yes install-headers"
		else
			_exec "Installing musl headers" "make ARCH=$arch prefix=$toolchain_prefix/$compile_target install-headers"
		fi
	fi

	# libgcc (libgcc-static for musl)
	if [ ! -r "$toolchain_prefix/lib/gcc/$compile_target/10.3.0/libgcc.a" ]; then
		cd "$gcc_dir/build"
		name="libgcc"
		printf "Preparing to compile libgcc..."
		if [ "$dist" = "gnu" ]; then
			_setup_glibc tc
		else
			name="$name-static"
			extra_flags="enable_shared=no"
		fi
		echo "Done."
		_exec "Compiling $name" "make -j$threads $extra_flags all-target-libgcc"
		_exec "Installing libgcc" "make install-strip-target-libgcc"
		rm -rf "$toolchain_prefix/$compile_target/lib/libc.so"
	fi

	# libc
	if [ ! -r "$toolchain_prefix/$compile_target/lib/libc.so" ]; then
		cd "$libc_dir"
		if [ "$dist" = "gnu" ]; then
			cd "build"
		else
			_exec "Configuring libc" "ARCH=$arch CC=$compile_target-gcc CROSS_COMPILE=$compile_target- LIBCC=$toolchain_prefix/lib/gcc/$compile_target/10.3.0/libgcc.a ./configure --prefix=$toolchain_prefix/$compile_target --host=$common_flags"
		fi

		_exec "Compiling libc" "make -j$threads AR=$compile_target-ar RANLIB=$compile_target-ranlib"
		_exec "Installing libc" "make AR=$compile_target-ar RANLIB=$compile_target-ranlib install"
	fi

	# libgcc-shared (musl-only)
	if [ ! -r "$toolchain_prefix/$compile_target/$libdir/libgcc_s.so" ]; then
		cd "$gcc_dir/build"
		_exec "Cleaning libgcc" "make -C $compile_target/libgcc distclean"
		_exec "Compiling libgcc-shared" "make enable_shared=yes -j$threads all-target-libgcc"
		_exec "Installing libgcc" "make install-strip-target-libgcc"
	fi

	# libstdc++
	_compile_pkg "$toolchain_prefix/$compile_target/$libdir/libstdc++.so" "$gcc_dir" "" "" "Compiling libstdc++" "" "Installing libstdc++" "install-strip-target-libstdc++-v3"

	# ncurses
	_compile_pkg "$toolchain_prefix/$compile_target/lib/libncurses.so" "$ncurses_dir" "Configuring Ncurses" "--prefix=$toolchain_prefix/$compile_target --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib" "Compiling Ncurses" "" "Installing Ncurses" "install INSTALL_PROG='/usr/bin/install --strip-program=$compile_target-strip -c -s'"

	# ncursesw
	if [ -r "$ncurses_dir/build" ]; then
		_exec "Cleaning Ncurses" "rm -rf $ncurses_dir/build"
	fi
	_compile_pkg "$toolchain_prefix/$compile_target/lib/libncursesw.so" "$ncurses_dir" "Configuring NcursesW" "--prefix=$toolchain_prefix/$compile_target --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib --enable-widec" "Compiling NcursesW" "" "Installing NcursesW" "install INSTALL_PROG='/usr/bin/install --strip-program=$compile_target-strip -c -s'"
}
