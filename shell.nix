with import <nixpkgs> {};
mkShell.override { stdenv = gcc7Stdenv; } {
	name = "pl-nix";

	shellHook=''
	export PATH="$HOME/cross/bin:$PATH" # add default toolchain location to path
	echo "PortaLinux nix-shell Development Environment"
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

		# kernel build deps
		ncurses
		libressl
		bc
		perl
		kmod
	];

}
