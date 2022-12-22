# SPDX-License-Identifier: MPL-2.0

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
	if ! command -v $cross_cc > /dev/null; then
		echo "Error: You do not have the compiler for system $compile_target installed. Please run $0 --build toolchain and try again"
		exit 1
	fi
	musl_subset="--with-sysroot=/ --datarootdir=/opt/share --includedir=/opt/include"
	common_flags="$musl_subset --host=$compile_target"
	included_comp="--prefix=/usr $common_flags"
	main_comp="$included_comp --disable-multilib"
	_get_pkg_names $dist

	printf "Creating rootfs structure..."
	for i in dev sys proc opt usr/bin usr/lib root mnt home tmp var; do
		mkdir -p "$output_rootfs/$i"
		printf "."
	done
	cd "$output_rootfs"
	for i in bin sbin usr/sbin; do
		if [ ! -r "$output_rootfs/$i" ]; then
			ln -s "./usr/bin" "$output_rootfs/$i" 2>/dev/null || true
			printf "."
		fi
	done
	if [ ! -r "$output_rootfs/lib" ]; then
		ln -s "./usr/lib" "$output_rootfs/lib" 2>/dev/null || true
	fi
	cd "$pldir"
	echo "Done."

	if [ ! -r "$output_rootfs/usr/lib/libc.a" ]; then
		cd "$libc_dir"
		if [ "$dist" = "gnu" ]; then
			_exec "Preparing for compilation" "_setup_gcc"
			mkdir -p "build" && cd "build"
			if [ ! -r "$libc_dir/build/Makefile" ]; then
				_exec "Configuring glibc" "../configure $main_comp libc_cv_forced_unwind=yes CFLAGS='-s -O2' CXXFLAGS='-s -O2'"
			fi
			_exec "Compiling glibc" "make -j$threads"
			_exec "Installing glibc" "make DESTDIR=$output_rootfs install"
		else
			_compile_musl "/usr" "$musl_subset" rootfs
		fi

		printf "Packaging libc headers..."
		mkdir -p "$output/$dist-libc-headers/files/opt"
		cp -r "$output_rootfs/opt/include" "$output/$dist-libc-headers/files/opt"
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/usr/bin/$(basename $coreutils_dir | cut -d- -f1)" ]; then
		cd "$coreutils_dir"

		printf "Configuring Coreutils..."
		script -qeac "make defconfig 2>&1" "$logfile" >/dev/null
		if [ $(echo $coreutils_dir | grep "toybox") ]; then
			printf "CONFIG_SH=y\nCONFIG_DD=y\nCONFIG_EXPR=y\nCONFIG_INIT=y\nCONFIG_GETTY=y\nCONFIG_MDEV=y\n" >> .config
		fi
		echo "Done."
		_exec "Compiling Coreutils" "make CC='$cross_cc' CFLAGS='$cross_cflags -march=$arch' -j$threads"
		printf "Installing Coreutils..."
		mv *box "$output_rootfs/usr/bin"
		ln -s "/bin/$(basename $coreutils_dir | cut -d- -f1)" "$output_rootfs/usr/bin/sh" 2>/dev/null || true
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/init" ]; then
		printf "Installing init script..."
		if [ -f "$output_rootfs/usr/bin/toybox" ]; then
			$cross_cc $cross_cflags "$plfiles/pl-utils/pl-init.c" -o "$output_rootfs/init" -w
		else
			cp "$plfiles/initramfs-init" "$output_rootfs/init"
			chmod 777 "$output_rootfs/init"
			sed -i "s/IMG_VER/$IMAGE_VERSION/g" "$output_rootfs/init"
		fi
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/etc" ]; then
		printf "Installing etc files..."
		source "$plfiles/os-release"
		cp -r "$plfiles/etc" "$output_rootfs"
		chmod 777 "$output_rootfs/etc/init.d/rcS"
		if [ "$dist" = "musl" ]; then
			mv "$output_rootfs/etc/ld.so.conf" "$output_rootfs/etc/ld-musl-$(_generate_stuff musl).path"
		fi
		sed -i "s/IMG_VER/$IMAGE_VERSION/g" "$output_rootfs/etc/issue"
		sed -i "s/IMG_VER/$IMAGE_VERSION/g" "$output_rootfs/etc/init.d/rcS"
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

	if [ ! -r "$output_rootfs/usr/lib/os-release" ]; then
		printf "Installing os-release..."
		cp "$plfiles/os-release" "$output_rootfs/usr/lib"
		if [ "$dist" = "gnu" ]; then
			sed -i 's/VAR_NAME/Desktop/g' "$output_rootfs/usr/lib/os-release"
			sed -i 's/VAR_ID/pl-glibc/g' "$output_rootfs/usr/lib/os-release"
		else
			if [ "$toybox" = "y" ] || [ "$LLVM" = "1" ]; then
				sed -i 's/VAR_NAME/ToyMusl/g' "$output_rootfs/usr/lib/os-release"
				sed -i 's/VAR_ID/pl-toymusl/g' "$output_rootfs/usr/lib/os-release"
			else
				sed -i 's/VAR_NAME/Musl/g' "$output_rootfs/usr/lib/os-release"
				sed -i 's/VAR_ID/pl-busymusl/g' "$output_rootfs/usr/lib/os-release"
			fi
		fi

		sed -i "s/BID/pl-build-$(date +%s)/g" "$output_rootfs/usr/lib/os-release"
		echo "Done."
	fi
}

create_boot_image(){
	_rootfs_cleanup

	# find a way to escalate privilages, if not already running as root
	if [ $(id -u) = 0 ]; then
		su_exec=""
	elif command -v /run/wrappers/bin/pkexec 2>/dev/null; then
		su_exec="/run/wrappers/bin/pkexec"
	elif command -v /run/wrappers/bin/sudo 2>/dev/null; then
		su_exec="/run/wrappers/bin/sudo"
	elif command -v pkexec 2>/dev/null; then
		su_exec="pkexec"
	elif command -v sudo 2>/dev/null; then
		su_exec="sudo"
	else
		echo "Error: No way to esclate privilages, aborting!"
		exit 3
	fi

	printf "Creating necessary device nodes..."
	$su_exec "$plfiles/compile-modules/mknod.sh"
	echo "Done."

	printf "Creating initramfs boot file..."
	cd "$output_rootfs"
	find . | cpio -H newc -ov > $output/rootfs.cpio 2>/dev/null
	$compression $output/rootfs.cpio
	echo "Done"
}
