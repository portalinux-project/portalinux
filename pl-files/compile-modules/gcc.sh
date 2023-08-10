# SPDX-License-Identifier: MPL-2.0

. ./common.sh

compile_toolchain(){
	common_flags="$compile_target --disable-multilib"
	gnu_flags="$common_flags $with_aoc --disable-werror --disable-doc"

	# libgcc-static
	if [ ! -r "$toolchain_prefix/lib/gcc/$compile_target/$(_generate_stuff pkg_ver gcc)/libgcc.a" ]; then
		cd "$gcc_dir/build"
		_exec "Compiling libgcc-static" "make -j$threads enable_shared=no all-target-libgcc"
		_exec "Installing libgcc-static" "make install-strip-target-libgcc"
		rm -rf "$sysroot/lib/libc.so"
	fi

	# libc
	_compile_musl "$sysroot"

	# libgcc-shared
	if [ ! -r "$sysroot/$libdir/libgcc_s.so" ]; then
		cd "$gcc_dir/build"
		_exec "Cleaning libgcc" "make -C $compile_target/libgcc distclean"
		_exec "Compiling libgcc-shared" "make enable_shared=yes -j$threads all-target-libgcc"
		_exec "Installing libgcc" "make install-strip-target-libgcc"
	fi

	# libstdc++
	_compile_ac_pkg "$sysroot/$libdir/libstdc++.so" "$gcc_dir" "" "" \
				"Compiling libstdc++" "" \
				"Installing libstdc++" "install-strip-target-libstdc++-v3"

	# pl32lib
	if [ ! -r "$sysroot/lib/libpl32.so" ]; then
		cd "$pl32lib_dir"

		_exec "Configuring pl32lib" "./configure --prefix='$sysroot' CC='$cross_cc' CFLAGS='$cross_cflags -march=$arch -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling pl32lib" "./compile build"
		_exec "Installing pl32lib" "./compile install"
	fi

	# libplml
	if [ ! -r "$sysroot/lib/libplml.so" ]; then
		cd "$libplml_dir"

		_exec "Configuring libplml" "./configure --prefix='$sysroot' CC='$cross_cc' CFLAGS='$cross_cflags -march=$arch -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling libplml" "./compile build"
		_exec "Installing libplml" "./compile install"
	fi

}
