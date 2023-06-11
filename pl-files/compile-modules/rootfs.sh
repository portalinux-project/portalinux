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

	if [ "$LLVM" != "" ]; then
		cross_cflags="$cross_cflags -march=i486"
	fi

	printf "Creating rootfs structure..."
	for i in dev sys proc opt usr/bin usr/lib root mnt home tmp var/pl-srv; do
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
		_compile_musl "/usr" "$musl_subset" rootfs

		printf "Packaging libc headers..."
		mkdir -p "$output/libc-headers/files/opt"
		cp -r "$output_rootfs/opt/include" "$output/libc-headers/files/opt"
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/usr/bin/toybox" ]; then
		cd "$coreutils_dir"

		printf "Configuring Toybox..."
		script -qeac "make defconfig 2>&1" "$logfile" >/dev/null
		printf "CONFIG_SH=y\nCONFIG_DD=y\nCONFIG_EXPR=y\nCONFIG_GETTY=y\nCONFIG_MDEV=y\n" >> .config
		echo "Done."
		_exec "Compiling Toybox" "make CC='$cross_cc' CFLAGS='$cross_cflags $cross_ldflags' -j$threads"
		printf "Installing Toybox..."
		mv *box "$output_rootfs/usr/bin"
		ln -s "/usr/bin/toybox" "$output_rootfs/usr/bin/sh" 2>/dev/null || true
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/usr/lib/libpl32.so" ]; then
		cd "$pl32lib_dir"

		_exec "Configuring pl32lib" "./configure --prefix='$output_rootfs/usr' CC='$cross_cc' CFLAGS='$cross_cflags -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling pl32lib" "./compile build"
		_exec "Installing pl32lib" "./compile install"
	fi

	if [ ! -r "$output_rootfs/usr/lib/libplml.so" ]; then
		cd "$libplml_dir"

		_exec "Configuring libplml" "./configure --prefix='$output_rootfs/usr' CC='$cross_cc' CFLAGS='$cross_cflags -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling libplml" "./compile build"
		_exec "Installing libplml" "./compile install"
	fi

	if [ ! -r "$output_rootfs/usr/bin/pl-srv" ]; then
		cd "$plsrv_dir"

		_exec "Configuring pl-srv" "./configure --prefix='$output_rootfs/usr' CC='$cross_cc' CFLAGS='$cross_cflags -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling pl-srv" "./compile build"
		_exec "Installing pl-srv" "./compile install"
		ln -s ./usr/bin/pl-init $output_rootfs/init
	fi

	if [ ! -r "$output_rootfs/etc" ]; then
		printf "Installing etc files..."
		source "$plfiles/os-release"
		cp -r "$plfiles/etc" "$output_rootfs"
		mkdir -p "$output_rootfs/etc/pl-srv"
		mv "$output_rootfs/etc/ld.so.conf" "$output_rootfs/etc/ld-musl-$(_generate_stuff musl).path"
		sed -i "s/IMG_VER/$IMAGE_VERSION/g" "$output_rootfs/etc/issue"
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/usr/bin/pl-setup" ]; then
		printf "Installing PortaLinux scripts..."
		cp "$plfiles/pl-utils/pl-install" "$output_rootfs/usr/bin"
		chmod 777 "$output_rootfs/usr/bin/pl-install"
		cp "$plfiles/pl-utils/toybox-init" "$output_rootfs/usr/bin"
		chmod 777 "$output_rootfs/usr/bin/toybox-init"
		cp "$plfiles/pl-utils/pl-shell" "$output_rootfs/usr/bin"
		chmod 777 "$output_rootfs/usr/bin/pl-shell"
		echo "Done."
	fi

	if [ ! -r "$output_rootfs/usr/lib/os-release" ]; then
		printf "Installing os-release..."
		cp "$plfiles/os-release" "$output_rootfs/usr/lib"
		sed -i 's/VAR_NAME/ToyMusl/g' "$output_rootfs/usr/lib/os-release"
		sed -i 's/VAR_ID/pl-toymusl/g' "$output_rootfs/usr/lib/os-release"
		sed -i "s/BID/pl-build-$(date +%s)/g" "$output_rootfs/usr/lib/os-release"
		echo "Done."
	fi
}

create_boot_image(){
	_rootfs_cleanup

	# find a way to escalate privilages, if not already running as root
	if [ $(id -u) = 0 ]; then
		su_exec=""
	elif command -v /run/wrappers/bin/pkexec >/dev/null; then
		su_exec="/run/wrappers/bin/pkexec"
	elif command -v /run/wrappers/bin/sudo >/dev/null; then
		su_exec="/run/wrappers/bin/sudo"
	elif command -v pkexec >/dev/null; then
		su_exec="pkexec"
	elif command -v sudo >/dev/null; then
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
