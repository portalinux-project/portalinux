_test() {
	case $1 in
		toolchain)
			$compile_target-gcc --version
			;;
		pkg_parser)
			if [ ! -r "$build" ]; then
				echo "Error: You haven't initialized yet! Run $0 --init and try again"
				exit 6
			fi

			_get_pkg_names
			printf "$linux_dir\n$binutils_dir\n$gcc_dir\n$gmp_dir\n$mpc_dir\n$mpfr_dir\n$libc_dir\n$coreutils_dir\n$bash_dir\n"
			;;
		defconfig)
			if [ "$3" != "" ]; then
				kdefconfig=$4
			fi

			echo "Default config is $kdefconfig"
			;;
		build-all-t*)
			toolchain-prefix="$HOME/test"

			for i in pc earm earm64; do
				logfile="$pldir/log-$i/"
				_target_system $i
				setup_toolchain
				_pl_clean soft
			done

			_target_system i486-gnu
			_init

			for i in pc64 aarch64-gnu i686-gnu armv7-gnu; do
				logfile="$pldir/log-$i/"
				_target_system $i
				setup_toolchain
				_pl_clean soft
			done
			;;
	esac
}
