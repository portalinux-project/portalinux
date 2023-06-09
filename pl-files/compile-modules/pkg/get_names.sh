# SPDX-License-Identifier: MPL-2.0

## Init Pkg Dir Vars
linux_dir=""
binutils_dir=""
gcc_dir=""
gmp_dir=""
mpc_dir=""
mpfr_dir=""
llvm_dir=""
libc_dir=""
coreutils_dir=""
pl32lib_dir=""
libplml_dir=""
plsrv_dir=""

_get_pkg_names(){
	dirlist="$(ls $build)"
	cd "$build"

	linux_dir="$(realpath $(echo $dirlist | grep 'linux.[0-9,a-z,A-Z,\.,\-]*' -o))"
	coreutils_dir="$(realpath $(echo $dirlist | grep '[0-9,a-z,A-Z,\.]*.box.[0-9,a-z,A-Z,\.]*' -o))"
	libc_dir="$(realpath $(echo $dirlist | grep 'musl.[0-9,a-z,A-Z,\.]*' -o))"
	pl32lib_dir="$(realpath $(echo $dirlist | grep 'pl32lib-ng.[0-9,a-z,A-Z,\.,\-]*' -o))"
	libplml_dir="$(realpath $(echo $dirlist | grep 'libplml.[0-9,a-z,A-Z,\.]*' -o))"
	plsrv_dir="$(realpath $(echo $dirlist | grep 'pl-srv.[0-9,a-z,A-Z,\.]*' -o))"
	if [ "$LLVM" != "" ]; then
		llvm_dir="$(realpath $(echo $dirlist | grep 'llvm.[0-9,a-z,A-Z,\.,\-]*' -o))"
	else
		binutils_dir="$(realpath $(echo $dirlist | grep 'binutils.[0-9,a-z,A-Z,\.]*' -o))"
		gcc_dir="$(realpath $(echo $dirlist | grep 'gcc.[0-9,a-z,A-Z,\.]*' -o))"
		if [ "$isinit" != "" ]; then
			gmp_dir="$(realpath $(echo $dirlist | grep 'gmp.[0-9,a-z,A-Z,\.]*' -o))"
			mpc_dir="$(realpath $(echo $dirlist | grep 'mpc.[0-9,a-z,A-Z,\.]*' -o))"
			mpfr_dir="$(realpath $(echo $dirlist | grep 'mpfr.[0-9,a-z,A-Z,\.]*' -o))"
		fi
	fi
}
