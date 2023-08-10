# SPDX-License-Identifier: MPL-2.0

. ./common.sh

compile_toolchain(){
	# pl32lib
	if [ ! -r "$sysroot/lib/libpl32.so" ]; then
		cd "$pl32lib_dir"

		_exec "Configuring pl32lib" "./configure --prefix='$sysroot' CC='$cross_cc' CFLAGS='$cross_cflags -march=$arch -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling pl32lib" "./compile build"
		_exec "Installing pl32lib" "./compile install"
	fi

	# libplml
	if [ ! -r "$sysroot/lib/libplml.so" ]; then
		cd "$libplml_dir"

		_exec "Configuring libplml" "./configure --prefix='$sysroot' CC='$cross_cc' CFLAGS='$cross_cflags -march=$arch -Os' LDFLAGS='$cross_ldflags'"
		_exec "Compiling libplml" "./compile build"
		_exec "Installing libplml" "./compile install"
	fi

}
