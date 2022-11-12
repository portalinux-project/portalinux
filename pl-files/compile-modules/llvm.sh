# SPDX-License-Identifier: GPL-2.0-or-later

_generate_llvm_wrappers(){
	mkdir -p "$sysroot"
	cat <<EOF > "$sysroot/cross_clang.cmake"
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR "$arch")
set(CMAKE_SYSROOT "$sysroot")

set(triple "$compile_target")
set(CMAKE_ASM_COMPILER_TARGET \${triple})
set(CMAKE_C_COMPILER_TARGET \${triple})
set(CMAKE_CXX_COMPILER_TARGET \${triple})
set(CMAKE_EXE_LINKER_FLAGS "--ld-path='$toolchain_prefix/bin/ld.lld' --rtlib=compiler-rt")
set(CMAKE_SHARED_LINKER_FLAGS \${CMAKE_EXE_LINKER_FLAGS})

set(CMAKE_C_COMPILER "$toolchain_prefix/bin/clang")
set(CMAKE_CXX_COMPILER "$toolchain_prefix/bin/clang++")
set(CMAKE_NM "$toolchain_prefix/bin/llvm-nm")
set(CMAKE_AR "$toolchain_prefix/bin/llvm-ar")
set(CMAKE_RANLIB "$toolchain_prefix/bin/llvm-ranlib")


# these variables tell CMake to avoid using any binary it finds in
# the sysroot, while picking headers and libraries exclusively from it
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF
}

compile_toolchain(){
	cmake_cross_flags="CMAKE_TOOLCHAIN_FILE='$sysroot/cross_clang.cmake' "
	cmake_bs_flags="$cmake_cross_flags CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"
	compiler_rt_flags="$cmake_bs_flags COMPILER_RT_BUILD_LIBFUZZER=0 COMPILER_RT_BUILD_MEMPROF=0 COMPILER_RT_BUILD_ORC=0 COMPILER_RT_BUILD_PROFILE=0 \
					COMPILER_RT_BUILD_SANITIZERS=0 COMPILER_RT_BUILD_XRAY=0 COMPILER_RT_DEFAULT_TARGET_ONLY=1"

	cross_cc="'$toolchain_prefix/bin/clang' --gcc-toolchain='' --target=$compile_target --sysroot='$sysroot' -fuse-ld='$toolchain_prefix/bin/ld.lld' --rtlib=compiler-rt"
	toolchain_bin="$toolchain_prefix/bin/"

	_get_pkg_names $dist
	_generate_llvm_wrappers


	# LLVM C/C++ compilers
	_compile_cmake_pkg "$toolchain_prefix/bin/clang" "$llvm_dir" llvm "toolchain" "$toolchain_prefix" \
					"LLVM_TARGETS_TO_BUILD='$llvm_targets' BUILD_SHARED_LIBS=1 LLVM_ENABLE_PROJECTS='clang;lld' LLVM_HAVE_LIBXAR=0" \
					"LLVM Toolchain" no-clean no-silent
	#rm -rf "$toolchain_prefix/include" "$toolchain_prefix/lib/"*".a"

	# linux headers
	if [ ! -r "$sysroot/include/linux" ]; then
		cd "$linux_dir"
		if ! [ -x "$(command -v clang)" ]; then LLVM=""; fi
		_exec "Installing Linux headers" "make ARCH=$linux_arch INSTALL_HDR_PATH='$sysroot' headers_install"
	fi

	# musl libc headers
	if [ ! -r "$sysroot/include/stdio.h" ]; then
		cd "$libc_dir"
		_exec "Installing musl headers" "make ARCH=$arch prefix=$sysroot install-headers"
	fi

	# compiler-rt builtins
	_compile_cmake_pkg "$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a" "$llvm_dir" compiler-rt "builtins" "$sysroot"	"$compiler_rt_flags" "compiler-rt builtins"
		# fix linking errors
	for i in begin end; do ln -sf "./linux/clang_rt.crt$i-$linux_arch.o" "$sysroot/lib/crt"$i"S.o"; done
	mkdir -p "$toolchain_prefix/lib/clang/$(_generate_stuff pkg_ver llvm)/lib/linux/"
	ln -sf "../../../../../$compile_target/lib/linux/libclang_rt.builtins-$linux_arch.a" "$toolchain_prefix/lib/clang/$(_generate_stuff pkg_ver llvm)/lib/linux/libclang_rt.builtins-$linux_arch.a"

	# musl libc
	if [ ! -r "$sysroot/lib/libc.so" ]; then
		cd "$libc_dir"
		_exec "Configuring musl libc" "ARCH=$arch CC='$cross_cc' LIBCC=$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a ./configure --prefix=$sysroot -isable-multilib --host=$compile_target"
		_exec "Compiling musl libc" "make -j$threads AR='$toolchain_prefix/bin/llvm-ar' RANLIB='$toolchain_prefix/bin/llvm-ranlib' "
		_exec "Installing musl libc" "make AR='$toolchain_prefix/bin/llvm-ar' RANLIB='$toolchain_prefix/bin/llvm-ranlib' install"
	fi

	# libatomic
	_compile_cmake_pkg "$sysroot/lib/linux/libclang_rt.atomic-$linux_arch.so" "$llvm_dir" compiler-rt "atomic" "$sysroot"	"$compiler_rt_flags COMPILER_RT_BUILD_STANDALONE_LIBATOMIC=1" "libatomic"
	ln -sf "./linux/libclang_rt.atomic-$linux_arch.so" "$sysroot/lib/libatomic.so"

	# LLVM C++ Runtimes (libunwind, libcxxabi, pstl, and libcxx)
	_compile_cmake_pkg "$sysroot/lib/libc++.so" "$llvm_dir" runtimes "runtimes" "$sysroot" \
					"$cmake_bs_flags LLVM_ENABLE_RUNTIMES='libunwind;libcxxabi;pstl;libcxx' LIBUNWIND_USE_COMPILER_RT=1 LIBCXXABI_USE_COMPILER_RT=1 LIBCXX_USE_COMPILER_RT=1 \
					LIBCXXABI_USE_LLVM_UNWINDER=1 LIBCXXABI_HAS_CXA_THREAD_ATEXIT_IMPL=0 LIBCXX_HAS_MUSL_LIBC=1" "LLVM C++ Runtimes"

	# ncurses
	# _compile_ac_pkg "$sysroot/lib/libncurses.so" "$ncurses_dir" \
	# 			"Configuring Ncurses" "--prefix=$sysroot --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib" \
	# 			"Compiling Ncurses" "" \
	# 			"Installing Ncurses" "install INSTALL_PROG='/usr/bin/env install --strip-program='$toolchain_prefix/bin/llvm-strip' -c -s'"

	# ncursesw
	# if [ -r "$ncurses_dir/build" ]; then
	# 	_exec "Cleaning Ncurses" "rm -rf $ncurses_dir/build"
	# fi
	# _compile_ac_pkg "$sysroot/lib/libncursesw.so" "$ncurses_dir" \
	# 			"Configuring NcursesW" "--prefix=$sysroot --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib --enable-widec" \
	# 			"Compiling NcursesW" "" \
	# 			"Installing NcursesW" "install INSTALL_PROG='/usr/bin/env install --strip-program='$toolchain_prefix/bin/llvm-strip' -c -s'"
}
