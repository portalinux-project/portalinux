# SPDX-License-Identifier: MPL-2.0

_get_deps(){
	URL="$kernel_url $bash_url $make_url $ncurses_url $nano_url $grub_url $musl_url $toybox_url"

	if [ "$LLVM" != "" ]; then
		URL="$llvm_url $URL"
	else
		URL="$gcc_url $gmp_url $mpc_url $mpfr_url $binutils_url $URL"
	fi

	if [ "$2" = "experimental" ]; then
		URl="$URL $xserver_url $bison_url"
	fi

	mkdir -p tarballs && cd tarballs

	for i in $URL; do
		if [ ! -f "$(basename $i)" ]; then
			printf "\n$i\n" >> $logfile
			_exec "Downloading $(basename $i)" "wget -q --show-progress --progress=dot:giga '$i' $1" "cd .. && rm -rf tarballs" "no-silent"
		else
			echo "$(basename $i) has already been downloaded. Skipping..."
		fi
	done
}

_decompress_all(){
	for i in $(ls | grep .tar); do
		printf "Unpacking archive $i..."
		case $i in
			*.gz)
				gunzip -c "$i" | tar xf -
				;;
			*.bz2)
				bunzip2 -c "$i" | tar xf -
				;;
			*.xz)
				xz -dc "$i" | tar xf -
				;;
			*.zip)
				unzip "$i" &>/dev/null
		esac
		echo "Done."
	done
	echo "Decompressed all files successfully"
}

_init(){
	if [ -d $build ]; then
		_exec "Detected old build files, removing" "rm -rf $build"
	fi

	_get_deps $1 $2
	mkdir -p $build $toolchain_prefix $output
	cd $pldir/tarballs && _decompress_all
	for i in $(ls); do
		if [ -d $i ]; then
			mv $i $build
		fi
	done

	_get_pkg_names $dist
	for i in arch crt; do
		cd "$libc_dir/$i"
		for j in i486 i586 i686; do
			ln i386 $j -s
		done
	done

	if [ "$toybox" != "" ]; then   # NixOS fixes
		sed -i "s/bash/sh/" "$coreutils_dir/scripts/genconfig.sh"
		sed -i "s/bash/sh/" "$coreutils_dir/scripts/make.sh"
	fi
}
