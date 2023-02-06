# SPDX-License-Identifier: MPL-2.0

_parse_platform(){
	set +e
	case $1 in
		android32 | earm)
			specific_arch="armv7"
			;;
		android64 | earm64)
			specific_arch="aarch64"
			;;
		pc | pc32)
			specific_arch="i486"
			;;
		pc64)
			specific_arch="x86_64"
			;;
		*)
			if [ -f "$pldir/custom-platforms" ]; then
				source "$plfiles/compile-modules/custom-platforms.sh" $specific_arch
			fi
			;;
	esac
	set -e
}

_target_system(){
	specific_arch=$1

	_parse_platform $1
	if [ $(echo "$specific_arch" | grep -c arm) -ne 0 ]; then
		arch="arm"
		abi="eabi"
		linux_arch="$arch"
		with_aoc="--with-arch=$specific_arch"
		if [ $(echo "$specific_arch" | grep -c 7) -ne 0 ]; then
			abi="eabihf"
		fi
	elif [ $(echo "$specific_arch" | grep -c 86) -ne 0 ]; then
		arch="$specific_arch"
		if [ $(echo "$specific_arch" | grep -c i) -ne 0 ]; then
			linux_arch="i386"
		else
			linux_arch="x86_64"
		fi
	else
		arch="$specific_arch"
		if [ "$specific_arch" = "aarch64" ]; then
			linux_arch="arm64"
		else
			linux_arch="$arch"
		fi

		if [ "$arch" = "powerpc" ]; then
			with_aoc="--with-cpu=$specific_arch"
		fi
	fi

	compile_target="$arch-pocket-linux-musl$abi"
	sysroot="$toolchain_prefix/$compile_target"
}
