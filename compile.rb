#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0

require 'yaml'
require 'etc'
require 'fileutils'

$threads = Etc.nprocessors / 2
$baseDir = File.expand_path(".")
$buildDir = "#{$baseDir}/build"
$rootfsPartsDir = "#{$baseDir}/pl-files/pl-rootfs"
$outputDir = "#{$baseDir}/output"
$rootfsDir = "#{$outputDir}/rootfs"
$buildTarget = Array.new

$action = ""

def errorHandler(msg, isOpt)
	print "Error: #{msg}."
	if isOpt == true
		puts " Run #{$0} -h for more information"
	end
	exit 1
end

def getPkgInfo pkgName action
	pkg = YAML.load_file("#{baseDir}/pl-files/configure-files/pkg/#{pkgName}.yaml")
	case action
		when "dir"
			return "#{pkg["name"]}-#{pkg["version"]}"
		when "version"
			return "#{pkg["version"]}"
	end
end

def blockingSpawn(*args){
	pid = spawn(*args)
	Process.wait pid
}

def musl_build(action, isRootfs=false)
	muslParams = {"arch" => $buildTarget["linux_arch"], "installDir" => $buildTarget["sysroot"], "prefixToInstallDir" => nil}

	if $buildTarget["arch"] == "aarch64"
		muslParams["arch"] = $buildTarget["arch"]
	end

	Dir.chdir("#{$buildDir}/#{getPkgInfo("musl", "dir")}")

	case action
		when "headers"
			if File.exist?("#{$buildTarget["sysroot"]}/include/stdio.h") == false
				system("make ARCH=#{muslParams["arch"]} prefix=#{$buildTarget["sysroot"]} install-headers")
				Dir.chdir("#{$buildDir}/#{getPkgInfo("linux", "dir")}")
				system("make ARCH=#{$buildTarget["linux_arch"]} INSTALL_HDR_PATH=#{$buildTarget["sysroot"]} headers_install")
			end
		when "libc"
			if File.exist?("#{installPath}/lib/libc.so") == false
				muslArgs = Array.new
				case $buildTarget["toolchain"]
					when "gcc"
						muslArgs.push("LIBCC" => "#{$buildTarget["tcprefix"]}/lib/gcc/#{$buildTarget["triple"]}/#{getPkgInfo("gcc", "version")}/libgcc.a")
						muslArgs.push("AR" => "#{$buildTarget["tcprefix"]}/bin/#{$buildTarget["triple"]}-ar")
						muslArgs.push("RANLIB" => "#{$buildTarget["tcprefix"]}/bin/#{$buildTarget["triple"]}-ranlib")
					when "llvm"
						muslArgs.push("LIBCC" => "#{$buildTarget["sysroot"]}/lib/linux/libclang_rt.builtins-#{$buildTarget["linux_arch"]}.a")
						muslArgs.push("AR" => "#{$buildTarget["tcprefix"]}/bin/llvm-ar")
						muslArgs.push("RANLIB" => "#{$buildTarget["tcprefix"]}/bin/llvm-ranlib")
				end

				blockingSpawn(muslArgs, "./compile --host=#{$buildTarget["triple"]} --prefix=#{$buildTarget["sysroot"]} --disable-multilib")
				system("make -j#{$threads} AR=#{muslArgs["AR"]} RANLIB=#{muslArgs["RANLIB"]}")
				system("make install")
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
			File.remove("#{$baseDir}/.config")
		end

		puts "Finished."
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

def launchBuildScript
	case $action
		when "toolchain"
			if $buildTarget["toolchain"] == "gcc"
				puts "Launching GCC Build Script..."
				require 'pl-files/compile-modules/gcc.rb'
			elsif $buildTarget["toolchain"] == "llvm"
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
	$buildTarget = parsedConfig
	$buildTarget.push("triple" => "#{$buildTarget["arch"]}-pocket-linux-musl")
	if $buildTarget["arch"].scan("arm") != Array.new
		$buildTarget["triple"] = $buildTarget["triple"] + "eabi"
		if $buildTarget["arch"] == "armv7"
			$buildTarget["triple"] = $buildTarget["triple"]	+ "hf"
		end
	end
	$buildTarget.push("linux_arch" => getLinuxArch($buildTarget["arch"]))
	$buildTarget.push("sysroot" => File.join($buildTarget["tcprefix"], $buildTarget["triple"]))

	case $buildTarget["toolchain"]
		when "gcc"
			$buildTarget.push("cross_cc" => "#{$buildTarget["triple"]-gcc}")
		when "llvm"
			$buildTarget.push("cross_cc" => File.join($buildTarget["tcprefix"], "/bin/clang"))
			$buildTarget.push("cross_cflags" => "--sysroot=#{$buildTarget["sysroot"]}")
		else
			errorHandler("Unknown toolchain.", false)
	end
end

puts "PortaLinux Build System v0.11"
puts "(c) 2022-2023 pocketlinux32 & raisinware, Under MPL 2.0"

parseArgs
init
