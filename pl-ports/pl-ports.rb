#!/usr/bin/env ruby
# SPDX-License-Identifier: MPL-2.0

# PortaLinux Ports System, v0.02
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

	print "* Extracting #{packageName}..."
	extracted = PLPorts::Common.extractArchive("#{packageName}.popk", packageName)
	if extracted == 1
		puts "Skipped."
		Dir.chdir(packageName)
	else
		puts "Done."
	end
end

def printPackageInfo(packageName)
	pkgInfo = PLML.load_file("./properties.plml")
	puts
	puts "Package name: #{pkgInfo["name"]}"
	puts "Package version: #{pkgInfo["version"]}"
	puts "Package Author: #{pkgInfo["author"]}"
	puts "Source URL: #{pkgInfo["url"]}"
	puts
end

def installPackage(packageName)
	load 'build.rb'
	print "* Initializing package..."
	Package.init()
	puts "Done."
	Package.fetch()

	stageAmnt = Package.getStageAmnt()
	if stageAmnt > 0
		currentStage = 0
		while currentStage < stageAmnt
			print "* Running Package.build() (Stage #{currentStage + 1})...\n\n"
			currentStage += 1
			Package.build(currentStage)
		end
	else
		print "* Running Package.build()...\n\n"
		Package.build()
	end
	print "* Running Package.install()...\n\n"
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

puts "PortaLinux Ports System, v0.02"
print "(c) 2024 CinnamonWolfy, Under MPL 2.0\n\n"

parseArgs
for package in $pkgNames
	fetchPackage(package)
	printPackageInfo(package)
	if $installPkg == true
		installPackage(package)
	end
end
