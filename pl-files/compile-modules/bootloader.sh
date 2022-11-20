# SPDX-License-Identifier: GPL-2.0-or-later

compile_bootloader(){
	_get_pkg_names

	_compile_ac_pkg "$toolchain_prefix/sbin/$compile_target-grub-install" "$grub_dir" \
				"Configuring GRUB" "--prefix=$toolchain_prefix --target=$compile_target --program-prefix=$compile_target- --with-platform=$grub_platform" \
				"Compiling GRUB" "" \
				"Installing GRUB Tools" "install"
	cp $grub_dir/build/grub-install ~/cross/bin/toolchain-grub-install
}
