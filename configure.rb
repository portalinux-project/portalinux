#!/usr/bin/env ruby

$validArchitectures = [ "i486", "i586", "i686", "x86_64", "armv6", "armv7", "aarch64", "riscv64" ]
$validToolchains = [ "llvm", "gcc" ]

$arch = ""
$toolchain = ""
$prefix = File.expand_path("~/cross")

def errorHandler(msg)
	puts "Error: #{msg}. Run #{$0} -h for more information"
	exit 1	
end

def parseArgs
	args = ARGV

	while args.length > 0
		case args[0]
			when "-a"
				if args.length < 2
					errorHandler "Not enough arguments"
				end
				$arch = args[1]
				args.shift
			when "-t"
				if args.length < 2
					errorHandler "Not enough arguments"
				end
				$toolchain = args[1]
				args.shift
			when "-p"
				if args.length < 2
					errorHandler "Not enough arguments"
				end
				$prefix = File.expand_path(args[1])
				args.shift
			when "-h"
				puts " -a	Sets the target architecture"
				puts "		Valid options:"
				puts "			i486"
				puts "			i586"
				puts "			i686"
				puts "			x86_64"
				puts "			armv6"
				puts "			armv7"
				puts "			aarch64"
				puts "			riscv64"
				puts " -t	Sets which toolchain to use"
				puts "		Valid options:"
				puts "			llvm"
				puts "			gcc"
				puts " -p	Sets the cross toolchain install directory"
				print " -h	Shows this help\n\n"
				puts "For more information, please go to https://github.com/pocketlinux32/portalinux"
				exit				
			else
				errorHandler "Unknown option" 
		end
		args.shift
	end
end

def validateArgs
	if $arch == ""
		errorHandler "Architecture not set"
	end

	if $toolchain == ""
		errorHandler "Toolchain not set"
	end

	i = 0
	while $validArchitectures[i] != $arch and i < $validArchitectures.length
		i = i + 1
	end

	if $validArchitectures[i] != $arch
		errorHandler "Unknown architecture"
	end

	i = 0
	while $validToolchains[i] != $toolchain and i < $validToolchains.length
		i = i + 1
	end

	if $validToolchains[i] != $toolchain
		errorHandler "Unsupported toolchain"
	end	
end

puts "PortaLinux Build System v0.11"
print "(c) 2023 pocketlinux32 & raisinware, Under MPL 2.0\n\n"

if ARGV.length < 1
	errorHandler "Not enough arguments"
end

parseArgs
validateArgs

puts "Toolchain: #{$toolchain}"
puts "Architecture: #{$arch}"
puts "Toolchain Install Directory: #{$prefix}"
