with import <nixpkgs> {};
mkShell.override { stdenv = gcc8Stdenv; } {
	name = "pl-nix";

	shellHook=''
	echo "PortaLinux nix-shell Development Environment"
	echo "NOTE: When using the GCC PortaLinux toolchain, please remember to add the toolchain prefix bin to your path."
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
		libuuid
		zstd

		# llvm deps
		cmake
		ninja
		python3

		# kernel build deps
		pkg-config
		ncurses
		libressl
		bc
		perl
		kmod
	];
}
