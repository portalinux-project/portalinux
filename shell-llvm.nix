with import <nixpkgs> {};
mkShell.override { stdenv = pkgsLLVM.stdenv; } {
	name = "pl-nix-llvm";

	shellHook=''
	export PATH="$HOME/cross/bin:$PATH" # add default toolchain location to path
	echo "PortaLinux nix-shell LLVM Development Environment"
	'';

	hardeningDisable = [ "format" ]; # fixes errors trying to build the gcc toolchain
	nativeBuildInputs = [
		#busybox
		cacert
		wget
		which
		unixtools.script
		rsync
		gnumake
		flex
		bison
		gawk

		# llvm deps
		cmake
		ninja
		python3

		# kernel build deps
		ncurses
		libressl
		bc
		perl
		kmod
	];
}
