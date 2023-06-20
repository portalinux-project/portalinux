#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0

require 'yaml'
require 'etc'
require 'fileutils'

$threads = Etc.nprocessors / 2
$baseDir = File.expand_path(".")
$buildDir = "#{$baseDir}/build"
$rootfsDir = "#{$baseDir}/pl-files/pl-rootfs"
$outputDir = "#{$baseDir}/output"
$buildTarget = Array.new

$action = ""

def errorHandler(msg, isOpt)
	print "Error: #{msg}."
	if isOpt == true
		puts " Run #{$0} -h for more information"
	end
	exit 1
end

def cleanProjectDir(lvl=2)
	if lvl < 4
		buildDirHandle = Dir.open("#{$buildDir}")

		for dir in buildDirHandle.each_child
			dirPath = File.join_path($buildDir, dir)
			print "Cleaning #{dir}..."

			if Dir.exist?("#{dirPath}/build") == true
				if lvl == 1
					Dir.chdir("#{dirPath}/build")
					system("make -s clean >/dev/null 2>/dev/null")
				else
					FileUtils.rm_rf("#{dirPath}/build")
				end
			else if File.exist?("#{dirPath}/Makefile") == true
				Dir.chdir("#{dirPath}")
				system("make -s clean >/dev/null 2>/dev/null")
			else if File.exist?("#{dirPath}/compile") and File.exist?("#{dirPath}/configure.ac") == false
				Dir.chdir("#{dirPath}")
				system("./compile clean")
			end
			puts "Done."
		end

		if lvl == 3
			if Dir.exist?("#{$outputDir}") == true
				FileUtils.rm_rf("#{$outputDir}")
			end
		end
	else
		if Dir.exist?("#{$buildDir}") == true
			FileUtils.rm_rf("#{$buildDir}")
		end

		if Dir.exist?("#{$outputDir}") == true
			FileUtils.rm_rf("#{$outputDir}")
		end
		
		if Dir.exist?("#{$baseDir}/tarballs") == true
			FileUtils.rm_rf("#{$baseDir}/tarballs")
		end
	end

	exit 0
end

def parseArgs
	args = ARGV

	while args.length > 0
		case args[0]
			when "-b"
				if args.length < 2
					errorHandler("Not enough arguments")
				$action = args[1]
				args.shift
			when "-t"
				if args.length < 2
					errorHandler("Not enough arguments")
				$threads = Integer(args[1])
				args.shift
			when "-c"
				if args.length > 1
					cleanProjectDir Integer(args[1])
				else
					cleanProjectDir
				end
			when "-hc"
				cleanProjectDir 4
			when "-h"
				puts "Usage: #{$0} [-b build|-c lvl|-hc|-h] {-t threads}"
				puts " -b	Builds a component"
				puts "		Valid options:"
				puts "			toolchain"
				puts "			rootfs"
				puts "			boot-img"
				puts "			kernel"
				puts " -t	Sets the amount of threads to use in compilation"
				puts "		Default: half of all threads"
				puts " -c	Cleans the build directory at the specified level of cleaning"
				puts "		Valid options:"
				puts "			1 (bare minimum)"
				puts "			2 (default, deletes internal build dir for autoconf projects)"
				puts "			3 (stronger, deletes output directory)"
				puts "			4 (hard clean, deletes all directories and files generated by the configure and build process)"
				puts " -hc	Equivalent to -c 4"
				puts " -h	Shows this help"
				puts "For more information, please go to https://github.com/pocketlinux32/portalinux"
				exit
			else
				errorHandler("Unknown option", true)
		end
		args.shift
	end
end

def launchBuildScript
	case $action
		when "toolchain"
			if $buildTarget["toolchain"] == "gcc"
				puts "Launching GCC Build Script..."
				require 'pl-files/compile-modules/gcc.rb'
			else if $buildTarget["toolchain"] == "llvm"
				puts "Launching LLVM Build Script..."
				require 'pl-files/compile-modules/llvm.rb'
			end

			toolchain_build
		when "rootfs"
			puts "Launching Root Filesystem Build Script..."
			require 'pl-files/compile-modules/rootfs.rb'
			rootfs_build
		when "boot-img"
			puts "Launching Root Filesystem Build Script..."
			require 'pl-files/compile-modules/rootfs.rb'
			bootimg_maker
		when "kernel"
			puts "Launching Linux Kernel Build Script..."
			require 'pl-files/compile-modules/kernel.rb'
			kernel_build
		else
			errorHandler("Unknown build option", true)
end

def init
	if File.exist?(".config") == false
		puts "Error: No configuration found. Please run ./configure.rb -h for more information"
		exit 1
	end

	parsedConfig = YAML.load_file(".config")
	$buildTarget = parsedConfig
	$buildTarget.push("triple" => "#{$buildTarget["arch"]}-pocket-linux-musl")
	if $buildTarget["arch"].scan("arm") != Array.new
		$buildTarget["triple"] = $buildTarget["triple"] + "eabi"
		if $buildTarget["arch"] == "armv7"
			$buildTarget["triple"] = $buildTarget["triple"]	+ "hf"
		end
	end
	$buildTarget.push("sysroot" => "#{$buildTarget["tcprefix"]/$buildTarget["triple"]}")

	case $buildTarget["toolchain"]
		when "gcc"
			$buildTarget.push("cross_cc" => "#{$buildTarget["triple"]-gcc}")
		when "llvm"
			$buildTarget.push("cross_cc" => "#{$buildTarget["tcprefix"]/bin/clang}")
			$buildTarget.push("cross_cflags" => "--sysroot=#{$buildTarget["sysroot"]}")
	end
end

puts "PortaLinux Build System v0.11"
puts "(c) 2022-2023 pocketlinux32 & raisinware, Under MPL 2.0"

parseArgs
init
