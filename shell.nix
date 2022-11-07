{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell.override { stdenv = pkgs.gcc7Stdenv; } {
	name = "pl-nix";

	shellHook=''
	export PATH="$HOME/cross/bin:$PATH" # add default toolchain location to path
	echo "PortaLinux nix-shell Development Environment"
	'';

	hardeningDisable = [ "format" ]; # fixes errors trying to build the gcc toolchain
	nativeBuildInputs = [
		#pkgs.busybox
		pkgs.cacert
		pkgs.wget
		pkgs.which
		pkgs.unixtools.script
		pkgs.rsync
		pkgs.gnumake
		pkgs.flex
		pkgs.bison
		pkgs.gawk

		# kernel build deps
		pkgs.ncurses
		pkgs.flex
		pkgs.libressl
		pkgs.bc
		pkgs.perl
		pkgs.kmod
	];

}
