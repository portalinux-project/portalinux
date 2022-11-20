# SPDX-License-Identifier: GPL-2.0-or-later

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
bash_dir=""
make_dir=""
nano_dir=""
ncurses_dir=""
python_dir=""
grub_dir=""

_get_pkg_names(){
	dirlist="$(ls $build)"
	cd "$build"

	linux_dir="$(realpath $(echo $dirlist | grep 'linux.[0-9,a-z,A-Z,\.,\-]*' -o))"
	coreutils_dir="$(realpath $(echo $dirlist | grep '[0-9,a-z,A-Z,\.]*.box.[0-9,a-z,A-Z,\.]*' -o))"
	bash_dir="$(realpath $(echo $dirlist | grep 'bash.[0-9,a-z,A-Z,\.]*' -o))"
	make_dir="$(realpath $(echo $dirlist | grep 'make.[0-9,a-z,A-Z,\.]*' -o))"
	nano_dir="$(realpath $(echo $dirlist | grep 'nano.[0-9,a-z,A-Z,\.]*' -o))"
	ncurses_dir="$(realpath $(echo $dirlist | grep 'ncurses.[0-9,a-z,A-Z,\.]*' -o))"
	grub_dir="$(realpath $(echo $dirlist | grep 'grub.[0-9,a-z,A-Z,\.]*' -o))"
#	python_dir="$(realpath $(echo $dirlist | grep 'python.[0-9,a-z,A-Z,\.]*' -o))"
	if [ "$LLVM" != "" ]; then
		llvm_dir="$(realpath $(echo $dirlist | grep 'llvm.[0-9,a-z,A-Z,\.,\-]*' -o))"
	else
		binutils_dir="$(realpath $(echo $dirlist | grep 'binutils.[0-9,a-z,A-Z,\.]*' -o))"
		gcc_dir="$(realpath $(echo $dirlist | grep 'gcc.[0-9,a-z,A-Z,\.]*' -o))"
		gmp_dir="$(realpath $(echo $dirlist | grep 'gmp.[0-9,a-z,A-Z,\.]*' -o))"
		mpc_dir="$(realpath $(echo $dirlist | grep 'mpc.[0-9,a-z,A-Z,\.]*' -o))"
		mpfr_dir="$(realpath $(echo $dirlist | grep 'mpfr.[0-9,a-z,A-Z,\.]*' -o))"
	fi

	if [ "$dist" = "gnu" ]; then
		libc_dir="$(realpath $(echo $dirlist | grep 'glibc.[0-9,a-z,A-Z,\.]*' -o))"
	else
		libc_dir="$(realpath $(echo $dirlist | grep 'musl.[0-9,a-z,A-Z,\.]*' -o))"
	fi
}
