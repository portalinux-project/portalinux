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

create_boot_image(){
	_rootfs_cleanup

	# find a way to escalate privilages, if not already running as root
	if [ $(id -u) = 0 ]; then
		su_exec=""
	elif command -v /run/wrappers/bin/sudo >/dev/null; then
		su_exec="/run/wrappers/bin/sudo"
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
