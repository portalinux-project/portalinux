#!/usr/bin/env ruby
require 'yaml'
require 'net/http'

$validArchitectures = [ "i486", "i586", "i686", "x86_64", "armv5", "armv6", "armv7", "aarch64", "riscv64" ]
$validToolchains = [ "llvm", "gcc" ]

$arch = ""
$toolchain = ""
$prefix = File.expand_path("~/cross")
$baseDir = File.expand_path(".")
$configDir = "#{$baseDir}/pl-files"

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
				puts "			armv5"
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

def downloadFile(url, file, secure)
	if File.exist?(file) == true
		puts "#{File.basename(file)} exists, skipping..."
		return
	end

	print "Downloading #{File.basename(file)}..."
	
	uri = URI(url)
	port = 80
	if secure == true
		port = 443
	end

	connection = Net::HTTP.new(uri.host, port)
	connection.use_ssl = secure
	response = connection.get(uri.path)
	downloadedFile = File.open(file, "wb")
	downloadedFile.write(response.body)
	downloadedFile.close

	puts "Done."
end

def fetchPkgs pkgList
	for i in pkgList
		fileParse = YAML.load_file("#{$configDir}/configure-files/pkg/" + i ".yaml")

		if fileParse["github"] == true
			tempUrl = "https://codeload.github.com/" + fileParse["url"] + "/tar.gz/refs/"
			if fileParse["tag"] == nil
				tempUrl = tempUrl + "heads/"
				if fileParse["branch"] == nil
					tempUrl = tempUrl + "main"
				else
					tempUrl = tempUrl + fileParse["branch"]
				end
			else
				tempUrl = tempUrl + "tags/" + fileParse["tag"]
			end

			downloadFile(tempUrl, "#{$baseDir}/tarballs/" + fileParse["name"] + "-" + fileParse["version"] + ".tar.gz", true)
		else
			use_secure = false
			if fileParse["secure"] != nil
				use_secure = fileParse["secure"]
			end

			downloadFile(fileParse["url"], "#{$baseDir}/tarballs/" + File.basename(URI.parse(fileParse["url"]).path), use_secure)
		end		
	end
end

def init
	if Dir.exist?("#{$baseDir}/tarballs") == false
		Dir.mkdir("#{$baseDir}/tarballs")
	end

	puts "Stage 1: Download packages\n"
	
	presetFile = YAML.load_file("#{$configDir}/configure-files/" + $toolchain + ".yaml")
	list = presetFile["pkgList"].scan(" ")

	fetchPkgs list

	puts "Stage 1 Complete! Starting Stage 2"
	puts "Stage 2: Extract packages\n"
end

puts "PortaLinux Configure System v0.11"
print "(c) 2022-2023 pocketlinux32 & raisinware, Under MPL 2.0\n\n"

if ARGV.length < 1
	errorHandler "Not enough arguments"
end

parseArgs
validateArgs

puts "Toolchain: #{$toolchain}"
puts "Architecture: #{$arch}"
puts "Toolchain Install Directory: #{$prefix}"

init
