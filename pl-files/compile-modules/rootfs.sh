# SPDX-License-Identifier: GPL-2.0-or-later

_rootfs_cleanup(){
	printf "Deleting unnecessary files..."
	for i in $(find "$output_rootfs/opt" -type f); do
		rm -f "$i"
		printf "."
	done
	rm -rf "$output_rootfs/opt/*"
	echo "Done."
}

compile_rootfs(){
	if [ ! -r "$toolchain_prefix/bin/$compile_target-gcc" ]; then
		echo "Error: You do not have the compiler for system $compile_target installed. Please run $0 --build toolchain and try again"
		exit 1
	fi
	common_flags="--with-sysroot=/ --host=$compile_target --datarootdir=/opt/share --includedir=/opt/include"
	included_comp="--prefix=/usr $common_flags"
	main_comp="$included_comp --disable-multilib"
	_get_pkg_names $dist

	printf "Creating rootfs structure..."
	for i in bin dev sys proc lib opt sbin usr/bin usr/lib usr/sbin root mnt home tmp var; do
		mkdir -p "$output_rootfs/$i"
		printf "."
	done
	echo "Done."

	if [ ! -r "$output_rootfs/usr/lib/libc.a" ]; then
		cd "$libc_dir"
		if [ "$dist" = "gnu" ]; then
			mkdir -p "build" && cd "build"
			if [ ! -r "$libc_dir/build/Makefile" ]; then
				_exec "Configuring glibc" "../configure $main_comp libc_cv_forced_unwind=yes CFLAGS='-s -O2' CXXFLAGS='-s -O2'"
			fi

			_exec "Preparing for compilation" "_setup_gcc"
		else
			_exec "Configuring musl" "./configure $main_comp"
		fi

		_exec "Compiling libc" "make -j$threads"
		_exec "Installing libc" "make DESTDIR=$output_rootfs install"
		printf "Packaging libc headers..."
		mkdir -p "$output/$dist-libc-headers/files/opt"
		cp -r "$output_rootfs/opt/include" "$output/$dist-libc-headers/files/opt"
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/bin/$(basename $(echo $coreutils_dir | cut -d- -f1))" ]; then
		cd "$coreutils_dir"

		printf "Configuring Coreutils..."
		script -qeac "make defconfig 2>&1" "$logfile" >/dev/null
		if [ $(echo $coreutils_dir | grep "toybox") ]; then
			printf "CONFIG_SH=y\nCONFIG_DD=y\nCONFIG_EXPR=y\nCONFIG_INIT=y\nCONFIG_GETTY=y\nCONFIG_MDEV=y\n" >> .config
		fi
		echo "Done."
		_exec "Compiling Coreutils" "make CROSS_COMPILE=$toolchain_prefix/bin/$compile_target- CC=gcc -j$threads"
		printf "Installing Coreutils..."
		mv *box "$output_rootfs/bin"
		ln -s "/bin/$(basename $(echo $coreutils_dir | cut -d- -f1))" "$output_rootfs/bin/sh" 2>/dev/null || true
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/init" ]; then
		printf "Installing init script..."
		cp "$plfiles/initramfs-init" "$output_rootfs/init"
		chmod 777 "$output_rootfs/init"
		if [ -f "$output_rootfs/bin/toybox" ]; then
			sed -i 's/PUT_DYN_SYMLINK_TO_BOX_HERE/for i in $(toybox --long); do toybox ln -s \/bin\/toybox \/$i 2>\/dev\/null; done/g' "$output_rootfs/init"
			sed -i 's/BOX/toybox/g' "$output_rootfs/init"
		else
			sed -i 's/PUT_DYN_SYMLINK_TO_BOX_HERE/\/bin\/busybox --install -s/g' "$output_rootfs/init"
			sed -i 's/BOX/busybox/g' "$output_rootfs/init"
		fi
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/etc" ]; then
		printf "Installing etc files..."
		cp -r "$plfiles/etc" "$output_rootfs"
		chmod 777 "$output_rootfs/etc/init.d/rcS"
		if [ "$dist" = "musl" ]; then
			mv "$output_rootfs/etc/ld.so.conf" "$output_rootfs/etc/ld-musl-$(_generate_stuff musl).path"
		fi
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/usr/bin/pl-setup" ]; then
		printf "Installing PortaLinux Package Installer & Setup..."
		cp "$plfiles/pl-utils/pl-install" "$output_rootfs/usr/bin"
		chmod 777 "$output_rootfs/usr/bin/pl-install"
		cp "$plfiles/pl-utils/pl-setup" "$output_rootfs/usr/bin"
		chmod 777 "$output_rootfs/usr/bin/pl-setup"
		echo "Done."
	fi
}

create_boot_image(){
	_rootfs_cleanup

	if [ $(id -u) -ne 0 ]; then
		echo "Error: You are not root"
		exit 3
	fi

	printf "Creating necessary device nodes..."
	mknod "$output_rootfs/dev/console" c 5 1 2>/dev/null || true
	mknod "$output_rootfs/dev/tty" c 5 0 2>/dev/null || true
	mknod "$output_rootfs/dev/null" c 1 3 2>/dev/null || true
	echo "Done."

	printf "Creating initramfs boot file..."
	cd "$output_rootfs"
	find . | cpio -H newc -ov > $output/rootfs.cpio 2>/dev/null
	$compression $output/rootfs.cpio
	echo "Done"
}