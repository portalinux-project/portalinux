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
		# TODO: compress headers and static libs created by LLVM
	fi

	# musl libc headers
	if [ ! -r "$sysroot/include/stdio.h" ]; then
		cd "$libc_dir"
		_exec "Installing musl headers" "make ARCH=$arch prefix=$sysroot install-headers"
	fi

	# compiler-rt builtins
	if [ ! -r "$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a" ]; then
		cd "$llvm_dir"
		rm -rf "build/builtins"
		_exec "Configuring compiler-rt builtins" "cmake -S ./compiler-rt -B build/builtins $cmake_cross_flags -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
						-DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_ORC=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF \
						-DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON"
		_exec "Compiling compiler-rt builtins" "cmake --build build/builtins -j$threads"
		_exec "Installing compiler-rt builtins" "cmake --install build/builtins --strip"
		# fix linking errors TODO: stop hardcoding LLVM versions
		for i in begin end; do ln -sf "./linux/clang_rt.crt$i-$linux_arch.o" "$sysroot/lib/crt"$i"S.o"; done
		mkdir -p "$toolchain_prefix/lib/clang/14.0.6/lib/linux/"
		ln -sf "../../../../../$compile_target/lib/linux/libclang_rt.builtins-$linux_arch.a" "$toolchain_prefix/lib/clang/14.0.6/lib/linux/libclang_rt.builtins-i386.a"
	fi

	# musl libc
	if [ ! -r "$sysroot/lib/libc.so" ]; then
		cd "$libc_dir"
		_exec "Configuring musl libc" "ARCH=$arch CC='$cross_cc' LIBCC=$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a ./configure --prefix=$sysroot --host=$common_flags"
		_exec "Compiling musl libc" "make -j$threads AR='$toolchain_prefix/bin/llvm-ar' RANLIB='$toolchain_prefix/bin/llvm-ranlib' "
		_exec "Installing musl libc" "make AR='$toolchain_prefix/bin/llvm-ar' RANLIB='$toolchain_prefix/bin/llvm-ranlib' install"
	fi

	# libatomic
	if [ ! -r "$sysroot/lib/linux/libclang_rt.atomic-$linux_arch.so" ]; then
		cd "$llvm_dir"
		rm -rf "build/atomic"
		_exec "Configuring libatomic" "cmake -S ./compiler-rt -B build/atomic $cmake_cross_flags -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
						-DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_ORC=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF \
						-DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON -DCOMPILER_RT_BUILD_STANDALONE_LIBATOMIC=ON"
		_exec "Compiling libatomic" "cmake --build build/atomic -j$threads"
		_exec "Installing libatomic" "cmake --install build/atomic --strip"
		ln -sf "./linux/libclang_rt.atomic-$linux_arch.so" "$sysroot/lib/libatomic.so"
	fi

	# LLVM C++ Runtimes (libunwind, libcxxabi, pstl, and libcxx)
	if [ ! -r "$sysroot/lib/libc++.so" ]; then
		cd "$llvm_dir"
		rm -rf "build/runtimes"
		_exec "Configuring LLVM C++ Runtimes" "cmake -S ./runtimes -B build/runtimes $cmake_cross_flags -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
						-DLLVM_ENABLE_RUNTIMES=libunwind\;libcxxabi\;pstl\;libcxx -DLIBUNWIND_USE_COMPILER_RT=ON -DLIBCXXABI_USE_COMPILER_RT=ON \
						-DLIBCXX_USE_COMPILER_RT=ON -DLIBCXXABI_USE_LLVM_UNWINDER=ON -DLIBCXXABI_HAS_CXA_THREAD_ATEXIT_IMPL=OFF -DLIBCXX_HAS_MUSL_LIBC=ON"
		_exec "Compiling LLVM C++ Runtimes" "cmake --build build/runtimes -j$threads"
		_exec "Installing LLVM C++ Runtimes" "cmake --install build/runtimes --strip"
	fi

	# ncurses
	# _compile_pkg "$sysroot/lib/libncurses.so" "$ncurses_dir" \
	# 			"Configuring Ncurses" "--prefix=$sysroot --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib" \
	# 			"Compiling Ncurses" "" \
	# 			"Installing Ncurses" "install INSTALL_PROG='/usr/bin/env install --strip-program=$compile_target-strip -c -s'"

	# ncursesw
	# if [ -r "$ncurses_dir/build" ]; then
	# 	_exec "Cleaning Ncurses" "rm -rf $ncurses_dir/build"
	# fi
	# _compile_pkg "$sysroot/lib/libncursesw.so" "$ncurses_dir" \
	# 			"Configuring NcursesW" "--prefix=$sysroot --host=$compile_target --with-cxx-shared --with-shared --enable-overwrite --with-termlib --enable-widec" \
	# 			"Compiling NcursesW" "" \
	# 			"Installing NcursesW" "install INSTALL_PROG='/usr/bin/env install --strip-program=$compile_target-strip -c -s'"
}
