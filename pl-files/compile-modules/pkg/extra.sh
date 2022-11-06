compile_extra_pkgs(){
	if [ ! -r "$output_rootfs/usr/bin/pl-install" ]; then
		compile_rootfs
	else
		_get_pkg_names $dist
	fi
	common_flags="--prefix=/opt --host=$compile_target"
	dev_stuff="$common_flags --disable-multilib --with-sysroot=/ --with-build-sysroot=$output_rootfs --with-native-system-header-dir=/opt/include"

	printf "Creating build folders..."
	for i in libstdc++ gcc linux-headers binutils bash make ncurses nano; do
		mkdir -p "$output/$i/files"
		printf "."
	done
	echo "Done"

	# libgcc and libstdc++
	_setup_gcc rfs
	_compile_pkg "$output/libstdc++/files/opt" "$gcc_dir" "Configuring GCC" "$dev_stuff $extra_gcc_flags --disable-bootstrap --disable-libstdcxx-debug --enable-languages=c,c++ --disable-libsanitizer" "Compiling GCC" "" "Packaging GCC C/C++ Compilers" "install-strip-gcc DESTDIR=$output/gcc/files" "Packaging libgcc" "install-strip-target-libgcc DESTDIR=$output/libstdc++/files" "Packaging libstdc++" "install-strip-target-libstdc++-v3 DESTDIR=$output/libstdc++/files"
	rm "$toolchain_prefix/bin/cc" -f
	rm "$toolchain_prefix/bin/c++" -f

	# linux headers
	if [ ! -d "$output/linux-headers/files/opt" ]; then
		cd "$linux_dir"

		_exec "Packaging Linux headers" "make ARCH=$linux_arch INSTALL_HDR_PATH=$output/linux-headers/files/opt headers_install"
	fi

	# binutils
	_compile_pkg "$output/binutils/files/opt" "$binutils_dir" "Configuring Binutils" "$dev_stuff" "Compiling Binutils" "" "Packaging Binutils" "install-strip DESTDIR=$output/binutils/files"

	# bash
	_compile_pkg "$output/bash/files/opt" "$bash_dir" "Configuring GNU Bash" "$common_flags --disable-gnu-malloc" "Compiling GNU Bash" "" "Packaging GNU Bash" "install-strip DESTDIR=$output/bash/files"

	# make
	_compile_pkg "$output/make/files/opt" "$make_dir" "Configuring GNU Make" "$common_flags --without-guile" "Compiling GNU Make" "" "Packaging GNU Make" "install-strip DESTDIR=$output/make/files"

	# ncurses
	_compile_pkg "$output/ncurses/files/opt/lib/libncurses.so" "$ncurses_dir" "Configuring Ncurses" "$common_flags --with-cxx-shared --with-shared --enable-overwrite --with-termlib" "Compiling Ncurses" "" "Packaging Ncurses" "install DESTDIR=$output/ncurses/files INSTALL_PROG='/usr/bin/env install --strip-program=$compile_target-strip -c -s'"
	if [ -r "$ncurses_dir/build" ]; then
		_exec "Cleaning Ncurses" "rm -rf $ncurses_dir/build"
	fi
	_compile_pkg "$output/ncurses/files/opt/lib/libncursesw.so" "$ncurses_dir" "Configuring NcursesW" "$common_flags --with-cxx-shared --with-shared --enable-overwrite --with-termlib --enable-widec" "Compiling NcursesW" "" "Packaging NcursesW" "install DESTDIR=$output/ncurses/files INSTALL_PROG='/usr/bin/env install --strip-program=$compile_target-strip -c -s'"

	# nano
	_compile_pkg "$output/nano/files/opt" "$nano_dir" "Configuring Nano" "$common_flags --enable-tiny --enable-utf8" "Compiling Nano" "" "Installing Nano" "install DESTDIR=$output/ncurses/files"

	_rootfs_cleanup

	printf "Creating packages..."
	for i in $dist-libc-headers libstdc++ gcc linux-headers binutils bash make ncurses nano; do
		cd "$output/$i"
		tar cf files.tar files
		sha256sum files.tar > files.tar.sha256sum
		printf "$i\n$(_generate_stuff pkg_ver $i)\n$arch\n" > pkg_info

		tar cf ../$i.tar files.tar files.tar.sha256sum pkg_info
		bzip2 ../$i.tar
		mv ../$i.tar.bz2 ../$i.plpak
		printf "."
	done
	echo "Done."
}
