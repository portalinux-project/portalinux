# SPDX-License-Identifier: MPL-2.0

_get_deps(){
	URL="$kernel_url $musl_url $toybox_url $pl32lib_url $libplml_url $plsrv_url"

	if [ "$LLVM" != "" ]; then
		URL="$llvm_url $URL"
	else
		URL="$gcc_url $gmp_url $mpc_url $mpfr_url $binutils_url $URL"
	fi

	mkdir -p tarballs && cd tarballs

	for i in $URL; do
		if [ ! -f "$(basename $i)" ] || [ $(echo "$i" | grep "https://github.com" -c) -ne 0 ]; then
			printf "\n$i\n" >> $logfile
			if [ "$i" = "$pl32lib_url" ] || [ "$i" = "$libplml_url" ] || [ "$i" = "$plsrv_url" ]; then
				extra_wget_flag="-O $(basename $(dirname $(dirname $(dirname $(dirname $i))))).tar.gz"
			fi
			_exec "Downloading $(basename $i)" "wget -q --show-progress --progress=dot:giga '$i' $extra_wget_flag $1" "cd .. && rm -rf tarballs" "no-silent"
		else
			echo "$(basename $i) has already been downloaded. Skipping..."
		fi
	done
}

_decompress_all(){
	if [ "$overlayfs" != "" ]; then
		set +e
	fi

	for i in $(ls | grep .tar); do
		printf "Unpacking archive $i..."
		case $i in
			*.gz)
				gunzip -c "$i"  | tar xf -
				;;
			*.bz2)
				bunzip2 -c "$i" | tar xf -
				;;
			*.xz)
				xz -dc "$i" | tar xf -
				;;
		esac
		echo "Done."
	done
	echo "Decompressed all files successfully"
}

_init(){
	isinit="yee :3"
	if [ -d "$build" ]; then
		_exec "Detected old build files, removing" "rm -rf $build"
	fi

	if [ "$1" = "overlayfs-mode" ]; then
		echo "WARNING: OverlayFS mode detected, error handling disabled"
		overlayfs="1"
		shift
	fi

	_get_deps $1
	mkdir -p "$build" "$toolchain_prefix" "$output"

	cd "$pldir/tarballs" && _decompress_all
	for i in $(ls); do
		if [ -d "$i" ]; then
			mv "$i" "$build"
		fi
	done

	_get_pkg_names
	for i in arch crt; do
		cd "$libc_dir/$i"
		for j in i486 i586 i686; do
			ln i386 $j -s
		done
	done

	if [ "$LLVM" = "" ]; then
		mv "$gmp_dir" "$gcc_dir/gmp"
		mv "$mpc_dir" "$gcc_dir/mpc"
		mv "$mpfr_dir" "$gcc_dir/mpfr"
	fi

	sed -i "s/bash/sh/" "$coreutils_dir/scripts/genconfig.sh"
	sed -i "s/bash/sh/" "$coreutils_dir/scripts/make.sh"
}
