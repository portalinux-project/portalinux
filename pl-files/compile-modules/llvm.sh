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
set(CMAKE_EXE_LINKER_FLAGS "-fuse-ld=lld --rtlib=compiler-rt")

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
	common_flags="$compile_target --disable-multilib"
	llvm_targets="AArch64;ARM;Mips;PowerPC;RISCV;Sparc;SystemZ;X86"
	cmake_flags="-GNinja -DCMAKE_BUILD_TYPE=MinSizeRel"
	cmake_cross_flags="$cmake_flags -DCMAKE_INSTALL_PREFIX='$sysroot' -DCMAKE_TOOLCHAIN_FILE='$sysroot/cross_clang.cmake' "
	cross_cc="'$toolchain_prefix/bin/clang' --gcc-toolchain='' --target=$compile_target --sysroot='$sysroot' -fuse-ld='$toolchain_prefix/bin/ld.lld' --rtlib=compiler-rt"

	_get_pkg_names $dist
	_generate_llvm_wrappers

	# linux headers
	if [ ! -r "$sysroot/include/linux" ]; then
		cd "$linux_dir"
		if ! [ -x "$(command -v clang)" ]; then LLVM=""; fi
		_exec "Installing Linux headers" "make ARCH=$linux_arch INSTALL_HDR_PATH='$sysroot' headers_install"
	fi

	# LLVM C/C++ compilers
	if [ ! -r "$toolchain_prefix/bin/clang" ]; then
		cd "$llvm_dir"
		_exec "Configuring LLVM" "cmake -S ./llvm -B build/toolchain $cmake_flags -DCMAKE_INSTALL_PREFIX='$toolchain_prefix' -DLLVM_TARGETS_TO_BUILD='$llvm_targets' \
						-DLLVM_LINK_LLVM_DYLIB=on -DCLANG_LINK_CLANG_DYLIB=on -DLLVM_ENABLE_PROJECTS=clang\;lld -DLLVM_ENABLE_RUNTIMES='' -DLLVM_HAVE_LIBXAR=0"
		_exec "Compiling LLVM...\n" "cmake --build build/toolchain -j$threads" no-silent
		_exec "Installing LLVM" "cmake --install build/toolchain --strip"
	fi

	# libc headers
	if [ ! -r "$sysroot/include/stdio.h" ]; then
		cd "$libc_dir"
		_exec "Installing musl headers" "make ARCH=$arch prefix=$sysroot install-headers"
	fi

	# compiler-rt builtins
	if [ ! -r "$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a" ]; then
		cd "$llvm_dir"
		rm -rf "build/builtins"
		_exec "Configuring compiler-rt builtins" "cmake -S ./runtimes -B build/builtins $cmake_cross_flags -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
						-DLLVM_ENABLE_RUNTIMES=compiler-rt -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_ORC=OFF \
						-DCOMPILER_RT_BUILD_PROFILE=OFF -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON"
		_exec "Compiling compiler-rt builtins...\n" "cmake --build build/builtins -j$threads" no-silent
		_exec "Installing LLVM" "cmake --install build/builtins --strip"
	fi

	# libc
	if [ ! -r "$sysroot/lib/libc.so" ]; then
		cd "$libc_dir"
		_exec "Configuring musl libc" "ARCH=$arch CC='$cross_cc' LIBCC=$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a ./configure --prefix=$sysroot --host=$common_flags"
		_exec "Compiling musl libc" "make -j$threads AR='$toolchain_prefix/bin/llvm-ar' RANLIB='$toolchain_prefix/bin/llvm-ranlib' "
		_exec "Installing musl libc" "make AR='$toolchain_prefix/bin/llvm-ar' RANLIB='$toolchain_prefix/bin/llvm-ranlib' install"
	fi

	# # libgcc-shared (musl-only)
	# if [ ! -r "$sysroot/$libdir/libgcc_s.so" ]; then
	# 	cd "$gcc_dir/build"
	# 	_exec "Cleaning libgcc" "make -C $compile_target/libgcc distclean"
	# 	_exec "Compiling libgcc-shared" "make enable_shared=yes -j$threads all-target-libgcc"
	# 	_exec "Installing libgcc" "make install-strip-target-libgcc"
	# fi

	# # libstdc++
	# _compile_pkg "$sysroot/$libdir/libstdc++.so" "$gcc_dir" "" "" \
	# 			"Compiling libstdc++" "" \
	# 			"Installing libstdc++" "install-strip-target-libstdc++-v3"

	# # ncurses
	# _compile_pkg "$sysroot/lib/libncurses.so" "$ncurses_dir" \
	# 			"Configuring Ncurses" "--prefix=$sysroot --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib" \
	# 			"Compiling Ncurses" "" \
	# 			"Installing Ncurses" "install INSTALL_PROG='/usr/bin/env install --strip-program=$compile_target-strip -c -s'"

	# # ncursesw
	# if [ -r "$ncurses_dir/build" ]; then
	# 	_exec "Cleaning Ncurses" "rm -rf $ncurses_dir/build"
	# fi
	# _compile_pkg "$sysroot/lib/libncursesw.so" "$ncurses_dir" \
	# 			"Configuring NcursesW" "--prefix=$sysroot --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib --enable-widec" \
	# 			"Compiling NcursesW" "" \
	# 			"Installing NcursesW" "install INSTALL_PROG='/usr/bin/env install --strip-program=$compile_target-strip -c -s'"
}
