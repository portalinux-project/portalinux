# SPDX-License-Identifier: MPL-2.0

build="$pldir/build"
output="$pldir/output"
output_rootfs="$output/rootfs"
toolchain_prefix="$(echo ~/cross)"
logfile="$pldir/log.txt"
compression="gzip"
compile_target="i486-pocket-linux-musl"
linux_arch="i386"
specific_arch="i486"
arch="i486"
libdir="lib"
abi=""
with_aoc=""
sysroot="$toolchain_prefix/$compile_target"
toolchain_bin="$toolchain_prefix/bin"
pldir="$(dirname $(realpath $0))"
plfiles="$pldir/pl-files"
threads=$(nproc)

_exit_handler(){
	exit_num=$?

	if [ $exit_num -ne 0 ]; then
		if [ $exit_num -eq 130 ]; then
			echo "Interrupt!"
		else
			printf "\nSomething wrong happened. Please check $(basename $logfile) or the output above for more info.\n"
		fi
	fi

	exit $exit_num
}

_exec(){
	set +e
	printf "$1..."
	if [ "$4" = "no-silent" ] || [ "$3" = "no-silent" ]; then
		script -qeac "$2" "$logfile"
	else
		script -qeac "$2 2>&1" "$logfile" >/dev/null
	fi
	errno=$?
	if [ $errno -ne 0 ]; then
		echo "Error!"
		if [ "$3" != "" ]; then
			$3
		fi
		exit $errno
	fi
	echo "Done."
	set -e
}

_compiler_check(){
	if [ "$LLVM" != "" ]; then
		cross_cc="$toolchain_bin/clang"
		cross_cflags="--target=$compile_target --sysroot=$sysroot"
		kbuild_flags="HOSTCC='cc' HOSTLD='ld' LLVM='$toolchain_bin' "

		printf "WARNING: LLVM PortaLinux is experimental, and currently only tested and supported on i486-musl. extra-pkgs are currently not supported on LLVM.\n\n"
	else
		cross_cc="$toolchain_bin/$compile_target-gcc"
	fi
}

_compile_ac_pkg(){
	if [ ! -r "$1" ]; then
		cd "$2"
		if [ ! -r "$2/Makefile" ]; then
			mkdir -p "build" && cd "build"
		fi

		if [ ! -r "./Makefile" ] || [ "$exec_conf" = "y" ]; then
			if [ "$dir" = "" ]; then
				dir=".."
			fi
			PATH="$toolchain_bin:$PATH" _exec "$3" "$dir/configure $4"
		fi

		while [ $# -gt 4 ]; do
			PATH="$toolchain_bin:$PATH" _exec "$5" "make -j$threads $6"
			shift 2
		done
	fi
}

#_compile_cmake_pkg 1)fileToCheckIfExists 2)mainProjectDir 3)projectToConfig 4)buildSubDir(optional)
#                   5)installPrefix 6)cmakeArgs 7)projectName 8)noCleanBuildDir(optional) 9)noSilentBuild(optional)
_compile_cmake_pkg(){
	if [ ! -r "$1" ]; then
		cd "$2"
		if [ "$8" = "" ]; then
			rm -rf "build/$4"
		fi

		# arg parser
		_args=""
		for i in $6; do
			_args="$_args -D$i"
		done

		# configure the project
		_exec "Configuring $7"			"cmake -S './$3' -B 'build/$4' -GNinja -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_INSTALL_PREFIX='$5' $_args"
		if [ "$9" = "" ]; then
			_exec "Compiling $7"		"cmake --build 'build/$4' -j$threads"
		else
			_exec "Compiling $7...\n"	"cmake --build 'build/$4' -j$threads" no-silent
		fi
		_exec "Installing $7"			"cmake --install 'build/$4' --strip"
	fi
}

_generate_stuff(){
	case $1 in
		"musl")
			if [ "$arch" != "aarch64" ]; then
				echo $linux_arch
			else
				echo "aarch64"
			fi
			;;
		"pkg_ver")
			set +e
			pkg=$2
			if [ "$2" = "libc-headers" ]; then
				pkg="musl"
			elif [ "$2" = "libstdc++" ]; then
				pkg="gcc"
			elif [ "$2" = "linux-headers" ]; then
				pkg="linux"
			fi
			set -e

			pkg_dir=$(ls $build | grep "$pkg")
			echo "$pkg_dir" | rev | cut -d- -f1 | rev
			;;
		"libdir")
			set +e
			if [ $(echo "$arch" | grep -c 64) -ne 0 ]; then
				libdir="lib64"
			fi
			set -e
			;;
	esac
}

_pl_clean(){
	set +e
	mode=2

	if [ "$1" != "" ]; then
		mode="$1"
	fi

	if [ $mode -lt 4 ]; then
		for i in $(ls "$build"); do
			printf "Cleaning $i..."
			if [ -d "$build/$i/build" ]; then
				if [ $mode -eq 1 ]; then
					cd "$build/$i/build"
					make -s clean >/dev/null 2>&1
					shift
				else
					rm -rf "$build/$i/build"
				fi
			elif [ -r "$build/$i/Makefile" ]; then
				cd "$build/$i"
				make -s clean >/dev/null 2>&1
				make -s distclean >/dev/null 2>&1
			elif [ -r "$build/$i/compile" ] && [ ! -r "$build/$i/configure.ac" ]; then
				cd "$build/$i"
				./compile clean >/dev/null
			fi
			echo "Done."
		done

		if [ $mode -gt 2 ]; then
			printf "Deleting output directory..."
			rm -rf "$output"
			echo "Done."
			shift
		fi
		rm -f "$logfile"
	else
		rm -rfv "$build" "$output" "$logfile"
		if [ $(echo "$2" | grep "no-rm-t" -c) -ne 0 ]; then
			shift
		else
			rm -rfv "$pldir/tarballs"
		fi
	fi
}


_compile_musl(){
	if [ "$3" = "rootfs" ]; then
		install_dir="$output_rootfs/"
	else
		install_dir=""
	fi

	if [ ! -r "$install_dir$1/lib/libc.so" ]; then
		cd "$libc_dir"
		libcc="$sysroot/lib/linux/libclang_rt.builtins-$linux_arch.a"
		ar="$toolchain_bin/llvm-ar"
		ranlib="$toolchain_bin/llvm-ranlib"

		if [ "$LLVM" = "" ]; then
			libcc="$toolchain_prefix/lib/gcc/$compile_target/$(_generate_stuff pkg_ver gcc)/libgcc.a"
			ar="$toolchain_bin/$compile_target-ar"
			ranlib="$toolchain_bin/$compile_target-ranlib"
		fi

		_exec "Configuring musl libc" "ARCH=$(_generate_stuff) LIBCC='$libcc' CC='$cross_cc $cross_cflags $cross_ldflags' ./configure --prefix='$1' --disable-multilib --host=$compile_target $2"
		_exec "Compiling musl libc" "make -j$threads AR='$ar' RANLIB='$ranlib'"
		_exec "Installing musl libc" "make AR='$ar' RANLIB='$ranlib' DESTDIR='$install_dir' install"
	fi
}
