#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0

require 'yaml'
# require 'pl-files/compile-files/plml.rb'
require 'etc'
require 'fileutils'

$baseDir = File.expand_path(".")
$buildDir = "#{$baseDir}/build"
$outputDir = "#{$baseDir}/output"

def errorHandler(msg, isOpt)
	print "Error: #{msg}."
	if isOpt == true
		puts " Run #{$0} -h for more information"
	end
	exit 1
end

def generatePkgInfo config
	preset = YAML.load_file("#{$baseDir}/pl-files/configure-files/#{config["preset"]}.yaml")
	pkgList = preset["pkgList"]
	retHash = Hash.new

	for pkgName in pkgList
		pkg = YAML.load_file("#{$baseDir}/pl-files/configure-files/pkg/#{pkgName}.yaml")
		retHash.store("#{pkg["name"]}", "#{pkg["version"]}")
	end

	return retHash
end

def cleanProjectDir(lvl=2)
	if lvl < 4
		buildDirHandle = Dir.open("#{$buildDir}")

		for dir in buildDirHandle.each_child
			dirPath = File.join($buildDir, dir)
			print "Cleaning #{dir}..."

			if Dir.exist?("#{dirPath}/build") == true
				if lvl == 1
					Dir.chdir("#{dirPath}/build")
					system("make -s clean >/dev/null 2>/dev/null")
				else
					FileUtils.rm_rf("#{dirPath}/build")
				end
			elsif File.exist?("#{dirPath}/Makefile") == true
				Dir.chdir("#{dirPath}")
				system("make -s clean >/dev/null 2>/dev/null")
			elsif File.exist?("#{dirPath}/compile") == true and File.exist?("#{dirPath}/configure.ac") == false
				Dir.chdir("#{dirPath}")
				system("./compile clean >/dev/null 2>/dev/null")
			end

			puts "Done."
		end

		if lvl == 3
			print "Cleaning output directory..."

			if Dir.exist?("#{$outputDir}") == true
				FileUtils.rm_rf("#{$outputDir}")
			end

			puts "Done."
		end

		puts "Project directory has been successfully cleaned."
	else
		print "Hard clean in progress..."

		if Dir.exist?("#{$buildDir}") == true
			FileUtils.rm_rf("#{$buildDir}")
		end

		if Dir.exist?("#{$outputDir}") == true
			FileUtils.rm_rf("#{$outputDir}")
		end

		if Dir.exist?("#{$baseDir}/tarballs") == true
			FileUtils.rm_rf("#{$baseDir}/tarballs")
		end

		if File.exist?("#{$baseDir}/.config") == true
			File.delete("#{$baseDir}/.config")
		end

		puts "Finished."
	end

	exit 0
end

def getLinuxArch arch
	if arch.scan("86") != Array.new and arch != "x86_64"
		return "i386"
	elsif arch.scan("arm") != Array.new or arch == "aarch64"
		if arch == "aarch64"
			return "arm64"
		end
		return "arm"
	else
		return arch
	end
end

def init
	if File.exist?(".config") == false
		puts "Error: No configuration found. Please run ./configure.rb -h for more information"
		exit 1
	end

	parsedConfig = YAML.load_file(".config")
	parsedConfig.store("triple", "#{parsedConfig["arch"]}-pocket-linux-musl")
	if parsedConfig["arch"].scan("arm") != Array.new
		parsedConfig["triple"] = parsedConfig["triple"] + "eabi"
		if parsedConfig["arch"] == "armv7"
			parsedConfig["triple"] = parsedConfig["triple"]	+ "hf"
		end
	end
	parsedConfig.store("linux_arch", getLinuxArch(parsedConfig["arch"]))

	parsedConfig.store("buildDir", $buildDir)
	parsedConfig.store("outputDir", $outputDir)
	parsedConfig.store("rootfsFilesDir", "#{$baseDir}/pl-files/pl-rootfs")
	parsedConfig.store("sysroot", File.join(parsedConfig["tcprefix"], parsedConfig["triple"]))
	case parsedConfig["toolchain"]
		when "gcc"
			parsedConfig.store("cross_cc", "#{parsedConfig["triple"]}-gcc")
		when "llvm"
			parsedConfig.store("cross_cc", File.join(parsedConfig["tcprefix"], "/bin/clang"))
			parsedConfig.store("cross_cflags", "--sysroot=#{parsedConfig["sysroot"]}")
		else
			errorHandler("Unknown toolchain.", false)
	end
	parsedConfig.merge!(generatePkgInfo(parsedConfig))

	return parsedConfig
end

def launchBuildScript config
	case $action
		when "toolchain"
			if config["toolchain"] == "gcc"
				puts "Launching GCC Build Script..."
				require_relative 'pl-files/compile-modules/gcc.rb'
			elsif config["toolchain"] == "llvm"
				puts "Launching LLVM Build Script..."
				require_relative 'pl-files/compile-modules/llvm.rb'
			end

			toolchainSetup config
			toolchainBuild
		when "rootfs"
			puts "Launching Root Filesystem Build Script..."
			require_relative 'pl-files/compile-modules/rootfs.rb'

			rootfsBuild
		when "boot-img"
			puts "Launching Root Filesystem Build Script..."
			require_relative 'pl-files/compile-modules/rootfs.rb'

			bootImgMaker
		when "kernel"
			puts "Launching Linux Kernel Build Script..."
			require_relative 'pl-files/compile-modules/kernel.rb'

			kernelBuild
		else
			errorHandler("Unknown build option", true)
	end
end

def parseArgs
	args = ARGV

	while args.length > 0
		case args[0]
			when "-b"
				if args.length < 2
					errorHandler("Not enough arguments")
				end
				$action = args[1]
				args.shift
			when "-t"
				if args.length < 2
					errorHandler("Not enough arguments")
				end
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

puts "PortaLinux Build System v0.11"
puts "(c) 2022-2023 pocketlinux32 & raisinware, Under MPL 2.0"

parseArgs
launchBuildScript init()
