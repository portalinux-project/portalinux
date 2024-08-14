#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0
# PortaLinux Ports System, v0.01
# (c) 2024 CinnamonWolfy, Under MPL 2.0

$LOAD_PATH.append(File.expand_path("./lib"))
require 'common-ports'

$rootDir = "#{File.dirname $0}"
$pkgNames = Array.new
$installPkg = false

def fetchPackage(packageName)
	# TODO: implement package fetching
	if File.exist?("#{packageName}.popk") == false
		PLPorts::Common.errorHandler("Fetching is not implemented. You must give a package that exists within the current directory")
	end

	PLPorts::Common.extractFile("#{packageName}.popk")
end

def printPackageInfo(packageName)
	Dir.chdir("#{packageName}")
	# TODO: implement info printing
end

def installPackage(packageName)
	Dir.chdir("#{packageName}")
	load 'build.rb'
	Package.init()
	Package.fetch()
	Package.build()
	Package.install()
	Dir.chdir("#{$rootDir}")
end

def parseArgs
	args = ARGV

	if args.length < 1
		PLPorts::Common.errorHandler("Not enough arguments. Please run '#{File.basename $0} help' for more information")
	end

	while args.length > 0
		case args[0]
			when "install"
				if args.length < 2
					PLPorts::Common.errorHandler("Not enough arguments.  Please run '#{File.basename $0} help' for more information")
				end

				$installPkg = true
				args.shift
				for name in args
					$pkgNames.push(name)
				end
				args.shift(args.length - 1)
			when "info"
				if args.length < 2
					PLPorts::Common.errorHandler("Not enough arguments.  Please run '#{File.basename $0} help' for more information")
				end

				args.shift
				for name in args
					$pkgNames.push(name)
				end
				args.shift(args.length - 1)
			when "help"
				print "Usage: #{File.basename $0} [install|info|refresh|help]\n\n"
				puts "install		- Installs packages"
				puts "info		- Shows information about the package"
				puts "refresh		- Redownload package listings"
				puts "help		- Shows this help"
			else
				PLPorts::Common.errorHandler("Unknown option.  Please run '#{File.basename $0} help' for more information")
		end
		args.shift
	end
end

puts "PortaLinux Ports System, v0.01"
print "(c) 2024 CinnamonWolfy, Under MPL 2.0\n\n"

parseArgs
for package in $pkgNames
	fetchPackage(package)
	if $installPkg == true
		installPackage(package)
	end
end
