{ pkgs ? import <nixpkgs> {} }:
let
  fullLlvm14Stdenv = pkgs.overrideCC pkgs.stdenv
    (pkgs.llvmPackages_14.libcxxStdenv.cc.override {
      inherit (pkgs.llvmPackages_14) bintools;
    });
in pkgs.mkShell.override { stdenv = fullLlvm14Stdenv; } {
	name = "pl-nix-llvm";

	shellHook=''
	export PATH="$HOME/cross/bin:$PATH" # add default toolchain location to path
	echo "PortaLinux nix-shell LLVM Development Environment"
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
		pkgs.libressl
		pkgs.bc
		pkgs.perl
		pkgs.kmod
	];
}
